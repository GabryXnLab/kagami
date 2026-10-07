/// Grafo delle dipendenze dell'app.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/tracking.dart';

import 'archive/device.dart';
import 'data/arrivals.dart';
import 'data/backup.dart';
import 'data/cleanup.dart';
import 'data/cloud.dart';
import 'data/db/database.dart';
import 'data/downloads.dart';
import 'data/drive.dart';
import 'data/drive_library.dart';
import 'data/folder_sync.dart';
import 'data/folder_sync_schedule.dart';
import 'data/library.dart';
import 'data/library_location.dart';
import 'data/library_repository.dart';
import 'data/library_view.dart';
import 'data/network.dart';
import 'data/notifications.dart';
import 'data/read_ahead.dart';
import 'data/reader_settings.dart';
import 'data/server_access.dart';
import 'data/statistics.dart';
import 'data/user_repository.dart';
import 'format/malf.dart';
import 'l10n.dart';
import 'format/reading.dart';

final libraryLocationProvider = FutureProvider<LibraryLocation>(
  (ref) => LibraryLocation.open(),
);

final readerSettingsProvider = Provider<ReaderSettingsStore>(
  (ref) => ReaderSettingsStore(ref.watch(databaseProvider)),
);

/// Radice scelta dall'utente: `null` finché non ne indica una.
class LibraryRoot extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? path) => state = path;
}

final libraryRootProvider =
    NotifierProvider<LibraryRoot, String?>(LibraryRoot.new);

/// Le cartelle dell'app: il valore vero lo mette `main`, prima di `runApp`.
final appDirectoriesProvider = Provider<AppDirectories>(
  (ref) => throw UnimplementedError('AppDirectories va risolto in main'),
);

/// Se c'è rete. Lo stato vive in [NetworkMonitor], che lo ricava dal sistema
/// e dalle richieste vere; qui diventa qualcosa che l'interfaccia può
/// guardare.
class NetworkOnline extends Notifier<bool> {
  @override
  bool build() {
    final online = NetworkMonitor.instance.online;
    void changed() => state = online.value;
    online.addListener(changed);
    ref.onDispose(() => online.removeListener(changed));
    return online.value;
  }
}

final networkOnlineProvider =
    NotifierProvider<NetworkOnline, bool>(NetworkOnline.new);

/// La cartella di Drive che contiene la libreria, come la si mostra.
class DriveFolder {
  const DriveFolder({required this.id, required this.name});

  factory DriveFolder.parse(String value) {
    final json = jsonDecode(value) as Map<String, Object?>;
    return DriveFolder(id: json['id'] as String, name: json['name'] as String);
  }

  final String id;
  final String name;

  String encode() => jsonEncode({'id': id, 'name': name});
}

/// La cartella di Drive scelta. Sta fra le impostazioni del database, non
/// fra le preferenze del telefono: così viaggia con il backup e con
/// l'account, e su un telefono nuovo la libreria compare al primo accesso.
class DriveFolderNotifier extends AsyncNotifier<DriveFolder?> {
  static const String _key = 'drive.folder';

  @override
  Future<DriveFolder?> build() async {
    final value = await ref.watch(userRepositoryProvider).readSetting(_key);
    if (value == null || value.isEmpty) return null;
    try {
      return DriveFolder.parse(value);
    } on FormatException {
      return null;
    }
  }

  Future<void> choose(DriveFolder? folder) async {
    state = AsyncData(folder);
    await ref
        .read(userRepositoryProvider)
        .writeSetting(_key, folder?.encode() ?? '');
  }
}

final driveFolderProvider =
    AsyncNotifierProvider<DriveFolderNotifier, DriveFolder?>(
  DriveFolderNotifier.new,
);

final driveAuthProvider = Provider<DriveAuth>(
  (ref) => DriveAuth(account: () => ref.read(cloudAccountProvider).account?.email),
);

/// Quanto spazio possono occupare le tavole lette da Drive.
class DriveCacheLimit extends AsyncNotifier<int> {
  static const String _key = 'drive.cacheLimit';

  /// Un gigabyte: una quarantina di capitoli di webtoon. Con i capitoli
  /// finiti che se ne vanno da soli dopo tre giorni, quello che resta è il
  /// seguito delle serie a metà e poco altro, e ci sta largo.
  static const int standard = 1 << 30;

  @override
  Future<int> build() async =>
      int.tryParse(
        await ref.watch(userRepositoryProvider).readSetting(_key) ?? '',
      ) ??
      standard;

  Future<void> set(int bytes) async {
    state = AsyncData(bytes);
    await ref.read(userRepositoryProvider).writeSetting(_key, '$bytes');
    await ref.read(driveFileCacheProvider).setLimit(bytes);
  }
}

final driveCacheLimitProvider =
    AsyncNotifierProvider<DriveCacheLimit, int>(DriveCacheLimit.new);

/// Una cache sola per tutta la vita dell'app: il conto dei byte sta in
/// memoria, e due istanze se lo contenderebbero.
final driveFileCacheProvider = Provider<DriveFileCache>((ref) {
  final directories = ref.watch(appDirectoriesProvider);
  final cache = DriveFileCache(
    Directory(p.join(directories.cache, 'drive')),
    limitBytes: DriveCacheLimit.standard,
  );
  ref.listen(
    driveCacheLimitProvider,
    (_, limit) => limit.whenData(cache.setLimit),
    fireImmediately: true,
  );
  unawaited(cache.ready());
  return cache;
});

/// La libreria su Drive, quando c'è un account e una cartella.
final driveRepositoryProvider = Provider<DriveRepository?>((ref) {
  if (!cloudAvailable) return null;
  final signedIn = ref.watch(cloudAccountProvider.select((s) => s.signedIn));
  // Solo l'id: la sincronizzazione d'avvio rilegge la cartella dal database,
  // e un oggetto nuovo per la stessa cartella rifarebbe il repository —
  // cioè la libreria di Drive riletta da zero a ogni apertura.
  final folderId =
      ref.watch(driveFolderProvider.select((folder) => folder.value?.id));
  if (!signedIn || folderId == null) return null;
  final auth = ref.watch(driveAuthProvider);
  final client = DriveClient(auth.token, network: NetworkMonitor.instance);
  final repository = DriveRepository(
    client: client,
    folderId: folderId,
    stateDirectory: p.join(ref.watch(appDirectoriesProvider).support, 'drive'),
    files: ref.watch(driveFileCacheProvider),
  );
  final files = DriveFiles(repository);
  RemoteFiles.instance = files;
  // La cache sa cosa buttare solo sapendo cosa si è letto. Lo stato si
  // pubblica all'avvio e uscendo dal lettore — mai mentre si scorre — ed è
  // il momento giusto per rifare i conti.
  ref.listen(readingProvider, (_, reading) {
    final data = reading.value;
    if (data == null) return;
    unawaited(files.sweep((series, chapter) {
      final state = data.of(series);
      final finished = state.readChapters.contains(chapter);
      return (
        finished: finished,
        resumePage: finished ? null : state.positions[chapter]?.page,
      );
    }));
  }, fireImmediately: true);
  ref.onDispose(() {
    if (identical(RemoteFiles.instance, files)) RemoteFiles.instance = null;
    files.dispose();
    client.close();
  });
  return repository;
});

final driveFilesProvider = Provider<DriveFiles?>((ref) {
  ref.watch(driveRepositoryProvider);
  final files = RemoteFiles.instance;
  return files is DriveFiles ? files : null;
});

/// La libreria unita: la cartella scelta, i download nello spazio dell'app
/// e, se c'è, Drive. `null` finché l'utente non ha indicato niente.
final libraryProvider = Provider<Library?>((ref) {
  final root = ref.watch(libraryRootProvider);
  final hasFolder =
      ref.watch(driveFolderProvider.select((state) => state.value != null));
  final drive = ref.watch(driveRepositoryProvider);
  if (root == null && !hasFolder) return null;
  final directories = ref.watch(appDirectoriesProvider);
  return Library([
    // Con Drive la cartella può anche non avere `library.json`: può
    // contenere soltanto ciò che l'app vi ha scaricato.
    if (root != null) LibraryRepository(root, requireIndex: !hasFolder),
    LibraryRepository(
      directories.privateLibrary,
      requireIndex: false,
      private: true,
    ),
    ?drive,
  ]);
});

/// Rilegge la libreria da capo, Drive compreso. È il gesto di chi tira giù
/// la griglia: vuole vedere cosa è arrivato adesso, non dieci minuti fa.
void reloadLibrary(WidgetRef ref) {
  ref.read(driveRepositoryProvider)?.refresh();
  ref.invalidate(libraryCatalogProvider);
}

/// La chiave di un capitolo nella coda dei download.
String downloadKey(String seriesKey, String chapterId) => '$seriesKey\u0000$chapterId';

/// I download in corso e in coda, per capitolo.
///
/// Un capitolo alla volta — dentro, quattro tavole alla volta: un capitolo
/// che finisce presto vale più di dieci che avanzano insieme, perché si può
/// cominciare a leggerlo. Chi ne esce con un errore resta in elenco col suo
/// errore finché non lo si riprova o lo si toglie.
class DownloadsNotifier extends Notifier<Map<String, DownloadProgress>> {
  final List<({String series, String chapter, String destination})> _queue = [];
  final Set<String> _cancelled = {};
  bool _running = false;

  @override
  Map<String, DownloadProgress> build() => const {};

  void enqueue(String seriesKey, Iterable<String> chapterIds, String destination) {
    final added = <String, DownloadProgress>{};
    for (final chapterId in chapterIds) {
      final key = downloadKey(seriesKey, chapterId);
      final current = state[key];
      if (current != null && current.error == null) continue;
      _cancelled.remove(key);
      _queue.add((series: seriesKey, chapter: chapterId, destination: destination));
      added[key] = const DownloadProgress(done: 0, total: 0, queued: true);
    }
    if (added.isEmpty) return;
    state = {...state, ...added};
    unawaited(_drain());
  }

