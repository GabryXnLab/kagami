/// I siti degli utenti: un file JSON che dice dove stanno serie, capitoli e
/// tavole, interpretato qui. Il formato è in `docs/siti.md`.
///
/// Niente codice del file viene eseguito: selettori CSS, percorsi JSON ed
/// espressioni regolari, e ogni indirizzo passa da [Provider.allowedHost] come
/// per i siti inclusi. Il file arriva da chiunque e il server gira nella rete
/// di casa di qualcuno, per questo gli host si controllano già all'installazione.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

import 'catalog.dart' show CatalogSite, catalogEngine, maxCatalogSiteBytes;
import 'http.dart';
import 'indexes.dart' show prettyJson;
import 'model.dart';
import 'providers.dart';
import 'providers/kit.dart';
import 'renderer.dart';
import 'site_engine.dart';
import 'stores.dart';

part 'declarative_extract.dart';
part 'declarative_filters.dart';
part 'declarative_guard.dart';
part 'declarative_recipe.dart';
part 'declarative_spec.dart';
part 'declarative_vars.dart';

/// Il formato più alto che questo motore sa leggere (legge anche il 1); quali
/// chiavi del formato sa interpretare lo dice [catalogEngine].
const int siteFormat = 2;

/// La cartella dei siti nella libreria, accanto a `library.json`.
const String sitesFolder = 'providers';

/// Un file di sito che non si può installare: il messaggio dice quale campo.
class SiteDefinitionError implements Exception {
  const SiteDefinitionError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Un file valido per un motore più nuovo: usa [key], che arriva con
/// l'`engine` [engine], più alto di [catalogEngine]. L'app lo dice come «serve
/// Kagami più nuovo», non come un file sbagliato.
class SiteEngineError extends SiteDefinitionError {
  SiteEngineError(this.engine, this.key)
      : super('Il sito usa «$key», che richiede un Kagami più nuovo (engine $engine, questo arriva al $catalogEngine).');

  final int engine;
  final String key;
}

/// Un sito descritto da un file: si comporta come uno incluso.
class DeclarativeProvider extends Provider {
  DeclarativeProvider._(this.definition, this._spec, this.catalog);

  /// Legge [text], il contenuto di un file di sito, e lo valida per intero:
  /// un errore qui non arriva mai a metà di un download. [catalog] è la voce
  /// dell'indice per un sito preso dal catalogo, `null` per uno dell'utente.
  factory DeclarativeProvider.parse(String text, {CatalogSite? catalog}) {
    _checkSize(utf8.encode(text).length, catalog);
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const SiteDefinitionError('Il file del sito non è un JSON valido.');
    }
    if (decoded is! Map<String, Object?>) throw const SiteDefinitionError('Il file del sito non è un oggetto JSON.');
    return DeclarativeProvider.fromJson(decoded, catalog: catalog);
  }

  factory DeclarativeProvider.fromJson(Map<String, Object?> json, {CatalogSite? catalog}) {
    _checkSize(utf8.encode(jsonEncode(json)).length, catalog);
    return DeclarativeProvider._(Map.unmodifiable(json), _Spec.read(json), catalog);
  }

  static void _checkSize(int bytes, CatalogSite? catalog) {
    if (catalog == null && bytes > _maxFileBytes) {
      throw const SiteDefinitionError('Il file del sito supera i 64 KB.');
    }
    if (catalog != null && bytes > _maxCatalogFileBytes) {
      throw const SiteDefinitionError('Il file del sito supera i 256 KB.');
    }
  }

  /// Richieste e byte di risposta ammessi a una operazione: quelli di fiducia
  /// per un sito del catalogo, quelli degli utenti per gli altri.
  int get requestLimit => catalog == null ? maxSiteRequests : maxCatalogSiteRequests;
  int get responseLimit => catalog == null ? maxSiteResponseBytes : maxCatalogSiteResponseBytes;

  /// Il file com'è stato letto, per riscriverlo nella libreria.
  final Map<String, Object?> definition;
  final _Spec _spec;

