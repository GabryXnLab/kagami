/// Il foglio che propone di togliere dal telefono i capitoli già letti.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/cleanup.dart';
import '../../data/drive.dart';
import '../../data/network.dart';
import '../../data/folder_sync.dart';
import '../../l10n.dart';
import '../../providers.dart';
import '../theme.dart';
import 'kit.dart';

typedef _Choice = ({bool folders, bool cache, bool remote, bool quiet});

/// Propone di liberare il telefono dai capitoli letti di una serie.
///
/// [asked] vuol dire che la proposta la fa l'app, aprendo la scheda: solo
/// allora c'è «Non chiedere più», perché chi apre il foglio da sé l'ha
/// voluto.
Future<void> offerCleanup(
  BuildContext context,
  WidgetRef ref,
  String seriesKey,
  ReadLeftovers leftovers, {
  bool asked = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final choice = await showKagamiSheet<_Choice>(
    context,
    title: l10n.cleanupTitle,
    builder: (context) => _CleanupForm(
      leftovers: leftovers,
      asked: asked,
      sync: ref.read(folderSyncSettingsProvider).value,
    ),
  );
  if (choice == null) return;
  if (choice.quiet) {
    await ref.read(cleanupQuietProvider.notifier).silence(seriesKey);
  }
  if (!choice.folders && !choice.cache && !choice.remote) return;
  final sync = ref.read(syncFilesProvider);
  // Un giro in corso potrebbe riscrivere proprio le cartelle che si stanno
  // togliendo, o annotarle dopo averle già confrontate.
  if ((choice.remote || (choice.folders && leftovers.synced)) &&
      await sync.busy()) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.cleanupSyncBusy)),
    );
    return;
  }
  DriveClient? writer;
  if (choice.remote) {
    writer = await _driveWriter(ref, messenger, l10n);
    if (writer == null) return;
  }
  try {
    await clearReadLeftovers(
      leftovers,
      series: seriesKey,
      folders: choice.folders,
      cache: choice.cache,
      remote: choice.remote,
      drive: ref.read(driveFilesProvider),
      writer: writer,
      sync: sync,
    );
  } on FileSystemException catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.cleanupNotAllDeleted(error.message))),
    );
  } on DriveException catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.cleanupDriveError(error.message))),
    );
  } finally {
    writer?.close();
  }
  // I capitoli tolti dal telefono si rileggono da Drive, o si mostrano come
  // non scaricati: l'elenco va rifatto.
  ref.invalidate(seriesChaptersProvider(seriesKey));
  ref.invalidate(readLeftoversProvider(seriesKey));
  final freed =
      (choice.folders ? leftovers.folderBytes : 0) +
      (choice.cache ? leftovers.cacheBytes : 0) +
      (choice.remote ? leftovers.remoteBytes : 0);
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.cleanupFreed(formatBytes(freed)))),
  );
}

/// Un client che può scrivere su Drive, chiedendo il permesso se non c'è
/// ancora. `null` se l'utente rinuncia o se manca la rete: senza, spostare
/// nel cestino non si può, e il resto della scelta aspetta con lui.
Future<DriveClient?> _driveWriter(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  if (!NetworkMonitor.instance.isOnline) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.cleanupNeedsNetwork)),
    );
    return null;
  }
  final auth = ref.read(driveAuthProvider);
  try {
    await auth.writeToken();
  } on DriveAuthRequired {
    try {
      await auth.authorize(write: true);
    } on DriveAuthRequired {
      return null;
    } on DriveException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return null;
    }
  }
  return DriveClient(auth.writeToken, network: NetworkMonitor.instance);
}

String formatBytes(int bytes) => bytes >= 1 << 30
    ? '${(bytes / (1 << 30)).toStringAsFixed(1)} GB'
    : bytes >= 1 << 20
    ? '${(bytes / (1 << 20)).round()} MB'
    : '${(bytes / 1024).ceil()} kB';

class _CleanupForm extends StatefulWidget {
  const _CleanupForm({
    required this.leftovers,
    required this.asked,
    required this.sync,
  });

  final ReadLeftovers leftovers;
  final bool asked;
  final SyncSettings? sync;

  @override
  State<_CleanupForm> createState() => _CleanupFormState();
}

class _CleanupFormState extends State<_CleanupForm> {
  late bool _folders = widget.leftovers.folders.isNotEmpty;
  late bool _cache = widget.leftovers.cached.isNotEmpty;

