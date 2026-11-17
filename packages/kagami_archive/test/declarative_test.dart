// I siti degli utenti: il file si valida per intero all'installazione, e un
// sito descritto si comporta come uno incluso (link, serie, tavole, ricerca).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/renderer.dart';
import 'package:kagami_archive/site_engine.dart';
import 'package:kagami_archive/stores.dart';
import 'package:test/test.dart';

import 'archive_fakes.dart' show ChallengedHttp;

/// Risponde da memoria e ricorda cosa si è chiesto.
class MapHttp implements ProviderHttp {
  MapHttp(this.pages);

  final Map<String, String> pages;
  final List<String> asked = [];

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    asked.add(url);
    final page = pages[url];
    if (page == null) throw HttpStatusError(404);
    return (body: Uint8List.fromList(utf8.encode(page)), contentType: 'text/html');
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => decodeJsonObject((await get(url)).body);
}

Map<String, Object?> htmlSite() => {
      'format': 1,
      'id': 'examplescans',
      'name': 'Example Scans',
      'version': 2,
      'update': 'https://raw.githubusercontent.com/someone/sites/main/examplescans.json',
      'home': 'https://examplescans.com',
      'hosts': ['examplescans.com'],
      'mediaHosts': ['*.examplecdn.net'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'url': 'https://examplescans.com/manga/{id}',
        'title': 'h1.title',
        'cover': {'css': 'div.thumb img', 'attr': ['data-src', 'src']},
        'description': {'css': 'div.summary', 'html': true},
        'status': 'div.status',
        'genres': {'css': 'div.genres a', 'all': true},
        'alternativeTitles': {'css': 'div.alt', 'split': '[,;]'},
        'chapters': {
          'items': 'ul.chapters li',
          'url': {'css': 'a', 'attr': 'href'},
          'title': 'a',
          'date': 'span.date',
          'id': {'from': 'url', 'regex': r'/chapter-([a-z0-9-]+)/?$'},
        },
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'div.reader img', 'url': {'attr': ['data-src', 'src']}},
      },
      'search': {
        'url': 'https://examplescans.com/?s={query}',
        'items': 'div.result',
        'title': 'h3 a',
        'link': {'css': 'h3 a', 'attr': 'href'},
        'cover': {'css': 'img', 'attr': 'src'},
        'latest': 'span.latest',
      },
    };

const String seriesPage = '''
<html><body>
<h1 class="title"> The  Long Road </h1>
<div class="thumb"><img data-src="https://img.examplecdn.net/long-road.webp"></div>
<div class="summary"><p>First.</p><p>Second.</p></div>
<div class="status">Ongoing</div>
<div class="genres"><a>Action</a><a>Drama</a></div>
<div class="alt">Il lungo cammino; La route</div>
<ul class="chapters">
  <li><a href="/manga/long-road/chapter-2/">Chapter 2</a><span class="date">2026-10-02</span></li>
  <li><a href="/manga/long-road/chapter-1-5/">Chapter 1.5</a><span class="date">2026-09-20</span></li>
  <li><a href="/manga/long-road/chapter-1/">Chapter 1</a><span class="date">2026-09-01</span></li>
</ul>
</body></html>''';

const String chapterPage = '''
<div class="reader">
  <img data-src="https://img.examplecdn.net/1.webp">
  <img src="https://img.examplecdn.net/2.webp">
</div>''';

const String searchPage = '''
<div class="result"><h3><a href="/manga/long-road/">The Long Road</a></h3><img src="https://img.examplecdn.net/c.webp"><span class="latest">Chapter 2</span></div>
<div class="result"><h3><a href="https://elsewhere.com/manga/x">Fuori</a></h3></div>''';

