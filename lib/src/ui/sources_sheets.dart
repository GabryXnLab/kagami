/// I fogli della schermata Sorgenti: aggiungere una sorgente WebDAV o SMB con la
/// prova di connessione, e il dettaglio di una sorgente (rinomina, password,
/// rimozione).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/remote.dart' show isPrivateAddress;
import 'package:kagami_archive/transport.dart' show StorageTransport;
import 'package:kagami_archive/webdav.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/sources/smb_transport.dart';
import '../data/sources/source.dart';
import '../data/sources/webdav_source.dart';
import '../l10n.dart';
import '../providers.dart';
import '../providers_shares.dart';
import '../providers_sources.dart';
import 'drive_received_sheet.dart' show sharedNameOf;
import 'theme.dart';
import 'widgets/kit.dart';

InputDecoration _field(IconData icon, String hint, {Widget? suffix}) => InputDecoration(
      prefixIcon: Icon(icon, size: 18),
      hintText: hint,
      suffixIcon: suffix,
    );

class AddSourceSheet extends ConsumerStatefulWidget {
  const AddSourceSheet({super.key});

  static Future<void> open(BuildContext context) => showKagamiSheet<void>(
        context,
        title: context.l10n.sourcesAdd,
        scrollable: true,
        builder: (_) => const AddSourceSheet(),
      );

