/// Una libreria MALF raggiunta per percorsi: WebDAV, un domani SMB.
///
/// Gemello di `DriveRepository`, più semplice perché qui i percorsi esistono
/// e non serve una ricerca per trovare i file: `library.json` sta nella
/// radice, `index.json` e `pages.json` nella cartella della serie, e le
/// tavole si chiedono col loro percorso.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kagami_archive/transport.dart';
import 'package:path/path.dart' as p;

import '../../format/malf.dart';
import '../drive.dart';
import '../library.dart';
import 'source.dart';

LibraryIndex _parseLibrary(String source) =>
    LibraryIndex.fromJson(jsonDecode(source) as Map<String, Object?>);

SeriesIndex _parseSeries(String source) =>
    SeriesIndex.fromJson(jsonDecode(source) as Map<String, Object?>);

PagesIndex _parsePages(String source) =>
    PagesIndex.fromJson(jsonDecode(source) as Map<String, Object?>);

/// Dopo quanto la libreria si rilegge da sola, come per Drive.
const Duration pathFreshness = Duration(minutes: 10);

class PathShelf implements LibraryShelf {
  /// [root] è la cartella della libreria dentro il trasporto (`''` se è la
  /// sua radice); [stateDirectory] è la cartella di stato della sorgente,
  /// sua e di nessun altro (`support/sources/<id>/`).
  PathShelf({
    required this.transport,
    required this.sourceId,
    required String stateDirectory,
    String root = '',
    @visibleForTesting DateTime Function()? now,
  })  : root = root.split('/').where((s) => s.isNotEmpty).join('/'),
        _state = Directory(stateDirectory),
        _now = now ?? DateTime.now;

  final StorageTransport transport;

  @override
  final String sourceId;

  final String root;
  final Directory _state;
  final DateTime Function() _now;

  LibraryIndex? _library;
  DateTime? _loadedAt;

  /// Se la libreria che si sta mostrando è l'istantanea dell'ultima volta,
  /// perché la sorgente non ha risposto.
  bool fromSnapshot = false;

  @override
  LibraryOrigin get origin => LibraryOrigin.remote;

  bool get stale =>
      _loadedAt == null || _now().difference(_loadedAt!) > pathFreshness;

  void refresh() => _loadedAt = null;

  File get _snapshot => File(p.join(_state.path, 'state.json'));

  Directory get _texts => Directory(p.join(_state.path, 'text'));

  /// Il percorso nel trasporto di un file relativo alla libreria.
  String pathOf(String relative) => root.isEmpty ? relative : '$root/$relative';

  Future<LibraryIndex>? _fetching;

  @override
  Future<LibraryIndex> loadLibrary() async {
    final memo = _library;
    if (memo != null && !stale) return memo;
    return _fetching ??= _fetch().whenComplete(() => _fetching = null);
  }

  Future<LibraryIndex> _fetch() async {
    try {
      final entry = await transport.stat(pathOf(libraryIndexFile));
      final LibraryIndex library;
      String? key;
      if (entry == null || entry.folder) {
        // Senza `library.json` la cartella è una libreria ancora vuota, ma
        // solo se la cartella c'è: una radice sparita non è «vuota».
        if (root.isNotEmpty && await transport.stat(root) == null) {
          throw SourceUnavailable(sourceId, SourceState.missing);
        }
        library = LibraryIndex.empty;
      } else {
        key = _textKey(entry);
        library = await compute(_parseLibrary, await _text(entry.path, key));
      }
      _library = library;
      _loadedAt = _now();
      fromSnapshot = false;
      await _save(key);
      _pruning = _prune(key);
      return library;
    } on TransportAuthRequired {
      _library = null;
      throw SourceUnavailable(sourceId, SourceState.needsAuth);
    } on TransportException catch (error) {
      final restored = _library ?? await _restore();
      if (restored != null) {
        _library = restored;
        fromSnapshot = true;
        return restored;
      }
      throw SourceUnavailable(
        sourceId,
        error is TransportNotFound ? SourceState.missing : SourceState.offline,
      );
    }
  }