void main() {
  formatTwo();
  pageEdges();
  renderedPages();
  expectAndFallback();
  group('validazione', () {
    test('un file completo si legge e torna uguale', () {
      final site = DeclarativeProvider.fromJson(htmlSite());
      expect(site.id, 'examplescans');
      expect(site.version, 2);
      expect(site.builtIn, isFalse);
      expect(site.searchable, isTrue);
      expect(jsonDecode(utf8.decode(site.encode())), htmlSite());
    });

    Map<String, Object?> changed(void Function(Map<String, Object?> json) edit) {
      final json = jsonDecode(jsonEncode(htmlSite())) as Map<String, Object?>;
      edit(json);
      return json;
    }

    final bad = <String, void Function(Map<String, Object?>)>{
      'formato sconosciuto': (json) => json['format'] = 3,
      'id con maiuscole': (json) => json['id'] = 'Example',
      'versione zero': (json) => json['version'] = 0,
      'host IP': (json) => json['hosts'] = ['192.168.1.10'],
      'localhost': (json) => json['hosts'] = ['localhost'],
      'host di casa': (json) => json['hosts'] = ['nas.lan'],
      'jolly sulle pagine': (json) => json['hosts'] = ['*.examplescans.com'],
      'jolly su un dominio intero': (json) => json['mediaHosts'] = ['*.net'],
      'home altrove': (json) => json['home'] = 'https://other.com',
      'home in http': (json) => json['home'] = 'http://examplescans.com',
      'regex rotta': (json) => (json['series'] as Map)['path'] = '([a-z',
      'quantificatori annidati (a+)+': (json) => (json['series'] as Map)['path'] = r'^/(a+)+$',
      'quantificatori annidati (\\w*)*': (json) => (json['series'] as Map)['path'] = r'^/(\w*)*$',
      'quantificatori annidati (.*a){2,}': (json) => (json['series'] as Map)['path'] = r'^/(.*a){2,}$',
      'annidati su due livelli': (json) => (json['series'] as Map)['path'] = r'^/((a|b+)c)*$',
      'backreference': (json) => (json['series'] as Map)['path'] = r'^/(a)\1$',
      'split annidato': (json) => ((json['series'] as Map)['alternativeTitles'] as Map)['split'] = r'(,+)+',
      'regex lunghissima': (json) => (json['series'] as Map)['path'] = 'a' * 301,
      'segnaposto nell\'host': (json) => (json['series'] as Map)['url'] = 'https://{id}.examplescans.com/x',
      'ricerca altrove': (json) => (json['search'] as Map)['url'] = 'https://evil.com/?s={query}',
      'chiave sconosciuta': (json) => (json['series'] as Map)['title'] = {'xpath': '//h1'},
      'senza capitoli': (json) => (json['series'] as Map).remove('chapters'),
      'ordine inventato': (json) => ((json['series'] as Map)['chapters'] as Map)['order'] = 'random',
    };
    for (final MapEntry(key: name, value: edit) in bad.entries) {
      test('rifiuta: $name', () {
        expect(() => DeclarativeProvider.fromJson(changed(edit)), throwsA(isA<SiteDefinitionError>()));
      });
    }

    test('regex senza annidamenti passano, anche con gruppi e ripetizioni limitate', () {
      for (final source in [r'^/manga/([a-z0-9-]+)/?$', r'(\d+)(?:-(\d+))?', r'^(?:a|b)+$', r'(ab){2}', r'(a+)?', r'[(+*]+(x)', r'\(a+\)+']) {
        final json = changed((json) => (json['series'] as Map)['path'] = source);
        expect(() => DeclarativeProvider.fromJson(json), returnsNormally, reason: source);
      }
    });

    test('un testo che non è JSON, o troppo grande, non si installa', () {
      expect(() => DeclarativeProvider.parse('{'), throwsA(isA<SiteDefinitionError>()));
      expect(() => DeclarativeProvider.parse('"x"'), throwsA(isA<SiteDefinitionError>()));
      final huge = changed((json) => json['name'] = 'x' * 70000);
      expect(() => DeclarativeProvider.fromJson(huge), throwsA(isA<SiteDefinitionError>()));
    });
  });

  group('un sito in HTML', () {
    final site = DeclarativeProvider.fromJson(htmlSite());

    test('link di serie e di capitolo, host consentiti', () {
      expect(site.accepts('https://examplescans.com/manga/long-road/'), isTrue);
      expect(site.accepts('http://examplescans.com/manga/long-road'), isFalse);
      expect(site.accepts('https://examplescans.com:8443/manga/long-road'), isFalse);
      expect(site.accepts(site.home), isFalse);
      expect(site.seriesOfChapter('https://examplescans.com/manga/long-road/chapter-3'),
          'https://examplescans.com/manga/long-road');
      expect(site.allows('https://img.examplecdn.net/a.webp'), isTrue);
      expect(site.allows('https://examplecdn.net.evil.com/a.webp'), isFalse);
      expect(site.allows('https://evil.com/a.webp'), isFalse);
    });

    test('la serie: titolo, metadati, copertina e capitoli dal primo', () async {
      final http = MapHttp({'https://examplescans.com/manga/long-road': seriesPage});
      final series = await site.fetchSeries('https://examplescans.com/manga/long-road/?ref=x', http);
      expect(series.key, 'examplescans:long-road');
      expect(series.title, 'The Long Road');
      expect(series.url, 'https://examplescans.com/manga/long-road');
      expect(series.coverUrl, 'https://img.examplecdn.net/long-road.webp');
      final metadata = normalizeMetadata(series.metadata);
      expect(metadata['description'], 'First.\n\nSecond.');
      expect(metadata['releaseStatus'], 'ongoing');
      expect(metadata['genres'], ['Action', 'Drama']);
      expect(metadata['alternativeTitles'], ['Il lungo cammino', 'La route']);
      expect([for (final chapter in series.chapters) chapter.id], ['1', '1-5', '2']);
      expect([for (final chapter in series.chapters) chapter.number], ['1', '1.5', '2']);
      expect(series.chapters.first.url, 'https://examplescans.com/manga/long-road/chapter-1/');
      expect(series.chapters.first.metadata['date'], '2026-09-01');
    });

    test('le tavole, ognuna su un host del sito', () async {
      final chapter = Chapter('1', 'Chapter 1', '1', 'https://examplescans.com/manga/long-road/chapter-1/');
      final content = await site.fetchPages(chapter, MapHttp({chapter.url: chapterPage}));
      expect([for (final page in content.pages) page.url],
          ['https://img.examplecdn.net/1.webp', 'https://img.examplecdn.net/2.webp']);
      final outside = MapHttp({chapter.url: '<div class="reader"><img src="https://evil.com/1.webp"></div>'});
      expect(() => site.fetchPages(chapter, outside), throwsA(isA<ProviderChanged>()));
      expect(() => site.fetchPages(chapter, MapHttp({chapter.url: '<p></p>'})), throwsA(isA<ProviderChanged>()));
    });

    test('la ricerca scarta ciò che non è suo', () async {
      final results = await site.search('long road', MapHttp({'https://examplescans.com/?s=long+road': searchPage}));
      expect(results, hasLength(1));
      expect(results.single.url, 'https://examplescans.com/manga/long-road');
      expect(results.single.latestChapter, '2');
      expect(results.single.coverUrl, 'https://img.examplecdn.net/c.webp');
    });

    test('una pagina cambiata è ProviderChanged, non una serie vuota', () async {
      final http = MapHttp({'https://examplescans.com/manga/long-road': '<h1 class="title">X</h1>'});
      expect(() => site.fetchSeries('https://examplescans.com/manga/long-road', http), throwsA(isA<ProviderChanged>()));
      final noTitle = MapHttp({'https://examplescans.com/manga/long-road': '<p>niente</p>'});
      expect(() => site.fetchSeries('https://examplescans.com/manga/long-road', noTitle), throwsA(isA<ProviderChanged>()));
    });
  });

  test('un sito con le API in JSON e i dati in uno script', () async {
    final site = DeclarativeProvider.fromJson({
      'format': 1,
      'id': 'apiscans',
      'name': 'Api Scans',
      'version': 1,
      'home': 'https://apiscans.io',
      'hosts': ['apiscans.io', 'api.apiscans.io'],
      'mediaHosts': ['cdn.apiscans.io'],
      'series': {
        'path': r'^/title/([a-z0-9-]+)$',
        'url': 'https://apiscans.io/title/{id}',
        'id': {'css': 'script#data', 'json': 'manga.id'},
        'title': {'css': 'script#data', 'json': 'manga.name'},
        'cover': {'css': 'script#data', 'json': 'manga.cover'},
        'authors': {'css': 'script#data', 'json': 'manga.authors', 'all': true},
        'chapters': {
          'api': 'https://api.apiscans.io/titles/{id}/chapters',
          'items': {'json': 'data.chapters'},
          'url': {'attr': 'path'},
          'title': {'attr': 'name'},
          'id': {'attr': 'id'},
          'order': 'newest-first',
        },
      },
      'chapter': {
        'path': r'^/title/([a-z0-9-]+)/[a-z0-9-]+$',
        'api': 'https://api.apiscans.io/chapters/{id}',
        'pages': {'items': {'json': 'images'}, 'url': {'attr': 'src'}, 'width': {'attr': 'w'}, 'height': {'attr': 'h'}},
      },
      'search': {
        'url': 'https://api.apiscans.io/search?q={query}',
        'json': true,
        'items': {'json': 'items'},
        'title': {'attr': 'name'},
        'link': {'attr': 'url'},
        'status': {'attr': 'status'},
      },
    });
    final http = MapHttp({
      'https://apiscans.io/title/night-garden':
          '<script id="data" type="application/json">{"manga":{"id":"K7","name":"Night Garden","cover":"https://cdn.apiscans.io/k7.webp","authors":[{"name":"A"},{"name":"B"}]}}</script>',
      'https://api.apiscans.io/titles/K7/chapters': jsonEncode({
        'data': {
          'chapters': [
            {'id': 'c2', 'name': 'Chapter 2', 'path': '/title/night-garden/c2'},
            {'id': 'c1', 'name': 'Chapter 1', 'path': '/title/night-garden/c1'},
          ],
        },
      }),
      'https://api.apiscans.io/chapters/c1': jsonEncode({
        'images': [
          {'src': 'https://cdn.apiscans.io/1.webp', 'w': 800, 'h': 1200},
        ],
      }),
      'https://api.apiscans.io/search?q=night': jsonEncode({
        'items': [
          {'name': 'Night Garden', 'url': '/title/night-garden', 'status': 'Completed'},
        ],
      }),
    });
    final series = await site.fetchSeries('https://apiscans.io/title/night-garden', http);
    expect(series.key, 'apiscans:K7');
    expect(series.coverUrl, 'https://cdn.apiscans.io/k7.webp');
    expect(normalizeMetadata(series.metadata)['authors'], ['A', 'B']);
    expect([for (final chapter in series.chapters) chapter.id], ['c1', 'c2']);
    // I link relativi dell'API si risolvono rispetto alla pagina della serie.
    expect(series.chapters.first.url, 'https://apiscans.io/title/night-garden/c1');
    final content = await site.fetchPages(series.chapters.first, http);
    expect(content.pages.single.width, 800);
    expect(content.pages.single.height, 1200);
    final results = await site.search('night', http);
    expect(results.single.releaseStatus, 'completed');
    expect(results.single.url, 'https://apiscans.io/title/night-garden');
  });

  test('le regex vedono al più 64 KB di testo', () async {
    final json = htmlSite();
    (json['series'] as Map)['title'] = {'css': 'h1.title', 'regex': r'(END)'};
    final site = DeclarativeProvider.fromJson(json);
    const url = 'https://examplescans.com/manga/long-road';
    Future<Series> read(String title) {
      final page = '<h1 class="title">$title</h1><ul class="chapters">'
          '<li><a href="/manga/long-road/chapter-1/">Chapter 1</a></li></ul>';
      return site.fetchSeries(url, MapHttp({url: page}));
    }

    expect((await read('short END')).title, 'END');
    // «END» sta oltre i 64 KB: il testo è tagliato prima della regex.
    await expectLater(read('${'x' * 70000}END'), throwsA(isA<ProviderError>()));
  });

  group('browser', () {
    Map<String, Object?> withBrowser([Map<String, Object?>? gate]) => {
          ...htmlSite(),
          'browser': gate ?? {'hosts': ['examplescans.com'], 'seriesReady': 'ul.chapters li', 'searchReady': 'form.search-form'},
        };

    test('un sito con browser lo dichiara, con le espressioni scritte dal motore', () {
      final site = DeclarativeProvider.fromJson(withBrowser());
      expect(site.needsBrowser, isTrue);
      expect(site.browser!.hosts, ['examplescans.com']);
      expect(site.browser!.seriesReady, '!!document.querySelector("ul.chapters li")');
      expect(site.browser!.searchReady, '!!document.querySelector("form.search-form")');
      expect(jsonDecode(utf8.decode(site.encode())), withBrowser());
      expect(DeclarativeProvider.fromJson(htmlSite()).needsBrowser, isFalse);
    });

    test('un selettore con virgolette e backslash resta una stringa sola', () {
      final selector = r'a[href="x\y</script>)"]';
      final site = DeclarativeProvider.fromJson(withBrowser({
        'hosts': ['examplescans.com'],
        'seriesReady': selector,
        'searchReady': 'form',
      }));
      expect(site.browser!.seriesReady, '!!document.querySelector(${jsonEncode(selector)})');
      expect(site.browser!.seriesReady, startsWith('!!document.querySelector("'));
      expect(site.browser!.seriesReady, endsWith('")'));
      expect(jsonDecode(site.browser!.seriesReady.substring('!!document.querySelector('.length, site.browser!.seriesReady.length - 1)), selector);
    });

    test('campi mancanti, host altrui e selettori non validi si rifiutano', () {
      const ok = {'hosts': ['examplescans.com'], 'seriesReady': 'ul', 'searchReady': 'form'};
      final bad = <String, Map<String, Object?>>{
        'browser': {'hosts': ['examplescans.com']},
        'browser.hosts': {'seriesReady': 'ul', 'searchReady': 'form'},
        'browser.hosts vuoto': {...ok, 'hosts': <String>[]},
        'browser.hosts fuori dal sito': {...ok, 'hosts': ['altro.com']},
        'browser.seriesReady': {...ok, 'seriesReady': 'ul[['},
        'browser.searchReady': {...ok, 'searchReady': ''},
      };
      for (final MapEntry(:key, :value) in bad.entries) {
        expect(
          () => DeclarativeProvider.fromJson(withBrowser(value)),
          throwsA(isA<SiteDefinitionError>().having((e) => e.message, 'message', contains(key.split(' ').first))),
          reason: key,
        );
      }
    });

    test('con la verifica, la serie si rilegge dalla pagina del browser', () async {
      final site = DeclarativeProvider.fromJson(withBrowser());
      final browser = _FakeBrowser(seriesPage);
      final read = await readSeries(site, 'https://examplescans.com/manga/long-road/', ChallengedHttp(), browser: browser);
      expect(read.series.title, 'The Long Road');
      expect(read.page, isNotNull);
      expect(browser.opened, ['https://examplescans.com/manga/long-road']);
      final plain = DeclarativeProvider.fromJson(htmlSite());
      await expectLater(readSeries(plain, 'https://examplescans.com/manga/long-road/', ChallengedHttp(), browser: browser),
          throwsA(isA<CloudflareChallenge>()));
    });

    test('registrato, il sito rispetta la regola della verifica sui suoi host', () {
      final site = DeclarativeProvider.fromJson(withBrowser());
      withUserProviders([site], () {
        final registered = providerById('examplescans')!;
        expect(registered.needsBrowser, isTrue);
        for (final host in registered.browser!.hosts) {
          expect(registered.allowedHost(Uri.https(host, '/')), isTrue, reason: host);
        }
      });
    });
  });

  group('registro', () {
    test('un sito degli utenti con l\'id di uno incluso prende il suo posto', () {
      final replacement = DeclarativeProvider.fromJson({...htmlSite(), 'id': 'mangak'});
      final extra = DeclarativeProvider.fromJson(htmlSite());
      withUserProviders([replacement, extra], () {
        expect(providers, hasLength(builtInProviders.length + 1));
        expect(providerById('mangak'), same(replacement));
        expect(providerById('examplescans'), same(extra));
      });
      expect(providerById('mangak')!.builtIn, isTrue);
      expect(providerById('examplescans'), isNull);
    });

    test('la zona segue gli await e non si mescola fra account', () async {
      final one = DeclarativeProvider.fromJson(htmlSite());
      final other = DeclarativeProvider.fromJson({...htmlSite(), 'name': 'Altro'});
      final names = await Future.wait([
        withUserProviders([one], () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return providerById('examplescans')!.name;
        }),
        withUserProviders([other], () async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return providerById('examplescans')!.name;
        }),
      ]);
      expect(names, ['Example Scans', 'Altro']);
    });

    test('una sorgente di siti si rilegge a ogni domanda', () {
      var sites = <Provider>[];
      withUserProviderSource(() => sites, () {
        expect(providerById('examplescans'), isNull);
        sites = [DeclarativeProvider.fromJson(htmlSite())];
        expect(providerById('examplescans'), isNotNull);
      });
    });

    test('installUserProviders vale per tutto il processo', () {
      addTearDown(() => installUserProviders(const []));
      installUserProviders([DeclarativeProvider.fromJson(htmlSite())]);
      expect(providerById('examplescans'), isNotNull);
      expect(resolveLink('https://examplescans.com/manga/long-road/chapter-1').seriesUrl,
          'https://examplescans.com/manga/long-road');
    });
  });

  test('i siti nella libreria: si scrivono, si leggono, un file rotto non ferma gli altri', () async {
    final root = await Directory.systemTemp.createTemp('kagami-sites');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalStore(root.path);
    await saveSite(store, DeclarativeProvider.fromJson(htmlSite()));
    await File('${root.path}/providers/broken.json').writeAsString('{"format": 1}');
    await File('${root.path}/providers/wrongname.json').writeAsString(jsonEncode(htmlSite()));
    final errors = <String>[];
    final sites = await loadSites(store, onError: (file, _) => errors.add(file));
    expect([for (final site in sites) site.id], ['examplescans']);
    expect(errors..sort(), ['broken.json', 'wrongname.json']);
    await removeSite(store, 'examplescans');
    await removeSite(store, 'examplescans');
    expect(await loadSites(store), isEmpty);
  });

  group('tetti per fiducia', () {
    final entry = CatalogSite(id: 'examplescans', state: CatalogSiteState.ok, variants: const []);
    // Una definizione con un campo in più che la porta alla dimensione voluta.
    String sized(int bytes) {
      final json = htmlSite()..['note'] = '';
      final base = utf8.encode(jsonEncode(json)).length;
      json['note'] = 'x' * (bytes - base);
      return jsonEncode(json);
    }

    test('la definizione: 64 KB per l\'utente, 256 KB per il catalogo', () {
      expect(utf8.encode(sized(64 * 1024)).length, 64 * 1024);
      expect(DeclarativeProvider.parse(sized(64 * 1024)).id, 'examplescans');
      expect(() => DeclarativeProvider.parse(sized(64 * 1024 + 1)), throwsA(isA<SiteDefinitionError>()));
      expect(() => DeclarativeProvider.parse(sized(2000000)), throwsA(isA<SiteDefinitionError>()));
      expect(DeclarativeProvider.parse(sized(maxCatalogSiteBytes), catalog: entry).id, 'examplescans');
      expect(() => DeclarativeProvider.parse(sized(maxCatalogSiteBytes + 1), catalog: entry),
          throwsA(isA<SiteDefinitionError>()));
      expect(() => DeclarativeProvider.fromJson(jsonDecode(sized(64 * 1024 + 1)) as Map<String, Object?>),
          throwsA(isA<SiteDefinitionError>()));
      expect(DeclarativeProvider.fromJson(jsonDecode(sized(200 * 1024)) as Map<String, Object?>, catalog: entry).origin,
          ProviderOrigin.catalog);
    });

    test('richieste per operazione', () {
      expect(DeclarativeProvider.fromJson(htmlSite()).requestLimit, 8);
      expect(DeclarativeProvider.fromJson(htmlSite(), catalog: entry).requestLimit, 32);
    });

    test('la risposta: 2 MB per l\'utente, 8 MB per il catalogo', () async {
      final body = '$seriesPage<!--${'x' * 3000000}-->';
      final http = MapHttp({'https://examplescans.com/manga/long-road': body});
      await expectLater(DeclarativeProvider.fromJson(htmlSite()).fetchSeries('https://examplescans.com/manga/long-road', http),
          throwsA(isA<ProviderError>()));
      final series = await DeclarativeProvider.fromJson(htmlSite(), catalog: entry)
          .fetchSeries('https://examplescans.com/manga/long-road', http);
      expect(series.chapters, hasLength(3));
      final huge = MapHttp({'https://examplescans.com/manga/long-road': '$seriesPage<!--${'x' * 8000001}-->'});
      await expectLater(
          DeclarativeProvider.fromJson(htmlSite(), catalog: entry).fetchSeries('https://examplescans.com/manga/long-road', huge),
          throwsA(isA<ProviderError>()));
    });
  });
}

