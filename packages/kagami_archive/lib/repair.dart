/// La riparazione delle serie archiviate: si rilegge ogni serie dal suo
/// `source` col provider di adesso e si riscrive ciò che il sito ha cambiato,
/// adottando un cambio d'identità (regole in `docs/malf.md`, «Cambi
/// d'identità e riparazione»). Vale per ogni [ArchiveStore], quindi per il
/// telefono e per il server.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'archiver.dart';
import 'drive.dart';
import 'health.dart';
import 'http.dart';
import 'image_tools.dart';
import 'indexes.dart';
import 'jobs.dart';
import 'manual.dart';
import 'model.dart';
import 'names.dart';
import 'providers.dart';
import 'stores.dart';
import 'tracking.dart';

/// Gli id di [old] tradotti in quelli di [fresh], abbinati per numero di
/// capitolo («1.50» è l'1.5) e, per i capitoli senza numero («Prologue»),
/// per nome. Un capitolo che il sito nuovo non ha resta fuori; se il sito
/// nuovo ripete un numero, vale il primo.
Map<String, String> matchChapters(
  Iterable<({String id, String? number, String? title})> old,
  Iterable<Chapter> fresh,
) {
  final byKey = <String, String>{};
  for (final chapter in fresh) {
    final key = _chapterKey(chapter.number, chapter.title);
    if (key.isNotEmpty) byKey.putIfAbsent(key, () => chapter.id);
  }
  return {
    for (final chapter in old) chapter.id: ?byKey[_chapterKey(chapter.number, chapter.title)],
  };
}

