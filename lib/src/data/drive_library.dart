/// La libreria MALF su Google Drive.
///
/// È la stessa cartella che FolderSync porterebbe sul telefono, letta senza
/// portarla sul telefono. Gli indici sono gli stessi e si leggono con gli
/// stessi modelli; cambia il prezzo di ogni file, che qui è una richiesta di
/// rete. Tutto quello che sta in questo file serve a pagarlo una volta sola:
///
/// * all'apertura bastano due richieste — l'elenco della cartella radice e
///   **una ricerca sola** che trova, in tutte le serie insieme, indici e
///   miniature. Elencare ottanta cartelle una per una sarebbe ottanta
///   richieste prima di poter disegnare la griglia;
/// * i testi si tengono su disco col nome della loro impronta: se
///   `library.json` non è cambiato non lo si riscarica, e senza rete la
///   libreria si apre com'era l'ultima volta;
/// * gli elenchi delle cartelle dei capitoli si tengono su disco anch'essi,
///   e si rifanno solo quando manca qualcosa che dovrebbe esserci;
/// * le tavole finiscono in una cache con un tetto, e da lì il lettore le
///   legge come se fossero sempre state sul telefono — fasce, geometria e
///   ripresa non sanno la differenza.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../format/malf.dart';
import '../l10n.dart';
import 'drive.dart';
import 'library.dart';
import 'network.dart';

LibraryIndex _parseLibrary(String source) =>
    LibraryIndex.fromJson(jsonDecode(source) as Map<String, Object?>);

SeriesIndex _parseSeries(String source) =>
    SeriesIndex.fromJson(jsonDecode(source) as Map<String, Object?>);

PagesIndex _parsePages(String source) =>
    PagesIndex.fromJson(jsonDecode(source) as Map<String, Object?>);

Map<String, Object?> _decodeObject(String source) =>
    jsonDecode(source) as Map<String, Object?>;

Map<String, DriveItem> _decodeListing(String source) => {
      for (final row in jsonDecode(source) as List)
        (row as Map<String, Object?>)['name'] as String: DriveItem.fromJson(row),
    };

List<CachedChapter> _decodeChapters(String source) => [
      for (final row in jsonDecode(source) as List)
        CachedChapter.fromJson(row as Map<String, Object?>),
    ];

/// I file di ogni serie che la ricerca d'apertura va a prendere.
const Set<String> _seriesFiles = {
  seriesIndexFile,
  pagesIndexFile,
  'series.json',
  'cover.webp',
  'cover.thumb.webp',
};

/// Dopo quanto la libreria su Drive si rilegge da sola. Tornare nell'app dopo
/// cinque minuti non deve costare due richieste; tornarci il giorno dopo sì.
const Duration driveFreshness = Duration(minutes: 10);

class DriveRepository implements LibraryShelf {
  DriveRepository({
    required this.client,
    required this.folderId,
    required String stateDirectory,
    required this.files,
  }) : _state = Directory(p.join(stateDirectory, folderId));

  final DriveClient client;
  final String folderId;
  final DriveFileCache files;
  final Directory _state;

  /// La cartella radice: nome → voce. Ci sono `library.json` e una cartella
  /// per serie.
  Map<String, DriveItem> _root = const {};

  /// Per ogni cartella di serie, i suoi file principali.
  Map<String, Map<String, DriveItem>> _series = const {};

  LibraryIndex? _library;
  DateTime? _loadedAt;

  /// Gli elenchi delle cartelle più in basso: id → nome → voce.
  final Map<String, Map<String, DriveItem>> _listings = {};

  /// Gli elenchi chiesti a Drive e non ancora arrivati. Le tavole di un
  /// capitolo partono quattro alla volta, e senza questo la stessa cartella
  /// si elencherebbe quattro volte.
  final Map<String, Future<Map<String, DriveItem>>> _asking = {};

  /// Le cartelle elencate in rete in questa sessione: un nome che non c'è in
  /// un elenco vecchio si ricerca, in uno appena fatto no.
  final Set<String> _fresh = {};

  @override
  LibraryOrigin get origin => LibraryOrigin.drive;

