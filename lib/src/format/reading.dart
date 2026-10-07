/// Stato di lettura: l'unica parte di MALF che l'app scrive.
///
/// Vive in `<libreria>/reading/` e non nella memoria dell'app perché deve
/// sopravvivere a una reinstallazione e viaggiare con le stesse automazioni
/// che portano i manga sul telefono.
library;

import 'malf.dart';

/// Come l'utente classifica una serie. È indipendente da [ReleaseStatus]:
/// una serie ancora in corso può essere `dropped`, una conclusa `reading`.
enum ShelfStatus {
  none,
  planned,
  reading,
  paused,
  completed,
  dropped;

  static ShelfStatus parse(Object? value) => switch (value) {
        'planned' => ShelfStatus.planned,
        'reading' => ShelfStatus.reading,
        'paused' => ShelfStatus.paused,
        'completed' => ShelfStatus.completed,
        'dropped' => ShelfStatus.dropped,
        _ => ShelfStatus.none,
      };

  String? get wireValue => this == ShelfStatus.none ? null : name;
}

DateTime _time(Object? value) =>
    (value is String ? DateTime.tryParse(value)?.toUtc() : null) ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Dove si è arrivati dentro un capitolo.
class ReadingProgress {
  const ReadingProgress({
    required this.chapterId,
    required this.page,
    required this.pageCount,
    required this.updatedAt,
    this.offset = 0,
  });