  void cancel(String seriesKey, String chapterId) {
    final key = downloadKey(seriesKey, chapterId);
    _cancelled.add(key);
    _queue.removeWhere((job) => downloadKey(job.series, job.chapter) == key);
    state = {...state}..remove(key);
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    final finished = <String, ({String series, String destination})>{};
    final remembered = <String>{};
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeAt(0);
        final key = downloadKey(job.series, job.chapter);
        try {
          await _download(job.series, job.chapter, job.destination, key);
          state = {...state}..remove(key);
          finished[job.series] = (series: job.series, destination: job.destination);
          // Al primo capitolo la serie si scrive subito fra quelle scaricate:
          // se l'app si chiude a metà di «scarica tutti», quello che è sceso
          // si ritrova comunque.
          if (remembered.add(job.series)) await _finishSeries(finished[job.series]!);
          // Il capitolo si legge dal telefono appena è sul telefono, non a
          // fine coda.
          ref.invalidate(seriesChaptersProvider(job.series));
        } on DownloadCancelled {
          state = {...state}..remove(key);
        } on DriveOffline {
          if (_cancelled.contains(key)) continue;
          // Senza rete un download non è fallito, è fermo: resta in testa alla
          // coda e riparte quando la rete torna. Le tavole già scese restano
          // nella cartella `.part`, e anche quella a metà riprende dal byte
          // dove si era interrotta.
          final current = state[key];
          state = {
            ...state,
            key: DownloadProgress(
              done: current?.done ?? 0,
              total: current?.total ?? 0,
              waiting: true,
            ),
          };
          _queue.insert(0, job);
          await NetworkMonitor.instance.whenOnline();
          // Una rete che torna a scatti non va presa d'assalto al primo segno.
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        } on Object catch (error) {
          if (_cancelled.contains(key)) continue;
          state = {
            ...state,
            key: DownloadProgress(done: 0, total: 0, error: error),
          };
        }
        if (_queue.every((next) => next.series != job.series) &&
            finished.containsKey(job.series)) {
          await _finishSeries(finished.remove(job.series)!);
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _download(
    String seriesKey,
    String chapterId,
    String destination,
    String key,
  ) async {
    final drive = ref.read(driveRepositoryProvider);
    final files = ref.read(driveFilesProvider);
    final entry = ref.read(seriesEntryProvider(seriesKey));
    if (drive == null || files == null || entry == null) {
      throw DriveException(currentL10n().dataDriveNotLinked);
    }
    final index = await drive.loadSeries(entry);
    final chapter = index?.chapters.firstWhereOrNull((row) => row.id == chapterId);
    final pages = (await drive.loadPages(entry))?.of(chapterId) ?? const [];
    if (chapter == null) throw DriveException(currentL10n().dataChapterNotOnDrive);
    await ChapterDownloader(drive, files).download(
      destination: destination,
      entry: entry,
      chapter: chapter,
      pages: pages,
      cancelled: () => _cancelled.contains(key),
      onPage: (done, total) => state = {
        ...state,
        key: DownloadProgress(done: done, total: total),
      },
    );
  }

  Future<void> _finishSeries(({String series, String destination}) job) async {
    final drive = ref.read(driveRepositoryProvider);
    final files = ref.read(driveFilesProvider);
    final entry = ref.read(seriesEntryProvider(job.series));
    if (drive == null || files == null || entry == null) return;
    try {
      await ChapterDownloader(drive, files)
          .finishSeries(destination: job.destination, entry: entry);
    } on Object {
      // I capitoli sono già al loro posto: senza indici accanto si leggono
      // lo stesso finché c'è Drive, e il prossimo download li riscrive.
    }
    ref.invalidate(libraryCatalogProvider);
  }
}

final downloadsProvider =
    NotifierProvider<DownloadsNotifier, Map<String, DownloadProgress>>(
  DownloadsNotifier.new,
);

/// Dove vanno i download: la cartella scelta, se c'è; altrimenti lo spazio
/// privato dell'app, se l'utente l'ha già preferito a una cartella.
/// `null` vuol dire che bisogna chiederglielo.
class DownloadPlace extends AsyncNotifier<bool> {
  static const String _key = 'downloads.private';

  @override
  Future<bool> build() async =>
      await ref.watch(userRepositoryProvider).readSetting(_key) == 'true';

  Future<void> preferPrivate() async {
    state = const AsyncData(true);
    await ref.read(userRepositoryProvider).writeSetting(_key, 'true');
  }
}

final downloadPrivateProvider =
    AsyncNotifierProvider<DownloadPlace, bool>(DownloadPlace.new);

/// Le serie tolte dalla libreria, chiave → firma della riga di allora. Sta
/// fra le impostazioni del database, quindi viaggia con backup e account:
/// una copia di `library.json` rimasta indietro su un altro telefono non le
/// rimette in griglia.
class RemovedSeries extends AsyncNotifier<Map<String, String>> {
  static const String _key = 'library.removed';

  @override
  Future<Map<String, String>> build() async {
    final value = await ref.watch(userRepositoryProvider).readSetting(_key);
    if (value == null || value.isEmpty) return const {};
    try {
      return {
        for (final MapEntry(:key, :value) in (jsonDecode(value) as Map).entries) '$key': '$value',
      };
    } on Object {
      return const {};
    }
  }

  Future<void> hide(Iterable<SeriesEntry> entries) async {
    final next = {...await future, for (final entry in entries) entry.key: entry.signature};
    state = AsyncData(next);
    await ref.read(userRepositoryProvider).writeSetting(_key, jsonEncode(next));
  }
}

final removedSeriesProvider =
    AsyncNotifierProvider<RemovedSeries, Map<String, String>>(RemovedSeries.new);

final libraryCatalogProvider = FutureProvider<LibraryCatalog>((ref) async {
  final library = ref.watch(libraryProvider);
  if (library == null) return LibraryCatalog.empty;
  final removed = await ref.watch(removedSeriesProvider.future);
  final catalog = (await library.load()).hiding(removed);
  final drive = ref.read(driveRepositoryProvider);
  // Aperta dall'istantanea, la libreria di Drive si rilegge dietro alla
  // griglia già disegnata, e la si rifà solo se è cambiato qualcosa.
  if (drive != null && drive.stale) {
    unawaited(drive.revalidate().then((changed) {
      if (changed && ref.mounted) ref.invalidateSelf();
    }));
  }
  // La libreria di Drive è quella dell'ultima volta: si mostra, e si dice.
  if (drive?.fromSnapshot ?? false) {
    return catalog.withNotice(const DriveOffline());
  }
  // Una cartella di Drive scelta e nessuno che la possa leggere: lo si dice,
  // invece di mostrare una libreria a cui mancano delle serie senza motivo.
  if (ref.read(driveFolderProvider).value != null && !library.hasDrive) {
    return catalog.withNotice(const DriveSignedOut());
  }
  return catalog;
});

final libraryIndexProvider = FutureProvider<LibraryIndex>(
  (ref) async => (await ref.watch(libraryCatalogProvider.future)).index,
);

final seriesEntryProvider = Provider.family<SeriesEntry?, String>((ref, key) {
  final index = ref.watch(libraryIndexProvider).value;
  return index?.series.firstWhereOrNull((entry) => entry.key == key);
});

/// Le sorgenti che hanno la serie, dalla preferita.
final seriesHoldersProvider =
    Provider.family<List<LibraryShelf>, String>((ref, key) {
  final catalog = ref.watch(libraryCatalogProvider).value;
  return catalog?.holders[key] ?? const [];
});

/// Dove sta la serie: è l'icona sulla copertina.
final seriesPlaceProvider = Provider.family<SeriesPlace?, String>(
  (ref, key) => ref.watch(libraryCatalogProvider).value?.places[key],
);

/// I capitoli di una serie da tutte le sorgenti, caricati solo quando la si
/// apre.
final seriesChaptersProvider =
    FutureProvider.family<SeriesChapters?, String>((ref, key) async {
  final library = ref.watch(libraryProvider);
  final entry = ref.watch(seriesEntryProvider(key));
  if (library == null || entry == null) return null;
  _againWhenOnline(ref);
  return library.loadSeries(entry, ref.watch(seriesHoldersProvider(key)));
});

/// Letto senza rete, un indice di Drive può mancare: quando la rete torna lo
/// si rilegge. Da connessi no — rileggere a ogni andirivieni della rete
/// sarebbe lavoro per niente.
void _againWhenOnline(Ref ref) {
  if (ref.read(networkOnlineProvider)) return;
  ref.listen(networkOnlineProvider, (_, online) {
    if (online) ref.invalidateSelf();
  });
}

/// Indice dei capitoli di una serie, caricato solo quando la si apre.
final seriesIndexProvider = FutureProvider.family<SeriesIndex?, String>(
  (ref, key) async =>
      (await ref.watch(seriesChaptersProvider(key).future))?.index,
);

/// Metadati estesi della scheda: la descrizione non sta in `library.json`.
final seriesManifestProvider =
    FutureProvider.family<Map<String, Object?>?, String>((ref, key) async {
  final library = ref.watch(libraryProvider);
  final entry = ref.watch(seriesEntryProvider(key));
  if (library == null || entry == null) return null;
  return library.loadSeriesManifest(
    entry,
    ref.watch(seriesHoldersProvider(key)),
  );
});

/// Pagine di una serie, caricate solo entrando in lettura.
final pagesIndexProvider =
    FutureProvider.family<PagesIndex?, String>((ref, key) async {
  final library = ref.watch(libraryProvider);
  final entry = ref.watch(seriesEntryProvider(key));
  final chapters = await ref.watch(seriesChaptersProvider(key).future);
  if (library == null || entry == null || chapters == null) return null;
  _againWhenOnline(ref);
  return library.loadPages(
    entry,
    chapters,
    ref.watch(seriesHoldersProvider(key)),
  );
});

/// Quanto occupano sul telefono i capitoli già letti di una serie. Si
/// rifà quando lo stato si pubblica, cioè mai mentre si legge.
final readLeftoversProvider =
    FutureProvider.family<ReadLeftovers, String>((ref, key) async {
  final entry = ref.watch(seriesEntryProvider(key));
  final holders = ref.watch(seriesHoldersProvider(key));
  final read = ref.watch(
    seriesStateProvider(key).select((state) => state.readChapters),
  );
  final drive = ref.watch(driveFilesProvider);
  final chapters = await ref.watch(seriesChaptersProvider(key).future);
  if (entry == null || chapters == null) return ReadLeftovers.empty;
  return findReadLeftovers(
    entry: entry,
    chapters: chapters,
    holders: holders,
    read: read,
    drive: drive,
  );
});

/// Le serie per cui l'utente ha chiesto di non proporre più di liberare
/// spazio aprendo la scheda. Fra le impostazioni del database, quindi nel
/// backup: è una sua scelta, non del telefono.
class CleanupQuiet extends AsyncNotifier<Set<String>> {
  static const String _key = 'cleanup.quiet';

  @override
  Future<Set<String>> build() async {
    final value = await ref.watch(userRepositoryProvider).readSetting(_key);
    if (value == null || value.isEmpty) return const {};
    try {
      return {...(jsonDecode(value) as List).whereType<String>()};
    } on FormatException {
      return const {};
    }
  }

  Future<void> silence(String seriesKey) async {
    final keys = {...await future, seriesKey};
    state = AsyncData(keys);
    await ref
        .read(userRepositoryProvider)
        .writeSetting(_key, jsonEncode(keys.toList()));
  }
}

final cleanupQuietProvider =
    AsyncNotifierProvider<CleanupQuiet, Set<String>>(CleanupQuiet.new);

/// Se aprendo una serie senza voto l'app lo chiede. Fra le impostazioni del
/// database, quindi nel backup: spenta una volta, vale su ogni telefono.
class RatingInvite extends AsyncNotifier<bool> {
  static const String _key = 'rating.quiet';

  @override
  Future<bool> build() async =>
      await ref.watch(userRepositoryProvider).readSetting(_key) != 'true';

  Future<void> set(bool value) async {
    state = AsyncData(value);
    await ref.read(userRepositoryProvider).writeSetting(_key, '${!value}');
  }
}

final ratingInviteProvider =
    AsyncNotifierProvider<RatingInvite, bool>(RatingInvite.new);

/// Il database dei dati personali: uno solo per tutta la vita dell'app.
final databaseProvider = Provider<KagamiDatabase>((ref) {
  final database = KagamiDatabase();
  ref.onDispose(database.close);
  return database;
});

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(databaseProvider)),
);