  /// Il nome su disco della versione di un testo: dall'etag se il server lo
  /// dà, altrimenti da dimensione e data. Senza nessuno dei due, `null`:
  /// quel testo si chiede ogni volta.
  String? _textKey(RemoteEntry entry) {
    final mark = entry.etag ??
        (entry.size != null && entry.modified != null
            ? '${entry.size}@${entry.modified!.toUtc().toIso8601String()}'
            : null);
    return mark == null ? null : addressKey('${entry.path}|$mark');
  }

  Future<String> _text(String path, String? key) async {
    final file = key == null ? null : File(p.join(_texts.path, key));
    if (file != null && await file.exists()) return file.readAsString();
    final text = await transport.text(path);
    if (file != null) await _write(file, text);
    return text;
  }

  Future<void> _write(File file, String text) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(text);
    await temporary.rename(file.path);
  }

  Future<void> _save(String? key) async {
    await _state.create(recursive: true);
    await _snapshot.writeAsString(jsonEncode({'library': key}));
  }

  Future<void> _pruning = Future.value();

  @visibleForTesting
  Future<void> get pruned => _pruning;

  /// Dei testi di `library.json` resta solo la versione in uso.
  Future<void> _prune(String? key) async {
    try {
      if (!await _texts.exists()) return;
      await for (final entity in _texts.list()) {
        final name = p.basename(entity.path);
        if (name == key || name.endsWith('.tmp')) continue;
        await entity.delete().catchError((_) => entity);
      }
    } on Object {
      // Sfoltire è un favore: un errore qui non deve toccare la lettura.
    }
  }

  Future<LibraryIndex?> _restore() async {
    try {
      final json = jsonDecode(await _snapshot.readAsString()) as Map;
      final key = json['library'] as String?;
      if (key == null) return null;
      final text = await File(p.join(_texts.path, key)).readAsString();
      return await compute(_parseLibrary, text);
    } on Object {
      return null;
    }
  }

  /// Un testo della serie, chiesto ogni volta che la serie si apre: l'ultima
  /// copia arrivata resta su disco e risponde se la sorgente tace. `null`
  /// solo se la sorgente ha detto che non c'è.
  Future<String?> seriesText(SeriesEntry entry, String name) async {
    final path = pathOf('${entry.path}/$name');
    final copy = File(p.join(_state.path, 'series', addressKey(path)));
    try {
      final text = await transport.text(path);
      await _write(copy, text);
      return text;
    } on TransportNotFound {
      await copy.delete().catchError((_) => copy);
      return null;
    } on TransportException {
      if (await copy.exists()) return copy.readAsString();
      rethrow;
    }
  }

  @override
  Future<SeriesIndex?> loadSeries(SeriesEntry entry) async {
    final text = await seriesText(entry, seriesIndexFile);
    return text == null ? null : compute(_parseSeries, text);
  }

  @override
  Future<PagesIndex?> loadPages(SeriesEntry entry) async {
    final text = await seriesText(entry, pagesIndexFile);
    return text == null ? null : compute(_parsePages, text);
  }

  @override
  Future<Map<String, Object?>?> loadSeriesManifest(SeriesEntry entry) async {
    final text = await seriesText(entry, 'series.json');
    if (text == null) return null;
    final data = jsonDecode(text);
    final metadata = data is Map<String, Object?> ? data['metadata'] : null;
    return metadata is Map<String, Object?> ? metadata : null;
  }

  @override
  String locate(SeriesEntry entry, String relative) =>
      sourceAddress(sourceId, '${entry.path}/$relative');

  /// In sola lettura l'app non toglie niente, quindi niente è tolto solo
  /// sulla carta.
  @override
  Future<Set<String>> withdrawnChapters(SeriesEntry entry) async => const {};
}

