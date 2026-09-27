/// Gli indici MALF che l'archivio scrive accanto ai manifest.
///
/// Porting di `mangaarchive/library.py`: `index.json`, `pages.json` e la
/// riga di `library.json` sono derivati da `series.json` e dai
/// `chapter.json`, e vengono uguali da qualunque parte li si scriva. Qui i
/// capitoli archiviati arrivano già raccolti ([ArchivedChapter]): su disco
/// li si legge dalle cartelle, su Drive dagli indici di prima più i capitoli
/// appena caricati, perché aprire un `chapter.json` a richiesta costa una
/// chiamata di rete ciascuno.
library;

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import 'names.dart';

const String malfFormatName = 'malf';
const int malfVersion = 1;

/// L'ora come la scrive Python con `isoformat()`: stesso formato in tutti i
/// manifest, chiunque li abbia scritti.
String isoNow([DateTime? at]) {
  final value = (at ?? DateTime.now()).toUtc();
  final text = value.toIso8601String();
  final micros = value.microsecond + value.millisecond * 1000;
  final base = text.substring(0, 19);
  return micros == 0 ? '$base+00:00' : '$base.${'$micros'.padLeft(6, '0')}+00:00';
}

/// L'ora al secondo con la `Z`, come `library.py:now()`.
String isoSeconds([DateTime? at]) =>
    '${(at ?? DateTime.now()).toUtc().toIso8601String().substring(0, 19)}Z';

/// `json.dumps(sort_keys=True, ensure_ascii=False)` di Python: la firma di
/// una serie deve venire uguale da tutt'e due i lati.
String pythonDumps(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}: ${pythonDumps(value[key])}').join(', ')}}';
  }
  if (value is List) return '[${value.map(pythonDumps).join(', ')}]';
  if (value is double && value == value.truncateToDouble() && value.abs() < 1e16) {
    return '${value.toInt()}.0';
  }
  return jsonEncode(value);
}

String signatureOf(Object? payload) =>
    sha256.convert(utf8.encode(pythonDumps(payload))).toString().substring(0, 16);

/// Una pagina come la legge il client: file, dimensioni e, se alta, tessere.
Map<String, Object?> pageEntry(Map<String, Object?> record) {
  final entry = <String, Object?>{
    'file': record['file'],
    'width': record['width'],
    'height': record['height'],
    'bytes': record['size'],
  };
  final tiles = record['tiles'];
  if (tiles is List && tiles.isNotEmpty) {
    entry['tiles'] = [
      for (final tile in tiles.whereType<Map>())
        {'file': tile['file'], 'height': tile['height'], 'bytes': tile['size']},
    ];
  }
  return entry;
}

/// Un capitolo che ha una cartella nell'archivio, con quanto serve agli
/// indici.
class ArchivedChapter {
  const ArchivedChapter({
    required this.path,
    required this.complete,
    required this.pages,
    required this.bytes,
    this.archivedAt,
  });

  /// Da un `chapter.json`.
  factory ArchivedChapter.fromManifest(String path, Map<String, Object?> manifest) {
    final records = [
      for (final record in (manifest['pages'] as List? ?? const []).whereType<Map<String, Object?>>())
        if (record['file'] != null && record['file'] != '') record,
    ];
    return ArchivedChapter(
      path: path,
      complete: manifest['complete'] == true,
      pages: records.map(pageEntry).toList(),
      bytes: records.fold(0, (sum, record) => sum + ((record['size'] as num?)?.toInt() ?? 0)),
      archivedAt: manifest['completedAt'] as String?,
    );
  }

  /// Dalle righe di `index.json` e `pages.json` scritte l'ultima volta.
  static ArchivedChapter? fromIndex(Map<String, Object?> entry, List<Object?>? pages) {
    final path = entry['path'];
    if (path is! String || entry['archived'] != true) return null;
    return ArchivedChapter(
      path: path,
      complete: entry['complete'] == true,
      pages: [...?pages?.whereType<Map<String, Object?>>()],
      bytes: (entry['bytes'] as num?)?.toInt() ?? 0,
      archivedAt: entry['archivedAt'] as String?,
    );
  }

  /// Percorso relativo alla cartella della serie: `chapters/<nome>`.
  final String path;
  final bool complete;
  final List<Map<String, Object?>> pages;
  final int bytes;
  final String? archivedAt;
}

class SeriesIndexes {
  const SeriesIndexes(this.index, this.pages);

  final Map<String, Object?> index;
  final Map<String, Object?> pages;
}