/// Stato utente tenuto in memoria e scritto sul database a ogni gesto.
class ReadingData {
  const ReadingData({this.series = const {}, this.collections = const []});

  final Map<String, SeriesState> series;
  final List<Collection> collections;

  SeriesState of(String key) => series[key] ?? const SeriesState();

  List<Collection> containing(String key) => collections
      .where((collection) => collection.seriesKeys.contains(key))
      .toList(growable: false);
}

/// L'unico punto da cui l'app modifica i dati personali.
///
/// La fotografia sta in memoria perché ogni gesto della lettura la interroga;
/// la scrittura va sul database, che è la fonte di verità e l'unico posto in
/// cui la cronologia si accumula.
class Reading extends AsyncNotifier<ReadingData> {
  late UserRepository _repository;

  @override
  Future<ReadingData> build() async {
    _repository = ref.watch(userRepositoryProvider);
    final root = ref.watch(libraryRootProvider);
    // Una libreria che arriva dal vecchio formato porta con sé `reading/`:
    // lo si importa una volta sola, poi il database è la verità.
    if (root != null) await _repository.importLegacyReading(root);
    return ReadingData(
      series: await _repository.loadStates(),
      collections: await _repository.loadCollections(),
    );
  }

  /// La fotografia scritta ma non ancora pubblicata.
  ///
  /// Serve alla posizione di lettura, che cambia mentre si scorre: il
  /// database la riceve subito, l'interfaccia no. Pubblicarla vorrebbe dire
  /// rifare segnali, filtri e ordinamenti di tutta la libreria — che resta
  /// montata sotto il lettore — al ritmo dello scorrimento.
  ReadingData? _quiet;
  final Set<String> _quietKeys = {};

  ReadingData get _data => _quiet ?? state.value ?? const ReadingData();

  /// Lo stato di una serie compreso quello scritto in silenzio: è ciò che il
  /// lettore deve vedere, perché è lui ad averlo scritto.
  SeriesState peek(String key) => _data.of(key);

  void _publish(Map<String, SeriesState> series, List<Collection> collections) {
    _quiet = null;
    _quietKeys.clear();
    state = AsyncData(ReadingData(series: series, collections: collections));
  }

  Future<void> _mutate(String key, SeriesState Function(SeriesState) change) async {
    final data = _data;
    final updated = change(data.of(key));
    _publish({...data.series, key: updated}, data.collections);
    await _repository.saveSeriesState(key, updated);
  }

  Future<void> _replaceCollections(List<Collection> collections) async {
    _publish(_data.series, collections);
    await _repository.replaceCollections(collections);
  }

  Future<void> setStatus(String key, ShelfStatus status) =>
      _mutate(key, (state) => state.copyWith(status: status));

  Future<void> setRating(String key, int? rating) => _mutate(
        key,
        (state) => rating == null
            ? state.copyWith(clearRating: true)
            : state.copyWith(rating: rating),
      );

  Future<void> toggleFavorite(String key) =>
      _mutate(key, (state) => state.copyWith(favorite: !state.favorite));

  Future<void> setNotes(String key, String notes) =>
      _mutate(key, (state) => state.copyWith(notes: notes));

  Future<void> toggleMuted(String key) =>
      _mutate(key, (state) => state.copyWith(muted: !state.muted));

  /// Porta i dati personali di [from] su [to] (`UserRepository.moveSeries`):
  /// serve a collegare una scheda manuale alla serie vera, che ha un'altra
  /// chiave.
  Future<void> moveSeries(String from, String to) async {
    await _repository.moveSeries(from, to);
    _publish(
      await _repository.loadStates(),
      await _repository.loadCollections(),
    );
  }

  /// «Arrivato a»: [chapterId] è l'ultimo capitolo letto altrove (null, non
  /// iniziata). Segna letti, come stimati, i capitoli con `order` fino a
  /// quello incluso che non lo sono già, scrive il suo numero e porta a «in
  /// lettura» una serie ancora da iniziare o in programma. Con null azzera il
  /// numero e lascia i letti com'erano: toglierli non è questo gesto.
  Future<void> setReachedThrough(
    String key,
    Iterable<ChapterEntry> chapters,
    String? chapterId,
  ) async {
    if (chapterId == null) {
      await _mutate(key, (state) => state.copyWith(clearReachedChapter: true));
      return;
    }
    final reached = chapters.firstWhere((chapter) => chapter.id == chapterId);
    await _marks(
      key,
      [
        for (final chapter in chapters)
          if (chapter.order <= reached.order) chapter.id,
      ],
      true,
      estimated: true,
    );
    final number = reached.number ?? '${reached.order + 1}';
    await _mutate(
      key,
      (state) => state.copyWith(
        reachedChapter: number,
        status: state.status == ShelfStatus.none ||
                state.status == ShelfStatus.planned
            ? ShelfStatus.reading
            : state.status,
      ),
    );
  }

  /// Per le schede senza elenco di capitoli: solo il numero dichiarato.
  Future<void> setReachedChapter(String key, String? number) {
    final value = number?.trim();
    return _mutate(
      key,
      (state) => value == null || value.isEmpty
          ? state.copyWith(clearReachedChapter: true)
          : state.copyWith(reachedChapter: value),
    );
  }

  /// Scrive in un colpo la scheda di una serie, anche non ancora in libreria:
  /// lo stato è per chiave e non chiede che la serie esista. I campi null
  /// restano come sono; per i letti stimati si chiama poi [setReachedThrough].
  Future<void> saveCard(
    String key, {
    ShelfStatus? status,
    int? rating,
    String? notes,
    bool? favorite,
    String? reachedChapter,
  }) =>
      _mutate(
        key,
        (state) => state.copyWith(
          status: status,
          rating: rating,
          notes: notes,
          favorite: favorite,
          reachedChapter: reachedChapter,
        ),
      );

  /// Segna l'apertura della scheda: è il riferimento con cui si decide se un
  /// capitolo arrivato dopo è una novità.
  Future<void> touch(String key) async {
    final data = _data;
    final updated = data.of(key).copyWith(lastOpenedAt: DateTime.now().toUtc());
    _publish({...data.series, key: updated}, data.collections);
    await _repository.touchSeries(key);
  }

  Future<void> setChapterRead(String key, String chapterId, bool read) =>
      _marks(key, [chapterId], read);

  /// Segna tutti i capitoli fino a quello indicato, incluso: è il gesto con
  /// cui si recupera una serie letta altrove senza toccarne cento a uno a uno.
  /// Sono letture di altrove, quindi `estimated`: cronologia e statistiche
  /// non devono contarle come cento capitoli letti oggi.
  Future<void> setReadThrough(String key, Iterable<String> chapterIds) =>
      _marks(key, chapterIds, true, estimated: true);

  Future<void> setAllRead(String key, Iterable<String> chapterIds, bool read) =>
      _marks(key, chapterIds, read);

  Future<void> _marks(
    String key,
    Iterable<String> chapterIds,
    bool read, {
    bool estimated = false,
  }) async {
    var ids = chapterIds.toList(growable: false);
    if (ids.isEmpty) return;
    final data = _data;
    final current = data.of(key);
    // Una lettura vera resta con la sua data: riscritta come stimata
    // sparirebbe da cronologia e statistiche.
    if (estimated) {
      ids = ids.where((id) => !current.readChapters.contains(id)).toList();
      if (ids.isEmpty) return;
    }
    final chapters = {...current.readChapters};
    if (read) {
      chapters.addAll(ids);
    } else {
      chapters.removeAll(ids);
    }
    final updated = current.copyWith(readChapters: chapters);
    _publish({...data.series, key: updated}, data.collections);
    await _repository.markChapters(key, ids, read, estimated: estimated);
    await _repository.saveSeriesState(key, updated);
  }

