/// Statistiche: cosa dice la cronologia se la si guarda da lontano.
///
/// Ogni grafico risponde a una domanda sola, e la domanda sta nel titolo. Le
/// serie storiche vengono dalla cronologia — quindi esistono solo da quando
/// l'app la registra — mentre la composizione della libreria viene dagli
/// indici, che sanno tutto fin dall'inizio.
library;

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library_view.dart';
import '../data/statistics.dart';
import '../format/reading.dart';
import '../l10n.dart';
import '../providers.dart';
import 'series_screen.dart';
import 'widgets/charts.dart';
import 'widgets/kit.dart';

/// Le finestre temporali della serie storica: una settimana non mostra una
/// abitudine, dieci anni non mostrano un mese.
enum StatsRange {
  month(30),
  quarter(90),
  year(365);

  const StatsRange(this.days);

  final int days;

  String label(AppLocalizations l10n) => switch (this) {
        month => l10n.statsRangeMonth,
        quarter => l10n.statsRangeQuarter,
        year => l10n.statsRangeYear,
      };
}

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  StatsRange _range = StatsRange.quarter;

  @override
  Widget build(BuildContext context) {
    final statistics = ref.watch(statisticsProvider);
    final library = ref.watch(librarySignalsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.statsTitle)),
      body: switch (statistics) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => KEmpty(
            icon: LucideIcons.circleAlert,
            title: context.l10n.statsUnavailable,
            message: '$error',
          ),
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              _Totals(statistics: value, library: library),
              _ChaptersOverTime(statistics: value, range: _range,
                  onRange: (range) => setState(() => _range = range)),
              _Activity(statistics: value),
              _ShelfPie(library: library),
              _GenrePie(library: library),
              _Ratings(library: library),
              _TopSeries(statistics: value),
              _LibraryShape(library: library),
            ],
          ),
      },
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.statistics, required this.library});

  final ReadingStatistics statistics;
  final List<SeriesSignals> library;

  @override
  Widget build(BuildContext context) {
    final rated = library.where((s) => s.state.rating != null).toList();
    final average = rated.isEmpty
        ? null
        : rated.fold<int>(0, (sum, s) => sum + s.state.rating!) / rated.length;
    final hours = statistics.timeRead.inMinutes / 60;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          StatTile(
            value: '${statistics.chaptersRead}',
            label: l10n.statsChaptersRead,
          ),
          StatTile(value: '${library.length}', label: l10n.statsSeriesInLibrary),
          StatTile(
            value: hours < 1
                ? l10n.statsMinutes(statistics.timeRead.inMinutes)
                : l10n.statsHours(hours.round()),
            label: l10n.statsReadingTime,
            hint: l10n.statsReadingTimeHint,
          ),
          StatTile(
            value: '${statistics.pagesRead}',
            label: l10n.statsPagesSeen,
          ),
          StatTile(
            value: '${statistics.streak}',
            label: l10n.statsStreak,
            hint: l10n.statsStreakRecord(statistics.longestStreak),
          ),
          StatTile(
            value: average == null ? '—' : average.toStringAsFixed(1),
            label: l10n.statsAverageRating,
            hint: l10n.statsRatedSeries(rated.length),
          ),
        ],
      ),
    );
  }
}

/// Capitoli letti nel tempo. Sotto i tre mesi si guarda giorno per giorno;
/// oltre, la settimana è l'unità in cui si riconosce un'abitudine.
class _ChaptersOverTime extends StatelessWidget {
  const _ChaptersOverTime({
    required this.statistics,
    required this.range,
    required this.onRange,
  });

  final ReadingStatistics statistics;
  final StatsRange range;
  final ValueChanged<StatsRange> onRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekly = range != StatsRange.month;
    final buckets = <DateTime, int>{};
    for (var back = range.days - 1; back >= 0; back--) {
      final day = today.subtract(Duration(days: back));
      final key = weekly
          ? day.subtract(Duration(days: (day.weekday - 1) % 7))
          : day;
      buckets[key] = (buckets[key] ?? 0) + (statistics.perDay[day] ?? 0);
    }
    final points = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final highest =
        points.fold<int>(1, (top, row) => row.value > top ? row.value : top);

