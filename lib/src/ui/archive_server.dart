/// Il server in «Scarica un manga»: crearlo, collegarlo, vederne la coda,
/// dirgli in quale cartella di Drive scrivere, e per il proprietario chi può
/// usarlo.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/remote.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cloud.dart';
import '../data/drive.dart';
import '../data/server_access.dart';
import '../l10n.dart';
import '../providers.dart';
import 'drive_ui.dart';
import 'library_screen.dart' show openSeries;
import 'sync_screen.dart' show clockOf;
import 'theme.dart';
import 'widgets/kit.dart';
import 'widgets/series_cover.dart';

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
  final l10n = currentL10n();
  return today
      ? l10n.serverWhenToday(clock)
      : l10n.serverWhenDate(DateFormat.Md(l10n.localeName).format(local), clock);
}

/// La serie che si sta scaricando, dal telefono o dal server: stessi campi,
/// stessa riga.
class ArchiveProgressRow extends StatelessWidget {
  const ArchiveProgressRow({
    required this.title,
    required this.status,
    required this.onCancel,
    this.card = false,
    super.key,
  });

  final String title;
  final ArchiveStatus status;
  final VoidCallback onCancel;

  /// Solo la scheda: niente pagine né capitoli da contare.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    final l10n = context.l10n;
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
                  card
                      ? l10n.archiveCardProgress(status.message)
                      : '${status.message}\n'
                          '${l10n.serverProgressStats(status.pagesDownloaded, archiveSize(status.bytes), status.pagesSkipped)}',
                  style: KagamiType.body(12.5, height: 1.4, color: muted),
                ),
                const SizedBox(height: 8),
                status.total == 0 ? const LinearProgressIndicator(minHeight: 5) : KProgress(value: status.fraction),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.serverRemoveFromQueue,
            icon: const Icon(LucideIcons.x, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Gli esiti raccolti per serie, il più recente per primo e quante volte è
/// scesa: scaricando man mano ogni capitolo letto lascia un esito, e la
/// stessa serie riempirebbe l'elenco.
List<({ArchiveOutcome outcome, int runs})> recentOutcomes(List<ArchiveOutcome> history) {
  final recent = <String, ({ArchiveOutcome outcome, int runs})>{};
  for (final outcome in history) {
    final key = outcome.seriesKey ?? outcome.url ?? outcome.title;
    final seen = recent[key];
    recent[key] = seen == null ? (outcome: outcome, runs: 1) : (outcome: seen.outcome, runs: seen.runs + 1);
  }
  return recent.values.toList();
}

/// Una serie scaricata da poco: la copertina se è già in libreria, com'è
/// andata l'ultima volta, e il tocco che la apre — o la riprova, se è
/// andata male.
class ArchiveRecentTile extends ConsumerWidget {
  const ArchiveRecentTile({required this.outcome, required this.runs, this.onRetry, super.key});

  final ArchiveOutcome outcome;
  final int runs;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final danger = context.tokens.danger;
    final key = outcome.seriesKey;
    final entry = key == null ? null : ref.watch(seriesEntryProvider(key));
    final when = archiveWhen(outcome.finishedAt);
    final line = runs > 1
        ? l10n.archiveRecentLineRuns(when, runs, outcome.message)
        : l10n.archiveHistoryLine(when, outcome.message);
    return KPress(
      onTap: entry != null ? () => openSeries(context, entry.key) : onRetry,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 36,
                height: 52,
                child: entry != null
                    ? CoverImage(entry: entry, width: 36)
                    : ColoredBox(
                        color: (outcome.ok ? scheme.onSurface : danger).withValues(alpha: .10),
                        child: Icon(
                          outcome.ok ? LucideIcons.circleCheck : LucideIcons.triangleAlert,
                          size: 18,
                          color: outcome.ok ? scheme.onSurface : danger,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!outcome.ok) ...[
                        Icon(LucideIcons.triangleAlert, size: 14, color: danger),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          outcome.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KagamiType.title(14.5, color: outcome.ok ? scheme.onSurface : danger),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: KagamiType.body(12.5, height: 1.35, color: context.tokens.muted),
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              IconButton(
                tooltip: l10n.archiveRetry,
                icon: const Icon(LucideIcons.rotateCcw, size: 18),
                onPressed: onRetry,
              )
            else if (entry != null) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 18, color: context.tokens.muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le serie scaricate, come copertine in fila: sono cronologia, non comandi,
/// e devono sembrarlo accanto alle righe di [KTile], che sono i comandi. In
/// colonna, una per riga, spingevano il controllo delle serie sotto lo
/// schermo; la fila tiene le ultime, e il foglio tutte, col dettaglio.
class ArchiveRecentStrip extends StatelessWidget {
  const ArchiveRecentStrip({
    required this.title,
    required this.history,
    required this.onClear,
    this.onRetry,
    super.key,
  });

  final String title;
  final List<ArchiveOutcome> history;
  final Future<void> Function() onClear;

  /// Riprova un download fallito dal suo link.
  final void Function(String url)? onRetry;

  static const double _width = 96;

  VoidCallback? _retryOf(ArchiveOutcome outcome) =>
      outcome.ok || outcome.url == null || onRetry == null ? null : () => onRetry!(outcome.url!);

  @override
  Widget build(BuildContext context) {
    final recent = recentOutcomes(history);
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 30),
        KSection(
          title,
          trailing: TextButton(
            onPressed: () => _openAll(context, recent),
            child: Text(context.l10n.archiveRecentAll(recent.length)),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: recent.length.clamp(0, 12),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final outcome = recent[index].outcome;
              return _RecentCover(outcome: outcome, width: _width, onRetry: _retryOf(outcome));
            },
          ),
        ),
      ],
    );
  }

  void _openAll(BuildContext context, List<({ArchiveOutcome outcome, int runs})> recent) =>
      showKagamiSheet<void>(
        context,
        title: title,
        scrollable: true,
        action: TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onClear();
          },
          child: Text(context.l10n.archiveClearHistory),
        ),
        builder: (sheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: KGroup(
            children: [
              for (final (:outcome, :runs) in recent)
                ArchiveRecentTile(
                  outcome: outcome,
                  runs: runs,
                  onRetry: switch (_retryOf(outcome)) {
                    final retry? => () {
                        Navigator.of(sheet).pop();
                        retry();
                      },
                    null => null,
                  },
                ),
            ],
          ),
        ),
      );
}

