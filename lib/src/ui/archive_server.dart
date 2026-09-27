/// Il server in «Scarica un manga»: collegarlo, vederne la coda, dirgli in
/// quale cartella di Drive scrivere.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/remote.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers.dart';
import 'sync_screen.dart' show clockOf;
import 'theme.dart';
import 'widgets/kit.dart';

String archiveSize(int bytes) {
  if (bytes < 1 << 20) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1 << 30) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
  return '${(bytes / (1 << 30)).toStringAsFixed(2)} GB';
}

String archiveWhen(DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final today = local.year == now.year && local.month == now.month && local.day == now.day;
  final clock = clockOf(local.hour * 60 + local.minute);
  return today ? 'oggi alle $clock' : '${local.day}/${local.month} alle $clock';
}

/// La serie che si sta scaricando, dal telefono o dal server: stessi campi,
/// stessa riga.
class ArchiveProgressRow extends StatelessWidget {
  const ArchiveProgressRow({required this.title, required this.status, required this.onCancel, super.key});

  final String title;
  final ArchiveStatus status;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.title.isEmpty ? title : status.title, style: KagamiType.body(14, weight: 600)),
                const SizedBox(height: 3),
                Text(
                  '${status.message}\n'
                  '${status.pagesDownloaded} tavole nuove · ${archiveSize(status.bytes)}'
                  '${status.pagesSkipped > 0 ? ' · ${status.pagesSkipped} già a posto' : ''}',
                  style: KagamiType.body(12.5, height: 1.4, color: muted),
                ),
                const SizedBox(height: 8),
                status.total == 0 ? const LinearProgressIndicator(minHeight: 5) : KProgress(value: status.fraction),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Togli dalla coda',
            icon: const Icon(LucideIcons.x, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// La sezione «Server»: com'è collegato, cosa sta facendo, cosa segue.
class ServerSection extends ConsumerWidget {
  const ServerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(remoteArchiveProvider);
    final link = view.link;
    final muted = context.tokens.muted;
    final children = <Widget>[
      const SizedBox(height: 30),
      KSection(
        'Server',
        trailing: view.queue.history.isEmpty
            ? null
            : TextButton(
                onPressed: () => _guard(context, ref.read(remoteArchiveProvider.notifier).clearHistory),
                child: const Text('Pulisci'),
              ),
      ),
    ];
    if (link == null) {
      children.addAll([
        Text(
          'Un computer sempre acceso — il tuo, con Kagami Server — può scaricare e '
          'caricare su Drive al posto del telefono, che può anche spegnersi.',
          style: KagamiType.body(12.5, height: 1.45, color: muted),
        ),
        const SizedBox(height: 12),
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.server,
              title: 'Collega un server',
              subtitle: 'Indirizzo e chiave API, o il link che stampa il server',
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => ServerLinkSheet.open(context),
            ),
          ],
        ),
      ]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    final notifier = ref.read(remoteArchiveProvider.notifier);
    final info = view.info;
    final queue = view.queue;
    final current = queue.current;
    final waiting = [for (final job in queue.jobs) if (job.id != current?.id) job];
    final appFolder = ref.watch(driveFolderProvider).value;
    final name = info?.name ?? link.url.host;
    final state = switch (view) {
      RemoteArchiveView(:final error?) => error,
      RemoteArchiveView(info: null) => 'Collegamento…',
      RemoteArchiveView(info: ServerInfo(driveAuthorized: false)) =>
        'Il server non ha ancora il permesso di Drive: «kagami-server drive login»',
      RemoteArchiveView(info: ServerInfo(folderId: null)) => 'Il server non sa ancora in quale cartella di Drive scrivere',
      RemoteArchiveView(:final info?) => 'Pronto · scrive in «${info.folderName ?? info.folderId}»',
    };
    // Con il server in errore, ciò che si sa di lui è vecchio: niente gesti
    // che partono da lì.
    final differs = view.error == null &&
        info != null &&
        info.driveAuthorized &&
        appFolder != null &&
        info.folderId != appFolder.id;
    children.add(KGroup(
      children: [
        KTile(
          icon: view.error == null ? LucideIcons.server : LucideIcons.serverOff,
          tint: view.error == null ? null : context.tokens.danger,
          title: name,
          subtitle: '${link.url.host}${link.url.hasPort ? ':${link.url.port}' : ''} · $state',
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => ServerLinkSheet.open(context, current: link),
        ),
        if (link.url.scheme == 'http' && !isPrivateAddress(link.url))
          KTile(
            icon: LucideIcons.triangleAlert,
            tint: context.tokens.danger,
            title: 'La chiave viaggia in chiaro',
            subtitle: 'Su un indirizzo pubblico serve HTTPS: Tailscale Funnel o un reverse proxy',
          ),
        if (differs)
          KTile(
            icon: LucideIcons.folderSync,
            title: 'Usa la cartella dell\'app',
            subtitle: info.folderId == null
                ? 'Il server scriverà in «${appFolder.name}», la cartella che leggi qui'
                : 'Il server scrive in «${info.folderName ?? info.folderId}», l\'app legge «${appFolder.name}»',
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _guard(context, () => notifier.useFolder(appFolder)),
          ),
        if (current != null)
          ArchiveProgressRow(
            title: current.title,
            status: queue.status,
            onCancel: () => _guard(context, () => notifier.cancel(current)),
          ),
        if (current == null && queue.jobs.isNotEmpty)
          KTile(
            icon: LucideIcons.clock,
            title: 'Coda in attesa',
            subtitle: queue.status.message.isEmpty ? 'Il server riparte da solo' : queue.status.message,
          ),
        for (final job in waiting)
          KTile(
            icon: job.automatic ? LucideIcons.refreshCw : LucideIcons.clock,
            title: job.title.isEmpty ? job.url : job.title,
            subtitle: job.automatic ? 'Capitoli nuovi · sul server' : 'In coda · sul server',
            trailing: IconButton(
              tooltip: 'Togli dalla coda',
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => _guard(context, () => notifier.cancel(job)),
            ),
          ),
        for (final outcome in queue.history.take(8))
          KTile(
            icon: outcome.ok ? LucideIcons.circleCheck : LucideIcons.triangleAlert,
            tint: outcome.ok ? null : context.tokens.danger,
            title: outcome.title,
            subtitle: '${archiveWhen(outcome.finishedAt)} · ${outcome.message}',
          ),
      ],
    ));
    if (info != null) {
      final minutes = info.checkMinutes;
      children.addAll([
        const SizedBox(height: 12),
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.refreshCw,
              title: 'Serie in corso sul server',
              subtitle: '${view.ongoing.isEmpty ? 'Nessuna, per ora' : '${view.ongoing.length} da seguire'}'
                  '${minutes == null ? ' · controllo spento' : ' · controllo alle ${clockOf(minutes)}'}. '
                  'Tocca per controllare adesso',
              onTap: view.error != null ? null : () => _checkNow(context, notifier),
            ),
            for (final series in view.ongoing)
              KTile(
                icon: series.problem == null ? LucideIcons.bookOpen : LucideIcons.triangleAlert,
                tint: series.problem == null ? null : context.tokens.danger,
                title: series.title,
                subtitle: series.problem ??
                    '${series.chapters} capitoli noti'
                        '${series.checkedAt == null ? '' : ' · controllata ${archiveWhen(series.checkedAt!)}'}',
                trailing: IconButton(
                  tooltip: 'Smetti di seguirla',
                  icon: const Icon(LucideIcons.bellOff, size: 18),
                  onPressed: () => _guard(context, () => notifier.forget(series)),
                ),
              ),
          ],
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  static Future<void> _checkNow(BuildContext context, RemoteArchiveController notifier) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await notifier.check();
      messenger.showSnackBar(const SnackBar(
        content: Text('Il server sta controllando: i capitoli nuovi compaiono nella sua coda.'),
      ));
    } on ServerException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// Un gesto verso il server: se non va, lo dice.
Future<void> _guard(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } on ServerException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}

