/// Da Drive al telefono: il pulsante «Scarica».
///
/// Un capitolo scaricato finisce **nello stesso albero MALF** in cui l'avrebbe
/// messo FolderSync — `<serie>/chapters/<capitolo>/0001.webp` — nella
/// cartella scelta dall'utente, o nello spazio privato dell'app se una
/// cartella non c'è. Da lì la sorgente locale lo trova da sé, e il lettore lo
/// legge con la strada di sempre.
///
/// Due cose l'app non fa:
///
/// * **non riscrive `library.json`.** Con FolderSync in entrambe le
///   direzioni, una versione scritta qui salirebbe su Drive al posto di
///   quella del server. Le serie scaricate si ricordano in
///   `reading/downloads.json`, che è lo spazio dell'app per contratto;
/// * **non lascia capitoli a metà.** Le tavole vanno in `<capitolo>.part` e
///   la cartella prende il suo nome solo a capitolo completo: un capitolo sul
///   telefono è sempre un capitolo intero.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../format/malf.dart';
import 'drive.dart';
import 'drive_library.dart';
import 'library_repository.dart';

/// A che punto è il download di un capitolo.
class DownloadProgress {
  const DownloadProgress({
    required this.done,
    required this.total,
    this.error,
    this.queued = false,
    this.waiting = false,
  });

  final int done;
  final int total;
  final Object? error;

  /// In coda dietro ad altri capitoli.
  final bool queued;

  /// Fermo perché manca la rete: riparte da solo quando torna, da dove era.
  final bool waiting;

  double get fraction => total == 0 ? 0 : done / total;
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

class ChapterDownloader {
  ChapterDownloader(this.drive, this.files);

  final DriveRepository drive;
  final DriveFiles files;

  /// Tavole scaricate insieme dentro un capitolo.
  static const int _atOnce = 4;

  Future<void> download({
    required String destination,
    required SeriesEntry entry,
    required ChapterEntry chapter,
    required List<PageEntry> pages,
    required void Function(int done, int total) onPage,
    required bool Function() cancelled,
  }) async {
    final path = chapter.path;
    if (path == null || pages.isEmpty) {
      throw const DriveException('Il capitolo non ha tavole su Drive');
    }
    final target = Directory(p.join(destination, entry.path, path));
    final partial = Directory('${target.path}$partialSuffix');
    await partial.create(recursive: true);
    // Le tessere scendono con le tavole: sono ciò che il lettore legge, e la
    // tavola resta perché la cartella è una copia dell'archivio.
    final tiles = {for (final page in pages) ...page.tiles.map((tile) => tile.file)};
    final queue = [...pages.map((page) => page.file), ...tiles];
    final total = queue.length;
    var done = 0;
    onPage(done, total);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        if (cancelled()) throw const DownloadCancelled();
        final name = queue.removeAt(0);
        final file = File(p.join(partial.path, name));
        if (!await file.exists()) {
          try {
            await _fetchPage(entry, p.posix.join(path, name), file);
          } on DriveOffline {
            rethrow;
          } on DriveException {
            // Una tessera che su Drive non c'è non è una tavola persa: il
            // lettore legge la tavola al suo posto.
            if (!tiles.contains(name)) rethrow;
          }
        }
        onPage(++done, total);
      }
    }

    try {
      await Future.wait([for (var i = 0; i < _atOnce; i++) worker()]);
    } on DownloadCancelled {
      // Annullare vuol dire non volerlo: le tavole già scaricate non restano
      // a occupare spazio in una cartella che nessuno vede.
      await partial.delete(recursive: true).catchError((_) => partial);
      rethrow;
    }
    if (await target.exists()) {
      // Una cartella c'è già: FolderSync ne ha portato una parte. Si
      // completano i file che mancano senza toccare quelli che ha messo lui.
      await for (final entity in partial.list()) {
        final destinationFile = File(p.join(target.path, p.basename(entity.path)));
        if (entity is File && !await destinationFile.exists()) {
          await entity.rename(destinationFile.path);
        }
      }
      await partial.delete(recursive: true);
    } else {
      await partial.rename(target.path);
    }
  }

  /// Una tavola già letta in streaming sta in cache: si copia invece di
  /// riscaricarla.
  Future<void> _fetchPage(SeriesEntry entry, String relative, File file) async {
    // Su una rete a scatti una tavola persa per strada si riprova subito, da
    // dove era arrivata; solo se la rete non c'è davvero si ferma il capitolo.
    for (var attempt = 1;; attempt++) {
      try {
        return await _fetchPageOnce(entry, relative, file);
      } on DriveOffline {
        if (attempt >= 3 || !await drive.client.network.check()) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
      }
    }
  }

  Future<void> _fetchPageOnce(SeriesEntry entry, String relative, File file) async {
    final address = drive.locate(entry, relative);
    final temporary = File('${file.path}.tmp');
    final cached = files.peek(address);
    if (cached != null) {
      await File(cached).copy(temporary.path);
    } else {
      final item = await drive.resolve('${entry.path}/$relative');
      if (item == null) throw const DriveException('Tavola non trovata su Drive');
      await drive.client.download(item.id, temporary);
    }
    await temporary.rename(file.path);
  }

  /// Quello che serve perché la serie si legga anche senza Drive: gli
  /// indici accanto ai capitoli, le copertine e la riga in
  /// `reading/downloads.json`.
  ///
  /// Gli indici si sovrascrivono con quelli di Drive: sono la versione più
  /// recente di ciò che FolderSync porterebbe comunque, quindi non si torna
  /// mai indietro.
  Future<void> finishSeries({
    required String destination,
    required SeriesEntry entry,
  }) async {
    final folder = Directory(p.join(destination, entry.path));
    await folder.create(recursive: true);
    for (final name in [seriesIndexFile, pagesIndexFile, 'series.json']) {
      final text = await drive.seriesText(entry, name);
      if (text != null) await _writeAtomically(File(p.join(folder.path, name)), text);
    }
    for (final name in {entry.cover, entry.coverThumbnail}.nonNulls) {
      final file = File(p.join(folder.path, name));
      if (await file.exists()) continue;
      try {
        await _fetchPage(entry, name, file);
      } on DriveException {
        // Una copertina che non arriva non vale il capitolo: si vedrà quella
        // di Drive, o il segnaposto.
      }
    }
    final present = await LibraryRepository(destination).presentChapters(entry);
    await _remember(destination, entry.copyWith(archivedChapterCount: present.length));
  }

  Future<void> _remember(String destination, SeriesEntry entry) async {
    final file = File(p.join(destination, readingDirectory, downloadsFile));
    final rows = <Map<String, Object?>>[];
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString());
        if (data is Map && data['series'] is List) {
          rows.addAll((data['series'] as List).whereType<Map<String, Object?>>());
        }
      } on FormatException {
        // Un elenco rovinato si riscrive: le cartelle sono ancora lì, e alla
        // prossima serie scaricata tornano a comparire.
      }
    }
    rows
      ..removeWhere((row) => row['key'] == entry.key)
      ..add(entry.toJson());
    await file.parent.create(recursive: true);
    await _writeAtomically(
      file,
      jsonEncode({'format': malfFormat, 'formatVersion': malfFormatVersion, 'series': rows}),
    );
  }

  static Future<void> _writeAtomically(File file, String text) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(text);
    await temporary.rename(file.path);
  }
}
