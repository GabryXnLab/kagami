/// «Scarica un manga»: una ricerca o un link, cosa scaricarne e dove, e la coda.
///
/// È il pannello MangaArchive di Cobalt portato nell'app, con le stesse
/// scelte — la serie intera, dal capitolo scelto in poi o solo alcuni
/// capitoli, la pausa fra le richieste, l'orario del controllo delle serie
/// in corso — e una in più: la destinazione, che qui può essere la cartella
/// di Drive della libreria, o un Kagami Server collegato. Il lavoro vero lo
/// fa `packages/kagami_archive/`, in un lavoro in primo piano che continua a
/// schermo spento, o sul server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/names.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/providers/manhwaread.dart';
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../data/cloud.dart';
import '../data/drive.dart';
import '../providers.dart';
import 'archive_server.dart';
import 'browser_check_page.dart';
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

enum _Mode { all, from, pick }

/// Dove va una serie: una delle destinazioni del telefono, o il server.
enum _Where {
  server,
  drive,
  driveAndPhone,
  phone;

  /// La destinazione della coda del telefono; `null` per il server, che ha
  /// la sua.
  ArchiveDestination? get local => switch (this) {
        server => null,
        drive => ArchiveDestination.drive,
        driveAndPhone => ArchiveDestination.driveAndPhone,
        phone => ArchiveDestination.phone,
      };

  String get label => local?.label ?? 'Server';

  IconData get icon => switch (this) {
        server => LucideIcons.server,
        drive => LucideIcons.cloud,
        driveAndPhone => LucideIcons.cloudDownload,
        phone => LucideIcons.smartphone,
      };
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

const List<String> _manhwaReadHosts = ['manhwaread.com', 'www.manhwaread.com'];

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final TextEditingController _link = TextEditingController();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _query = TextEditingController();

  Timer? _searchTimer;
  int _searchRun = 0;
  final Map<String, _Found> _found = {};

  /// ManhwaRead si cerca da una WebView invisibile: a `SiteHttp`
  /// Cloudflare non risponde nemmeno dopo la verifica.
  BrowserFetcher? _fetcher;
  static const String _searchReady = "!!document.getElementById('inputQuickSearch')";

  _Inspected? _inspected;
  bool _busy = false;
  String? _error;

  _Mode _mode = _Mode.all;
  String? _from;
  final Set<String> _picked = {};
  _Where? _destination;
  int _delayMs = 200;

  static const List<int> _delays = [0, 200, 500, 1000, 2000];