  /// La voce dell'indice del catalogo (stato e messaggio per la pagina Siti)
  /// se il sito viene da lì; `null` per un sito dell'utente.
  final CatalogSite? catalog;

  @override
  String get id => _spec.id;

  @override
  String get name => _spec.name;

  @override
  String get home => _spec.home;

  @override
  String? get iconUrl => _spec.icon;

  @override
  bool get builtIn => false;

  @override
  ProviderOrigin get origin => catalog == null ? ProviderOrigin.user : ProviderOrigin.catalog;

  /// Le espressioni le scrive il motore: il file dà solo selettori, che
  /// restano stringhe JSON e non possono diventare codice.
  @override
  BrowserGate? get browser {
    final gate = _spec.browser;
    if (gate == null) return null;
    String ready(String selector) => '!!document.querySelector(${jsonEncode(selector)})';
    return BrowserGate(
      hosts: gate.hosts,
      seriesReady: ready(gate.seriesReady),
      searchReady: ready(gate.searchReady),
    );
  }

  int get version => _spec.version;

  /// Da dove rileggere il file per aggiornarlo.
  String? get updateUrl => _spec.update;

  bool get searchable => _spec.search != null;

  /// Gli host a cui il sito chiederà qualcosa: chi installa li vede prima.
  List<String> get hosts => [..._spec.hosts, ..._spec.mediaHosts];

  /// Il file come lo si scrive in `providers/<id>.json`.
  Uint8List encode() => Uint8List.fromList(utf8.encode(prettyJson(definition)));

  @override
  bool accepts(String url) => _seriesMatch(url) != null;

  RegExpMatch? _seriesMatch(String url) =>
      siteMatch(url, hosts: _spec.hosts.toSet(), path: _spec.series.path, maxPath: _maxMatchText);

  @override
  String? seriesOfChapter(String url) {
    final series = _spec.series;
    final address = series.url;
    final found = siteMatch(url, hosts: _spec.hosts.toSet(), path: _spec.chapter.path, maxPath: _maxMatchText);
    if (found == null || found.groupCount < 1 || found[1] == null) return null;
    if (series.link case final link?) {
      // `id` dal percorso del capitolo e le `linkVars` sul suo link: se una
      // resta vuota il link non si compone e il capitolo non dà la serie.
      final vars = _Vars({'id': found[1], 'url': url});
      _evaluate(series.linkVars, url, _Context(url, vars, url: url));
      final rendered = link.render(vars);
      return rendered != null && accepts(rendered) ? rendered : null;
    }
    if (address == null) return null;
    // Dal link di un capitolo si ha solo `id`: un indirizzo che chiede altre
    // variabili non si rifà, e il link non vale come capitolo.
    return address.alternatives.first.render(_Vars({'id': found[1]}));
  }

  @override
  bool allowedHost(Uri uri) =>
      _spec.hosts.contains(uri.host) || _spec.mediaHosts.any((host) => _hostMatches(host, uri.host));