  bool get stale =>
      _loadedAt == null || DateTime.now().difference(_loadedAt!) > driveFreshness;

  /// Fa rileggere la libreria alla prossima richiesta.
  void refresh() {
    _loadedAt = null;
    _fresh.clear();
  }

  File get _snapshot => File(p.join(_state.path, 'state.json'));

  Directory get _texts => Directory(p.join(_state.path, 'text'));

  /// Se la libreria che si sta mostrando è l'istantanea dell'ultima volta,
  /// perché la rete non c'era: tornata la rete, va riletta.
  bool fromSnapshot = false;

  /// Drive ha negato il permesso all'ultima lettura: l'istantanea non basta
  /// più, e la libreria deve dirlo invece di mostrarsi come se niente fosse.
  bool _needsAuth = false;

  @override
  Future<LibraryIndex> loadLibrary() async {
    final memo = _library;
    if (memo != null && !stale) return memo;
    if (memo == null && !_needsAuth) {
      // All'apertura si mostra la libreria dell'ultima volta, senza aspettare
      // la rete: le serie ci sono subito, le copertine arrivano dopo, e
      // [revalidate] rilegge Drive dietro alla griglia.
      final restored = await _restore();
      if (restored != null) {
        _library = restored;
        fromSnapshot = !client.network.isOnline;
        return restored;
      }
    }
    if (!client.network.isOnline) {
      // Senza rete non si aspetta un timeout per sapere quello che si sa già:
      // la libreria dell'ultima volta si apre subito.
      final restored = memo ?? await _restore();
      if (restored != null) {
        _library = restored;
        fromSnapshot = true;
        return restored;
      }
      throw DriveOffline(currentL10n().dataDriveOfflineNeverOpened);
    }
    return _fetching ??= _fetch(memo).whenComplete(() => _fetching = null);
  }

  /// La lettura dalla rete in corso: quella dietro alla griglia e quella di
  /// chi torna nell'app nello stesso momento diventano una.
  Future<LibraryIndex>? _fetching;

  Future<LibraryIndex> _fetch(LibraryIndex? memo) async {
    try {
      final root = await client.children(folderId);
      _root = {for (final item in root) item.name: item};
      final index = _root[libraryIndexFile];
      _series = await _findSeriesFiles(root);
      _thumbnails = null;
      // Senza `library.json` la cartella è una libreria ancora vuota: è da
      // lì che parte chi archivia dall'app, senza il server.
      final library = index == null || index.folder
          ? LibraryIndex.empty
          : await compute(_parseLibrary, await _text(index));
      _library = library;
      _loadedAt = DateTime.now();
      fromSnapshot = false;
      _needsAuth = false;
      // L'istantanea prima di rispondere: è ciò che apre la libreria senza
      // rete, e un'app chiusa subito dopo non deve perderla.
      await _save();
      _pruning = _prune();
      return library;
    } on DriveAuthRequired {
      _needsAuth = true;
      _library = null;
      rethrow;
    } on DriveException {
      // Senza rete la libreria c'è ancora: quella dell'ultima volta.
      final restored = memo ?? await _restore();
      if (restored == null) rethrow;
      _library = restored;
      fromSnapshot = true;
      return restored;
    }
  }

  Future<void> _pruning = Future.value();

  @visibleForTesting
  Future<void> get pruned => _pruning;

  /// Rilegge dalla rete la libreria aperta dall'istantanea. Dice se chi la
  /// mostra deve rifarla: se `library.json` è un altro, se la rete è mancata
  /// — c'è un avviso da dare — o se Drive chiede di nuovo il permesso.
  /// Altrimenti la griglia resta com'è e non si ricalcola niente.
  Future<bool> revalidate() async {
    if (_library == null || !stale || !client.network.isOnline) return false;
    final before = _root[libraryIndexFile]?.contentKey;
    final offline = fromSnapshot;
    try {
      await loadLibrary();
    } on DriveAuthRequired {
      return true;
    } on DriveException {
      return false;
    }
    return fromSnapshot != offline ||
        _root[libraryIndexFile]?.contentKey != before;
  }

