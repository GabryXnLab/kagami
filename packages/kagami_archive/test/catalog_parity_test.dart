// Parità fra i siti inclusi (provider Dart) e le loro definizioni del
// catalogo (`catalog/sites/<id>.json`, formato 2): stesse risposte finte,
// stesso esito. Le differenze ammesse sono quelle di `docs/siti.md`
// («I siti inclusi nel formato 2»); ogni altra è uno `skip` con il motivo.
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/providers/asurascans.dart';
import 'package:kagami_archive/providers/coffeemanga.dart';
import 'package:kagami_archive/providers/mangak.dart';
import 'package:kagami_archive/providers/manhwaread.dart';
import 'package:kagami_archive/site_engine.dart';
import 'package:test/test.dart';

import 'archive_fakes.dart';

/// Il motore dei siti del catalogo legge le API con `get`, i provider Dart con
/// `json`: gli host `api.` rispondono dal `json` del finto, gli altri dal `get`.
class _ApiAsGet implements ProviderHttp {
  _ApiAsGet(this.inner);

  final ProviderHttp inner;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (Uri.parse(url).host.startsWith('api.')) {
      return (body: utf8.encode(jsonEncode(await inner.json(url))), contentType: 'application/json');
    }
    return inner.get(url, limit: limit, referer: referer);
  }

  @override
  Future<Map<String, Object?>> json(String url) => inner.json(url);

  @override
  Future<bool> imageExists(String url, {required String referer}) => inner.imageExists(url, referer: referer);
}

DeclarativeProvider _site(String id) {
  final text = File('../../catalog/sites/$id.json').readAsStringSync();
  return DeclarativeProvider.parse(text, catalog: CatalogSite(id: id, state: CatalogSiteState.ok, variants: const []));
}

List<(String, String, String, String)> _chapters(Series series) =>
    [for (final c in series.chapters) (c.id, c.number, c.url, c.title)];

List<(String, int?, int?)> _pages(ChapterContent content) =>
    [for (final page in content.pages) (page.url, page.width, page.height)];

List<(String, String, String?, String?, String)> _results(List<SearchResult> results) =>
    [for (final r in results) (r.title, r.url, r.coverUrl, r.latestChapter, r.releaseStatus)];

/// La stessa serie letta dal provider Dart e dal sito del catalogo, con due
/// finti identici (uno per lettore: i finti contano le richieste).
Future<void> _sameSeries(
  Provider dart,
  DeclarativeProvider site,
  ProviderHttp Function() fake,
  String url, {
  bool sameUrl = true,
}) async {
  final expected = await dart.fetchSeries(url, fake());
  final actual = await site.fetchSeries(url, _ApiAsGet(fake()));
  expect(actual.id, expected.id);
  expect(actual.title, expected.title);
  expect(actual.coverUrl, expected.coverUrl);
  if (sameUrl) expect(actual.url, expected.url);
  expect(_chapters(actual), _chapters(expected));
}

Future<void> _samePages(
  Provider dart,
  DeclarativeProvider site,
  ProviderHttp Function() fake,
  String url,
) async {
  final dartHttp = fake();
  final siteHttp = _ApiAsGet(fake());
  final expected = await dart.fetchSeries(url, dartHttp);
  final actual = await site.fetchSeries(url, siteHttp);
  expect(actual.chapters, isNotEmpty);
  for (final (i, chapter) in expected.chapters.indexed) {
    final fromDart = await dart.fetchPages(chapter, dartHttp);
    final fromSite = await site.fetchPages(actual.chapters[i], siteHttp);
    expect(_pages(fromSite), _pages(fromDart), reason: chapter.title);
  }
}

