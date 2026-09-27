/// Modelli del formato MALF, chiunque abbia scritto la libreria.
///
/// La specifica è `docs/malf.md`. Questi tipi ne
/// sono l'unica lettura nell'app: nessun'altra parte del codice conosce i nomi
/// dei campi JSON o la disposizione delle cartelle.
library;

import 'package:path/path.dart' as p;

const String malfFormat = 'malf';
const int malfFormatVersion = 1;

const String libraryIndexFile = 'library.json';
const String seriesIndexFile = 'index.json';
const String pagesIndexFile = 'pages.json';
const String readingDirectory = 'reading';

/// Stato di pubblicazione della serie, già normalizzato dall'archiviatore.
enum ReleaseStatus {
  ongoing,
  completed,
  hiatus,
  cancelled,
  unknown;

  static ReleaseStatus parse(Object? value) => switch (value) {
        'ongoing' => ReleaseStatus.ongoing,
        'completed' => ReleaseStatus.completed,
        'hiatus' => ReleaseStatus.hiatus,
        'cancelled' => ReleaseStatus.cancelled,
        _ => ReleaseStatus.unknown,
      };
}

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList(growable: false) : const [];

int _int(Object? value) => value is num ? value.toInt() : 0;

int? _maybeInt(Object? value) => value is num ? value.toInt() : null;

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

/// Una riga della griglia di libreria: non contiene la descrizione, che vive
/// in `series.json` e serve solo alla scheda di dettaglio.
class SeriesEntry {
  const SeriesEntry({
    required this.key,
    required this.path,
    required this.title,
    required this.provider,
    required this.releaseStatus,
    required this.chapterCount,
    required this.archivedChapterCount,
    required this.pageCount,
    required this.bytes,
    required this.signature,
    this.cover,
    this.coverThumbnail,
    this.coverWidth,
    this.coverHeight,
    this.authors = const [],
    this.artists = const [],
    this.genres = const [],
    this.tags = const [],
    this.type,
    this.language,
    this.latestChapterNumber,
    this.latestChapterTitle,
    this.latestChapterArchivedAt,
    this.archivedAt,
  });

  factory SeriesEntry.fromJson(Map<String, Object?> json) => SeriesEntry(
        key: json['key'] as String,
        path: json['path'] as String? ?? '',
        title: json['title'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        releaseStatus: ReleaseStatus.parse(json['releaseStatus']),
        chapterCount: _int(json['chapterCount']),
        archivedChapterCount: _int(json['archivedChapterCount']),
        pageCount: _int(json['pageCount']),
        bytes: _int(json['bytes']),
        signature: json['signature'] as String? ?? '',
        cover: json['cover'] as String?,
        coverThumbnail: json['coverThumbnail'] as String?,
        coverWidth: _maybeInt(json['coverWidth']),
        coverHeight: _maybeInt(json['coverHeight']),
        authors: _strings(json['authors']),
        artists: _strings(json['artists']),
        genres: _strings(json['genres']),
        tags: _strings(json['tags']),
        type: json['type'] as String?,
        language: json['language'] as String?,
        latestChapterNumber: json['latestChapterNumber'] as String?,
        latestChapterTitle: json['latestChapterTitle'] as String?,
        latestChapterArchivedAt: _time(json['latestChapterArchivedAt']),
        archivedAt: _time(json['archivedAt']),
      );

  /// La riga com'è in `library.json`. Serve a chi scarica una serie da Drive
  /// dentro una cartella locale: `library.json` lì non lo scrive l'app, e la
  /// riga deve pur stare da qualche parte.
  Map<String, Object?> toJson() => {
        'key': key,
        'path': path,
        'title': title,
        'provider': provider,
        'releaseStatus': releaseStatus.name,
        'chapterCount': chapterCount,
        'archivedChapterCount': archivedChapterCount,
        'pageCount': pageCount,
        'bytes': bytes,
        'signature': signature,
        'cover': ?cover,
        'coverThumbnail': ?coverThumbnail,
        'coverWidth': ?coverWidth,
        'coverHeight': ?coverHeight,
        'authors': authors,
        'artists': artists,
        'genres': genres,
        'tags': tags,
        'type': ?type,
        'language': ?language,
        'latestChapterNumber': ?latestChapterNumber,
        'latestChapterTitle': ?latestChapterTitle,
        'latestChapterArchivedAt': ?latestChapterArchivedAt?.toIso8601String(),
        'archivedAt': ?archivedAt?.toIso8601String(),
      };

  SeriesEntry copyWith({int? archivedChapterCount}) => SeriesEntry(
        key: key,
        path: path,
        title: title,
        provider: provider,
        releaseStatus: releaseStatus,
        chapterCount: chapterCount,
        archivedChapterCount: archivedChapterCount ?? this.archivedChapterCount,
        pageCount: pageCount,
        bytes: bytes,
        signature: signature,
        cover: cover,
        coverThumbnail: coverThumbnail,
        coverWidth: coverWidth,
        coverHeight: coverHeight,
        authors: authors,
        artists: artists,
        genres: genres,
        tags: tags,
        type: type,
        language: language,
        latestChapterNumber: latestChapterNumber,
        latestChapterTitle: latestChapterTitle,
        latestChapterArchivedAt: latestChapterArchivedAt,
        archivedAt: archivedAt,
      );

  final String key;
  final String path;
  final String title;
  final String provider;
  final ReleaseStatus releaseStatus;
  final int chapterCount;
  final int archivedChapterCount;
  final int pageCount;
  final int bytes;
  final String signature;
  final String? cover;
  final String? coverThumbnail;
  final int? coverWidth;
  final int? coverHeight;
  final List<String> authors;
  final List<String> artists;
  final List<String> genres;
  final List<String> tags;
  final String? type;
  final String? language;
  final String? latestChapterNumber;
  final String? latestChapterTitle;
  final DateTime? latestChapterArchivedAt;
  final DateTime? archivedAt;

  /// Capitoli pubblicati dal provider e non ancora presenti in locale.
  int get missingChapterCount =>
      (chapterCount - archivedChapterCount).clamp(0, chapterCount);

  bool get isOngoing => releaseStatus == ReleaseStatus.ongoing;

  /// Immagine da usare nella griglia: la miniatura quando c'è, perché la
  /// copertina piena costa una decodifica intera per ogni cella visibile.
  String? gridImagePath(String libraryRoot) {
    final name = coverThumbnail ?? cover;
    return name == null ? null : p.join(libraryRoot, path, name);
  }

  String? coverPath(String libraryRoot) =>
      cover == null ? null : p.join(libraryRoot, path, cover!);

  String directory(String libraryRoot) => p.join(libraryRoot, path);
}

/// Contenuto di `library.json`.
class LibraryIndex {
  const LibraryIndex({
    required this.generatedAt,
    required this.series,
    required this.chapterCount,
    required this.pageCount,
    required this.bytes,
  });

