/// «Scarica un manga»: una ricerca o un link, cosa scaricarne e dove, e la coda.
///
/// È il pannello MangaArchive di Cobalt portato nell'app, con le stesse
/// scelte — la serie intera, dal capitolo scelto in poi o solo alcuni
/// capitoli, la pausa fra le richieste, l'orario del controllo delle serie
/// in corso — e due in più: scaricare «man mano», pochi capitoli davanti a
/// quello che si legge, e la destinazione, che qui può essere la cartella di
/// Drive della libreria, o un Kagami Server collegato. La scelta per una
/// serie sta nella sua pagina (`archive_series.dart`), il percorso dal link
/// alla coda in `archive_flow.dart`, che usano anche altri. Il lavoro vero lo fa
/// `packages/kagami_archive/`, in un lavoro in primo piano che continua a
/// schermo spento, o sul server.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format/malf.dart';
import '../providers.dart';
import 'archive_flow.dart';
import 'archive_import.dart';
import 'archive_manual.dart';
import 'archive_series.dart';
import 'archive_server.dart';
import 'browser_check_page.dart';
import '../l10n.dart';
import 'sync_screen.dart' show clockOf;
import 'theme.dart';
import 'widgets/kit.dart';

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

/// Quale stato della serie si vuole vedere fra i risultati.
enum _StatusFilter {
  /// In corso o in pausa: chi cerca qualcosa da seguire non vuole le concluse.
  ongoing,
  completed,
}

/// I filtri della ricerca. Si ricordano fra le impostazioni, che vanno in
/// backup e account: chi non usa un sito non vuole rispegnerlo a ogni
/// apertura.
class _SearchFilters {
  const _SearchFilters({this.off = const {}, this.status, this.notInLibrary = false});

  static const String offKey = 'archive.searchOff';
  static const String statusKey = 'archive.searchStatus';
  static const String notInLibraryKey = 'archive.searchNotInLibrary';

  /// I siti spenti, non quelli accesi: un sito nuovo nasce acceso.
  final Set<String> off;
  final _StatusFilter? status;
  final bool notInLibrary;

  bool searches(Provider provider) => !off.contains(provider.id);

  bool passes(SearchResult result, {required bool owned}) {
    final ok = switch (status) {
      null => true,
      _StatusFilter.ongoing => result.releaseStatus == 'ongoing' || result.releaseStatus == 'hiatus',
      _StatusFilter.completed => result.releaseStatus == 'completed',
    };
    return ok && !(notInLibrary && owned);
  }

  _SearchFilters copyWith({Set<String>? off, _StatusFilter? Function()? status, bool? notInLibrary}) => _SearchFilters(
        off: off ?? this.off,
        status: status == null ? this.status : status(),
        notInLibrary: notInLibrary ?? this.notInLibrary,
      );
}

/// Il titolo come lo si confronta: i risultati non portano l'id della serie
/// (MangaK lo dà solo nella pagina), quindi «già in libreria» è lo stesso
/// sito e lo stesso titolo, a meno di maiuscole e punteggiatura.
String _titleKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

