/// «Cambia provider»: su quale provider è la serie, e quale delle sue.
///
/// Si sceglie il provider dall'elenco di «Scarica un manga» e la pagina
/// cerca da sé la serie col suo titolo e con quelli alternativi
/// ([sameSeries]): se la trova la dà subito, altrimenti lo dice e lascia
/// cercare con la barra di ricerca di quel provider, perché lì la serie può
/// chiamarsi in un altro modo. Ciò che dà è il link della serie, che la
/// scheda legge e scarica come uno incollato.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/site_switch.dart';
import '../format/malf.dart';
import '../l10n.dart';
import 'archive_screen.dart' show ArchiveResultTile;
import 'archive_series.dart' show archiveStatusLabel;
import 'browser_check_page.dart';
import 'theme.dart';
import 'widgets/kit.dart';

class ProviderSwitchPage extends StatefulWidget {
  const ProviderSwitchPage({required this.entry, required this.titles, super.key});

  final SeriesEntry entry;

  /// Il titolo della serie e quelli alternativi del suo manifest.
  final List<String> titles;

  /// Il link della serie sul provider scelto, o `null` se si torna indietro.
  static Future<String?> open(BuildContext context, SeriesEntry entry, List<String> titles) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => ProviderSwitchPage(entry: entry, titles: titles)),
      );

  @override
  State<ProviderSwitchPage> createState() => _ProviderSwitchPageState();
}

/// A che punto è la ricerca sul provider scelto.
enum _Phase { checking, notFound, searching, results, challenged, failed }

class _ProviderSwitchPageState extends State<ProviderSwitchPage> {
  final TextEditingController _query = TextEditingController();
  Provider? _provider;
  _Phase _phase = _Phase.checking;
  List<SearchResult> _results = const [];
  String? _error;
  Timer? _searchTimer;

  /// Una risposta arrivata per una ricerca già superata si butta.
  int _run = 0;

  /// I provider dietro una verifica del browser si cercano da una WebView
  /// invisibile, come in «Scarica un manga».
  final Map<String, BrowserFetcher> _fetchers = {};