  /// Indici e copertine di tutte le serie con una ricerca sola.
  Future<Map<String, Map<String, DriveItem>>> _findSeriesFiles(
    List<DriveItem> root,
  ) async {
    final folders = {
      for (final item in root)
        if (item.folder) item.id: item.name,
    };
    final names = _seriesFiles.map((name) => "name = '$name'").join(' or ');
    final found = await client.query('($names) and trashed = false',
        orderBy: 'modifiedTime desc');
    final series = <String, Map<String, DriveItem>>{};
    for (final item in found) {
      for (final parent in item.parents) {
        final folder = folders[parent];
        if (folder == null) continue;
        // In ordine dal più recente: con due copie dello stesso nome — rclone
        // può lasciarne — vale l'ultima scritta.
        series.putIfAbsent(folder, () => {}).putIfAbsent(item.name, () => item);
      }
    }
    return series;
  }

  /// Le letture in corso, per impronta. Il loro `.tmp` [_prune] non lo deve
  /// toccare, e due letture dello stesso indice — quella in sottofondo e
  /// quella della scheda — diventano una richiesta sola invece di due che
  /// scrivono lo stesso `.tmp`.
  final Map<String, Future<String>> _reading = {};

  static const String _temporary = '.tmp';

  Future<String> _text(DriveItem item) {
    final key = item.contentKey;
    return _reading[key] ??=
        // Il blocco non deve restituire ciò che rimuove: `whenComplete`
        // aspetterebbe quel futuro, che è sé stesso.
        _readText(item).whenComplete(() {
      _reading.remove(key);
    });
  }

  Future<String> _readText(DriveItem item) async {
    final file = File(p.join(_texts.path, item.contentKey));
    if (await file.exists()) return file.readAsString();
    final text = await client.text(item.id);
    await _texts.create(recursive: true);
    final temporary = File('${file.path}$_temporary');
    await temporary.writeAsString(text);
    await temporary.rename(file.path);
    return text;
  }

  Future<void> _save() async {
    await _state.create(recursive: true);
    await _snapshot.writeAsString(await compute(jsonEncode, {
      'root': [for (final item in _root.values) item.toJson()],
      'series': {
        for (final MapEntry(:key, :value) in _series.entries)
          key: [for (final item in value.values) item.toJson()],
      },
    }));
  }

  /// Le miniature delle copertine della libreria, come nomi di file della
  /// cache: la cache le tiene come si tiene il capitolo che si sta leggendo.
  Set<String> get thumbnailKeys => _thumbnails ??= {
        for (final files in _series.values)
          ?files['cover.thumb.webp']?.md5,
      };
  Set<String>? _thumbnails;

  /// Dopo quanto un elenco di cartella non più chiesto si butta. Rifarlo
  /// costa una richiesta; tenerli tutti vuol dire un file per ogni capitolo
  /// mai aperto, per sempre.
  static const Duration _listingRetention = Duration(days: 30);

  /// Dei testi resta solo la versione in uso: `library.json` cambia a ogni
  /// capitolo archiviato, e ogni versione vecchia sono centinaia di kilobyte.
  /// Degli elenchi delle cartelle, quelli rifatti nell'ultimo mese.
  Future<void> _prune() async {
    final keep = {
      ?_root[libraryIndexFile]?.contentKey,
      for (final files in _series.values)
        for (final item in files.values) item.contentKey,
    };
    if (await _texts.exists()) {
      await for (final entity in _texts.list()) {
        final name = p.basename(entity.path);
        if (keep.contains(name)) continue;
        // Parte senza essere atteso: una lettura può star scrivendo il suo
        // `.tmp` proprio adesso, e buttarlo le fa fallire il rename.
        if (name.endsWith(_temporary) &&
            _reading.containsKey(
                name.substring(0, name.length - _temporary.length))) {
          continue;
        }
        await entity.delete().catchError((_) => entity);
      }
    }
    final tree = Directory(p.join(_state.path, 'tree'));
    if (!await tree.exists()) return;
    final now = DateTime.now();
    await for (final entity in tree.list()) {
      if (entity is! File) continue;
      final modified = (await entity.stat()).modified;
      if (now.difference(modified) > _listingRetention) {
        _listings.remove(p.basenameWithoutExtension(entity.path));
        await entity.delete().catchError((_) => entity);
      }
    }
  }