class _FakeBrowser implements PageBrowser {
  _FakeBrowser(this.html);

  final String? html;
  final List<String> opened = [];

  @override
  Future<String?> seriesPage(String url, BrowserGate gate) async {
    opened.add(url);
    return html;
  }
}

/// Risponde con uno stato per gli indirizzi di [statuses], da [pages] gli altri.
class StatusHttp extends MapHttp {
  StatusHttp(super.pages, this.statuses);

  final Map<String, int> statuses;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (statuses[url] case final status?) {
      asked.add(url);
      throw HttpStatusError(status);
    }
    return super.get(url, limit: limit, referer: referer);
  }
}

/// Un sito alla MangaK: id e versione dalla pagina, API composte, link con `base`.
Map<String, Object?> composedSite() => {
      'format': 2,
      'id': 'composed',
      'name': 'Composed',
      'version': 1,
      'home': 'https://mangak.io',
      'hosts': ['mangak.io', 'api.mangak.io'],
      'mediaHosts': ['cdn.mangak.io'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)$',
        'linkVars': {'slug': {'from': 'page', 'regex': r'^https://mangak\.io/manga/([a-z0-9-]+)'}},
        'url': 'https://mangak.io/manga/{slug}',
        'vars': {
          'data': {'css': 'script#__NEXT_DATA__', 'json': 'props.pageProps'},
          'mangaId': {'var': 'data', 'json': 'initialManga.id'},
          'cv': {'var': 'data', 'json': 'initialManga.cv'},
        },
        'title': {'var': 'data', 'json': 'initialManga.name'},
        'chapters': {
          'api': {
            'template': 'https://api.mangak.io/titles/{mangaId}/chapters',
            'query': {'cv': '{cv}', 'lang': 'en'},
          },
          'items': {'json': 'chapters'},
          'vars': {'n': {'json': 'number'}, 'chapterSlug': {'json': 'slug'}, 'mid': {'template': '{mangaId}'}},
          'keep': ['mid'],
          'url': {'json': 'path', 'base': 'https://mangak.io'},
          'title': {'template': 'Chapter {n}'},
          'id': {'var': 'chapterSlug'},
          'order': 'newest-first',
        },
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/[a-z0-9-]+$',
        'api': 'https://api.mangak.io/titles/{mid}/chapters/{chapterId}',
        'pages': {
          'items': {'json': 'pages'},
          'vars': {'file': {'json': 'file'}},
          'url': {'template': '{file}', 'base': 'https://cdn.mangak.io/img/'},
        },
      },
      'search': {
        'url': {'template': 'https://api.mangak.io/search', 'query': {'q': '{query}'}},
        'json': true,
        'items': {'json': 'items'},
        'title': {'first': [{'json': 'title'}, {'json': 'name'}]},
        'link': {'json': 'path', 'base': 'https://mangak.io'},
      },
    };

String nextData(Map<String, Object?> manga) =>
    '<script id="__NEXT_DATA__" type="application/json">${jsonEncode({'props': {'pageProps': {'initialManga': manga}}})}</script>';

Map<String, Object?> edited(Map<String, Object?> Function() base, void Function(Map<String, dynamic> json) edit) {
  final json = jsonDecode(jsonEncode(base())) as Map<String, dynamic>;
  edit(json);
  return json;
}