  factory ReadingProgress.fromJson(Map<String, Object?> json) => ReadingProgress(
        chapterId: json['chapterId'] as String,
        page: (json['page'] as num?)?.toInt() ?? 0,
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        updatedAt: _time(json['updatedAt']),
        offset: ((json['offset'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      );

  final String chapterId;
  final int page;
  final int pageCount;
  final DateTime updatedAt;

  /// Quanto si è già scorso della tavola [page], da 0 a 1.
  ///
  /// Senza questo la ripresa era esatta quanto una tavola, e la tavola di un
  /// webtoon è dieci schermate: riaprire il capitolo voleva dire tornare
  /// indietro di un minuto di lettura.
  final double offset;

  double get fraction => pageCount <= 0
      ? 0
      : ((page + offset) / pageCount).clamp(0.0, 1.0);

  Map<String, Object?> toJson() => {
        'chapterId': chapterId,
        'page': page,
        'pageCount': pageCount,
        'updatedAt': updatedAt.toIso8601String(),
        if (offset > 0) 'offset': offset,
      };
}

ReadingProgress? _latest(Iterable<ReadingProgress> progresses) =>
    progresses.fold<ReadingProgress?>(
      null,
      (latest, value) =>
          latest == null || value.updatedAt.isAfter(latest.updatedAt)
              ? value
              : latest,
    );

/// Lo stato di una serie, indicizzato per chiave MALF (`provider:id`).
class SeriesState {
  const SeriesState({
    this.status = ShelfStatus.none,
    this.rating,
    this.favorite = false,
    this.readChapters = const {},
    this.positions = const {},
    this.notes,
    this.updatedAt,
    this.lastOpenedAt,
    this.muted = false,
    this.reachedChapter,
  });

  factory SeriesState.fromJson(Map<String, Object?> json) {
    final progress = json['progress'];
    return SeriesState(
      status: ShelfStatus.parse(json['status']),
      rating: (json['rating'] as num?)?.toInt(),
      favorite: json['favorite'] == true,
      readChapters: (json['readChapters'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      positions: progress is Map<String, Object?> && progress['chapterId'] is String
          ? {
              progress['chapterId'] as String:
                  ReadingProgress.fromJson(progress),
            }
          : const {},
      notes: json['notes'] as String?,
      updatedAt: _time(json['updatedAt']),
      lastOpenedAt: json['lastOpenedAt'] is String
          ? DateTime.tryParse(json['lastOpenedAt'] as String)?.toUtc()
          : null,
      reachedChapter: json['reachedChapter'] as String?,
    );
  }

  final ShelfStatus status;
  final int? rating;
  final bool favorite;
  final Set<String> readChapters;

  /// Dove si è arrivati in ogni capitolo aperto, per id: chi lascia a metà
  /// due capitoli li ritrova entrambi dove li aveva lasciati.
  final Map<String, ReadingProgress> positions;
  final String? notes;
  final DateTime? updatedAt;

  /// Quando l'utente ha aperto la scheda l'ultima volta: è il riferimento con
  /// cui si dice se un capitolo arrivato dopo è una novità.
  final DateTime? lastOpenedAt;

  /// Niente notifiche per i capitoli nuovi. Non rende la serie "seguita" e
  /// quindi non entra in [isEmpty]: è una preferenza, non una lettura.
  final bool muted;

  /// Il numero dell'ultimo capitolo letto altrove. Non entra in [isEmpty]:
  /// da solo non rende la serie letta, la rende solo una scheda compilata.
  final String? reachedChapter;

  /// L'ultima posizione scritta: è il capitolo da cui la serie riprende.
  ReadingProgress? get progress => _latest(positions.values);

  bool get isEmpty =>
      status == ShelfStatus.none &&
      rating == null &&
      !favorite &&
      readChapters.isEmpty &&
      positions.isEmpty &&
      reachedChapter == null &&
      (notes == null || notes!.isEmpty);

  SeriesState copyWith({
    ShelfStatus? status,
    int? rating,
    bool clearRating = false,
    bool? favorite,
    Set<String>? readChapters,
    ReadingProgress? progress,
    String? notes,
    DateTime? lastOpenedAt,
    bool? muted,
    String? reachedChapter,
    bool clearReachedChapter = false,
  }) =>
      SeriesState(
        status: status ?? this.status,
        rating: clearRating ? null : (rating ?? this.rating),
        favorite: favorite ?? this.favorite,
        readChapters: readChapters ?? this.readChapters,
        positions: progress == null
            ? positions
            : {...positions, progress.chapterId: progress},
        notes: notes ?? this.notes,
        updatedAt: DateTime.now().toUtc(),
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        muted: muted ?? this.muted,
        reachedChapter: clearReachedChapter
            ? null
            : (reachedChapter ?? this.reachedChapter),
      );

  /// Fonde due versioni dello stesso record dopo una sincronizzazione.
  ///
  /// Vince il più recente campo per campo, tranne i capitoli letti, che sono
  /// l'unione: un capitolo finito su un dispositivo non torna mai da leggere
  /// solo perché un altro dispositivo non lo sapeva. Le posizioni si fondono
  /// capitolo per capitolo, con la più recente per ciascuno.
  SeriesState mergeWith(SeriesState other) {
    final mine = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final theirs = other.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final newer = theirs.isAfter(mine) ? other : this;
    final chapters = {...positions.keys, ...other.positions.keys};
    return SeriesState(
      status: newer.status,
      rating: newer.rating,
      favorite: newer.favorite,
      readChapters: {...readChapters, ...other.readChapters},
      positions: {
        for (final id in chapters)
          id: _latest([positions[id], other.positions[id]].nonNulls)!,
      },
      notes: newer.notes,
      updatedAt: theirs.isAfter(mine) ? theirs : mine,
      lastOpenedAt: [lastOpenedAt, other.lastOpenedAt].nonNulls.fold<DateTime?>(
        null,
        (latest, value) =>
            latest == null || value.isAfter(latest) ? value : latest,
      ),
      muted: newer.muted,
      reachedChapter: newer.reachedChapter,
    );
  }

  Map<String, Object?> toJson() => {
        if (status.wireValue != null) 'status': status.wireValue,
        if (rating != null) 'rating': rating,
        if (favorite) 'favorite': true,
        if (readChapters.isNotEmpty) 'readChapters': readChapters.toList()..sort(),
        if (progress != null) 'progress': progress!.toJson(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (reachedChapter != null) 'reachedChapter': reachedChapter,
        if (lastOpenedAt != null)
          'lastOpenedAt': lastOpenedAt!.toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      };
}

/// Una raccolta di serie, l'equivalente della playlist di un lettore musicale.
class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.seriesKeys,
    this.color,
    this.order = 0,
    this.updatedAt,
  });

  factory Collection.fromJson(Map<String, Object?> json) => Collection(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        seriesKeys: (json['series'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        color: (json['color'] as num?)?.toInt(),
        order: (json['order'] as num?)?.toInt() ?? 0,
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)?.toUtc()
            : null,
      );

  final String id;
  final String name;
  final List<String> seriesKeys;
  final int? color;
  final int order;
  final DateTime? updatedAt;

  Collection copyWith({String? name, List<String>? seriesKeys, int? color, int? order}) =>
      Collection(
        id: id,
        name: name ?? this.name,
        seriesKeys: seriesKeys ?? this.seriesKeys,
        color: color ?? this.color,
        order: order ?? this.order,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'series': seriesKeys,
        if (color != null) 'color': color,
        'order': order,
        'updatedAt': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      };
}

/// I capitoli prima di [finished] che non risultano letti, nell'ordine di
/// lettura.
///
/// Finire il 21 con i primi venti ancora da leggere vuol dire, quasi sempre,
/// che quelli li si è letti altrove: è la domanda che il lettore fa alla fine
/// del capitolo. Contano anche i capitoli non scaricati — sono comunque
/// venuti prima — e non conta niente di ciò che viene dopo.
List<String> unreadBefore(
  Iterable<ChapterEntry> chapters,
  String finished,
  Set<String> read,
) {
  final last = chapters.where((chapter) => chapter.id == finished).firstOrNull;
  if (last == null) return const [];
  return [
    for (final chapter in chapters.toList()
      ..sort((a, b) => a.order.compareTo(b.order)))
      if (chapter.order < last.order && !read.contains(chapter.id)) chapter.id,
  ];
}