  Future<LibraryIndex?> _restore() async {
    try {
      final json = await compute(_decodeObject, await _snapshot.readAsString());
      List<DriveItem> items(Object? rows) => [
            for (final row in rows as List? ?? const [])
              DriveItem.fromJson(row as Map<String, Object?>),
          ];
      _root = {for (final item in items(json['root'])) item.name: item};
      _series = {
        for (final MapEntry(:key, :value)
            in (json['series'] as Map? ?? const {}).cast<String, Object?>().entries)
          key: {for (final item in items(value)) item.name: item},
      };
      _thumbnails = null;
      final index = _root[libraryIndexFile];
      if (index == null) return null;
      final file = File(p.join(_texts.path, index.contentKey));
      if (!await file.exists()) return null;
      return await compute(_parseLibrary, await file.readAsString());
    } on Object {
      return null;
    }
  }

  /// Un file della serie: dalla ricerca d'apertura se l'ha trovato,
  /// altrimenti elencando la cartella della serie.
  Future<DriveItem?> _seriesFile(SeriesEntry entry, String name) async =>
      _series[entry.path]?[name] ?? await resolve('${entry.path}/$name');

  @override
  Future<SeriesIndex?> loadSeries(SeriesEntry entry) async {
    final item = await _seriesFile(entry, seriesIndexFile);
    if (item == null) return null;
    return compute(_parseSeries, await _text(item));
  }

  @override
  Future<PagesIndex?> loadPages(SeriesEntry entry) async {
    final item = await _seriesFile(entry, pagesIndexFile);
    if (item == null) return null;
    return compute(_parsePages, await _text(item));
  }

  @override
  Future<Map<String, Object?>?> loadSeriesManifest(SeriesEntry entry) async {
    final item = await _seriesFile(entry, 'series.json');
    if (item == null) return null;
    final data = jsonDecode(await _text(item));
    final metadata = data is Map<String, Object?> ? data['metadata'] : null;
    return metadata is Map<String, Object?> ? metadata : null;
  }

  /// Il testo di un file della serie così com'è su Drive: serve a chi
  /// scarica, che lo copia accanto ai capitoli.
  Future<String?> seriesText(SeriesEntry entry, String name) async {
    final item = await _seriesFile(entry, name);
    return item == null ? null : _text(item);
  }

  @override
  String locate(SeriesEntry entry, String relative) =>
      '$remotePrefix${entry.path}/$relative';

  /// Da un percorso relativo alla radice alla voce di Drive.
  Future<DriveItem?> resolve(String relative) async {
    final segments = p.posix.split(p.posix.normalize(relative));
    if (segments.isEmpty) return null;
    var item = _root[segments.first];
    if (segments.length == 2) {
      final known = _series[segments.first]?[segments.last];
      if (known != null) return known;
    }
    for (final name in segments.skip(1)) {
      if (item == null || !item.folder) return null;
      item = await _child(item.id, name);
    }
    return item;
  }

  Future<DriveItem?> _child(String folderId, String name) async {
    final known = (await _listing(folderId))[name];
    if (known != null || _fresh.contains(folderId)) return known;
    // Il nome non c'è in un elenco vecchio: la cartella può essere cambiata
    // dopo — un capitolo arrivato ieri. Si rielenca, una volta.
    return (await _listing(folderId, fresh: true))[name];
  }

  Future<Map<String, DriveItem>> _listing(
    String folderId, {
    bool fresh = false,
  }) async {
    final file = File(p.join(_state.path, 'tree', '$folderId.json'));
    if (!fresh) {
      final memo = _listings[folderId];
      if (memo != null) return memo;
      try {
        return _listings[folderId] =
            await compute(_decodeListing, await file.readAsString());
      } on Object {
        // Nessun elenco da parte, o illeggibile: lo si chiede a Drive.
      }
    }
    // Il blocco e non la freccia: `remove` restituisce proprio questo
    // `Future`, e `whenComplete` aspetterebbe sé stesso per sempre.
    return _asking[folderId] ??= _ask(folderId, file).whenComplete(() {
      _asking.remove(folderId);
    });
  }