  @override
  void dispose() {
    _link.dispose();
    _number.dispose();
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
    if (provider is ManhwaRead) {
      site = null;
      if (_fetcher == null) {
        // La WebView deve entrare nell'albero prima di caricare.
        setState(() => _fetcher = BrowserFetcher(ready: _searchReady));
      }
      http = _fetcher!;
    } else {
      http = site = SiteHttp(provider.allowedHost);
    }
    _Found found;
    try {
      found = _Found.results(await provider.search(query, http));
    } on CloudflareChallenge {
      found = provider is ManhwaRead
          ? const _Found.challenged()
          : const _Found.error('Il sito chiede una verifica che da qui non si può fare.');
    } on ProviderOffline {
      found = const _Found.error('Nessuna connessione: il sito non risponde.');
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
    final pass = await BrowserCheckPage.open(
      context,
      provider.home,
      _manhwaReadHosts,
      ready: _searchReady,
      waitingFor: 'la ricerca del sito',
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
        if (provider is! ManhwaRead || !mounted) rethrow;
        final canonical = provider.canonical(url);
        pass = await BrowserCheckPage.open(
          context,
          canonical,
          _manhwaReadHosts,
        );
        if (pass == null) {
          setState(() => _error = 'La verifica del sito non è stata completata.');
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
      setState(() {
        _inspected = inspected;
        _mode = _Mode.all;
        _from = null;
        _picked.clear();
        _number.clear();
      });
      unawaited(_ask(inspected));
    } on ProviderOffline {
      setState(() => _error = 'Nessuna connessione: il sito non risponde.');
    } on ProviderError catch (error) {
      setState(() => _error = error.message);
    } finally {
      http?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// La domanda che segue il link, come nel bot di Telegram e nella GUI di
  /// Cobalt: tutta la serie o da quale capitolo. Chiudendola senza scegliere
  /// resta la scheda sotto, con la scelta dei capitoli uno per uno.
  Future<void> _ask(_Inspected inspected) async {
    final destinations = _destinations();
    final choice = await showKagamiSheet<_Start>(
      context,
      title: inspected.series.title,
      scrollable: true,
      builder: (context) => _StartSheet(
        chapters: inspected.series.chapters,
        destinations: destinations,
        destination: destinations.contains(_destination) ? _destination! : destinations.first,
      ),
    );
    if (choice == null || !mounted || _inspected != inspected) return;
    setState(() {
      _mode = choice.from == null ? _Mode.all : _Mode.from;
      _from = choice.from;
      _number.clear();
      _destination = choice.destination;
    });
    await _download();
  }

  /// Il server per primo, se c'è ed è pronto: chi l'ha collegato vuole che
  /// scarichi lui.
  List<_Where> _destinations() {
    // La cartella può arrivare da un backup anche in una build senza
    // Firebase, dove Drive non si può aprire.
    final drive =
        cloudAvailable && ref.read(driveFolderProvider).value != null;
    return [
      if (ref.read(remoteArchiveProvider).ready) _Where.server,
      ...drive ? const [_Where.drive, _Where.driveAndPhone] : const [_Where.phone],
    ];
  }

  String? _start() => switch (_mode) {
        _Mode.from => _number.text.trim().isNotEmpty ? _number.text.trim() : _from,
        _ => null,
      };

  bool get _ready => switch (_mode) {
        _Mode.all => true,
        _Mode.from => (_start() ?? '').isNotEmpty,
        _Mode.pick => _picked.isNotEmpty,
      };

  Future<void> _download() async {
    final inspected = _inspected;
    if (inspected == null || !_ready) return;
    final messenger = ScaffoldMessenger.of(context);
    final where = _destination ?? _destinations().first;
    final destination = where.local;
    if (destination == null) return _sendToServer(inspected);
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
          start: _start(),
          ids: _mode == _Mode.pick ? {..._picked} : null,
          delayMs: _delayMs,
          snapshot: snapshot,
          userAgent: pass?.userAgent,
          cookies: pass?.cookies ?? const {},
        ));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('«${inspected.series.title}» è in coda. Continua anche a schermo spento.'),
    ));
    setState(() {
      _inspected = null;
      _link.clear();
    });
  }