  factory LibraryIndex.fromJson(Map<String, Object?> json) {
    final entries = (json['series'] as List? ?? const [])
        .whereType<Map<String, Object?>>()
        .where((row) => row['key'] is String)
        .map(SeriesEntry.fromJson)
        .toList(growable: false);
    return LibraryIndex(
      generatedAt: _time(json['generatedAt']),
      series: entries,
      chapterCount: _int(json['chapterCount']),
      pageCount: _int(json['pageCount']),
      bytes: _int(json['bytes']),
    );
  }

  static const LibraryIndex empty = LibraryIndex(
      generatedAt: null, series: [], chapterCount: 0, pageCount: 0, bytes: 0);

  final DateTime? generatedAt;
  final List<SeriesEntry> series;
  final int chapterCount;
  final int pageCount;
  final int bytes;
}

/// Un capitolo nell'indice di serie. `order` è l'ordine di lettura
/// autorevole: `number` è testo libero e manca del tutto sugli speciali.
class ChapterEntry {
  const ChapterEntry({
    required this.id,
    required this.order,
    required this.archived,
    required this.complete,
    required this.pageCount,
    required this.bytes,
    this.number,
    this.title,
    this.sortKey,
    this.path,
    this.publishedAt,
    this.archivedAt,
  });

  factory ChapterEntry.fromJson(Map<String, Object?> json) => ChapterEntry(
        id: json['id'] as String,
        order: _int(json['order']),
        archived: json['archived'] == true,
        complete: json['complete'] == true,
        pageCount: _int(json['pageCount']),
        bytes: _int(json['bytes']),
        number: json['number'] as String?,
        title: json['title'] as String?,
        sortKey: (json['sortKey'] as num?)?.toDouble(),
        path: json['path'] as String?,
        publishedAt: _time(json['publishedAt']),
        archivedAt: _time(json['archivedAt']),
      );

  final String id;
  final int order;
  final bool archived;
  final bool complete;
  final int pageCount;
  final int bytes;
  final String? number;
  final String? title;
  final double? sortKey;
  final String? path;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  /// Leggibile solo se i file ci sono: una serie in corso elenca anche
  /// capitoli annunciati dal provider e non ancora scaricati.
  bool get isReadable => complete && path != null && pageCount > 0;

  /// Un nome solo per capitolo. I siti mettono il numero anche nel titolo
  /// («Chapter 70.5»): ripeterlo accanto a «Capitolo 70.5» sembrerebbe una
  /// seconda numerazione, quindi dal titolo resta solo ciò che viene dopo.
  String label() {
    final number = this.number;
    final title = this.title;
    // Un numero che non è un numero («Side Story 1») è il titolo stesso,
    // messo lì da chi archivia perché il capitolo ne avesse uno.
    if (number == null || number.isEmpty || double.tryParse(number) == null) {
      return title == null || title.isEmpty ? number ?? id : title;
    }
    final head = 'Capitolo $number';
    if (title == null || title.isEmpty || title == number) return head;
    final repeated = _numbered.firstMatch(title);
    if (repeated == null ||
        double.tryParse(repeated[1]!.replaceAll(',', '.')) != double.tryParse(number)) {
      return '$head · $title';
    }
    final rest = title.substring(repeated.end);
    return rest.isEmpty ? head : '$head · $rest';
  }