  Future<Map<String, DriveItem>> _ask(String folderId, File file) async {
    final items = await client.children(folderId);
    _fresh.add(folderId);
    final listing = {for (final item in items) item.name: item};
    _listings[folderId] = listing;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode([for (final item in items) item.toJson()]),
    );
    return listing;
  }

  // ------------------------------------------------ capitoli tolti da Drive

  /// I capitoli tolti da Drive da «Libera spazio», per cartella di serie.
  ///
  /// `index.json` lo scrive il server e l'app non lo riscrive: finché il
  /// server non lo rifà, i capitoli tolti restano elencati, e senza questo
  /// il lettore proverebbe a leggerli da lì. Sta su disco perché il server
  /// può metterci giorni.
  Map<String, Set<String>>? _withdrawn;

  File get _withdrawnFile => File(p.join(_state.path, 'withdrawn.json'));

  Future<Map<String, Set<String>>> _loadWithdrawn() async {
    final memo = _withdrawn;
    if (memo != null) return memo;
    final result = <String, Set<String>>{};
    try {
      final json = jsonDecode(await _withdrawnFile.readAsString());
      if (json is Map) {
        for (final MapEntry(:key, :value) in json.entries) {
          if (key is String && value is List) {
            result[key] = value.whereType<String>().toSet();
          }
        }
      }
    } on Object {
      // Niente tolto ancora, o un file rovinato: al peggio si vede come
      // leggibile da Drive un capitolo che non c'è, e lo si dice aprendolo.
    }
    return _withdrawn = result;
  }

  Future<void> _saveWithdrawn() async {
    final rows = {
      for (final MapEntry(:key, :value) in (await _loadWithdrawn()).entries)
        if (value.isNotEmpty) key: value.toList(),
    };
    await _withdrawnFile.parent.create(recursive: true);
    final temporary = File('${_withdrawnFile.path}.tmp');
    await temporary.writeAsString(jsonEncode(rows));
    await temporary.rename(_withdrawnFile.path);
  }

  /// I capitoli tolti di una serie. Se il server li ha rimessi — rclone li
  /// ricopia dall'archivio, che li ha ancora — la cartella dei capitoli li
  /// mostra di nuovo, e tornano a leggersi da qui: per saperlo si elenca
  /// quella cartella una volta per sessione, e solo per le serie da cui si
  /// è tolto qualcosa.
  @override
  Future<Set<String>> withdrawnChapters(SeriesEntry entry) async {
    final marks = (await _loadWithdrawn())[entry.path];
    if (marks == null || marks.isEmpty) return const {};
    try {
      final folder = await resolve('${entry.path}/chapters');
      if (folder != null && folder.folder) {
        final listing = await _listing(
          folder.id,
          fresh: !_fresh.contains(folder.id),
        );
        final back = {
          for (final path in marks)
            if (listing.containsKey(p.posix.basename(path))) path,
        };
        if (back.isNotEmpty) {
          marks.removeAll(back);
          await _saveWithdrawn();
        }
      }
    } on DriveException {
      // Senza rete valgono i segni che si hanno.
    }
    return {...marks};
  }

  /// Sposta nel cestino di Drive le cartelle di questi capitoli (percorsi
  /// come in [ChapterEntry.path]) con [writer], che ha il permesso di
  /// scrivere. Ognuno si segna appena tolto: se la rete cade a metà, quelli
  /// già nel cestino non devono sembrare ancora leggibili.
  Future<void> withdrawChapters(
    SeriesEntry entry,
    Iterable<String> paths,
    DriveClient writer,
  ) async {
    final marks = (await _loadWithdrawn()).putIfAbsent(entry.path, () => {});
    for (final path in paths.map(p.posix.normalize)) {
      final item = await resolve('${entry.path}/$path');
      if (item != null) {
        await writer.trash(item.id);
        await _forgetItem(item);
      }
      marks.add(path);
      await _saveWithdrawn();
    }
  }

  /// Toglie una voce dagli elenchi tenuti da parte, in memoria e su disco.
  Future<void> _forgetItem(DriveItem item) async {
    for (final MapEntry(key: folderId, value: listing) in _listings.entries) {
      if (listing[item.name]?.id != item.id) continue;
      listing.remove(item.name);
      final file = File(p.join(_state.path, 'tree', '$folderId.json'));
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([for (final row in listing.values) row.toJson()]),
      );
    }
  }

  /// Il nome in cache di un file, senza rete. Delle copertine si usa
  /// l'impronta — cambiano, e il percorso resta lo stesso — delle tavole il
  /// percorso: sta in una cartella che porta l'id del capitolo e non cambia.
  String cacheKeyOf(String relative) {
    final segments = p.posix.split(relative);
    if (segments.length == 2) {
      final known = _series[segments.first]?[segments.last];
      if (known?.md5 != null) return known!.md5!;
    }
    return addressKey(relative);
  }
}