void formatTwo() {
  group('formato 2', () {
    test('questo motore arriva alla ricetta intera', () {
      expect(siteFormat, 2);
      expect(catalogEngine, 16);
    });

    test('minEngine: il massimo delle chiavi usate, nomi e letterali esclusi', () {
      int engine(Map<String, Object?> json) => siteMinEngine(json).engine;
      expect(siteMinEngine(htmlSite()), (engine: 1, key: null));
      expect(siteMinEngine(htmlSite()..['format'] = 2), (engine: 2, key: 'format'));
      expect(siteMinEngine(composedSite()).engine, 3);
      expect(engine(edited(htmlSite, (json) => json['series']['chapters']['api'] = 'https://examplescans.com/{mangaId}')), 2);
      expect(siteMinEngine(edited(htmlSite, (json) => json['series']['chapters']['api'] = 'https://examplescans.com/{mangaId}')).key,
          '{mangaId}');
      expect(engine(edited(htmlSite, (json) => json['series']['vars'] = {'first': 'h1', 'fetch': 'h2'})), 2);
      expect(engine(edited(htmlSite, (json) => json['series']['title'] = {'first': ['h1']})), 3);
      expect(engine(edited(htmlSite, (json) => json['series']['url'] = {'try': ['x'], 'on': [404]})), 3);
      expect(engine(edited(htmlSite, (json) => json['series']['chapters']['skip'] = [
            {'json': 'p', 'equals': {'fetch': 1, 'recipe': 2}},
          ])), 4);
      expect(siteMinEngine(edited(htmlSite, (json) => json['mediaHosts'] = ['rx.cdn?.org'])), (engine: 5, key: 'mediaHosts'));
      expect(engine(edited(htmlSite, (json) => json['series']['title'] = {'css': 'script', 'jsonAt': 'x'})), 6);
      expect(engine(edited(htmlSite, (json) => json['chapter']['recipe'] = [{'let': 'a', 'get': {'var': 'b'}}])), 10);
      expect(siteMinEngine(edited(htmlSite, (json) => json['chapter']['recipe'] = [
            {'let': 'a', 'base64': '{b}'},
            {'let': 'c', 'fetch': 'https://examplescans.com/x', 'json': true},
          ])), (engine: 15, key: 'fetch'));
    });

    test('il formato 1 non conosce le chiavi nuove; un engine più alto chiede Kagami più nuovo', () {
      for (final edit in <void Function(Map<String, dynamic>)>[
        (json) => json['series']['vars'] = {'x': 'h1'},
        (json) => json['series']['title'] = {'first': ['h1']},
        (json) => json['chapter']['api'] = 'https://examplescans.com/{chapterId}',
      ]) {
        expect(() => DeclarativeProvider.fromJson(edited(htmlSite, edit)),
            throwsA(isA<SiteDefinitionError>().having((error) => error.message, 'message', contains('"format": 2'))));
      }
      // Oggi nessuna chiave va oltre catalogEngine: la più alta si installa, e
      // l'errore di una più nuova dice «Kagami più nuovo».
      final newest = edited(htmlSite, (json) {
        json['format'] = 2;
        json['chapter']['recipe'] = [{'let': 'a', 'fetch': 'https://examplescans.com/x', 'json': true}];
      });
      expect(siteMinEngine(newest), (engine: 15, key: 'fetch'));
      expect(DeclarativeProvider.fromJson(newest), isA<DeclarativeProvider>());
      expect(SiteEngineError(catalogEngine + 1, 'futura').message, contains('Kagami più nuovo'));
    });

    test('un file "format": 2 con le sole chiavi del formato 1 vuol dire la stessa cosa', () async {
      final http = MapHttp({'https://examplescans.com/manga/long-road': seriesPage});
      final one = await DeclarativeProvider.fromJson(htmlSite()).fetchSeries('https://examplescans.com/manga/long-road', http);
      final two = await DeclarativeProvider.fromJson(htmlSite()..['format'] = 2)
          .fetchSeries('https://examplescans.com/manga/long-road', http);
      expect(two.title, one.title);
      expect(two.metadata, one.metadata);
      expect([for (final chapter in two.chapters) [chapter.id, chapter.url, chapter.metadata]],
          [for (final chapter in one.chapters) [chapter.id, chapter.url, chapter.metadata]]);
    });

    test('variabili e modelli: serie, capitoli, tavole e ricerca composti', () async {
      final site = DeclarativeProvider.fromJson(composedSite());
      final http = MapHttp({
        'https://mangak.io/manga/moon': nextData({'id': 'm/7', 'name': 'Moon', 'cv': 'v2'}),
        'https://api.mangak.io/titles/m%2F7/chapters?cv=v2&lang=en': jsonEncode({
          'chapters': [
            {'number': 2, 'slug': 'c-2', 'path': '/manga/moon/c-2'},
            {'number': 1, 'slug': 'c-1', 'path': '/manga/moon/c-1'},
          ],
        }),
        'https://api.mangak.io/titles/m%2F7/chapters/c-1': jsonEncode({
          'pages': [{'file': '1.webp'}, {'file': '2.webp'}],
        }),
        'https://api.mangak.io/search?q=moon+light': jsonEncode({
          'items': [{'name': 'Moon', 'path': '/manga/moon'}],
        }),
      });
      final series = await site.fetchSeries('https://mangak.io/manga/moon', http);
      expect(series.key, 'composed:moon');
      expect(series.title, 'Moon');
      expect(series.url, 'https://mangak.io/manga/moon');
      expect([for (final chapter in series.chapters) chapter.id], ['c-1', 'c-2']);
      expect([for (final chapter in series.chapters) chapter.title], ['Chapter 1', 'Chapter 2']);
      expect(series.chapters.first.url, 'https://mangak.io/manga/moon/c-1');
      expect(series.chapters.first.metadata, {'mid': 'm/7'});
      final content = await site.fetchPages(series.chapters.first, http);
      expect([for (final page in content.pages) page.url],
          ['https://cdn.mangak.io/img/1.webp', 'https://cdn.mangak.io/img/2.webp']);
      final results = await site.search('moon light', http);
      expect(results.single.title, 'Moon');
      expect(results.single.url, 'https://mangak.io/manga/moon');
      // Un parametro vuoto non si scrive.
      final noCv = MapHttp({
        'https://mangak.io/manga/moon': nextData({'id': 'm7', 'name': 'Moon'}),
        'https://api.mangak.io/titles/m7/chapters?lang=en': jsonEncode({
          'chapters': [{'number': 1, 'slug': 'c-1', 'path': '/manga/moon/c-1'}],
        }),
      });
      expect((await site.fetchSeries('https://mangak.io/manga/moon', noCv)).chapters.single.metadata, {'mid': 'm7'});
      // Senza l'id dell'API l'indirizzo non si compone: il sito ha cambiato forma.
      final noId = MapHttp({'https://mangak.io/manga/moon': nextData({'name': 'Moon'})});
      await expectLater(site.fetchSeries('https://mangak.io/manga/moon', noId), throwsA(isA<ProviderChanged>()));
    });

    test('un link di capitolo si riporta alla serie solo se l\'indirizzo chiede soltanto id', () {
      expect(DeclarativeProvider.fromJson(composedSite()).seriesOfChapter('https://mangak.io/manga/moon/c-1'), isNull);
      final plain = edited(composedSite, (json) => json['series']['url'] = 'https://mangak.io/manga/{id}');
      expect(DeclarativeProvider.fromJson(plain).seriesOfChapter('https://mangak.io/manga/moon/c-1'),
          'https://mangak.io/manga/moon');
    });

    group('series.link', () {
      Map<String, Object?> linked() => edited(composedSite, (json) {
            json['series']['url'] = 'https://mangak.io/data/{slug}';
            json['series']['link'] = 'https://mangak.io/manga/{slug}';
          });

      test('engine 7, canonical dal link e Series.url diversi dall\'indirizzo chiesto', () async {
        expect(siteMinEngine(linked()), (engine: 7, key: 'link'));
        final site = DeclarativeProvider.fromJson(linked());
        expect(site.canonical('https://mangak.io/manga/moon'), 'https://mangak.io/manga/moon');
        final http = MapHttp({
          'https://mangak.io/data/moon': nextData({'id': 'm7', 'name': 'Moon', 'cv': 'v2'}),
          'https://api.mangak.io/titles/m7/chapters?cv=v2&lang=en': jsonEncode({
            'chapters': [{'number': 1, 'slug': 'c-1', 'path': '/manga/moon/c-1'}],
          }),
        });
        final series = await site.fetchSeries('https://mangak.io/manga/moon', http);
        expect(http.asked.first, 'https://mangak.io/data/moon');
        expect(series.url, 'https://mangak.io/manga/moon');
      });

      test('un link di capitolo rifà la serie da series.link, con le linkVars del capitolo', () {
        final site = DeclarativeProvider.fromJson(linked());
        expect(site.seriesOfChapter('https://mangak.io/manga/moon/c-1'), 'https://mangak.io/manga/moon');
      });

      test('in format 1 non vale, e un link che il percorso rifiuta non si installa', () {
        expect(() => DeclarativeProvider.fromJson(edited(linked, (json) => json['format'] = 1)),
            throwsA(isA<SiteDefinitionError>()));
        for (final link in ['https://mangak.io/other/{slug}', 'https://evil.com/manga/{slug}', 'https://mangak.io/manga/{nope}']) {
          expect(() => DeclarativeProvider.fromJson(edited(linked, (json) => json['series']['link'] = link)),
              throwsA(isA<SiteDefinitionError>()), reason: link);
        }
        expect(() => DeclarativeProvider.fromJson(edited(linked, (json) => json['series']['link'] = {'try': ['x']})),
            throwsA(isA<SiteDefinitionError>()));
      });

      test('i dati letti non cambiano il link: una variabile della pagina non è ammessa', () {
        expect(() => DeclarativeProvider.fromJson(edited(linked, (json) => json['series']['link'] = 'https://mangak.io/manga/{mangaId}')),
            throwsA(isA<SiteDefinitionError>()));
      });
    });

    final bad = <String, void Function(Map<String, dynamic>)>{
      'modello con una variabile sconosciuta': (json) => json['series']['title'] = {'template': '{nope}'},
      'var sconosciuta': (json) => json['series']['title'] = {'var': 'nope'},
      'variabile scritta due volte': (json) => json['series']['vars']['id'] = 'h1',
      'nome di variabile non valido': (json) => json['series']['vars']['Bad'] = 'h1',
      'nome di variabile troppo lungo': (json) => json['series']['vars']['a${'b' * 32}'] = 'h1',
      'variabile della pagina prima della richiesta': (json) => json['series']['url'] = 'https://mangak.io/manga/{mangaId}',
      'variabile nell\'host': (json) => json['series']['url'] = 'https://{slug}.mangak.io/x',
      'indirizzo composto altrove': (json) => json['series']['chapters']['api']['template'] = 'https://evil.com/{mangaId}',
      'parametro con una variabile sconosciuta': (json) => json['series']['chapters']['api']['query']['x'] = '{nope}',
      'api dei capitoli senza variabili': (json) => json['series']['chapters']['api'] = 'https://api.mangak.io/all',
      'ricerca senza query': (json) => json['search']['url'] = {'template': 'https://api.mangak.io/search', 'query': {'q': 'x'}},
      'chiave sconosciuta nell\'indirizzo': (json) => json['series']['chapters']['api']['path'] = 'x',
      'var e template insieme': (json) => json['series']['title'] = {'var': 'data', 'template': '{cv}'},
      'keep di una variabile non dell\'elemento': (json) => json['series']['chapters']['keep'] = ['mangaId'],
      'keep chiamato date': (json) {
        json['series']['chapters']['vars']['date'] = 'span';
        json['series']['chapters']['keep'] = ['date'];
      },
      'variabile dell\'elemento fuori dall\'elemento': (json) => json['series']['chapters']['items'] = {'var': 'n'},
      'first con altre chiavi': (json) => json['series']['title'] = {'first': ['h1'], 'all': true},
      'first oltre 8': (json) => json['series']['title'] = {'first': List.filled(9, 'h1')},
      'first vuoto': (json) => json['series']['title'] = {'first': []},
      'try oltre 4': (json) => json['series']['url'] = {'try': List.filled(5, 'https://mangak.io/manga/{slug}')},
      'try con un indirizzo altrove': (json) =>
          json['series']['url'] = {'try': ['https://mangak.io/manga/{slug}', 'https://evil.com/{slug}']},
      'on non è uno stato di errore': (json) => json['series']['url'] = {'try': ['https://mangak.io/manga/{slug}'], 'on': [200]},
    };
    for (final MapEntry(key: name, value: edit) in bad.entries) {
      test('rifiuta: $name', () {
        expect(() => DeclarativeProvider.fromJson(edited(composedSite, edit)), throwsA(isA<SiteDefinitionError>()));
      });
    }

    test('al più 64 variabili per operazione, quelle già date comprese', () {
      Map<String, Object?> withVars(int count) => edited(composedSite, (json) {
            json['series'].remove('linkVars');
            json['series']['url'] = 'https://mangak.io/manga/{id}';
            json['series']['chapters']['vars'] = {'n': {'json': 'number'}};
            json['series']['chapters']['keep'] = [];
            json['series']['chapters']['id'] = {'json': 'slug'};
            json['chapter']['api'] = 'https://api.mangak.io/chapters/{chapterId}';
            final vars = json['series']['vars'] as Map<String, dynamic>;
            for (var i = vars.length; i < count; i++) {
              vars['v$i'] = 'h1';
            }
          });
      // id, url, n e le variabili della pagina.
      expect(() => DeclarativeProvider.fromJson(withVars(61)), returnsNormally);
      expect(() => DeclarativeProvider.fromJson(withVars(62)), throwsA(isA<SiteDefinitionError>()));
    });

    test('ripieghi: first per i campi e per gli elenchi', () async {
      final site = DeclarativeProvider.fromJson(edited(composedSite, (json) {
        json['series']['title'] = {'first': [{'var': 'data', 'json': 'initialManga.title'}, {'css': 'h1'}]};
        json['series']['chapters']['items'] = {'first': [{'json': 'data.chapters'}, {'json': 'chapters'}]};
      }));
      final http = MapHttp({
        'https://mangak.io/manga/moon': '${nextData({'id': 'm7'})}<h1>From the page</h1>',
        'https://api.mangak.io/titles/m7/chapters?lang=en': jsonEncode({
          'chapters': [{'number': 1, 'slug': 'c-1', 'path': '/manga/moon/c-1'}],
        }),
      });
      final series = await site.fetchSeries('https://mangak.io/manga/moon', http);
      expect(series.title, 'From the page');
      expect(series.chapters.single.id, 'c-1');
    });

    group('try', () {
      Map<String, Object?> tried({List<int>? on}) => edited(composedSite, (json) {
            json['series']['linkVars'] = {'slug': {'from': 'page', 'regex': r'/manga/([a-z]+)'}};
            json['series']['url'] = {
              'try': ['https://mangak.io/manga/{slug}', 'https://mangak.io/manga/{id}'],
              'on': ?on,
            };
          });
      final pages = {
        'https://mangak.io/manga/moon-1a2b': nextData({'id': 'm7', 'name': 'Moon'}),
        'https://api.mangak.io/titles/m7/chapters?lang=en': jsonEncode({
          'chapters': [{'number': 1, 'slug': 'c-1', 'path': '/manga/moon-1a2b/c-1'}],
        }),
      };

      test('al successivo su 404, e il link canonico resta il primo', () async {
        final site = DeclarativeProvider.fromJson(tried());
        final http = MapHttp(pages);
        final series = await site.fetchSeries('https://mangak.io/manga/moon-1a2b', http);
        expect(http.asked.take(2), ['https://mangak.io/manga/moon', 'https://mangak.io/manga/moon-1a2b']);
        expect(series.url, 'https://mangak.io/manga/moon');
        expect(series.title, 'Moon');
      });

      test('uno stato fuori da on si ferma lì', () async {
        final http = StatusHttp(pages, {'https://mangak.io/manga/moon': 500});
        await expectLater(DeclarativeProvider.fromJson(tried()).fetchSeries('https://mangak.io/manga/moon-1a2b', http),
            throwsA(isA<HttpStatusError>()));
        expect(http.asked, ['https://mangak.io/manga/moon']);
        final gone = StatusHttp(pages, {'https://mangak.io/manga/moon': 410});
        final series =
            await DeclarativeProvider.fromJson(tried(on: [410])).fetchSeries('https://mangak.io/manga/moon-1a2b', gone);
        expect(series.title, 'Moon');
      });

      test('due alternative uguali si chiedono una volta', () async {
        final http = MapHttp({});
        await expectLater(DeclarativeProvider.fromJson(tried()).fetchSeries('https://mangak.io/manga/moon', http),
            throwsA(isA<HttpStatusError>()));
        expect(http.asked, ['https://mangak.io/manga/moon']);
      });

      test('ogni alternativa conta fra le richieste dell\'operazione', () async {
        final site = DeclarativeProvider.fromJson(edited(composedSite, (json) {
          json['series']['chapters']['api'] = {
            'try': [
              for (final n in ['a', 'b', 'c', 'd']) 'https://api.mangak.io/$n/{mangaId}',
            ],
          };
        }));
        final http = MapHttp({'https://mangak.io/manga/moon': nextData({'id': 'm7', 'name': 'Moon'})});
        await expectLater(site.fetchSeries('https://mangak.io/manga/moon', http), throwsA(isA<HttpStatusError>()));
        expect(http.asked, hasLength(5));
      });
    });

    group('filtri e condizioni', () {
      test('filtri: replace col gruppo, lower, trim, number, prefix e suffix, voce per voce', () async {
        final site = DeclarativeProvider.fromJson(edited(composedSite, (json) {
          json['series']['linkVars']['slug']['filters'] = [{'replace': [r'-[0-9a-f]{4}$', '']}];
          json['series']['title'] = {
            'var': 'data',
            'json': 'initialManga.name',
            'filters': [{'replace': [r'^(\w+) (\w+)$', r'$2 $1']}, 'lower', {'suffix': '  '}, 'trim', {'prefix': '» '}],
          };
          json['series']['genres'] = {'var': 'data', 'json': 'initialManga.genres', 'all': true, 'filters': ['lower']};
          json['series']['chapters']['title'] = {'json': 'number', 'filters': ['number', {'prefix': 'Chapter '}]};
          json['series']['chapters']['number'] = {
            'first': [{'json': 'label', 'filters': ['number']}, {'json': 'number', 'filters': ['number']}],
          };
        }));
        final http = MapHttp({
          'https://mangak.io/manga/moon': nextData({'id': 'm7', 'name': 'Moon Light', 'genres': ['Action', 'DRAMA']}),
          'https://api.mangak.io/titles/m7/chapters?lang=en': jsonEncode({
            'chapters': [
              {'number': 2.0, 'label': 'Extra', 'slug': 'c-2', 'path': '/manga/moon/c-2'},
              {'number': 1.5, 'label': '0x1F', 'slug': 'c-1', 'path': '/manga/moon/c-1'},
            ],
          }),
        });
        final series = await site.fetchSeries('https://mangak.io/manga/moon-1a2b', http);
        expect(http.asked.first, 'https://mangak.io/manga/moon');
        expect(series.url, 'https://mangak.io/manga/moon');
        expect(series.title, '» light moon');
        expect(series.metadata['genres'], ['action', 'drama']);
        expect([for (final chapter in series.chapters) chapter.title], ['Chapter 1.5', 'Chapter 2']);
        // Un testo che non è un numero non dà un valore, così first passa oltre.
        expect([for (final chapter in series.chapters) chapter.number], ['1.5', '2']);
      });

      Map<String, Object?> guarded() => edited(composedSite, (json) {
            json['series']['require'] = [{'var': 'mangaId', 'exists': true}];
            json['series']['chapters']['vars']['premium'] = {'json': 'premium'};
            json['series']['chapters']['skip'] = [
              {'var': 'premium', 'equals': true},
              {'json': 'slug', 'matches': '^draft-'},
            ];
            json['chapter']['require'] = [{'json': 'chapter.id', 'equals': '{chapterId}'}];
            json['chapter']['locked'] = {'json': 'locked', 'equals': true};
            json['chapter']['pages']['items'] = {'json': 'chapter.pages'};
            json['chapter']['pages']['skip'] = [{'json': 'ad', 'exists': true}];
            json['search']['require'] = [{'json': 'items', 'exists': true}];
            json['search']['skip'] = [{'json': 'type', 'equals': 'novel', 'not': false}, {'json': 'path', 'exists': false}];
          });

      test('skip scarta, require e locked fermano, ognuno col suo errore', () async {
        final site = DeclarativeProvider.fromJson(guarded());
        final http = MapHttp({
          'https://mangak.io/manga/moon': nextData({'id': 'm7', 'name': 'Moon'}),
          'https://api.mangak.io/titles/m7/chapters?lang=en': jsonEncode({
            'chapters': [
              {'number': 3, 'slug': 'c-3', 'path': '/manga/moon/c-3', 'premium': true},
              {'number': 2, 'slug': 'draft-2', 'path': '/manga/moon/draft-2'},
              {'number': 1, 'slug': 'c-1', 'path': '/manga/moon/c-1', 'premium': false},
            ],
          }),
          'https://api.mangak.io/titles/m7/chapters/c-1': jsonEncode({
            'chapter': {'id': 'c-1', 'pages': [{'file': '1.webp'}, {'file': 'ad.webp', 'ad': true}, {'file': '2.webp'}]},
          }),
          'https://api.mangak.io/titles/m7/chapters/c-9': jsonEncode({
            'chapter': {'id': 'c-1', 'pages': [{'file': '1.webp'}]},
          }),
          'https://api.mangak.io/titles/m7/chapters/c-5': jsonEncode({
            'chapter': {'id': 'c-5', 'pages': [{'file': '1.webp'}]},
            'locked': true,
          }),
          'https://api.mangak.io/search?q=moon': jsonEncode({
            'items': [
              {'name': 'Moon Novel', 'path': '/manga/moon-novel', 'type': 'novel'},
              {'name': 'No link'},
              {'name': 'Moon', 'path': '/manga/moon', 'type': 'manga'},
            ],
          }),
          'https://api.mangak.io/search?q=sun': jsonEncode({'results': []}),
        });
        final series = await site.fetchSeries('https://mangak.io/manga/moon', http);
        expect([for (final chapter in series.chapters) chapter.id], ['c-1']);
        final content = await site.fetchPages(series.chapters.single, http);
        expect([for (final page in content.pages) page.url],
            ['https://cdn.mangak.io/img/1.webp', 'https://cdn.mangak.io/img/2.webp']);
        Chapter other(String id) => Chapter(id, 'Chapter X', 'X', 'https://mangak.io/manga/moon/$id', const {'mid': 'm7'});
        await expectLater(site.fetchPages(other('c-9'), http), throwsA(isA<ProviderChanged>()));
        await expectLater(
            site.fetchPages(other('c-5'), http),
            throwsA(isA<ProviderError>()
                .having((error) => error, 'changed', isNot(isA<ProviderChanged>()))
                .having((error) => error.message, 'message', contains('abbonati'))));
        expect([for (final result in await site.search('moon', http)) result.title], ['Moon']);
        await expectLater(site.search('sun', http), throwsA(isA<ProviderChanged>()));
        final noId = MapHttp({'https://mangak.io/manga/moon': nextData({'name': 'Moon'})});
        await expectLater(site.fetchSeries('https://mangak.io/manga/moon', noId), throwsA(isA<ProviderChanged>()));
      });

      test('equals confronta il testo, i numeri per valore; not nega', () async {
        final site = DeclarativeProvider.fromJson(edited(guarded, (json) {
          json['series']['chapters']['skip'] = [
            {'json': 'number', 'equals': 12},
            {'json': 'slug', 'matches': r'^c-\d+$', 'not': true},
          ];
        }));
        final http = MapHttp({
          'https://mangak.io/manga/moon': nextData({'id': 'm7', 'name': 'Moon'}),
          'https://api.mangak.io/titles/m7/chapters?lang=en': jsonEncode({
            'chapters': [
              {'number': 12.0, 'slug': 'c-12', 'path': '/manga/moon/c-12'},
              {'number': '12', 'slug': 'c-13', 'path': '/manga/moon/c-13'},
              {'number': 11, 'slug': 'x-11', 'path': '/manga/moon/x-11'},
              {'number': 10, 'slug': 'c-10', 'path': '/manga/moon/c-10'},
            ],
          }),
        });
        final series = await site.fetchSeries('https://mangak.io/manga/moon', http);
        expect([for (final chapter in series.chapters) chapter.id], ['c-10']);
      });

      test('un filtro non fa crescere un valore oltre i 2 MB', () async {
        final site = DeclarativeProvider.fromJson(edited(composedSite, (json) {
          json['series']['title'] = {'var': 'data', 'json': 'initialManga.name', 'filters': [{'replace': ['x', 'y' * 1000]}]};
        }));
        final http = MapHttp({'https://mangak.io/manga/moon': nextData({'id': 'm7', 'name': 'x' * 3000})});
        await expectLater(site.fetchSeries('https://mangak.io/manga/moon', http),
            throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('2 MB'))));
      });

      final badConditions = <String, void Function(Map<String, dynamic>)>{
        'filtro sconosciuto': (json) => json['series']['title'] = {'css': 'h1', 'filters': ['upper']},
        'filtri non in lista': (json) => json['series']['title'] = {'css': 'h1', 'filters': 'lower'},
        'replace senza sostituto': (json) => json['series']['title'] = {'css': 'h1', 'filters': [{'replace': ['a']}]},
        'replace con una regex annidata': (json) =>
            json['series']['title'] = {'css': 'h1', 'filters': [{'replace': ['(a+)+', '']}]},
        'filtro con due chiavi': (json) => json['series']['title'] = {'css': 'h1', 'filters': [{'prefix': 'a', 'suffix': 'b'}]},
        'condizione senza prova': (json) => json['series']['require'] = [{'json': 'x'}],
        'condizione con due prove': (json) => json['series']['require'] = [{'json': 'x', 'exists': true, 'equals': 'a'}],
        'equals con una lista': (json) => json['series']['require'] = [{'json': 'x', 'equals': [1]}],
        'equals con una variabile sconosciuta': (json) => json['series']['require'] = [{'json': 'x', 'equals': '{nope}'}],
        'exists non booleano': (json) => json['series']['require'] = [{'json': 'x', 'exists': 'yes'}],
        'skip non in lista': (json) => json['series']['chapters']['skip'] = {'json': 'x', 'exists': true},
        'skip con una variabile della pagina dopo': (json) =>
            json['search']['skip'] = [{'var': 'mangaId', 'exists': true}],
        'locked come lista': (json) => json['chapter']['locked'] = [{'json': 'x', 'exists': true}],
      };
      for (final MapEntry(key: name, value: edit) in badConditions.entries) {
        test('rifiuta: $name', () {
          expect(() => DeclarativeProvider.fromJson(edited(composedSite, edit)),
              throwsA(allOf(isA<SiteDefinitionError>(), isNot(isA<SiteEngineError>()))));
        });
      }
    });

    group('schemi di host', () {
      Map<String, Object?> schemed(List<String> media) => edited(composedSite, (json) => json['mediaHosts'] = media);

      test('? vale una lettera o una cifra, una sola', () async {
        final site = DeclarativeProvider.fromJson(schemed(['rx.qvzr?.org', '*.img??.net']));
        bool allowed(String host) => site.allowedHost(Uri.parse('https://$host/1.webp'));
        expect(allowed('rx.qvzr5.org'), isTrue);
        expect(allowed('rx.qvzrb.org'), isTrue);
        expect(allowed('rx.qvzr.org'), isFalse);
        expect(allowed('rx.qvzrab.org'), isFalse);
        expect(allowed('rx.qvzr-.org'), isFalse);
        expect(allowed('x.rx.qvzr5.org'), isFalse);
        expect(allowed('a.b.img1x.net'), isTrue);
        expect(allowed('img1x.net'), isFalse);
        expect(allowed('mangak.io'), isTrue);
        final pages = DeclarativeProvider.fromJson(edited(composedSite, (json) {
          json['mediaHosts'] = ['rx.qvzr?.org'];
          json['chapter']['pages']['url'] = {'json': 'file'};
        }));
        final http = MapHttp({
          'https://api.mangak.io/titles/m7/chapters/c-1': jsonEncode({
            'pages': [{'file': 'https://rx.qvzr7.org/1.webp'}],
          }),
          'https://api.mangak.io/titles/m7/chapters/c-2': jsonEncode({
            'pages': [{'file': 'https://rx.qvzr77.org/1.webp'}],
          }),
        });
        Chapter chapter(String id) => Chapter(id, 'Chapter', '1', 'https://mangak.io/manga/moon/$id', const {'mid': 'm7'});
        expect((await pages.fetchPages(chapter('c-1'), http)).pages.single.url, 'https://rx.qvzr7.org/1.webp');
        await expectLater(pages.fetchPages(chapter('c-2'), http), throwsA(isA<ProviderChanged>()));
      });

      final badHosts = <String, Map<String, Object?> Function()>{
        'più di 4 ?': () => schemed(['rx.q?????.org']),
        '? nell\'ultima etichetta': () => schemed(['rx.qvzr.or?']),
        '? che non resta un dominio pubblico': () => schemed(['cdn.?.local']),
        '? negli hosts delle pagine': () => edited(composedSite, (json) => json['hosts'] = ['mangak.io', 'api?.mangak.io']),
      };
      for (final MapEntry(key: name, value: site) in badHosts.entries) {
        test('rifiuta: $name', () {
          expect(() => DeclarativeProvider.fromJson(site()),
              throwsA(allOf(isA<SiteDefinitionError>(), isNot(isA<SiteEngineError>()))));
        });
      }
    });

    group('jsonAt', () {
      Map<String, Object?> scripted({Map<String, Object?>? data}) => edited(composedSite, (json) {
            json['chapter'] = {
              'path': r'^/manga/([a-z0-9-]+)/[a-z0-9-]+$',
              'vars': {
                'data': data ?? {'css': 'script', 'all': true, 'jsonAt': r'\bchapterData\s*=\s*'},
                'cdn': {'var': 'data', 'json': 'base', 'filters': [{'replace': [r'/+$', '']}]},
              },
              'pages': {
                'items': {'var': 'data', 'json': 'images'},
                'url': {'json': 'src', 'base': '{cdn}/'},
                'width': {'json': 'w'},
              },
            };
          });
      const chapter = Chapter('c-1', 'Chapter 1', '1', 'https://mangak.io/manga/moon/c-1');
      String page(String script) => '<script>var other = {"base": "nope"};</script><script>$script</script>';

      test('l\'oggetto che segue, a parentesi bilanciate, dal primo elemento in cui si trova', () async {
        final http = MapHttp({
          chapter.url: page('window.chapterData = {"base": "https://cdn.mangak.io/x//", "note": "a } and a \\" {", '
              '"images": [{"src": "1.webp", "w": 800}, {"src": "2.webp"}]}; var chapterData2 = 1;'),
        });
        final content = await DeclarativeProvider.fromJson(scripted()).fetchPages(chapter, http);
        expect([for (final page in content.pages) page.url], ['https://cdn.mangak.io/x/1.webp', 'https://cdn.mangak.io/x/2.webp']);
        expect(content.pages.first.width, 800);
      });

      test('una lista, e dopo jsonAt un percorso json', () async {
        final site = DeclarativeProvider.fromJson(edited(() => scripted(), (json) {
          json['chapter']['vars'] = {
            'images': {'css': 'script', 'all': true, 'jsonAt': r'pages\s*=\s*', 'json': 'src'},
          };
          json['chapter']['pages'] = {'items': {'var': 'images'}, 'url': {'base': 'https://cdn.mangak.io/'}};
        }));
        final http = MapHttp({chapter.url: page('pages = [{"src": "a.webp"}, {"src": "b.webp"}]')});
        final content = await site.fetchPages(chapter, http);
        expect([for (final page in content.pages) page.url], ['https://cdn.mangak.io/a.webp', 'https://cdn.mangak.io/b.webp']);
      });

      test('niente dopo l\'espressione, o un JSON rotto, non dà un valore', () async {
        final site = DeclarativeProvider.fromJson(scripted());
        for (final script in [
          'chapterData = loadData();',
          'chapterData = {"base": "https://cdn.mangak.io/x", images: []}',
          'chapterData = {"base": "https://cdn.mangak.io/x", "images": [',
          'nothing here',
        ]) {
          await expectLater(site.fetchPages(chapter, MapHttp({chapter.url: page(script)})), throwsA(isA<ProviderChanged>()),
              reason: script);
        }
      });

      test('al più 2 MB', () async {
        final entry = CatalogSite(id: 'composed', state: CatalogSiteState.ok, variants: const []);
        final site = DeclarativeProvider.fromJson(scripted(), catalog: entry);
        final http = MapHttp({chapter.url: page('chapterData = {"base": "${'x' * 2100000}", "images": []}')});
        await expectLater(site.fetchPages(chapter, http),
            throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('2 MB'))));
      });

      test('rifiuta un\'espressione non valida o annidata', () {
        for (final pattern in ['(', '(a+)+', 'x' * 301]) {
          expect(() => DeclarativeProvider.fromJson(scripted(data: {'css': 'script', 'jsonAt': pattern})),
              throwsA(allOf(isA<SiteDefinitionError>(), isNot(isA<SiteEngineError>()))));
        }
      });
    });

    test('tetti: modello 64 KB, indirizzo 4 KB, variabile 2 MB', () async {
      final big = DeclarativeProvider.fromJson(edited(composedSite, (json) => json['series']['title'] = {'template': '{cv}{cv}'}));
      final http = MapHttp({'https://mangak.io/manga/moon': nextData({'id': 'm7', 'cv': 'x' * 40000})});
      await expectLater(big.fetchSeries('https://mangak.io/manga/moon', http),
          throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('64 KB'))));
      final long = MapHttp({'https://mangak.io/manga/moon': nextData({'id': 'm' * 5000, 'name': 'Moon'})});
      await expectLater(DeclarativeProvider.fromJson(composedSite()).fetchSeries('https://mangak.io/manga/moon', long),
          throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('4 KB'))));
      final entry = CatalogSite(id: 'composed', state: CatalogSiteState.ok, variants: const []);
      final heavy = DeclarativeProvider.fromJson(
          edited(composedSite, (json) => json['series']['vars']['whole'] = {'css': 'div.big'}),
          catalog: entry);
      final huge = MapHttp({'https://mangak.io/manga/moon': '${nextData({'id': 'm7'})}<div class="big">${'x' * 2100000}</div>'});
      await expectLater(heavy.fetchSeries('https://mangak.io/manga/moon', huge),
          throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('2 MB'))));
    });
  });
}