  /// Ripresa esatta: pagina e capitolo dove si è smesso.
  ///
  /// Se lo stato era vuoto la serie passa a "in lettura" da sé: averla aperta
  /// è già la risposta alla domanda che il menù porrebbe.
  Future<void> saveProgress(
    String key, {
    required String chapterId,
    required int page,
    required int pageCount,
    double offset = 0,
  }) async {
    final data = _data;
    final current = data.of(key);
    final progress = ReadingProgress(
      chapterId: chapterId,
      page: page,
      pageCount: pageCount,
      offset: offset,
      updatedAt: DateTime.now().toUtc(),
    );
    final updated = current.copyWith(
      status: current.status == ShelfStatus.none
          ? ShelfStatus.reading
          : current.status,
      progress: progress,
    );
    _publish({...data.series, key: updated}, data.collections);
    await _repository.saveProgress(key, progress);
    await _repository.saveSeriesState(key, updated);
  }

  /// La stessa cosa, ma in silenzio: la riga va su disco, la fotografia
  /// resta da parte finché qualcuno non chiede di pubblicarla.
  Future<void> noteProgress(
    String key, {
    required String chapterId,
    required int page,
    required double offset,
    required int pageCount,
  }) async {
    final data = _data;
    final current = data.of(key);
    final progress = ReadingProgress(
      chapterId: chapterId,
      page: page,
      pageCount: pageCount,
      offset: offset,
      updatedAt: DateTime.now().toUtc(),
    );
    final updated = current.copyWith(
      status: current.status == ShelfStatus.none
          ? ShelfStatus.reading
          : current.status,
      progress: progress,
    );
    _quiet = ReadingData(
      series: {...data.series, key: updated},
      collections: data.collections,
    );
    _quietKeys.add(key);
    await _repository.saveProgress(key, progress);
  }

  /// Il capitolo finito mentre si legge: su disco subito, nella fotografia
  /// all'uscita dal lettore. Pubblicarlo lì per lì rifaceva i segnali di tutta
  /// la libreria nel mezzo dello scorrimento, alla fine di ogni capitolo.
  Future<void> noteChapterRead(String key, String chapterId) =>
      noteChaptersRead(key, [chapterId]);

  /// Più capitoli insieme, allo stesso modo. [estimated] è per quelli che
  /// si segnano letti senza averli letti adesso — i precedenti di un
  /// capitolo finito —: la data non è vera, e cronologia e statistiche non
  /// devono contarli come letture di oggi.
  Future<void> noteChaptersRead(
    String key,
    Iterable<String> chapterIds, {
    bool estimated = false,
  }) async {
    final data = _data;
    final current = data.of(key);
    final ids = chapterIds
        .where((id) => !current.readChapters.contains(id))
        .toList(growable: false);
    if (ids.isEmpty) return;
    _quiet = ReadingData(
      series: {
        ...data.series,
        key: current.copyWith(readChapters: {...current.readChapters, ...ids}),
      },
      collections: data.collections,
    );
    _quietKeys.add(key);
    await _repository.markChapters(key, ids, true, estimated: estimated);
  }

  /// Rende pubblico quello che la lettura ha scritto in silenzio. Si chiama
  /// uscendo dal lettore: è il momento in cui la libreria deve accorgersi che
  /// il segnalibro si è mosso.
  Future<void> commitProgress() async {
    final quiet = _quiet;
    if (quiet == null) return;
    final keys = _quietKeys.toList(growable: false);
    _publish(quiet.series, quiet.collections);
    for (final key in keys) {
      await _repository.saveSeriesState(key, quiet.of(key));
    }
  }

  Future<void> createCollection(String name, {int? color}) async {
    final current = _data.collections;
    final collection = Collection(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
      seriesKeys: const [],
      color: color,
      order: current.length,
      updatedAt: DateTime.now().toUtc(),
    );
    await _replaceCollections([...current, collection]);
  }

  Future<void> editCollection(String id, {String? name, int? color}) async {
    await _replaceCollections([
      for (final collection in _data.collections)
        collection.id == id
            ? collection.copyWith(name: name, color: color)
            : collection,
    ]);
  }

  Future<void> deleteCollection(String id) async {
    await _replaceCollections([
      for (final collection in _data.collections.where((row) => row.id != id))
        collection,
    ]);
  }

  Future<void> setSeriesInCollection(
    String id,
    String seriesKey,
    bool member,
  ) async {
    await _replaceCollections([
      for (final collection in _data.collections)
        if (collection.id != id)
          collection
        else
          collection.copyWith(
            seriesKeys: member
                ? [...collection.seriesKeys.where((k) => k != seriesKey), seriesKey]
                : collection.seriesKeys
                    .where((k) => k != seriesKey)
                    .toList(growable: false),
          ),
    ]);
  }

  Future<void> reorderCollection(String id, int from, int to) async {
    final current = _data.collections;
    final target = current.firstWhereOrNull((row) => row.id == id);
    if (target == null) return;
    final keys = [...target.seriesKeys];
    if (from < 0 || from >= keys.length) return;
    final moved = keys.removeAt(from);
    keys.insert(to.clamp(0, keys.length), moved);
    await _replaceCollections([
      for (final collection in current)
        collection.id == id ? collection.copyWith(seriesKeys: keys) : collection,
    ]);
  }

  Future<void> reorderCollections(int from, int to) async {
    final current = [..._data.collections];
    if (from < 0 || from >= current.length) return;
    final moved = current.removeAt(from);
    current.insert(to.clamp(0, current.length), moved);
    await _replaceCollections([
      for (var position = 0; position < current.length; position++)
        current[position].copyWith(order: position),
    ]);
  }
}

final readingProvider =
    AsyncNotifierProvider<Reading, ReadingData>(Reading.new);

final seriesStateProvider = Provider.family<SeriesState, String>((ref, key) {
  final reading = ref.watch(readingProvider).value;
  return reading?.of(key) ?? const SeriesState();
});

final collectionsProvider = Provider<List<Collection>>((ref) {
  final reading = ref.watch(readingProvider).value;
  return reading?.collections ?? const [];
});

/// I capitoli nuovi: quanti ne ha visti questo telefono per serie, e le
/// notifiche di quelli arrivati dopo.
///
/// Si guarda ogni volta che la libreria si rilegge — all'avvio, tornando in
/// primo piano se l'indice è cambiato, tirando giù la griglia — perché è lì
/// che la catena fa arrivare ciò che MangaArchive ha scaricato. Solo un
/// catalogo completo conta: una libreria senza Drive, o letta mentre la
/// cartella di Drive non è ancora nota, ha meno capitoli di quella vera, e
/// quando la si rilegge intera i capitoli di Drive sembrerebbero arrivati
/// adesso.
class Arrivals extends AsyncNotifier<Map<String, ArrivalMark>> {
  late UserRepository _repository;
  late ArrivalFiles _files;

  /// Osservare e prendere atto leggono e riscrivono le stesse righe: in fila,
  /// o una delle due scriverebbe su una fotografia vecchia.
  Future<void> _work = Future.value();

  @override
  Future<Map<String, ArrivalMark>> build() async {
    _repository = ref.watch(userRepositoryProvider);
    _files = ArrivalFiles(ref.watch(appDirectoriesProvider).support);
    ref.listen(libraryCatalogProvider, (_, next) {
      final catalog = next.value;
      if (catalog != null) _enqueue(() => _observe(catalog));
    }, fireImmediately: true);
    return _repository.loadArrivals();
  }

  void _enqueue(Future<void> Function() job) =>
      _work = _work.then((_) => job(), onError: (_) => job());

  Future<void> _observe(LibraryCatalog catalog) async {
    if (catalog.notices.isNotEmpty) return;
    // Finché la cartella di Drive non è nota la libreria è solo quella del
    // telefono. Se c'è, il catalogo intero arriva dopo e passa di qui.
    await ref.read(driveFolderProvider.future);
    if (ref.read(libraryCatalogProvider).value != catalog) return;
    final stored = await future;
    final recorded = recordedArrivals(stored, await _files.readRecord());
    final marks = {...stored, ...recorded};
    final reading = await ref.read(readingProvider.future);
    final plan = planArrivals(catalog.index.series, reading.series, marks);
    final changed = {...recorded, ...plan.marks};
    if (changed.isEmpty) return;
    state = AsyncData({...marks, ...plan.marks});
    await _repository.saveArrivals(changed);
    await ArrivalNotifications.instance.show(plan.alerts);
  }

  /// Lascia al controllo ad app chiusa le serie da guardare nella cartella
  /// locale. Lo si fa uscendo dall'app: è da lì in poi che serve, ed è lo
  /// stato più recente che l'app possa dargli.
  void handOver() => _enqueue(() async {
        final root = ref.read(libraryRootProvider);
        final marks = await future;
        await _files.writeWatch(
          root == null
              ? null
              : watchList(root, ref.read(librarySignalsProvider), marks),
        );
        if (root != null) {
          await ArrivalNotifications.instance.watch(_files);
        }
      });

  /// La scheda è stata aperta: quello che c'era non è più nuovo.
  void acknowledge(String key) => _enqueue(() async {
        await ArrivalNotifications.instance.dismiss(key);
        final entry = ref.read(seriesEntryProvider(key));
        if (entry == null) return;
        final marks = await future;
        final stored = marks[key];
        final mark = stored != null && stored.fits(entry)
            ? stored.acknowledged(SeriesSignals.arrivalCount(entry))
            : ArrivalMark.of(entry);
        if (mark == marks[key]) return;
        state = AsyncData({...marks, key: mark});
        await _repository.saveArrivals({key: mark});
      });
}

final arrivalsProvider =
    AsyncNotifierProvider<Arrivals, Map<String, ArrivalMark>>(Arrivals.new);