String _chapterKey(String? number, String? title) {
  for (final candidate in [number, chapterNumber(title ?? '')]) {
    final value = double.tryParse(candidate?.trim().replaceAll(',', '.') ?? '');
    if (value != null) return '#$value';
  }
  return (title ?? number ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Cosa ha cambiato la riparazione di una serie.
class RepairOutcome {
  RepairOutcome(this.key, this.title);

  /// La chiave della serie dopo la riparazione.
  String key;
  String title;

  /// La chiave di prima, se la serie ne ha adottata una nuova.
  String? adoptedFrom;
  bool titleChanged = false;
  bool coverChanged = false;

  /// `series.json` è cambiato: metadati, stato, elenco o ordine dei capitoli.
  bool seriesChanged = false;

  /// Capitoli che il sito elenca e l'archivio non aveva.
  final List<String> added = [];

  /// Capitoli archiviati che il sito non elenca più: restano, `listed: false`.
  final List<String> unlisted = [];

  /// Id vecchio → nuovo dei capitoli adottati.
  final Map<String, String> renamed = {};

  /// Capitoli archiviati a metà, da rimettere in coda (id di adesso).
  final List<String> incomplete = [];

  /// Ciò che non è riuscito senza fermare la serie (la copertina).
  final List<String> problems = [];

  /// Perché la serie non si è potuta riparare; niente è stato scritto, o
  /// solo la parte da cui una ripetizione riprende.
  String? error;

  /// Se la riparazione ha scritto qualcosa.
  bool written = false;

  /// L'esito per la storia dei lavori: è riuscito se non c'è [error].
  ArchiveOutcome toArchiveOutcome({String? url}) => ArchiveOutcome(
        title: title,
        ok: error == null,
        message: error ?? (changed ? 'Serie riparata.' : 'Niente da riparare.'),
        finishedAt: DateTime.now(),
        seriesKey: key,
        url: url,
        repair: toJson(),
      );

  bool get changed =>
      adoptedFrom != null || titleChanged || coverChanged || seriesChanged || renamed.isNotEmpty || written;

  Map<String, Object?> toJson() => {
        'key': key,
        'title': title,
        'adoptedFrom': ?adoptedFrom,
        if (titleChanged) 'titleChanged': true,
        if (coverChanged) 'coverChanged': true,
        if (seriesChanged) 'seriesChanged': true,
        if (added.isNotEmpty) 'added': added,
        if (unlisted.isNotEmpty) 'unlisted': unlisted,
        if (renamed.isNotEmpty) 'renamed': renamed,
        if (incomplete.isNotEmpty) 'incomplete': incomplete,
        if (problems.isNotEmpty) 'problems': problems,
        'error': ?error,
        if (written) 'written': true,
      };
}

Map<String, Object?> _withoutFetchedAt(Map<String, Object?> manifest) =>
    {for (final entry in manifest.entries) if (entry.key != 'fetchedAt') entry.key: entry.value};

const _equality = DeepCollectionEquality();

/// Ripara la serie della riga di libreria [row] (`key`, `path`, `source`).
///
/// Un errore di lettura — sito, Drive, `series.json` che manca — esce come
/// eccezione prima di qualunque scrittura sulla serie; a [repairLibrary]
/// tocca non lasciare che fermi le altre.
Future<({RepairOutcome outcome, Series series})> repairSeries({
  required ArchiveStore store,
  required Map<String, Object?> row,
  required Provider provider,
  required ProviderHttp http,
  required Directory scratch,
  ImageTools images = const NoImageTools(),
  PageBrowser? browser,
  Duration delay = const Duration(milliseconds: 200),
}) async {
  final source = row['source'] as String;
  final (:series, page: _) = await readSeries(provider, source, http, browser: browser);
  var folder = row['path'] as String;
  var old = await store.readJson(p.posix.join(folder, seriesManifestFile));
  if (old == null) {
    // Una riparazione interrotta dopo la rinomina della cartella: la riga ha
    // ancora il percorso di prima.
    final moved = await store.existingFolder(series);
    if (moved != null) {
      folder = moved;
      old = await store.readJson(p.posix.join(folder, seriesManifestFile));
    }
  }
  if (old == null) throw FileSystemException('Manca il series.json', folder);
  final outcome = RepairOutcome(series.key, series.title);
  final oldKey = '${old['provider']}:${old['id']}';
  if (oldKey != series.key) outcome.adoptedFrom = oldKey;
  outcome.titleChanged = old['title'] != series.title;

  // La cartella della serie per prima: se il nome nuovo è preso la serie non
  // si tocca, e una ripresa la ritrova dal suffisso.
  final suffix = '${safeName(series.provider, limit: 20)}-${safeName(series.id, limit: 30)}';
  if (folderSuffix(folder) != suffix) {
    final name = seriesFolderName(series);
    await store.renameFolder(folder, name);
    folder = name;
    outcome.written = true;
  }

  final oldEntries = [
    for (final entry in (old['chapters'] as List? ?? const []).whereType<Map<String, Object?>>())
      if (entry['id'] case final String id when id.isNotEmpty) (id: id, entry: entry),
  ];
  final renamed = _pair(oldEntries, series.chapters, provider);
  final archived = await store.archivedChapters(folder, old);
  final byId = {for (final chapter in series.chapters) chapter.id: chapter};
  final keep = <String>{};
  for (final (:id, entry: _) in oldEntries) {
    final now = renamed[id];
    if (now == null) {
      if (archived.containsKey(id) && !byId.containsKey(id)) keep.add(id);
      continue;
    }
    if (now != id) outcome.renamed[id] = now;
    final stored = archived[id] ?? archived[now];
    if (stored == null) continue;
    final chapter = byId[now]!;
    var path = p.posix.join(folder, stored.path);
    final manifest = await store.readJson(p.posix.join(path, chapterManifestFile));
    if (manifest != null &&
        (manifest['id'] != chapter.id ||
            manifest['number'] != chapter.number ||
            manifest['title'] != chapter.title ||
            manifest['source'] != chapter.url)) {
      await store.writeChapterManifest(path, {
        ...manifest,
        'id': chapter.id,
        'number': chapter.number,
        'title': chapter.title,
        'source': chapter.url,
      });
      outcome.written = true;
    }
    final name = chapterFolderName(chapter);
    if (p.posix.basename(path) != name) {
      await store.renameFolder(path, name);
      path = p.posix.join(p.posix.dirname(path), name);
      outcome.written = true;
    }
  }
  final known = {for (final (:id, entry: _) in oldEntries) renamed[id] ?? id};
  outcome.added.addAll([for (final chapter in series.chapters) if (!known.contains(chapter.id)) chapter.id]);
  outcome.unlisted.addAll([
    for (final (:id, :entry) in oldEntries)
      if (keep.contains(id) && entry['listed'] != false) id,
  ]);

  final archiver = Archiver(provider: provider, http: http, store: store, scratch: scratch, images: images, delay: delay);
  final (:cover, :files, :failure) = await archiver.coverOf(series, folder, old);
  if (failure != null) outcome.problems.add('${failure.chapter}: ${failure.error}');
  outcome.coverChanged = files.isNotEmpty && failure == null;
  var manifest = seriesManifest(
    series,
    normalizeMetadata(series.metadata),
    failure == null ? cover : old['cover'] as Map<String, Object?>?,
    chapterEntries(series.chapters, old['chapters'], renamed: renamed, keep: keep),
    formerKeys: [
      ...?(old['formerKeys'] as List?)?.whereType<String>(),
      ?outcome.adoptedFrom,
    ],
  );
  outcome.seriesChanged = !_equality.equals(_withoutFetchedAt(manifest), _withoutFetchedAt(old));
  if (outcome.seriesChanged || files.isNotEmpty) {
    files[seriesManifestFile] = utf8.encode(prettyJson(manifest));
    await store.writeSeriesFiles(folder, files);
    outcome.written = true;
  } else {
    manifest = old;
  }

  final now = await store.archivedChapters(folder, manifest);
  outcome.incomplete.addAll([
    for (final MapEntry(key: id, value: stored) in now.entries)
      if (byId.containsKey(id) && (!stored.complete || stored.pages.isEmpty)) id,
  ]);
  final built = buildSeriesIndex(manifest, now);
  if (built == null) return (outcome: outcome, series: series);
  final indexChanged = !_equality.equals(built.index, await store.readJson(p.posix.join(folder, seriesIndexName))) ||
      !_equality.equals(built.pages, await store.readJson(p.posix.join(folder, pagesIndexName)));
  if (indexChanged) {
    await store.writeSeriesFiles(folder, {
      seriesIndexName: Uint8List.fromList(utf8.encode(prettyJson(built.index))),
      pagesIndexName: Uint8List.fromList(utf8.encode(prettyJson(built.pages))),
    });
  }
  if (indexChanged || row['key'] != series.key || row['path'] != folder) {
    await store.writeLibraryRow(summarize(folder, manifest, built.index));
    outcome.written = true;
  }
  return (outcome: outcome, series: series);
}

/// Gli id dei capitoli di prima tradotti in quelli del sito: lo stesso id,
/// poi lo stesso link, poi numero o titolo. Ogni capitolo del sito ne prende
/// al più uno, il primo.
Map<String, String> _pair(
  List<({String id, Map<String, Object?> entry})> old,
  List<Chapter> site,
  Provider provider,
) {
  final result = <String, String>{};
  final taken = <String>{};
  final ids = {for (final chapter in site) chapter.id};
  for (final (:id, entry: _) in old) {
    if (ids.contains(id) && taken.add(id)) result[id] = id;
  }
  String? linkOf(Object? url) {
    if (url is! String || url.isEmpty) return null;
    try {
      return provider.chapterKeyOf(url);
    } on FormatException {
      return null;
    }
  }

  final byLink = <String, String>{};
  for (final chapter in site) {
    final link = linkOf(chapter.url);
    if (link != null) byLink.putIfAbsent(link, () => chapter.id);
  }
  for (final (:id, :entry) in old) {
    if (result.containsKey(id)) continue;
    final match = byLink[linkOf(entry['source'])];
    if (match != null && taken.add(match)) result[id] = match;
  }
  final rest = [
    for (final (:id, :entry) in old)
      if (!result.containsKey(id))
        (id: id, number: entry['number'] as String?, title: entry['title'] as String?),
  ];
  final free = [for (final chapter in site) if (!taken.contains(chapter.id)) chapter];
  for (final MapEntry(key: id, value: match) in matchChapters(rest, free).entries) {
    if (taken.add(match)) result[id] = match;
  }
  return result;
}

/// Le righe della libreria: `library.json` e, per le serie del telefono,
/// `reading/downloads.json`. Una chiave sola volta, e non quelle che un'altra
/// riga ha adottato: sul telefono la riga vecchia di `library.json` resta
/// finché non la riscrive chi l'ha scritta.
Future<List<Map<String, Object?>>> libraryRows(ArchiveStore store) async {
  final seen = <Object?>{};
  final rows = [
    for (final file in [libraryFile, p.posix.join(readingFolder, downloadsName)])
      for (final row in ((await store.readJson(file))?['series'] as List? ?? const []).whereType<Map<String, Object?>>())
        if (seen.add(row['key'])) row,
  ];
  final adopted = {for (final row in rows) ...(row['formerKeys'] as List? ?? const [])};
  return [for (final row in rows) if (!adopted.contains(row['key'])) row];
}

/// Ripara le serie della libreria in [store]: tutte, quelle con le chiavi in
/// [only] o quelle del sito [site]. Come [Tracking.check], l'errore di una
/// serie non ferma le altre; solo la rete che manca ferma tutto. Un sito che
/// risponde si segna sano in [health]. La serie seguita in [tracking] prende
/// la chiave adottata e perde il suo problema; i capitoli a metà vanno in
/// coda in [files], verso [target], se ci sono tutti e due.
Future<List<RepairOutcome>> repairLibrary({
  required ArchiveStore store,
  required ProviderHttp Function(Provider provider) httpFor,
  required Directory scratch,
  ImageTools images = const NoImageTools(),
  PageBrowser? browser,
  HealthLog? health,
  Tracking? tracking,
  ArchiveFiles? files,
  ArchiveTarget? target,
  Set<String>? only,
  String? site,
  bool Function()? cancelled,
  void Function(int done, int total, String title)? progress,
  Future<void> Function(RepairOutcome outcome)? onOutcome,
  Duration delay = const Duration(milliseconds: 200),
  Duration pause = const Duration(seconds: 1),
}) async {
  final outcomes = <RepairOutcome>[];
  // Ogni esito esce appena c'è: se la rete cade a metà, quelli già fatti
  // restano nella storia anche se l'eccezione salta il ritorno.
  Future<void> record(RepairOutcome outcome) async {
    outcomes.add(outcome);
    await onOutcome?.call(outcome);
  }
  final watch = health == null ? null : SiteWatch(health);
  final todo = <({Map<String, Object?> row, String key, Provider provider})>[];
  for (final row in await libraryRows(store)) {
    final key = row['key'];
    final url = row['source'];
    if (key is! String || row['path'] is! String || url is! String) continue;
    if (row['provider'] == manualProvider) continue;
    if (only != null && !only.contains(key)) continue;
    final Provider provider;
    try {
      provider = selectProvider(url);
    } on ProviderError {
      continue;
    }
    if (site != null && provider.id != site) continue;
    if (provider.needsBrowser && browser == null) continue;
    todo.add((row: row, key: key, provider: provider));
  }
  try {
    for (final (index, (:row, :key, :provider)) in todo.indexed) {
      if (cancelled?.call() ?? false) break;
      if (index > 0 && pause > Duration.zero) await Future<void>.delayed(pause);
      progress?.call(index, todo.length, row['title'] as String? ?? key);
      try {
        final (:outcome, :series) = await repairSeries(
          store: store,
          row: row,
          provider: provider,
          http: httpFor(provider),
          scratch: scratch,
          images: images,
          browser: browser,
          delay: delay,
        );
        await watch?.succeeded(provider.id);
        await tracking?.adopt(key, series, outcome.renamed);
        if (files != null && target != null && outcome.incomplete.isNotEmpty) {
          await files.enqueue(ArchiveJob(
            id: 'repair-${series.key}-${DateTime.now().millisecondsSinceEpoch}',
            url: series.url,
            title: series.title,
            target: target,
            ids: outcome.incomplete.toSet(),
            automatic: true,
          ));
        }
        await record(outcome);
      } on ProviderOffline {
        rethrow;
      } on DriveOffline {
        rethrow;
      } on DriveAuthRequired {
        rethrow;
      } on ProviderError catch (error) {
        await watch?.failed(provider.id, error);
        await record(RepairOutcome(key, row['title'] as String? ?? key)..error = '$error');
      } on DriveException catch (error) {
        await record(RepairOutcome(key, row['title'] as String? ?? key)..error = '$error');
      } on FolderConflict catch (error) {
        await record(RepairOutcome(key, row['title'] as String? ?? key)..error = '$error');
      } on FileSystemException catch (error) {
        await record(RepairOutcome(key, row['title'] as String? ?? key)..error = error.message);
      }
    }
  } finally {
    await watch?.finish();
  }
  return outcomes;
}

/// Adotta la copia di una serie — la cartella dei download sul telefono,
/// [store] — già riparata altrove: [fresh] è il `series.json` riparato di
/// Drive, con i `formerKeys` e i `formerIds` che dicono cosa è cambiato.
/// [path] è la cartella della serie com'era, o com'è dopo una ripresa.
///
/// Fa ciò che [repairSeries] fa sui file, senza sito e senza rete: rinomina la
/// cartella della serie e quelle dei capitoli, riscrive nel `chapter.json`
/// id, numero, titolo e link, e rifà `series.json`, indici e riga. Le tavole
/// non si toccano, niente si cancella, la copertina resta quella della copia.
/// Una seconda chiamata non scrive niente; una interrotta riprende dai nomi
/// già cambiati.
Future<RepairOutcome> adoptCopy({
  required ArchiveStore store,
  required String path,
  required Map<String, Object?> fresh,
}) async {
  final series = Series(
    provider: fresh['provider'] as String,
    id: fresh['id'] as String,
    title: fresh['title'] as String? ?? '',
    url: fresh['source'] as String? ?? '',
    coverUrl: null,
    metadata: const {},
    chapters: const [],
  );
  final outcome = RepairOutcome(series.key, series.title);
  var folder = path;
  var old = await store.readJson(p.posix.join(folder, seriesManifestFile));
  if (old == null) {
    final moved = p.posix.join(p.posix.dirname(path) == '.' ? '' : p.posix.dirname(path), seriesFolderName(series));
    old = await store.readJson(p.posix.join(moved, seriesManifestFile));
    if (old != null) folder = moved;
  }
  if (old == null) throw FileSystemException('Manca il series.json', folder);
  outcome.adoptedFrom = '${old['provider']}:${old['id']}' == series.key ? null : '${old['provider']}:${old['id']}';

  final suffix = '${safeName(series.provider, limit: 20)}-${safeName(series.id, limit: 30)}';
  if (folderSuffix(folder) != suffix) {
    final name = seriesFolderName(series);
    await store.renameFolder(folder, name);
    folder = p.posix.join(p.posix.dirname(folder) == '.' ? '' : p.posix.dirname(folder), name);
    outcome.written = true;
  }

  final entries = [
    for (final entry in (fresh['chapters'] as List? ?? const []).whereType<Map<String, Object?>>())
      if (entry['id'] case final String id when id.isNotEmpty) (id: id, entry: entry),
  ];
  final archived = await store.archivedChapters(folder, fresh);
  for (final (:id, :entry) in entries) {
    final formerIds = (entry['formerIds'] as List? ?? const []).whereType<String>();
    final found = archived[id] != null ? id : formerIds.firstWhereOrNull(archived.containsKey);
    if (found == null) continue;
    if (found != id) outcome.renamed[found] = id;
    final chapter = Chapter(id, entry['title'] as String? ?? '', entry['number'] as String? ?? '', entry['source'] as String? ?? '');
    var chapterPath = p.posix.join(folder, archived[found]!.path);
    final manifest = await store.readJson(p.posix.join(chapterPath, chapterManifestFile));
    if (manifest != null &&
        (manifest['id'] != chapter.id ||
            manifest['number'] != chapter.number ||
            manifest['title'] != chapter.title ||
            manifest['source'] != chapter.url)) {
      await store.writeChapterManifest(chapterPath, {
        ...manifest,
        'id': chapter.id,
        'number': chapter.number,
        'title': chapter.title,
        'source': chapter.url,
      });
      outcome.written = true;
    }
    final name = chapterFolderName(chapter);
    if (p.posix.basename(chapterPath) != name) {
      await store.renameFolder(chapterPath, name);
      outcome.written = true;
    }
  }

  var manifest = {...fresh, if (old['cover'] != null) 'cover': old['cover']};
  if (!_equality.equals(manifest, old)) {
    await store.writeSeriesFiles(folder, {seriesManifestFile: utf8.encode(prettyJson(manifest))});
    outcome.seriesChanged = true;
    outcome.written = true;
  } else {
    manifest = old;
  }

  final now = await store.archivedChapters(folder, manifest);
  final built = buildSeriesIndex(manifest, now);
  if (built == null) return outcome;
  final indexChanged = !_equality.equals(built.index, await store.readJson(p.posix.join(folder, seriesIndexName))) ||
      !_equality.equals(built.pages, await store.readJson(p.posix.join(folder, pagesIndexName)));
  if (indexChanged) {
    await store.writeSeriesFiles(folder, {
      seriesIndexName: Uint8List.fromList(utf8.encode(prettyJson(built.index))),
      pagesIndexName: Uint8List.fromList(utf8.encode(prettyJson(built.pages))),
    });
  }
  final rows = await libraryRows(store);
  final listed = rows.any((row) => row['key'] == series.key && row['path'] == folder);
  if (indexChanged || !listed) {
    await store.writeLibraryRow(summarize(folder, manifest, built.index));
    outcome.written = true;
  }
  return outcome;
}
