/// Home: la domanda con cui si apre l'app.
///
/// Non è un secondo elenco della libreria, sono le risposte che si ricavano
/// dallo stato di lettura — dove ero, cosa è arrivato, cosa non ho ancora
/// aperto, cosa avevo lasciato a metà. Su serie in corso con un capitolo a
/// settimana è quasi sempre abbastanza per non passare dalla griglia.
library;

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library_view.dart';
import '../format/malf.dart';
import '../format/reading.dart';
import '../providers.dart';
import 'app_shell.dart';
import 'library_screen.dart';
import 'reader_screen.dart';
import 'statistics_screen.dart';
import 'theme.dart';
import 'drive_ui.dart';
import 'widgets/kit.dart';
import 'widgets/series_cover.dart';

final DateTime _never = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final all = ref.watch(librarySignalsProvider);
    if (library == null) return const SizedBox.shrink();

    final resume = all.where((s) => s.isStarted && s.hasUnread).sorted(
          (a, b) => _lastTouched(b).compareTo(_lastTouched(a)),
        );
    final updates = all
        .where((s) => s.hasUnread && s.entry.latestChapterArchivedAt != null)
        .sorted((a, b) => b.freshness.compareTo(a.freshness))
        .take(20)
        .toList(growable: false);
    final start = all
        .where(AutoCollection.planned.matches)
        .sorted((a, b) => b.freshness.compareTo(a.freshness));
    final added = all
        .where((s) => s.entry.archivedAt != null)
        .sorted((a, b) => b.entry.archivedAt!.compareTo(a.entry.archivedAt!))
        .take(20)
        .toList(growable: false);
    final abandoned = all
        .where((s) =>
            s.state.status == ShelfStatus.paused ||
            s.state.status == ShelfStatus.dropped)
        .sorted((a, b) => _lastTouched(b).compareTo(_lastTouched(a)));
    final similar = _similar(all);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            reloadLibrary(ref);
            ref.invalidate(readingProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: navBarInset),
            children: [
              _Greeting(library: all),
              const LibraryNotices(),
              if (all.isEmpty)
                const KEmpty(
                  icon: LucideIcons.bookOpen,
                  title: 'Libreria vuota',
                  message: 'Niente da sfogliare: la cartella non contiene '
                      'ancora nessuna serie.',
                )
              else ...[
                Entrance(child: _StatsStrip(library: all)),
                if (resume.isNotEmpty)
                  Entrance(
                    index: 1,
                    child:
                        _ResumeRow(series: resume.take(10).toList()),
                  ),
                if (updates.isNotEmpty)
                  Entrance(
                    index: 2,
                    child: _UpdatesSection(series: updates),
                  ),
                if (start.isNotEmpty)
                  Entrance(
                    index: 3,
                    child:
                        _Shelf(title: 'Da iniziare', series: start),
                  ),
                if (similar.isNotEmpty)
                  _Shelf(
                    title: 'Perché leggi quello che leggi',
                    subtitle: 'Non ancora aperte, con i generi che ti tornano',
                    series: similar,
                  ),
                if (added.isNotEmpty)
                  _Shelf(
                    title: 'Arrivate di recente',
                    series: added,
                  ),
                if (abandoned.isNotEmpty)
                  _Shelf(
                    title: 'Lasciate a metà',
                    subtitle: 'In pausa e abbandonate',
                    series: abandoned,
                  ),
                if (resume.isEmpty && updates.isEmpty && start.isEmpty)
                  const KEmpty(
                    icon: LucideIcons.circleCheck,
                    title: 'Sei in pari',
                    message: 'Con tutto quello che è sincronizzato. Il prossimo '
                        'capitolo arriverà con la cartella.',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static DateTime _lastTouched(SeriesSignals signals) =>
      signals.state.progress?.updatedAt ?? signals.state.updatedAt ?? _never;

  /// Serie mai aperte che condividono i generi di quelle lette: l'unica forma
  /// di consiglio possibile senza rete, e l'unica onesta — sa solo quello che
  /// c'è nell'archivio.
  static List<SeriesSignals> _similar(List<SeriesSignals> all) {
    final liked = <String, int>{};
    for (final signals in all) {
      final weight = switch (signals.state.status) {
        ShelfStatus.completed => 3,
        ShelfStatus.reading => 2,
        _ => signals.state.favorite ? 3 : 0,
      };
      if (weight == 0) continue;
      for (final genre in signals.entry.genres) {
        liked[genre] = (liked[genre] ?? 0) + weight;
      }
    }
    if (liked.isEmpty) return const [];
    final candidates = all
        .where((signals) => !signals.isStarted && signals.state.isEmpty)
        .map((signals) => (
              signals,
              signals.entry.genres
                  .fold<int>(0, (sum, genre) => sum + (liked[genre] ?? 0)),
            ))
        .where((row) => row.$2 > 0)
        .sorted((a, b) => b.$2.compareTo(a.$2));
    return [for (final row in candidates.take(20)) row.$1];
  }
}

/// L'intestazione: il nome dell'app, l'ora del giorno e le due azioni che non
/// stanno in nessun'altra parte — rileggere la cartella e pescare a caso.
class _Greeting extends ConsumerWidget {
  const _Greeting({required this.library});

  final List<SeriesSignals> library;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _partOfDay(),
                    style:
                        KagamiType.overline(color: context.tokens.muted),
                  ),
                  const SizedBox(height: 4),
                  Text('Kagami', style: KagamiType.display(30)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Una a caso',
              onPressed: library.isEmpty
                  ? null
                  : () => openSeries(
                        context,
                        library[Random().nextInt(library.length)].entry.key,
                      ),
              icon: const Icon(LucideIcons.dices),
            ),
            IconButton(
              tooltip: 'Rileggi la libreria',
              onPressed: () {
                reloadLibrary(ref);
                ref.invalidate(readingProvider);
              },
              icon: const Icon(LucideIcons.refreshCw),
            ),
          ],
        ),
      );

  static String _partOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Notte fonda';
    if (hour < 12) return 'Buongiorno';
    if (hour < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }
}