/// Le tavole di una sorgente per percorsi portate sul telefono quando
/// servono, nella cache comune delle tavole con chiavi che cominciano per
/// l'id della sorgente.
///
/// Urgenti (la tavola sullo schermo) davanti ai precarichi, fino a [atOnce]
/// insieme; un download interrotto lascia il suo `.part`, e il prossimo
/// riprende da lì con `Range`.
class PathFiles implements RemoteFiles {
  PathFiles(this.shelf, this.cache, {this.atOnce = 4});

  final PathShelf shelf;
  final DriveFileCache cache;
  final int atOnce;

  final Map<String, _Fetch> _pending = {};
  final Queue<_Fetch> _urgent = Queue();
  List<_Fetch> _prefetch = [];
  int _running = 0;

  String get _prefix => sourceAddress(shelf.sourceId, '');

  String _relative(String address) {
    if (!address.startsWith(_prefix)) {
      throw ArgumentError.value(address, 'address', 'non è di ${shelf.sourceId}');
    }
    return address.substring(_prefix.length);
  }

  String keyOf(String address) =>
      '${shelf.sourceId}-${addressKey(_relative(address))}';

  @override
  String? peek(String address) => cache.peek(keyOf(address));

  @override
  Future<String> fetch(String address, {bool urgent = false}) {
    final ready = peek(address);
    if (ready != null) return Future.value(ready);
    final pending = _pending[address];
    if (pending != null) {
      if (urgent && !pending.urgent && _prefetch.remove(pending)) {
        pending.urgent = true;
        _urgent.addFirst(pending);
        _pump();
      }
      return pending.done.future;
    }
    final fetch = _Fetch(address)..urgent = urgent;
    _pending[address] = fetch;
    urgent ? _urgent.addFirst(fetch) : _prefetch.add(fetch);
    _pump();
    return fetch.done.future;
  }

  /// Un precarico nuovo sostituisce quello vecchio, come per Drive.
  @override
  void warm(Iterable<String> addresses) {
    final wanted = [
      for (final address in addresses)
        if (peek(address) == null) address,
    ];
    final keep = wanted.toSet();
    for (final stale in _prefetch.where((f) => !keep.contains(f.address))) {
      _pending.remove(stale.address);
      stale.done.future.ignore();
      stale.done.completeError(const TransportException('Precarico annullato'));
    }
    final queued = {for (final fetch in _prefetch) fetch.address: fetch};
    _prefetch = [
      for (final address in wanted)
        if (queued[address] case final fetch?)
          fetch
        else if (!_pending.containsKey(address))
          _enqueue(address),
    ];
    _pump();
  }

  _Fetch _enqueue(String address) {
    final fetch = _Fetch(address);
    _pending[address] = fetch;
    fetch.done.future.ignore();
    return fetch;
  }

  /// Il rango dei capitoli aperti è di `DriveFiles`, che tiene la cache: qui
  /// le tavole contano solo per l'ultimo uso.
  @override
  void rememberChapter(String series, String chapter, List<String> addresses) {}

  void _pump() {
    while (_running < atOnce) {
      final _Fetch fetch;
      if (_urgent.isNotEmpty) {
        fetch = _urgent.removeFirst();
      } else if (_prefetch.isNotEmpty) {
        fetch = _prefetch.removeAt(0);
      } else {
        return;
      }
      _running++;
      unawaited(_run(fetch));
    }
  }

  Future<void> _run(_Fetch fetch) async {
    try {
      final path = await _download(fetch.address);
      if (!fetch.done.isCompleted) fetch.done.complete(path);
    } on Object catch (error, stack) {
      if (!fetch.done.isCompleted) fetch.done.completeError(error, stack);
    } finally {
      _pending.remove(fetch.address);
      _running--;
      _pump();
    }
  }

  Future<String> _download(String address) => cache.store(
        keyOf(address),
        (target) async {
          final from = await target.exists() ? await target.length() : 0;
          await shelf.transport.download(
            shelf.pathOf(_relative(address)),
            target,
            resumeFrom: from,
          );
        },
      );
}

class _Fetch {
  _Fetch(this.address);

  final String address;
  final Completer<String> done = Completer();
  bool urgent = false;
}
