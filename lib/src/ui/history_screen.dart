/// Cronologia: cosa si è letto e quando.
///
/// È il rovescio della scheda della serie — lì si guarda una serie e si cerca
/// il capitolo, qui si guarda il tempo e si ritrova la serie. Su una libreria
/// con molte serie in corso è spesso il modo più corto per tornare dove si era.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/user_repository.dart';
import '../l10n.dart';
import '../providers.dart';
import 'library_screen.dart';
import 'reader_screen.dart';
import 'theme.dart';
import 'widgets/kit.dart';
import 'widgets/series_cover.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final library = ref.watch(libraryProvider);
    final history = ref.watch(historyProvider);
    final incognito = ref.watch(incognitoProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: [
          IconButton(
            tooltip: incognito ? l10n.historyIncognitoOn : l10n.historyIncognitoOff,
            onPressed: () => ref.read(incognitoProvider.notifier).toggle(),
            icon: Icon(
              incognito ? LucideIcons.eyeOff : LucideIcons.eye,
              color: incognito ? context.colors.primary : null,
            ),
          ),
          IconButton(
            tooltip: l10n.historyClear,
            onPressed: history.value?.isEmpty ?? true
                ? null
                : () => _confirmClear(context, ref),
            icon: const Icon(LucideIcons.trash2),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: switch (history) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => KEmpty(
            icon: LucideIcons.circleAlert,
            title: l10n.historyUnreadable,
            message: '$error',
          ),
        AsyncData(:final value) when value.isEmpty || library == null =>
          KEmpty(
            icon: LucideIcons.history,
            title: l10n.historyEmptyTitle,
            message: l10n.historyEmptyMessage,
          ),
        AsyncData(:final value) => _HistoryList(entries: value),
      },
      bottomNavigationBar: incognito
          ? const _IncognitoBanner()
          : null,
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showKagamiSheet<bool>(
      context,
      title: context.l10n.historyClearTitle,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.historyClearMessage,
              style: KagamiType.body(13.5, color: context.tokens.muted),
            ),
            const SizedBox(height: 22),
            KButton(
              label: context.l10n.historyClear,
              icon: LucideIcons.trash2,
              expand: true,
              tone: context.tokens.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(userRepositoryProvider).clearHistory();
    ref.invalidate(readingProvider);
  }
}

class _IncognitoBanner extends StatelessWidget {
  const _IncognitoBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(LucideIcons.eyeOff, size: 18, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.historyIncognitoBanner,
                  style: KagamiType.body(12.5, color: context.tokens.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le righe raggruppate per giorno, con l'intestazione appiccicata in alto:
/// scorrendo si sa sempre di che giorno si sta guardando.
class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries});

  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final days = groupBy(entries, (HistoryEntry entry) => entry.day);
    return CustomScrollView(
      slivers: [
        for (final day in days.keys)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _DayHeader(label: _dayLabel(context, day)),
              ),
              SliverList.builder(
                itemCount: days[day]!.length,
                itemBuilder: (context, position) =>
                    _HistoryTile(entry: days[day]![position]),
              ),
            ],
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  String _dayLabel(BuildContext context, DateTime day) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return l10n.historyToday;
    if (difference == 1) return l10n.historyYesterday;
    if (difference < 7) return DateFormat.EEEE(l10n.localeName).format(day);
    return DateFormat.yMMMMd(l10n.localeName).format(day);
  }
}

class _DayHeader extends SliverPersistentHeaderDelegate {
  const _DayHeader({required this.label});

  final String label;

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Container(
        color: context.colors.surface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: KagamiType.overline(color: context.tokens.muted),
        ),
      );

  @override
  bool shouldRebuild(_DayHeader old) => old.label != label;
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesEntryProvider(entry.seriesKey));
    // Una serie sparita dall'indice resta in cronologia: la sincronizzazione
    // può essere a metà e cancellare la riga sarebbe perdere un dato vero.
    final chapters = ref.watch(seriesIndexProvider(entry.seriesKey)).value;
    final chapter =
        chapters?.chapters.firstWhereOrNull((row) => row.id == entry.chapterId);
    final local = entry.readAt.toLocal();
    final time = DateFormat.Hm(context.l10n.localeName).format(local);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: KCard(
        padding: const EdgeInsets.all(10),
        onTap: series == null ? null : () => openSeries(context, entry.seriesKey),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 38,
                height: 54,
                child: CoverImage(entry: series, width: 38),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    series?.title ?? entry.seriesKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KagamiType.title(14, weight: 600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$time · ${chapter?.label() ?? entry.chapterId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        KagamiType.label(size: 11.5, color: context.tokens.muted),
                  ),
                ],
              ),
            ),
            if (chapter != null && chapter.isReadable)
              IconButton(
                tooltip: context.l10n.historyReread,
                onPressed: () => openReader(
                  context,
                  seriesKey: entry.seriesKey,
                  chapterId: entry.chapterId,
                ),
                icon: const Icon(LucideIcons.rotateCcw, size: 18),
              ),
            IconButton(
              tooltip: context.l10n.historyRemove,
              onPressed: () => ref
                  .read(readingProvider.notifier)
                  .setChapterRead(entry.seriesKey, entry.chapterId, false),
              icon: const Icon(LucideIcons.x, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
