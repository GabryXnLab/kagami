// `tool/site.dart har`: dall'HAR alla cassetta e all'inventario.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/cassette.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/site.dart';
import '../tool/src/lint.dart';

Future<({int code, String out, String err})> _run(List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runSiteTool(args, out: out, err: err);
  return (code: code, out: out.toString(), err: err.toString());
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('site_tool'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String outDir() => p.join(tmp.path, 'cassetta');

  group('har', () {
    test('har attach: corpi accanto, filtro per host, terze parti e mediaHosts', () async {
      final r = await _run(['har', 'test/fixtures/har/attach', '--hosts', 'site.test,api.site.test', '--out', outDir()]);
      expect(r.code, 0, reason: r.err);
      final cassette = Cassette.load(Directory(outDir()));
      expect(cassette.entries.keys, hasLength(3));
      expect(cassette.entries['https://site.test/manga/123']!.body, isNotEmpty);
      expect(cassette.entries.keys.any((k) => k.contains('tracker') || k.contains('cdn.example')), isFalse);
      expect(r.out, contains('Terze parti ignorate: 2'));
      expect(r.out, contains('cdn.example'));
      expect(r.out, contains('__NEXT_DATA__'));
      expect(r.out, contains('og: meta'));
      expect(r.out, contains('/series/{}/chapters'));
      expect(r.out, contains('candidato elenco capitoli'));
    });

    test('har: la cassetta non contiene header né cookie', () async {
      await _run(['har', 'test/fixtures/har/attach', '--hosts', 'site.test,api.site.test', '--out', outDir()]);
      for (final f in Directory(outDir()).listSync().whereType<File>()) {
        expect(utf8.decode(f.readAsBytesSync(), allowMalformed: true).toLowerCase(), isNot(contains('cookie')));
      }
    });

    test('har: POST nell\'inventario come non esprimibile, buildId segnalato', () async {
      final r = await _run(['har', 'test/fixtures/har/attach/recording.har', '--hosts', 'site.test,api.site.test', '--out', outDir()]);
      expect(r.out, contains('Non esprimibile'));
      expect(r.out, contains('POST api.site.test/login'));
      expect(r.out, contains('_next/data/<buildId>'));
      final cassette = Cassette.load(Directory(outDir()));
      expect(cassette.entries.keys.any((k) => k.endsWith('/login')), isFalse);
    });

    test('har inline: text e base64, immagine ridotta ai primi byte', () async {
      final r = await _run(['har', 'test/fixtures/har/inline', '--hosts', 'site.test', '--out', outDir(), '--json']);
      expect(r.code, 0, reason: r.err);
      expect(jsonDecode(r.out), containsPair('cassetteEntries', 2));
      final cassette = Cassette.load(Directory(outDir()));
      expect(utf8.decode(cassette.entries['https://site.test/']!.body), contains('ciao'));
      expect(cassette.entries['https://site.test/p/1.png']!.body, hasLength(64));
    });

    test('har: --definition fornisce gli host', () async {
      final def = File(p.join(tmp.path, 'def.json'))..writeAsStringSync('{"hosts":["site.test"]}');
      final r = await _run(['har', 'test/fixtures/har/inline', '--definition', def.path, '--out', outDir()]);
      expect(r.code, 0, reason: r.err);
    });

    test('har: _file ostile scartato e contato', () async {
      final dir = Directory(p.join(tmp.path, 'evil'))..createSync();
      File(p.join(tmp.path, 'x')).writeAsStringSync('segreto');
      File(p.join(dir.path, 'a.har')).writeAsStringSync(jsonEncode({
        'log': {
          'entries': [
            {
              'request': {'method': 'GET', 'url': 'https://site.test/'},
              'response': {
                'status': 200,
                'content': {'mimeType': 'text/html', '_file': '../x'},
              },
            },
          ],
        },
      }));
      final r = await _run(['har', dir.path, '--hosts', 'site.test', '--out', outDir()]);
      expect(r.code, 0, reason: r.err);
      expect(r.out, contains('Corpi scartati (_file non ammesso): 1'));
      for (final f in Directory(outDir()).listSync().whereType<File>()) {
        expect(utf8.decode(f.readAsBytesSync(), allowMalformed: true), isNot(contains('segreto')));
      }
    });

    test('har: senza --hosts né definizione è un errore', () async {
      final r = await _run(['har', 'test/fixtures/har/inline', '--out', outDir()]);
      expect(r.code, 1);
    });
  });

  group('lint', () {
    // Una definizione che l'app installerebbe: lint la prova con DeclarativeProvider.parse.
    Map<String, Object?> base() => {
          'format': 2,
          'id': 'x',
          'name': 'X',
          'version': 1,
          'update': 'https://raw.githubusercontent.com/someone/sites/main/x.json',
          'home': 'https://x.com',
          'hosts': ['x.com'],
          'mediaHosts': ['*.xcdn.net'],
          'series': <String, Object?>{
            'path': r'^/manga/([a-z0-9-]+)/?$',
            'url': 'https://x.com/manga/{id}',
            'title': {'first': ['h1', 'h2']},
            'chapters': <String, Object?>{
              'items': {'first': ['ul.a li', 'ul.b li']},
              'url': {'css': 'a', 'attr': 'href'},
              'title': 'a',
              'id': {'from': 'url', 'regex': r'/chapter-([a-z0-9-]+)/?$'},
            },
          },
          'chapter': <String, Object?>{
            'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
            'pages': <String, Object?>{'items': {'first': ['div.a img', 'div.b img']}, 'url': {'attr': 'src'}},
          },
        };
    // Le regole si provano una per volta su definizioni ritoccate che parse può rifiutare: qui senza `install`.
    List<LintIssue> lint(Map<String, Object?> d, {Map? canaries}) =>
        lintSite(d, canaries: canaries).where((i) => i.id != 'install').toList();
    Set<String> ids(List<LintIssue> l) => l.map((i) => i.id).toSet();

    test('definizione pulita: nessuna segnalazione', () => expect(lint(base()), isEmpty));

    test('install: ciò che parse rifiuta è un error', () {
      final d = base()..['hosts'] = <String>[];
      final r = lintSite(d);
      expect(r.where((i) => i.id == 'install' && i.isError), isNotEmpty);
      expect(lintSite(base()), isEmpty);
    });

    test('single-source: una sola strategia, risolta da fallback', () {
      final d = base();
      (d['series'] as Map<String, Object?>)['title'] = 'h1';
      final r = lint(d);
      expect(r.single.id, 'single-source');
      expect(r.single.field, 'series.title');
      expect(r.single.level, 'warn');
      (d['series'] as Map<String, Object?>)['fallback'] = [{'title': 'h2'}];
      expect(lint(d), isEmpty);
    });

    test('fragile-selector: hash e nth-child profondi, non [class*=]', () {
      for (final css in ['.css-1x2y3z', '.sc-AbCdEf h1', '.styles_title__x7Qa2', 'li:nth-child(2) > a:nth-child(3)']) {
        final d = base();
        (d['series'] as Map<String, Object?>)['cover'] = {'css': css};
        expect(ids(lint(d)), {'fragile-selector'}, reason: css);
      }
      final d = base();
      (d['series'] as Map<String, Object?>)['cover'] = {'css': '[class*="title"]'};
      expect(lint(d), isEmpty);
    });

    test('volatile-segment: buildId e versione fissi sono error, da variabile no', () {
      final d = base();
      (d['series'] as Map<String, Object?>)['url'] = 'https://s.test/_next/data/AbC123/x.json';
      final r = lint(d);
      expect(r.single.id, 'volatile-segment');
      expect(r.single.isError, isTrue);
      (d['series'] as Map<String, Object?>)['url'] = 'https://s.test/_next/data/{build}/x.json';
      expect(lint(d), isEmpty);
      (d['series'] as Map<String, Object?>)['url'] = {'template': 'https://s.test/a', 'query': {'cv': '12'}};
      expect(lint(d).single.isError, isTrue);
      (d['series'] as Map<String, Object?>)['url'] = {'template': 'https://s.test/a', 'query': {'cv': '{cv}'}};
      expect(lint(d), isEmpty);
    });

    test('json-without-link: json true senza series.link', () {
      final d = base();
      (d['series'] as Map<String, Object?>)['json'] = true;
      expect(lint(d).single.id, 'json-without-link');
      (d['series'] as Map<String, Object?>)['link'] = 'https://s.test/{id}';
      expect(lint(d), isEmpty);
    });

    test('chapter-identity: tavole da API senza require', () {
      final d = base();
      (d['chapter'] as Map<String, Object?>)['api'] = 'https://api.s.test/{chapterId}';
      (d['chapter'] as Map<String, Object?>).remove('require');
      expect(lint(d).single.id, 'chapter-identity');
    });

    test('missing-canary solo con --canaries', () {
      expect(lint(base()), isEmpty);
      expect(lint(base(), canaries: {'sites': {}}).single.id, 'missing-canary');
      expect(lint(base(), canaries: {'sites': {'x': {}}}), isEmpty);
    });

    test('comando: exit 1 con un error, 0 con soli warn, --json', () async {
      final bad = File(p.join(tmp.path, 'bad.json'))..writeAsStringSync(jsonEncode(base()..['series'] = {'url': '/_next/data/Zz9/a.json'}));
      final r = await _run(['lint', bad.path]);
      expect(r.code, 1);
      expect(r.out, contains('volatile-segment'));
      final warn = File(p.join(tmp.path, 'warn.json'))..writeAsStringSync(jsonEncode(base()..['series'] = ((base()['series'] as Map<String, Object?>)..['title'] = 'h1')));
      final j = await _run(['lint', warn.path, '--json']);
      expect(j.code, 0);
      expect((jsonDecode(j.out) as List).first['id'], 'single-source');
    });

    for (final site in ['mangak', 'asurascans']) {
      test('$site reale: nessun error', () {
        final def = jsonDecode(File('../../catalog/sites/$site.json').readAsStringSync()) as Map;
        final canaries = jsonDecode(File('../../catalog/canaries.json').readAsStringSync()) as Map;
        final r = lintSite(def, canaries: canaries);
        // ignore: avoid_print
        print('$site: ${r.map((i) => i.toString()).toList()}');
        expect(r.where((i) => i.isError), isEmpty);
      });
    }
  });

  group('check', () {
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
    const seriesUrl = 'https://examplescans.com/manga/long';
    const chapterUrl = 'https://examplescans.com/manga/long/chapter-1/';
    const seriesHtml = '<h1 class="title">Long</h1><ul class="chapters"><li><a href="/manga/long/chapter-1/">C1</a></li></ul>';
    const chapterHtml = '<div class="reader"><img src="https://img.examplecdn.net/1.webp"></div>';

    Map<String, Object?> expectJson() => {
          'url': seriesUrl,
          'seriesId': 'long',
          'title': 'Long',
          'minChapters': 1,
          'firstPage': 'https://img.examplecdn.net/1.webp',
        };

    String record({Map<String, Object?>? expect, bool withChapter = true}) {
      final cassette = Cassette();
      CassetteEntry html(String body) => CassetteEntry(status: 200, contentType: 'text/html', body: Uint8List.fromList(utf8.encode(body)));
      cassette.entries[seriesUrl] = html(seriesHtml);
      if (withChapter) cassette.entries[chapterUrl] = html(chapterHtml);
      final dir = Directory(p.join(tmp.path, 'cas'));
      cassette.save(dir);
      File(p.join(dir.path, 'expect.json')).writeAsStringSync(jsonEncode(expect ?? expectJson()));
      return dir.path;
    }

    String defFile() => (File(p.join(tmp.path, 'def.json'))..writeAsStringSync(jsonEncode(def))).path;

    test('replay: query/url da expect.json, esito JSON, exit 0', () async {
      final r = await _run(['check', defFile(), '--replay', record(), '--json']);
      expect(r.code, 0, reason: r.out + r.err);
      final json = jsonDecode(r.out) as Map;
      expect(json['series'], {'id': 'long', 'title': 'Long', 'chapters': 1});
      expect(json['pages'], containsPair('count', 1));
      expect(json['fault'], isNull);
      expect(json['degraded'], isEmpty);
    });

    test('replay: expect diverso -> exit 1 col campo', () async {
      final r = await _run(['check', defFile(), '--replay', record(expect: expectJson()..['title'] = 'Altro')]);
      expect(r.code, 1);
      expect(r.out, contains('DIFFERENZA title'));
      final m = await _run(['check', defFile(), '--replay', record(expect: expectJson()..['minChapters'] = 5)]);
      expect(m.code, 1);
      expect(m.out, contains('minChapters'));
    });

    test('replay: richiesta fuori cassetta -> errore leggibile', () async {
      final r = await _run(['check', defFile(), '--replay', record(withChapter: false)]);
      expect(r.code, 1);
      expect(r.err, contains('fuori dalla cassetta'));
      expect(r.err, contains(chapterUrl));
    });

    test('opzioni incoerenti', () async {
      expect((await _run(['check', defFile()])).code, 1);
      expect((await _run(['check', defFile(), '--replay', record(), '--record', 'x'])).err, contains('--live'));
      expect((await _run(['check', defFile(), '--replay', record(), '--query', 'a', '--url', 'b'])).code, 1);
    });
  });

  group('flatten', () {
    test('stampa la definizione piatta; lint e check accettano il sorgente con extends', () async {
      final sites = Directory(p.join(tmp.path, 'catalog', 'sites'))..createSync(recursive: true);
      final themes = Directory(p.join(tmp.path, 'catalog', 'themes'))..createSync(recursive: true);
      File(p.join(themes.path, 't.json')).writeAsStringSync(jsonEncode({
        'format': 1,
        'series': {'path': r'^/m/([a-z]+)/?$', 'url': 'https://s.test/m/{id}', 'title': 'h1', 'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'}},
        'chapter': {'path': r'^/m/([a-z]+)/c-1/?$', 'pages': {'items': 'img', 'url': {'attr': 'src'}}},
      }));
      final f = File(p.join(sites.path, 's.json'))
        ..writeAsStringSync(jsonEncode({'id': 's', 'name': 'S', 'version': 1, 'home': 'https://s.test', 'hosts': ['s.test'], 'extends': 't', 'series': {'title': 'h2'}}));
      final r = await _run(['flatten', f.path]);
      expect(r.code, 0, reason: r.err);
      final flat = jsonDecode(r.out) as Map;
      expect(flat.containsKey('extends'), isFalse);
      expect((flat['series'] as Map)['title'], 'h2');
      expect((flat['series'] as Map)['path'], isNotNull);
      expect((await _run(['lint', f.path])).err, isNot(contains('extends')));
      expect((await _run(['flatten', f.path, '--themes', p.join(tmp.path, 'nulla')])).err, contains('non trovato'));
    });
  });

  group('coffeemanga-key', () {
    test('dal bundle la chiave in esadecimale, come coffeeMangaKey', () async {
      final r = await _run(['coffeemanga-key', 'test/fixtures/coffeemanga_key.js']);
      expect(r.code, 0, reason: r.err);
      expect(r.out.trim(), '143d17cc4fbf2e4e9441e493c4765c915ce55d6d0f7bf1b45af32f5d76a7699c');
    });

    test('un bundle senza TE() si ferma con un messaggio', () async {
      final file = File(p.join(tmp.path, 'b.js'))..writeAsStringSync('var a=1;');
      final r = await _run(['coffeemanga-key', file.path]);
      expect(r.code, 1);
      expect(r.err, contains('TE()'));
    });
  });
}