/// Indice e stato incrociati: è la forma in cui l'interfaccia guarda la
/// libreria, e l'unica che sa dire cosa è nuovo e cosa resta da leggere.
final librarySignalsProvider = Provider<List<SeriesSignals>>((ref) {
  final index = ref.watch(libraryIndexProvider).value;
  final reading = ref.watch(readingProvider).value;
  final arrivals = ref.watch(arrivalsProvider).value ?? const {};
  if (index == null) return const [];
  return [
    for (final entry in index.series)
      _signals(
        ref,
        entry,
        reading?.of(entry.key) ?? const SeriesState(),
        arrivals[entry.key]?.seenFor(entry),
      ),
  ];
});

final seriesSignalsProvider =
    Provider.family<SeriesSignals?, String>((ref, key) {
  final entry = ref.watch(seriesEntryProvider(key));
  if (entry == null) return null;
  return _signals(
    ref,
    entry,
    ref.watch(seriesStateProvider(key)),
    ref
        .watch(arrivalsProvider.select((marks) => marks.value?[key]))
        ?.seenFor(entry),
  );
});

/// L'indice si legge solo per le serie archiviate a metà e già cominciate:
/// sono le sole in cui i conti senza indice possono sbagliare, e segnare
/// letta una serie intera resta l'unico altro motivo per leggerne tanti.
SeriesSignals _signals(
  Ref ref,
  SeriesEntry entry,
  SeriesState state,
  int? seen,
) => SeriesSignals.of(
      entry,
      state,
      seenChapters: seen,
      chapters: SeriesSignals.needsChapters(entry, state)
          ? ref.watch(seriesIndexProvider(entry.key)).value?.chapters
          : null,
    );

class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setSort(LibrarySort sort) => state = state.sort == sort
      ? state.copyWith(descending: !state.descending)
      : state.copyWith(sort: sort, descending: true);

  void toggleShelf(ShelfStatus value) =>
      state = state.copyWith(shelf: _toggle(state.shelf, value));

  void toggleRelease(ReleaseStatus value) =>
      state = state.copyWith(release: _toggle(state.release, value));

  void toggleGenre(String value) =>
      state = state.copyWith(genres: state.genres.toggled(value));

  void toggleTag(String value) =>
      state = state.copyWith(tags: state.tags.toggled(value));

  void toggleAuthor(String value) =>
      state = state.copyWith(authors: state.authors.toggled(value));

  void setOnlyUnread(bool value) => state = state.copyWith(onlyUnread: value);

  void setOnlyStarted(bool value) => state = state.copyWith(onlyStarted: value);

  void setOnlyFavorite(bool value) =>
      state = state.copyWith(onlyFavorite: value);

  void setOnlyNew(bool value) => state = state.copyWith(onlyNew: value);

  void setOnlyCards(bool value) => state = state.copyWith(onlyCards: value);

  void setMinRating(int? value) => value == null
      ? state = state.copyWith(clearRating: true)
      : state = state.copyWith(minRating: value);

  /// Rimescola: l'ordine casuale è stabile finché non lo si chiede di nuovo.
  void shuffle() => state = state.copyWith(
        sort: LibrarySort.shuffle,
        seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      );

  /// Apre la libreria già filtrata su un valore: è il gesto con cui un tag
  /// della scheda diventa una domanda ("altre così").
  void only({String? genre, String? tag, String? author}) => state =
      const LibraryFilter().copyWith(
        genres: genre == null ? null : TriFilter(include: {genre}),
        tags: tag == null ? null : TriFilter(include: {tag}),
        authors: author == null ? null : TriFilter(include: {author}),
      );

  void showAuto(AutoCollection? auto) => state = auto == null
      ? state.copyWith(clearAuto: true, clearCollection: true)
      : state.copyWith(auto: auto, clearCollection: true);

  void showCollection(String? id) => id == null
      ? state = state.copyWith(clearCollection: true)
      : state = state.copyWith(collectionId: id, clearAuto: true);

  void clear() => state = state.cleared();

  Set<T> _toggle<T>(Set<T> values, T value) =>
      values.contains(value) ? ({...values}..remove(value)) : {...values, value};
}

/// Come è disposta la griglia. Si ricorda, perché è una preferenza e non una
/// scelta da rifare a ogni apertura.
class LibraryDisplayNotifier extends AsyncNotifier<LibraryDisplay> {
  static const String _key = 'library.display';

  @override
  Future<LibraryDisplay> build() async => LibraryDisplay.parse(
        await ref.watch(userRepositoryProvider).readSetting(_key),
      );

  Future<void> show(LibraryDisplay display) async {
    state = AsyncData(display);
    await ref.read(userRepositoryProvider).writeSetting(_key, display.name);
  }
}

final libraryDisplayProvider =
    AsyncNotifierProvider<LibraryDisplayNotifier, LibraryDisplay>(
  LibraryDisplayNotifier.new,
);

/// Le serie selezionate nella griglia. Vuoto significa che non si sta
/// selezionando: la modalità non è uno stato a parte.
class SelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String key) => state = state.contains(key)
      ? ({...state}..remove(key))
      : {...state, key};

  void replace(Iterable<String> keys) => state = keys.toSet();

  void clear() => state = const {};
}

final selectionProvider =
    NotifierProvider<SelectionNotifier, Set<String>>(SelectionNotifier.new);

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
  LibraryFilterNotifier.new,
);

final libraryFacetsProvider = Provider<LibraryFacets>((ref) {
  final index = ref.watch(libraryIndexProvider).value;
  return LibraryFacets.of(index?.series ?? const []);
});

/// La libreria come la si vede: filtrata e ordinata.
final visibleLibraryProvider = Provider<List<SeriesSignals>>((ref) {
  final filter = ref.watch(libraryFilterProvider);
  final collection = filter.collectionId == null
      ? null
      : ref
          .watch(collectionsProvider)
          .firstWhereOrNull((row) => row.id == filter.collectionId);
  return applyFilter(
    ref.watch(librarySignalsProvider),
    filter,
    collectionOrder: collection?.seriesKeys ?? const [],
  );
});

/// Cronologia delle letture, riletta quando lo stato cambia: segnare un
/// capitolo letto è esattamente ciò che vi aggiunge una riga.
final historyProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  ref.watch(readingProvider);
  return ref.watch(userRepositoryProvider).history();
});

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

/// Copia automatica dentro la libreria. È accesa di suo: da quando i dati
/// personali stanno nel database, è l'unica cosa che li fa sopravvivere a una
/// reinstallazione senza che l'utente ci debba pensare.
class AutoBackup extends AsyncNotifier<bool> {
  static const String _key = 'backup.auto';

  @override
  Future<bool> build() async =>
      await ref.watch(userRepositoryProvider).readSetting(_key) != 'false';

  Future<void> set(bool value) async {
    state = AsyncData(value);
    await ref.read(userRepositoryProvider).writeSetting(_key, '$value');
  }
}

final autoBackupProvider =
    AsyncNotifierProvider<AutoBackup, bool>(AutoBackup.new);

/// Fa la copia se è ora di farla. Si guarda una volta all'avvio: è un lavoro
/// da qualche centinaio di kilobyte, non una cosa da ripetere.
final autoBackupRunProvider = FutureProvider<void>((ref) async {
  final root = ref.watch(libraryRootProvider);
  if (root == null) return;
  if (!await ref.watch(autoBackupProvider.future)) return;
  await ref.watch(backupServiceProvider).autoBackup(root);
});

/// L'accesso con Google e il viaggio dei dati personali.
final cloudAuthProvider = Provider<CloudAuth>((ref) => const CloudAuth());

final cloudSyncProvider = Provider<CloudSync>(
  (ref) => CloudSync(
    ref.watch(backupServiceProvider),
    ref.watch(userRepositoryProvider),
  ),
);

/// Chi ha fatto l'accesso, e com'è andata l'ultima sincronizzazione.
///
/// La sincronizzazione avviene in tre momenti e nessun altro: all'avvio,
/// quando si esce dall'app, e quando la si chiede. Un'app che manda su i dati
/// a ogni pagina girata terrebbe la radio accesa per tutta la lettura, che è
/// il modo più rapido di trasformare un lettore in un consumo di batteria.
class CloudAccountNotifier extends Notifier<CloudStatus> {
  @override
  CloudStatus build() {
    if (!cloudAvailable) return const CloudStatus();
    final auth = ref.watch(cloudAuthProvider);
    final subscription = auth.changes().listen(
          (account) => state = account == null
              ? const CloudStatus()
              : state.copyWith(account: account),
        );
    ref.onDispose(subscription.cancel);
    unawaited(_restoreLastSync());
    return CloudStatus(account: auth.current);
  }

  Future<void> _restoreLastSync() async {
    final last = await ref.read(cloudSyncProvider).lastSync();
    if (last != null) state = state.copyWith(lastSyncAt: last);
  }

  Future<void> signIn() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final account = await ref.read(cloudAuthProvider).signIn();
      if (account == null) {
        state = state.copyWith(busy: false);
        return;
      }
      state = state.copyWith(account: account);
      await _run();
    } on Exception catch (error) {
      state = state.copyWith(busy: false, error: cloudMessage(error));
    }
  }

  /// Uscire manda su quello che si ha prima di dimenticare chi si era:
  /// altrimenti l'ultima lettura resterebbe su un telefono solo.
  Future<void> signOut() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref.read(cloudSyncProvider).sync();
    } on Exception catch (_) {
      // Uscire deve riuscire anche senza rete: i dati restano qui, e la
      // prossima sincronizzazione li ritroverà.
    }
    await ref.read(cloudAuthProvider).signOut();
    ref.read(driveAuthProvider).forget();
    state = const CloudStatus();
  }

  Future<void> syncNow() => _run();

  /// Per quando l'app passa in secondo piano: se ne sta già facendo una, è
  /// quella a mandare su i dati.
  Future<void> pushNow() async {
    if (!state.signedIn || state.busy) return;
    await _run();
  }

  /// Smette di tenerne copia: la riga in rete sparisce e l'accesso si chiude.
  /// I dati di questo telefono non si toccano.
  Future<void> forget() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref.read(cloudSyncProvider).forget();
    } on Exception catch (error) {
      state = state.copyWith(busy: false, error: cloudMessage(error));
      return;
    }
    await ref.read(cloudAuthProvider).signOut();
    ref.read(driveAuthProvider).forget();
    state = const CloudStatus();
  }

  Future<void> _run() async {
    if (!state.signedIn) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final (:at, :merged) = await ref.read(cloudSyncProvider).sync();
      state = state.copyWith(busy: false, lastSyncAt: at);
      // Fondere ha riscritto il database sotto l'app: la fotografia in memoria
      // va rifatta, altrimenti la libreria mostra ancora quella di prima.
      if (merged) {
        ref.invalidate(readingProvider);
        // La cartella di Drive viaggia con le impostazioni: su un telefono
        // nuovo è ciò che fa comparire la libreria al primo accesso.
        ref.invalidate(driveFolderProvider);
        ref.invalidate(serverLinkProvider);
      }
    } on Exception catch (error) {
      state = state.copyWith(busy: false, error: cloudMessage(error));
    }
  }

}