  @override
  void dispose() {
    _query.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  List<Provider> get _choices => [
        for (final provider in providers)
          if (provider.id != widget.entry.provider) provider,
      ];

  void _choose(Provider? provider) {
    _searchTimer?.cancel();
    _run++;
    setState(() {
      _provider = provider;
      _results = const [];
      _error = null;
      _phase = _Phase.checking;
    });
    _query.text = widget.titles.first;
    if (provider != null) unawaited(_check(provider));
  }

  /// Cerca la serie col titolo e, se non c'è, con quelli alternativi: la
  /// prima ricerca che la trova la sceglie. Altrimenti restano i risultati
  /// del titolo, da cui l'utente sceglie o riparte cercando.
  Future<void> _check(Provider provider) async {
    final run = _run;
    List<SearchResult>? first;
    for (final title in widget.titles.take(4)) {
      final List<SearchResult> results;
      try {
        results = await _searchOn(provider, title);
      } on ProviderError catch (error) {
        if (!mounted || run != _run) return;
        _fail(error);
        return;
      }
      if (!mounted || run != _run) return;
      first ??= results;
      final found = sameSeries(results, widget.titles);
      if (found != null) {
        Navigator.of(context).pop(found.url);
        return;
      }
    }
    setState(() {
      _results = first ?? const [];
      _phase = _Phase.notFound;
    });
  }

  void _onQuery(String text) {
    _searchTimer?.cancel();
    setState(() {});
    final provider = _provider;
    if (provider == null || text.trim().length < 2) return;
    _searchTimer = Timer(const Duration(milliseconds: 500), () => _search(provider, text.trim()));
  }

  Future<void> _search(Provider provider, String query) async {
    final run = ++_run;
    setState(() => _phase = _Phase.searching);
    try {
      final results = await _searchOn(provider, query);
      if (!mounted || run != _run) return;
      setState(() {
        _results = results;
        _phase = _Phase.results;
      });
    } on ProviderError catch (error) {
      if (!mounted || run != _run) return;
      _fail(error);
    }
  }

  void _fail(ProviderError error) => setState(() {
        if (error is CloudflareChallenge && _provider!.needsBrowser) {
          _phase = _Phase.challenged;
        } else {
          _phase = _Phase.failed;
          _error = switch (error) {
            CloudflareChallenge() => currentL10n().archiveErrChallenge,
            ProviderOffline() => currentL10n().archiveErrOffline,
            _ => error.message,
          };
        }
      });

  Future<List<SearchResult>> _searchOn(Provider provider, String query) async {
    if (provider.browser case final gate?) {
      var fetcher = _fetchers[provider.id];
      if (fetcher == null) {
        fetcher = BrowserFetcher(ready: gate.searchReady);
        // La WebView deve entrare nell'albero prima di caricare.
        setState(() => _fetchers[provider.id] = fetcher!);
      }
      return provider.search(query, fetcher);
    }
    final http = SiteHttp(provider.allowedHost);
    try {
      return await provider.search(query, http);
    } finally {
      http.close();
    }
  }

  /// La verifica si fa sulla pagina principale: i cookie delle WebView sono
  /// gli stessi in tutta l'app, e quella che cerca li trova già.
  Future<void> _verify(Provider provider) async {
    final gate = provider.browser!;
    final pass = await BrowserCheckPage.open(
      context,
      provider.home,
      gate.hosts,
      ready: gate.searchReady,
      waitingFor: BrowserWaiting.search,
    );
    if (pass == null || !mounted) return;
    _choose(provider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = _provider;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.seriesSwitchProvider)),
      body: Stack(
        children: [
          for (final fetcher in _fetchers.values) Positioned.fill(child: fetcher.view()),
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(
                  l10n.seriesSwitchMessage,
                  style: KagamiType.body(13, height: 1.5, color: context.tokens.muted),
                ),
                const SizedBox(height: 18),
                KSection(widget.entry.title),
                if (provider == null)
                  KGroup(children: [for (final choice in _choices) _providerTile(choice)])
                else ...[
                  KGroup(children: [_providerTile(provider, chosen: true)]),
                  const SizedBox(height: 16),
                  ..._searchArea(provider),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerTile(Provider provider, {bool chosen = false}) => KTile(
        icon: LucideIcons.globe,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(provider.icon, width: 36, height: 36),
        ),
        title: provider.name,
        subtitle: chosen ? context.l10n.seriesSwitchOther : Uri.parse(provider.home).host,
        trailing: Icon(chosen ? LucideIcons.arrowLeftRight : LucideIcons.chevronRight, size: 18),
        onTap: () => _choose(chosen ? null : provider),
      );

  List<Widget> _searchArea(Provider provider) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    if (_phase == _Phase.checking) {
      return [
        Text(
          l10n.seriesSwitchSearching(widget.titles.first, provider.name),
          style: KagamiType.body(13, color: muted),
        ),
        const SizedBox(height: 10),
        const LinearProgressIndicator(minHeight: 3),
      ];
    }
    return [
      if (_phase == _Phase.notFound) ...[
        KCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.searchX, size: 18, color: context.tokens.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.seriesSwitchNotFound(widget.titles.first, provider.name),
                  style: KagamiType.body(13, height: 1.45, color: context.colors.onSurface),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      TextField(
        controller: _query,
        textInputAction: TextInputAction.search,
        onChanged: _onQuery,
        onSubmitted: (text) {
          _searchTimer?.cancel();
          if (text.trim().length >= 2) _search(provider, text.trim());
        },
        decoration: InputDecoration(
          hintText: l10n.seriesSwitchSearchHint(provider.name),
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
      const SizedBox(height: 14),
      switch (_phase) {
        _Phase.searching || _Phase.checking => const LinearProgressIndicator(minHeight: 3),
        _Phase.challenged => KGroup(
            children: [
              KTile(
                icon: LucideIcons.shieldCheck,
                title: l10n.archiveVerifySite(provider.name),
                subtitle: l10n.archiveVerifySiteHint,
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => _verify(provider),
              ),
            ],
          ),
        _Phase.failed => Text(
            _error ?? '',
            style: KagamiType.body(12.5, height: 1.45, color: context.tokens.danger),
          ),
        _ when _results.isEmpty => Text(
            l10n.archiveNoResults(provider.name),
            style: KagamiType.body(12.5, color: muted),
          ),
        _ => KGroup(
            children: [
              for (final result in _results)
                ArchiveResultTile(
                  result: result,
                  referer: provider.home,
                  details: [
                    if (result.latestChapter case final number?) l10n.archiveLatestChapter(number),
                    if (result.releaseStatus != 'unknown') archiveStatusLabel(l10n, result.releaseStatus),
                  ].join(' · '),
                  onTap: () => Navigator.of(context).pop(result.url),
                ),
            ],
          ),
      },
    ];
  }
}