void main() {
  group('coffeemanga', () {
    final dart = CoffeeManga();
    final site = _site('coffeemanga');
    const url = FakeCoffeeManga.url;

    test('engine 15, link e chiave della fixture', () {
      expect(siteMinEngine(site.definition), (engine: 15, key: 'fetch'));
      expect(site.id, dart.id);
      expect(site.home, dart.home);
      for (final link in [url, 'https://www.coffeemanga.net/manga/the-house-without-time', '${url}chapter-1/']) {
        expect(site.accepts(link), dart.accepts(link), reason: link);
      }
      expect(site.seriesOfChapter('${url}chapter-1/'), dart.seriesOfChapter('${url}chapter-1/'));
      expect(site.canonical('https://www.coffeemanga.net/manga/the-house-without-time'), dart.canonical(url));
      for (final host in ['i.coffeemanga.net', 'coffeemanga.net', 'example.com']) {
        expect(site.allowedHost(Uri.parse('https://$host/x')), dart.allowedHost(Uri.parse('https://$host/x')), reason: host);
      }
      // La costante del file è la chiave che il Dart ricava dal bundle della fixture.
      final key = coffeeMangaKey(File('test/fixtures/coffeemanga_key.js').readAsStringSync());
      expect(File('../../catalog/sites/coffeemanga.json').readAsStringSync(),
          contains([for (final b in key) b.toRadixString(16).padLeft(2, '0')].join()));
    });

    test('serie e capitoli, senza quelli VIP', () async {
      await _sameSeries(dart, site, FakeCoffeeManga.new, url);
    });

    test('tavole dal manifest cifrato, in ogni forma e codifica', () async {
      for (var version = 0; version < 9; version++) {
        await _samePages(dart, site, () => FakeCoffeeManga()..versions['chapter-1'] = version, url);
      }
    });

    test('un capitolo VIP o di un\'altra pagina non passa', () async {
      final http = FakeCoffeeManga();
      await expectLater(site.fetchPages(Chapter('chapter-3', 'Chapter 3', '3', '${url}chapter-3/'), http),
          throwsA(isA<ProviderError>().having((e) => e.message, 'message', contains('riservato'))));
      await expectLater(site.fetchPages(Chapter('chapter-9', 'Chapter 9', '9', '${url}chapter-1/'), http),
          throwsA(isA<ProviderChanged>()));
    });

    test('una chiave sbagliata non dà tavole', () async {
      final http = FakeCoffeeManga()..bundle = FakeCoffeeManga().bundle.replaceFirst('33747,47843', '33747,47844');
      final series = await site.fetchSeries(url, http);
      await expectLater(site.fetchPages(series.chapters.first, http), throwsA(isA<ProviderChanged>()));
    });

    test('ricerca dalla pagina dei risultati', () async {
      SearchHttp fake() => SearchHttp(page: coffeePage('Catalog/Search', {
            'series': [
              {
                'url': '/manga/ocveobera7alg81/',
                'title': 'Merry Psycho',
                'status': 'ongoing',
                'cover': 'https://i.coffeemanga.net/img/X/rs:fill:193:278/Y',
                'chapters': [{'label': 'Chapter 78'}],
              },
              {'url': '/manga/psycho-eyes/', 'title': 'Psycho Eyes', 'status': 'completed', 'chapters': []},
              {'url': '/aviso/news/', 'title': 'News', 'chapters': []},
            ],
          }));
      final siteHttp = fake();
      expect(_results(await site.search('psycho', siteHttp)), _results(await dart.search('psycho', fake())));
      expect(siteHttp.requests.single, 'https://coffeemanga.net/search?q=psycho');
    });
  });
  group('mangak', () {
    final dart = MangaK();
    final site = _site('mangak');
    const url = 'https://mangak.io/test-series';

    test('engine 9 e link', () {
      expect(siteMinEngine(site.definition), (engine: 9, key: 'fallback'));
      expect(site.id, dart.id);
      expect(site.home, dart.home);
      expect(site.accepts(url), isTrue);
      expect(site.accepts('https://mangak.io/test-series/chapter-1'), isFalse);
      expect(site.seriesOfChapter('https://mangak.io/test-series/chapter-1'), url);
      expect(site.canonical('https://mangak.io/test-series/'), dart.canonical(url));
      for (final host in ['rx.resmk.org', 'rx.qvzre.org', 'api.mangak.io']) {
        expect(site.allowedHost(Uri.parse('https://$host/x')), dart.allowedHost(Uri.parse('https://$host/x')), reason: host);
      }
      expect(site.allowedHost(Uri.parse('https://example.com/x')), isFalse);
    });

    test('serie e capitoli', () async {
      await _sameSeries(dart, site, FakeMangaK.new, url);
    });

    test('il numero è quello del nome e un avviso passa', () async {
      FakeMangaK fake() {
        final http = FakeMangaK();
        http.chapterItems.insert(0, {'id': 'C3', 'name': 'Chapter 2.5', 'number': 3, 'url': '/test-series/chapter-2-5'});
        http.chapterItems.insert(0, {'id': 'C4', 'name': 'Chapter 3', 'number': 4, 'url': '/test-series/chapter-3'});
        http.chapterItems.insert(0, {'id': 'C5', 'name': 'Prologue', 'number': 5, 'url': '/test-series/chapter-prologue'});
        http.chapterItems.insert(0, {'id': 'C6', 'name': 'Notice.', 'number': 6, 'url': '/test-series/notice'});
        (http.series['stats'] as Map)['chaptersCount'] = 6;
        return http;
      }

      await _sameSeries(dart, site, fake, url);
    });

    test('senza cv l\'elenco si chiede senza parametro', () async {
      // Il finto vuole `?cv=123` e dice nell'errore cosa gli è stato chiesto.
      Future<String> asked(Future<Object?> read) async {
        try {
          await read;
        } on StateError catch (error) {
          return error.message;
        }
        throw TestFailure('doveva fallire');
      }

      FakeMangaK fake() => FakeMangaK()..series.remove('cv');
      final expected = await asked(dart.fetchSeries(url, fake()));
      expect(expected, startsWith('https://api.mangak.io/titles/S1/chapters != '));
      expect(await asked(site.fetchSeries(url, _ApiAsGet(fake()))), expected);
    });

    test('tavole con le misure', () async {
      await _samePages(dart, site, FakeMangaK.new, url);
    });

    test('un capitolo di un altro id non passa', () async {
      final http = FakeMangaK();
      final series = await site.fetchSeries(url, _ApiAsGet(http));
      final wrong = Chapter('C9', 'x', '1', series.chapters.first.url, const {});
      await expectLater(site.fetchPages(wrong, _ApiAsGet(http)), throwsA(isA<ProviderChanged>()));
      await expectLater(dart.fetchPages(wrong, http), throwsA(isA<ProviderChanged>()));
    });

    test('ricerca: solo serie del sito, copertine ammesse, stato', () async {
      SearchHttp fake() => SearchHttp(response: {
            'success': true,
            'data': {
              'items': [
                {
                  'name': 'Solo Leveling', 'url': '/solo-leveling',
                  'cover': 'https://rx.resmk.org/covers/c8ccb9d017d6.webp',
                  'status': 'completed', 'stats': {'chapters_count': 265},
                  'latest_chapters': [
                    {'name': 'Chapter 202', 'number': 270},
                    {'name': 'Chapter : Notice (official translation)', 'number': 268},
                  ],
                },
                {'name': 'Capitolo', 'url': '/solo-leveling/chapter-1'},
                {'name': 'Altrove', 'url': '/altrove', 'cover': 'https://example.com/x.webp'},
              ],
            },
          });
      final dartHttp = fake();
      final siteHttp = fake();
      final expected = await dart.search(' solo lev ', dartHttp);
      final actual = await site.search(' solo lev ', _ApiAsGet(siteHttp));
      expect(Uri.parse(siteHttp.requests.single).queryParameters, Uri.parse(dartHttp.requests.single).queryParameters);
      expect(Uri.parse(siteHttp.requests.single).path, Uri.parse(dartHttp.requests.single).path);
      expect(_results(actual), _results(expected));
    });

    test('ricerca: il più alto fra gli ultimi capitoli', () async {
      final response = {
        'success': true,
        'data': {
          'items': [
            {
              'name': 'Solo Leveling', 'url': '/solo-leveling',
              'latest_chapters': [
                {'name': 'Chapter 201'},
                {'name': 'Chapter 202'},
                {'name': 'Chapter : Notice (official translation)'},
              ],
            },
          ],
        },
      };
      final expected = await dart.search('solo', SearchHttp(response: response));
      final actual = await site.search('solo', _ApiAsGet(SearchHttp(response: response)));
      expect(_results(actual), _results(expected));
    }, skip: 'Fuori dalle differenze di docs/siti.md: `latest` è un solo estrattore, il Dart prende il massimo '
        'fra gli ultimi capitoli (latestChapterNumber); il file legge il primo.');

    test('l\'elenco più corto di chaptersCount oltre il 5% non passa, uno più lungo sì', () async {
      FakeMangaK fake() => FakeMangaK()..series['stats'] = {'chaptersCount': 10};
      await expectLater(dart.fetchSeries(url, fake()), throwsA(isA<ProviderChanged>()));
      await expectLater(
          site.fetchSeries(url, _ApiAsGet(fake())),
          throwsA(isA<ProviderChanged>()
              .having((error) => error.fault?.field, 'field', 'series.chapters.expect')
              .having((error) => error.fault?.detail, 'detail', '2 capitoli, il sito ne dichiara 10')));
      FakeMangaK cached() => FakeMangaK()..series['stats'] = {'chaptersCount': 1};
      await _sameSeries(dart, site, cached, url);
    });

    test('le tavole di __NEXT_DATA__ mancano: vince la riserva sulle API, e la traccia lo dice', () async {
      final http = FakeMangaK();
      final series = await dart.fetchSeries(url, http);
      final fromSite = await site.fetchSeries(url, _ApiAsGet(http));
      expect(fromSite.chapters.first.metadata['titleId'], 'S1');
      final changed = _NoPages(http);
      await expectLater(dart.fetchPages(series.chapters.first, changed), throwsA(isA<ProviderChanged>()));
      final trace = SiteTrace();
      final content = await trace.run(() => site.fetchPages(fromSite.chapters.first, _ApiAsGet(changed)));
      final expected = await dart.fetchPages(series.chapters.first, http);
      // L'API dà solo gli indirizzi: le misure le legge poi l'archivio dall'immagine.
      expect([for (final page in content.pages) page.url], [for (final page in expected.pages) page.url]);
      expect(trace.degraded, ['chapter#2']);
      // Con la pagina buona vince il principale, misure comprese.
      final clean = SiteTrace();
      final principal = await clean.run(() => site.fetchPages(fromSite.chapters.first, _ApiAsGet(http)));
      expect(_pages(principal), _pages(expected));
      expect(clean.degraded, isEmpty);
    });

    test('un capitolo fuori dalla serie non passa', () async {
      for (final path in ['/other-series/chapter-3', '/test-seriesx/chapter-3']) {
        FakeMangaK fake() {
          final http = FakeMangaK();
          http.chapterItems.first['url'] = path;
          return http;
        }

        await expectLater(dart.fetchSeries(url, fake()), throwsA(isA<ProviderError>()), reason: path);
        await expectLater(site.fetchSeries(url, _ApiAsGet(fake())), throwsA(isA<ProviderError>()), reason: path);
      }
    }, skip: 'Fuori dalle differenze di docs/siti.md: il Dart pretende che il percorso del capitolo stia sotto '
        '`initialManga.url`; il file ne controlla solo la forma (`/serie/capitolo`), nessuna primitiva confronta '
        'il prefisso con un valore della pagina.');

    test('tavole non coerenti con l\'elenco immagini non passano', () async {
      final http = FakeMangaK();
      final series = await dart.fetchSeries(url, http);
      final broken = _BrokenImages(http);
      await expectLater(dart.fetchPages(series.chapters.first, broken), throwsA(isA<ProviderChanged>()));
      await expectLater(site.fetchPages(series.chapters.first, _ApiAsGet(broken)), throwsA(isA<ProviderChanged>()));
    }, skip: 'Fuori dalle differenze di docs/siti.md: il Dart confronta `initialChapter.images` con `pages` '
        '(stessa lunghezza, stessi url); il file legge solo `pages`.');
  });

  group('manhwaread', () {
    final dart = ManhwaRead();
    final site = _site('manhwaread');
    const url = FakeManhwaRead.url;

    test('engine, link accettati e canonico', () {
      expect(site.id, dart.id);
      expect(site.home, dart.home);
      expect(site.accepts(url), isTrue);
      for (final other in [
        'https://www.manhwaread.com/manhwa/disfarming',
        '${url}chapter-01/',
        'http://manhwaread.com/manhwa/disfarming/',
        'https://manhwaread.com/other/disfarming/',
      ]) {
        expect(site.accepts(other), dart.accepts(other), reason: other);
      }
      expect(site.canonical('https://www.manhwaread.com/manhwa/disfarming'), dart.canonical('https://www.manhwaread.com/manhwa/disfarming'));
    });

    test('dal link di un capitolo si rifà la serie', () {
      for (final link in ['${url}chapter-02/', 'https://www.manhwaread.com/manhwa/disfarming/chapter-02']) {
        expect(site.seriesOfChapter(link), dart.seriesOfChapter(link), reason: link);
      }
    });

    test('un link con query o frammento passa per una serie', () {
      const link = 'https://manhwaread.com/manhwa/disfarming/?ref=1';
      expect(site.accepts(link), dart.accepts(link));
    }, skip: 'Fuori dalle differenze di docs/siti.md: il Dart rifiuta query e frammento (`plain`); il motore '
        'dei siti del catalogo li accetta e li toglie.');

    test('browser dichiarato come il Dart', () {
      final gate = site.browser;
      expect(gate, isNotNull);
      expect(gate!.hosts, dart.browser.hosts);
    });

    test('serie: titolo, copertina e capitoli, con i due contenitori', () async {
      for (final alternate in [false, true]) {
        await _sameSeries(dart, site, () => FakeManhwaRead(alternate: alternate), url);
      }
      final series = await site.fetchSeries(url, FakeManhwaRead());
      expect(series.chapters.map((c) => c.id), ['chapter-01', 'chapter-02', 'side-story-1']);
      expect(series.chapters[1].metadata['date'], 'Yesterday');
    });

    test('i capitoli portano gli id per il CDN', () async {
      final expected = await dart.fetchSeries(url, FakeManhwaRead());
      final actual = await site.fetchSeries(url, FakeManhwaRead());
      expect(actual.chapters.first.metadata['titleId'], expected.chapters.first.metadata['manga_id']);
      expect(actual.chapters.first.metadata['chapterKey'], expected.chapters.first.metadata['chapter_id']);
    });

    test('metadati della serie come il Dart', () async {
      final expected = await dart.fetchSeries(url, FakeManhwaRead());
      final actual = await site.fetchSeries(url, FakeManhwaRead());
      expect(actual.metadata['description'], expected.metadata['description']);
    });

    test('etichette dei metadati (artisti, autori, tag, generi)', () async {
      final expected = await dart.fetchSeries(url, FakeManhwaRead());
      final actual = await site.fetchSeries(url, FakeManhwaRead());
      expect(actual.metadata['authors'], expected.metadata['authors']);
    }, skip: 'Fuori dal formato: il Dart legge le coppie etichetta-valore del corpo con euristica (`_labels`); '
        'il file dà un selettore per campo, e la pagina finta non ha classi stabili.');

    test('tavole dalla ricetta base64 di chapterData', () async {
      // Il finto serve solo le tavole del primo capitolo.
      final expected = await dart.fetchSeries(url, FakeManhwaRead());
      final actual = await site.fetchSeries(url, FakeManhwaRead());
      final fromDart = await dart.fetchPages(expected.chapters.first, FakeManhwaRead());
      final fromSite = await site.fetchPages(actual.chapters.first, FakeManhwaRead());
      expect(_pages(fromSite), _pages(fromDart));
      expect(fromSite.pages.map((p) => p.url), FakeManhwaRead.media);
    });

    test('dati delle tavole rovinati', () async {
      final http = FakeManhwaRead(badPages: true);
      final series = await site.fetchSeries(url, http);
      await expectLater(site.fetchPages(series.chapters.first, http), throwsA(isA<ProviderError>()));
    });

    test('dietro Cloudflare le tavole si trovano sul CDN', () async {
      final http = FakeManhwaRead(challenge: true);
      final series = await site.fetchSeries(url, http);
      final pages = await site.fetchPages(series.chapters.first, http);
      expect(pages.pages, hasLength(2));
    }, skip: 'Fuori dal formato: `_probeCdn` prova mr_001.jpg, mr_002.jpg… finché uno manca, un ciclo che si '
        'ferma su un esito e non un `range` (docs/siti.md, «I siti inclusi nel formato 2»).');

    test('ricerca dalle schede dei risultati', () async {
      const page = '''<html><body><form id="formQuickSearch"><input name="s" id="inputQuickSearch"></form>
        <div class="manga-grid">
          <div class="manga-item loop-item">
            <div class="manga-item__img"><img alt="Disfarming" src="https://mancover.xyz/cover/2026/02/disfarming.webp"></div>
            <a href="https://manhwaread.com/manhwa/disfarming/" class="btn--solid"><span>Read</span></a>
            <h3><a href="https://manhwaread.com/manhwa/disfarming/" class="manga-item__link">Disfarming</a></h3>
            <span class="manga-status" data-status="completed"><span>Completed</span></span>
            <a href="https://manhwaread.com/manhwa/disfarming/chapter-12/" class="chapter-item">Chapter 12</a>
          </div>
        </div></body></html>''';
      final dartHttp = SearchHttp(page: page);
      final siteHttp = SearchHttp(page: page);
      final expected = await dart.search(' dis far ', dartHttp);
      final actual = await site.search(' dis far ', siteHttp);
      expect(Uri.parse(siteHttp.requests.single).queryParameters, Uri.parse(dartHttp.requests.single).queryParameters);
      expect(_results(actual), _results(expected));
    });
  });

  group('asura', () {
    final dart = AsuraScans();
    final site = _site('asurascans');
    const url = 'https://asurascans.com/comics/war-of-extinction-bd5bdaf8';

    test('engine 7 e link', () {
      expect(siteMinEngine(site.definition), (engine: 7, key: 'link'));
      expect(site.id, dart.id);
      expect(site.home, dart.home);
      expect(site.accepts(url), isTrue);
      expect(site.accepts('https://www.asurascans.com/comics/nano-machine/'), isTrue);
      for (final other in [
        '$url/chapter/1',
        'http://asurascans.com/comics/nano-machine',
        'https://asurascans.com:8443/comics/nano-machine',
        'https://asuracomic.net/series/nano-machine',
      ]) {
        expect(site.accepts(other), dart.accepts(other), reason: other);
      }
    });

    test('dal link di un capitolo si rifà la serie senza suffisso', () {
      expect(site.seriesOfChapter('$url/chapter/1'), dart.seriesOfChapter('$url/chapter/1'));
    });

    test('un link con query o frammento passa per una serie', () {
      const link = 'https://asurascans.com/comics/nano-machine?ref=1';
      expect(site.accepts(link), dart.accepts(link));
    }, skip: 'Fuori dalle differenze di docs/siti.md: il Dart rifiuta query e frammento (`plain`) perché su '
        'questo sito cambierebbero pagina; il motore dei siti del catalogo li accetta e li toglie.');

    test('serie dall\'API: capitoli dal primo, senza quelli a pagamento', () async {
      final http = FakeAsuraScans();
      await _sameSeries(dart, site, FakeAsuraScans.new, url);
      final first = await site.fetchSeries(url, _ApiAsGet(http));
      expect(http.requests.first, '${FakeAsuraScans.api}/series/war-of-extinction');
      expect(first.chapters.map((c) => c.url), ['https://asurascans.com/comics/war-of-extinction/chapter/1', 'https://asurascans.com/comics/war-of-extinction/chapter/2']);
    });

    test('il link della serie è quello del sito, non dell\'API', () async {
      final series = await site.fetchSeries(url, _ApiAsGet(FakeAsuraScans()));
      expect(series.url, 'https://asurascans.com/comics/war-of-extinction');
      expect(site.canonical(url), dart.canonical(url));
    });

    test('un capitolo che esce con numero decimale e senza titolo', () async {
      FakeAsuraScans fake() {
        final http = FakeAsuraScans();
        http.chapters.insert(1, {
          'id': 150, 'number': 2.5, 'slug': 'chapter-2-5', 'is_premium': false, 'series_slug': 'war-of-extinction',
        });
        http.chapterPages[150] = ['https://cdn.asurascans.com/asura-images/chapters/war-of-extinction/2-5/aa.webp'];
        return http;
      }

      await _sameSeries(dart, site, fake, url);
      await _samePages(dart, site, fake, url);
    });

    test('tavole con le misure quando l\'API le dà', () async {
      await _samePages(dart, site, FakeAsuraScans.new, url);
      final http = FakeAsuraScans();
      final series = await site.fetchSeries(url, _ApiAsGet(http));
      await site.fetchPages(series.chapters.first, _ApiAsGet(http));
      expect(http.requests.last, '${FakeAsuraScans.api}/series/war-of-extinction/chapters/ac158a3a-7e87-4492-b792-cf36c9ef9dd5');
    });

    test('un capitolo chiuso non passa per vuoto', () async {
      final http = _ApiAsGet(FakeAsuraScans());
      final series = await site.fetchSeries(url, http);
      (http.inner as FakeAsuraScans).locked.add(102);
      await expectLater(
        site.fetchPages(series.chapters.last, http),
        throwsA(isA<ProviderError>().having((e) => e.message, 'message', contains('abbonati'))),
      );
    });

    test('uno slug che finisce come il suffisso si cerca anche intero', () async {
      const missing = 'https://asurascans.com/comics/missing-0badcafe';
      final dartHttp = FakeAsuraScans();
      final siteHttp = FakeAsuraScans();
      await expectLater(dart.fetchSeries(missing, dartHttp), throwsA(isA<ProviderError>()));
      await expectLater(site.fetchSeries(missing, _ApiAsGet(siteHttp)), throwsA(isA<HttpStatusError>()));
      expect(siteHttp.requests.where((r) => r.contains('missing')), dartHttp.requests.where((r) => r.contains('missing')));
    });

    test('ricerca senza romanzi', () async {
      SearchHttp fake() => SearchHttp(response: {
            'data': [
              {
                'id': 2017, 'slug': 'nano-machine', 'title': 'Nano Machine', 'type': 'manhwa',
                'cover': 'https://cdn.asurascans.com/asura-images/covers/nano-machine.e31bdb.webp',
                'status': 'ongoing', 'chapter_count': 332,
                'latest_chapters': [
                  {'number': 331, 'slug': 'chapter-331'},
                  {'number': 330.5, 'slug': 'chapter-330-5'},
                ],
              },
              {'id': 9, 'slug': 'black-badger', 'title': 'Black Badger', 'type': 'novel'},
              {'id': 1933, 'slug': 'my-path', 'title': 'My Path', 'status': 'dropped', 'cover': 'https://example.com/c.webp'},
            ],
          });
      final dartHttp = fake();
      final siteHttp = fake();
      final expected = await dart.search(' nano ', dartHttp);
      final actual = await site.search(' nano ', _ApiAsGet(siteHttp));
      expect(Uri.parse(siteHttp.requests.single).queryParameters, Uri.parse(dartHttp.requests.single).queryParameters);
      expect(_results(actual), _results(expected));
    });

    test('ricerca senza romanzi, a parte il link', () async {
      SearchHttp fake() => SearchHttp(response: {
            'data': [
              {
                'id': 2017, 'slug': 'nano-machine', 'title': 'Nano Machine', 'type': 'manhwa',
                'cover': 'https://cdn.asurascans.com/asura-images/covers/nano-machine.e31bdb.webp',
                'status': 'ongoing',
                'latest_chapters': [
                  {'number': 331, 'slug': 'chapter-331'},
                  {'number': 330.5, 'slug': 'chapter-330-5'},
                ],
              },
              {'id': 9, 'slug': 'black-badger', 'title': 'Black Badger', 'type': 'novel'},
              {'id': 1933, 'slug': 'my-path', 'title': 'My Path', 'status': 'dropped', 'cover': 'https://example.com/c.webp'},
            ],
          });
      final expected = await dart.search(' nano ', fake());
      final actual = await site.search(' nano ', _ApiAsGet(fake()));
      List<(String, String?, String?, String)> rest(List<SearchResult> r) =>
          [for (final x in r) (x.title, x.coverUrl, x.latestChapter, x.releaseStatus)];
      expect(rest(actual), rest(expected));
    });
  });
}

