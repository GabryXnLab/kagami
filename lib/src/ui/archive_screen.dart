/// «Scarica un manga»: una ricerca o un link, cosa scaricarne e dove, e la coda.
///
/// È il pannello MangaArchive di Cobalt portato nell'app, con le stesse
/// scelte — la serie intera, dal capitolo scelto in poi o solo alcuni
/// capitoli, la pausa fra le richieste, l'orario del controllo delle serie
/// in corso — e due in più: scaricare «man mano», pochi capitoli davanti a
/// quello che si legge, e la destinazione, che qui può essere la cartella di
/// Drive della libreria, o un Kagami Server collegato. La scelta per una
/// serie sta nella sua pagina (`archive_series.dart`). Il lavoro vero lo fa
/// `packages/kagami_archive/`, in un lavoro in primo piano che continua a
/// schermo spento, o sul server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../data/cloud.dart';
import '../data/drive.dart';
import '../providers.dart';
import 'archive_series.dart';
import 'archive_server.dart';
import 'browser_check_page.dart';
import '../l10n.dart';
import 'drive_ui.dart';
import 'sync_screen.dart' show clockOf;
import 'theme.dart';
import 'widgets/kit.dart';

/// La serie letta dal sito, con ciò che serve a scaricarla uguale dopo.
class _Inspected {
  const _Inspected(this.series, this.metadata, {this.pass});

  final Series series;
  final Map<String, Object?> metadata;

  /// La verifica di Cloudflare superata nella WebView, se è servita.
  final BrowserPass? pass;
}

/// Cosa ha risposto un sito all'ultima ricerca.
class _Found {
  const _Found.loading() : results = null, error = null, challenged = false;
  const _Found.results(List<SearchResult> this.results) : error = null, challenged = false;
  const _Found.error(String this.error) : results = null, challenged = false;
  const _Found.challenged() : results = null, error = null, challenged = true;

  final List<SearchResult>? results;
  final String? error;
  final bool challenged;
}

