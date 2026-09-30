/// Il server in «Scarica un manga»: crearlo, collegarlo, vederne la coda,
/// dirgli in quale cartella di Drive scrivere, e per il proprietario chi può
/// usarlo.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/remote.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cloud.dart';
import '../data/drive.dart';
import '../data/server_access.dart';
import '../providers.dart';
import 'drive_ui.dart';
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

/// Collega questo account al server a [url]: il server dice se lo conosce,
/// e se non ha ancora il suo Drive glielo si dà. Si salva solo se tutto è
/// andato; `null` se l'utente ha rinunciato a un passo.
Future<ServerInfo?> linkServer(BuildContext context, WidgetRef ref, Uri url) async {
  final email = await _signedIn(ref);
  if (email == null || !context.mounted) return null;
  final access = ref.read(serverAccessProvider);
  final link = ServerLink(url);
  final client = ServerClient(link, access.idToken);
  try {
    var info = await client.info();
    if (!info.ready) {
      if (!context.mounted || !await _giveDrive(context, ref, client, email)) return null;
      info = await client.info();
    }
    await ref.read(serverLinkProvider.notifier).choose(link);
    try {
      await access.withdraw(email, url);
    } on Exception {
      // Un invito rimasto non fa danni: il server è già collegato, e da qui
      // non si ripropone.
    }
    return info;
  } finally {
    client.close();
  }
}

Future<String?> _signedIn(WidgetRef ref) async {
  if (!ref.read(cloudAccountProvider).signedIn) await ref.read(cloudAccountProvider.notifier).signIn();
  return ref.read(cloudAccountProvider).account?.email;
}

/// Dà al server il permesso sul Drive di [email] e la cartella della
/// libreria che legge l'app; se l'app non ne ha una, la si sceglie prima.
Future<bool> _giveDrive(BuildContext context, WidgetRef ref, ServerClient client, String email) async {
  var folder = ref.read(driveFolderProvider).value;
  if (folder == null) {
    await connectDrive(context, ref);
    folder = ref.read(driveFolderProvider).value;
    if (folder == null) return false;
  }
  final grant = await ref.read(serverAccessProvider).grantDrive(email);
  if (grant == null) return false;
  await client.grantDrive(grant.refreshToken, folder.id);
  return true;
}

