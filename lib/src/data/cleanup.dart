/// Liberare spazio dai capitoli già letti.
///
/// Un capitolo letto occupa spazio in tre posti sul telefono — la cartella
/// scelta, lo spazio privato dell'app dove finiscono i download, la cache
/// di Drive — e in uno fuori, Drive stesso. Tutti si svuotano da qui, e solo
/// quando lo chiede l'utente: è l'unico punto in cui l'app cancella
/// qualcosa dalla libreria. Da Drive i capitoli vanno nel cestino, e la
/// sorgente di Drive smette di servirli
/// ([DriveRepository.withdrawChapters]).
///
/// La cartella scelta e Drive sono di solito sincronizzati. Con la
/// sincronizzazione di Kagami ciò che si toglie qui si annota
/// ([SyncFiles.release]), così il giro seguente non lo riporta e non lo
/// toglie dall'altra parte; con FolderSync, che l'app non vede, la
/// cancellazione può arrivare fino a Drive o i capitoli tornare. Per questo
/// [ReadLeftovers.synced] c'è: l'interfaccia lo deve dire prima.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../format/malf.dart';
import 'drive.dart';
import 'drive_library.dart';
import 'folder_sync.dart';
import 'library.dart';
import 'library_repository.dart';

/// Quello che i capitoli letti di una serie occupano sul telefono.
class ReadLeftovers {
  const ReadLeftovers({
    this.entry,
    this.folders = const {},
    this.folderBytes = 0,
    this.syncedPaths = const {},
    this.cached = const {},
    this.cacheBytes = 0,
    this.remote = const {},
    this.remoteBytes = 0,
    this.synced = false,
    this.onDrive = false,
  });

  final SeriesEntry? entry;

  static const ReadLeftovers empty = ReadLeftovers();

  /// Le cartelle dei capitoli letti, per capitolo: lo stesso capitolo può
  /// stare sia nella cartella scelta sia nello spazio dell'app.
  final Map<String, List<String>> folders;

  /// Dall'indice, non dal disco: sommare i file di cento capitoli sarebbe
  /// migliaia di letture a ogni apertura della scheda.
  final int folderBytes;

  /// Le cartelle della cartella scelta, relative alla libreria come le vede
  /// la sincronizzazione.
  final Set<String> syncedPaths;

  /// I capitoli letti che hanno ancora tavole nella cache di Drive.
  final Set<String> cached;
  final int cacheBytes;

  /// I capitoli letti che sono ancora su Drive, con il loro percorso nella
  /// serie. Non contano per la proposta aprendo la scheda — su Drive c'è
  /// tutto ciò che si è letto, e la si farebbe per ogni serie —, ma si
  /// possono togliere dal foglio.
  final Map<String, String> remote;
  final int remoteBytes;

  /// Se qualche cartella sta in quella scelta dall'utente, che di solito è
  /// sincronizzata.
  final bool synced;

  /// Se la serie è anche su Drive: i capitoli tolti dal telefono si
  /// rileggono da lì.
  final bool onDrive;

  /// Niente occupa spazio sul telefono: la scheda non propone niente.
  bool get isEmpty => folders.isEmpty && cached.isEmpty;

  /// C'è qualcosa da togliere, anche solo da Drive.
  bool get offersAnything => !isEmpty || remote.isNotEmpty;

  int get chapterCount => {...folders.keys, ...cached}.length;
}

Future<ReadLeftovers> findReadLeftovers({
  required SeriesEntry entry,
  required SeriesChapters chapters,
  required List<LibraryShelf> holders,
  required Set<String> read,
  DriveFiles? drive,
}) async {
  if (read.isEmpty) return ReadLeftovers.empty;
  final folders = <String, List<String>>{};
  final syncedPaths = <String>{};
  var folderBytes = 0;
  var synced = false;
  for (final shelf in holders.whereType<LibraryRepository>()) {
    final present = await shelf.presentChapters(entry);
    if (present.isEmpty) continue;
    for (final chapter in chapters.index.chapters) {
      final path = chapter.path;
      if (path == null ||
          !read.contains(chapter.id) ||
          !present.contains(p.posix.normalize(path))) {
        continue;
      }
      folders.putIfAbsent(chapter.id, () => []).add(shelf.locate(entry, path));
      folderBytes += chapter.bytes;
      if (!shelf.private) {
        synced = true;
        syncedPaths.add('${entry.path}/${p.posix.normalize(path)}');
      }
    }
  }
  final cached = await drive?.cachedOf(entry.key, read);
  final remote = <String, String>{};
  var remoteBytes = 0;
  final repository = holders.whereType<DriveRepository>().firstOrNull;
  if (repository != null) {
    try {
      final index = await repository.loadSeries(entry);
      final withdrawn = await repository.withdrawnChapters(entry);
      for (final chapter in index?.readable ?? const <ChapterEntry>[]) {
        final path = p.posix.normalize(chapter.path!);
        if (!read.contains(chapter.id) || withdrawn.contains(path)) continue;
        remote[chapter.id] = path;
        remoteBytes += chapter.bytes;
      }
    } on DriveException {
      // Senza Drive si propone quello che c'è sul telefono.
    }
  }
  return ReadLeftovers(
    entry: entry,
    folders: folders,
    folderBytes: folderBytes,
    syncedPaths: syncedPaths,
    cached: cached?.chapters ?? const {},
    cacheBytes: cached?.bytes ?? 0,
    remote: remote,
    remoteBytes: remoteBytes,
    synced: synced,
    onDrive: repository != null,
  );
}

/// Cancella ciò che [leftovers] ha trovato: le cartelle se [folders], la
/// cache di Drive se [cache], i capitoli su Drive se [remote] — con
/// [writer], che ha il permesso di scrivere.
///
/// Ogni cosa tolta si annota per la sincronizzazione ([sync]) prima di
/// toglierla: un'annotazione su qualcosa che c'è ancora non fa niente,
/// mentre una cancellazione non annotata il giro seguente la
/// fraintenderebbe.
Future<void> clearReadLeftovers(
  ReadLeftovers leftovers, {
  required String series,
  required bool folders,
  required bool cache,
  bool remote = false,
  DriveFiles? drive,
  DriveClient? writer,
  SyncFiles? sync,
}) async {
  if (folders) {
    await sync?.release(leftovers.syncedPaths, SyncSide.local);
    for (final path in leftovers.folders.values.expand((paths) => paths)) {
      final directory = Directory(path);
      // Fra la ricerca e la conferma la sincronizzazione può averla già tolta.
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }
  final entry = leftovers.entry;
  if (remote && entry != null && drive != null && writer != null) {
    final paths = leftovers.remote.values;
    await sync?.release(
      [for (final path in paths) '${entry.path}/$path'],
      SyncSide.remote,
    );
    await drive.repository.withdrawChapters(entry, paths, writer);
  }
  // Un capitolo tolto da Drive non si legge più da lì: anche le sue tavole
  // in cache sono spazio perso.
  final forget = {
    if (cache) ...leftovers.cached,
    if (remote) ...leftovers.remote.keys,
  };
  if (forget.isNotEmpty) await drive?.forgetChapters(series, forget);
}