/// Tre numeri e la strada per gli altri: la home non è il posto delle
/// statistiche, ma è il posto da cui viene voglia di guardarle.
class _StatsStrip extends ConsumerWidget {
  const _StatsStrip({required this.library});

  final List<SeriesSignals> library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statistics = ref.watch(statisticsProvider).value;
    if (statistics == null) return const SizedBox.shrink();
    final unread = library.fold<int>(0, (sum, s) => sum + s.unreadCount);
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StatisticsScreen()),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: KStatCard(
              icon: LucideIcons.bookCheck,
              label: 'Letti',
              value: '${statistics.chaptersRead}',
              caption: 'capitoli in tutto',
              onTap: open,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KStatCard(
              icon: LucideIcons.layers,
              label: 'Da leggere',
              value: '$unread',
              caption: 'sul telefono',
              onTap: open,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KStatCard(
              icon: LucideIcons.flame,
              label: 'Di fila',
              value: '${statistics.streak}',
              caption: statistics.streak == 1 ? 'giorno' : 'giorni',
              tint: statistics.streak > 0 ? context.tokens.warning : null,
              onTap: open,
            ),
          ),
        ],
      ),
    );
  }
}

/// La ripresa non è una copertina fra le altre: è il gesto per cui si apre
/// l'app, e dice a voce alta dove si era rimasti.
class _ResumeRow extends ConsumerWidget {
  const _ResumeRow({required this.series});

  final List<SeriesSignals> series;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Riprendi'),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: series.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, position) =>
                  _ResumeCard(signals: series[position]),
            ),
          ),
        ],
      );
}

