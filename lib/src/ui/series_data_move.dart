/// «Porta qui i miei dati» sulla scheda di una serie (FASE-5b §3, F5.16):
/// si sceglie un'altra serie della libreria, il foglio dice cosa passa e cosa
/// si perde, e solo dopo la conferma i dati si spostano.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/series_data_move.dart';
import '../format/malf.dart';
import '../l10n.dart';
import '../providers.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// Le serie, oltre a [target], di cui l'utente ha dati da portare.
Future<List<SeriesEntry>> _candidates(WidgetRef ref, String target) async {
  final index = await ref.read(libraryIndexProvider.future);
  final withData = await ref.read(userRepositoryProvider).keysWithData();
  return [
    for (final entry in index.series)
      if (entry.key != target && withData.contains(entry.key)) entry,
  ];
}

/// Il gesto intero, da [target] verso se stessa. Restituisce se i dati sono
/// stati spostati.
Future<bool> bringDataHere(BuildContext context, WidgetRef ref, SeriesEntry target) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final candidates = await _candidates(ref, target.key);
  if (!context.mounted) return false;
  final source = await showKagamiSheet<SeriesEntry>(
    context,
    title: l10n.seriesBringDataPick,
    scrollable: true,
    builder: (context) => candidates.isEmpty
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Text(
              l10n.seriesBringDataEmpty,
              style: KagamiType.body(13.5, height: 1.5, color: context.tokens.muted),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in candidates)
                KTile(
                  icon: LucideIcons.bookOpen,
                  title: entry.title,
                  onTap: () => Navigator.of(context).pop(entry),
                ),
            ],
          ),
  );
  if (source == null || !context.mounted) return false;

  final chapters = await (
    ref.read(seriesChaptersProvider(source.key).future),
    ref.read(seriesChaptersProvider(target.key).future),
  ).wait;
  if (!context.mounted) return false;
  final (from, to) = chapters;
  if (from == null || to == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.seriesBringDataNoChapters)));
    return false;
  }
  final plan = planSeriesDataMove(
    from: source.key,
    to: target.key,
    fromChapters: from.index.chapters,
    toChapters: to.index.chapters,
    readInFrom: ref.read(seriesStateProvider(source.key)).readChapters,
  );
  final moved = await runSeriesDataMove(
    plan,
    confirm: (plan) async =>
        await showKagamiSheet<bool>(
          context,
          title: l10n.seriesBringData,
          builder: (context) => _Confirm(plan: plan, from: source.title, to: target.title),
        ) ==
        true,
    move: (plan) async {
      final repository = ref.read(userRepositoryProvider);
      await repository.dropChaptersExcept(plan.from, plan.chapters.keys.toSet());
      await ref.read(readingProvider.notifier).moveSeries(plan.from, plan.to, chapters: plan.chapters);
      ref.invalidate(seriesActivityProvider);
    },
  );
  if (moved) messenger.showSnackBar(SnackBar(content: Text(l10n.seriesBringDataDone(target.title))));
  return moved;
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.plan, required this.from, required this.to});

  final SeriesDataMove plan;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.seriesBringDataBody(from, to, plan.matchedReads),
            style: KagamiType.body(13.5, height: 1.5, color: context.tokens.muted),
          ),
          if (plan.lostReads > 0) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.triangleAlert, size: 16, color: context.tokens.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.seriesBringDataLost(plan.lostReads),
                    style: KagamiType.body(13, height: 1.45, color: context.tokens.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          KButton(
            label: l10n.seriesBringDataConfirm,
            icon: LucideIcons.arrowRightLeft,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