/// `index.json` e `pages.json` di una serie. [archived] è per id di capitolo.
SeriesIndexes? buildSeriesIndex(
  Map<String, Object?> manifest,
  Map<String, ArchivedChapter> archived,
) {
  final provider = manifest['provider'];
  final id = manifest['id'];
  if (provider is! String || provider.isEmpty || id is! String || id.isEmpty) return null;
  final metadata = manifest['metadata'] as Map? ?? const {};
  final key = '$provider:$id';
  final chapters = <Map<String, Object?>>[];
  final pages = <String, Object?>{};
  final list = manifest['chapters'] as List? ?? const [];
  for (var order = 0; order < list.length; order++) {
    final chapter = list[order];
    if (chapter is! Map || chapter['id'] == null || chapter['id'] == '') continue;
    final chapterId = chapter['id'] as String;
    final stored = archived[chapterId];
    final chapterMetadata = chapter['metadata'] as Map? ?? const {};
    chapters.add({
      'id': chapterId,
      'number': chapter['number'],
      'title': chapter['title'],
      'order': order,
      'sortKey': sortKey(chapter['number'] as String? ?? ''),
      'path': stored?.path,
      'archived': stored != null,
      'complete': stored?.complete ?? false,
      'pageCount': stored?.pages.length ?? 0,
      'bytes': stored?.bytes ?? 0,
      'publishedAt': chapterMetadata['publishedAt'],
      'updatedAt': chapterMetadata['updatedAt'],
      'archivedAt': stored?.archivedAt,
    });
    if (stored != null && stored.pages.isNotEmpty) pages[chapterId] = stored.pages;
  }
  final cover = manifest['cover'] is Map ? manifest['cover'] : null;
  final signature = signatureOf(chapters);
  final index = <String, Object?>{
    'format': malfFormatName,
    'formatVersion': malfVersion,
    'key': key,
    'provider': provider,
    'id': id,
    'title': manifest['title'],
    'source': manifest['source'],
    'releaseStatus': metadata['releaseStatus'] ?? 'unknown',
    'cover': cover,
    'chapterCount': chapters.length,
    'archivedChapterCount': chapters.where((entry) => entry['complete'] == true).length,
    'pageCount': chapters.fold<int>(0, (sum, entry) => sum + (entry['pageCount'] as int)),
    'bytes': chapters.fold<int>(0, (sum, entry) => sum + (entry['bytes'] as int)),
    'archivedAt': manifest['fetchedAt'],
    'chapters': chapters,
    'signature': signature,
  };
  return SeriesIndexes(index, {
    'format': malfFormatName,
    'formatVersion': malfVersion,
    'key': key,
    'signature': signature,
    'pages': pages,
  });
}

/// La riga di libreria: quanto basta a disegnare la griglia, niente di più.
Map<String, Object?> summarize(
  String folder,
  Map<String, Object?> manifest,
  Map<String, Object?> index,
) {
  final metadata = manifest['metadata'] as Map? ?? const {};
  final complete = [
    for (final entry in (index['chapters'] as List).cast<Map<String, Object?>>())
      if (entry['complete'] == true) entry,
  ];
  Map<String, Object?>? latest;
  for (final entry in complete) {
    if (latest == null || (entry['order'] as int) > (latest['order'] as int)) latest = entry;
  }
  final cover = index['cover'] as Map? ?? const {};
  return {
    'key': index['key'],
    'path': folder,
    'provider': index['provider'],
    'id': index['id'],
    'title': index['title'],
    'source': index['source'],
    'cover': cover['file'],
    'coverThumbnail': cover['thumbnail'],
    'coverWidth': cover['width'],
    'coverHeight': cover['height'],
    'releaseStatus': index['releaseStatus'],
    'type': metadata['type'],
    'language': metadata['language'],
    'authors': metadata['authors'] ?? const [],
    'artists': metadata['artists'] ?? const [],
    'genres': metadata['genres'] ?? const [],
    'tags': metadata['tags'] ?? const [],
    'chapterCount': index['chapterCount'],
    'archivedChapterCount': index['archivedChapterCount'],
    'pageCount': index['pageCount'],
    'bytes': index['bytes'],
    'latestChapterNumber': latest?['number'],
    'latestChapterTitle': latest?['title'],
    'latestChapterArchivedAt': latest?['archivedAt'],
    'updatedAt': metadata['updatedAt'],
    'archivedAt': index['archivedAt'],
    'signature': index['signature'],
  };
}

/// `library.json` con la riga [row] al posto di quella con la stessa chiave.
///
/// Le altre righe restano come sono: le ha scritte chi le ha scritte, server
/// compreso, e una serie archiviata qui non deve costringere a rileggere le
/// altre.
Map<String, Object?> libraryWith(Map<String, Object?>? previous, Map<String, Object?> row) {
  final rows = [
    for (final entry in (previous?['series'] as List? ?? const []).whereType<Map<String, Object?>>())
      if (entry['key'] != row['key']) entry,
    row,
  ];
  // Stabile come `sorted` di Python: due titoli uguali restano nell'ordine
  // in cui erano.
  mergeSort(rows, compare: (a, b) =>
      '${a['title'] ?? ''}'.toLowerCase().compareTo('${b['title'] ?? ''}'.toLowerCase()));
  int total(String field) =>
      rows.fold(0, (sum, entry) => sum + ((entry[field] as num?)?.toInt() ?? 0));
  return {
    'format': malfFormatName,
    'formatVersion': malfVersion,
    'generatedAt': isoSeconds(),
    'seriesCount': rows.length,
    'chapterCount': total('archivedChapterCount'),
    'pageCount': total('pageCount'),
    'bytes': total('bytes'),
    'series': rows,
  };
}

/// Come `json.dumps(indent=2)` più l'a capo finale dei manifest del server.
String prettyJson(Object? value) => '${const JsonEncoder.withIndent('  ').convert(value)}\n';