    return ChartCard(
      title: context.l10n.statsChaptersOverTime,
      subtitle: weekly
          ? context.l10n.statsPerWeek
          : context.l10n.statsPerDay,
      height: 180,
      // Le tre finestre stanno tutte su una riga: nasconderle in un menù
      // significherebbe non guardarle mai.
      trailing: SizedBox(
        width: 168,
        child: KSegmented(
          options: [for (final value in StatsRange.values) value.label(context.l10n)],
          index: range.index,
          onChanged: (index) => onRange(StatsRange.values[index]),
        ),
      ),
      child: points.every((row) => row.value == 0)
          ? _NoHistory(theme: theme)
          : LineChart(
              LineChartData(
                minY: 0,
                maxY: highest * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: (highest / 2).clamp(1, double.infinity),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (highest / 2).clamp(1, double.infinity),
                      getTitlesWidget: (value, _) => Text(
                        value.round().toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (points.length / 4).ceilToDouble(),
                      getTitlesWidget: (value, _) {
                        final position = value.round();
                        if (position < 0 || position >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final day = points[position].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat.Md(context.l10n.localeName).format(day),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].value.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    barWidth: 2,
                    color: theme.colorScheme.primary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity({required this.statistics});

  final ReadingStatistics statistics;

  @override
  Widget build(BuildContext context) => ChartCard(
        title: context.l10n.statsActivityTitle,
        subtitle: context.l10n.statsActivitySubtitle,
        height: 116,
        child: ActivityCalendar(perDay: statistics.perDay, days: 182),
      );
}

/// Come sono divise le serie fra i tuoi stati. La torta ha senso qui perché
/// le parti sono un intero: ogni serie sta in uno stato e uno solo.
class _ShelfPie extends StatelessWidget {
  const _ShelfPie({required this.library});

  final List<SeriesSignals> library;

  @override
  Widget build(BuildContext context) {
    final palette = chartPalette(context);
    final counts = <ShelfStatus, int>{};
    for (final signals in library) {
      counts[signals.state.status] = (counts[signals.state.status] ?? 0) + 1;
    }
    final slices = ShelfStatus.values
        .where((status) => (counts[status] ?? 0) > 0)
        .toList(growable: false);
    if (slices.isEmpty) return const SizedBox.shrink();
    final total = library.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChartCard(
          title: context.l10n.statsShelfTitle,
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: counts[slices[i]]!.toDouble(),
                    color: palette[i % palette.length],
                    radius: 42,
                    title: '${(counts[slices[i]]! * 100 / total).round()}%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ChartLegend(
            entries: [
              for (var i = 0; i < slices.length; i++)
                (
                  shelfLabels[slices[i]]!,
                  palette[i % palette.length],
                  '${counts[slices[i]]}',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// I generi che leggi davvero: contati sulle serie iniziate, non su tutta la
/// libreria, che direbbe solo cosa l'archivio contiene.
class _GenrePie extends StatelessWidget {
  const _GenrePie({required this.library});

  final List<SeriesSignals> library;

  @override
  Widget build(BuildContext context) {
    final palette = chartPalette(context);
    final counts = <String, int>{};
    for (final signals in library.where((s) => s.isStarted)) {
      for (final genre in signals.entry.genres) {
        counts[genre] = (counts[genre] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final ranked = counts.entries.sorted((a, b) => b.value.compareTo(a.value));
    // Oltre cinque fette la torta diventa un mosaico: il resto è "altri".
    final top = ranked.take(5).toList();
    final rest = ranked.skip(5).fold<int>(0, (sum, row) => sum + row.value);
    final slices = <(String, int)>[
      for (final row in top) (row.key, row.value),
      if (rest > 0) (context.l10n.statsGenreOthers(ranked.length - 5), rest),
    ];
    final total = slices.fold<int>(0, (sum, row) => sum + row.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChartCard(
          title: context.l10n.statsGenresTitle,
          subtitle: context.l10n.statsGenresSubtitle,
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].$2.toDouble(),
                    color: palette[i % palette.length],
                    radius: 42,
                    title: '${(slices[i].$2 * 100 / total).round()}%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ChartLegend(
            entries: [
              for (var i = 0; i < slices.length; i++)
                (slices[i].$1, palette[i % palette.length], '${slices[i].$2}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ratings extends StatelessWidget {
  const _Ratings({required this.library});

  final List<SeriesSignals> library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = List<int>.filled(11, 0);
    for (final signals in library) {
      final rating = signals.state.rating;
      if (rating != null) counts[rating.clamp(0, 10)]++;
    }
    if (counts.every((value) => value == 0)) return const SizedBox.shrink();
    final highest = counts.reduce((a, b) => a > b ? a : b);

    return ChartCard(
      title: context.l10n.statsRatingsTitle,
      subtitle: context.l10n.statsRatingsSubtitle,
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: highest * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${value.round()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barGroups: [
            for (var rating = 0; rating <= 10; rating++)
              BarChartGroupData(
                x: rating,
                barRods: [
                  BarChartRodData(
                    toY: counts[rating].toDouble(),
                    width: 12,
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Le serie su cui è finito il tempo. Un elenco con una barra dietro dice la
/// stessa cosa di un grafico a barre, e in più si può toccare.
class _TopSeries extends ConsumerWidget {
  const _TopSeries({required this.statistics});

  final ReadingStatistics statistics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (statistics.topSeries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final highest = statistics.topSeries.first.$2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.statsTopSeries, style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          for (final (key, chapters) in statistics.topSeries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ref.watch(seriesEntryProvider(key))?.title ?? key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '$chapters',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: chapters / highest,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Com'è fatta la libreria, che è una domanda sull'archivio e non su di te:
/// si risponde con gli indici e vale anche il primo giorno.
class _LibraryShape extends StatelessWidget {
  const _LibraryShape({required this.library});

  final List<SeriesSignals> library;

  @override
  Widget build(BuildContext context) {
    if (library.isEmpty) return const SizedBox.shrink();
    final chapters =
        library.fold<int>(0, (sum, s) => sum + s.entry.archivedChapterCount);
    final unread = library.fold<int>(0, (sum, s) => sum + s.unreadCount);
    final ongoing = library.where((s) => s.entry.isOngoing).length;
    final bytes = library.fold<int>(0, (sum, s) => sum + s.entry.bytes);
    final missing =
        library.fold<int>(0, (sum, s) => sum + s.entry.missingChapterCount);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.statsShapeTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              StatTile(value: '$chapters', label: l10n.statsSyncedChapters),
              StatTile(value: '$unread', label: l10n.statsStillUnread),
              StatTile(
                value: '$ongoing',
                label: l10n.statsOngoingSeries,
                hint: missing == 0 ? null : l10n.statsAnnouncedMissing(missing),
              ),
              StatTile(
                value: '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB',
                label: l10n.statsBytesOnPhone,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoHistory extends StatelessWidget {
  const _NoHistory({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          context.l10n.statsNoHistory,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