  /// Al server va il link con le stesse scelte; la pagina della serie solo se
  /// è servita la verifica del browser, perché il server non ne ha uno.
  Future<void> _sendToServer(_Inspected inspected) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = ref.read(remoteArchiveProvider).info?.name ?? 'server';
    try {
      await ref.read(remoteArchiveProvider.notifier).enqueue(
            url: inspected.series.url,
            title: inspected.series.title,
            start: _start(),
            ids: _mode == _Mode.pick ? {..._picked} : null,
            delayMs: _delayMs,
            snapshot: inspected.pass == null ? null : utf8.decode(inspected.pass!.html, allowMalformed: true),
          );
    } on ServerException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('«${inspected.series.title}» è in coda su «$name». Il telefono può anche spegnersi.'),
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
    final inspected = _inspected;
    return Scaffold(
      appBar: AppBar(title: const Text('Scarica un manga')),
      body: Stack(
        children: [
          if (_fetcher case final fetcher?) Positioned.fill(child: fetcher.view()),
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(
                  'Cerca un titolo sui siti supportati, o incolla il link di una '
                  'serie: Kagami la scarica dal sito, con metadati, copertina e '
                  'l\'elenco completo dei capitoli, nella libreria.',
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
                    hintText: 'Cerca un manga per titolo',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Cancella',
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
                      tooltip: 'Incolla',
                      icon: const Icon(LucideIcons.clipboardPaste, size: 18),
                      onPressed: _busy ? null : _paste,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                KButton(
                  label: _busy ? 'Lettura della serie…' : 'Verifica serie',
                  icon: LucideIcons.search,
                  expand: true,
                  onPressed: _busy ? null : _verify,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
                ],
                if (inspected != null) ..._choices(inspected),
                ..._queue(view),
                const ServerSection(),
                ..._tracked(view),
                ..._sites(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _choices(_Inspected inspected) {
    final series = inspected.series;
    final metadata = inspected.metadata;
    final muted = context.tokens.muted;
    final known = ref.watch(seriesEntryProvider(series.key));
    final destinations = _destinations();
    final destination = destinations.contains(_destination) ? _destination! : destinations.first;
    final authors = (metadata['authors'] as List).cast<String>();
    final tags = [...(metadata['genres'] as List).cast<String>(), ...(metadata['tags'] as List).cast<String>()];
    return [
      const SizedBox(height: 24),
      KCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 104,
                child: series.coverUrl == null
                    ? ColoredBox(color: context.tokens.muted.withValues(alpha: .15))
                    : Image.network(
                        series.coverUrl!,
                        fit: BoxFit.cover,
                        headers: {'Referer': series.url, 'User-Agent': defaultUserAgent},
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: context.tokens.muted.withValues(alpha: .15)),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(series.title, style: KagamiType.body(16, weight: 700, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(
                    '${providerById(series.provider)?.name ?? series.provider} · '
                    '${series.chapters.length} capitoli · ${_status(metadata['releaseStatus'])}',
                    style: KagamiType.body(12.5, color: muted),
                  ),
                  if (authors.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(authors.take(3).join(', '), style: KagamiType.body(12.5, color: muted)),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [for (final tag in tags.take(6)) KTag(label: tag, dense: true)],
                    ),
                  ],
                  if (known != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Già in libreria: ${known.archivedChapterCount} di '
                      '${known.chapterCount} capitoli. Quelli che ci sono si saltano.',
                      style: KagamiType.body(12.5, weight: 600, color: context.colors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const KSection('Cosa scaricare'),
      KSegmented(
        options: const ['Tutta', 'Dal capitolo', 'Scelti'],
        icons: const [LucideIcons.library, LucideIcons.skipForward, LucideIcons.listChecks],
        index: _mode.index,
        onChanged: (index) => setState(() => _mode = _Mode.values[index]),
      ),
      const SizedBox(height: 10),
      Text(
        switch (_mode) {
          _Mode.all => 'Tutti i capitoli. Rifarlo più avanti porta solo quelli '
              'nuovi o rovinati.',
          _Mode.from => 'Dal capitolo scelto in poi: i precedenti restano '
              'nell\'elenco della serie, segnati come non scaricati.',
          _Mode.pick => 'Solo i capitoli toccati. Gli altri restano '
              'nell\'elenco, non scaricati.',
        },
        style: KagamiType.body(12.5, height: 1.45, color: muted),
      ),
      if (_mode == _Mode.from) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _number,
          keyboardType: TextInputType.text,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Numero del capitolo, come sul sito',
            prefixIcon: Icon(LucideIcons.hash, size: 18),
          ),
        ),
      ],
      if (_mode != _Mode.all) ...[
        const SizedBox(height: 12),
        _ChapterGrid(
          chapters: series.chapters,
          selected: _mode == _Mode.from ? {?_from} : _picked,
          onTap: (chapter) => setState(() {
            if (_mode == _Mode.from) {
              _from = chapter.id;
              _number.clear();
            } else if (!_picked.remove(chapter.id)) {
              _picked.add(chapter.id);
            }
          }),
        ),
        if (_mode == _Mode.pick)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text('${_picked.length} scelti', style: KagamiType.body(12.5, color: muted)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _picked
                    ..clear()
                    ..addAll(series.chapters.map((c) => c.id))),
                  child: const Text('Tutti'),
                ),
                TextButton(
                  onPressed: () => setState(_picked.clear),
                  child: const Text('Nessuno'),
                ),
              ],
            ),
          ),
      ],
      const SizedBox(height: 22),
      const KSection('Dove'),
      if (destinations.length > 1)
        KSegmented(
          options: [for (final value in destinations) value.label],
          icons: [for (final value in destinations) value.icon],
          index: destinations.indexOf(destination),
          onChanged: (index) => setState(() => _destination = destinations[index]),
        ),
      const SizedBox(height: 10),
      Text(
        switch (destination) {
          _Where.server => _serverWhere(),
          _Where.drive => 'Nella cartella di Drive della libreria. Le '
              'tavole passano dal telefono e se ne vanno appena Drive le ha: '
              'si leggono in streaming, o si scaricano dopo.',
          _Where.driveAndPhone => 'Nella cartella di Drive della '
              'libreria, e i capitoli restano anche sul telefono per leggerli '
              'senza rete.',
          _Where.phone => 'Sul telefono, nella cartella dei manga o '
              'nello spazio dell\'app. Collegando Drive si può scaricare '
              'direttamente là.',
        },
        style: KagamiType.body(12.5, height: 1.45, color: muted),
      ),
      const SizedBox(height: 22),
      const KSection('Pausa fra le richieste'),
      KSegmented(
        options: [for (final ms in _delays) ms == 0 ? 'Niente' : '${ms / 1000} s'],
        index: math.max(0, _delays.indexOf(_delayMs)),
        onChanged: (index) => setState(() => _delayMs = _delays[index]),
      ),
      const SizedBox(height: 10),
      Text(
        'I siti non amano chi scarica a raffica: una pausa breve evita di '
        'farsi bloccare.',
        style: KagamiType.body(12.5, height: 1.45, color: muted),
      ),
      const SizedBox(height: 20),
      KButton(
        label: switch (_mode) {
          _Mode.all => 'Scarica tutta la serie',
          _Mode.from => 'Scarica dal capitolo scelto',
          _Mode.pick => 'Scarica ${_picked.length} capitoli',
        },
        icon: LucideIcons.download,
        expand: true,
        onPressed: _ready ? _download : null,
      ),
    ];
  }

  String _serverWhere() {
    final info = ref.read(remoteArchiveProvider).info;
    final folder = ref.read(driveFolderProvider).value;
    final other = folder != null && info?.folderId != folder.id;
    return 'Lo scarica «${info?.name}» e lo carica in «${info?.folderName ?? info?.folderId}» '
        'su Drive, anche a telefono spento. Le serie in corso le segue il server.'
        '${other ? ' Attenzione: non è la cartella che legge l\'app.' : ''}';
  }

