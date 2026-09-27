/// Come si percorre la libreria: segnali per serie, ricerca, filtri,
/// ordinamenti e raccolte automatiche.
///
/// È logica pura — niente disco, niente widget — perché è la parte che decide
/// cosa l'utente vede e va poter provare senza una libreria vera.
library;

import 'dart:math' as math;

import '../format/malf.dart';
import '../format/reading.dart';

final DateTime _never = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Quanto si sa di una serie incrociando l'indice con lo stato utente.
///
/// I capitoli da leggere si contano sull'archiviato, non su quanto il provider
/// annuncia: una serie in corso ha sempre capitoli che non esistono ancora sul
/// telefono e mostrarla come incompleta per quelli sarebbe rumore. I letti
/// invece sono tutti, scaricati o no: chi ha archiviato una serie dal 126 i
/// primi 125 li ha letti altrove, e li segna letti.
class SeriesSignals {
  const SeriesSignals({
    required this.entry,
    required this.state,
    required this.readCount,
    required this.unreadCount,
    this.seenChapters,
  });

  /// [chapters] è l'indice della serie, quando lo si ha: senza, i letti si
  /// possono contare solo supponendo che siano tutti fra gli archiviati, e
  /// su una serie archiviata a metà con i capitoli precedenti segnati letti
  /// la supposizione la dà per finita.
  factory SeriesSignals.of(
    SeriesEntry entry,
    SeriesState state, {
    int? seenChapters,
    Iterable<ChapterEntry>? chapters,
  }) {
    final read = state.readChapters;
    if (chapters != null) {
      var known = 0;
      var unread = 0;
      for (final chapter in chapters) {
        if (read.contains(chapter.id)) {
          known++;
        } else if (chapter.isReadable) {
          unread++;
        }
      }
      return SeriesSignals(
        entry: entry,
        state: state,
        readCount: known,
        unreadCount: unread,
        seenChapters: seenChapters,
      );
    }
    final archived = entry.archivedChapterCount;
    return SeriesSignals(
      entry: entry,
      state: state,
      readCount: read.length.clamp(0, math.max(archived, entry.chapterCount)),
      unreadCount: archived - read.length.clamp(0, archived),
      seenChapters: seenChapters,
    );
  }

  final SeriesEntry entry;
  final SeriesState state;

  /// I capitoli letti, anche quelli che sul telefono e su Drive non ci sono.
  final int readCount;

  /// I capitoli che si possono leggere e non sono ancora letti.
  final int unreadCount;

  /// I capitoli archiviati che questo telefono aveva già all'ultima apertura
  /// della scheda (`SeriesArrivals`). `null` finché la serie non è stata
  /// vista una prima volta: senza riferimento non c'è niente di nuovo.
  final int? seenChapters;

  /// Serve l'indice per contare [readCount] e [unreadCount]: l'archivio
  /// conosce capitoli che non ha, e qualcuno di quelli è già letto.
  static bool needsChapters(SeriesEntry entry, SeriesState state) =>
      entry.chapterCount > entry.archivedChapterCount &&
      state.readChapters.isNotEmpty;

  bool get hasUnread => unreadCount > 0;

  bool get isStarted => readCount > 0 || state.progress != null;

  bool get isFinished =>
      state.status == ShelfStatus.completed ||
      (entry.archivedChapterCount > 0 && unreadCount == 0);

  double get fraction => readCount + unreadCount == 0
      ? 0
      : readCount / (readCount + unreadCount);

  /// Una serie che l'utente segue: ci ha messo mano — stato, voto,
  /// preferito, capitoli letti — e non l'ha abbandonata. Su una serie mai
  /// aperta non c'è novità, c'è tutto da iniziare.
  bool get isFollowed =>
      !state.isEmpty && state.status != ShelfStatus.dropped;

  /// Quanti capitoli sono arrivati dopo l'ultima apertura della scheda e non
  /// sono ancora letti: è il numero sul pallino della copertina.
  ///
  /// Il conteggio viene da [seenChapters], che è di questo telefono; se la
  /// scheda è stata aperta altrove dopo l'ultimo arrivo — `lastOpenedAt`
  /// viaggia con l'account — quei capitoli li si è già visti.
  int get newChapters {
    final seen = seenChapters;
    if (seen == null || !isFollowed) return 0;
    final opened = state.lastOpenedAt;
    final arrived = entry.latestChapterArchivedAt;
    if (opened != null && arrived != null && !arrived.isAfter(opened)) return 0;
    return (entry.archivedChapterCount - seen).clamp(0, unreadCount);
  }

  bool get isNew => newChapters > 0;

  /// Data con cui ordinare per "aggiornamento recente".
  DateTime get freshness =>
      entry.latestChapterArchivedAt ?? entry.archivedAt ?? _never;

