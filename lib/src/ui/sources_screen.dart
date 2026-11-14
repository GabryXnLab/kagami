/// Impostazioni → Libreria → «Sorgenti»: da dove arrivano le serie e in che
/// ordine si preferiscono (`handoff/raccolte-social-sorgenti/FASE-6.md`,
/// «Piano della schermata»).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'drive_received_sheet.dart' show sharedNameOf;
import '../data/sources/source.dart';
import '../l10n.dart';
import '../providers.dart';
import '../providers_sources.dart';
import 'sources_sheets.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// Lo stato di ogni sorgente che non risponde, dagli avvisi del catalogo e da
/// quelli di quando la sorgente si è accesa (scaduta, indirizzo non valido).
final sourceStatesProvider = Provider<Map<String, SourceState>>((ref) {
  final notices = [
    ...ref.watch(storageSourcesProvider).notices,
    ...ref.watch(libraryCatalogProvider).value?.notices ?? const [],
  ];
  return {
    for (final notice in notices.whereType<SourceUnavailable>()) notice.sourceId: notice.state,
  };
});

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sources = ref.watch(storageSourcesProvider).sources;
    final added = ref.watch(librarySourcesProvider).value?.sources ?? const <SourceConfig>[];
    final states = ref.watch(sourceStatesProvider);
    final builtIn = [
      for (final source in sources)
        if (const {SourceKind.folder, SourceKind.appPrivate, SourceKind.drive}.contains(source.config.kind)) source.config,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sourcesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(l10n.sourcesHelp, style: KagamiType.body(13, height: 1.45, color: context.tokens.muted)),
          ),
          for (final config in builtIn) _Row(config: config, state: states[config.id] ?? SourceState.ready),
          if (added.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (from, to) {
                final ids = [for (final config in added) config.id];
                ids.insert(to, ids.removeAt(from));
                unawaited(ref.read(librarySourcesProvider.notifier).reorder(ids));
              },
              children: [
                for (final (index, config) in added.indexed)
                  _Row(
                    key: ValueKey(config.id),
                    config: config,
                    state: states[config.id] == SourceState.otherAccount
                        ? SourceState.otherAccount
                        : config.expiredAt(DateTime.now()) ? SourceState.expired : states[config.id] ?? SourceState.ready,
                    index: index,
                    onTap: () => SourceDetailSheet.open(context, config, states[config.id]),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          KButton(
            label: l10n.sourcesAdd,
            icon: LucideIcons.plus,
            expand: true,
            onPressed: () => AddSourceSheet.open(context),
          ),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.config, required this.state, this.index, this.onTap, super.key});

  final SourceConfig config;
  final SourceState state;

  /// La posizione fra le aggiunte, se si può trascinare.
  final int? index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final (icon, title, subtitle) = switch (config.kind) {
      SourceKind.folder => (LucideIcons.folder, l10n.sourcesBuiltInFolder, null),
      SourceKind.appPrivate => (LucideIcons.smartphone, l10n.sourcesBuiltInApp, null),
      SourceKind.drive => (LucideIcons.cloud, l10n.sourcesBuiltInDrive, null),
      SourceKind.driveShared => (
          LucideIcons.users,
          sharedNameOf(config),
          config.params['owner'] is String ? l10n.sourcesOwner('${config.params['ownerName'] ?? config.params['owner']}') : null,
        ),
      SourceKind.webdav => (
          LucideIcons.server,
          config.label,
          [l10n.sourcesKindWebdav, Uri.tryParse('${config.params['url']}')?.host ?? ''].where((s) => s.isNotEmpty).join(' · '),
        ),
      SourceKind.smb => (
          LucideIcons.hardDrive,
          config.label,
          [l10n.sourcesKindSmb, '${config.params['host'] ?? ''}'].where((s) => s.isNotEmpty).join(' · '),
        ),
    };
    final (stateIcon, stateText, tone) = switch (state) {
      SourceState.ready => (LucideIcons.circleCheck, l10n.sourcesStateReady, tokens.success),
      SourceState.offline => (LucideIcons.wifiOff, l10n.sourcesStateOffline, tokens.warning),
      SourceState.needsAuth => (LucideIcons.keyRound, l10n.sourcesStateNeedsAuth, tokens.warning),
      SourceState.expired => (
          LucideIcons.clock,
          l10n.sourcesStateExpired(config.expiresAt == null ? '' : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(config.expiresAt!.toLocal())),
          tokens.danger,
        ),
      SourceState.missing => (LucideIcons.folderX, l10n.sourcesStateMissing, tokens.danger),
      SourceState.otherAccount => (LucideIcons.userX, l10n.sourcesStateOtherAccount, tokens.warning),
    };
    final readOnly = config.kind == SourceKind.driveShared || config.kind == SourceKind.webdav ||
        config.kind == SourceKind.smb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KTile(
              icon: icon,
              title: title,
              subtitle: subtitle,
              onTap: onTap,
              trailing: index == null
                  ? null
                  : ReorderableDragStartListener(
                      index: index!,
                      child: Icon(LucideIcons.gripVertical, size: 20, color: tokens.muted),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(63, 0, 14, 13),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  KChip(label: stateText, icon: stateIcon, tint: tone),
                  if (readOnly) KChip(label: l10n.sourcesReadOnlyBadge, icon: LucideIcons.lock),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