  /// Con `try` il link canonico è la prima alternativa, la stessa per ogni
  /// forma del link; la richiesta passa poi alle altre.
  @override
  String canonical(String url) {
    final found = _seriesMatch(url);
    if (found == null) return url;
    if (_spec.series.link case final link?) {
      // Un link che `series.path` rifiuta resta com'è arrivato: `canonical` non solleva.
      final rendered = link.render(_linkVars(url, found));
      return rendered != null && accepts(rendered) ? rendered : url;
    }
    if (_spec.series.url case final address?) {
      if (address.alternatives.first.render(_linkVars(url, found)) case final rendered?) return rendered;
    }
    return Uri.parse(url).replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '');
  }

  /// Le variabili della serie prima di ogni richiesta: `id`, `url` e `linkVars`.
  _Vars _linkVars(String url, RegExpMatch found) {
    final vars = _Vars({'id': found.groupCount >= 1 ? found[1] : null, 'url': url});
    _evaluate(_spec.series.linkVars, url, _Context(url, vars, url: url));
    return vars;
  }

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) => _bounded((budget) => _fetchSeries(url, http, budget));

  Future<Series> _fetchSeries(String url, ProviderHttp http, _Budget budget) async {
    final found = _seriesMatch(url);
    if (found == null) throw ProviderError('Inserisci il link di una serie $name.');
    final spec = _spec.series;
    final address = canonical(url);
    final vars = _linkVars(url, found);
    final (fetched, page) = spec.url == null
        ? (address, await _read(http, budget, address, 'series', json: spec.json, ready: _ready('series')))
        : await _fetch(http, budget, spec.url!, vars, 'series', 'series.url', json: spec.json, ready: _ready('series'));
    final context = _Context(fetched, vars);
    _evaluate(spec.vars, page, context);
    _require(spec.require, page, context, 'Serie $name non riconosciuta nella pagina.', 'series', 'series.require', fetched);
    await spec.recipe?.run(page, context, budget, _recipeFetch(http, budget, 'series'), 'series', name);
    var seriesId = found.groupCount >= 1 ? found[1] : null;
    if (spec.id case final extractor?) {
      seriesId = extractor.first(page, context);
      if (seriesId != null && seriesId.isNotEmpty) SiteTrace.current?.seriesId = seriesId;
    }
    final title = spec.title.first(page, context);
    if (seriesId == null || seriesId.isEmpty || title == null) {
      final missingId = seriesId == null || seriesId.isEmpty;
      throw ProviderChanged(
        'Serie $name non riconosciuta nella pagina.',
        fault: SiteFault('series',
            field: missingId ? 'series.id' : 'series.title', detail: 'valore assente nella pagina', url: fetched),
      );
    }
    // `chapters.api` chiede l'elenco con l'id letto, come nel formato 1.
    if (seriesId != found[1]) vars.set('id', seriesId);
    final metadata = <String, Object?>{};
    for (final MapEntry(key: field, value: extractor) in spec.metadata.entries) {
      final values = extractor.strings(page, context);
      if (values.isEmpty) continue;
      metadata[field] = extractor.all || extractor.split != null ? values : values.first;
    }
    var cover = spec.cover?.first(page, context);
    if (cover != null && !allows(cover)) cover = null;
    final chapters = await _withReserves(spec.chapters.where,
        spec.chapters, spec.chapters.fallback, budget, (block) => _chapters(block, http, budget, page, context));
    var seriesUrl = address;
    if (spec.link case final link?) {
      // Con l'id letto dalla serie: `linkVars` restano quelle del link.
      seriesUrl = link.render(vars) ?? '';
      if (!accepts(seriesUrl)) {
        throw ProviderChanged(
          'Serie $name non riconosciuta nella pagina.',
          fault: SiteFault('series', field: 'series.link', detail: 'link non accettato da series.path: $seriesUrl', url: fetched),
        );
      }
    }
    return Series(
      provider: id,
      id: seriesId,
      title: title,
      url: seriesUrl,
      coverUrl: cover,
      metadata: metadata,
      chapters: chapters,
    );
  }

  /// L'elenco dei capitoli secondo [spec], il principale o una riserva: [page]
  /// e [context] sono la pagina della serie e le sue variabili, che nessun
  /// blocco cambia.
  Future<List<Chapter>> _chapters(
      _ChaptersSpec spec, ProviderHttp http, _Budget budget, Object? page, _Context context) async {
    final where = spec.where;
    final declared = switch (spec.expect?.first(page, context)) {
      null => null,
      final text => int.tryParse(_shortNumber(text) ?? ''),
    };
    if (spec.expect != null && (declared == null || declared < 0)) SiteTrace.current?.missing('$where.expect');
    var source = page;
    var read = context.page;
    // I link relativi di un'API si risolvono rispetto alla serie: l'API sta
    // spesso su un altro host, i capitoli no.
    final base = context;
    if (spec.api case final api?) {
      (read, source) = await _fetch(http, budget, api, context.vars, 'chapters', '$where.api', json: true);
    }
    final items = spec.items.nodes(source, base);
    // Prima di `skip`: i capitoli che il file scarta per scelta il sito li conta.
    final short = declared == null ? 0 : declared - items.length;
    if (declared != null && short > chaptersTolerance(declared)) {
      throw ProviderChanged(
        'Elenco capitoli $name incompleto: ${items.length} su $declared.',
        fault: SiteFault('chapters',
            field: '$where.expect', detail: '${items.length} capitoli, il sito ne dichiara $declared', url: read),
      );
    }
    // Uno scarto entro la soglia non blocca: il sito è usabile ma la sonda lo vede.
    if (short > 0) SiteTrace.current?.missing('$where.expect');
    final chapters = <Chapter>[];
    for (final item in items) {
      final itemBase = _Context(base.page, base.vars.child());
      _evaluate(spec.vars, item, itemBase);
      if (_anyHolds(spec.skip, item, itemBase)) continue;
      final link = spec.url.first(item, itemBase);
      final title = spec.title.first(item, itemBase);
      if (link == null || title == null) {
        throw ProviderChanged(
          'Capitolo $name incompleto.',
          fault: SiteFault('chapters',
              field: link == null ? '$where.url' : '$where.title',
              detail: 'valore assente in un capitolo',
              url: base.page),
        );
      }
      if (!allows(link)) {
        throw ProviderChanged(
          'Capitolo $name fuori dai domini del sito.',
          fault: SiteFault('chapters', field: '$where.url', detail: 'indirizzo fuori dai domini: $link', url: base.page),
        );
      }
      final itemContext = _Context(base.page, itemBase.vars, url: link);
      final chapterId = spec.id?.first(item, itemContext) ?? _lastSegment(link);
      if (chapterId == null || chapterId.isEmpty) {
        throw ProviderChanged(
          'Capitolo $name senza id.',
          fault: SiteFault('chapters', field: '$where.id', detail: 'id assente in un capitolo', url: base.page),
        );
      }
      final number = spec.number?.first(item, itemContext) ?? chapterNumber(title) ?? title;
      final date = spec.date?.first(item, itemContext);
      final kept = {
        for (final name in spec.keep)
          if (itemBase.vars.text(name) case final text when text.isNotEmpty) name: text,
      };
      chapters.add(Chapter(chapterId, title, number, link, {'date': ?date, ...kept}));
    }
    if (chapters.isEmpty) {
      throw ProviderChanged(
        'Elenco capitoli $name vuoto.',
        fault: SiteFault('chapters', field: '$where.items', detail: 'elenco vuoto', url: base.page),
      );
    }
    final ordered = switch (spec.order) {
      'newest-first' => chapters.reversed.toList(),
      'oldest-first' => chapters,
      _ => oldestFirst(chapters),
    };
    requireUniqueIds(ordered, name);
    return ordered;
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) =>
      _bounded((budget) => _fetchPages(chapter, http, budget));

  Future<ChapterContent> _fetchPages(Chapter chapter, ProviderHttp http, _Budget budget) =>
      _withReserves('chapter', _spec.chapter, _spec.chapter.fallback, budget, (block) => _pages(block, chapter, http, budget));

  /// Le tavole secondo [spec], il principale o una riserva: ognuno parte dalle
  /// sole variabili del capitolo.
  Future<ChapterContent> _pages(_ChapterSpec spec, Chapter chapter, ProviderHttp http, _Budget budget) async {
    final where = spec.where;
    final vars = _Vars({
      'id': chapter.id,
      'url': chapter.url,
      'chapterId': chapter.id,
      for (final name in _spec.series.chapters.keep)
        if (chapter.metadata[name] case final String value) name: value,
    });
    _evaluate(spec.linkVars, chapter.url, _Context(chapter.url, vars, url: chapter.url));
    final (address, page) = spec.api == null
        ? (chapter.url, await _read(http, budget, chapter.url, 'pages', json: spec.json, ready: _ready('chapter')))
        : await _fetch(http, budget, spec.api!, vars, 'pages', '$where.api', json: true);
    final context = _Context(address, vars);
    _evaluate(spec.vars, page, context);
    _require(spec.require, page, context, 'Capitolo non corrispondente: ${chapter.title}.', 'pages', '$where.require', address);
    if (spec.locked?.holds(page, context) ?? false) {
      throw ProviderError('Capitolo riservato agli abbonati di $name: ${chapter.title}.');
    }
    await spec.recipe?.run(page, context, budget, _recipeFetch(http, budget, 'pages'), 'pages', name);
    final pages = <Page>[];
    for (final item in spec.pages.items.nodes(page, context)) {
      final itemContext = _Context(address, vars.child());
      _evaluate(spec.pages.vars, item, itemContext);
      if (_anyHolds(spec.pages.skip, item, itemContext)) continue;
      final link = spec.pages.url.first(item, itemContext);
      if (link == null) {
        throw ProviderChanged(
          'Tavola senza indirizzo: ${chapter.title}.',
          fault: SiteFault('pages', field: '$where.pages.url', detail: 'valore assente in una tavola', url: address),
        );
      }
      if (!allows(link)) {
        throw ProviderChanged(
          'Tavola fuori dai domini del sito: ${chapter.title}.',
          fault: SiteFault('pages', field: '$where.pages.url', detail: 'indirizzo fuori dai domini: $link', url: address),
        );
      }
      pages.add(Page(
        link,
        int.tryParse(spec.pages.width?.first(item, itemContext) ?? ''),
        int.tryParse(spec.pages.height?.first(item, itemContext) ?? ''),
      ));
    }
    if (pages.isEmpty) {
      throw ProviderChanged(
        'Nessuna tavola trovata: ${chapter.title}.',
        fault: SiteFault('pages', field: '$where.pages.items', detail: 'elenco vuoto', url: address),
      );
    }
    return ChapterContent(pages, const {});
  }

  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) => _bounded((budget) => _search(query, http, budget));

  Future<List<SearchResult>> _search(String query, ProviderHttp http, _Budget budget) async {
    final spec = _spec.search;
    if (spec == null || query.trim().isEmpty) return const [];
    return _withReserves('search', spec, spec.fallback, budget, (block) => _results(block, query.trim(), http, budget));
  }

  Future<List<SearchResult>> _results(_SearchSpec spec, String query, ProviderHttp http, _Budget budget) async {
    final vars = _Vars({'query': query});
    final (address, page) =
        await _fetch(http, budget, spec.url, vars, 'search', '${spec.where}.url', json: spec.json, ready: _ready('search'));
    final context = _Context(address, vars);
    _evaluate(spec.vars, page, context);
    _require(spec.require, page, context, 'Ricerca di $name non riconosciuta nella pagina.', 'search',
        '${spec.where}.require', address);
    await spec.recipe?.run(page, context, budget, _recipeFetch(http, budget, 'search'), 'search', name);
    final results = <SearchResult>[];
    for (final item in spec.items.nodes(page, context)) {
      if (_anyHolds(spec.skip, item, context)) continue;
      final link = spec.link.first(item, context);
      final title = spec.title.first(item, context);
      if (link == null || title == null || !accepts(link)) continue;
      final cover = spec.cover?.first(item, context);
      final latest = spec.latest?.first(item, context);
      results.add(SearchResult(
        provider: id,
        title: title,
        url: canonical(link),
        coverUrl: cover != null && allows(cover) ? cover : null,
        latestChapter: latest == null ? null : chapterNumber(latest) ?? (num.tryParse(latest) != null ? latest : null),
        releaseStatus: releaseStatus(spec.status?.first(item, context)),
      ));
      if (results.length == searchLimit) break;
    }
    return results;
  }

  /// `fetch` della ricetta: la risposta come testo o JSON, contata fra le
  /// richieste dell'operazione.
  _Fetch _recipeFetch(ProviderHttp http, _Budget budget, String phase) =>
      (address, vars, field, {required json}) async =>
          (await _fetch(http, budget, address, vars, phase, field, json: json, text: true)).$2;

  /// Chiede [address] con [vars]: con `try` le alternative in ordine, alla
  /// successiva solo su uno stato di `on`; due uguali si chiedono una volta.
  /// Dà anche l'indirizzo che ha risposto, per i link relativi.
  Future<(String, Object?)> _fetch(
      ProviderHttp http, _Budget budget, _Address address, _Vars vars, String phase, String field,
      {required bool json, bool text = false, String? ready}) async {
    // L'indirizzo e la sua alternativa, contata da 0: due uguali si chiedono
    // una volta, e la traccia nomina la prima che lo dava.
    final urls = <(String, int)>[];
    for (final (alternative, link) in address.alternatives.indexed) {
      final url = link.render(vars);
      if (url == null) {
        throw ProviderChanged(
          'Indirizzo di $name incompleto: manca un valore della pagina.',
          fault: SiteFault(phase, field: field, detail: 'variabile vuota nell\'indirizzo'),
        );
      }
      if (!urls.any((known) => known.$1 == url)) urls.add((url, alternative));
    }
    for (final (index, (url, alternative)) in urls.indexed) {
      try {
        final page = await _read(http, budget, url, phase, json: json, text: text, ready: ready);
        if (alternative > 0) SiteTrace.current?.note(field, alternative + 1);
        return (url, page);
      } on HttpStatusError catch (error) {
        if (index == urls.length - 1 || !address.on.contains(error.status)) rethrow;
      }
    }
    throw StateError('nessun indirizzo');
  }

  /// `fallback` (`docs/siti.md`, «Blocchi di riserva»): [main], poi le
  /// riserve in ordine, finché uno riesce. Si passa alla successiva solo su un
  /// `ProviderChanged` o su un 4xx che non sia 403 (verifica anti-bot) o 429
  /// (limite di frequenza), e solo se restano richieste; se nessuno riesce
  /// vale l'errore del principale, la forma da cui si ripara. La traccia
  /// prende le voci del solo blocco riuscito, più `where#n` se è una riserva.
  Future<T> _withReserves<T, B>(
      String where, B main, List<B> reserves, _Budget budget, Future<T> Function(B block) attempt) async {
    if (reserves.isEmpty) return attempt(main);
    final outer = SiteTrace.current;
    Object? failure;
    StackTrace? failureStack;
    for (final (index, block) in [main, ...reserves].indexed) {
      if (index > 0 && budget.requests >= requestLimit) break;
      final trace = SiteTrace();
      try {
        final result = await trace.run(() => attempt(block));
        outer?.absorb(trace);
        outer?.note(where, index + 1);
        return result;
      } on Object catch (error, stack) {
        if (index == 0) (failure, failureStack) = (error, stack);
        if (!_fallsBack(error)) break;
      }
    }
    Error.throwWithStackTrace(failure!, failureStack!);
  }

  static bool _fallsBack(Object error) =>
      error is ProviderChanged ||
      (error is HttpStatusError && error.status >= 400 && error.status < 500 && error.status != 403 && error.status != 429);

  /// `require`: una condizione che non vale vuol dire che il sito ha cambiato forma.
  void _require(List<_Condition> conditions, Object? page, _Context context, String message, String phase,
      String field, String url) {
    if (!conditions.every((condition) => condition.holds(page, context))) {
      throw ProviderChanged(message, fault: SiteFault(phase, field: field, detail: 'condizione non soddisfatta', url: url));
    }
  }

  Future<T> _bounded<T>(Future<T> Function(_Budget budget) operation) async {
    try {
      return await operation(_Budget()).timeout(maxSiteOperationTime);
    } on TimeoutException {
      throw ProviderError('Il sito $name ha impiegato troppo: operazione interrotta.');
    }
  }

  /// L'espressione che riconosce [page] (`series`, `chapter`, `search`) pronta
  /// nel browser, se il file la vuole resa (`browser.pages`); scritta dal motore.
  String? _ready(String page) {
    final gate = _spec.browser;
    if (gate == null || !gate.pages.contains(page)) return null;
    final selector = switch (page) {
      'series' => gate.seriesReady,
      'chapter' => gate.chapterReady!,
      _ => gate.searchReady,
    };
    return '!!document.querySelector(${jsonEncode(selector)})';
  }

  /// [url] resa dal browser installato, appena [ready] è vera: il documento
  /// che ne esce lo leggono gli estrattori come una pagina scaricata.
  Future<dom.Document> _render(String url, String ready) async {
    final hosts = _spec.browser!.hosts;
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || !hosts.contains(uri.host)) {
      throw ProviderError('Il sito $name chiede di rendere una pagina fuori da browser.hosts: $url');
    }
    final renderer = pageRenderer;
    if (renderer == null) throw RendererMissing('Il sito $name va letto da un browser, che qui non c\'è: serve il browser.');
    final String? html;
    try {
      html = await renderer
          .render(url, hosts: hosts, ready: ready, timeout: maxRenderTime)
          .timeout(maxRenderTime + const Duration(seconds: 10));
    } on TimeoutException {
      throw RenderTimeout('La pagina di $name non è pronta nel browser: $url');
    }
    if (html == null) throw RenderTimeout('La pagina di $name non è pronta nel browser: $url');
    if (utf8.encode(html).length > maxRenderedPageBytes) throw const ProviderError('Pagina resa troppo grande.');
    return parser.parse(html);
  }

  /// [text]: senza [json], il corpo com'è invece del documento HTML. Con
  /// [ready] la pagina la rende il browser (`browser.pages`).
  Future<Object?> _read(ProviderHttp http, _Budget budget, String url, String phase,
      {required bool json, bool text = false, String? ready}) async {
    validateUrl(url);
    if (++budget.requests > requestLimit) {
      throw ProviderError('Il sito $name chiede troppe richieste per una sola operazione.');
    }
    // Una pagina già resa dal browser (SnapshotHttp) vale quanto un rendering.
    if (ready != null && !(http is SnapshotHttp && http.url == url)) return _render(url, ready);
    final result = await http.get(url, limit: responseLimit);
    if (result.body.length > responseLimit) throw const ProviderError('Risposta troppo grande.');
    final body = utf8.decode(result.body, allowMalformed: true);
    if (!json) return text ? body : parser.parse(body);
    try {
      return jsonDecode(body);
    } on FormatException {
      throw ProviderChanged(
        'Risposta di $name non in JSON.',
        fault: SiteFault(phase, detail: 'attesa una risposta JSON, arrivato: $body', url: url),
      );
    }
  }
}