/// `expect` (engine 8) e `fallback` (engine 9): `docs/siti.md`, «Conteggio
/// dichiarato» e «Blocchi di riserva».
void expectAndFallback() {
  const seriesUrl = 'https://mangak.io/manga/moon';
  const chaptersApi = 'https://api.mangak.io/titles/m7/chapters?lang=en';
  final twoChapters = jsonEncode({
    'chapters': [
      {'number': 2, 'slug': 'c-2', 'path': '/manga/moon/c-2'},
      {'number': 1, 'slug': 'c-1', 'path': '/manga/moon/c-1'},
    ],
  });
  final chapter = Chapter('c-1', 'Chapter 1', '1', 'https://mangak.io/manga/moon/c-1', const {'mid': 'm7'});
  const pagesApi = 'https://api.mangak.io/titles/m7/chapters/c-1';
  const reserveApi = 'https://api.mangak.io/v2/m7/c-1/images';

  group('expect', () {
    Map<String, Object?> counted() => edited(composedSite, (json) {
          json['series']['chapters']['expect'] = {'var': 'data', 'json': 'initialManga.count'};
        });
    MapHttp http(Object? count) => MapHttp({
          seriesUrl: nextData({'id': 'm7', 'name': 'Moon', 'count': ?count}),
          chaptersApi: twoChapters,
        });

    test('engine 8; un elenco più corto è un guasto, uno più lungo va bene', () async {
      expect(siteMinEngine(counted()), (engine: 8, key: 'expect'));
      final site = DeclarativeProvider.fromJson(counted());
      await expectLater(
          site.fetchSeries(seriesUrl, http(10)),
          throwsA(isA<ProviderChanged>()
              .having((error) => error.fault?.field, 'field', 'series.chapters.expect')
              .having((error) => error.fault?.detail, 'detail', '2 capitoli, il sito ne dichiara 10')
              .having((error) => error.fault?.url, 'url', chaptersApi)));
      for (final count in [2, 1, 0, '2', 2.0]) {
        final trace = SiteTrace();
        final series = await trace.run(() => site.fetchSeries(seriesUrl, http(count)));
        expect(series.chapters, hasLength(2), reason: '$count');
        expect(trace.degraded, isEmpty, reason: '$count');
      }
    });

    test('buchi di numerazione entro il 5% non bloccano e la traccia li segna, oltre sono un guasto', () async {
      final site = DeclarativeProvider.fromJson(counted());
      // Due capitoli: dichiarati 3 (uno in meno su 3, tolleranza 1) passa; 4 no.
      final trace = SiteTrace();
      final series = await trace.run(() => site.fetchSeries(seriesUrl, http(3)));
      expect(series.chapters, hasLength(2));
      expect(trace.degraded, ['series.chapters.expect']);
      await expectLater(
          site.fetchSeries(seriesUrl, http(4)),
          throwsA(isA<ProviderChanged>().having((error) => error.fault?.field, 'field', 'series.chapters.expect')));
      expect([for (final n in [1, 20, 21, 270, 400]) chaptersTolerance(n)], [1, 1, 2, 14, 20]);
    });

    test('i capitoli scartati da skip contano', () async {
      final site = DeclarativeProvider.fromJson(edited(counted, (json) {
        json['series']['chapters']['skip'] = [{'json': 'number', 'equals': '2'}];
      }));
      final series = await site.fetchSeries(seriesUrl, http(2));
      expect([for (final chapter in series.chapters) chapter.id], ['c-1']);
      await expectLater(site.fetchSeries(seriesUrl, http(10)), throwsA(isA<ProviderChanged>()));
    });

    test('senza conteggio il controllo si salta e la traccia lo segna', () async {
      final site = DeclarativeProvider.fromJson(counted());
      for (final count in [null, 'molti', -1, 2.5]) {
        final trace = SiteTrace();
        final series = await trace.run(() => site.fetchSeries(seriesUrl, http(count)));
        expect(series.chapters, hasLength(2), reason: '$count');
        expect(trace.degraded, ['series.chapters.expect'], reason: '$count');
      }
    });
  });

  group('fallback', () {
    // Il principale legge `pages` dall'API del capitolo; la riserva un'altra
    // API, con un `first` suo per vedere il percorso interno nella traccia.
    Map<String, Object?> reserved({List<Map<String, Object?>>? extra}) => edited(composedSite, (json) {
          json['chapter']['fallback'] = [
            {
              'api': 'https://api.mangak.io/v2/{mid}/{chapterId}/images',
              'json': true,
              'pages': {
                'items': {'first': [{'json': 'old'}, {'json': 'images'}]},
              },
            },
            ...?extra,
          ];
        });
    final images = jsonEncode({'images': ['https://cdn.mangak.io/r/1.webp', 'https://cdn.mangak.io/r/2.webp']});

    test('engine 9; la riserva vince su ProviderChanged e la traccia la nomina', () async {
      expect(siteMinEngine(reserved()), (engine: 9, key: 'fallback'));
      final site = DeclarativeProvider.fromJson(reserved());
      final http = MapHttp({pagesApi: jsonEncode({'pages': []}), reserveApi: images});
      final trace = SiteTrace();
      final content = await trace.run(() => site.fetchPages(chapter, http));
      expect([for (final page in content.pages) page.url], ['https://cdn.mangak.io/r/1.webp', 'https://cdn.mangak.io/r/2.webp']);
      expect(http.asked, [pagesApi, reserveApi]);
      expect(trace.degraded, ['chapter#2', 'chapter.fallback[0].pages.items#2']);
      // Col principale buono la riserva non si chiede.
      final good = MapHttp({pagesApi: jsonEncode({'pages': [{'file': '1.webp'}]}), reserveApi: images});
      final clean = SiteTrace();
      await clean.run(() => site.fetchPages(chapter, good));
      expect(good.asked, [pagesApi]);
      expect(clean.degraded, isEmpty);
    });

    test('un 404 passa alla riserva; rete, 5xx, 403, 429 e locked no', () async {
      final site = DeclarativeProvider.fromJson(reserved());
      final missing = StatusHttp({reserveApi: images}, {pagesApi: 404});
      expect((await site.fetchPages(chapter, missing)).pages, hasLength(2));
      for (final status in [500, 503, 403, 429]) {
        final http = StatusHttp({reserveApi: images}, {pagesApi: status});
        await expectLater(site.fetchPages(chapter, http),
            throwsA(isA<HttpStatusError>().having((error) => error.status, 'status', status)));
        expect(http.asked, [pagesApi], reason: '$status');
      }
      final offline = _OfflineHttp({reserveApi: images}, pagesApi);
      await expectLater(site.fetchPages(chapter, offline), throwsA(isA<ProviderOffline>()));
      expect(offline.asked, isEmpty);
      final locked = DeclarativeProvider.fromJson(edited(reserved, (json) {
        json['chapter']['locked'] = {'json': 'locked', 'equals': true};
      }));
      final http = MapHttp({pagesApi: jsonEncode({'locked': true, 'pages': []}), reserveApi: images});
      await expectLater(locked.fetchPages(chapter, http),
          throwsA(allOf(isA<ProviderError>(), isNot(isA<ProviderChanged>()))));
      expect(http.asked, [pagesApi]);
    });

    test('se falliscono tutte vale l\'errore del principale, col suo guasto', () async {
      final site = DeclarativeProvider.fromJson(reserved(extra: [
        {'api': 'https://api.mangak.io/v3/{chapterId}', 'json': true, 'pages': {'items': {'json': 'images'}}},
      ]));
      final http = MapHttp({pagesApi: jsonEncode({'pages': []}), reserveApi: jsonEncode({'images': []})});
      final trace = SiteTrace();
      await expectLater(
          trace.run(() => site.fetchPages(chapter, http)),
          throwsA(isA<ProviderChanged>().having((error) => error.fault?.field, 'field', 'chapter.pages.items')));
      expect(http.asked, [pagesApi, reserveApi, 'https://api.mangak.io/v3/c-1']);
      expect(trace.degraded, isEmpty);
    });

    test('in chapters: senza api rilegge la pagina della serie, e search ha le sue', () async {
      final site = DeclarativeProvider.fromJson(edited(composedSite, (json) {
        json['series']['chapters']['fallback'] = [
          {
            'items': {'var': 'data', 'json': 'initialManga.chapters'},
            'vars': {'mid': {'template': '{mangaId}'}},
            'keep': ['mid'],
            'url': {'json': 'path', 'base': 'https://mangak.io'},
            'title': {'json': 'name'},
            'id': {'json': 'slug'},
          },
        ];
        json['search']['fallback'] = [
          {
            'url': 'https://mangak.io/find?q={query}',
            'json': true,
            'items': {'json': 'results'},
            'title': {'json': 'name'},
            'link': {'json': 'path', 'base': 'https://mangak.io'},
          },
        ];
      }));
      final http = MapHttp({
        seriesUrl: nextData({
          'id': 'm7',
          'name': 'Moon',
          'chapters': [{'slug': 'c-1', 'name': 'Chapter 1', 'path': '/manga/moon/c-1'}],
        }),
        'https://mangak.io/find?q=moon': jsonEncode({'results': [{'name': 'Moon', 'path': '/manga/moon'}]}),
      });
      final trace = SiteTrace();
      final series = await trace.run(() => site.fetchSeries(seriesUrl, http));
      expect(series.chapters.single.metadata, {'mid': 'm7'});
      expect(http.asked, [seriesUrl, chaptersApi]);
      final results = await trace.run(() => site.search('moon', http));
      expect(results.single.url, seriesUrl);
      expect(trace.degraded, ['search#2', 'series.chapters#2']);
    });

    test('le richieste delle riserve contano fra le 8 dell\'operazione', () async {
      final site = DeclarativeProvider.fromJson(edited(composedSite, (json) {
        json['series']['chapters']['api'] = {
          'try': [for (final n in ['a', 'b', 'c', 'd']) 'https://api.mangak.io/$n/{mangaId}'],
        };
        json['series']['chapters']['fallback'] = [
          {
            'api': {'try': [for (final n in ['e', 'f', 'g', 'h']) 'https://api.mangak.io/$n/{mangaId}']},
            'items': {'json': 'chapters'},
            'vars': {'mid': {'template': '{mangaId}'}},
            'keep': ['mid'],
            'url': {'json': 'path', 'base': 'https://mangak.io'},
            'title': {'json': 'name'},
          },
        ];
      }));
      final http = MapHttp({seriesUrl: nextData({'id': 'm7', 'name': 'Moon'})});
      // 1 per la serie, 4 del principale, 3 della riserva: la quarta non parte,
      // e l'errore resta quello del principale.
      await expectLater(site.fetchSeries(seriesUrl, http),
          throwsA(isA<HttpStatusError>().having((error) => error.status, 'status', 404)));
      expect(http.asked, hasLength(8));
      expect(http.asked.last, 'https://api.mangak.io/g/m7');
    });

    final rejected = <String, void Function(Map<String, dynamic>)>{
      'più di 2 riserve': (json) => json['chapter']['fallback'] = [
            for (var i = 0; i < 3; i++) {'pages': {'items': 'img'}},
          ],
      'una lista vuota': (json) => json['chapter']['fallback'] = [],
      'riserve annidate': (json) => json['chapter']['fallback'] = [
            {'pages': {'items': 'img'}, 'fallback': [{'pages': {'items': 'img'}}]},
          ],
      'path in una riserva': (json) => json['chapter']['fallback'] = [
            {'path': r'^/x$', 'pages': {'items': 'img'}},
          ],
      'una riserva di chapters con keep diverso': (json) => json['series']['chapters']['fallback'] = [
            {'items': 'li', 'url': 'a', 'title': 'a'},
          ],
      'una riserva che nomina una variabile del principale': (json) => json['chapter']['fallback'] = [
            {'pages': {'items': {'var': 'file'}}},
          ],
    };
    for (final MapEntry(key: name, value: edit) in rejected.entries) {
      test('rifiuta: $name', () {
        expect(() => DeclarativeProvider.fromJson(edited(composedSite, edit)),
            throwsA(allOf(isA<SiteDefinitionError>(), isNot(isA<SiteEngineError>()))));
      });
    }
  });
}