final cloudAccountProvider =
    NotifierProvider<CloudAccountNotifier, CloudStatus>(
  CloudAccountNotifier.new,
);

/// La sincronizzazione d'avvio: una sola, come la copia automatica. È quella
/// che fa trovare il segno di lettura dell'altro telefono già al suo posto.
final cloudSyncRunProvider = FutureProvider<void>((ref) async {
  // Solo `signedIn`: lo stato intero cambia a ogni sincronizzazione — in
  // corso, finita, data dell'ultima — e osservarlo la rilanciava all'infinito,
  // una fusione nel database e un invio dopo l'altro finché l'app era aperta.
  if (!ref.watch(cloudAccountProvider.select((status) => status.signedIn))) {
    return;
  }
  await ref.read(cloudAccountProvider.notifier).syncNow();
});

/// I file della sincronizzazione della cartella con Drive.
final syncFilesProvider = Provider<SyncFiles>(
  (ref) => SyncFiles(ref.watch(appDirectoriesProvider).support),
);

/// Come è impostata la sincronizzazione della cartella.
///
/// Il file lo legge anche il lavoro programmato, che non ha l'app intorno:
/// per questo porta con sé la cartella del telefono e quella di Drive, e le
/// si riscrive qui quando cambiano.
class FolderSyncSettings extends AsyncNotifier<SyncSettings> {
  late SyncFiles _files;

  @override
  Future<SyncSettings> build() async {
    _files = ref.watch(syncFilesProvider);
    ref.listen(libraryRootProvider, (_, _) => _replace());
    ref.listen(driveFolderProvider, (_, _) => _replace());
    final stored = await _files.readSettings();
    final placed = _placed(stored);
    if (placed != stored) await _save(placed);
    return placed;
  }

  /// La cartella del telefono può non essere ancora nota all'avvio — la si
  /// ripristina dalle preferenze subito dopo —, e quella di Drive arriva dal
  /// database: finché non si sa, vale quella salvata.
  SyncSettings _placed(SyncSettings settings) {
    final folder = ref.read(driveFolderProvider);
    return settings.copyWith(
      clearPlaces: true,
      root: ref.read(libraryRootProvider) ?? settings.root,
      folderId: folder.hasValue ? folder.value?.id : settings.folderId,
    );
  }

  Future<void> _replace() async {
    final current = state.value;
    if (current == null) return;
    final placed = _placed(current);
    if (placed == current) return;
    state = AsyncData(placed);
    await _save(placed);
  }

  Future<void> change(SyncSettings Function(SyncSettings current) update) async {
    final current = await future;
    final next = _placed(update(current));
    state = AsyncData(next);
    await _save(next);
  }

  Future<void> _save(SyncSettings settings) async {
    await _files.writeSettings(settings);
    await const FolderSyncScheduler().apply(settings);
  }
}

final folderSyncSettingsProvider =
    AsyncNotifierProvider<FolderSyncSettings, SyncSettings>(
  FolderSyncSettings.new,
);

/// Il giro in corso nell'app, e l'esito dell'ultimo — anche di quello
/// programmato, che lo scrive nello stesso file.
class FolderSyncStatus {
  const FolderSyncStatus({this.progress, this.last, this.message});

  /// `null` quando non sta girando niente.
  final SyncProgress? progress;
  final SyncReport? last;

  /// Perché un giro non è partito.
  final String? message;

  bool get running => progress != null;
}

class FolderSyncRun extends Notifier<FolderSyncStatus> {
  bool _cancelled = false;

  @override
  FolderSyncStatus build() {
    unawaited(refresh());
    return const FolderSyncStatus();
  }

  /// Rilegge l'esito dal disco: il giro programmato può essere passato
  /// mentre l'app era chiusa.
  Future<void> refresh() async {
    final last = await ref.read(syncFilesProvider).readReport();
    if (!state.running) {
      state = FolderSyncStatus(last: last, message: state.message);
    }
  }

  Future<void> run() async {
    if (state.running) return;
    _cancelled = false;
    state = FolderSyncStatus(
      progress: const SyncProgress(SyncPhase.listing),
      last: state.last,
    );
    try {
      final report = await runFolderSync(
        ref.read(syncFilesProvider),
        ref.read(driveAuthProvider),
        onProgress: (progress) => state =
            FolderSyncStatus(progress: progress, last: state.last),
        cancelled: () => _cancelled,
      );
      state = FolderSyncStatus(
        last: report ?? state.last,
        message: report == null ? currentL10n().dataSyncMissingFolderOrDirection : null,
      );
      // Quello che è sceso cambia la libreria: capitoli nuovi sul telefono,
      // indici più recenti.
      if (report != null && report.downloaded + report.deletedLocal > 0) {
        ref.invalidate(libraryCatalogProvider);
      }
    } on SyncBusy catch (busy) {
      state = FolderSyncStatus(last: state.last, message: '$busy');
    }
  }

  void cancel() => _cancelled = true;
}

final folderSyncRunProvider =
    NotifierProvider<FolderSyncRun, FolderSyncStatus>(FolderSyncRun.new);

/// Il tema scelto dall'utente. Lo scuro resta il predefinito — si legge di
/// sera — ma sceglierlo deve essere possibile.
class ThemeChoice extends AsyncNotifier<ThemeMode> {
  static const String _key = 'theme.mode';

  @override
  Future<ThemeMode> build() async {
    final value = await ref.watch(userRepositoryProvider).readSetting(_key);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(userRepositoryProvider).writeSetting(_key, mode.name);
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeChoice, ThemeMode>(ThemeChoice.new);

/// La lingua dell'interfaccia; `null` segue quella del sistema. Sta fra le
/// impostazioni del database, quindi segue il lettore su un telefono nuovo.
class AppLanguage extends AsyncNotifier<Locale?> {
  static const String _key = 'app.locale';

  @override
  Future<Locale?> build() async {
    final value = await ref.watch(userRepositoryProvider).readSetting(_key);
    return AppLocalizations.supportedLocales
        .where((locale) => locale.languageCode == value)
        .firstOrNull;
  }

  Future<void> set(Locale? locale) async {
    state = AsyncData(locale);
    await ref
        .read(userRepositoryProvider)
        .writeSetting(_key, locale?.languageCode ?? '');
  }
}

final appLanguageProvider =
    AsyncNotifierProvider<AppLanguage, Locale?>(AppLanguage.new);

/// Le statistiche, ricalcolate quando la cronologia cambia.
final statisticsProvider = FutureProvider<ReadingStatistics>((ref) async {
  ref.watch(readingProvider);
  return StatisticsRepository(ref.watch(databaseProvider)).load();
});

/// Lettura in incognito: mentre è attiva l'app non registra né posizione, né
/// capitoli finiti, né tempo di lettura. È una scelta esplicita dell'utente,
/// quindi va ricordata: sopravvive alla chiusura dell'app.
class Incognito extends AsyncNotifier<bool> {
  static const String _key = 'reader.incognito';

  @override
  Future<bool> build() async =>
      await ref.watch(userRepositoryProvider).readSetting(_key) == 'true';

  Future<void> toggle() async {
    final value = !(state.value ?? false);
    state = AsyncData(value);
    await ref.read(userRepositoryProvider).writeSetting(_key, '$value');
  }
}

final incognitoProvider = AsyncNotifierProvider<Incognito, bool>(Incognito.new);

/// Le destinazioni della navigazione. Stanno nel grafo e non nella shell
/// perché anche le raccolte automatiche vi mandano l'utente.
enum ShellTab { home, library, collections, settings }

class ShellTabNotifier extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.home;

  void show(ShellTab tab) => state = tab;
}

final shellTabProvider =
    NotifierProvider<ShellTabNotifier, ShellTab>(ShellTabNotifier.new);

/// La coda dei download dai siti, i suoi file nello spazio dell'app.
final archiveFilesProvider = Provider<ArchiveFiles>(
  (ref) => ArchiveFiles(ref.watch(appDirectoriesProvider).support),
);

/// Quello che la schermata «Scarica un manga» mostra: com'è la coda adesso.
class ArchiveView {
  const ArchiveView({
    this.status = const ArchiveStatus(),
    this.jobs = const [],
    this.history = const [],
    this.tracked = const [],
    this.check = const CheckSettings(),
    this.alive = false,
  });

  final ArchiveStatus status;
  final List<ArchiveJob> jobs;
  final List<ArchiveOutcome> history;
  final List<TrackedSeries> tracked;
  final CheckSettings check;

  /// Il giro tiene vivo il suo lucchetto: senza, lo stato «in corso» è
  /// quello rimasto da un processo morto a metà.
  final bool alive;

  /// Il lavoro che sta girando, se è ancora in coda.
  ArchiveJob? get current => status.state == ArchiveState.running && alive
      ? jobs.where((job) => job.id == status.jobId).firstOrNull
      : null;
}

/// Rilegge la coda dal disco ogni secondo finché qualcuno la guarda: il
/// giro la scrive da un altro motore, e non c'è un canale per saperlo prima.
class ArchiveController extends Notifier<ArchiveView> {
  Timer? _timer;
  String? _lastOutcome;