String _destinationName(AppLocalizations l10n, ArchiveDestination destination) => switch (destination) {
      ArchiveDestination.drive => l10n.archiveWhereDrive,
      ArchiveDestination.driveAndPhone => l10n.archiveWhereDriveAndPhone,
      ArchiveDestination.phone => l10n.archiveWherePhone,
    };

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final TextEditingController _link = TextEditingController();
  final TextEditingController _query = TextEditingController();

  Timer? _searchTimer;
  int _searchRun = 0;
  final Map<String, _Found> _found = {};

  /// I siti dietro una verifica del browser si cercano da una WebView
  /// invisibile, una per sito: a `SiteHttp` Cloudflare non risponde nemmeno
  /// dopo la verifica.
  final Map<String, BrowserFetcher> _fetchers = {};

  _Inspected? _inspected;
  bool _busy = false;
  String? _error;

  ArchiveWhere? _destination;
  int _delayMs = 200;

  @override
  void dispose() {
    _link.dispose();
    _query.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  /// Come la barra del sito: si cerca mezzo secondo dopo l'ultimo tasto, e
  /// una risposta arrivata tardi per un testo già cambiato si butta.
  void _onQuery(String text) {
    _searchTimer?.cancel();
    final query = text.trim();
    // Anche la ✕ del campo dipende dal testo.
    setState(() {});
    if (query.length < 2) {
      _searchRun++;
      _found.clear();
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  void _search(String query) {
    final run = ++_searchRun;
    setState(() {
      for (final provider in providers) {
        _found[provider.id] = const _Found.loading();
      }
    });
    for (final provider in providers) {
      unawaited(_searchOn(provider, query, run));
    }
  }

  Future<void> _searchOn(Provider provider, String query, int run) async {
    final SiteHttp? site;
    final ProviderHttp http;
    if (provider.browser case final gate?) {
      site = null;
      var fetcher = _fetchers[provider.id];
      if (fetcher == null) {
        fetcher = BrowserFetcher(ready: gate.searchReady);
        // La WebView deve entrare nell'albero prima di caricare.
        setState(() => _fetchers[provider.id] = fetcher!);
      }
      http = fetcher;
    } else {
      http = site = SiteHttp(provider.allowedHost);
    }
    _Found found;
    try {
      found = _Found.results(await provider.search(query, http));
    } on CloudflareChallenge {
      found = provider.needsBrowser
          ? const _Found.challenged()
          : _Found.error(currentL10n().archiveErrChallenge);
    } on ProviderOffline {
      found = _Found.error(currentL10n().archiveErrOffline);
    } on ProviderError catch (error) {
      found = _Found.error(error.message);
    } finally {
      site?.close();
    }
    if (!mounted || run != _searchRun) return;
    setState(() => _found[provider.id] = found);
  }

  /// La verifica si fa sulla pagina principale, e basta che compaia la
  /// barra di ricerca del sito: i cookie delle WebView sono gli stessi in
  /// tutta l'app, e la WebView che cerca li trova già.
  Future<void> _verifySearch(Provider provider) async {
    final gate = provider.browser!;
    final pass = await BrowserCheckPage.open(
      context,
      provider.home,
      gate.hosts,
      ready: gate.searchReady,
      waitingFor: BrowserWaiting.search,
    );
    if (pass == null || !mounted) return;
    final query = _query.text.trim();
    if (query.length >= 2) {
      setState(() => _found[provider.id] = const _Found.loading());
      await _searchOn(provider, query, _searchRun);
    }
  }

  /// Scegliere un risultato è incollarne il link: stessa verifica, stessa
  /// domanda «tutta o da un capitolo», stesso modulo.
  Future<void> _pick(SearchResult result) async {
    _searchTimer?.cancel();
    _searchRun++;
    setState(_found.clear);
    _link.text = result.url;
    await _verify();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _link.text = text;
    await _verify();
  }

  Future<void> _verify() async {
    final url = _link.text.trim();
    if (url.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _inspected = null;
    });
    SiteHttp? http;
    try {
      final provider = selectProvider(url);
      http = SiteHttp(provider.allowedHost);
      Series series;
      BrowserPass? pass;
      try {
        series = await provider.fetchSeries(url, http);
      } on CloudflareChallenge {
        final gate = provider.browser;
        if (gate == null || !mounted) rethrow;
        final canonical = provider.canonical(url);
        pass = await BrowserCheckPage.open(
          context,
          canonical,
          gate.hosts,
          ready: gate.seriesReady,
        );
        if (pass == null) {
          setState(() => _error = currentL10n().archiveErrVerifyIncomplete);
          return;
        }
        final cookies = pass.cookies;
        http.close();
        http = SiteHttp(
          provider.allowedHost,
          userAgent: pass.userAgent,
          cookies: (uri) => cookies[uri.host],
        );
        series = await provider.fetchSeries(url, SnapshotHttp(http, canonical, pass.html));
      }
      if (!mounted) return;
      final inspected = _Inspected(series, normalizeMetadata(series.metadata), pass: pass);
      setState(() => _inspected = inspected);
      unawaited(_choose(inspected));
    } on ProviderOffline {
      setState(() => _error = currentL10n().archiveErrOffline);
    } on ProviderError catch (error) {
      setState(() => _error = error.message);
    } finally {
      http?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Dopo il link, la pagina in cui si sceglie cosa scaricare e dove.
  /// Chiudendola senza scegliere la serie resta qui sotto, da riaprire.
  Future<void> _choose(_Inspected inspected) async {
    final destinations = _destinations();
    final choice = await ArchiveSeriesPage.open(
      context,
      series: inspected.series,
      metadata: inspected.metadata,
      destinations: destinations,
      destination: destinations.contains(_destination) ? _destination! : destinations.first,
      delayMs: _delayMs,
      serverHint: _serverWhere(),
      serverAhead: ref.read(remoteArchiveProvider).info?.ahead ?? false,
    );
    if (choice == null || !mounted || _inspected != inspected) return;
    setState(() {
      _destination = choice.where;
      _delayMs = choice.delayMs;
    });
    await _download(inspected, choice);
  }

  /// Il server per primo, se c'è ed è pronto: chi l'ha collegato vuole che
  /// scarichi lui.
  List<ArchiveWhere> _destinations() {
    // La cartella può arrivare da un backup anche in una build senza
    // Firebase, dove Drive non si può aprire.
    final drive =
        cloudAvailable && ref.read(driveFolderProvider).value != null;
    return [
      if (ref.read(remoteArchiveProvider).ready) ArchiveWhere.server,
      ...drive ? const [ArchiveWhere.drive, ArchiveWhere.driveAndPhone] : const [ArchiveWhere.phone],
    ];
  }

  Future<void> _download(_Inspected inspected, ArchiveChoice choice) async {
    final messenger = ScaffoldMessenger.of(context);
    final destination = choice.where.local;
    if (destination == null) return _sendToServer(inspected, choice);
    final folder = ref.read(driveFolderProvider).value;
    String? root;
    var private = false;
    if (destination.keepsOnPhone) {
      root = await downloadDestination(context, ref);
      if (root == null) return;
      private = root == ref.read(appDirectoriesProvider).privateLibrary;
    }
    if (destination.usesDrive) {
      // Caricare vuole il permesso di scrivere su Drive, che l'app chiede
      // solo quando serve.
      try {
        await ref.read(driveAuthProvider).authorize(write: true);
      } on DriveAuthRequired {
        return;
      } on DriveException catch (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
    }
    final files = ref.read(archiveFilesProvider);
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    String? snapshot;
    final pass = inspected.pass;
    if (pass != null) {
      final file = File(p.join(files.snapshots.path, '$id.html'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(pass.html);
      snapshot = file.path;
    }
    await ref.read(archiveProvider.notifier).enqueue(ArchiveJob(
          id: id,
          url: inspected.series.url,
          title: inspected.series.title,
          target: ArchiveTarget(
            destination: destination,
            folderId: destination.usesDrive ? folder?.id : null,
            root: root,
            private: private,
          ),
          start: choice.start,
          ids: choice.ids,
          delayMs: choice.delayMs,
          snapshot: snapshot,
          userAgent: pass?.userAgent,
          cookies: pass?.cookies ?? const {},
          ahead: choice.ahead,
        ));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(currentL10n().archiveQueuedSnack(inspected.series.title)),
    ));
    setState(() {
      _inspected = null;
      _link.clear();
    });
  }

  /// Al server va il link con le stesse scelte; la pagina della serie solo se
  /// è servita la verifica del browser, perché il server non ne ha uno.
  Future<void> _sendToServer(_Inspected inspected, ArchiveChoice choice) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = ref.read(remoteArchiveProvider).info?.name ?? currentL10n().archiveServerFallbackName;
    try {
      await ref.read(remoteArchiveProvider.notifier).enqueue(
            url: inspected.series.url,
            title: inspected.series.title,
            start: choice.start,
            ids: choice.ids,
            delayMs: choice.delayMs,
            ahead: choice.ahead,
            snapshot: inspected.pass == null ? null : utf8.decode(inspected.pass!.html, allowMalformed: true),
          );
    } on ServerException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(currentL10n().archiveQueuedServerSnack(inspected.series.title, name)),
    ));
    setState(() {
      _inspected = null;
      _link.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(archiveProvider);
    // Tiene acceso il controllo del server finché la schermata è aperta, e
    // ridisegna la scelta della destinazione quando il server risponde.
    ref.watch(remoteArchiveProvider);
    final muted = context.tokens.muted;
    final l10n = context.l10n;
    final inspected = _inspected;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archiveTitle)),
      body: Stack(
        children: [
          for (final fetcher in _fetchers.values) Positioned.fill(child: fetcher.view()),
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(
                  l10n.archiveIntro,
                  style: KagamiType.body(13, height: 1.5, color: muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _query,
                  enabled: !_busy,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQuery,
                  onSubmitted: (text) {
                    _searchTimer?.cancel();
                    if (text.trim().length >= 2) _search(text.trim());
                  },
                  decoration: InputDecoration(
                    hintText: l10n.archiveSearchHint,
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.archiveClear,
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () {
                              _query.clear();
                              _onQuery('');
                            },
                          ),
                  ),
                ),
                ..._results(),
                const SizedBox(height: 16),
                TextField(
                  controller: _link,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _verify(),
                  decoration: InputDecoration(
                    hintText: 'https://…',
                    prefixIcon: const Icon(LucideIcons.link, size: 18),
                    suffixIcon: IconButton(
                      tooltip: l10n.archivePaste,
                      icon: const Icon(LucideIcons.clipboardPaste, size: 18),
                      onPressed: _busy ? null : _paste,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                KButton(
                  label: _busy ? l10n.archiveReading : l10n.archiveVerify,
                  icon: LucideIcons.search,
                  expand: true,
                  onPressed: _busy ? null : _verify,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
                ],
                if (inspected != null) ..._pending(inspected),
                ..._queue(view),
                ServerSection(onRetry: _busy ? null : _retry),
                ..._tracked(view),
                ..._sites(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La serie letta e non ancora scaricata: la pagina della scelta si
  /// riapre da qui.
  List<Widget> _pending(_Inspected inspected) {
    final series = inspected.series;
    final l10n = context.l10n;
    final placeholder = ColoredBox(color: context.tokens.muted.withValues(alpha: .15));
    return [
      const SizedBox(height: 20),
      KCard(
        padding: const EdgeInsets.all(12),
        onTap: () => _choose(inspected),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 62,
                child: series.coverUrl == null
                    ? placeholder
                    : Image.network(
                        series.coverUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 132,
                        headers: {'Referer': series.url, 'User-Agent': defaultUserAgent},
                        errorBuilder: (_, _, _) => placeholder,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KagamiType.title(14.5, color: context.colors.onSurface),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.archiveSeriesSummary(
                      providerById(series.provider)?.name ?? series.provider,
                      series.chapters.length,
                      archiveStatusLabel(l10n, inspected.metadata['releaseStatus']),
                    ),
                    style: KagamiType.body(12.5, color: context.tokens.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: context.tokens.muted),
          ],
        ),
      ),
      const SizedBox(height: 10),
      KButton(
        label: l10n.archiveReopen,
        icon: LucideIcons.listChecks,
        expand: true,
        onPressed: () => _choose(inspected),
      ),
    ];
  }

  String _serverWhere() {
    final info = ref.read(remoteArchiveProvider).info;
    final folder = ref.read(driveFolderProvider).value;
    final other = folder != null && info?.folderId != folder.id;
    return context.l10n.archiveServerHint(
      info?.name ?? '',
      info?.folderName ?? info?.folderId ?? '',
      other ? 'other' : 'same',
    );
  }

  List<Widget> _results() {
    final muted = context.tokens.muted;
    final l10n = context.l10n;
    return [
      for (final provider in providers)
        if (_found[provider.id] case final found?) ...[
          const SizedBox(height: 18),
          KSection(provider.name),
          if (found.results case final results?)
            results.isEmpty
                ? Text(l10n.archiveNoResults(provider.name),
                    style: KagamiType.body(12.5, color: muted))
                : KGroup(
                    children: [
                      for (final result in results)
                        _ResultTile(
                          result: result,
                          referer: provider.home,
                          details: [
                            if (result.chapters case final count?) l10n.archiveChaptersCount(count),
                            if (result.releaseStatus != 'unknown') archiveStatusLabel(l10n, result.releaseStatus),
                          ].join(' · '),
                          onTap: _busy ? null : () => _pick(result),
                        ),
                    ],
                  )
          else if (found.challenged)
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.shieldCheck,
                  title: l10n.archiveVerifySite(provider.name),
                  subtitle: l10n.archiveVerifySiteHint,
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => _verifySearch(provider),
                ),
              ],
            )
          else if (found.error case final error?)
            Text(error, style: KagamiType.body(12.5, height: 1.45, color: context.tokens.danger))
          else
            const LinearProgressIndicator(minHeight: 3),
        ],
    ];
  }

  List<Widget> _queue(ArchiveView view) {
    final notifier = ref.read(archiveProvider.notifier);
    final l10n = context.l10n;
    final status = view.status;
    final current = view.current;
    final waiting = [for (final job in view.jobs) if (job.id != current?.id) job];
    final recent = recentOutcomes(view.history);
    return [
      if (view.jobs.isNotEmpty) ...[
        const SizedBox(height: 30),
        KSection(l10n.archiveDownloads),
        KGroup(
          children: [
            if (current != null)
              ArchiveProgressRow(
                title: current.title,
                status: status,
                onCancel: () => notifier.remove(current),
              ),
            if (current == null)
              KTile(
                icon: LucideIcons.play,
                title: l10n.archiveQueueStopped,
                subtitle: status.state == ArchiveState.waiting
                    ? status.message
                    : l10n.archiveQueueResumeHint,
                onTap: notifier.resume,
              ),
            for (final job in waiting)
              KTile(
                icon: job.ahead != null
                    ? LucideIcons.sparkles
                    : job.automatic
                        ? LucideIcons.refreshCw
                        : LucideIcons.clock,
                title: job.title,
                subtitle: job.ahead != null
                    ? l10n.archiveJobAhead(job.ids?.length ?? 0, _destinationName(l10n, job.target.destination))
                    : job.automatic
                        ? l10n.archiveJobAutomatic(_destinationName(l10n, job.target.destination))
                        : l10n.archiveJobQueued(_destinationName(l10n, job.target.destination)),
                trailing: IconButton(
                  tooltip: l10n.archiveRemoveFromQueue,
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => notifier.remove(job),
                ),
              ),
          ],
        ),
      ],
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 30),
        KSection(
          l10n.archiveRecent,
          trailing: TextButton(onPressed: notifier.clearHistory, child: Text(l10n.archiveClearHistory)),
        ),
        KGroup(
          children: [
            for (final (:outcome, :runs) in recent.take(10))
              ArchiveRecentTile(
                outcome: outcome,
                runs: runs,
                onRetry: outcome.ok || outcome.url == null || _busy ? null : () => _retry(outcome.url!),
              ),
          ],
        ),
      ],
    ];
  }

  /// Un download fallito si riprova dal suo link: stessa verifica, stessa
  /// pagina di scelta.
  void _retry(String url) {
    _link.text = url;
    _verify();
  }

  /// I siti da cui si può scaricare, col loro indirizzo: il link giusto è
  /// quello della pagina di una serie su uno di questi.
  List<Widget> _sites() {
    final muted = context.tokens.muted;
    final l10n = context.l10n;
    return [
      const SizedBox(height: 30),
      KSection(l10n.archiveSites),
      KGroup(
        children: [
          for (final provider in providers)
            KTile(
              icon: LucideIcons.globe,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(provider.icon, width: 36, height: 36),
              ),
              title: provider.name,
              subtitle: Uri.parse(provider.home).host,
              trailing: const Icon(LucideIcons.externalLink, size: 18),
              onTap: () => _openLink(provider.home),
            ),
        ],
      ),
      const SizedBox(height: 12),
      KCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.sparkles, size: 18, color: context.colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.archiveMoreSites,
                style: KagamiType.body(12.5, height: 1.45, color: muted),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static const MethodChannel _links = MethodChannel('kagami/links');

  /// Nel browser; dove non c'è modo di aprirlo (la build Linux), il link
  /// finisce negli appunti.
  Future<void> _openLink(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await _links.invokeMethod<bool>('open', url) ?? false) return;
    } on MissingPluginException {
      // Si ripiega sugli appunti.
    }
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(SnackBar(content: Text(currentL10n().archiveLinkCopied(url))));
  }

  List<Widget> _tracked(ArchiveView view) {
    final notifier = ref.read(archiveProvider.notifier);
    final muted = context.tokens.muted;
    final l10n = context.l10n;
    final minutes = view.check.minutes;
    return [
      const SizedBox(height: 30),
      KSection(l10n.archiveTracked),
      Text(
        l10n.archiveTrackedIntro,
        style: KagamiType.body(12.5, height: 1.45, color: muted),
      ),
      const SizedBox(height: 12),
      KGroup(
        children: [
          KTile(
            icon: LucideIcons.clock,
            title: l10n.archiveCheckDaily,
            subtitle: minutes == null ? l10n.archiveCheckManual : l10n.archiveCheckAt(clockOf(minutes)),
            onTap: () => _toggleCheck(view.check),
            trailing: Switch(value: minutes != null, onChanged: (_) => _toggleCheck(view.check)),
          ),
          if (minutes != null) ...[
            KTile(
              icon: LucideIcons.alarmClock,
              title: l10n.archiveCheckTime,
              subtitle: clockOf(minutes),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => _chooseTime(view.check),
            ),
            KTile(
              icon: LucideIcons.wifi,
              title: l10n.archiveWifiOnly,
              subtitle: view.check.wifiOnly
                  ? l10n.archiveWifiOnlyOn
                  : l10n.archiveWifiOnlyOff,
              onTap: () => notifier.setCheck(CheckSettings(minutes: minutes, wifiOnly: !view.check.wifiOnly)),
              trailing: Switch(
                value: view.check.wifiOnly,
                onChanged: (value) => notifier.setCheck(CheckSettings(minutes: minutes, wifiOnly: value)),
              ),
            ),
          ],
          KTile(
            icon: LucideIcons.refreshCw,
            title: l10n.archiveCheckNow,
            subtitle: view.tracked.isEmpty
                ? l10n.archiveNoTracked
                : l10n.archiveTrackedCount(view.tracked.length),
            onTap: view.tracked.isEmpty ? null : _checkNow,
          ),
          for (final series in view.tracked)
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
                      ? l10n.archiveTrackedAhead(series.ahead!, _destinationName(l10n, series.target.destination))
                      : series.checkedAt == null
                      ? l10n.archiveTrackedLine(
                          series.chapters.length,
                          _destinationName(l10n, series.target.destination),
                        )
                      : l10n.archiveTrackedLineChecked(
                          series.chapters.length,
                          _destinationName(l10n, series.target.destination),
                          archiveWhen(series.checkedAt!),
                        )),
              trailing: IconButton(
                tooltip: l10n.archiveStopFollowing,
                icon: const Icon(LucideIcons.bellOff, size: 18),
                onPressed: () => _forget(series),
              ),
            ),
        ],
      ),
    ];
  }

  Future<void> _toggleCheck(CheckSettings settings) => ref
      .read(archiveProvider.notifier)
      .setCheck(settings.minutes == null
          ? CheckSettings(minutes: 4 * 60, wifiOnly: settings.wifiOnly)
          : CheckSettings(wifiOnly: settings.wifiOnly));

  Future<void> _chooseTime(CheckSettings settings) async {
    final minutes = settings.minutes ?? 4 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: context.l10n.archiveCheckTimeHelp,
    );
    if (picked == null) return;
    await ref
        .read(archiveProvider.notifier)
        .setCheck(CheckSettings(minutes: picked.hour * 60 + picked.minute, wifiOnly: settings.wifiOnly));
  }

  Future<void> _checkNow() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await ref.read(archiveProvider.notifier).checkNow();
      final l10n = currentL10n();
      final parts = [
        if (report.queued.isNotEmpty) l10n.archiveCheckQueued(report.queued.join(', ')),
        if (report.removed.isNotEmpty) l10n.archiveCheckRemoved(report.removed.join(', ')),
        if (report.failed.isNotEmpty) l10n.archiveCheckFailed(report.failed.length),
      ];
      messenger.showSnackBar(SnackBar(
        content: Text(parts.isEmpty
            ? l10n.archiveNoNewChapters
            : l10n.archiveCheckReport(parts.join(l10n.archiveCheckSeparator))),
      ));
    } on ProviderOffline {
      messenger.showSnackBar(SnackBar(content: Text(currentL10n().archiveNoConnection)));
    }
  }

  Future<void> _forget(TrackedSeries series) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archiveForgetTitle),
        content: Text(l10n.archiveForgetBody(series.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.archiveCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.archiveForgetConfirm)),
        ],
      ),
    );
    if (sure ?? false) await ref.read(archiveProvider.notifier).forget(series);
  }

}

/// Una serie trovata: la copertina piccola, il titolo e ciò che il sito ne
/// dice. Stesse misure di [KTile], perché le linee di [KGroup] tornino.
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.result,
    required this.referer,
    required this.details,
    this.onTap,
  });

  final SearchResult result;
  final String referer;
  final String details;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: context.tokens.muted.withValues(alpha: .15));
    return KPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 36,
                height: 52,
                child: result.coverUrl == null
                    ? placeholder
                    : Image.network(
                        result.coverUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 108,
                        headers: {'Referer': referer, 'User-Agent': defaultUserAgent},
                        errorBuilder: (_, _, _) => placeholder,
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KagamiType.title(14.5, color: context.colors.onSurface),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(details, style: KagamiType.body(12.5, color: context.tokens.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(LucideIcons.download, size: 18),
          ],
        ),
      ),
    );
  }
}
