// I siti degli utenti: il file si valida per intero all'installazione, e un
// sito descritto si comporta come uno incluso (link, serie, tavole, ricerca).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
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
      'formato sconosciuto': (json) => json['format'] = 2,
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