  /// Quando l'utente ci ha messo mano l'ultima volta.
  DateTime get lastRead =>
      state.progress?.updatedAt ?? state.lastOpenedAt ?? state.updatedAt ?? _never;

  /// Le persone che ci hanno lavorato, autori e disegnatori insieme: nella
  /// ricerca e nei filtri la distinzione non serve a nessuno.
  Iterable<String> get people => entry.authors.followedBy(entry.artists);
}

enum LibrarySort {
  updated('Aggiornate di recente'),
  title('Titolo'),
  progress('Avanzamento'),
  added('Aggiunte di recente'),
  lastRead('Lette di recente'),
  unread('Da leggere'),
  rating('Voto'),
  chapters('Numero di capitoli'),
  shuffle('A caso');

  const LibrarySort(this.label);

  final String label;
}

/// Come si dispone la griglia. Su una libreria grande la differenza fra
/// vedere sei copertine e vederne dodici è la differenza fra scorrere e
/// cercare.
enum LibraryDisplay {
  comfortable('Griglia comoda'),
  compact('Griglia fitta'),
  list('Elenco'),
  detailed('Elenco dettagliato');

  const LibraryDisplay(this.label);

  static LibraryDisplay parse(String? value) => LibraryDisplay.values
      .firstWhere((row) => row.name == value, orElse: () => comfortable);

  final String label;

  bool get isGrid => this == comfortable || this == compact;
}

/// Le raccolte che l'app costruisce da sé e che non si possono modificare.
enum AutoCollection {
  reading('In lettura'),
  fresh('Novità'),
  favorites('Preferiti'),
  planned('Da iniziare'),
  finished('Finiti');

  const AutoCollection(this.label);

  final String label;

  bool matches(SeriesSignals signals) => switch (this) {
        AutoCollection.reading =>
          signals.state.status == ShelfStatus.reading ||
              (signals.state.status == ShelfStatus.none && signals.isStarted),
        AutoCollection.fresh => signals.isNew,
        AutoCollection.favorites => signals.state.favorite,
        AutoCollection.planned => signals.state.status == ShelfStatus.planned ||
            (signals.state.status == ShelfStatus.none &&
                !signals.isStarted &&
                signals.entry.archivedChapterCount > 0),
        AutoCollection.finished => signals.state.status == ShelfStatus.completed,
      };
}

/// Come un valore entra in un filtro: indifferente, richiesto o escluso.
///
/// Il terzo stato serve più di quanto sembri: "shonen ma non horror" è una
/// richiesta normale, e con soli due stati si può solo elencare tutto il resto.
enum FacetState { off, include, exclude }

class TriFilter {
  const TriFilter({this.include = const {}, this.exclude = const {}});

  final Set<String> include;
  final Set<String> exclude;

  bool get isEmpty => include.isEmpty && exclude.isEmpty;

  int get length => include.length + exclude.length;

  FacetState stateOf(String value) => include.contains(value)
      ? FacetState.include
      : exclude.contains(value)
          ? FacetState.exclude
          : FacetState.off;

  /// Un tocco fa girare il valore: niente, richiesto, escluso, niente.
  TriFilter toggled(String value) => switch (stateOf(value)) {
        FacetState.off => TriFilter(
            include: {...include, value},
            exclude: exclude,
          ),
        FacetState.include => TriFilter(
            include: {...include}..remove(value),
            exclude: {...exclude, value},
          ),
        FacetState.exclude => TriFilter(
            include: include,
            exclude: {...exclude}..remove(value),
          ),
      };

  /// Richiesti tutti, esclusi nessuno: è l'interpretazione che non sorprende.
  bool allows(Iterable<String> values) {
    final present = values.toSet();
    if (!include.every(present.contains)) return false;
    return !exclude.any(present.contains);
  }
}

/// Una ricerca scritta a mano, con i prefissi che evitano di aprire i filtri
/// per una domanda sola: `tag:isekai autore:oda stato:in lettura`.
class SearchQuery {
  const SearchQuery({this.terms = const [], this.fields = const []});

  factory SearchQuery.parse(String raw) {
    final terms = <String>[];
    final fields = <(String, String)>[];
    for (final token in raw.toLowerCase().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final colon = token.indexOf(':');
      if (colon <= 0 || colon == token.length - 1) {
        terms.add(token);
        continue;
      }
      final field = _fields[token.substring(0, colon)];
      if (field == null) {
        terms.add(token);
        continue;
      }
      fields.add((field, token.substring(colon + 1)));
    }
    return SearchQuery(terms: terms, fields: fields);
  }

  static const Map<String, String> _fields = {
    'tag': 'tag',
    'genere': 'genre',
    'genre': 'genre',
    'autore': 'author',
    'author': 'author',
    'stato': 'status',
    'status': 'status',
    'tipo': 'type',
    'type': 'type',
    'lingua': 'language',
    'provider': 'provider',
  };