  @override
  ArchiveView build() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(refresh()));
    ref.onDispose(() => _timer?.cancel());
    unawaited(refresh());
    return const ArchiveView();
  }

  ArchiveFiles get _files => ref.read(archiveFilesProvider);

  Future<void> refresh() async {
    final files = _files;
    final view = ArchiveView(
      status: await files.status(),
      jobs: await files.jobs(),
      history: await files.history(),
      tracked: await Tracking(files.ongoing).load(),
      check: await files.settings(),
      alive: await files.running(),
    );
    if (!ref.mounted) return;
    // Una serie finita cambia la libreria: la si rilegge, da Drive compresa.
    final latest = view.history.firstOrNull;
    final marker = latest == null ? '' : '${latest.finishedAt}';
    if (_lastOutcome != null && marker != _lastOutcome) {
      ref.read(driveRepositoryProvider)?.refresh();
      ref.invalidate(libraryCatalogProvider);
    }
    _lastOutcome = marker;
    state = view;
  }

  Future<void> enqueue(ArchiveJob job) async {
    await _files.enqueue(job);
    await const ArchiveScheduler().start();
    await refresh();
  }

  /// Toglie un lavoro dalla coda; se è quello che gira, lo ferma e fa
  /// ripartire la coda dal seguente.
  Future<void> remove(ArchiveJob job) async {
    final running = state.current?.id == job.id;
    if (running) await const ArchiveScheduler().stop();
    await _files.remove(job.id);
    if (running && (await _files.jobs()).isNotEmpty) {
      // Il lavoro fermato ha ancora qualche istante per chiudersi: la coda
      // riparte dopo, altrimenti WorkManager terrebbe quello vecchio.
      await Future<void>.delayed(const Duration(seconds: 2));
      await const ArchiveScheduler().start();
    }
    await refresh();
  }

  /// Fa ripartire una coda rimasta ferma, per esempio in attesa della rete.
  Future<void> resume() async {
    await const ArchiveScheduler().start();
    await refresh();
  }

  Future<void> clearHistory() async {
    await _files.clearHistory();
    await refresh();
  }

  Future<void> forget(TrackedSeries series) async {
    await Tracking(_files.ongoing).forget(series.key);
    await refresh();
  }

  Future<void> setCheck(CheckSettings settings) async {
    await _files.writeSettings(settings);
    await const ArchiveScheduler().apply(settings);
    await refresh();
  }

  /// Il controllo delle serie in corso adesso, qui nell'app: sono poche
  /// pagine, e i capitoli nuovi li scarica poi la coda.
  Future<CheckReport> checkNow() async {
    final report = await Tracking(_files.ongoing).check(
      _files,
      (provider) => SiteHttp(provider.allowedHost),
    );
    if (report.queued.isNotEmpty) await const ArchiveScheduler().start();
    await refresh();
    return report;
  }
}

final archiveProvider =
    NotifierProvider.autoDispose<ArchiveController, ArchiveView>(ArchiveController.new);

/// Le serie scaricate «man mano»: a ogni stato di lettura pubblicato —
/// uscendo dal lettore — e a ogni libreria riletta si guarda se davanti al
/// lettore mancano capitoli, e si mettono in coda. Vive accanto alla shell,
/// come [arrivalsProvider], perché si legge da ogni destinazione.
///
/// Le serie le segue chi le scarica: la coda del telefono o il server
/// collegato. Il server non sa cosa si legge, quindi anche per le sue i
/// capitoli li chiede l'app: quelli che l'indice conosce in coda sul server
/// (`POST /v2/jobs` con `ahead` e `automatic`), quelli nuovi del sito con
/// `PUT /v2/ongoing/{key}`, che li fa cercare a lui.
class ReadAhead extends Notifier<void> {
  Future<void> _work = Future.value();
  Timer? _soon;

  /// L'ultimo download finito visto qui, dal telefono e dal server: uno più
  /// recente vuol dire capitoli che la libreria in memoria non conosce
  /// ancora, e che altrimenti si rimetterebbero in coda.
  DateTime? _seenLocal;
  DateTime? _seenServer;

  /// Il controllo sul sito per una serie arrivata in fondo: non a ogni
  /// uscita dal lettore, che in fondo alla serie sono tutte uguali.
  static const Duration _recheck = Duration(hours: 6);

  @override
  void build() {
    ref.listen(readingProvider, (_, _) => _schedule());
    ref.listen(libraryCatalogProvider, (_, _) => _schedule());
    ref.onDispose(() => _soon?.cancel());
  }

  /// Pubblicare lo stato e rileggere la libreria arrivano spesso insieme.
  void _schedule() {
    _soon?.cancel();
    _soon = Timer(const Duration(seconds: 2), () {
      _work = _work.then((_) => _plan()).catchError((Object _) {});
    });
  }

  /// Il catalogo è più vecchio dell'ultimo download finito: lo si rilegge,
  /// e il catalogo nuovo fa ripartire il giro.
  bool _stale(DateTime? latest, DateTime? seen) {
    if (seen == null || latest == null || latest == seen) return false;
    ref.read(driveRepositoryProvider)?.refresh();
    ref.invalidate(libraryCatalogProvider);
    return true;
  }

  /// Cosa manca davanti al lettore per la serie [key], con [pending]
  /// capitoli già in coda; `null` se la libreria non la conosce ancora.
  Future<AheadPlan?> _planOf(String key, int window, Set<String> pending) async {
    final catalog = ref.read(libraryCatalogProvider).value;
    final library = ref.read(libraryProvider);
    final reading = ref.read(readingProvider).value;
    if (catalog == null || library == null || reading == null) return null;
    final row = catalog.index.series.firstWhereOrNull((row) => row.key == key);
    if (row == null) return null;
    final chapters = await library.loadSeries(row, catalog.holders[key] ?? const []);
    if (chapters == null) return null;
    return planAhead(
      chapters: chapters.index.chapters,
      state: reading.of(key),
      pending: pending,
      window: window,
    );
  }

  static bool _due(DateTime? checked) => checked == null || DateTime.now().difference(checked) > _recheck;

  Future<void> _plan() async {
    if (await _planServer()) return;
    await _planPhone();
  }

  /// `true` se il catalogo va riletto prima di decidere.
  Future<bool> _planServer() async {
    final link = ref.read(serverLinkProvider).value;
    if (link == null) return false;
    final client = serverClient(ref, link);
    try {
      final smart = [for (final series in await client.ongoing()) if (series.ahead != null) series];
      if (smart.isEmpty) return false;
      final queue = await client.queue();
      final seen = _seenServer;
      _seenServer = queue.history.firstOrNull?.finishedAt;
      if (_stale(_seenServer, seen)) return true;
      for (final series in smart) {
        final same = [for (final job in queue.jobs) if (job.url == series.url) job];
        if (same.any((job) => job.ids == null)) continue;
        final plan = await _planOf(series.key, series.ahead!, {for (final job in same) ...?job.ids});
        if (plan == null) continue;
        if (plan.enqueue.isNotEmpty) {
          await client.enqueue(
            url: series.url,
            title: series.title,
            ids: plan.enqueue.toSet(),
            ahead: series.ahead,
            automatic: true,
          );
        }
        if (plan.wanted != series.wanted) await client.want(series.key, plan.wanted);
      }
    } on ServerException {
      // Server spento, account non ammesso, versione vecchia: ci si riprova
      // alla prossima uscita dal lettore.
    } on IOException {
      // Lo stesso, senza rete.
    } finally {
      client.close();
    }
    return false;
  }

  Future<void> _planPhone() async {
    final files = ref.read(archiveFilesProvider);
    final tracking = Tracking(files.ongoing);
    final smart = [for (final entry in await tracking.load()) if (entry.ahead != null) entry];
    if (smart.isEmpty) return;
    final seen = _seenLocal;
    _seenLocal = (await files.history()).firstOrNull?.finishedAt;
    if (_stale(_seenLocal, seen)) return;
    final jobs = await files.jobs();
    var queued = false;
    final check = <String>{};
    for (final entry in smart) {
      final same = [for (final job in jobs) if (job.url == entry.url) job];
      // Una serie che scende per intero, o da un capitolo in poi, porta già
      // tutto quello che si potrebbe chiedere.
      if (same.any((job) => job.ids == null)) continue;
      final plan = await _planOf(entry.key, entry.ahead!, {for (final job in same) ...?job.ids});
      if (plan == null) continue;
      if (plan.enqueue.isNotEmpty) {
        await files.enqueue(ArchiveJob(
          id: 'ahead-${entry.key}-${DateTime.now().millisecondsSinceEpoch}',
          url: entry.url,
          title: entry.title,
          target: entry.target,
          ids: plan.enqueue.toSet(),
          automatic: true,
          ahead: entry.ahead,
        ));
        queued = true;
      }
      await tracking.want(entry.key, plan.wanted);
      if (plan.wanted > 0 && _due(entry.checkedAt)) check.add(entry.key);
    }
    if (check.isNotEmpty) {
      try {
        final report = await tracking.check(files, (provider) => SiteHttp(provider.allowedHost), only: check);
        if (report.queued.isNotEmpty) queued = true;
      } on ProviderOffline {
        // Lo rifà il controllo quotidiano, o la prossima uscita dal lettore.
      }
    }
    if (queued) await const ArchiveScheduler().start();
  }
}

final readAheadProvider = NotifierProvider<ReadAhead, void>(ReadAhead.new);

/// Il server che scarica al posto del telefono: il suo indirizzo. Sta fra
/// le impostazioni del database, quindi viaggia con backup e account come la
/// cartella di Drive: su un telefono nuovo il server è già collegato, e chi
/// chiama lo dice l'account, non il telefono.
class ServerLinkNotifier extends AsyncNotifier<ServerLink?> {
  static const String _key = 'server.link';

