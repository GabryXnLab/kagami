/// «Su altri siti»: la serie sugli altri siti registrati, nella scheda, e
/// dall'avviso di un sito rotto l'elenco delle sue serie con dove altro si
/// leggono (`docs/design.md`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/elsewhere.dart';
import 'package:kagami_archive/providers.dart' show providerById;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/elsewhere.dart';
import '../format/malf.dart';
import '../l10n.dart';
import '../providers.dart';
import 'library_screen.dart' show seriesRoute;
import 'theme.dart';
import 'widgets/kit.dart';

/// La sezione nella scheda di [entry]: dalla copia subito, poi rinfrescata.
/// [onSwitch] riceve il link trovato su un sito; senza, le righe non hanno
/// il pulsante.
class ElsewhereSection extends ConsumerWidget {
  const ElsewhereSection({required this.entry, required this.onSwitch, super.key});

  final SeriesEntry entry;
  final ValueChanged<String>? onSwitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alternatives = ref.watch(seriesManifestProvider(entry.key)).value?['metadata'];
    final target = ElsewhereTarget(
      entry.key,
      [
        entry.title,
        if (alternatives is Map && alternatives['alternativeTitles'] is List)
          for (final title in alternatives['alternativeTitles'] as List)
            if (title is String && title.trim().isNotEmpty) title,
      ],
      concluded: const {'completed', 'cancelled'}.contains(entry.releaseStatus.name),
    );
    final view = ref.watch(elsewhereProvider(target)).value ?? const ElsewhereView(busy: true);
    final chapters = ref.watch(seriesChaptersProvider(entry.key)).value?.index.chapters ?? const <ChapterEntry>[];
    return ElsewhereRows(data: view.data, busy: view.busy, chapters: chapters, onSwitch: onSwitch);
  }
}

class ElsewhereRows extends StatelessWidget {
  const ElsewhereRows({required this.data, required this.busy, required this.chapters, this.onSwitch, super.key});

  final Elsewhere? data;
  final bool busy;

  /// Quelli della serie in uso: il termine di paragone di avanti/indietro.
  final List<ChapterEntry> chapters;
  final ValueChanged<String>? onSwitch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sites = [
      for (final copy in data?.sites.values ?? const <SiteCopy>[])
        if (providerById(copy.provider) != null) copy,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KSection(l10n.elsewhereTitle),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.elsewhereChecking, style: KagamiType.body(12.5, color: context.tokens.muted)),
                ),
              ],
            ),
          ),
        for (final copy in sites)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SiteRow(copy: copy, chapters: chapters, onSwitch: onSwitch),
          ),
      ],
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.copy, required this.chapters, required this.onSwitch});

  final SiteCopy copy;
  final List<ChapterEntry> chapters;
  final ValueChanged<String>? onSwitch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final provider = providerById(copy.provider)!;
    final found = copy.state == ElsewhereState.found;
    final url = copy.url;
    final lines = <String>[
      switch (copy.state) {
        ElsewhereState.found => [
            if (copy.chapters != null) l10n.elsewhereChapters(copy.chapters!),
            ?_distance(l10n),
          ].join(' · '),
        ElsewhereState.missing => l10n.elsewhereMissing,
        ElsewhereState.broken => l10n.elsewhereBroken,
        ElsewhereState.gated => l10n.elsewhereGated,
        ElsewhereState.error => l10n.elsewhereError,
      },
      if (copy.latest != null)
        copy.latestAt == null
            ? l10n.elsewhereLatest(copy.latest!)
            : l10n.elsewhereLatestAt(copy.latest!, copy.latestAt!),
    ].where((line) => line.isNotEmpty).toList();
    return KCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SiteIcon(provider, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider.name, style: KagamiType.title(14.5, color: context.colors.onSurface)),
                for (final line in lines)
                  Text(
                    line,
                    style: KagamiType.body(
                      12.5,
                      height: 1.45,
                      color: copy.state == ElsewhereState.broken ? tokens.danger : tokens.muted,
                    ),
                  ),
                if (found && url != null && onSwitch != null) ...[
                  const SizedBox(height: 10),
                  KGhostButton(
                    label: l10n.elsewhereSwitch,
                    icon: LucideIcons.arrowLeftRight,
                    height: 38,
                    onPressed: () => onSwitch!(url),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _distance(AppLocalizations l10n) {
    final diff = chaptersAhead(copy.latest, chapters);
    if (diff == null) return null;
    final count = diff.round();
    return count == 0
        ? l10n.elsewhereSame
        : count > 0
            ? l10n.elsewhereAhead(count)
            : l10n.elsewhereBehind(-count);
  }
}

/// Le serie in libreria di [site] (l'avviso di un sito rotto) e, per
/// ciascuna, gli altri siti dove c'è: dalla copia e, col server, dalla sua
/// risposta. Toccare una serie apre la sua scheda.
class ElsewhereSitePage extends ConsumerWidget {
  const ElsewhereSitePage({required this.site, super.key});

  final String site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final series = [
      for (final signals in ref.watch(shownSignalsProvider))
        if (signals.entry.provider == site) signals.entry,
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final found = ref.watch(siteElsewhereProvider(site));
    final copies = found.value ?? const <String, Elsewhere>{};
    return Scaffold(
      appBar: AppBar(title: Text(l10n.elsewhereSiteTitle(providerById(site)?.name ?? site))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (ref.watch(archiveEngineProvider) != ArchiveEngine.server)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(l10n.elsewhereSiteOffline, style: KagamiType.body(12.5, height: 1.45, color: tokens.muted)),
            ),
          if (found.isLoading) const LinearProgressIndicator(minHeight: 3),
          if (series.isEmpty && !found.isLoading)
            Text(l10n.elsewhereSiteEmpty, style: KagamiType.body(13, color: tokens.muted)),
          for (final entry in series)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(seriesRoute(entry.key)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: KagamiType.title(14.5, color: context.colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      _summary(l10n, copies[entry.key]),
                      style: KagamiType.body(12.5, height: 1.45, color: tokens.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _summary(AppLocalizations l10n, Elsewhere? data) {
    if (data == null) return l10n.elsewhereSiteUnknown;
    final names = [
      for (final copy in data.sites.values)
        if (copy.state == ElsewhereState.found) providerById(copy.provider)?.name ?? copy.provider,
    ];
    return names.isEmpty ? l10n.elsewhereSiteNowhere : names.join(', ');
  }
}