/// La sezione «Server»: accesso, inviti, com'è collegato, cosa sta facendo,
/// cosa segue.
class ServerSection extends ConsumerWidget {
  const ServerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(remoteArchiveProvider);
    final link = view.link;
    final muted = context.tokens.muted;
    final account = ref.watch(cloudAccountProvider).account;
    final invites = [
      for (final invite in ref.watch(serverInvitesProvider).value ?? const <ServerInvite>[])
        if (invite.url != link?.url.toString()) invite,
    ];
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
    if (!cloudAvailable) {
      children.add(Text(
        'Il server riconosce chi lo usa dall\'account Google, che in questa build dell\'app non c\'è.',
        style: KagamiType.body(12.5, height: 1.45, color: muted),
      ));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    if (account == null) {
      children.addAll([
        Text(
          'Un computer sempre acceso può scaricare e caricare sul tuo Drive al posto del telefono, '
          'che intanto può anche spegnersi. Il server ti riconosce dal tuo account Google.',
          style: KagamiType.body(12.5, height: 1.45, color: muted),
        ),
        const SizedBox(height: 12),
        KGroup(children: [
          KTile(
            icon: LucideIcons.logIn,
            title: 'Accedi con Google',
            subtitle: 'Per creare il tuo server o usare quello di qualcun altro',
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => ref.read(cloudAccountProvider.notifier).signIn(),
          ),
        ]),
      ]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    if (invites.isNotEmpty) {
      children.addAll([
        KGroup(children: [
          for (final invite in invites)
            KTile(
              icon: LucideIcons.userPlus,
              title: '${invite.sender} ti ha dato accesso a «${invite.serverName}»',
              subtitle: 'Scarica sul tuo Drive, anche a telefono spento. Tocca per collegarlo',
              trailing: IconButton(
                tooltip: 'Ignora',
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () => _ignore(context, ref, invite),
              ),
              onTap: () => ServerLinkSheet.open(context, address: Uri.parse(invite.url), from: invite),
            ),
        ]),
        const SizedBox(height: 12),
      ]);
    }
    if (link == null) {
      children.addAll([
        Text(
          'Un computer sempre acceso — il tuo o quello di chi ti ha dato accesso — può scaricare '
          'e caricare sul tuo Drive al posto del telefono, che intanto può anche spegnersi.',
          style: KagamiType.body(12.5, height: 1.45, color: muted),
        ),
        const SizedBox(height: 12),
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.serverCog,
              title: 'Crea il tuo server',
              subtitle: 'Un comando da incollare su un computer con Docker: niente da configurare',
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => ServerSetupSheet.open(context),
            ),
            KTile(
              icon: LucideIcons.server,
              title: 'Collega un server',
              subtitle: 'Il tuo, già acceso, o quello di chi ti ha aggiunto',
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
      RemoteArchiveView(info: ServerInfo(driveAuthorized: false)) => 'Non ha ancora il permesso del tuo Drive',
      RemoteArchiveView(info: ServerInfo(folderId: null)) => 'Non sa ancora in quale cartella del tuo Drive scrivere',
      RemoteArchiveView(:final info?) => 'Pronto · scrive in «${info.folderName ?? info.folderId}» sul tuo Drive',
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
          subtitle: '${link.url.host}${link.url.hasPort ? ':${link.url.port}' : ''}'
              '${info == null || info.isOwner ? '' : ' · di ${info.owner}'} · $state',
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => ServerLinkSheet.open(context, address: link.url, linked: true),
        ),
        if (link.url.scheme == 'http' && !isPrivateAddress(link.url))
          KTile(
            icon: LucideIcons.triangleAlert,
            tint: context.tokens.danger,
            title: 'La connessione è in chiaro',
            subtitle: 'Il token del tuo account si legge per strada: serve HTTPS (Tailscale Funnel, un reverse proxy)',
          ),
        if (view.error == null && info != null && !info.ready)
          KTile(
            icon: LucideIcons.hardDriveUpload,
            title: 'Dai il tuo Drive al server',
            subtitle: 'Scaricherà nella cartella che legge l\'app, anche a telefono spento',
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _grant(context, ref, link),
          ),
        if (differs)
          KTile(
            icon: LucideIcons.folderSync,
            title: 'Usa la cartella dell\'app',
            subtitle: 'Il server scrive in «${info.folderName ?? info.folderId}», l\'app legge «${appFolder.name}»',
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _guard(context, () => notifier.useFolder(appFolder)),
          ),
        if (info != null && info.isOwner && view.error == null)
          KTile(
            icon: LucideIcons.users,
            title: 'Chi può usarlo',
            subtitle: view.users.length <= 1
                ? 'Solo tu. Aggiungi l\'account Google di chi vuoi'
                : '${view.users.length} account, te compreso',
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => ServerUsersSheet.open(context),
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

  static Future<void> _ignore(BuildContext context, WidgetRef ref, ServerInvite invite) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(serverAccessProvider).withdraw(invite.to, Uri.parse(invite.url));
    } on FirebaseException {
      messenger.showSnackBar(const SnackBar(content: Text('Non sono riuscito a togliere l\'invito: riprova.')));
    }
  }

  static Future<void> _grant(BuildContext context, WidgetRef ref, ServerLink link) async {
    final email = ref.read(cloudAccountProvider).account?.email;
    if (email == null) return;
    final client = ServerClient(link, ref.read(serverAccessProvider).idToken);
    await _guard(context, () async {
      if (await _giveDrive(context, ref, client, email)) {
        await ref.read(remoteArchiveProvider.notifier).refresh(full: true);
      }
    });
    client.close();
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
  } on DriveException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}

/// Il campo dell'indirizzo del server, uguale in tutti i fogli.
class _AddressField extends StatelessWidget {
  const _AddressField({required this.controller, required this.enabled, required this.onChanged});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null || text.isEmpty) return;
    controller.text = text;
    onChanged();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: 'http://192.168.1.20:8080',
          prefixIcon: const Icon(LucideIcons.server, size: 18),
          suffixIcon: IconButton(
            tooltip: 'Incolla',
            icon: const Icon(LucideIcons.clipboardPaste, size: 18),
            onPressed: enabled ? _paste : null,
          ),
        ),
      );
}

/// L'avviso sotto l'indirizzo: in chiaro fuori casa il token si legge.
Widget _addressNote(BuildContext context, TextEditingController address, String otherwise) {
  final url = normalizeServerUrl(address.text);
  final exposed = url != null && url.scheme == 'http' && !isPrivateAddress(url);
  return Text(
    exposed
        ? 'Attenzione: in chiaro su un indirizzo pubblico il token del tuo account si legge per strada. '
            'Usa HTTPS (Tailscale Funnel, un reverse proxy) o Tailscale.'
        : otherwise,
    style: KagamiType.body(12.5, height: 1.45, color: exposed ? context.tokens.danger : context.tokens.muted),
  );
}

/// Collegare un server, cambiarlo o scollegarlo. Si salva solo dopo che il
/// server ha riconosciuto l'account e ha il suo Drive.
class ServerLinkSheet extends ConsumerStatefulWidget {
  const ServerLinkSheet({this.address, this.from, this.linked = false, super.key});