String _destinationName(AppLocalizations l10n, ArchiveDestination destination) => switch (destination) {
      ArchiveDestination.drive => l10n.archiveWhereDrive,
      ArchiveDestination.driveAndPhone => l10n.archiveWhereDriveAndPhone,
      ArchiveDestination.phone => l10n.archiveWherePhone,
    };

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({this.link, this.importText, super.key});

  /// Un link condiviso con l'app: si apre già incollato e verificato.
  final String? link;

  /// Il testo condiviso con più link: si apre l'import, già compilato.
  final String? importText;

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

  InspectedSeries? _inspected;
  bool _busy = false;
  String? _error;

  /// Il link che nessun sito riconosce: si offre la scheda manuale.
  String? _unsupported;

  ArchiveWhere? _destination;
  int _delayMs = 200;

  _SearchFilters _filters = const _SearchFilters();

  @override
  void initState() {
    super.initState();
    unawaited(_loadFilters());
    final link = widget.link;
    final importText = widget.importText;
    if (link != null || importText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (importText != null) {
          unawaited(ArchiveImportPage.open(context, text: importText));
        } else {
          _link.text = link!;
          unawaited(_verify());
        }
      });
    }
  }

  Future<void> _loadFilters() async {
    final user = ref.read(userRepositoryProvider);
    final off = await user.readSetting(_SearchFilters.offKey) ?? '';
    final status = await user.readSetting(_SearchFilters.statusKey) ?? '';
    final notInLibrary = await user.readSetting(_SearchFilters.notInLibraryKey);
    if (!mounted) return;
    final known = {for (final provider in providers) provider.id};
    final stored = off.split(',').where(known.contains).toSet();
    setState(() => _filters = _SearchFilters(
          // Spenti tutti, per un sito che nel frattempo ha cambiato id, non
          // si cercherebbe più niente.
          off: stored.length == known.length ? const {} : stored,
          status: _StatusFilter.values.where((value) => value.name == status).firstOrNull,
          notInLibrary: notInLibrary == 'true',
        ));
  }

  Future<void> _saveFilters() async {
    final user = ref.read(userRepositoryProvider);
    await user.writeSetting(_SearchFilters.offKey, (_filters.off.toList()..sort()).join(','));
    await user.writeSetting(_SearchFilters.statusKey, _filters.status?.name ?? '');
    await user.writeSetting(_SearchFilters.notInLibraryKey, '${_filters.notInLibrary}');
  }

  /// Un sito spento non si interroga affatto: oltre al rumore, sono le sue
  /// richieste (e per ManhwaRead la WebView) che si risparmiano.
  void _toggleSite(Provider provider) {
    final off = {..._filters.off};
    final enabling = off.remove(provider.id);
    if (!enabling) {
      // Almeno un sito resta acceso, o la ricerca non cercherebbe niente.
      if (off.length == providers.length - 1) return;
      off.add(provider.id);
    }
    final query = _query.text.trim();
    setState(() {
      _filters = _filters.copyWith(off: off);
      if (enabling && query.length >= 2) {
        _found[provider.id] = const _Found.loading();
      } else {
        _found.remove(provider.id);
      }
    });
    if (enabling && query.length >= 2) unawaited(_searchOn(provider, query, _searchRun));
    unawaited(_saveFilters());
  }

  void _setFilters(_SearchFilters filters) {
    setState(() => _filters = filters);
    unawaited(_saveFilters());
  }

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
    final searched = providers.where(_filters.searches).toList();
    setState(() {
      for (final provider in searched) {
        _found[provider.id] = const _Found.loading();
      }
    });
    for (final provider in searched) {
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
      _unsupported = null;
      _inspected = null;
    });
    try {
      final inspected = await inspectArchiveLink(context, url);
      if (!mounted) return;
      setState(() => _inspected = inspected);
      unawaited(_choose(inspected));
    } on UnsupportedLink {
      if (mounted) setState(() => _unsupported = url);
    } on ProviderError catch (error) {
      if (mounted) setState(() => _error = archiveErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Il modulo della scheda manuale; se dentro si incolla un link di un
  /// sito supportato e si sceglie il percorso normale, lo si legge da qui.
  Future<void> _manual({String? link}) async {
    final normal = await ManualCardPage.open(context, link: link);
    if (!mounted) return;
    setState(() => _unsupported = null);
    if (normal == null) return;
    _link.text = normal;
    await _verify();
  }

  /// Dopo il link, la pagina in cui si sceglie cosa scaricare e dove.
  /// Chiudendola senza scegliere la serie resta qui sotto, da riaprire.
  Future<void> _choose(InspectedSeries inspected) async {
    final choice = await chooseArchive(context, ref, inspected, where: _destination, delayMs: _delayMs);
    if (choice == null || !mounted || _inspected != inspected) return;
    setState(() {
      _destination = choice.where;
      _delayMs = choice.delayMs;
    });
    final queued = await enqueueArchive(context, ref, inspected, choice);
    if (!queued || !mounted) return;
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
                const SizedBox(height: 10),
                _filterBar(),
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
                const SizedBox(height: 8),
                KGhostButton(
                  label: l10n.archiveManualAction,
                  icon: LucideIcons.bookmarkPlus,
                  expand: true,
                  onPressed: _busy ? null : _manual,
                ),
                const SizedBox(height: 8),
                KGhostButton(
                  label: l10n.archiveImportAction,
                  icon: LucideIcons.listPlus,
                  expand: true,
                  onPressed: _busy ? null : () => ArchiveImportPage.open(context),
                ),
                if (_unsupported != null) ...[
                  const SizedBox(height: 12),
                  KCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.archiveManualUnsupported,
                          style: KagamiType.body(13, height: 1.45, color: context.tokens.warning),
                        ),
                        const SizedBox(height: 10),
                        KButton(
                          label: l10n.archiveManualUnsupportedAction,
                          icon: LucideIcons.bookmarkPlus,
                          expand: true,
                          onPressed: () => _manual(link: _unsupported),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
                ],
                if (inspected != null) ..._pending(inspected),
                // Prima ciò che si comanda — la coda, il controllo delle serie,
                // il server —, poi ciò che è già successo, poi i siti.
                ..._queue(view),
                ..._tracked(view),
                ServerSection(onRetry: _busy ? null : _retry),
                ArchiveRecentStrip(
                  title: l10n.archiveRecent,
                  history: view.history,
                  onClear: ref.read(archiveProvider.notifier).clearHistory,
                  onRetry: _busy ? null : _retry,
                ),
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
  List<Widget> _pending(InspectedSeries inspected) {
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

  /// Siti, stato e libreria in una fila sola sotto il campo: si cambiano
  /// mentre si guarda il risultato, senza aprire niente.
  Widget _filterBar() {
    final l10n = context.l10n;
    final filters = _filters;
    _StatusFilter? Function() toggle(_StatusFilter value) => () => filters.status == value ? null : value;
    return KChipBar(
      children: [
        for (final provider in providers)
          KChip(
            label: provider.name,
            active: filters.searches(provider),
            onTap: () => _toggleSite(provider),
          ),
        Center(child: Container(width: 1, height: 20, color: context.tokens.line)),
        KChip(
          label: l10n.archiveFilterOngoing,
          active: filters.status == _StatusFilter.ongoing,
          onTap: () => _setFilters(filters.copyWith(status: toggle(_StatusFilter.ongoing))),
        ),
        KChip(
          label: l10n.archiveFilterCompleted,
          active: filters.status == _StatusFilter.completed,
          onTap: () => _setFilters(filters.copyWith(status: toggle(_StatusFilter.completed))),
        ),
        KChip(
          label: l10n.archiveFilterNotInLibrary,
          icon: LucideIcons.bookX,
          active: filters.notInLibrary,
          onTap: () => _setFilters(filters.copyWith(notInLibrary: !filters.notInLibrary)),
        ),
      ],
    );
  }

  List<Widget> _results() {
    final owned = <String, Set<String>>{};
    for (final entry in ref.watch(libraryIndexProvider).value?.series ?? const <SeriesEntry>[]) {
      owned.putIfAbsent(entry.provider, () => {}).add(_titleKey(entry.title));
    }
    bool inLibrary(SearchResult result) => owned[result.provider]?.contains(_titleKey(result.title)) ?? false;
    return [
      for (final provider in providers)
        if (_found[provider.id] case final found? when _filters.searches(provider)) ...[
          const SizedBox(height: 18),
          KSection(provider.name),
          _siteResults(provider, found, inLibrary),
        ],
    ];
  }

  /// Cosa ha dato un sito, filtrato. Se i filtri nascondono tutto lo si
  /// dice, altrimenti sembrerebbe che il sito non abbia la serie.
  Widget _siteResults(Provider provider, _Found found, bool Function(SearchResult) inLibrary) {
    final muted = context.tokens.muted;
    final l10n = context.l10n;
    if (found.results case final results?) {
      if (results.isEmpty) {
        return Text(l10n.archiveNoResults(provider.name), style: KagamiType.body(12.5, color: muted));
      }
      final shown = [
        for (final result in results)
          if (_filters.passes(result, owned: inLibrary(result))) result,
      ];
      if (shown.isEmpty) {
        return Text(l10n.archiveResultsFiltered(results.length), style: KagamiType.body(12.5, color: muted));
      }
      return KGroup(
        children: [
          for (final result in shown)
            _ResultTile(
              result: result,
              referer: provider.home,
              inLibrary: inLibrary(result),
              details: [
                if (inLibrary(result)) l10n.archiveInLibrary,
                if (result.chapters case final count?) l10n.archiveChaptersCount(count),
                if (result.releaseStatus != 'unknown') archiveStatusLabel(l10n, result.releaseStatus),
              ].join(' · '),
              onTap: _busy ? null : () => _pick(result),
            ),
        ],
      );
    }
    if (found.challenged) {
      return KGroup(
        children: [
          KTile(
            icon: LucideIcons.shieldCheck,
            title: l10n.archiveVerifySite(provider.name),
            subtitle: l10n.archiveVerifySiteHint,
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _verifySearch(provider),
          ),
        ],
      );
    }
    if (found.error case final error?) {
      return Text(error, style: KagamiType.body(12.5, height: 1.45, color: context.tokens.danger));
    }
    return const LinearProgressIndicator(minHeight: 3);
  }

  List<Widget> _queue(ArchiveView view) {
    final notifier = ref.read(archiveProvider.notifier);
    final l10n = context.l10n;
    final status = view.status;
    final current = view.current;
    final waiting = [for (final job in view.jobs) if (job.id != current?.id) job];
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
                card: current.cardOnly,
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
                icon: job.cardOnly
                    ? LucideIcons.bookmark
                    : job.ahead != null
                        ? LucideIcons.sparkles
                        : job.automatic
                            ? LucideIcons.refreshCw
                            : LucideIcons.clock,
                title: job.title,
                subtitle: job.cardOnly
                    ? job.automatic
                        ? l10n.archiveJobCardUpdate(_destinationName(l10n, job.target.destination))
                        : l10n.archiveJobCard(_destinationName(l10n, job.target.destination))
                    : job.ahead != null
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
              onTap: () => openInBrowser(context, provider.home),
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
            onTap: view.tracked.isEmpty ? null : _checkNow,
          ),
        ],
      ),
      const SizedBox(height: 12),
      ArchiveFollowedTile(
        count: view.tracked.length,
        problems: view.tracked.where((series) => series.problem != null).length,
        tiles: _followedTiles,
      ),
    ];
  }

  /// Le serie seguite dal telefono, per il foglio.
  List<Widget> _followedTiles(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return [
      for (final series in ref.watch(archiveProvider).tracked)
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
      // Le schede stanno anche fra le serie in coda, ma per loro scende solo
      // l'elenco dei capitoli: dirle «capitoli nuovi» prometterebbe tavole.
      final chapters = [for (final title in report.queued) if (!report.cards.contains(title)) title];
      final parts = [
        if (chapters.isNotEmpty) l10n.archiveCheckQueued(chapters.join(', ')),
        if (report.cards.isNotEmpty) l10n.archiveCheckCards(report.cards.join(', ')),
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
    this.inLibrary = false,
    this.onTap,
  });

  final SearchResult result;
  final String referer;

  /// Si può riscaricare lo stesso — porta solo ciò che manca —, ma deve
  /// vedersi che c'è già.
  final bool inLibrary;
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
            Icon(inLibrary ? LucideIcons.bookCheck : LucideIcons.download, size: 18),
          ],
        ),
      ),
    );
  }
}
