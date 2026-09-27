/// Il motore dell'archivio: una serie dal sito alla libreria MALF.
///
/// Porting di `Archiver` in `mangaarchive/archive.py`, con le stesse regole:
///
/// * `series.json` è **l'elenco completo** del sito anche se si scarica dal
///   capitolo 16 in poi: i capitoli non scaricati restano visibili al
///   lettore come mancanti invece di sparire;
/// * ogni tavola ha dimensione e SHA-256 nel `chapter.json`, riscritto dopo
///   ogni tavola; `complete: true` arriva solo alla fine. Una ripresa salta
///   le tavole già verificate;
/// * un capitolo che fallisce non ferma gli altri e resta da ritentare. Una
///   rete che manca invece ferma tutto ([ProviderOffline], [DriveOffline]):
///   non è un capitolo sbagliato, è un giro da riprendere.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'drive.dart';
import 'http.dart';
import 'image_tools.dart';
import 'images.dart';
import 'indexes.dart';
import 'model.dart';
import 'names.dart';
import 'providers.dart';
import 'stores.dart';

const int archiveSchemaVersion = 3;

/// Cosa sta succedendo, per chi mostra l'avanzamento.
sealed class ArchiveEvent {
  const ArchiveEvent();
}

class SeriesStarted extends ArchiveEvent {
  const SeriesStarted(this.title, this.total);
  final String title;
  final int total;
}

class ChapterStarted extends ArchiveEvent {
  const ChapterStarted(this.index, this.total, this.title);
  final int index;
  final int total;
  final String title;
}

class PageSaved extends ArchiveEvent {
  const PageSaved(this.page, this.pages, {required this.saved, required this.size});
  final int page;
  final int pages;
  final bool saved;
  final int size;
}

/// Le tavole del capitolo ci sono tutte e partono verso Drive: è la parte
/// lunga, un file per tavola e uno per tessera.
class ChapterUploading extends ArchiveEvent {
  const ChapterUploading(this.title, this.files);
  final String title;
  final int files;
}

class ChapterFinished extends ArchiveEvent {
  const ChapterFinished(this.index, this.total, this.title, {this.error});
  final int index;
  final int total;
  final String title;
  final String? error;
}

class ArchiveCancelled implements Exception {
  const ArchiveCancelled();

  @override
  String toString() => 'Download interrotto';
}

class ArchiveFailure {
  const ArchiveFailure(this.chapter, this.error);
  final String chapter;
  final String error;
}

class ArchiveResult {
  ArchiveResult(this.series, this.folder, this.chapters);

  final Series series;
  final String folder;
  final int chapters;
  int completed = 0;
  int pagesDownloaded = 0;
  int pagesSkipped = 0;
  final List<ArchiveFailure> failed = [];

  /// I capitoli a posto: archiviati ora o saltati per scelta. Il controllo
  /// delle serie in corso non li riscarica.
  final List<String> settled = [];

  Map<String, Object?> metadata = const {};
}

Future<Uint8List?> _verify(File file, Map<String, Object?> record, String url) async {
  if (record['source'] != url || record['sha256'] is! String || !await file.exists()) return null;
  if (await file.length() != record['size']) return null;
  final body = await file.readAsBytes();
  return sha256.convert(body).toString() == record['sha256'] ? body : null;
}

Future<bool> _tileOk(Directory folder, Object? tile) async {
  if (tile is! Map || tile['file'] is! String) return false;
  final file = File(p.join(folder.path, tile['file'] as String));
  if (p.dirname(file.path) != folder.path || !await file.exists()) return false;
  if (await file.length() != tile['size']) return false;
  return sha256.convert(await file.readAsBytes()).toString() == tile['sha256'];
}

Map<String, Object?> _measured(Map<String, Object?> record, Uint8List? body, [Page? page]) {
  Object? width = record['width'];
  Object? height = record['height'];
  bool known(Object? value) => value != null && value != 0;
  if (body != null && !(known(width) && known(height))) {
    final size = imageSize(body);
    width = size?.$1;
    height = size?.$2;
  }
  if (!(known(width) && known(height)) && page != null) {
    width = page.width;
    height = page.height;
  }
  return {...record, 'width': width, 'height': height};
}

