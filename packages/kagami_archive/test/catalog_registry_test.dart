// Il registro a tre strati (`docs/catalogo.md` § «Il registro: chi vince»):
// inclusi < catalogo < utenti, l'origine di ogni sito e i siti da installare
// presi da un catalogo adottato.
import 'dart:convert';

import 'package:kagami_archive/catalog.dart';
import 'dart:typed_data';

import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/fallback.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:test/test.dart';

Map<String, Object?> siteJson(String id, {int version = 1}) => {
      'format': 1,
      'id': id,
      'name': 'Nome $id',
      'version': version,
      'home': 'https://examplescans.com',
      'hosts': ['examplescans.com'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'title': 'h1',
        'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'img', 'url': {'attr': 'src'}},
      },
    };

CatalogSite catalogSite(String id, {bool builtin = true}) =>
    CatalogSite(id: id, state: CatalogSiteState.ok, variants: const [], builtin: builtin);

DeclarativeProvider fromCatalog(String id, {bool builtin = true}) =>
    DeclarativeProvider.fromJson(siteJson(id), catalog: catalogSite(id, builtin: builtin));
DeclarativeProvider fromUser(String id) => DeclarativeProvider.fromJson(siteJson(id));

String sha(String c) => List.filled(64, c).join();

void main() {
  tearDown(() {
    installCatalogProviders(const []);
    installUserProviders(const []);
  });

  group('strati', () {
    test('senza catalogo né utenti valgono gli inclusi', () {
      expect(providers.map((p) => p.id), builtInProviders.map((p) => p.id));
      expect(providers.every((p) => p.origin == ProviderOrigin.builtIn), isTrue);
    });

    test('il catalogo sostituisce un incluso al suo posto e aggiunge i nuovi dopo', () {
      installCatalogProviders([fromCatalog('nuovo'), fromCatalog('mangak')]);
      final ids = providers.map((p) => p.id).toList();
      expect(ids, [...builtInProviders.map((p) => p.id), 'nuovo']);
      expect(providerById('mangak')!.origin, ProviderOrigin.catalog);
      expect(providerById('mangak')!.builtIn, isFalse);
      expect(providerById('nuovo')!.origin, ProviderOrigin.catalog);
      expect(providerById('manhwaread')!.origin, ProviderOrigin.builtIn);
    });

    test('un sito dell\'utente vince sul catalogo con lo stesso id, al posto di quello', () {
      installCatalogProviders([fromCatalog('nuovo'), fromCatalog('mangak')]);
      installUserProviders([fromUser('mio'), fromUser('nuovo'), fromUser('mangak')]);
      final ids = providers.map((p) => p.id).toList();
      expect(ids, [...builtInProviders.map((p) => p.id), 'nuovo', 'mio']);
      expect(providerById('mangak')!.origin, ProviderOrigin.user);
      expect(providerById('nuovo')!.origin, ProviderOrigin.user);
      expect(providerById('mio')!.origin, ProviderOrigin.user);
    });

    test('la zona di un account del server sta sopra il catalogo del processo', () async {
      installCatalogProviders([fromCatalog('mangak'), fromCatalog('nuovo')]);
      await withUserProviders([fromUser('mangak')], () async {
        await Future<void>.delayed(Duration.zero);
        expect(providerById('mangak')!.origin, ProviderOrigin.user);
        expect(providerById('nuovo')!.origin, ProviderOrigin.catalog);
      });
      final sites = [fromUser('nuovo')];
      withUserProviderSource(() => sites, () {
        expect(providerById('nuovo')!.origin, ProviderOrigin.user);
        expect(providerById('mangak')!.origin, ProviderOrigin.catalog);
      });
    });

    test('spegnere il catalogo riporta gli inclusi', () {
      installCatalogProviders([fromCatalog('mangak')]);
      installCatalogProviders(const []);
      expect(providerById('mangak')!.origin, ProviderOrigin.builtIn);
    });
  });

  group('catalogProviders', () {
    AdoptedCatalog adopted(Map<String, CatalogDefinition> definitions, Map<String, Object?> sites) => AdoptedCatalog(
          serial: 3,
          indexBytes: utf8.encode(jsonEncode({'catalog': 1, 'serial': 3, 'issuedAt': '2026-11-15T09:30:00Z', 'sites': sites})),
          definitions: definitions,
        );
    Map<String, Object?> entry(String c, {String state = 'ok', String? message}) => {
          'state': state,
          'message': ?message,
          'variants': [
            {'version': 1, 'minEngine': 1, 'sha256': sha(c), 'path': 'sites/$c.json'},
          ],
        };

    test('dà i siti del catalogo con origine, stato e messaggio dell\'indice', () {
      final catalog = adopted(
        {
          'mangak': CatalogDefinition(text: jsonEncode(siteJson('mangak')), sha256: sha('a'), version: 1),
          'nuovo': CatalogDefinition(text: jsonEncode(siteJson('nuovo')), sha256: sha('b'), version: 1),
        },
        {'mangak': entry('a', state: 'broken', message: 'Non risponde.'), 'nuovo': entry('b')},
      );
      final sites = {for (final site in catalogProviders(catalog)) site.id: site};
      expect(sites.keys, unorderedEquals(['mangak', 'nuovo']));
      expect(sites.values.every((site) => site.origin == ProviderOrigin.catalog), isTrue);
      expect(sites['mangak']!.catalog!.state, CatalogSiteState.broken);
      expect(sites['mangak']!.catalog!.message, 'Non risponde.');
      expect(sites['nuovo']!.catalog!.state, CatalogSiteState.ok);
      expect(fromUser('mio').catalog, isNull);
    });

    test('una definizione in cache che non si legge si salta e si segnala', () {
      final catalog = adopted(
        {
          'mangak': CatalogDefinition(text: '{', sha256: sha('a'), version: 1),
          'nuovo': CatalogDefinition(text: jsonEncode(siteJson('nuovo')), sha256: sha('b'), version: 1),
        },
        {'mangak': entry('a'), 'nuovo': entry('b')},
      );
      final problems = <String>[];
      final sites = catalogProviders(catalog, onError: (id, problem) => problems.add(id));
      expect(sites.map((site) => site.id), ['nuovo']);
      expect(problems, ['mangak']);
    });
  });

  group('ripiego sull\'incluso', () {
    const url = 'https://examplescans.com/manga/solo';
    const broken = '<html><body><p>pagina nuova</p></body></html>';
    const good = '<h1>Solo</h1><ul><li><a href="https://examplescans.com/manga/solo/chapter-1">C1</a></li></ul>';

    test('il registro avvolge solo un sito del catalogo sopra un incluso, senza builtin off', () {
      installCatalogProviders([fromCatalog('mangak'), fromCatalog('nuovo'), fromCatalog('manhwaread', builtin: false)]);
      final mangak = providerById('mangak')!;
      expect(mangak, isA<FallbackProvider>());
      expect(mangak.origin, ProviderOrigin.catalog);
      expect(mangak.unwrapped, isA<DeclarativeProvider>());
      expect(providerById('nuovo'), isA<DeclarativeProvider>());
      expect(providerById('manhwaread'), isA<DeclarativeProvider>());
      expect(siteLayers('mangak').map((p) => p.origin), [ProviderOrigin.catalog, ProviderOrigin.builtIn]);
    });

    test('un sito dell\'utente non ripiega mai', () {
      installCatalogProviders([fromCatalog('mangak')]);
      installUserProviders([fromUser('mangak')]);
      expect(providerById('mangak'), isA<DeclarativeProvider>());
      expect(withFallback(fromUser('mangak')), isA<DeclarativeProvider>());
    });

    test('builtin off dall\'indice spegne il ripiego; un valore diverso invalida l\'indice', () {
      Map<String, Object?> index(Object builtin) => {
            'catalog': 1,
            'serial': 1,
            'issuedAt': '2026-11-15T09:30:00Z',
            'sites': {
              'mangak': {
                'state': 'ok',
                'builtin': builtin,
                'variants': [
                  {'version': 1, 'minEngine': 1, 'sha256': sha('a'), 'path': 'sites/a.json'},
                ],
              },
            },
          };
      final off = CatalogIndex.parse(utf8.encode(jsonEncode(index('off'))));
      expect(off.sites['mangak']!.builtin, isFalse);
      expect(CatalogIndex.parse(utf8.encode(jsonEncode(index('on')))).sites['mangak']!.builtin, isTrue);
      expect(() => CatalogIndex.parse(utf8.encode(jsonEncode(index(true)))), throwsA(isA<CatalogFormatError>()));
      final site = DeclarativeProvider.fromJson(siteJson('mangak'), catalog: off.sites['mangak']);
      expect(withFallback(site), same(site));
    });

    test('catalogo ProviderChanged e incluso che va: vale l\'incluso, e la traccia lo dice', () async {
      final included = _Included();
      final provider = FallbackProvider(fromCatalog('mangak'), included);
      final trace = SiteTrace();
      final series = await trace.run(() => provider.fetchSeries(url, _MapHttp({url: broken})));
      expect(series.title, 'Solo incluso');
      expect(included.calls, 1);
      expect(trace.degraded, contains('layer:builtIn'));
      final pages = await provider.fetchPages(series.chapters.single, _MapHttp({'$url/chapter-1': broken}));
      expect(pages.pages.single.url, 'https://img.example.net/1.webp');
    });

    test('il catalogo che va non chiama l\'incluso e non segna la traccia', () async {
      final included = _Included();
      final provider = FallbackProvider(fromCatalog('mangak'), included);
      final trace = SiteTrace();
      final series = await trace.run(() => provider.fetchSeries(url, _MapHttp({url: good})));
      expect(series.title, 'Solo');
      expect(included.calls, 0);
      expect(trace.degraded, isNot(contains('layer:builtIn')));
    });

    test('se fallisce anche l\'incluso vale l\'errore del catalogo', () async {
      final provider = FallbackProvider(fromCatalog('mangak'), _Included(fails: true));
      await expectLater(provider.fetchSeries(url, _MapHttp({url: broken})),
          throwsA(isA<ProviderChanged>().having((e) => e.message, 'message', isNot(contains('incluso')))));
    });

    test('un errore di rete o di stato non fa ripiegare', () async {
      final included = _Included();
      final provider = FallbackProvider(fromCatalog('mangak'), included);
      await expectLater(provider.fetchSeries(url, _MapHttp({})), throwsA(isA<HttpStatusError>()));
      await expectLater(provider.fetchSeries(url, _MapHttp({}, offline: true)), throwsA(isA<ProviderOffline>()));
      expect(included.calls, 0);
    });

    test('un incluso che dà alla serie un id diverso non è un ripiego: vale l\'errore del catalogo', () async {
      final included = _Included(seriesId: 'altro');
      final provider = FallbackProvider(fromCatalog('mangak'), included);
      await expectLater(provider.fetchSeries(url, _MapHttp({url: broken})), throwsA(isA<ProviderChanged>()));
      expect(included.calls, 1);
    });
  });
}