  static final RegExp _numbered = RegExp(
    r'^\s*(?:chapter|ch\.|capitolo|cap\.|episode|ep\.)\s*0*(\d+(?:[.,]\d+)?)\b[\s:.\-–—]*',
    caseSensitive: false,
  );

  String? directory(String libraryRoot, String seriesPath) =>
      path == null ? null : p.join(libraryRoot, seriesPath, path!);
}

/// Contenuto di `index.json`.
class SeriesIndex {
  const SeriesIndex({
    required this.key,
    required this.title,
    required this.releaseStatus,
    required this.signature,
    required this.chapters,
  });

  factory SeriesIndex.fromJson(Map<String, Object?> json) => SeriesIndex(
        key: json['key'] as String,
        title: json['title'] as String? ?? '',
        releaseStatus: ReleaseStatus.parse(json['releaseStatus']),
        signature: json['signature'] as String? ?? '',
        chapters: (json['chapters'] as List? ?? const [])
            .whereType<Map<String, Object?>>()
            .where((row) => row['id'] is String)
            .map(ChapterEntry.fromJson)
            .toList(growable: false),
      );

  final String key;
  final String title;
  final ReleaseStatus releaseStatus;
  final String signature;
  final List<ChapterEntry> chapters;

  List<ChapterEntry> get readable =>
      chapters.where((chapter) => chapter.isReadable).toList(growable: false);
}

/// Una pagina, con le dimensioni misurate all'archiviazione: bastano a
/// riservare lo spazio di scorrimento senza decodificare l'immagine.
class PageEntry {
  const PageEntry({
    required this.file,
    this.width,
    this.height,
    this.bytes,
    this.tiles = const [],
  });

  factory PageEntry.fromJson(Map<String, Object?> json) {
    final width = _maybeInt(json['width']);
    final height = _maybeInt(json['height']);
    return PageEntry(
      file: json['file'] as String,
      width: width,
      height: height,
      bytes: _maybeInt(json['bytes']),
      tiles: TileEntry.listOf(json['tiles'], width: width, height: height),
    );
  }

  final String file;
  final int? width;
  final int? height;
  final int? bytes;

  /// La tavola tagliata dall'archivio in tessere, dall'alto in basso; vuota
  /// per le tavole basse e per quelle archiviate prima che le tessere
  /// esistessero.
  final List<TileEntry> tiles;

  double? get aspectRatio =>
      width != null && height != null && height! > 0 ? width! / height! : null;

  String path(String chapterDirectory) => p.join(chapterDirectory, file);
}

/// Una tessera di una tavola alta: larga quanto la tavola, alta [height].
class TileEntry {
  const TileEntry({required this.file, required this.height, this.bytes});

  final String file;
  final int height;
  final int? bytes;

  /// Le tessere di una pagina, o nessuna se non la ricompongono esattamente.
  ///
  /// Una tessera sbagliata sposterebbe tutta la striscia sotto di lei: meglio
  /// leggere la tavola intera, che le dimensioni le ha giuste per costruzione.
  static List<TileEntry> listOf(Object? raw, {int? width, int? height}) {
    if (raw is! List || raw.isEmpty || width == null || height == null) {
      return const [];
    }
    final tiles = <TileEntry>[];
    for (final row in raw) {
      if (row is! Map) return const [];
      final file = row['file'];
      final tall = _maybeInt(row['height']);
      if (file is! String || tall == null || tall <= 0) return const [];
      tiles.add(TileEntry(file: file, height: tall, bytes: _maybeInt(row['bytes'])));
    }
    final total = tiles.fold<int>(0, (sum, tile) => sum + tile.height);
    return total == height ? List.unmodifiable(tiles) : const [];
  }
}

/// Contenuto di `pages.json`: letto solo entrando in lettura.
class PagesIndex {
  const PagesIndex({required this.key, required this.signature, required this.pages});

  factory PagesIndex.fromJson(Map<String, Object?> json) {
    final raw = json['pages'];
    final pages = <String, List<PageEntry>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! List) continue;
        pages[key] = value
            .whereType<Map<String, Object?>>()
            .where((row) => row['file'] is String)
            .map(PageEntry.fromJson)
            .toList(growable: false);
      }
    }
    return PagesIndex(
      key: json['key'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      pages: pages,
    );
  }

  final String key;
  final String signature;
  final Map<String, List<PageEntry>> pages;

  List<PageEntry> of(String chapterId) => pages[chapterId] ?? const [];
}