  List<Widget> _results() {
    final muted = context.tokens.muted;
    return [
      for (final provider in providers)
        if (_found[provider.id] case final found?) ...[
          const SizedBox(height: 18),
          KSection(provider.name),
          if (found.results case final results?)
            results.isEmpty
                ? Text('Nessun risultato su ${provider.name}.',
                    style: KagamiType.body(12.5, color: muted))
                : KGroup(
                    children: [
                      for (final result in results)
                        _ResultTile(
                          result: result,
                          referer: provider.home,
                          details: [
                            if (result.chapters case final count?) count == 1 ? '1 capitolo' : '$count capitoli',
                            if (result.releaseStatus != 'unknown') _status(result.releaseStatus),
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
                  title: 'Verifica ${provider.name}',
                  subtitle: 'Il sito vuole sapere che sei una persona: toccando '
                      'si apre la verifica, poi si cerca anche lì',
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

  static String _status(Object? value) => switch (value) {
        'ongoing' => 'in corso',
        'completed' => 'conclusa',
        'hiatus' => 'in pausa',
        'cancelled' => 'interrotta',
        _ => 'stato ignoto',
      };

  List<Widget> _queue(ArchiveView view) {
    final notifier = ref.read(archiveProvider.notifier);
    final status = view.status;
    final current = view.current;
    final waiting = [for (final job in view.jobs) if (job.id != current?.id) job];
    if (view.jobs.isEmpty && view.history.isEmpty) return const [];
    return [
      const SizedBox(height: 30),
      KSection(
        'Download',
        trailing: view.history.isEmpty
            ? null
            : TextButton(onPressed: notifier.clearHistory, child: const Text('Pulisci')),
      ),
      KGroup(
        children: [
          if (current != null)
            ArchiveProgressRow(
              title: current.title,
              status: status,
              onCancel: () => notifier.remove(current),
            ),
          if (current == null && view.jobs.isNotEmpty)
            KTile(
              icon: LucideIcons.play,
              title: 'Coda ferma',
              subtitle: status.state == ArchiveState.waiting
                  ? status.message
                  : 'Riparte da sola; toccando la fai partire adesso',
              onTap: notifier.resume,
            ),
          for (final job in waiting)
            KTile(
              icon: job.automatic ? LucideIcons.refreshCw : LucideIcons.clock,
              title: job.title,
              subtitle: '${job.automatic ? 'Capitoli nuovi' : 'In coda'} · ${job.target.destination.label}',
              trailing: IconButton(
                tooltip: 'Togli dalla coda',
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () => notifier.remove(job),
              ),
            ),
          for (final outcome in view.history.take(8))
            KTile(
              icon: outcome.ok ? LucideIcons.circleCheck : LucideIcons.triangleAlert,
              tint: outcome.ok ? null : context.tokens.danger,
              title: outcome.title,
              subtitle: '${archiveWhen(outcome.finishedAt)} · ${outcome.message}',
            ),
        ],
      ),
    ];
  }

  /// I siti da cui si può scaricare, col loro indirizzo: il link giusto è
  /// quello della pagina di una serie su uno di questi.
  List<Widget> _sites() {
    final muted = context.tokens.muted;
    return [
      const SizedBox(height: 30),
      const KSection('Siti supportati'),
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
                'Altri siti sono in arrivo: il supporto per nuovi provider '
                'arriverà con i prossimi aggiornamenti.',
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
    messenger.showSnackBar(SnackBar(content: Text('$url copiato negli appunti.')));
  }

  List<Widget> _tracked(ArchiveView view) {
    final notifier = ref.read(archiveProvider.notifier);
    final muted = context.tokens.muted;
    final minutes = view.check.minutes;
    return [
      const SizedBox(height: 30),
      const KSection('Serie in corso'),
      Text(
        'Le serie in corso scaricate da qui si ricontrollano: arrivano solo i '
        'capitoli nuovi, nella stessa destinazione. Quelle del server le segue '
        'il server.',
        style: KagamiType.body(12.5, height: 1.45, color: muted),
      ),
      const SizedBox(height: 12),
      KGroup(
        children: [
          KTile(
            icon: LucideIcons.clock,
            title: 'Controllo ogni giorno',
            subtitle: minutes == null ? 'Solo a mano' : 'Alle ${clockOf(minutes)}, anche ad app chiusa',
            onTap: () => _toggleCheck(view.check),
            trailing: Switch(value: minutes != null, onChanged: (_) => _toggleCheck(view.check)),
          ),
          if (minutes != null) ...[
            KTile(
              icon: LucideIcons.alarmClock,
              title: 'Ora',
              subtitle: clockOf(minutes),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => _chooseTime(view.check),
            ),
            KTile(
              icon: LucideIcons.wifi,
              title: 'Solo con Wi-Fi',
              subtitle: view.check.wifiOnly
                  ? 'Aspetta una rete che non si paga a consumo'
                  : 'Anche con i dati mobili',
              onTap: () => notifier.setCheck(CheckSettings(minutes: minutes, wifiOnly: !view.check.wifiOnly)),
              trailing: Switch(
                value: view.check.wifiOnly,
                onChanged: (value) => notifier.setCheck(CheckSettings(minutes: minutes, wifiOnly: value)),
              ),
            ),
          ],
          KTile(
            icon: LucideIcons.refreshCw,
            title: 'Controlla adesso',
            subtitle: view.tracked.isEmpty
                ? 'Nessuna serie da seguire, per ora'
                : '${view.tracked.length} serie da seguire',
            onTap: view.tracked.isEmpty ? null : _checkNow,
          ),
          for (final series in view.tracked)
            KTile(
              icon: series.problem == null ? LucideIcons.bookOpen : LucideIcons.triangleAlert,
              tint: series.problem == null ? null : context.tokens.danger,
              title: series.title,
              subtitle: series.problem ??
                  '${series.chapters.length} capitoli noti · ${series.target.destination.label}'
                      '${series.checkedAt == null ? '' : ' · controllata ${archiveWhen(series.checkedAt!)}'}',
              trailing: IconButton(
                tooltip: 'Smetti di seguirla',
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
      helpText: 'Ora del controllo',
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
      final parts = [
        if (report.queued.isNotEmpty) 'capitoli nuovi per ${report.queued.join(', ')}',
        if (report.removed.isNotEmpty) '${report.removed.join(', ')} ora conclusa',
        if (report.failed.isNotEmpty) '${report.failed.length} non raggiunte',
      ];
      messenger.showSnackBar(SnackBar(
        content: Text(parts.isEmpty ? 'Nessun capitolo nuovo.' : '${parts.join('; ')}.'),
      ));
    } on ProviderOffline {
      messenger.showSnackBar(const SnackBar(content: Text('Nessuna connessione.')));
    }
  }

  Future<void> _forget(TrackedSeries series) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smettere di seguirla?'),
        content: Text('I capitoli nuovi di «${series.title}» non arriveranno più da soli. '
            'Quelli già scaricati restano.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Smetti')),
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

/// I capitoli da toccare: in ordine di lettura, col numero del sito.
class _ChapterGrid extends StatelessWidget {
  const _ChapterGrid({required this.chapters, required this.selected, required this.onTap});

  final List<Chapter> chapters;
  final Set<String> selected;
  final ValueChanged<Chapter> onTap;

  static String _label(Chapter chapter) =>
      chapter.number.isNotEmpty && chapter.number.length <= 8 ? chapter.number : chapter.title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 72,
          mainAxisExtent: 38,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          final active = selected.contains(chapter.id);
          return Tooltip(
            message: chapter.title,
            child: Material(
              color: active ? colors.primary : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTap(chapter),
                child: Center(
                  child: Text(
                    _label(chapter),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KagamiType.body(
                      12.5,
                      weight: 600,
                      color: active ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cosa si è scelto nel foglio: da dove partire (`null`, tutta) e dove.
class _Start {
  const _Start(this.from, this.destination);

  final String? from;
  final _Where destination;
}

/// «Scarica tutto oppure scegli da quale capitolo partire»: la stessa
/// domanda di `ChapterPicker.svelte` e della tastiera del bot di Telegram,
/// con i capitoli da toccare o il numero da scrivere.
class _StartSheet extends StatefulWidget {
  const _StartSheet({
    required this.chapters,
    required this.destinations,
    required this.destination,
  });

  final List<Chapter> chapters;
  final List<_Where> destinations;
  final _Where destination;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  final TextEditingController _written = TextEditingController();
  String? _selected;
  late _Where _destination = widget.destination;

  @override
  void dispose() {
    _written.dispose();
    super.dispose();
  }

  /// Il capitolo che corrisponde al numero scritto, se c'è.
  Chapter? get _typed {
    final text = _written.text.trim();
    if (text.isEmpty) return null;
    try {
      return widget.chapters[startIndex(widget.chapters, text)];
    } on ProviderError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    final chapters = widget.chapters;
    final typed = _typed;
    final chosen = typed ??
        chapters.where((chapter) => chapter.id == _selected).firstOrNull;
    final remaining = chosen == null ? 0 : chapters.length - chapters.indexOf(chosen);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${chapters.length} capitoli. Scarica tutto oppure scegli da quale '
            'capitolo partire: i precedenti restano in elenco nel lettore, '
            'senza tavole.',
            style: KagamiType.body(13, height: 1.45, color: muted),
          ),
          const SizedBox(height: 14),
          _ChapterGrid(
            chapters: chapters,
            selected: {?chosen?.id},
            onTap: (chapter) => setState(() {
              _selected = chapter.id;
              _written.clear();
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _written,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Numero del capitolo, come sul sito',
              prefixIcon: Icon(LucideIcons.hash, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _written.text.trim().isNotEmpty && typed == null
                ? 'Nessun capitolo con questo numero.'
                : chosen != null
                    ? 'Da «${chosen.title}» in poi: $remaining capitoli.'
                    : 'Nessun capitolo scelto: si può scaricare tutto.',
            style: KagamiType.body(
              12.5,
              height: 1.4,
              color: _written.text.trim().isNotEmpty && typed == null
                  ? context.tokens.danger
                  : muted,
            ),
          ),
          if (widget.destinations.length > 1) ...[
            const SizedBox(height: 16),
            const KSection('Dove'),
            KSegmented(
              options: [for (final value in widget.destinations) value.label],
              icons: [for (final value in widget.destinations) value.icon],
              index: widget.destinations.indexOf(_destination),
              onChanged: (index) =>
                  setState(() => _destination = widget.destinations[index]),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: KButton(
                  label: 'Scarica tutto',
                  icon: LucideIcons.library,
                  tone: context.colors.surfaceContainerHighest,
                  expand: true,
                  onPressed: () =>
                      Navigator.of(context).pop(_Start(null, _destination)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KButton(
                  label: 'Da qui',
                  icon: LucideIcons.skipForward,
                  expand: true,
                  onPressed: chosen == null
                      ? null
                      : () => Navigator.of(context)
                          .pop(_Start(chosen.id, _destination)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