class _Included extends Provider {
  _Included({this.seriesId = 'solo', this.fails = false});

  final String seriesId;
  final bool fails;
  int calls = 0;

  @override
  String get id => 'mangak';
  @override
  String get name => 'MangaK incluso';
  @override
  String get home => 'https://examplescans.com';
  @override
  bool accepts(String url) => true;
  @override
  String? seriesOfChapter(String url) => null;
  @override
  bool allowedHost(Uri uri) => true;

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) async {
    calls++;
    if (fails) throw const ProviderChanged('rotto anche l\'incluso');
    return Series(
      provider: 'mangak',
      id: seriesId,
      title: 'Solo incluso',
      url: url,
      coverUrl: null,
      metadata: const {},
      chapters: [Chapter('1', 'Chapter 1', '1', '$url/chapter-1')],
    );
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) async =>
      const ChapterContent([Page('https://img.example.net/1.webp')], {});

  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) async => const [];
}

class _MapHttp implements ProviderHttp {
  _MapHttp(this.pages, {this.offline = false});

  final Map<String, String> pages;
  final bool offline;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (offline) throw const ProviderOffline();
    final page = pages[url];
    if (page == null) throw HttpStatusError(404);
    return (body: Uint8List.fromList(utf8.encode(page)), contentType: 'text/html');
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => decodeJsonObject((await get(url)).body);
}