/// Le tavole di Drive portate sul telefono quando servono.
///
/// Due file d'attesa, perché due sono i bisogni:
///
/// * **urgenti** — la tavola sullo schermo, una copertina nella griglia.
///   Partono sempre, fino a quattro insieme, e l'ultima chiesta per prima:
///   scorrendo, è quella sotto gli occhi;
/// * **precarichi** — il resto del capitolo, nell'ordine in cui lo si leggerà
///   da dove si è arrivati. Partono solo se nessuna urgente aspetta, e mai
///   tutti insieme: su una rete lenta quattro download in parallelo
///   dividerebbero la banda in quattro, e la tavola che serve adesso
///   arriverebbe per ultima. Quanti ne partono lo decide la velocità misurata
///   sulle tavole appena scese.
///
/// Senza rete niente parte e chi chiede riceve subito [DriveOffline]: la
/// tavola mostra l'avviso invece di un cerchio che gira. Quando la rete torna
/// il precarico riprende da solo; le tavole sullo schermo le riprova il
/// magazzino delle fasce, che sa quali sono.
class DriveFiles implements RemoteFiles {
  DriveFiles(this.repository) {
    network.online.addListener(_onNetwork);
    cache.rank = _rankOf;
  }

  final DriveRepository repository;

  DriveFileCache get cache => repository.files;

  // Nell'app ogni client di Drive nasce col monitor del telefono: il
  // pacchetto lo conosce solo come `NetworkState`, le tavole ne ascoltano
  // anche i cambiamenti.
  NetworkMonitor get network => repository.client.network as NetworkMonitor;

  static const int _atOnce = 4;

  /// Tentativi di una tavola prima di dichiararla non arrivata, finché la
  /// sonda dice che la rete c'è: una connessione a scatti ne perde qualcuna
  /// per strada, e non è un motivo per mostrare un avviso.
  static const int _attempts = 3;

  final Map<String, _Fetch> _pending = {};
  final Queue<_Fetch> _urgent = Queue();
  List<_Fetch> _prefetch = [];
  int _running = 0;
  int _runningPrefetch = 0;

  /// L'ultimo precarico chiesto: tornata la rete, si riparte da lì.
  List<String> _wanted = const [];

  /// Byte al secondo di un singolo download, media mobile.
  double? _rate;

  void dispose() {
    network.online.removeListener(_onNetwork);
    if (cache.rank == _rankOf) cache.rank = null;
  }

  // ------------------------------------------------------ capitoli in cache

  /// I capitoli aperti nel lettore, per serie e capitolo. Stanno accanto alla
  /// cache e non dentro: la cartella della cache contiene solo tavole.
  final Map<String, CachedChapter> _chapters = {};
  Future<void>? _chaptersLoaded;
  Future<void> _saving = Future.value();

  Map<String, CacheRank> _ranks = const {};
  DateTime? _sweptAt;

  /// Ogni quanto la cache butta da sé ciò che è scaduto. Il rango si
  /// ricalcola sempre, costa niente; cancellare file no.
  static const Duration _sweepEvery = Duration(minutes: 30);