/// Collegare un server, cambiarlo o scollegarlo. Si salva solo dopo che il
/// server ha risposto con quella chiave.
class ServerLinkSheet extends ConsumerStatefulWidget {
  const ServerLinkSheet({this.current, super.key});

  final ServerLink? current;

  static Future<void> open(BuildContext context, {ServerLink? current}) => showKagamiSheet<void>(
        context,
        title: current == null ? 'Collega un server' : 'Server',
        scrollable: true,
        builder: (context) => ServerLinkSheet(current: current),
      );

  @override
  ConsumerState<ServerLinkSheet> createState() => _ServerLinkSheetState();
}

class _ServerLinkSheetState extends ConsumerState<ServerLinkSheet> {
  late final TextEditingController _address = TextEditingController(text: widget.current?.url.toString() ?? '');
  late final TextEditingController _key = TextEditingController(text: widget.current?.key ?? '');
  bool _busy = false;
  bool _showKey = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _key.dispose();
    super.dispose();
  }

  /// Un link di abbinamento incollato nel campo dell'indirizzo riempie tutti
  /// e due i campi.
  void _onAddress(String text) {
    final pairing = ServerLink.parsePairing(text);
    if (pairing == null) return;
    _address.text = '${pairing.url}';
    _key.text = pairing.key;
    setState(() {});
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null || text.isEmpty) return;
    final pairing = ServerLink.parsePairing(text);
    if (pairing != null) {
      _onAddress(text);
    } else if (text.startsWith('kagami_')) {
      _key.text = text;
    } else {
      _address.text = text;
    }
    setState(() {});
  }

  Future<void> _connect() async {
    final url = normalizeServerUrl(_address.text);
    final key = _key.text.trim();
    if (url == null) {
      setState(() => _error = 'Scrivi l\'indirizzo del server, per esempio http://192.168.1.20:8080.');
      return;
    }
    if (key.isEmpty) {
      setState(() => _error = 'Manca la chiave API: la stampa il server al primo avvio, o «kagami-server key create».');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final link = ServerLink(url, key);
    final client = ServerClient(link);
    try {
      final info = await client.info();
      if (info.api != 1) {
        throw ServerException('Il server parla l\'API ${info.api}, questa versione dell\'app la 1: aggiorna uno dei due.');
      }
      await ref.read(serverLinkProvider.notifier).choose(link);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Collegato a «${info.name}».')));
    } on ServerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    await ref.read(serverLinkProvider.notifier).choose(null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    final url = normalizeServerUrl(_address.text);
    final exposed = url != null && url.scheme == 'http' && !isPrivateAddress(url);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kagami Server gira su un tuo computer e scarica al posto del telefono. '
            'Incolla il link che stampa «kagami-server key create --url …», oppure '
            'scrivi indirizzo e chiave.',
            style: KagamiType.body(13, height: 1.45, color: muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _address,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (text) {
              _onAddress(text);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'http://192.168.1.20:8080',
              prefixIcon: const Icon(LucideIcons.server, size: 18),
              suffixIcon: IconButton(
                tooltip: 'Incolla',
                icon: const Icon(LucideIcons.clipboardPaste, size: 18),
                onPressed: _busy ? null : _paste,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            enabled: !_busy,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'Chiave API (kagami_…)',
              prefixIcon: const Icon(LucideIcons.keyRound, size: 18),
              suffixIcon: IconButton(
                tooltip: _showKey ? 'Nascondi' : 'Mostra',
                icon: Icon(_showKey ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            exposed
                ? 'Attenzione: in chiaro su un indirizzo pubblico la chiave si legge per strada. '
                    'Usa HTTPS (Tailscale Funnel, un reverse proxy) o Tailscale.'
                : 'Indirizzo e chiave viaggiano col backup e con l\'account, come la cartella di Drive.',
            style: KagamiType.body(12.5, height: 1.45, color: exposed ? context.tokens.danger : muted),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
          ],
          const SizedBox(height: 18),
          KButton(
            label: _busy ? 'Verifica…' : 'Verifica e collega',
            icon: LucideIcons.plugZap,
            expand: true,
            onPressed: _busy ? null : _connect,
          ),
          if (widget.current != null) ...[
            const SizedBox(height: 10),
            KGhostButton(
              label: 'Scollega',
              icon: LucideIcons.unplug,
              expand: true,
              onPressed: _busy ? null : _unlink,
            ),
          ],
        ],
      ),
    );
  }
}
