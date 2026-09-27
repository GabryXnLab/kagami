/// Le domande che si fanno alla cronologia.
///
/// Sono aggregazioni, non elenchi: quanti capitoli in questo mese, quanti
/// giorni di fila, quale serie ha preso più tempo. Stanno qui e non nella
/// schermata perché una somma è una query, e perché un grafico sbagliato è
/// più difficile da riconoscere di un numero sbagliato.
library;

import 'package:drift/drift.dart';

import 'db/database.dart';

/// Quante tavole al minuto si assume di leggere quando di una sessione non
/// c'è traccia: è la stessa stima grossolana della scheda della serie.
const double pagesPerMinute = 3;

/// Un giorno di lettura, con quanto ci si è letto.
typedef DayCount = (DateTime day, int chapters);

/// Una voce di classifica: una serie, un genere, un voto.
typedef Ranked = (String label, int value);

class ReadingStatistics {
  const ReadingStatistics({
    required this.chaptersRead,
    required this.pagesRead,
    required this.timeRead,
    required this.perDay,
    required this.perMonth,
    required this.topSeries,
    required this.firstRead,
  });

  static const ReadingStatistics empty = ReadingStatistics(
    chaptersRead: 0,
    pagesRead: 0,
    timeRead: Duration.zero,
    perDay: {},
    perMonth: {},
    topSeries: [],
    firstRead: null,
  );

  /// Capitoli finiti, comprese le letture importate dal vecchio `reading/`:
  /// erano letture vere, solo senza una data credibile.
  final int chaptersRead;

  /// Tavole viste, dalle sessioni: è la misura più vicina a "quanto ho letto"
  /// che l'app possa avere senza inventare.
  final int pagesRead;
  final Duration timeRead;

  /// Capitoli per giorno locale, nella finestra chiesta. Solo date vere.
  final Map<DateTime, int> perDay;

  /// Capitoli per mese, dal primo mese con letture.
  final Map<DateTime, int> perMonth;

  final List<(String seriesKey, int chapters)> topSeries;
  final DateTime? firstRead;

  /// Giorni di fila fino a oggi. Ieri conta come oggi: una serie di giorni non
  /// si spezza perché non si è ancora letto stamattina.
  int get streak {
    if (perDay.isEmpty) return 0;
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!perDay.containsKey(day)) {
      day = day.subtract(const Duration(days: 1));
      if (!perDay.containsKey(day)) return 0;
    }
    var count = 0;
    while (perDay.containsKey(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// La serie più lunga di giorni consecutivi, anche se è finita.
  int get longestStreak {
    if (perDay.isEmpty) return 0;
    final days = perDay.keys.toList()..sort();
    var best = 1;
    var current = 1;
    for (var position = 1; position < days.length; position++) {
      final gap = days[position].difference(days[position - 1]).inDays;
      current = gap == 1 ? current + 1 : 1;
      if (current > best) best = current;
    }
    return best;
  }

  /// Media dei giorni in cui si è letto qualcosa: la media su tutti i giorni
  /// direbbe solo quanto spesso si legge, che è un'altra domanda.
  double get chaptersPerReadingDay => perDay.isEmpty
      ? 0
      : perDay.values.fold<int>(0, (sum, value) => sum + value) / perDay.length;
}

class StatisticsRepository {
  StatisticsRepository(this.db, {this.profileId = defaultProfileId});

  final KagamiDatabase db;
  final String profileId;

  /// [window] limita i giorni della serie storica: un anno basta a ogni
  /// grafico dell'app e tiene la query corta anche dopo anni di letture.
  Future<ReadingStatistics> load({Duration window = const Duration(days: 365)}) async {
    final since = DateTime.now().toUtc().subtract(window);

    final counted = await db.customSelect(
      'SELECT COUNT(*) AS total FROM chapter_reads WHERE profile_id = ?',
      variables: [Variable<String>(profileId)],
      readsFrom: {db.chapterReads},
    ).getSingle();

    final reads = await (db.select(db.chapterReads)
          ..where((row) =>
              row.profileId.equals(profileId) & row.estimated.equals(false)))
        .get();

    final sessions = await (db.select(db.readingSessions)
          ..where((row) => row.profileId.equals(profileId)))
        .get();

    final perDay = <DateTime, int>{};
    final perMonth = <DateTime, int>{};
    final perSeries = <String, int>{};
    DateTime? first;
    for (final read in reads) {
      final local = read.readAt.toLocal();
      final month = DateTime(local.year, local.month);
      perMonth[month] = (perMonth[month] ?? 0) + 1;
      perSeries[read.seriesKey] = (perSeries[read.seriesKey] ?? 0) + 1;
      if (first == null || read.readAt.isBefore(first)) first = read.readAt;
      if (read.readAt.isBefore(since)) continue;
      final day = DateTime(local.year, local.month, local.day);
      perDay[day] = (perDay[day] ?? 0) + 1;
    }

    final top = perSeries.entries.map((row) => (row.key, row.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    return ReadingStatistics(
      chaptersRead: counted.read<int>('total'),
      pagesRead:
          sessions.fold<int>(0, (sum, session) => sum + session.pagesRead),
      timeRead: sessions.fold<Duration>(
        Duration.zero,
        (total, session) =>
            total + session.endedAt.difference(session.startedAt),
      ),
      perDay: perDay,
      perMonth: perMonth,
      topSeries: top.take(10).toList(growable: false),
      firstRead: first,
    );
  }
}