  @override
  ConsumerState<AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends ConsumerState<AddSourceSheet> {
  SourceKind _kind = SourceKind.webdav;
  bool _seal = false;
  final _url = TextEditingController();
  final _host = TextEditingController();
  final _share = TextEditingController();
  final _domain = TextEditingController();
  final _root = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _obscure = true;
  bool _probing = false;
  WebDavProbe? _result;
  String? _addressError;

  @override
  void dispose() {
    for (final controller in [_url, _host, _share, _domain, _root, _user, _password, _name]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {
        _result = null;
        _addressError = null;
      });

  bool get _smb => _kind == SourceKind.smb;

  /// Host e condivisione di una sorgente SMB, o il motivo per cui non vanno.
  (String, String) _smbTarget() => (smbHost(_host.text, seal: _seal), smbShare(_share.text));

  Future<void> _probe() async {
    final StorageTransport transport;
    try {
      if (_smb) {
        final (host, share) = _smbTarget();
        final user = _user.text.trim();
        transport = SmbTransport(() => PoolSmbSession.connect(
              host: host,
              share: share,
              user: user.isEmpty ? null : user,
              password: user.isEmpty ? null : _password.text,
              domain: _domain.text.trim().isEmpty ? null : _domain.text.trim(),
              seal: _seal,
              timeout: const Duration(seconds: 10),
            ));
      } else {
        transport = WebDavTransport(webDavAddress(_url.text), user: _user.text.trim(), password: _password.text);
      }
    } on FormatException catch (error) {
      setState(() => _addressError = error.message);
      return;
    }
    setState(() {
      _probing = true;
      _result = null;
    });
    try {
      final result = await probeWebDav(transport, _root.text);
      if (mounted) setState(() => _result = result);
    } finally {
      transport.close();
      if (mounted) setState(() => _probing = false);
    }
  }

  Future<void> _add() async {
    final root = _root.text.split('/').where((s) => s.isNotEmpty).join('/');
    final id = SourceConfig.newId();
    final name = _name.text.trim();
    // Il segreto prima della configurazione: una sorgente che compare senza
    // la sua password sarebbe «da ricollegare» per un attimo, per niente.
    if (_password.text.isNotEmpty) {
      await ref.read(sourceSecretsProvider).write(id, _password.text);
    }
    final SourceConfig config;
    if (_smb) {
      final (host, share) = _smbTarget();
      config = SourceConfig(
        id: id,
        kind: SourceKind.smb,
        label: name.isNotEmpty ? name : (root.isEmpty ? share : root.split('/').last),
        params: {
          'host': host,
          'share': share,
          'folder': root,
          'user': _user.text.trim(),
          'domain': _domain.text.trim(),
          'seal': _seal,
        },
      );
    } else {
      final address = webDavAddress(_url.text);
      config = SourceConfig(
        id: id,
        kind: SourceKind.webdav,
        label: name.isNotEmpty ? name : (root.isEmpty ? address.host : root.split('/').last),
        params: {'url': address.toString(), 'user': _user.text.trim(), 'root': root},
      );
    }
    await ref.read(librarySourcesProvider.notifier).add(config);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final uri = Uri.tryParse(_url.text.trim());
    final http = !_smb && uri != null && uri.scheme == 'http' && uri.host.isNotEmpty;
    final privateHttp = http && isPrivateAddress(uri);
    // SMB: l'host in chiaro verso Internet è un errore, in casa un avviso.
    String? smbError;
    if (_smb && _host.text.trim().isNotEmpty) {
      try {
        smbHost(_host.text, seal: _seal);
      } on FormatException catch (error) {
        smbError = error.message;
      }
    }
    final plainSmb = _smb && !_seal && _host.text.trim().isNotEmpty && smbError == null;
    final problem = _addressError ?? smbError;
    final hasWarning = http || problem != null || plainSmb;
    final danger = problem != null || (http && !privateHttp);
    final warning = problem ??
        (plainSmb
            ? l10n.sourcesSmbPlainWarning
            : (privateHttp ? l10n.sourcesHttpPrivateWarning : l10n.sourcesHttpPublicWarning));
    final result = _result;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            KChip(
              label: l10n.sourcesKindWebdav,
              icon: LucideIcons.server,
              active: !_smb,
              onTap: () => setState(() {
                _kind = SourceKind.webdav;
                _changed();
              }),
            ),
            const SizedBox(width: 8),
            KChip(
              label: l10n.sourcesKindSmb,
              icon: LucideIcons.hardDrive,
              active: _smb,
              onTap: () => setState(() {
                _kind = SourceKind.smb;
                _changed();
              }),
            ),
          ]),
          const SizedBox(height: 16),
          if (_smb) ...[
            TextField(
              controller: _host,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _changed(),
              decoration: _field(LucideIcons.globe, l10n.sourcesSmbHostHint),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _share,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _changed(),
              decoration: _field(LucideIcons.hardDrive, l10n.sourcesSmbShareHint),
            ),
          ] else
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _changed(),
            decoration: _field(
              LucideIcons.globe,
              'https://nas.example.com/webdav',
              suffix: IconButton(
                icon: const Icon(LucideIcons.clipboardPaste, size: 18),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text == null) return;
                  _url.text = data!.text!.trim();
                  _changed();
                },
              ),
            ),
          ),
          if (hasWarning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  danger ? LucideIcons.triangleAlert : LucideIcons.shieldAlert,
                  size: 16,
                  color: danger ? tokens.danger : tokens.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: KagamiType.body(12.5, height: 1.45, color: danger ? tokens.danger : tokens.warning),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _root,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _changed(),
            decoration: _field(LucideIcons.folder, l10n.sourcesWebdavFolderHint),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _user,
            autocorrect: false,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _changed(),
            decoration: _field(LucideIcons.userRound, _smb ? l10n.sourcesSmbUserHint : l10n.sourcesWebdavUserHint),
          ),
          const SizedBox(height: 10),
          if (_smb) ...[
            TextField(
              controller: _domain,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _changed(),
              decoration: _field(LucideIcons.building2, l10n.sourcesSmbDomainHint),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _changed(),
            decoration: _field(
              LucideIcons.keyRound,
              l10n.sourcesWebdavPasswordHint,
              suffix: IconButton(
                icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_smb) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(LucideIcons.lock, size: 18),
              title: Text(l10n.sourcesSmbSealLabel),
              subtitle: Text(l10n.sourcesSmbSealNote, style: KagamiType.body(12, height: 1.4, color: tokens.muted)),
              value: _seal,
              onChanged: (value) => setState(() {
                _seal = value;
                _changed();
              }),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.done,
            decoration: _field(LucideIcons.tag, l10n.sourcesWebdavNameHint),
          ),
          const SizedBox(height: 16),
          KGhostButton(
            label: _probing ? l10n.sourcesProbing : l10n.sourcesProbeButton,
            icon: LucideIcons.plugZap,
            expand: true,
            onPressed: _probing || _url.text.trim().isEmpty ? null : () => unawaited(_probe()),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            _ProbeResult(result),
          ],
          const SizedBox(height: 12),
          KButton(
            label: l10n.sourcesAdd,
            icon: LucideIcons.check,
            expand: true,
            onPressed: result is WebDavProbeOk ? () => unawaited(_add()) : null,
          ),
        ],
      ),
    );
  }
}