/// Legge i siti in `providers/` di [store]. Un file rovinato non ferma gli
/// altri: lo dice [onError] e resta dov'è, perché togliere un sito è una scelta
/// dell'utente.
Future<List<DeclarativeProvider>> loadSites(
  ArchiveStore store, {
  void Function(String file, Object error)? onError,
}) async {
  final sites = <DeclarativeProvider>[];
  final files = await store.filesIn(sitesFolder);
  for (final name in files.keys.toList()..sort()) {
    if (!name.endsWith('.json')) continue;
    try {
      final json = await store.readJson('$sitesFolder/$name');
      if (json == null) throw const SiteDefinitionError('Il file non si legge o non è un JSON valido.');
      final site = DeclarativeProvider.fromJson(json);
      if ('${site.id}.json' != name) throw SiteDefinitionError('Il file $name contiene il sito ${site.id}.');
      sites.add(site);
    } on Object catch (error) {
      onError?.call(name, error);
    }
  }
  return sites;
}

/// Scrive [site] nella libreria di [store], al posto della versione di prima.
Future<void> saveSite(ArchiveStore store, DeclarativeProvider site) =>
    store.writeSeriesFiles(sitesFolder, {'${site.id}.json': site.encode()});

/// Toglie il file del sito [id] dalla libreria; le sue serie restano.
Future<void> removeSite(ArchiveStore store, String id) => store.removeFile('$sitesFolder/$id.json');

String? _lastSegment(String url) =>
    Uri.tryParse(url)?.pathSegments.where((segment) => segment.isNotEmpty).lastOrNull;
