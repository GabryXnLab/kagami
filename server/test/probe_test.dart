// La parte del server della sentinella: il comando e il file dei canarini.
// La sonda in sé (stati, fault, degraded) è provata in packages/kagami_archive/test/probe_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/cassette.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/providers.dart';

import 'package:kagami_server/kagami_server.dart';
import 'package:test/test.dart';

void main() {
  test('il server riesporta la sonda del pacchetto', () {
    expect(Canary.parse('{"sites":{"a":{"query":"q"}}}')['a']!.single.query, 'q');
    expect(ProbeStatus.values, contains(ProbeStatus.gated));
  });

  test('catalog/canaries.json del repo si legge ed è al più di 3 canarini per sito', () {
    final file = File('../catalog/canaries.json');
    final canaries = Canary.parse(file.readAsStringSync());
    expect(canaries, isNotEmpty);
    expect(canaries.values.every((list) => list.isNotEmpty && list.length <= Canary.maxPerSite), isTrue);
  });

  group('definition e capture', () {
    const def = {
      'format': 1,
      'id': 'examplescans',
      'name': 'Example Scans',
      'version': 1,
      'update': 'https://raw.githubusercontent.com/someone/sites/main/examplescans.json',
      'home': 'https://examplescans.com',
      'hosts': ['examplescans.com'],
      'mediaHosts': ['*.examplecdn.net'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'url': 'https://examplescans.com/manga/{id}',
        'title': 'h1.title',
        'chapters': {
          'items': 'ul.chapters li',
          'url': {'css': 'a', 'attr': 'href'},
          'title': 'a',
          'id': {'from': 'url', 'regex': r'/chapter-([a-z0-9-]+)/?$'},
        },
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'div.reader img', 'url': {'attr': 'src'}},
      },
    };
    const series = '<h1 class="title">Long</h1><ul class="chapters"><li><a href="/manga/long/chapter-1/">C1</a></li></ul>';
    const chapter = '<div class="reader"><img src="https://img.examplecdn.net/1.webp"></div>';
    final canaries = {'examplescans': [const Canary(url: 'https://examplescans.com/manga/long')]};
    Future<Uint8List> image(String url, String referer) async =>
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 0, 0, 0, 0]);

    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('probe_run'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('definition: la definizione da file si prova su un http finto, senza cassetta se va', () async {
      final provider = DeclarativeProvider.parse(jsonEncode(def));
      final http = _MapHttp({
        'https://examplescans.com/manga/long': series,
        'https://examplescans.com/manga/long/chapter-1/': chapter,
      });
      final results = await probeSites([provider], canaries, (_) => http,
          capture: Directory('${tmp.path}/cap'), fetchImage: image);
      expect(results.single.status, ProbeStatus.ok);
      expect(results.single.version, 1);
      expect(Directory('${tmp.path}/cap').existsSync(), isFalse);
    });

    test('capture: un sito che fallisce lascia la sua cassetta in <dir>/<id>/<data>-guasto', () async {
      final provider = DeclarativeProvider.parse(jsonEncode(def));
      final http = _MapHttp({'https://examplescans.com/manga/long': series});
      final results = await probeSites([provider], canaries, (_) => http,
          capture: Directory('${tmp.path}/cap'), now: DateTime.utc(2026, 11, 16), fetchImage: image);
      expect(results.single.failed, isTrue);
      final cassette = Cassette.load(Directory('${tmp.path}/cap/examplescans/2026-11-16-guasto'));
      expect(cassette.entries['https://examplescans.com/manga/long']!.status, 200);
      expect(cassette.entries['https://examplescans.com/manga/long/chapter-1/']!.status, 404);
    });

    test('definition: senza capture un guasto non scrive niente', () async {
      final provider = DeclarativeProvider.parse(jsonEncode(def));
      final results = await probeSites([provider], canaries, (_) => _MapHttp({}));
      expect(results.single.failed, isTrue);
      expect(tmp.listSync(), isEmpty);
    });
  });

  group('--layers all', () {
    tearDown(() => installCatalogProviders(const []));

    test('un sito del catalogo sopra un incluso dà una voce per strato, ognuna col suo origin', () async {
      final catalogDef = {
        'format': 1,
        'id': 'mangak',
        'name': 'MangaK',
        'version': 4,
        'home': 'https://mangak.io',
        'hosts': ['mangak.io'],
        'series': {
          'path': r'^/([a-z0-9-]+)/?$',
          'title': 'h1',
          'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
        },
        'chapter': {'path': r'^/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$', 'pages': {'items': 'img', 'url': {'attr': 'src'}}},
      };
      installCatalogProviders([
        DeclarativeProvider.fromJson(catalogDef,
            catalog: const CatalogSite(id: 'mangak', state: CatalogSiteState.ok, variants: [])),
      ]);
      final layers = probeLayers([providerById('mangak')!, providerById('manhwaread')!]);
      expect(layers.map((p) => '${p.id}/${p.origin.name}'), ['mangak/catalog', 'mangak/builtIn', 'manhwaread/builtIn']);
      // Senza canarini ogni strato è «skipped», ma ognuno ha la sua voce.
      final results = await probeSites(layers, const {}, (_) => _MapHttp({}));
      expect(results.map((r) => '${r.site}/${r.origin}/${r.version}'),
          ['mangak/catalog/4', 'mangak/builtIn/null', 'manhwaread/builtIn/null']);
    });
  });
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
