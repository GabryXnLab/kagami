/// «Librerie condivise con me»: il foglio di chi riceve. Gli inviti
/// (accetta, rifiuta) e le librerie già accettate, con il loro termine e il
/// «Togli». Tutto qui è locale: la riga di chi condivide non si tocca
/// (docs/drive.md, «La libreria condivisa»).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/share_directory.dart';
import '../data/shared_library.dart';
import '../data/sources/source.dart';
import '../l10n.dart';
import '../providers_shares.dart';
import '../providers_social.dart';
import '../providers_sources.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// Chi ha condiviso, come lo dice una sorgente: il nome se c'è, sempre l'indirizzo.
String sharedOwnerOf(SourceConfig source) {
  final owner = '${source.params['owner'] ?? ''}';
  final name = source.params['ownerName'];
  return name is String && name.isNotEmpty ? '$name ($owner)' : owner;
}

/// Il nome breve per gli avvisi: quello di chi ha condiviso, o della cartella.
String sharedNameOf(SourceConfig source) {
  final name = source.params['ownerName'];
  if (name is String && name.isNotEmpty) return name;
  final owner = source.params['owner'];
  return owner is String && owner.isNotEmpty ? owner : source.label;
}

class DriveReceivedSheet extends ConsumerWidget {
  const DriveReceivedSheet({super.key});

  static Future<void> open(BuildContext context) => showKagamiSheet<void>(
        context,
        title: context.l10n.driveReceivedTitle,
        scrollable: true,
        builder: (context) => const DriveReceivedSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final invites = ref.watch(shareInvitesProvider);
    final sources = [
      for (final source in ref.watch(librarySourcesProvider).value?.sources ?? const <SourceConfig>[])
        if (source.kind == SourceKind.driveShared) source,
    ];
    final rows = ref.watch(incomingSharesProvider).value ?? const <DriveShare>[];
    final canWrite = ref.watch(socialMessagesProvider) != null;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (invites.isEmpty && sources.isEmpty)
            Text(l10n.driveReceivedEmpty, style: KagamiType.body(13, height: 1.45, color: context.tokens.muted)),
          for (final invite in invites) ...[
            _Invite(invite: invite),
            const SizedBox(height: 12),
          ],
          if (sources.isNotEmpty)
            KGroup(
              children: [
                for (final source in sources)
                  KTile(
                    icon: source.expiredAt(now) ? LucideIcons.clockAlert : LucideIcons.libraryBig,
                    title: source.label,
                    subtitle: '${switch (source.expiresAt) {
                      _ when source.expiredAt(now) => l10n.driveReceivedExpiredRow(sharedOwnerOf(source)),
                      null => l10n.driveReceivedNoLimit(sharedOwnerOf(source)),
                      final at => l10n.driveReceivedUntil(sharedOwnerOf(source), at.toLocal()),
                    }} · ${source.params['download'] == true ? l10n.driveReceivedCanDownload : l10n.driveReceivedStreamOnly}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A chi condivide si scrive sul social: serve il suo `from_uid`.
                        if (canWrite)
                          for (final row in rows)
                            if (row.fromUid != null && followsShare(source, row))
                              TextButton(
                                onPressed: () => _askMore(context, ref, row),
                                child: Text(l10n.messagesAskMore),
                              ),
                        IconButton(
                          tooltip: l10n.driveReceivedRemove,
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () => removeSharedSource(ref, source),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<void> _askMore(BuildContext context, WidgetRef ref, DriveShare share) async {
  final l10n = context.l10n;
  String text;
  try {
    await requestMoreTime(ref, share);
    text = l10n.messagesAskSent;
  } on Object {
    // Un limite, un blocco e una rete che manca dicono la stessa cosa.
    text = l10n.socialRefusedSnack;
  }
  if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

class _Invite extends ConsumerWidget {
  const _Invite({required this.invite});

  final DriveShare invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.libraryBig, size: 20, color: context.tokens.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.driveReceivedInvite(shareOwnerLabel(invite), invite.folderName),
                  style: KagamiType.body(13, height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => declineShare(ref, invite),
                child: Text(l10n.driveReceivedDecline),
              ),
              const SizedBox(width: 8),
              KButton(
                label: l10n.driveReceivedAccept,
                icon: LucideIcons.check,
                onPressed: () => ref.read(librarySourcesProvider.notifier).accept(invite),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