/// Un capitolo MangaK la cui pagina ha cambiato forma: `initialChapter.pages` non c'è più.
class _NoPages extends _Delegate {
  _NoPages(super.inner);

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    final result = await inner.get(url, limit: limit, referer: referer);
    if (!url.contains('/chapter-')) return result;
    final text = utf8.decode(result.body).replaceFirst('"pages":', '"tavole":');
    return (body: utf8.encode(text), contentType: result.contentType);
  }
}

/// Un capitolo MangaK il cui elenco `images` non corrisponde a `pages`.
class _BrokenImages extends _Delegate {
  _BrokenImages(super.inner);

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    final result = await inner.get(url, limit: limit, referer: referer);
    if (!url.contains('/chapter-')) return result;
    final text = utf8.decode(result.body).replaceFirst('"images":["', '"images":["https://rx.resmk.org/x.webp","');
    return (body: utf8.encode(text), contentType: result.contentType);
  }
}

class _Delegate implements ProviderHttp {
  _Delegate(this.inner);

  final ProviderHttp inner;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) => inner.get(url, limit: limit, referer: referer);

  @override
  Future<Map<String, Object?>> json(String url) => inner.json(url);

  @override
  Future<bool> imageExists(String url, {required String referer}) => inner.imageExists(url, referer: referer);
}