  /// I prefissi che si possono scrivere, per suggerirli invece di lasciarli
  /// indovinare.
  static const List<String> hints = [
    'tag:',
    'genere:',
    'autore:',
    'stato:',
    'tipo:',
    'provider:',
  ];

  final List<String> terms;
  final List<(String, String)> fields;

  bool get isEmpty => terms.isEmpty && fields.isEmpty;

  bool matches(SeriesSignals signals) {
    final entry = signals.entry;
    for (final term in terms) {
      final inTitle = entry.title.toLowerCase().contains(term);
      final inPeople =
          signals.people.any((name) => name.toLowerCase().contains(term));
      if (!inTitle && !inPeople) return false;
    }
    for (final (field, value) in fields) {
      final found = switch (field) {
        'tag' => _any(entry.tags, value),
        'genre' => _any(entry.genres, value),
        'author' => _any(signals.people, value),
        'type' => _contains(entry.type, value),
        'language' => _contains(entry.language, value),
        'provider' => _contains(entry.provider, value),
        'status' => _status(signals, value),
        _ => false,
      };
      if (!found) return false;
    }
    return true;
  }

  static bool _any(Iterable<String> values, String needle) =>
      values.any((value) => value.toLowerCase().contains(needle));

  static bool _contains(String? value, String needle) =>
      value != null && value.toLowerCase().contains(needle);

  /// `stato:` prende sia lo stato dell'utente sia quello di pubblicazione:
  /// sono due domande che si fanno con la stessa parola.
  static bool _status(SeriesSignals signals, String needle) =>
      signals.state.status.name.contains(needle) ||
      signals.entry.releaseStatus.name.contains(needle);
}

/// Cosa mostrare della libreria. Un filtro vuoto lascia passare tutto.
class LibraryFilter {
  const LibraryFilter({
    this.query = '',
    this.sort = LibrarySort.updated,
    this.descending = true,
    this.shelf = const {},
    this.release = const {},
    this.genres = const TriFilter(),
    this.tags = const TriFilter(),
    this.authors = const TriFilter(),
    this.onlyUnread = false,
    this.onlyStarted = false,
    this.onlyFavorite = false,
    this.onlyNew = false,
    this.minRating,
    this.auto,
    this.collectionId,
    this.seed = 0,
  });

  final String query;
  final LibrarySort sort;
  final bool descending;
  final Set<ShelfStatus> shelf;
  final Set<ReleaseStatus> release;
  final TriFilter genres;
  final TriFilter tags;
  final TriFilter authors;
  final bool onlyUnread;
  final bool onlyStarted;
  final bool onlyFavorite;
  final bool onlyNew;

  /// Voto minimo: chiedere anche il massimo servirebbe a cercare i brutti,
  /// che nessuno cerca.
  final int? minRating;
  final AutoCollection? auto;
  final String? collectionId;

  /// Rende ripetibile l'ordine casuale finché non lo si rimescola: una griglia
  /// che cambia a ogni ricostruzione non si riesce a percorrere.
  final int seed;

  bool get isFiltering => query.isNotEmpty || activeCount > 0;

  int get activeCount =>
      shelf.length +
      release.length +
      genres.length +
      tags.length +
      authors.length +
      (onlyUnread ? 1 : 0) +
      (onlyStarted ? 1 : 0) +
      (onlyFavorite ? 1 : 0) +
      (onlyNew ? 1 : 0) +
      (minRating == null ? 0 : 1);

  LibraryFilter copyWith({
    String? query,
    LibrarySort? sort,
    bool? descending,
    Set<ShelfStatus>? shelf,
    Set<ReleaseStatus>? release,
    TriFilter? genres,
    TriFilter? tags,
    TriFilter? authors,
    bool? onlyUnread,
    bool? onlyStarted,
    bool? onlyFavorite,
    bool? onlyNew,
    int? minRating,
    bool clearRating = false,
    AutoCollection? auto,
    bool clearAuto = false,
    String? collectionId,
    bool clearCollection = false,
    int? seed,
  }) =>
      LibraryFilter(
        query: query ?? this.query,
        sort: sort ?? this.sort,
        descending: descending ?? this.descending,
        shelf: shelf ?? this.shelf,
        release: release ?? this.release,
        genres: genres ?? this.genres,
        tags: tags ?? this.tags,
        authors: authors ?? this.authors,
        onlyUnread: onlyUnread ?? this.onlyUnread,
        onlyStarted: onlyStarted ?? this.onlyStarted,
        onlyFavorite: onlyFavorite ?? this.onlyFavorite,
        onlyNew: onlyNew ?? this.onlyNew,
        minRating: clearRating ? null : (minRating ?? this.minRating),
        auto: clearAuto ? null : (auto ?? this.auto),
        collectionId:
            clearCollection ? null : (collectionId ?? this.collectionId),
        seed: seed ?? this.seed,
      );