Map<String, Object?> _withoutTiles(Map<String, Object?> record) =>
    {for (final entry in record.entries) if (entry.key != 'tiles') entry.key: entry.value};

class Archiver {
  Archiver({
    required this.provider,
    required this.http,
    required this.store,
    required this.scratch,
    this.images = const NoImageTools(),
    this.delay = const Duration(milliseconds: 200),
    this.onEvent,
    this.cancelled,
  });

  final Provider provider;
  final ProviderHttp http;
  final ArchiveStore store;

  /// Una cartella per i file di passaggio (la copertina da ridurre).
  final Directory scratch;
  final ImageTools images;

  /// La pausa fra una richiesta e l'altra: i siti non amano chi scarica a
  /// raffica.
  final Duration delay;
  final void Function(ArchiveEvent event)? onEvent;
  final bool Function()? cancelled;

  void _emit(ArchiveEvent event) => onEvent?.call(event);

  void _check() {
    if (cancelled?.call() ?? false) throw const ArchiveCancelled();
  }

  Future<void> _pause() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  /// Archivia [series]: tutta, i capitoli con gli id in [ids] o quelli dal
  /// capitolo [start] in poi.
  Future<ArchiveResult> download(Series series, {Set<String>? ids, String? start}) async {
    final List<Chapter> selected;
    if (start != null) {
      selected = series.chapters.sublist(startIndex(series.chapters, start));
    } else {
      selected = [
        for (final chapter in series.chapters)
          if (ids == null || ids.contains(chapter.id) || ids.contains(chapter.number)) chapter,
      ];
    }
    if (selected.isEmpty) throw const ProviderError('Nessun capitolo corrisponde alla selezione.');
    final folder = await store.existingFolder(series) ?? seriesFolderName(series);
    final result = ArchiveResult(series, folder, selected.length);
    final metadata = normalizeMetadata(series.metadata);
    result.metadata = metadata;
    final manifest = await _writeSeries(series, folder, metadata, result);
    _emit(SeriesStarted(series.title, selected.length));
    final chosen = {for (final chapter in selected) chapter.id};
    result.settled.addAll([
      for (final chapter in series.chapters)
        if (!chosen.contains(chapter.id)) chapter.id,
    ]);
    var sinceIndex = 0;
    for (var index = 0; index < selected.length; index++) {
      _check();
      final chapter = selected[index];
      _emit(ChapterStarted(index + 1, selected.length, chapter.title));
      final counts = [0, 0];
      try {
        await _chapter(folder, chapter, counts);
        result.completed++;
        result.settled.add(chapter.id);
        _emit(ChapterFinished(index + 1, selected.length, chapter.title));
        sinceIndex++;
      } on ProviderOffline {
        rethrow;
      } on DriveOffline {
        rethrow;
      } on DriveAuthRequired {
        rethrow;
      } on ArchiveCancelled {
        rethrow;
      } on ProviderError catch (error) {
        _fail(result, index, selected.length, chapter, error);
      } on DriveException catch (error) {
        _fail(result, index, selected.length, chapter, error);
      } on FileSystemException catch (error) {
        _fail(result, index, selected.length, chapter, error.message);
      } finally {
        result.pagesDownloaded += counts[0];
        result.pagesSkipped += counts[1];
      }
      // Ogni tanto gli indici si riscrivono anche a metà: una serie lunga
      // compare nella libreria mentre scende, e un giro interrotto lascia
      // leggibile ciò che ha già portato.
      if (sinceIndex >= 10) {
        await refreshIndexes(folder, manifest);
        sinceIndex = 0;
      }
      if (index < selected.length - 1) await _pause();
    }
    try {
      await refreshIndexes(folder, manifest);
    } on DriveOffline {
      rethrow;
    } on DriveException catch (error) {
      // Gli indici sono derivati: ripetere il download li riscrive, invece
      // di perdere il lavoro dei capitoli già saliti.
      result.failed.add(ArchiveFailure('indici di lettura', '$error'));
    }
    return result;
  }