class _ProbeResult extends StatelessWidget {
  const _ProbeResult(this.result);

  final WebDavProbe result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final (icon, text, tone) = switch (result) {
      WebDavProbeOk(:final series) => (LucideIcons.circleCheck, l10n.sourcesProbeSuccess(series), tokens.success),
      WebDavProbeAuth() => (LucideIcons.keyRound, l10n.sourcesProbeAuthFailed, tokens.danger),
      WebDavProbeUnreachable() => (LucideIcons.wifiOff, l10n.sourcesProbeUnreachable, tokens.danger),
      WebDavProbeNoLibrary() => (LucideIcons.folderX, l10n.sourcesProbeNoLibrary, tokens.warning),
    };
    return KCard(
      color: context.colors.surfaceContainerHigh,
      radius: 16,
      padding: const EdgeInsets.all(13),
      child: Row(children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: KagamiType.body(13, color: tone))),
      ]),
    );
  }
}

/// Il dettaglio di una sorgente aggiunta. Le tre di sempre non passano di
/// qui: hanno le loro impostazioni.
class SourceDetailSheet extends ConsumerStatefulWidget {
  const SourceDetailSheet(this.config, this.state, {super.key});

  final SourceConfig config;
  final SourceState? state;

  static Future<void> open(BuildContext context, SourceConfig config, SourceState? state) =>
      showKagamiSheet<void>(
        context,
        title: config.kind == SourceKind.driveShared ? sharedNameOf(config) : config.label,
        scrollable: true,
        builder: (_) => SourceDetailSheet(config, state),
      );

  @override
  ConsumerState<SourceDetailSheet> createState() => _SourceDetailSheetState();
}

class _SourceDetailSheetState extends ConsumerState<SourceDetailSheet> {
  late final _name = TextEditingController(text: widget.config.label);
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _name.text.trim();
    if (label.isNotEmpty && label != widget.config.label) {
      await ref.read(librarySourcesProvider.notifier).replace(widget.config.copyWith(label: label));
    }
    if (_password.text.isNotEmpty) {
      await ref.read(sourceSecretsProvider).write(widget.config.id, _password.text);
      // La sorgente ha già letto il suo segreto (o la sua assenza): si riaccende.
      ref.invalidate(storageSourcesProvider);
      reloadLibrary(ref);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final config = widget.config;
    final name = config.kind == SourceKind.driveShared ? sharedNameOf(config) : config.label;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.sourcesRemoveConfirmTitle(name)),
        content: Text(l10n.sourcesRemoveConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.archiveCancel)),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.sourcesRemove)),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    if (config.kind == SourceKind.driveShared) {
      await removeSharedSource(ref, config);
    } else {
      await ref.read(librarySourcesProvider.notifier).remove(config.id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final webdav = widget.config.kind == SourceKind.webdav || widget.config.kind == SourceKind.smb;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (webdav) ...[
            TextField(controller: _name, decoration: _field(LucideIcons.tag, l10n.sourcesWebdavNameHint)),
            const SizedBox(height: 10),
            // Campo sempre vuoto: la password non si rilegge.
            TextField(
              controller: _password,
              obscureText: true,
              autocorrect: false,
              decoration: _field(LucideIcons.keyRound, l10n.sourcesPasswordRewriteHint),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
              child: Text(l10n.sourcesSecretNote, style: KagamiType.body(12, height: 1.4, color: tokens.muted)),
            ),
            KButton(label: l10n.sourcesSave, icon: LucideIcons.check, expand: true, onPressed: () => unawaited(_save())),
            const SizedBox(height: 14),
          ],
          KGroup(
            children: [
              KTile(
                icon: LucideIcons.trash2,
                title: webdav ? l10n.sourcesRemove : l10n.sourcesDismiss,
                subtitle: webdav ? l10n.sourcesRemoveSubtitle : null,
                tint: tokens.danger,
                onTap: () => unawaited(_remove()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
