/// Accesso alla libreria su disco.
///
/// Tutto il JSON viene decodificato in un isolate: `library.json` di una
/// libreria grande arriva a qualche centinaio di kilobyte e decodificarlo sul
/// thread della UI perderebbe frame proprio all'apertura dell'app.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../format/malf.dart';
import 'library.dart';

/// Motivo per cui una cartella non è una libreria utilizzabile.
enum LibraryProblem {
  missing('La cartella non esiste o non è leggibile.'),
  notIndexed('La cartella non contiene library.json: vanno rigenerati gli '
      'indici con l\'archiviatore che ha scritto la libreria.'),
  unreadable('library.json non è leggibile o non è un indice MALF valido.'),
  unsupported('library.json usa una versione del formato più recente di questa app.');

  const LibraryProblem(this.message);

  final String message;
}

class LibraryException implements Exception {
  const LibraryException(this.problem);

  final LibraryProblem problem;

  @override
  String toString() => problem.message;
}

Map<String, Object?> _decode(String source) {
  final data = jsonDecode(source);
  if (data is! Map<String, Object?>) throw const FormatException('Radice non valida.');
  return data;
}

LibraryIndex _parseLibrary(String source) => LibraryIndex.fromJson(_decode(source));

SeriesIndex _parseSeries(String source) => SeriesIndex.fromJson(_decode(source));

PagesIndex _parsePages(String source) => PagesIndex.fromJson(_decode(source));

/// Dove l'app ricorda le serie che ha scaricato da Drive in una cartella.
///
/// `library.json` lo scrive l'archivio e l'app non lo tocca: con FolderSync
/// in entrambe le direzioni una versione riscritta qui finirebbe su Drive al
/// posto di quella del server. `reading/` invece è dell'app per contratto.
const String downloadsFile = 'downloads.json';

/// Il suffisso di un capitolo che si sta ancora scaricando.
const String partialSuffix = '.part';

/// Una cartella del telefono che contiene una libreria MALF.
class LibraryRepository implements LibraryShelf {
  LibraryRepository(this.root, {this.requireIndex = true, this.private = false});

  final String root;

  /// Se una cartella senza `library.json` è un errore. Non lo è quando c'è
  /// Drive: la cartella può contenere soltanto ciò che l'app vi ha scaricato.
  final bool requireIndex;

  /// Lo spazio privato dell'app, dove finiscono i download quando l'utente
  /// non ha scelto una cartella.
  final bool private;

  @override
  LibraryOrigin get origin => LibraryOrigin.local;

  File get _libraryFile => File(p.join(root, libraryIndexFile));

  File get downloads => File(p.join(root, readingDirectory, downloadsFile));

  @override
  Future<LibraryIndex> loadLibrary() async {
    final downloaded = await _loadDownloads();
    if (!await Directory(root).exists()) {
      if (!requireIndex) return LibraryIndex.empty;
      throw const LibraryException(LibraryProblem.missing);
    }
    if (!await _libraryFile.exists()) {
      if (!requireIndex || downloaded.isNotEmpty) {
        return _withDownloads(LibraryIndex.empty, downloaded);
      }
      throw const LibraryException(LibraryProblem.notIndexed);
    }
    final String source;
    try {
      source = await _libraryFile.readAsString();
    } on IOException {
      throw const LibraryException(LibraryProblem.unreadable);
    }
    final Map<String, Object?> head;
    try {
      head = _decode(source);
    } on FormatException {
      throw const LibraryException(LibraryProblem.unreadable);
    }
    if (head['format'] != malfFormat) {
      throw const LibraryException(LibraryProblem.unreadable);
    }
    if ((head['formatVersion'] as num? ?? 0) > malfFormatVersion) {
      throw const LibraryException(LibraryProblem.unsupported);
    }
    return _withDownloads(await compute(_parseLibrary, source), downloaded);
  }

  Future<List<SeriesEntry>> _loadDownloads() async {
    if (!await downloads.exists()) return const [];
    try {
      return (await compute(_parseLibrary, await downloads.readAsString()))
          .series;
    } on FormatException {
      return const [];
    } on IOException {
      return const [];
    }
  }

  /// Le serie scaricate si aggiungono a quelle dell'indice; quelle che
  /// l'indice conosce già restano come le descrive lui.
  LibraryIndex _withDownloads(LibraryIndex index, List<SeriesEntry> downloaded) {
    if (downloaded.isEmpty) return index;
    final known = {for (final entry in index.series) entry.key};
    return LibraryIndex(
      generatedAt: index.generatedAt,
      series: [
        ...index.series,
        ...downloaded.where((entry) => !known.contains(entry.key)),
      ],
      chapterCount: index.chapterCount,
      pageCount: index.pageCount,
      bytes: index.bytes,
    );
  }

  /// Le cartelle dei capitoli che sono davvero sul telefono, come percorsi
  /// relativi alla serie. Una lettura di cartella per serie.
  Future<Set<String>> presentChapters(SeriesEntry entry) async {
    final directory = Directory(p.join(entry.directory(root), 'chapters'));
    try {
      return {
        await for (final child in directory.list(followLinks: false))
          // Un download a metà sta accanto con `.part` in fondo: non è un
          // capitolo finché non viene rinominato.
          if (child is Directory && !child.path.endsWith(partialSuffix))
            p.posix.join('chapters', p.basename(child.path)),
      };
    } on IOException {
      return const {};
    }
  }

  @override
  String locate(SeriesEntry entry, String relative) =>
      p.join(entry.directory(root), relative);

  /// Sul telefono un capitolo tolto non ha più la cartella: lo dice già
  /// [presentChapters].
  @override
  Future<Set<String>> withdrawnChapters(SeriesEntry entry) async => const {};

  /// Quando l'indice è stato riscritto sul disco, per rileggerlo solo se serve.
  Future<DateTime?> libraryModifiedAt() async =>
      await _libraryFile.exists() ? (await _libraryFile.stat()).modified : null;

  @override
  Future<SeriesIndex?> loadSeries(SeriesEntry entry) async {
    final file = File(p.join(entry.directory(root), seriesIndexFile));
    if (!await file.exists()) return null;
    try {
      return await compute(_parseSeries, await file.readAsString());
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  /// Letto solo entrando in lettura: tiene le pagine di tutti i capitoli e in
  /// una serie lunga è il file più pesante della serie.
  @override
  Future<PagesIndex?> loadPages(SeriesEntry entry) async {
    final file = File(p.join(entry.directory(root), pagesIndexFile));
    if (!await file.exists()) return null;
    try {
      return await compute(_parsePages, await file.readAsString());
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  /// Descrizione e metadati estesi, letti solo dalla scheda di dettaglio.
  @override
  Future<Map<String, Object?>?> loadSeriesManifest(SeriesEntry entry) async {
    final file = File(p.join(entry.directory(root), 'series.json'));
    if (!await file.exists()) return null;
    try {
      final data = _decode(await file.readAsString());
      final metadata = data['metadata'];
      return metadata is Map<String, Object?> ? metadata : null;
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  /// Pagine di un capitolo con il percorso già risolto, nell'ordine di lettura.
  List<String> pagePaths(SeriesEntry entry, ChapterEntry chapter, PagesIndex pages) {
    final directory = chapter.directory(root, entry.path);
    if (directory == null) return const [];
    return pages
        .of(chapter.id)
        .map((page) => page.path(directory))
        .toList(growable: false);
  }
}