  void _fail(ArchiveResult result, int index, int total, Chapter chapter, Object error) {
    result.failed.add(ArchiveFailure(chapter.title, '$error'));
    _emit(ChapterFinished(index + 1, total, chapter.title, error: '$error'));
  }

  /// Copertina, miniatura e `series.json`.
  Future<Map<String, Object?>> _writeSeries(
    Series series,
    String folder,
    Map<String, Object?> metadata,
    ArchiveResult result,
  ) async {
    final files = <String, Uint8List>{};
    Map<String, Object?>? cover;
    final coverUrl = series.coverUrl;
    if (coverUrl != null) {
      try {
        final old = await store.readJson(p.posix.join(folder, seriesManifestFile));
        final previous = old?['cover'] is Map<String, Object?> ? old!['cover'] as Map<String, Object?> : null;
        final stored = await store.filesIn(folder);
        final name = previous?['file'];
        final kept = previous != null &&
            name is String &&
            previous['source'] == coverUrl &&
            stored[name]?.size == previous['size'];
        Uint8List? body;
        if (kept) {
          cover = previous;
        } else {
          final image = await _image(coverUrl, series.url);
          body = image.body;
          files['cover${image.extension}'] = body;
          cover = _measured({
            'file': 'cover${image.extension}',
            'source': coverUrl,
            'size': body.length,
            'sha256': sha256.convert(body).toString(),
          }, body);
        }
        const thumb = 'cover.thumb.webp';
        if (cover['thumbnail'] != thumb || !stored.containsKey(thumb) || body != null) {
          body ??= (await _image(coverUrl, series.url)).body;
          final small = await _thumbnail(body);
          if (small != null) files[thumb] = small;
          cover = {...cover, 'thumbnail': small == null ? null : thumb};
        }
      } on ProviderError catch (error) {
        if (error is ProviderOffline) rethrow;
        result.failed.add(ArchiveFailure('copertina', '$error'));
      }
    }
    final manifest = <String, Object?>{
      'schemaVersion': archiveSchemaVersion,
      'metadataSchemaVersion': metadataSchemaVersion,
      'provider': series.provider,
      'id': series.id,
      'title': series.title,
      'source': series.url,
      'fetchedAt': isoNow(),
      'metadata': metadata,
      'cover': cover,
      'chapters': [
        for (final chapter in series.chapters)
          {
            'id': chapter.id,
            'number': chapter.number,
            'title': chapter.title,
            'source': chapter.url,
            'metadata': normalizeMetadata(chapter.metadata),
          },
      ],
    };
    files[seriesManifestFile] = _utf8(prettyJson(manifest));
    await store.writeSeriesFiles(folder, files);
    return manifest;
  }

