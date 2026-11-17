// Il ripiego sull'incluso e l'identità delle serie quando la definizione la
// legge dalla pagina con `series.id` (`docs/catalogo.md` § «Il registro: chi
// vince»).
import 'dart:convert';
import 'dart:typed_data';

import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/fallback.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:test/test.dart';

const url = 'https://examplescans.com/manga/solo';

DeclarativeProvider catalogWithSeriesId() => DeclarativeProvider.fromJson({
      'format': 1,
      'id': 'mangak',
      'name': 'MangaK',
      'version': 1,
      'home': 'https://examplescans.com',
      'hosts': ['examplescans.com'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'id': {'css': 'meta[name=series]', 'attr': 'content'},
        'title': 'h1',
        'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'img', 'url': {'attr': 'src'}},
      },
    }, catalog: CatalogSite(id: 'mangak', state: CatalogSiteState.ok, variants: const [], builtin: true));

// L'id c'è, il titolo no: il catalogo ha letto l'identità e poi è caduto.
const idWithoutTitle = '<html><head><meta name="series" content="4242"></head><body><p>nuova</p></body></html>';
const nothing = '<html><body><p>pagina nuova</p></body></html>';

void main() {
  group('series.id', () {
    test('l\'incluso con lo stesso id letto dal catalogo vale come ripiego', () async {
      final included = _Included('4242');
      final trace = SiteTrace();
      final series = await trace.run(
          () => FallbackProvider(catalogWithSeriesId(), included).fetchSeries(url, _MapHttp({url: idWithoutTitle})));
      expect(series.id, '4242');
      expect(included.calls, 1);
      expect(trace.degraded, contains('layer:builtIn'));
    });

    test('un incluso con un id diverso da quello letto non è un ripiego', () async {
      final included = _Included('solo');
      await expectLater(FallbackProvider(catalogWithSeriesId(), included).fetchSeries(url, _MapHttp({url: idWithoutTitle})),
          throwsA(isA<ProviderChanged>().having((e) => e.fault?.field, 'field', 'series.title')));
      expect(included.calls, 1);
    });

    test('se il catalogo non ha letto l\'id l\'identità non si verifica e vale il suo errore', () async {
      final included = _Included('4242');
      await expectLater(FallbackProvider(catalogWithSeriesId(), included).fetchSeries(url, _MapHttp({url: nothing})),
          throwsA(isA<ProviderChanged>().having((e) => e.fault?.field, 'field', 'series.id')));
      expect(included.calls, 1);
    });
  });
}

class _Included extends Provider {
  _Included(this.seriesId);

  final String seriesId;
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
  _MapHttp(this.pages);

  final Map<String, String> pages;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    final page = pages[url];
    if (page == null) throw HttpStatusError(404);
    return (body: Uint8List.fromList(utf8.encode(page)), contentType: 'text/html');
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => decodeJsonObject((await get(url)).body);
}