  File get _chaptersFile => File('${cache.directory.path}.chapters.json');

  Future<void> _loadChapters() => _chaptersLoaded ??= () async {
        try {
          final rows = await compute(
            _decodeChapters,
            await _chaptersFile.readAsString(),
          );
          for (final row in rows) {
            _chapters[_chapterId(row.series, row.chapter)] = row;
          }
        } on Object {
          // Nessun elenco ancora, o illeggibile: si ricomincia da capo, e i
          // file senza capitolo si comportano come prima, in ordine d'uso.
        }
      }();

  static String _chapterId(String series, String chapter) =>
      '$series\u0000$chapter';

  @visibleForTesting
  Future<void> get saved => _saving;

  void _saveChapters() {
    final rows = [for (final row in _chapters.values) row.toJson()];
    _saving = _saving.then((_) async {
      final text = await compute(jsonEncode, rows);
      final temporary = File('${_chaptersFile.path}.tmp');
      await temporary.writeAsString(text);
      await temporary.rename(_chaptersFile.path);
    }).catchError((Object _) {});
  }

  @override
  void rememberChapter(String series, String chapter, List<String> addresses) {
    final keys = [
      for (final address in addresses)
        if (isRemote(address)) repository.cacheKeyOf(_relative(address)),
    ];
    if (keys.isEmpty) return;
    unawaited(_loadChapters().then((_) {
      _chapters[_chapterId(series, chapter)] = CachedChapter(
        series: series,
        chapter: chapter,
        keys: keys,
        openedAt: DateTime.now().toUtc(),
      );
      _saveChapters();
    }));
  }

  /// Rifà i ranghi con lo stato di lettura di adesso e, ogni tanto, butta
  /// quello che è scaduto: i capitoli finiti da qualche giorno, le tavole già
  /// passate dei capitoli a metà, i capitoli lasciati da due settimane.
  Future<void> sweep(
    ChapterReading Function(String series, String chapter) reading,
  ) async {
    await _loadChapters();
    await cache.ready();
    final now = DateTime.now().toUtc();
    final plan = planCache(_chapters.values, reading, now);
    _ranks = plan.ranks;
    final due = _sweptAt == null || now.difference(_sweptAt!) > _sweepEvery;
    if (!due) return;
    _sweptAt = now;
    await cache.forget(plan.expired);
    // Un capitolo di cui non resta niente non serve più ricordarlo: la cache
    // l'ha già fatto uscire, per spazio o per tempo.
    final before = _chapters.length;
    _chapters.removeWhere((_, row) => !row.keys.any(cache.has));
    if (plan.expired.isNotEmpty || _chapters.length != before) _saveChapters();
  }

  /// Quali di questi capitoli della serie hanno ancora tavole in cache, e
  /// quanto occupano.
  Future<({Set<String> chapters, int bytes})> cachedOf(
    String series,
    Set<String> chapters,
  ) async {
    await _loadChapters();
    await cache.ready();
    final found = <String>{};
    var bytes = 0;
    for (final row in _chapters.values) {
      if (row.series != series || !chapters.contains(row.chapter)) continue;
      for (final key in row.keys.where(cache.has)) {
        found.add(row.chapter);
        bytes += cache.sizeOf(key);
      }
    }
    return (chapters: found, bytes: bytes);
  }

  /// Butta subito dalla cache questi capitoli della serie, senza aspettare
  /// che scadano: è l'utente a dire che non gli servono più.
  Future<void> forgetChapters(String series, Set<String> chapters) async {
    await _loadChapters();
    final gone = [
      for (final MapEntry(:key, value: row) in _chapters.entries)
        if (row.series == series && chapters.contains(row.chapter)) key,
    ];
    if (gone.isEmpty) return;
    await cache.forget([for (final key in gone) ..._chapters[key]!.keys]);
    gone.forEach(_chapters.remove);
    _saveChapters();
  }

  /// Le miniature della griglia valgono quanto il capitolo che si sta
  /// leggendo: sono piccole, e senza la libreria offline è un muro grigio.
  CacheRank _rankOf(String key) =>
      _ranks[key] ??
      (repository.thumbnailKeys.contains(key)
          ? CacheRank.kept
          : CacheRank.ordinary);