  /// Spento di partenza: togliere da Drive è l'unica scelta del foglio che
  /// non si rimedia riscaricando.
  bool _remote = false;
  bool _quiet = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final leftovers = widget.leftovers;
    final tokens = context.tokens;
    final count = leftovers.chapterCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            count == 0
                ? l10n.cleanupIntroDrive(leftovers.remote.length)
                : l10n.cleanupIntroPhone(count),
            style: KagamiType.body(13.5, height: 1.5, color: tokens.muted),
          ),
          const SizedBox(height: 14),
          KGroup(
            children: [
              if (leftovers.folders.isNotEmpty)
                KTile(
                  icon: LucideIcons.hardDrive,
                  title: l10n.cleanupPhoneChapters,
                  subtitle: l10n.cleanupApproxSize(
                    leftovers.folders.length,
                    formatBytes(leftovers.folderBytes),
                  ),
                  onTap: () => setState(() => _folders = !_folders),
                  trailing: Switch(
                    value: _folders,
                    onChanged: (value) => setState(() => _folders = value),
                  ),
                ),
              if (leftovers.cached.isNotEmpty)
                KTile(
                  icon: LucideIcons.cloud,
                  title: l10n.cleanupDriveCache,
                  subtitle: l10n.cleanupExactSize(
                    leftovers.cached.length,
                    formatBytes(leftovers.cacheBytes),
                  ),
                  onTap: () => setState(() => _cache = !_cache),
                  trailing: Switch(
                    value: _cache,
                    onChanged: (value) => setState(() => _cache = value),
                  ),
                ),
              if (leftovers.remote.isNotEmpty)
                KTile(
                  icon: LucideIcons.cloudOff,
                  title: l10n.cleanupDriveChapters,
                  subtitle: l10n.cleanupApproxSizeTrash(
                    leftovers.remote.length,
                    formatBytes(leftovers.remoteBytes),
                  ),
                  onTap: () => setState(() => _remote = !_remote),
                  trailing: Switch(
                    value: _remote,
                    onChanged: (value) => setState(() => _remote = value),
                  ),
                ),
              if (widget.asked)
                KTile(
                  icon: LucideIcons.bellOff,
                  title: l10n.cleanupQuiet,
                  onTap: () => setState(() => _quiet = !_quiet),
                  trailing: Switch(
                    value: _quiet,
                    onChanged: (value) => setState(() => _quiet = value),
                  ),
                ),
            ],
          ),
          if (_folders) ...[
            const SizedBox(height: 14),
            _Warning(
              !leftovers.onDrive
                  ? l10n.cleanupWarnNotOnDrive
                  : _remote
                  ? l10n.cleanupWarnGoneEverywhere
                  : l10n.cleanupWarnStaysOnDrive,
            ),
          ],
          if (_remote) ...[
            const SizedBox(height: 8),
            _Warning(l10n.cleanupWarnTrash),
          ],
          if ((_folders && leftovers.synced) || _remote) ...[
            const SizedBox(height: 8),
            _Warning(_syncWarning(l10n, widget.sync)),
          ],
          const SizedBox(height: 20),
          KButton(
            label: l10n.cleanupDelete,
            icon: LucideIcons.trash2,
            tone: tokens.danger,
            expand: true,
            onPressed: _folders || _cache || _remote
                ? () => Navigator.of(context).pop((
                    folders: _folders,
                    cache: _cache,
                    remote: _remote,
                    quiet: _quiet,
                  ))
                : null,
          ),
          const SizedBox(height: 10),
          KGhostButton(
            label: l10n.cleanupNotNow,
            expand: true,
            // «Non chiedere più» vale anche senza cancellare niente: è
            // proprio chi dice di no a volerlo.
            onPressed: () =>
                Navigator.of(context).pop((
                  folders: false,
                  cache: false,
                  remote: false,
                  quiet: _quiet,
                )),
          ),
        ],
      ),
    );
  }
}

/// Cosa succede su Drive. Con la sincronizzazione di Kagami lo si sa; con
/// FolderSync, che l'app non vede, si può solo avvisare.
String _syncWarning(AppLocalizations l10n, SyncSettings? sync) =>
    sync == null || !sync.enabled
    ? l10n.cleanupSyncWarnExternal
    : l10n.cleanupSyncWarnOwn;

class _Warning extends StatelessWidget {
  const _Warning(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final tint = context.tokens.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(LucideIcons.triangleAlert, size: 15, color: tint),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: KagamiType.body(
              12.5,
              height: 1.45,
              color: context.tokens.muted,
            ),
          ),
        ),
      ],
    );
  }
}
