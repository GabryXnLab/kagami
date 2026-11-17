/// «Chi può leggere la mia libreria»: il foglio di chi lascia leggere la
/// cartella di Drive a un altro account, con la durata e il rinnovo. Dice il
/// vero (docs/drive.md, «La libreria condivisa»): le righe del backend e, sotto,
/// ciò che Drive aggiunge; non leggere non è «nessuno».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/drive.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/drive_access.dart';
import '../l10n.dart';
import '../providers.dart';
import '../providers_shares.dart';
import 'archive_server.dart' show RenewChoice;
import 'theme.dart';
import 'widgets/kit.dart';

class DriveShareSheet extends ConsumerStatefulWidget {
  const DriveShareSheet({super.key});

  static Future<void> open(BuildContext context) => showKagamiSheet<void>(
        context,
        title: context.l10n.driveShareTitle,
        scrollable: true,
        builder: (context) => const DriveShareSheet(),
      );

  @override
  ConsumerState<DriveShareSheet> createState() => _DriveShareSheetState();
}

class _DriveShareSheetState extends ConsumerState<DriveShareSheet> {
  final TextEditingController _email = TextEditingController();
  bool _busy = false;
  bool _authorized = false;
  String? _error;
  AccessDuration _duration = AccessDuration.proposed;
  bool _download = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Lo scope completo si chiede una volta, al primo gesto che scrive, dopo
  /// aver detto che l'altra persona vedrà tutti i file della cartella.
  /// Senza, niente succede.
  Future<bool> _ensureWrite() async {
    if (_authorized) return true;
    final l10n = context.l10n;
    final folder = ref.read(driveFolderProvider).value?.name ?? '';
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.driveShareConsentTitle),
        content: Text(l10n.driveShareConsentBody(folder)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.serverCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.driveShareConsentContinue)),
        ],
      ),
    );
    if (go != true || !mounted) return false;
    try {
      await ref.read(driveAuthProvider).authorize(write: true);
    } on DriveAuthRequired {
      return false;
    } on DriveException catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
      return false;
    }
    _authorized = true;
    return true;
  }

  String _errorText(Object error) {
    final l10n = context.l10n;
    return switch (error) {
      DriveOffline() => l10n.driveShareOffline,
      ShareUnavailable() => l10n.driveShareUnavailable,
      ShareDownloadUnavailable() => l10n.driveShareDownloadUnavailable,
      ArgumentError() => l10n.driveShareSelf,
      DriveException(:final message) => l10n.driveShareFailed(message),
      _ => l10n.driveShareFailed('$error'),
    };
  }

  /// Una scrittura: prima il consenso, poi l'azione. Un errore si dice e lo
  /// stato di prima resta; a fine giro si rilegge, perché una scrittura a metà
  /// ha cambiato qualcosa di vero.
  Future<void> _write(Future<void> Function(DriveAccess access) action) async {
    final access = ref.read(driveAccessProvider);
    if (access == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _ensureWrite()) return;
      await action(access);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      ref.invalidate(driveShareReadersProvider);
      unawaited(ref.read(driveShareServerSyncProvider)());
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = context.l10n.serverUserEmailInvalid);
      return;
    }
    final folder = ref.read(driveFolderProvider).value;
    if (folder == null) return;
    final duration = _duration.span;
    final download = _download;
    final added = context.l10n.driveShareAdded(email);
    final messenger = ScaffoldMessenger.of(context);
    var done = false;
    await _write((access) async {
      await access.share(folderId: folder.id, folderName: folder.name, email: email,
          duration: duration, download: download);
      done = true;
    });
    if (!done || !mounted) return;
    _email.clear();
    messenger.showSnackBar(SnackBar(content: Text(added)));
  }

  Future<void> _renew(DriveShare share) async {
    final duration = await showKagamiSheet<AccessDuration>(
      context,
      title: context.l10n.serverUserRenewTitle(share.to),
      builder: (context) => const RenewChoice(),
    );
    if (duration == null || !mounted) return;
    await _write((access) => access.renew(share, duration.span));
  }

  Future<void> _setDownload(DriveShare share) => _write((access) => access.setDownload(share, !share.download));

  Future<bool> _confirmRemove(String who) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.serverRemoveTitle(who)),
          content: Text(context.l10n.driveShareRemoveBody),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.serverCancel)),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.l10n.serverRemove)),
          ],
        ),
      ) ==
      true;

  Future<void> _revoke(DriveShare share) async {
    if (!await _confirmRemove(share.to) || !mounted) return;
    await _write((access) => access.revoke(share));
  }

  Future<void> _revokePermission(DrivePermission permission, String folderId) async {
    if (!await _confirmRemove(permission.email ?? permission.id) || !mounted) return;
    await _write((access) => access.revokePermission(folderId, permission.id));
  }

  String _subtitle(DriveShare share, String currentFolder) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final at = share.expiresAt;
    final term = share.expiredAt(now)
        ? l10n.serverUserExpired
        : at == null
            ? l10n.accessDurationNever
            : l10n.serverUserExpires(at.toLocal());
    final permission = share.download ? l10n.driveShareRowDownload : l10n.driveShareRowStreaming;
    final line = '$term · $permission';
    return share.folderId == currentFolder ? line : '$line · ${l10n.driveShareInFolder(share.folderName)}';
  }

  Widget _note(IconData icon, String text, {bool warning = false, Widget? action}) {
    final color = warning ? context.tokens.danger : context.tokens.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: KagamiType.body(13, height: 1.45, color: color))),
          ?action,
        ],
      ),
    );
  }

  /// I dati personali rimasti nella cartella vanno nel cestino di Drive, con
  /// lo stesso consenso di una condivisione.
  Future<void> _clearPersonal(String folderId) => _write((access) => access.clearPersonalData(folderId));

  Widget _readers(ShareReaders readers, String folderId) {
    final l10n = context.l10n;
    final tiles = <Widget>[
      for (final share in readers.shares)
        KTile(
          icon: LucideIcons.user,
          title: share.to,
          subtitle: _subtitle(share, folderId),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: share.download ? l10n.driveShareDownloadDeny : l10n.driveShareDownloadAllow,
                icon: Icon(share.download ? LucideIcons.download : LucideIcons.eye, size: 18),
                onPressed: _busy ? null : () => _setDownload(share),
              ),
              TextButton(
                onPressed: _busy ? null : () => _renew(share),
                child: Text(l10n.serverUserRenew),
              ),
              IconButton(
                tooltip: l10n.serverRemove,
                icon: const Icon(LucideIcons.userMinus, size: 18),
                onPressed: _busy ? null : () => _revoke(share),
              ),
            ],
          ),
        ),
      for (final permission in readers.withoutRow)
        KTile(
          icon: LucideIcons.userRoundSearch,
          title: permission.email ?? permission.id,
          subtitle: l10n.driveShareFromDrive,
          trailing: IconButton(
            tooltip: l10n.serverRemove,
            icon: const Icon(LucideIcons.userMinus, size: 18),
            onPressed: _busy ? null : () => _revokePermission(permission, folderId),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!readers.driveAnswered) _note(LucideIcons.triangleAlert, l10n.driveShareDriveSilent, warning: true),
        if (readers.linkAccess) _note(LucideIcons.link, l10n.driveShareLinkAccess, warning: true),
        if (readers.personal == null)
          _note(LucideIcons.triangleAlert, l10n.driveSharePersonalUnchecked, warning: true)
        else if (readers.personal!.isNotEmpty)
          _note(
            LucideIcons.fileExclamationPoint,
            l10n.driveSharePersonalFound,
            warning: true,
            action: TextButton(
              onPressed: _busy ? null : () => _clearPersonal(folderId),
              child: Text(l10n.driveSharePersonalRemove),
            ),
          ),
        if (tiles.isNotEmpty)
          KGroup(children: tiles)
        else if (readers.driveAnswered)
          Text(l10n.driveShareNobody, style: KagamiType.body(13, color: context.tokens.muted)),
      ],
    );
  }

  Widget _addForm(AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _add(),
            decoration: const InputDecoration(
              hintText: 'nome@gmail.com',
              prefixIcon: Icon(LucideIcons.atSign, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          AccessDurationPicker(value: _duration, onChanged: (value) => setState(() => _duration = value)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.driveShareDownloadOption),
            subtitle: Text(
              l10n.driveShareDownloadNote,
              style: KagamiType.body(12, height: 1.45, color: context.tokens.muted),
            ),
            value: _download,
            onChanged: _busy ? null : (value) => setState(() => _download = value),
          ),
          const SizedBox(height: 12),
          KButton(
            label: l10n.driveShareAdd,
            icon: LucideIcons.userPlus,
            expand: true,
            onPressed: _busy ? null : _add,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final readers = ref.watch(driveShareReadersProvider);
    final folder = ref.watch(driveFolderProvider).value;
    final unavailable = readers.error is ShareUnavailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unavailable)
            Text(l10n.driveShareUnavailable, style: KagamiType.body(13, height: 1.45, color: context.tokens.muted))
          else ...[
            Text(
              l10n.driveShareIntro(folder?.name ?? ''),
              style: KagamiType.body(13, height: 1.45, color: context.tokens.muted),
            ),
            const SizedBox(height: 14),
            _addForm(l10n),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
            ],
            const SizedBox(height: 16),
            if (folder != null)
              switch (readers) {
                AsyncData(:final value?) => _readers(value, folder.id),
                AsyncError(:final error) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _note(LucideIcons.triangleAlert, l10n.driveShareLoadFailed('$error'), warning: true),
                      KButton(
                        label: l10n.driveRetry,
                        icon: LucideIcons.refreshCw,
                        expand: true,
                        onPressed: () => ref.invalidate(driveShareReadersProvider),
                      ),
                    ],
                  ),
                AsyncData() => const SizedBox.shrink(),
                _ => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
              },
          ],
        ],
      ),
    );
  }
}