  /// Quanti precarichi possono correre insieme. Sotto i 150 kB/s uno solo:
  /// la banda è tutta della tavola che si sta per guardare.
  int get _prefetchSlots {
    final rate = _rate;
    if (rate == null) return 2;
    if (rate < 150 * 1024) return 1;
    if (rate < 600 * 1024) return 2;
    return 3;
  }

  String _relative(String address) => address.substring(remotePrefix.length);

  @override
  String? peek(String address) =>
      cache.peek(repository.cacheKeyOf(_relative(address)));

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
    if (!network.isOnline) return Future.error(const DriveOffline());
    final fetch = _Fetch(address)..urgent = urgent;
    _pending[address] = fetch;
    urgent ? _urgent.addFirst(fetch) : _prefetch.add(fetch);
    _pump();
    return fetch.done.future;
  }

  @override
  void warm(Iterable<String> addresses) {
    _wanted = addresses.toList(growable: false);
    if (!network.isOnline) return;
    final wanted = _wanted.where((address) => peek(address) == null).toList();
    final keep = wanted.toSet();
    // Un precarico nuovo sostituisce quello vecchio: chi è saltato a un altro
    // capitolo non vuole aspettare le tavole di quello che ha lasciato.
    for (final stale in _prefetch.where((f) => !keep.contains(f.address))) {
      _drop(stale, DriveException(currentL10n().dataPrefetchCancelled));
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

  void _drop(_Fetch fetch, Object error) {
    _pending.remove(fetch.address);
    fetch.done.future.ignore();
    if (!fetch.done.isCompleted) fetch.done.completeError(error);
  }

  void _onNetwork() {
    if (network.isOnline) {
      warm(_wanted);
      return;
    }
    // La rete se n'è andata: chi aspetta in fila lo sa subito, invece di
    // scoprirlo dopo un giro di tentativi.
    for (final fetch in [..._urgent, ..._prefetch]) {
      _drop(fetch, const DriveOffline());
    }
    _urgent.clear();
    _prefetch = [];
  }

  void _pump() {
    while (_running < _atOnce) {
      final _Fetch fetch;
      if (_urgent.isNotEmpty) {
        fetch = _urgent.removeFirst();
      } else if (_prefetch.isNotEmpty && _runningPrefetch < _prefetchSlots) {
        fetch = _prefetch.removeAt(0);
        _runningPrefetch++;
        fetch.counted = true;
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
      if (fetch.counted) _runningPrefetch--;
      _pump();
    }
  }

  Future<String> _download(String address) async {
    final relative = _relative(address);
    for (var attempt = 1;; attempt++) {
      try {
        final item = await repository.resolve(relative);
        if (item == null || item.folder) {
          throw DriveException(currentL10n().dataPageNotOnDrive);
        }
        final started = DateTime.now();
        var bytes = 0;
        final path = await cache.store(
          repository.cacheKeyOf(relative),
          (target) async {
            final before = await target.exists() ? await target.length() : 0;
            await repository.client.download(item.id, target);
            bytes = await target.length() - before;
          },
        );
        _measure(bytes, DateTime.now().difference(started));
        return path;
      } on DriveOffline {
        if (attempt >= _attempts || !await network.check()) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
      }
    }
  }

  void _measure(int bytes, Duration elapsed) {
    // Sotto i 32 kB il tempo è quasi tutto latenza, non banda: una copertina
    // non dice niente di quanto veloce scenderà una tavola.
    if (bytes < 32 * 1024 || elapsed.inMilliseconds <= 0) return;
    final rate = bytes * 1000 / elapsed.inMilliseconds;
    _rate = _rate == null ? rate : _rate! * 0.7 + rate * 0.3;
  }
}

class _Fetch {
  _Fetch(this.address);

  final String address;
  final Completer<String> done = Completer();

  /// Se qualcuno la sta guardando: solo i precarichi si possono annullare.
  bool urgent = false;

  /// Se occupa uno dei posti dei precarichi.
  bool counted = false;
}