/// Una serie della fila: la copertina se è in libreria, e sotto quando è
/// scesa. Una fallita lo dice col colore e si riprova toccandola.
class _RecentCover extends ConsumerWidget {
  const _RecentCover({required this.outcome, required this.width, this.onRetry});

  final ArchiveOutcome outcome;
  final double width;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final danger = context.tokens.danger;
    final failed = !outcome.ok;
    final key = outcome.seriesKey;
    final entry = key == null ? null : ref.watch(seriesEntryProvider(key));
    final tint = failed ? danger : scheme.onSurface;
    final line = failed
        ? l10n.archiveRecentFailed
        : outcome.card
            ? l10n.archiveRecentCard(archiveWhen(outcome.finishedAt))
            : archiveWhen(outcome.finishedAt);
    return Semantics(
      button: true,
      label: '${outcome.title}, $line',
      excludeSemantics: true,
      child: KPress(
        onTap: failed && onRetry != null
            ? onRetry
            : entry != null
                ? () => openSeries(context, entry.key)
                : null,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: width,
                  height: width * 1.42,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (entry != null)
                        CoverImage(entry: entry, width: width)
                      else
                        ColoredBox(
                          color: tint.withValues(alpha: .10),
                          child: Icon(
                            failed
                                ? LucideIcons.triangleAlert
                                : outcome.card
                                    ? LucideIcons.bookmark
                                    : LucideIcons.bookCheck,
                            size: 24,
                            color: tint,
                          ),
                        ),
                      if (failed) ...[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: danger, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        if (onRetry != null)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(color: danger, shape: BoxShape.circle),
                              child: const Icon(LucideIcons.rotateCcw, size: 13, color: Colors.white),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                outcome.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KagamiType.title(12.5, color: scheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KagamiType.body(11.5, color: failed ? danger : context.tokens.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La voce che apre le serie seguite: quante sono, e quante hanno un
/// problema, che deve vedersi anche col foglio chiuso.
class ArchiveFollowedTile extends StatelessWidget {
  const ArchiveFollowedTile({
    required this.count,
    required this.problems,
    required this.tiles,
    super.key,
  });

  final int count;
  final int problems;

  /// Le righe del foglio, rilette mentre è aperto: smettere di seguire una
  /// serie la toglie subito.
  final List<Widget> Function(BuildContext context, WidgetRef ref) tiles;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return KGroup(
      children: [
        KTile(
          icon: problems > 0 ? LucideIcons.triangleAlert : LucideIcons.bookMarked,
          tint: problems > 0 ? context.tokens.danger : null,
          title: l10n.archiveFollowedTitle,
          subtitle: count == 0
              ? l10n.archiveNoTracked
              : [
                  l10n.archiveTrackedCount(count),
                  if (problems > 0) l10n.archiveFollowedProblems(problems),
                ].join(' · '),
          trailing: count == 0 ? null : const Icon(LucideIcons.chevronRight, size: 18),
          onTap: count == 0 ? null : () => _open(context),
        ),
      ],
    );
  }

  void _open(BuildContext context) => showKagamiSheet<void>(
        context,
        title: context.l10n.archiveFollowedTitle,
        scrollable: true,
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            final children = tiles(context, ref);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: children.isEmpty
                  ? Text(
                      context.l10n.archiveNoTracked,
                      style: KagamiType.body(13, color: context.tokens.muted),
                    )
                  : KGroup(children: children),
            );
          },
        ),
      );
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
  const ServerSection({this.onRetry, super.key});

  /// Riprova un download fallito dal suo link.
  final void Function(String url)? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(remoteArchiveProvider);
    final link = view.link;
    final muted = context.tokens.muted;
    final l10n = context.l10n;
    final account = ref.watch(cloudAccountProvider).account;
    final invites = [
      for (final invite in ref.watch(serverInvitesProvider).value ?? const <ServerInvite>[])
        if (invite.url != link?.url.toString()) invite,
    ];
    final children = <Widget>[
      const SizedBox(height: 30),
      KSection(l10n.serverTitle),
    ];
    if (!cloudAvailable) {
      children.add(Text(
        l10n.serverNoFirebase,
        style: KagamiType.body(12.5, height: 1.45, color: muted),
      ));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    if (account == null) {
      children.addAll([
        Text(
          l10n.serverSignedOutIntro,
          style: KagamiType.body(12.5, height: 1.45, color: muted),
        ),
        const SizedBox(height: 12),
        KGroup(children: [
          KTile(
            icon: LucideIcons.logIn,
            title: l10n.serverSignIn,
            subtitle: l10n.serverSignInSubtitle,
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
              title: l10n.serverInviteTitle(invite.sender, invite.serverName),
              subtitle: l10n.serverInviteSubtitle,
              trailing: IconButton(
                tooltip: l10n.serverIgnore,
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
          l10n.serverLinkIntro,
          style: KagamiType.body(12.5, height: 1.45, color: muted),
        ),
        const SizedBox(height: 12),
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.serverCog,
              title: l10n.serverCreate,
              subtitle: l10n.serverCreateSubtitle,
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => ServerSetupSheet.open(context),
            ),
            KTile(
              icon: LucideIcons.server,
              title: l10n.serverLinkTitle,
              subtitle: l10n.serverLinkSubtitle,
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
      RemoteArchiveView(info: null) => l10n.serverStateConnecting,
      RemoteArchiveView(info: ServerInfo(driveAuthorized: false)) => l10n.serverStateNoGrant,
      RemoteArchiveView(info: ServerInfo(folderId: null)) => l10n.serverStateNoFolder,
      RemoteArchiveView(:final info?) => l10n.serverStateReady('${info.folderName ?? info.folderId}'),
    };
    // Con il server in errore, ciò che si sa di lui è vecchio: niente gesti
    // che partono da lì.
    final differs = view.error == null &&
        info != null &&
        info.driveAuthorized &&
        appFolder != null &&
        info.folderId != appFolder.id;
    final address = '${link.url.host}${link.url.hasPort ? ':${link.url.port}' : ''}';
    children.add(KGroup(
      children: [
        KTile(
          icon: view.error == null ? LucideIcons.server : LucideIcons.serverOff,
          tint: view.error == null ? null : context.tokens.danger,
          title: name,
          subtitle: info == null || info.isOwner
              ? l10n.serverTileSubtitle(address, state)
              : l10n.serverTileSubtitleOwner(address, '${info.owner}', state),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => ServerLinkSheet.open(context, address: link.url, linked: true),
        ),
        if (link.url.scheme == 'http' && !isPrivateAddress(link.url))
          KTile(
            icon: LucideIcons.triangleAlert,
            tint: context.tokens.danger,
            title: l10n.serverPlainTitle,
            subtitle: l10n.serverPlainSubtitle,
          ),
        if (view.error == null && info != null && !info.ready)
          KTile(
            icon: LucideIcons.hardDriveUpload,
            title: l10n.serverGrantTitle,
            subtitle: l10n.serverGrantSubtitle,
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _grant(context, ref, link),
          ),
        if (differs)
          KTile(
            icon: LucideIcons.folderSync,
            title: l10n.serverUseAppFolder,
            subtitle: l10n.serverUseAppFolderSubtitle('${info.folderName ?? info.folderId}', appFolder.name),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _guard(context, () => notifier.useFolder(appFolder)),
          ),
        if (info != null && info.isOwner && view.error == null)
          KTile(
            icon: LucideIcons.users,
            title: l10n.serverUsersTitle,
            subtitle: view.users.length <= 1 ? l10n.serverUsersOnlyYou : l10n.serverUsersCount(view.users.length),
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
            title: l10n.serverQueueWaiting,
            subtitle: queue.status.message.isEmpty ? l10n.serverQueueRestarts : queue.status.message,
          ),
        for (final job in waiting)
          KTile(
            icon: job.ahead != null
                ? LucideIcons.sparkles
                : job.automatic
                    ? LucideIcons.refreshCw
                    : LucideIcons.clock,
            title: job.title.isEmpty ? job.url : job.title,
            subtitle: job.ahead != null
                ? l10n.serverJobAhead(job.ids?.length ?? 0)
                : job.automatic
                    ? l10n.serverJobAutomatic
                    : l10n.serverJobQueued,
            trailing: IconButton(
              tooltip: l10n.serverRemoveFromQueue,
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => _guard(context, () => notifier.cancel(job)),
            ),
          ),
      ],
    ));
    if (info != null) {
      final check = info.check;
      children.addAll([
        const SizedBox(height: 12),
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.calendarClock,
              title: l10n.serverCheckDaily,
              subtitle: [
                if (check.enabled) l10n.serverCheckDailyAt(clockOf(check.minutes)) else l10n.serverCheckDailyOff,
                if (check.checkedAt case final at?) l10n.serverCheckLast(archiveWhen(at), check.queued),
              ].join('\n'),
              onTap: view.error != null || !check.enabled ? null : () => _checkTime(context, notifier, check),
              trailing: Switch(
                value: check.enabled,
                onChanged: view.error != null
                    ? null
                    : (value) => _guard(context, () => notifier.configureCheck(enabled: value)),
              ),
            ),
            if (check.enabled)
              KTile(
                icon: LucideIcons.libraryBig,
                title: l10n.serverCheckLibrary,
                subtitle: check.library ? l10n.serverCheckLibraryOn : l10n.serverCheckLibraryOff,
                trailing: Switch(
                  value: check.library,
                  onChanged: view.error != null
                      ? null
                      : (value) => _guard(context, () => notifier.configureCheck(library: value)),
                ),
              ),
            KTile(
              icon: LucideIcons.refreshCw,
              title: l10n.archiveCheckNow,
              onTap: view.error != null ? null : () => _checkNow(context, notifier),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ArchiveFollowedTile(
          count: view.ongoing.length,
          problems: view.ongoing.where((series) => series.problem != null).length,
          tiles: _ongoingTiles,
        ),
      ]);
    }
    children.add(ArchiveRecentStrip(
      title: l10n.serverRecent,
      history: queue.history,
      onClear: () => _guard(context, notifier.clearHistory),
      onRetry: onRetry,
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  /// Le serie che segue il server, per il foglio.
  static List<Widget> _ongoingTiles(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(remoteArchiveProvider);
    final notifier = ref.read(remoteArchiveProvider.notifier);
    return [
      for (final series in view.ongoing)
        KTile(
          icon: series.problem != null
              ? LucideIcons.triangleAlert
              : series.ahead != null
                  ? LucideIcons.sparkles
                  : LucideIcons.bookOpen,
          tint: series.problem == null ? null : context.tokens.danger,
          title: series.title,
          subtitle: series.problem ??
              (series.ahead != null
                  ? l10n.serverSeriesAhead(series.ahead!)
                  : series.checkedAt == null
                  ? l10n.serverSeriesKnown(series.chapters)
                  : l10n.serverSeriesKnownChecked(series.chapters, archiveWhen(series.checkedAt!))),
          trailing: IconButton(
            tooltip: l10n.serverStopFollowing,
            icon: const Icon(LucideIcons.bellOff, size: 18),
            onPressed: () => _guard(context, () => notifier.forget(series)),
          ),
        ),
    ];
  }

  static Future<void> _ignore(BuildContext context, WidgetRef ref, ServerInvite invite) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(serverAccessProvider).withdraw(invite.to, Uri.parse(invite.url));
    } on FirebaseException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.serverInviteRemoveFailed)));
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

  static Future<void> _checkTime(BuildContext context, RemoteArchiveController notifier, RemoteCheck check) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: check.minutes ~/ 60, minute: check.minutes % 60),
      helpText: context.l10n.serverCheckTimeHelp,
    );
    if (picked == null || !context.mounted) return;
    await _guard(context, () => notifier.configureCheck(minutes: picked.hour * 60 + picked.minute));
  }

  static Future<void> _checkNow(BuildContext context, RemoteArchiveController notifier) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await notifier.check();
      messenger.showSnackBar(SnackBar(content: Text(l10n.serverCheckingNow)));
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
            tooltip: context.l10n.serverPaste,
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
        ? context.l10n.serverAddressExposed
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
        title: linked ? context.l10n.serverTitle : context.l10n.serverLinkTitle,
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
      setState(() => _error = context.l10n.serverAddressMissing);
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
        content: Text(context.l10n.serverLinked(info.name, '${info.folderName ?? info.folderId}')),
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
    final l10n = context.l10n;
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
                ? l10n.serverLinkFromInvite(from.sender, from.serverName)
                : widget.linked
                    ? l10n.serverLinkLinked(email ?? l10n.serverSignedInAccount)
                    : l10n.serverLinkNew,
            style: KagamiType.body(13, height: 1.45, color: muted),
          ),
          const SizedBox(height: 14),
          _AddressField(controller: _address, enabled: !_busy, onChanged: () => setState(() {})),
          const SizedBox(height: 10),
          _addressNote(context, _address, l10n.serverAddressSavedNote),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
          ],
          const SizedBox(height: 18),
          KButton(
            label: _busy ? l10n.serverVerifying : (widget.linked ? l10n.serverVerifyAgain : l10n.serverVerifyAndLink),
            icon: LucideIcons.plugZap,
            expand: true,
            onPressed: _busy ? null : _connect,
          ),
          if (widget.linked) ...[
            const SizedBox(height: 10),
            KGhostButton(
              label: l10n.serverUnlink,
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
        title: context.l10n.serverCreate,
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
        final l10n = context.l10n;
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
          name: first == null || first.isEmpty
              ? l10n.serverDefaultNameOwn
              : l10n.serverDefaultNameOf(first),
        );
        if (mounted) setState(() => _command = serverCommand(setup, image: serverImage));
      });

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _command!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.serverCommandCopied)));
  }

  Future<void> _connect() => _run(() async {
        final url = normalizeServerUrl(_address.text);
        if (url == null) {
          throw ServerException(context.l10n.serverComputerAddressMissing);
        }
        final info = await linkServer(context, ref, url);
        if (info == null || !mounted) return;
        if (!info.isOwner) {
          throw ServerException(context.l10n.serverNotOwner('${info.owner}'));
        }
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.serverReady(info.name)),
        ));
      });

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    final l10n = context.l10n;
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
            l10n.serverSetupIntro(folder?.name ?? l10n.serverLibraryFolderFallback),
            style: KagamiType.body(13, height: 1.45, color: muted),
          ),
          const SizedBox(height: 16),
          if (command == null) ...[
            Text(
              l10n.serverPrepareIntro(account == null ? 'yes' : 'no', folder == null ? 'yes' : 'no'),
              style: KagamiType.body(13, height: 1.45, color: muted),
            ),
            const SizedBox(height: 16),
            KButton(
              label: _busy ? l10n.serverPreparing : l10n.serverGenerate,
              icon: LucideIcons.terminal,
              expand: true,
              onPressed: _busy ? null : _generate,
            ),
          ] else ...[
            step('1', l10n.serverStep1),
            step('2', l10n.serverStep2),
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
            KGhostButton(label: l10n.serverCopyCommand, icon: LucideIcons.copy, expand: true, onPressed: _copy),
            const SizedBox(height: 16),
            step('3', l10n.serverStep3),
            const SizedBox(height: 4),
            _AddressField(controller: _address, enabled: !_busy, onChanged: () => setState(() {})),
            const SizedBox(height: 10),
            _addressNote(context, _address, l10n.serverPortNote),
            const SizedBox(height: 16),
            KButton(
              label: _busy ? l10n.serverVerifying : l10n.serverVerifyAndLink,
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
        title: context.l10n.serverUsersTitle,
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
      setState(() => _error = context.l10n.serverUserEmailInvalid);
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
          content: Text(context.l10n.serverUserAdded(email)),
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
        title: Text(context.l10n.serverRemoveTitle(user.email)),
        content: Text(context.l10n.serverRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.serverCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.l10n.serverRemove)),
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
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.serverUsersIntro,
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
                tooltip: l10n.serverAdd,
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
                    ? l10n.serverOwnerYou
                    : user.connected
                        ? l10n.serverConnected
                        : l10n.serverInvitedPending,
                trailing: user.owner
                    ? null
                    : IconButton(
                        tooltip: l10n.serverRemove,
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