/// Senza rete per [offline], da [pages] gli altri indirizzi.
class _OfflineHttp extends MapHttp {
  _OfflineHttp(super.pages, this.offline);

  final String offline;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (url == offline) throw const ProviderOffline();
    return super.get(url, limit: limit, referer: referer);
  }
}

/// Un browser finto: la pagina resa la dà [pages], e ricorda cosa ha aperto.
class _FakeRenderer implements PageRenderer {
  _FakeRenderer(this.pages);

  final String? Function(String url) pages;
  final List<(String, String)> opened = [];

  @override
  Future<String?> render(String url, {required List<String> hosts, required String ready, required Duration timeout}) async {
    opened.add((url, ready));
    return pages(url);
  }
}

void renderedPages() {
  group('browser.pages', () {
    Map<String, dynamic> jsSite([void Function(Map<String, dynamic> json)? edit]) => edited(htmlSite, (json) {
          json['format'] = 2;
          json['browser'] = {
            'hosts': ['examplescans.com'],
            'seriesReady': 'ul.chapters li',
            'searchReady': 'div.result',
            'chapterReady': 'div.reader img',
            'pages': ['series', 'chapter', 'search'],
          };
          edit?.call(json);
        });
    // La pagina scaricata è il guscio vuoto che il JavaScript riempie.
    const shell = '<html><body><div id="app"></div></body></html>';
    final http = MapHttp({
      'https://examplescans.com/manga/long-road': shell,
      'https://examplescans.com/manga/long-road/chapter-1/': shell,
    });
    String? rendered(String url) => url.contains('/chapter-')
        ? chapterPage
        : url.contains('?s=')
            ? searchPage
            : seriesPage;

    tearDown(() => installPageRenderer(null));

    test('la definizione legge dal DOM reso, con le attese scritte dal motore', () async {
      final renderer = _FakeRenderer(rendered);
      installPageRenderer(renderer);
      final site = DeclarativeProvider.fromJson(jsSite());
      final series = await site.fetchSeries('https://examplescans.com/manga/long-road/', http);
      expect(series.title, 'The Long Road');
      expect(series.chapters, hasLength(3));
      final content = await site.fetchPages(series.chapters.first, http);
      expect(content.pages.map((page) => page.url), ['https://img.examplecdn.net/1.webp', 'https://img.examplecdn.net/2.webp']);
      final results = await site.search('long road', http);
      expect(results.single.title, 'The Long Road');
      expect(http.asked, isEmpty);
      expect(renderer.opened.map((open) => open.$2), [
        '!!document.querySelector("ul.chapters li")',
        '!!document.querySelector("div.reader img")',
        '!!document.querySelector("div.result")',
      ]);
      expect(renderer.opened.first.$1, 'https://examplescans.com/manga/long-road');
    });

    test('snapshot series: una pagina già in mano sostituisce il rendering della serie', () async {
      final renderer = _FakeRenderer(rendered);
      installPageRenderer(renderer);
      final site = DeclarativeProvider.fromJson(jsSite());
      final page = Uint8List.fromList(utf8.encode(seriesPage));
      final snapshot = SnapshotHttp(http, 'https://examplescans.com/manga/long-road', page);
      final series = await site.fetchSeries('https://examplescans.com/manga/long-road/', snapshot);
      expect(series.title, 'The Long Road');
      expect(series.chapters, hasLength(3));
      expect(renderer.opened, isEmpty);
      expect(http.asked, isEmpty);
    });

    test('solo le pagine dichiarate si rendono', () async {
      final renderer = _FakeRenderer(rendered);
      installPageRenderer(renderer);
      final site = DeclarativeProvider.fromJson(jsSite((json) => json['browser']['pages'] = ['chapter']));
      final pages = MapHttp({'https://examplescans.com/manga/long-road': seriesPage});
      final series = await site.fetchSeries('https://examplescans.com/manga/long-road/', pages);
      expect(pages.asked, ['https://examplescans.com/manga/long-road']);
      await site.fetchPages(series.chapters.first, pages);
      expect(renderer.opened.single.$1, series.chapters.first.url);
    });

    test('senza browser installato è un errore dichiarato, non un sito cambiato', () async {
      final site = DeclarativeProvider.fromJson(jsSite());
      await expectLater(site.fetchSeries('https://examplescans.com/manga/long-road/', http),
          throwsA(isA<RendererMissing>().having((error) => error.message, 'message', contains('serve il browser'))));
    });

    test('un selettore mai pronto è un tempo scaduto dichiarato', () async {
      installPageRenderer(_FakeRenderer((_) => null));
      final site = DeclarativeProvider.fromJson(jsSite());
      await expectLater(site.fetchSeries('https://examplescans.com/manga/long-road/', http),
          throwsA(isA<RenderTimeout>().having((error) => error.message, 'message', contains('non è pronta'))));
    });

    test('una pagina resa oltre i 2 MB si rifiuta, anche per il catalogo', () async {
      installPageRenderer(_FakeRenderer((_) => 'x' * (maxRenderedPageBytes + 1)));
      final site = DeclarativeProvider.fromJson(jsSite());
      await expectLater(site.fetchSeries('https://examplescans.com/manga/long-road/', http),
          throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('troppo grande'))));
    });

    test('un indirizzo fuori da browser.hosts non va al browser', () async {
      final renderer = _FakeRenderer(rendered);
      installPageRenderer(renderer);
      final site = DeclarativeProvider.fromJson(jsSite((json) {
        json['hosts'] = ['examplescans.com', 'api.examplescans.com'];
        json['series']['url'] = 'https://api.examplescans.com/manga/{id}';
      }));
      await expectLater(site.fetchSeries('https://examplescans.com/manga/long-road/', http),
          throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('browser.hosts'))));
      expect(renderer.opened, isEmpty);
    });

    test('engine 16, e il campo pages delle tavole non conta', () {
      expect(siteMinEngine(jsSite()).engine, 16);
      expect(siteMinEngine(jsSite((json) {
        json['browser']['pages'] = ['series'];
        (json['browser'] as Map).remove('chapterReady');
      })), (engine: 16, key: 'pages'));
      expect(siteMinEngine(jsSite((json) => (json['browser'] as Map).remove('pages'))), (engine: 16, key: 'chapterReady'));
      expect(siteMinEngine(edited(htmlSite, (json) => json['format'] = 2)), (engine: 2, key: 'format'));
      expect(16, lessThanOrEqualTo(catalogEngine));
      expect(DeclarativeProvider.fromJson(jsSite()).needsBrowser, isTrue);
    });

    test('un motore fermo all\'engine 15 la rifiuta come più nuova', () {
      // Lo stesso conto di `_Spec.read` con catalogEngine 15: è ciò che fa
      // l'app di prima con un file installato a mano.
      final (:engine, :key) = siteMinEngine(jsSite((json) {
        json['browser']['pages'] = ['search'];
        (json['browser'] as Map).remove('chapterReady');
      }));
      expect(engine > 15, isTrue);
      expect(SiteEngineError(engine, key!).message, allOf(contains('«pages»'), contains('Kagami più nuovo')));
    });

    test('valori, chapterReady, formato 1 e pagine JSON si rifiutano', () {
      final bad = <String, void Function(Map<String, dynamic>)>{
        'browser.pages vuoto': (json) => json['browser']['pages'] = <String>[],
        'browser.pages ignoto': (json) => json['browser']['pages'] = ['home'],
        'browser.pages ripetuto': (json) => json['browser']['pages'] = ['series', 'series'],
        'browser.chapterReady': (json) => (json['browser'] as Map).remove('chapterReady'),
        'browser.chapterReady non valido': (json) => json['browser']['chapterReady'] = 'div[[',
        '"format": 2': (json) => json['format'] = 1,
        'series.json': (json) => json['series']['json'] = true,
        'chapter.api': (json) => json['chapter']['api'] = 'https://examplescans.com/api/{chapterId}',
        'search.json': (json) => json['search']['json'] = true,
      };
      for (final MapEntry(:key, :value) in bad.entries) {
        expect(() => DeclarativeProvider.fromJson(jsSite(value)),
            throwsA(isA<SiteDefinitionError>().having((e) => e.message, 'message', contains(key.split(' ').first))),
            reason: key);
      }
    });
  });
}