  final Uri? address;

  /// L'invito da cui si arriva, se si arriva da uno.
  final ServerInvite? from;

  /// Il server a [address] è quello già collegato.
  final bool linked;

  static Future<void> open(BuildContext context, {Uri? address, ServerInvite? from, bool linked = false}) =>
      showKagamiSheet<void>(
        context,
        title: linked ? 'Server' : 'Collega un server',
        scrollable: true,
        builder: (context) => ServerLinkSheet(address: address, from: from, linked: linked),
      );

  @override
  ConsumerState<ServerLinkSheet> createState() => _ServerLinkSheetState();
}

class _ServerLinkSheetState extends ConsumerState<ServerLinkSheet> {
  late final TextEditingController _address = TextEditingController(text: widget.address?.toString() ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = normalizeServerUrl(_address.text);
    if (url == null) {
      setState(() => _error = 'Scrivi l\'indirizzo del server, per esempio http://192.168.1.20:8080.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await linkServer(context, ref, url);
      if (info == null || !mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Collegato a «${info.name}»: scarica in «${info.folderName ?? info.folderId}» sul tuo Drive.'),
      ));
    } on ServerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on DriveException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    setState(() => _busy = true);
    await ref.read(remoteArchiveProvider.notifier).unlink();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    final from = widget.from;
    final email = ref.watch(cloudAccountProvider).account?.email;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            from != null
                ? '${from.sender} ti ha aggiunto a «${from.serverName}». Collegandolo, il server scaricherà '
                    'i manga che scegli nella cartella della tua libreria sul tuo Drive: Google ti chiederà '
                    'di permettergli di scriverci. Chi gestisce il server potrà usare quel permesso.'
                : widget.linked
                    ? 'Il server ti riconosce come ${email ?? 'l\'account con cui hai fatto l\'accesso'}. '
                        'Scollegandolo, se non è tuo, dimentica anche il permesso sul tuo Drive e la tua coda.'
                    : 'Scrivi l\'indirizzo del server: il tuo, o quello che ti ha dato chi ti ha aggiunto. '
                        'Il server ti riconosce dall\'account Google, e la prima volta gli dai il permesso '
                        'di scrivere nella cartella della tua libreria su Drive.',
            style: KagamiType.body(13, height: 1.45, color: muted),
          ),
          const SizedBox(height: 14),
          _AddressField(controller: _address, enabled: !_busy, onChanged: () => setState(() {})),
          const SizedBox(height: 10),
          _addressNote(context, _address, 'L\'indirizzo viaggia col backup e con l\'account, come la cartella di Drive.'),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
          ],
          const SizedBox(height: 18),
          KButton(
            label: _busy ? 'Verifica…' : (widget.linked ? 'Verifica di nuovo' : 'Verifica e collega'),
            icon: LucideIcons.plugZap,
            expand: true,
            onPressed: _busy ? null : _connect,
          ),
          if (widget.linked) ...[
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

/// Crea il server del proprietario: l'app prepara tutto e ne esce un comando
/// solo, da incollare su un computer con Docker. Sul server non c'è niente da
/// configurare né accessi da fare: progetto, client e permesso sul Drive
/// viaggiano nel comando.
class ServerSetupSheet extends ConsumerStatefulWidget {
  const ServerSetupSheet({super.key});

  static Future<void> open(BuildContext context) => showKagamiSheet<void>(
        context,
        title: 'Crea il tuo server',
        scrollable: true,
        builder: (context) => const ServerSetupSheet(),
      );

  @override
  ConsumerState<ServerSetupSheet> createState() => _ServerSetupSheetState();
}

class _ServerSetupSheetState extends ConsumerState<ServerSetupSheet> {
  final TextEditingController _address = TextEditingController();
  String? _command;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() step) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await step();
    } on ServerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on DriveException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Accesso, cartella della libreria, permesso duraturo su Drive: ognuno
  /// si salta se c'è già, tranne l'ultimo, che il comando porta con sé.
  Future<void> _generate() => _run(() async {
        final email = await _signedIn(ref);
        if (email == null || !mounted) return;
        if (ref.read(driveFolderProvider).value == null) await connectDrive(context, ref);
        final folder = ref.read(driveFolderProvider).value;
        if (folder == null) return;
        final access = ref.read(serverAccessProvider);
        final grant = await access.grantDrive(email);
        if (grant == null) return;
        final account = ref.read(cloudAccountProvider).account;
        final first = account?.name?.split(' ').first;
        final setup = ServerSetup(
          project: access.project,
          client: grant.client,
          owner: email,
          refreshToken: grant.refreshToken,
          folderId: folder.id,
          folderName: folder.name,
          name: first == null || first.isEmpty ? 'Il mio Kagami Server' : 'Il server di $first',
        );
        if (mounted) setState(() => _command = serverCommand(setup, image: serverImage));
      });

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _command!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comando copiato.')));
  }

  Future<void> _connect() => _run(() async {
        final url = normalizeServerUrl(_address.text);
        if (url == null) {
          throw const ServerException('Scrivi l\'indirizzo del computer, per esempio http://192.168.1.20:8080.');
        }
        final info = await linkServer(context, ref, url);
        if (info == null || !mounted) return;
        if (!info.isOwner) {
          throw ServerException('Quel server è di ${info.owner}: è collegato, ma non l\'hai creato tu.');
        }
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('«${info.name}» è pronto. Aggiungi chi vuoi da «Chi può usarlo».'),
        ));
      });

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    final command = _command;
    final folder = ref.watch(driveFolderProvider).value;
    final account = ref.watch(cloudAccountProvider).account;
    Widget step(String number, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, child: Text(number, style: KagamiType.body(13, weight: 700))),
              Expanded(child: Text(text, style: KagamiType.body(13, height: 1.45, color: muted))),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Serve un computer che resti acceso — un mini PC, un NAS, un Raspberry Pi, un server in rete — '
            'con Docker. Il server scarica i manga e li carica sul tuo Drive, in '
            '«${folder?.name ?? 'la cartella della libreria'}», anche a telefono spento.',
            style: KagamiType.body(13, height: 1.45, color: muted),
          ),
          const SizedBox(height: 16),
          if (command == null) ...[
            Text(
              'Preparo un comando che contiene tutto: '
              '${account == null ? 'prima fai l\'accesso con Google, poi ' : ''}'
              '${folder == null ? 'scegli la cartella dei manga su Drive, poi ' : ''}'
              'Google ti chiede di permettere al server di scrivere sul tuo Drive.',
              style: KagamiType.body(13, height: 1.45, color: muted),
            ),
            const SizedBox(height: 16),
            KButton(
              label: _busy ? 'Preparo…' : 'Genera il comando',
              icon: LucideIcons.terminal,
              expand: true,
              onPressed: _busy ? null : _generate,
            ),
          ] else ...[
            step('1', 'Installa Docker sul computer (docker.com), se non c\'è già.'),
            step('2', 'Incolla questo comando nel suo terminale. Contiene il permesso sul tuo Drive: '
                'non mandarlo a nessuno.'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                command,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: KagamiType.body(12, height: 1.4).copyWith(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 10),
            KGhostButton(label: 'Copia il comando', icon: LucideIcons.copy, expand: true, onPressed: _copy),
            const SizedBox(height: 16),
            step('3', 'Scrivi qui l\'indirizzo del computer: in casa quello della rete locale; da fuori, '
                'il suo nome in Tailscale o l\'indirizzo HTTPS con cui lo esponi.'),
            const SizedBox(height: 4),
            _AddressField(controller: _address, enabled: !_busy, onChanged: () => setState(() {})),
            const SizedBox(height: 10),
            _addressNote(context, _address, 'Il server risponde sulla porta 8080.'),
            const SizedBox(height: 16),
            KButton(
              label: _busy ? 'Verifica…' : 'Verifica e collega',
              icon: LucideIcons.plugZap,
              expand: true,
              onPressed: _busy ? null : _connect,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
          ],
        ],
      ),
    );
  }
}

