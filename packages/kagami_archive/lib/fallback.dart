/// L'auto-ripiego del registro (`docs/catalogo.md` § «Il registro: chi
/// vince»): un sito del catalogo che sostituisce un incluso, con l'incluso
/// sotto da provare una volta quando la definizione dà [ProviderChanged].
library;

import 'declarative.dart' show DeclarativeProvider;
import 'http.dart';
import 'model.dart';
import 'providers.dart';
import 'providers/kit.dart' show siteMatch;

/// [site] col ripiego sull'incluso con lo stesso id, se gli spetta: solo un
/// sito del catalogo, con un incluso sotto e senza `builtin: "off"`
/// nell'indice. I siti degli utenti non ripiegano mai.
Provider withFallback(Provider site) {
  if (site is! DeclarativeProvider) return site;
  final entry = site.catalog;
  if (entry == null || !entry.builtin) return site;
  final included = builtInProviders.where((provider) => provider.id == site.id).firstOrNull;
  return included == null ? site : FallbackProvider(site, included);
}

/// Si presenta come il sito del catalogo; solo `fetchSeries`, `fetchPages`
/// e `search`, che parlano al sito, ripiegano su [included].
class FallbackProvider extends Provider {
  FallbackProvider(this.catalog, this.included);

  final DeclarativeProvider catalog;
  final Provider included;

  @override
  Provider get unwrapped => catalog;

  @override
  String get id => catalog.id;

  @override
  String get name => catalog.name;

  @override
  String get home => catalog.home;

  @override
  String get icon => catalog.icon;

  @override
  String? get iconUrl => catalog.iconUrl;

  @override
  bool get builtIn => catalog.builtIn;

  @override
  ProviderOrigin get origin => catalog.origin;

  @override
  bool accepts(String url) => catalog.accepts(url);

  @override
  String? seriesOfChapter(String url) => catalog.seriesOfChapter(url);

  @override
  String chapterKeyOf(String url) => catalog.chapterKeyOf(url);

  @override
  String canonical(String url) => catalog.canonical(url);

  @override
  BrowserGate? get browser => catalog.browser;

  /// Anche gli host dell'incluso: le tavole che dà dopo un ripiego stanno
  /// sui suoi, ed è codice di chi ha compilato l'app come il catalogo.
  @override
  bool allowedHost(Uri uri) => catalog.allowedHost(uri) || included.allowedHost(uri);

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) => _attempt(
        (provider) => provider.fetchSeries(url, http),
        valid: (series, read) => series.provider == id && _sameIdentity(url, series, read),
      );

  /// I `metadata` del capitolo li ha scritti il catalogo e possono non
  /// bastare all'incluso: in quel caso fallisce e vale l'errore del catalogo.
  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) =>
      _attempt((provider) => provider.fetchPages(chapter, http));

  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) =>
      _attempt((provider) => provider.search(query, http));

  /// L'incluso deve dare alla serie l'id del catalogo: un id diverso è un
  /// cambio d'identità, non un ripiego. Con `series.id` è quello che il
  /// catalogo ha letto dalla pagina prima di cadere ([read]); se non l'ha
  /// letto l'identità non si può verificare e il ripiego non vale. Senza,
  /// è il primo gruppo di `series.path` sul link.
  bool _sameIdentity(String url, Series series, SiteTrace read) {
    final spec = catalog.definition['series'];
    if (spec is! Map) return true;
    if (spec['id'] != null) return read.seriesId != null && series.id == read.seriesId;
    if (spec['path'] is! String) return true;
    final hosts = catalog.definition['hosts'];
    if (hosts is! List) return true;
    final found = siteMatch(url, hosts: {for (final host in hosts) '$host'}, path: RegExp(spec['path'] as String));
    if (found == null || found.groupCount < 1 || found[1] == null) return true;
    return series.id == found[1];
  }

  Future<T> _attempt<T>(Future<T> Function(Provider provider) operation, {bool Function(T result, SiteTrace first)? valid}) async {
    final trace = SiteTrace.current;
    final first = SiteTrace();
    try {
      final result = await first.run(() => operation(catalog));
      trace?.absorb(first);
      return result;
    } on ProviderChanged catch (error, stack) {
      // Solo ProviderChanged: rete e stato HTTP l'incluso li avrebbe uguali.
      final second = SiteTrace();
      final T result;
      try {
        result = await second.run(() => operation(included));
      } on Object {
        Error.throwWithStackTrace(error, stack);
      }
      if (valid != null && !valid(result, first)) Error.throwWithStackTrace(error, stack);
      trace
        ?..absorb(second)
        ..missing('layer:builtIn');
      return result;
    }
  }
}