/// Casi limite delle tavole di un capitolo (R9.2, R9.3).
void pageEdges() {
  group('tavole', () {
    const url = 'https://examplescans.com/manga/long-road/chapter-1/';

    test('una tavola senza url è un ProviderChanged, non uno scarto silenzioso', () async {
      final site = DeclarativeProvider.fromJson(htmlSite());
      final http = MapHttp({url: '<div class="reader"><img data-src="https://img.examplecdn.net/1.webp"><img alt="x"></div>'});
      await expectLater(
        site.fetchPages(const Chapter('1', 'Chapter 1', '1', url), http),
        throwsA(isA<ProviderChanged>()
            .having((error) => error.fault?.phase, 'phase', 'pages')
            .having((error) => error.fault?.field, 'field', 'chapter.pages.url')),
      );
    });

    test('var byte: i byte restano un solo valore, non diventano un numero per byte', () async {
      final site = DeclarativeProvider.fromJson(edited(htmlSite, (json) {
        json['format'] = 2;
        json['chapter']['recipe'] = [
          {'let': 'b', 'hex': 'ff00ff'},
        ];
        json['chapter']['pages'] = {
          'items': {'var': 'b'},
          'url': {'template': 'https://img.examplecdn.net/p.webp'},
        };
      }));
      final content = await site.fetchPages(const Chapter('1', 'Chapter 1', '1', url), MapHttp({url: '<html></html>'}));
      expect(content.pages, hasLength(1));
    });
  });
}