/// Chi può usare il server: solo per il proprietario. Chi si aggiunge riceve
/// un avviso nell'app, e i suoi download vanno sul suo Drive.
class ServerUsersSheet extends ConsumerStatefulWidget {
  const ServerUsersSheet({super.key});

  static Future<void> open(BuildContext context) => showKagamiSheet<void>(
        context,
        title: 'Chi può usarlo',
        scrollable: true,
        builder: (context) => const ServerUsersSheet(),
      );

  @override
  ConsumerState<ServerUsersSheet> createState() => _ServerUsersSheetState();
}

class _ServerUsersSheetState extends ConsumerState<ServerUsersSheet> {
  final TextEditingController _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Scrivi l\'indirizzo dell\'account Google, per esempio nome@gmail.com.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(remoteArchiveProvider.notifier).addUser(email);
      _email.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$email può usare il server: glielo dice la sua app.'),
        ));
      }
    } on ServerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ServerUser user) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Togliere ${user.email}?'),
        content: const Text('Non potrà più usare il server. La sua coda e il permesso sul suo Drive si '
            'cancellano; ciò che è già sul suo Drive resta.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Togli')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _guard(context, () => ref.read(remoteArchiveProvider.notifier).removeUser(user));
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(remoteArchiveProvider.select((view) => view.users));
    final muted = context.tokens.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Aggiungi l\'account Google di chi vuoi. Nella sua app di Kagami comparirà l\'invito: '
            'collegando il server, i suoi download andranno sul suo Drive, con la sua coda.',
            style: KagamiType.body(13, height: 1.45, color: muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'nome@gmail.com',
              prefixIcon: const Icon(LucideIcons.atSign, size: 18),
              suffixIcon: IconButton(
                tooltip: 'Aggiungi',
                icon: const Icon(LucideIcons.userPlus, size: 18),
                onPressed: _busy ? null : _add,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
          ],
          const SizedBox(height: 16),
          KGroup(children: [
            for (final user in users)
              KTile(
                icon: user.owner ? LucideIcons.crown : LucideIcons.user,
                title: user.email,
                subtitle: user.owner
                    ? 'Tu, il proprietario'
                    : user.connected
                        ? 'Ha collegato il server'
                        : 'Invitato, non ha ancora collegato il server',
                trailing: user.owner
                    ? null
                    : IconButton(
                        tooltip: 'Togli',
                        icon: const Icon(LucideIcons.userMinus, size: 18),
                        onPressed: _busy ? null : () => _remove(user),
                      ),
              ),
          ]),
        ],
      ),
    );
  }
}