  Future<Uint8List?> _thumbnail(Uint8List cover) async {
    await scratch.create(recursive: true);
    final file = File(p.join(scratch.path, 'cover-${DateTime.now().microsecondsSinceEpoch}'));
    await file.writeAsBytes(cover);
    try {
      return await images.thumbnail(file);
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  Future<({Uint8List body, String extension})> _image(String url, String referer) async {
    final result = await http.get(url, limit: 30000000, referer: referer);
    final extension = imageExtension(result.body);
    if (!result.contentType.startsWith('image/')) {
      throw const ProviderError('Il provider non ha restituito un’immagine.');
    }
    return (body: result.body, extension: extension);
  }

  /// Riscrive `index.json`, `pages.json` e la riga in libreria.
  Future<void> refreshIndexes(String folder, Map<String, Object?> manifest) async {
    final archived = await store.archivedChapters(folder, manifest);
    final built = buildSeriesIndex(manifest, archived);
    if (built == null) return;
    await store.writeSeriesFiles(folder, {
      seriesIndexName: _utf8(prettyJson(built.index)),
      pagesIndexName: _utf8(prettyJson(built.pages)),
    });
    await store.writeLibraryRow(summarize(folder, manifest, built.index));
  }

  bool _alreadyThere(
    Map<String, Object?>? stored,
    String chapterId,
    List<Page> pages,
    Map<String, StoredFile> files,
  ) {
    if (stored == null || stored['id'] != chapterId || stored['complete'] != true) return false;
    final records = stored['pages'];
    if (records is! List || records.length != pages.length) return false;
    for (var i = 0; i < pages.length; i++) {
      final record = records[i];
      if (record is! Map ||
          record['source'] != pages[i].url ||
          record['file'] is! String ||
          files[record['file']]?.size != record['size']) {
        return false;
      }
      for (final tile in (record['tiles'] as List? ?? const [])) {
        if (tile is! Map || files[tile['file']]?.size != tile['size']) return false;
      }
    }
    return true;
  }

  Future<void> _chapter(String folder, Chapter chapter, List<int> counts) async {
    final content = await provider.fetchPages(chapter, http);
    final path = p.posix.join(folder, 'chapters', chapterFolderName(chapter));
    final stored = await store.filesIn(path);
    final storedManifest = stored.containsKey(chapterManifestFile)
        ? await store.readJson(p.posix.join(path, chapterManifestFile))
        : null;
    final mirror = store is DriveStore ? (store as DriveStore).mirror : null;
    // Il capitolo c'è già, intero: lo dice il suo `chapter.json`, con le
    // tavole che il sito elenca adesso e i file della misura giusta. È la
    // ricevuta del server, letta dalla destinazione invece che da un file
    // a parte, così vale anche per i capitoli che ha scritto lui.
    if (_alreadyThere(storedManifest, chapter.id, content.pages, stored) &&
        (mirror == null ||
            _alreadyThere(storedManifest, chapter.id, content.pages, await mirror.filesIn(path)))) {
      counts[1] += content.pages.length;
      for (var i = 1; i <= content.pages.length; i++) {
        _emit(PageSaved(i, content.pages.length, saved: false, size: 0));
      }
      return;
    }
    final work = await store.workspace(path);
    final previous = await readJsonFile(File(p.join(work.path, chapterManifestFile))) ?? storedManifest;
    var oldPages = previous?['id'] == chapter.id ? previous!['pages'] : null;
    if (oldPages is! List) oldPages = const [];
    final records = [
      for (final record in oldPages.take(content.pages.length))
        record is Map<String, Object?> ? record : <String, Object?>{},
    ];
    final manifest = <String, Object?>{
      'schemaVersion': archiveSchemaVersion,
      'metadataSchemaVersion': metadataSchemaVersion,
      'id': chapter.id,
      'title': chapter.title,
      'number': chapter.number,
      'source': chapter.url,
      'metadata': normalizeMetadata({...chapter.metadata, ...content.metadata}),
      'complete': false,
      'pages': records,
    };
    final manifestFile = File(p.join(work.path, chapterManifestFile));
    // Riusare una tavola che è già nella destinazione ma non qui ha senso
    // solo se il telefono non ne deve tenere una copia.
    final reuseRemote = store is DriveStore && mirror == null;
    for (var index = 1; index <= content.pages.length; index++) {
      _check();
      final page = content.pages[index - 1];
      final record = index <= records.length ? records[index - 1] : <String, Object?>{};
      final oldName = record['file'];
      final oldFile = oldName is String && oldName.isNotEmpty && !oldName.contains('/')
          ? File(p.join(work.path, oldName))
          : null;
      final kept = oldFile == null ? null : await _verify(oldFile, record, page.url);
      Map<String, Object?> next;
      Uint8List? body;
      var saved = false;
      if (kept != null) {
        counts[1]++;
        body = kept;
        next = _measured(record, kept, page);
      } else if (reuseRemote &&
          oldFile != null &&
          !await oldFile.exists() &&
          _remoteKept(record, page.url, stored)) {
        counts[1]++;
        next = record;
      } else {
        final image = await _image(page.url, chapter.url);
        body = image.body;
        final file = File(p.join(work.path, '${'$index'.padLeft(4, '0')}${image.extension}'));
        await writeAtomically(file, body);
        next = _measured({
          'file': p.basename(file.path),
          'source': page.url,
          'size': body.length,
          'sha256': sha256.convert(body).toString(),
        }, body, page);
        counts[0]++;
        saved = true;
      }
      if (body != null) next = await _tile(work, next);
      if (index <= records.length) {
        records[index - 1] = next;
      } else {
        records.add(next);
      }
      await writeAtomically(manifestFile, _utf8(prettyJson(manifest)));
      _emit(PageSaved(index, content.pages.length, saved: saved, size: saved ? next['size'] as int : 0));
      if (index < content.pages.length) await _pause();
    }
    manifest['complete'] = true;
    manifest['completedAt'] = isoNow();
    await writeAtomically(manifestFile, _utf8(prettyJson(manifest)));
    final files = <String>[
      for (final record in records) ...[
        if (record['file'] case final String name) name,
        for (final tile in (record['tiles'] as List? ?? const []).whereType<Map>())
          if (tile['file'] case final String name) name,
      ],
    ];
    final present = [
      for (final name in files)
        if (await File(p.join(work.path, name)).exists()) name,
    ];
    if (store is DriveStore) _emit(ChapterUploading(chapter.title, present.length + 1));
    await store.commitChapter(path, work, [...present, chapterManifestFile]);
  }

  bool _remoteKept(Map<String, Object?> record, String url, Map<String, StoredFile> stored) {
    final name = record['file'];
    if (record['source'] != url || name is! String || stored[name]?.size != record['size']) return false;
    final height = (record['height'] as num?)?.toInt() ?? 0;
    final tiles = record['tiles'];
    if (tileHeights(height).isEmpty) return true;
    return tiles is List &&
        tiles.isNotEmpty &&
        tiles.every((tile) => tile is Map && stored[tile['file']]?.size == tile['size']);
  }

  /// Il record della pagina con le sue tessere, scritte accanto alla tavola.
  /// Una tavola bassa non ne ha; una che le ha già, integre, non le rifà.
  Future<Map<String, Object?>> _tile(Directory work, Map<String, Object?> record) async {
    final heights = tileHeights((record['height'] as num?)?.toInt() ?? 0);
    final name = record['file'] as String;
    if (heights.isEmpty || name.endsWith('.gif')) return _withoutTiles(record);
    final existing = record['tiles'];
    if (existing is List &&
        _sameHeights(existing, heights) &&
        (await Future.wait(existing.map((tile) => _tileOk(work, tile)))).every((ok) => ok)) {
      return record;
    }
    final parts = await images.tiles(File(p.join(work.path, name)), heights);
    if (parts == null) return _withoutTiles(record);
    final stem = p.basenameWithoutExtension(name);
    final made = <Map<String, Object?>>[];
    for (var i = 0; i < parts.length; i++) {
      final file = File(p.join(work.path, '$stem-${'${i + 1}'.padLeft(2, '0')}.webp'));
      await writeAtomically(file, parts[i]);
      made.add({
        'file': p.basename(file.path),
        'height': heights[i],
        'size': parts[i].length,
        'sha256': sha256.convert(parts[i]).toString(),
      });
    }
    return {...record, 'tiles': made};
  }

  static bool _sameHeights(List<Object?> tiles, List<int> heights) {
    final values = [for (final tile in tiles) if (tile is Map) tile['height']];
    if (values.length != heights.length) return false;
    for (var i = 0; i < heights.length; i++) {
      if (values[i] != heights[i]) return false;
    }
    return true;
  }
}

Uint8List _utf8(String text) => utf8.encode(text);