  @override
  Future<ServerLink?> build() async {
    final value = await ref.watch(userRepositoryProvider).readSetting(_key);
    if (value == null || value.isEmpty) return null;
    try {
      return ServerLink.fromJson(jsonDecode(value) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  Future<void> choose(ServerLink? link) async {
    state = AsyncData(link);
    await ref
        .read(userRepositoryProvider)
        .writeSetting(_key, link == null ? '' : jsonEncode(link.toJson()));
  }
}

final serverLinkProvider =
    AsyncNotifierProvider<ServerLinkNotifier, ServerLink?>(ServerLinkNotifier.new);

final serverAccessProvider = Provider<ServerAccess>((ref) => const ServerAccess());

/// Un client per [link] con il token dell'account di adesso.
ServerClient serverClient(Ref ref, ServerLink link) {
  final access = ref.read(serverAccessProvider);
  return ServerClient(link, access.idToken);
}

/// Gli inviti ai server degli altri per l'account con cui si è fatto
/// l'accesso. Senza le regole di Firestore pubblicate la lettura fallisce:
/// non ci sono inviti, e basta.
final serverInvitesProvider = StreamProvider<List<ServerInvite>>((ref) {
  final email = ref.watch(cloudAccountProvider.select((status) => status.account?.email));
  if (!cloudAvailable || email == null || email.isEmpty) return Stream.value(const []);
  return ref
      .watch(serverAccessProvider)
      .invitesFor(email)
      .handleError((Object _) {}, test: (error) => error is FirebaseException);
});

/// Dà notizia di un invito una volta sola: gli id già annunciati stanno fra
/// le impostazioni, così un secondo telefono con lo stesso account non
/// ripete la notifica dopo la sincronizzazione.
Future<void> announceServerInvites(UserRepository user, List<ServerInvite> invites, {String? linked}) async {
  const key = 'server.invites.seen';
  final seen = {...(await user.readSetting(key) ?? '').split(',').where((id) => id.isNotEmpty)};
  final fresh = [for (final invite in invites) if (!seen.contains(invite.id) && invite.url != linked) invite];
  if (fresh.isEmpty) return;
  for (final invite in fresh) {
    await ArrivalNotifications.instance.invite(
      invite.id,
      title: currentL10n().dataServerInviteTitle(invite.sender),
      text: currentL10n().dataServerInviteText(invite.serverName),
    );
  }
  await user.writeSetting(key, {...seen, for (final invite in fresh) invite.id}.join(','));
}

/// Il server come lo mostra «Scarica un manga».
class RemoteArchiveView {
  const RemoteArchiveView({
    this.link,
    this.info,
    this.queue = const RemoteQueue(),
    this.ongoing = const [],
    this.users = const [],
    this.error,
    this.unauthorized = false,
  });

  final ServerLink? link;

  /// L'ultima presentazione del server; `null` finché non ha risposto.
  final ServerInfo? info;
  final RemoteQueue queue;
  final List<RemoteSeries> ongoing;

  /// Gli account ammessi, solo per il proprietario.
  final List<ServerUser> users;

  /// Perché l'ultima richiesta non è andata, se non è andata.
  final String? error;
  final bool unauthorized;

  /// Se gli si possono mandare lavori adesso.
  bool get ready => error == null && (info?.ready ?? false);

  RemoteArchiveView copyWith({
    ServerInfo? info,
    RemoteQueue? queue,
    List<RemoteSeries>? ongoing,
    List<ServerUser>? users,
    String? error,
    bool clearError = false,
    bool? unauthorized,
  }) =>
      RemoteArchiveView(
        link: link,
        info: info ?? this.info,
        queue: queue ?? this.queue,
        ongoing: ongoing ?? this.ongoing,
        users: users ?? this.users,
        error: clearError ? null : error ?? this.error,
        unauthorized: unauthorized ?? this.unauthorized,
      );
}

/// Chiede al server a che punto è, ogni tre secondi finché la schermata è
/// aperta. Il server non spinge niente: un canale aperto apposta terrebbe
/// sveglia la radio anche a schermata chiusa, e chi guarda la coda la guarda
/// da qui.
class RemoteArchiveController extends Notifier<RemoteArchiveView> {
  ServerClient? _client;
  Timer? _timer;
  int _tick = 0;
  String? _lastOutcome;

  @override
  RemoteArchiveView build() {
    final link = ref.watch(serverLinkProvider).value;
    if (link == null) return const RemoteArchiveView();
    // Un altro account è un altro utente per il server: coda, Drive e
    // permessi si rileggono da capo.
    final email = ref.watch(cloudAccountProvider.select((status) => status.account?.email));
    if (email == null) {
      return RemoteArchiveView(link: link, error: currentL10n().dataServerSignInRequired, unauthorized: true);
    }
    final client = _client = serverClient(ref, link);
    _tick = 0;
    _lastOutcome = null;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(refresh()));
    ref.onDispose(() {
      _timer?.cancel();
      client.close();
      if (identical(_client, client)) _client = null;
    });
    unawaited(refresh(full: true));
    return RemoteArchiveView(link: link);
  }

  /// La coda sempre; presentazione, serie in corso e utenti ogni mezzo
  /// minuto, o dopo un gesto che le cambia.
  Future<void> refresh({bool full = false}) async {
    final client = _client;
    if (client == null) return;
    final every = full || _tick++ % 10 == 0;
    try {
      final info = every || state.info == null ? await client.info() : null;
      final queue = await client.queue();
      final ongoing = every ? await client.ongoing() : null;
      final users = every && (info ?? state.info)?.isOwner == true ? await client.users() : null;
      if (!ref.mounted || client != _client) return;
      // Una serie finita sul server è su Drive: la libreria si rilegge.
      final latest = queue.history.firstOrNull;
      final marker = latest == null ? '' : '${latest.finishedAt}';
      if (_lastOutcome != null && marker != _lastOutcome) {
        ref.read(driveRepositoryProvider)?.refresh();
        ref.invalidate(libraryCatalogProvider);
      }
      _lastOutcome = marker;
      if (info != null) await _delegate(info);
      state = state.copyWith(
        info: info,
        queue: queue,
        ongoing: ongoing,
        users: users,
        clearError: true,
        unauthorized: false,
      );
    } on ServerException catch (error) {
      if (!ref.mounted || client != _client) return;
      state = state.copyWith(
        error: error.message,
        unauthorized: error is ServerUnauthorized || error is ServerForbidden,
      );
    }
  }

  ServerClient get _live => _client ?? (throw ServerException(state.error ?? currentL10n().dataServerNotLinked));

  Future<RemoteJob> enqueue({
    required String url,
    required String title,
    String? start,
    Set<String>? ids,
    int? delayMs,
    String? snapshot,
    int? ahead,
  }) async {
    final job = await _live.enqueue(
      url: url,
      title: title,
      start: start,
      ids: ids,
      delayMs: delayMs,
      snapshot: snapshot,
      ahead: ahead,
    );
    await refresh();
    return job;
  }

  Future<void> cancel(RemoteJob job) async {
    await _live.cancel(job.id);
    await refresh();
  }

  Future<void> clearHistory() async {
    await _live.clearHistory();
    await refresh();
  }

  Future<void> forget(RemoteSeries series) async {
    await _live.forget(series.key);
    await refresh(full: true);
  }

  Future<void> check() => _live.check();

  /// Il controllo quotidiano del server per questo account.
  Future<void> configureCheck({bool? enabled, int? minutes, bool? library}) async {
    final check = await _live.configureCheck(enabled: enabled, minutes: minutes, library: library);
    final info = state.info?.withCheck(check);
    if (info == null) return;
    await _delegate(info);
    state = state.copyWith(info: info);
  }

  /// Il controllo del telefono lascia al server le serie della cartella di
  /// cui il server guarda ogni giorno tutta la libreria.
  Future<void> _delegate(ServerInfo info) => ref.read(archiveFilesProvider).delegate(
        info.ready && info.check.enabled && info.check.library ? info.folderId : null,
      );

  /// Dice al server di scrivere nella cartella di Drive che legge l'app.
  Future<void> useFolder(DriveFolder folder) async {
    final chosen = await _live.chooseFolder(folder.id);
    final info = state.info;
    if (info != null) {
      state = state.copyWith(info: info.withDrive(authorized: info.driveAuthorized, id: chosen.id, name: chosen.name));
    }
    await refresh(full: true);
  }

  /// Ammette un account e lo avvisa: l'invito lo trova la sua app.
  Future<void> addUser(String email) async {
    final user = await _live.addUser(email);
    await refresh(full: true);
    final link = state.link;
    if (link == null) return;
    try {
      await ref
          .read(serverAccessProvider)
          .invite(to: user.email, url: link.url, serverName: state.info?.name ?? 'Kagami Server');
    } on FirebaseException {
      throw ServerException(currentL10n().dataServerUserNotNotified(user.email, link.url.toString()));
    }
  }

  Future<void> removeUser(ServerUser user) async {
    await _live.removeUser(user.email);
    await refresh(full: true);
    final link = state.link;
    if (link == null) return;
    try {
      await ref.read(serverAccessProvider).withdraw(user.email, link.url);
    } on FirebaseException {
      // L'invito rimasto non apre niente: il server non lo ammette più.
    }
  }

  /// Scollega il server da questo account. Chi non è il proprietario gli
  /// fa anche dimenticare il suo Drive e la sua coda; il proprietario no,
  /// perché il suo permesso è quello del comando di avvio.
  Future<void> unlink() async {
    final client = _client;
    if (client != null && state.info?.isOwner == false) {
      try {
        await client.forgetDrive();
      } on ServerException {
        // Anche spento o irraggiungibile il server si scollega: il permesso
        // lo si può togliere anche da myaccount.google.com.
      }
    }
    await ref.read(archiveFilesProvider).delegate(null);
    await ref.read(serverLinkProvider.notifier).choose(null);
  }
}

final remoteArchiveProvider =
    NotifierProvider.autoDispose<RemoteArchiveController, RemoteArchiveView>(
  RemoteArchiveController.new,
);