  /// Ripulisce i filtri lasciando in piedi la raccolta che si sta guardando.
  LibraryFilter cleared() => LibraryFilter(
        sort: sort,
        descending: descending,
        auto: auto,
        collectionId: collectionId,
        seed: seed,
      );
}

/// Applica filtri e ordinamento. L'ordine dell'elenco di raccolta, quando è
/// una raccolta manuale a essere aperta, è quello scelto dall'utente e vince
/// sull'ordinamento della libreria.
List<SeriesSignals> applyFilter(
  List<SeriesSignals> all,
  LibraryFilter filter, {
  List<String> collectionOrder = const [],
}) {
  final query = SearchQuery.parse(filter.query.trim());
  final result = all.where((signals) {
    final entry = signals.entry;
    if (!query.isEmpty && !query.matches(signals)) return false;
    if (filter.shelf.isNotEmpty && !filter.shelf.contains(signals.state.status)) {
      return false;
    }
    if (filter.release.isNotEmpty &&
        !filter.release.contains(entry.releaseStatus)) {
      return false;
    }
    if (!filter.genres.allows(entry.genres)) return false;
    if (!filter.tags.allows(entry.tags)) return false;
    if (!filter.authors.allows(signals.people)) return false;
    if (filter.onlyUnread && !signals.hasUnread) return false;
    if (filter.onlyStarted && !signals.isStarted) return false;
    if (filter.onlyFavorite && !signals.state.favorite) return false;
    if (filter.onlyNew && !signals.isNew) return false;
    final rating = signals.state.rating;
    if (filter.minRating != null &&
        (rating == null || rating < filter.minRating!)) {
      return false;
    }
    if (filter.auto != null && !filter.auto!.matches(signals)) return false;
    return true;
  }).toList();

  if (filter.collectionId != null) {
    final rank = {
      for (var position = 0; position < collectionOrder.length; position++)
        collectionOrder[position]: position,
    };
    result
      ..removeWhere((signals) => !rank.containsKey(signals.entry.key))
      ..sort((a, b) => rank[a.entry.key]!.compareTo(rank[b.entry.key]!));
    return result;
  }

  if (filter.sort == LibrarySort.shuffle) {
    result.sort((a, b) =>
        _shuffleKey(a, filter.seed).compareTo(_shuffleKey(b, filter.seed)));
    return result;
  }

  int compare(SeriesSignals a, SeriesSignals b) => switch (filter.sort) {
        LibrarySort.updated => a.freshness.compareTo(b.freshness),
        LibrarySort.title =>
          a.entry.title.toLowerCase().compareTo(b.entry.title.toLowerCase()),
        LibrarySort.progress => a.fraction.compareTo(b.fraction),
        LibrarySort.added => (a.entry.archivedAt ?? a.freshness)
            .compareTo(b.entry.archivedAt ?? b.freshness),
        LibrarySort.lastRead => a.lastRead.compareTo(b.lastRead),
        LibrarySort.unread => a.unreadCount.compareTo(b.unreadCount),
        LibrarySort.rating =>
          (a.state.rating ?? -1).compareTo(b.state.rating ?? -1),
        LibrarySort.chapters =>
          a.entry.archivedChapterCount.compareTo(b.entry.archivedChapterCount),
        LibrarySort.shuffle => 0,
      };

  result.sort((a, b) {
    final order = compare(a, b);
    if (order != 0) return filter.descending ? -order : order;
    return a.entry.title.toLowerCase().compareTo(b.entry.title.toLowerCase());
  });
  return result;
}

/// Un ordine casuale ma stabile: dipende dalla chiave della serie e dal seme,
/// quindi non cambia mentre si scorre.
int _shuffleKey(SeriesSignals signals, int seed) {
  var hash = seed;
  for (final unit in signals.entry.key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

/// I valori con cui si può filtrare, presi dalla libreria vera invece che da
/// un elenco fisso: i generi che contano sono quelli che l'archivio usa.
class LibraryFacets {
  const LibraryFacets({
    required this.genres,
    required this.tags,
    required this.authors,
  });

  factory LibraryFacets.of(Iterable<SeriesEntry> series) {
    final genres = <String>{};
    final tags = <String>{};
    final authors = <String>{};
    for (final entry in series) {
      genres.addAll(entry.genres);
      tags.addAll(entry.tags);
      authors
        ..addAll(entry.authors)
        ..addAll(entry.artists);
    }
    List<String> sorted(Set<String> values) =>
        values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return LibraryFacets(
      genres: sorted(genres),
      tags: sorted(tags),
      authors: sorted(authors),
    );
  }

  final List<String> genres;
  final List<String> tags;
  final List<String> authors;
}