class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.signals});

  final SeriesSignals signals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.tokens.muted;
    final progress = signals.state.progress;
    final chapters = ref.watch(seriesIndexProvider(signals.entry.key)).value;
    final target = _target(chapters?.readable ?? const []);

    return SizedBox(
      width: 296,
      child: KCard(
        padding: EdgeInsets.zero,
        onTap: () => openSeries(context, signals.entry.key),
        child: Row(
          children: [
            // KCard non ritaglia i figli: senza, la copertina copre gli
            // angoli tondi a sinistra.
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(22)),
              child: SizedBox(
                width: 100,
                height: 150,
                child: CoverImage(
                  entry: signals.entry,
                  width: 100,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      signals.entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KagamiType.title(14.5, weight: 700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      target?.label() ?? 'Capitolo successivo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KagamiType.body(12.5, color: muted),
                    ),
                    if (progress != null && progress.fraction > 0) ...[
                      const SizedBox(height: 9),
                      KProgress(value: progress.fraction, height: 4),
                    ],
                    const SizedBox(height: 11),
                    KButton(
                      label: 'Leggi',
                      icon: LucideIcons.play,
                      height: 38,
                      onPressed: target == null
                          ? null
                          : () => openReader(
                                context,
                                seriesKey: signals.entry.key,
                                chapterId: target.id,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Il capitolo lasciato a metà, altrimenti il primo non letto.
  ChapterEntry? _target(List<ChapterEntry> readable) {
    final state = signals.state;
    final progress = state.progress;
    if (progress != null && !state.readChapters.contains(progress.chapterId)) {
      final open =
          readable.firstWhereOrNull((row) => row.id == progress.chapterId);
      if (open != null) return open;
    }
    return readable
        .sorted((a, b) => a.order.compareTo(b.order))
        .firstWhereOrNull((row) => !state.readChapters.contains(row.id));
  }
}

/// I capitoli arrivati, in ordine di arrivo: è la scheda che in un lettore
/// con serie in corso si guarda per prima.
class _UpdatesSection extends StatelessWidget {
  const _UpdatesSection({required this.series});

  final List<SeriesSignals> series;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'Aggiornamenti',
          subtitle: 'Capitoli sincronizzati e non ancora letti',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: KCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final signals in series)
                  KPress(
                    onTap: () => openSeries(context, signals.entry.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 40,
                              height: 56,
                              child: CoverImage(
                                entry: signals.entry,
                                width: 40,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  signals.entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: KagamiType.title(
                                    14,
                                    weight: signals.isNew ? 700 : 500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (signals.entry.latestChapterNumber !=
                                        null)
                                      'cap. ${signals.entry.latestChapterNumber}',
                                    _ago(signals.freshness),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: KagamiType.label(
                                    size: 11.5,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: signals.isNew
                                  ? context.colors.primary
                                      .withValues(alpha: 0.18)
                                  : context.colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              '${signals.unreadCount}',
                              style: KagamiType.figure(
                                12,
                                color: signals.isNew
                                    ? context.colors.primary
                                    : muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Quanto tempo fa, in parole: una data esatta qui non dice niente.
  static String _ago(DateTime when) {
    final days = DateTime.now().toUtc().difference(when).inDays;
    if (days <= 0) return 'oggi';
    if (days == 1) return 'ieri';
    if (days < 7) return '$days giorni fa';
    if (days < 30) return '${days ~/ 7} settimane fa';
    if (days < 365) return '${days ~/ 30} mesi fa';
    return '${days ~/ 365} anni fa';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: KagamiType.display(19)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: KagamiType.body(12.5, color: context.tokens.muted),
              ),
            ],
          ],
        ),
      );
}

/// Una fila orizzontale di copertine: scorre da sé e non costringe a scegliere
/// fra vedere tutto e vedere qualcosa.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.series,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<SeriesSignals> series;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title, subtitle: subtitle),
          SizedBox(
            height: 238,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: series.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, position) => SizedBox(
                width: 118,
                child: SeriesCover(
                  signals: series[position],
                  onTap: () => openSeries(context, series[position].entry.key),
                ),
              ),
            ),
          ),
        ],
      );
}
