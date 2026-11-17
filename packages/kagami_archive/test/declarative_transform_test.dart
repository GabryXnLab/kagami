// La ricetta del formato 2 (`docs/siti.md`, «Ricetta»): passi, codifiche,
// intExpr e switch; tipi controllati all'installazione, guasti col percorso
// del passo, tetti.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:test/test.dart';

class MapHttp implements ProviderHttp {
  MapHttp(this.pages);

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

const Chapter chapter = Chapter('chapter-1', 'Chapter 1', '1', 'https://manhwaread.com/manhwa/moon/chapter-1');

/// Il capitolo di ManhwaRead della specifica; [chapterSpec] lo sostituisce.
Map<String, Object?> site({Map<String, Object?>? chapterSpec, Map<String, Object?>? series}) => {
      'format': 2,
      'id': 'manhwaread',
      'name': 'ManhwaRead',
      'version': 1,
      'home': 'https://manhwaread.com',
      'hosts': ['manhwaread.com'],
      'mediaHosts': ['cdn.manhwaread.com'],
      'series': {
        'path': r'^/manhwa/([a-z0-9-]+)/?$',
        'title': 'h1',
        'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
        ...?series,
      },
      'chapter': chapterSpec ??
          {
            // La specifica scrive `([a-z0-9]+(?:-[a-z0-9]+)*)`, che il controllo delle ripetizioni annidate rifiuta.
            'path': r'^/manhwa/([a-z0-9-]+)/[a-z0-9-]+/?$',
            'vars': {
              'data': {'css': 'script', 'all': true, 'jsonAt': r'\bchapterData\s*=\s*'},
              'cdn': {'var': 'data', 'json': 'base', 'filters': [{'replace': [r'/+$', '']}]},
            },
            'recipe': [
              {'let': 'encoded', 'get': {'var': 'data', 'json': 'data'}, 'check': r'^[A-Za-z0-9+/=]+$'},
              {'let': 'bytes', 'base64': '{encoded}'},
              {'let': 'images', 'json': '{bytes}'},
            ],
            'pages': {
              'items': {'var': 'images'},
              'url': {'json': 'src', 'base': '{cdn}/'},
              'width': {'json': 'w'},
              'height': {'json': 'h'},
            },
          },
    };

String scriptPage(String data, {String base = 'https://cdn.manhwaread.com/moon//'}) =>
    '<html><body><script>var chapterData = {"base": "$base", "data": "$data"};</script></body></html>';

/// Un capitolo con [recipe] il cui risultato è la variabile `r`: la tavola è
/// `https://cdn.manhwaread.com/p/<r>`.
Map<String, Object?> probe(List<Object?> recipe) => site(chapterSpec: {
      'path': r'^/manhwa/([a-z0-9-]+)/[a-z0-9-]+$',
      'vars': {'data': {'css': 'script', 'all': true, 'jsonAt': r'\bchapterData\s*=\s*'}},
      'recipe': recipe,
      'pages': {
        'items': {'template': '{r}'},
        'url': {'template': 'p/{r}', 'base': 'https://cdn.manhwaread.com/'},
      },
    });

Future<String> result(List<Object?> recipe, {String page = '', Map<String, String> more = const {}}) async {
  final content = await DeclarativeProvider.fromJson(probe(recipe))
      .fetchPages(chapter, MapHttp({chapter.url: page.isEmpty ? scriptPage('') : page, ...more}));
  return Uri.decodeComponent(content.pages.single.url.split('/p/').last);
}

Future<String> expression(String source, {Map<String, String> text = const {}}) => result([
      for (final MapEntry(key: name, value: value) in text.entries) {'let': name, 'template': value},
      {'let': 'r', 'intExpr': source},
    ]);

Matcher faultAt(String field) => throwsA(isA<ProviderChanged>()
    .having((error) => error.fault?.field, 'field', field)
    .having((error) => error.fault?.phase, 'phase', 'pages'));

Matcher refused = throwsA(isA<SiteDefinitionError>());

/// Un capitolo con [recipe] le cui tavole sono le voci `src` della lista [list].
Map<String, Object?> listing(List<Object?> recipe, {String list = 'l'}) => site(chapterSpec: {
      'path': r'^/manhwa/([a-z0-9-]+)/[a-z0-9-]+$',
      'vars': {'data': {'css': 'script', 'all': true, 'jsonAt': r'\bchapterData\s*=\s*'}},
      'recipe': recipe,
      'pages': {'items': {'var': list}, 'url': {'json': 'src', 'base': 'https://cdn.manhwaread.com/'}},
    });

Future<List<String>> listed(Map<String, Object?> json, {String page = '', Map<String, String> more = const {}}) async {
  final content = await DeclarativeProvider.fromJson(json)
      .fetchPages(chapter, MapHttp({chapter.url: page.isEmpty ? scriptPage('') : page, ...more}));
  return [for (final page in content.pages) page.url.split('/').last];
}

String hexOf(List<int> bytes) => [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();

void main() {
  group('base: ricetta', () {
    test('ManhwaRead: chapterData in base64 → byte → JSON → tavole', () async {
      final images = [
        {'src': '1.webp', 'w': 800, 'h': 1200},
        {'src': '2.webp', 'w': 800, 'h': 1100},
      ];
      final http = MapHttp({chapter.url: scriptPage(base64.encode(utf8.encode(jsonEncode(images))))});
      final content = await DeclarativeProvider.fromJson(site()).fetchPages(chapter, http);
      expect([for (final page in content.pages) page.url],
          ['https://cdn.manhwaread.com/moon/1.webp', 'https://cdn.manhwaread.com/moon/2.webp']);
      expect([for (final page in content.pages) (page.width, page.height)], [(800, 1200), (800, 1100)]);
    });

    test('check fallito: ProviderChanged col percorso del passo', () async {
      final http = MapHttp({chapter.url: scriptPage('non base64!')});
      expect(DeclarativeProvider.fromJson(site()).fetchPages(chapter, http), faultAt('chapter.recipe[0]'));
    });

    test('un JSON rovinato dopo la decodifica: guasto del passo json', () async {
      final http = MapHttp({chapter.url: scriptPage(base64.encode(utf8.encode('[{"src": ')))});
      expect(DeclarativeProvider.fromJson(site()).fetchPages(chapter, http), faultAt('chapter.recipe[2]'));
    });

    test('base64 url senza riempimento, hex, utf8 e i versi opposti', () async {
      expect(await result([
        {'let': 'b', 'base64': '-_8', 'url': true},
        {'let': 'r', 'hex': '{b}', 'encode': true},
      ]), 'fbff');
      expect(await result([
        {'let': 'b', 'hex': '4b61676d69'},
        {'let': 'r', 'utf8': '{b}'},
      ]), 'Kagmi');
      expect(await result([
        {'let': 'b', 'base64': 'S2FnYW1p'},
        {'let': 'r', 'base64': '{b}', 'encode': true, 'url': true},
      ]), 'S2FnYW1p');
      expect(await result([{'let': 'r', 'base64': 'ab', 'encode': true}]), 'YWI=');
      expect(result([{'let': 'b', 'base64': '-_8'}, {'let': 'r', 'template': 'x'}]), faultAt('chapter.recipe[0]'));
      expect(result([{'let': 'b', 'hex': 'abc'}, {'let': 'r', 'template': 'x'}]), faultAt('chapter.recipe[0]'));
      expect(result([{'let': 'b', 'hex': 'ff'}, {'let': 'r', 'utf8': '{b}'}]), faultAt('chapter.recipe[1]'));
    });

    test('intExpr: precedenze, 64 bit, bit a 32 bit come JavaScript, confronti', () async {
      final cases = {
        '1 + 2 * 3': '7',
        '(1 + 2) * 3': '9',
        '10 - 4 - 3': '3',
        '7 / 2': '3',
        '-7 / 2': '-3',
        '-7 % 3': '-1',
        '6 & 3 | 8 ^ 1': '11',
        '1 << 31': '-2147483648',
        '1 << 33': '2',
        '-1 >> 28': '-1',
        '4294967296 | 0': '0',
        '~5': '-6',
        '9223372036854775807 + 1': '-9223372036854775808',
        '1 < 2 && 3 >= 3': '1',
        '2 == 2 == 1': '1',
        '1 + 1 == 2 || 1 / 0': '1',
        '!0 + !7': '1',
        '3 != 3': '0',
      };
      for (final MapEntry(key: source, value: expected) in cases.entries) {
        expect(await expression(source), expected, reason: source);
      }
      expect(await expression('n * 2 + len(s)', text: {'n': '42', 's': 'àbc'}), '88');
    });

    test('intExpr: divisione per zero e variabile non intera sono guasti del passo', () async {
      expect(expression('5 / (2 - 2)'), faultAt('chapter.recipe[0]'));
      expect(expression('5 % 0'), faultAt('chapter.recipe[0]'));
      expect(expression('n + 1', text: {'n': 'tre'}), faultAt('chapter.recipe[1]'));
    });

    test('switch: il caso, il default, nessun caso è un guasto', () async {
      List<Object?> chooser(String key, {bool fallback = true}) => [
            {'let': 'k', 'intExpr': key},
            {
              'let': 'r',
              'switch': '{k}',
              'cases': {'0': 'zero', '1': 'uno-{k}'},
              if (fallback) 'default': 'altro',
            },
          ];
      expect(await result(chooser('0')), 'zero');
      expect(await result(chooser('2 - 1')), 'uno-1');
      expect(await result(chooser('5')), 'altro');
      expect(result(chooser('5', fallback: false)), faultAt('chapter.recipe[1]'));
    });

    test('when: con 0 il passo si salta e la variabile resta vuota', () async {
      List<Object?> gated(String when) => [
            {'let': 'a', 'template': 'preso', 'when': when},
            {'let': 'r', 'switch': '{a}', 'cases': {'preso': 'si'}, 'default': 'saltato'},
          ];
      expect(await result(gated('1 + 1 == 2')), 'si');
      expect(await result(gated('1 > 2')), 'saltato');
    });

    test('le variabili della ricetta valgono nei campi di serie e ricerca', () async {
      final json = site(series: {
        'recipe': [
          {'let': 'n', 'intExpr': '6 * 7'},
          {'let': 'name', 'template': 'Moon {n}'},
        ],
        'title': {'var': 'name'},
      })
        ..['search'] = {
          'url': 'https://manhwaread.com/?s={query}',
          'recipe': [{'let': 'prefix', 'template': '/manhwa/'}],
          'items': 'div.r',
          'title': 'a',
          'link': {'css': 'a', 'attr': 'href'},
        };
      final provider = DeclarativeProvider.fromJson(json);
      final http = MapHttp({
        'https://manhwaread.com/manhwa/moon': '<h1>x</h1><ul><li><a href="/manhwa/moon/chapter-1">Chapter 1</a></li></ul>',
        'https://manhwaread.com/?s=moon': '<div class="r"><a href="/manhwa/moon">Moon</a></div>',
      });
      expect((await provider.fetchSeries('https://manhwaread.com/manhwa/moon', http)).title, 'Moon 42');
      expect([for (final found in await provider.search('moon', http)) found.title], ['Moon']);
    });

    group('tipi: il passo che riceve il tipo sbagliato non si installa', () {
      final wrong = <String, List<Object?>>{
        'utf8 di un testo': [{'let': 'r', 'utf8': 'abc'}],
        'json di un intero': [{'let': 'n', 'intExpr': '1'}, {'let': 'r', 'json': '{n}'}],
        'json di un JSON': [{'let': 'j', 'json': '[1]'}, {'let': 'r', 'json': '{j}'}],
        'base64 di byte': [{'let': 'b', 'hex': 'ff'}, {'let': 'r', 'base64': '{b}'}],
        'hex di un intero': [{'let': 'n', 'intExpr': '1'}, {'let': 'r', 'hex': '{n}'}],
        'byte in un modello': [{'let': 'b', 'hex': 'ff'}, {'let': 'r', 'template': 'x{b}'}],
        'byte in intExpr': [{'let': 'b', 'hex': 'ff'}, {'let': 'r', 'intExpr': 'b + 1'}],
        'JSON in intExpr': [{'let': 'j', 'json': '[1]'}, {'let': 'r', 'intExpr': 'j + 1'}],
        'len di un intero': [{'let': 'n', 'intExpr': '1'}, {'let': 'r', 'intExpr': 'len(n)'}],
        'check su byte': [{'let': 'r', 'hex': 'ff', 'check': '.'}],
        'casi di tipi diversi': [
          {'let': 'b', 'hex': 'ff'},
          {'let': 'r', 'switch': 'x', 'cases': {'a': '{b}', 'b': 'testo'}},
        ],
      };
      for (final MapEntry(key: name, value: recipe) in wrong.entries) {
        test(name, () => expect(() => DeclarativeProvider.fromJson(probe(recipe)), refused));
      }
    });

    group('forma: passi scritti male non si installano', () {
      final bad = <String, List<Object?>>{
        'due operazioni': [{'let': 'r', 'template': 'a', 'intExpr': '1'}],
        'nessuna operazione': [{'let': 'r'}],
        'chiave sconosciuta': [{'let': 'r', 'template': 'a', 'mode': 1}],
        'url fuori da base64': [{'let': 'r', 'hex': 'ff', 'url': true}],
        'variabile già scritta': [{'let': 'r', 'template': 'a'}, {'let': 'r', 'template': 'b'}],
        'variabile sconosciuta': [{'let': 'r', 'template': '{nessuna}'}],
        'un passo vede solo i precedenti': [{'let': 'r', 'template': '{s}'}, {'let': 's', 'template': 'a'}],
        'intExpr a metà': [{'let': 'r', 'intExpr': '1 +'}],
        'intExpr con un simbolo ignoto': [{'let': 'r', 'intExpr': '1 ** 2'}],
        'intExpr oltre 64 bit': [{'let': 'r', 'intExpr': '99999999999999999999'}],
        'intExpr oltre 200 caratteri': [{'let': 'r', 'intExpr': List.filled(101, '1').join('+')}],
        'when non intero': [{'let': 'r', 'template': 'a', 'when': 'x'}],
        'ricetta vuota': [],
        'oltre 32 passi': [for (var i = 0; i < 32; i++) {'let': 'v$i', 'template': 'a'}, {'let': 'r', 'template': 'a'}],
      };
      for (final MapEntry(key: name, value: recipe) in bad.entries) {
        test(name, () => expect(() => DeclarativeProvider.fromJson(probe(recipe)), refused));
      }

      test('32 passi si installano', () {
        expect(DeclarativeProvider.fromJson(probe([
          for (var i = 0; i < 31; i++) {'let': 'v$i', 'template': 'a'},
          {'let': 'r', 'template': 'a'},
        ])), isA<DeclarativeProvider>());
      });

      test('nel formato 1 la ricetta è una chiave sconosciuta', () {
        expect(() => DeclarativeProvider.fromJson(probe([{'let': 'r', 'template': 'a'}])..['format'] = 1), refused);
      });
    });

    group('tetti', () {
      test('un modello oltre 64 KB', () {
        final big = 'a' * 40000;
        expect(result([{'let': 'big', 'get': {'var': 'data', 'json': 'data'}}, {'let': 'r', 'template': '{big}{big}'}],
                page: scriptPage(big)),
            throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('64 KB'))));
      });

      test('un valore oltre 2 MB', () {
        final data = base64.encode(Uint8List(1100000));
        expect(result([
          {'let': 'e', 'get': {'var': 'data', 'json': 'data'}},
          {'let': 'b', 'base64': '{e}'},
          {'let': 'r', 'hex': '{b}', 'encode': true},
        ], page: scriptPage(data)), throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('2 MB'))));
      });

      test('tutte le variabili oltre 8 MB', () {
        final data = base64.encode(Uint8List(1100000));
        expect(result([
          {'let': 'e', 'get': {'var': 'data', 'json': 'data'}},
          for (var i = 0; i < 4; i++) ...[
            {'let': 'b$i', 'base64': i == 0 ? '{e}' : '{e${i - 1}}'},
            {'let': 'e$i', 'base64': '{b$i}', 'encode': true},
          ],
          {'let': 'r', 'template': 'x'},
        ], page: scriptPage(data)), throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('8 MB'))));
      });
    });
  });

  group('ricetta, seconda metà', () {
    test('range: byte concatenati, una lista se do dà testo o JSON', () async {
      expect(await result([
        {'let': 'k', 'range': {'count': '3', 'max': 4, 'as': 'b'}, 'do': {'hex': '0{b}'}},
        {'let': 'r', 'hex': '{k}', 'encode': true},
      ]), '000102');
      expect(await result([
        {'let': 'l', 'range': {'count': '5', 'max': 5, 'as': 'i'}, 'do': {'template': 'p{i}'}},
        {'let': 'r', 'intExpr': 'len(l)'},
      ]), '5');
      expect(await listed(listing([
        {'let': 'n', 'intExpr': '1 + 1'},
        {'let': 'l', 'range': {'count': 'n', 'max': 8, 'as': 'i'}, 'do': {'json': '{"src": "p{i}.webp"}'}},
      ])), ['p0.webp', 'p1.webp']);
      expect(await result([
        {'let': 'k', 'range': {'count': '0', 'max': 1, 'as': 'b'}, 'do': {'hex': '0{b}'}},
        {'let': 'r', 'intExpr': 'len(k) + 7'},
      ]), '7');
    });

    test('range: max superato è un errore all\'installazione se count è costante, un guasto se no', () {
      expect(() => DeclarativeProvider.fromJson(probe([
            {'let': 'r', 'range': {'count': '2 * 3', 'max': 5, 'as': 'b'}, 'do': {'template': 'x'}},
          ])), refused);
      expect(result([
        {'let': 'n', 'template': '6'},
        {'let': 'k', 'range': {'count': 'n', 'max': 5, 'as': 'b'}, 'do': {'template': 'x'}},
        {'let': 'r', 'template': 'x'},
      ]), faultAt('chapter.recipe[1]'));
    });

    group('range e crittografia scritti male non si installano', () {
      final bad = <String, List<Object?>>{
        'do annidato': [
          {'let': 'r', 'range': {'count': '2', 'max': 2, 'as': 'a'}, 'do': {
            'range': {'count': '2', 'max': 2, 'as': 'b'}, 'do': {'template': 'x'}}},
        ],
        'fetch in do': [
          {'let': 'r', 'range': {'count': '2', 'max': 2, 'as': 'a'}, 'do': {'fetch': 'https://manhwaread.com/{a}'}},
        ],
        'do con let': [{'let': 'r', 'range': {'count': '2', 'max': 2, 'as': 'a'}, 'do': {'let': 'x', 'template': 'x'}}],
        'senza max': [{'let': 'r', 'range': {'count': '2', 'as': 'a'}, 'do': {'template': 'x'}}],
        'max oltre 256': [{'let': 'r', 'range': {'count': '2', 'max': 257, 'as': 'a'}, 'do': {'template': 'x'}}],
        'senza do': [{'let': 'r', 'range': {'count': '2', 'max': 2, 'as': 'a'}}],
        'as visibile solo in do': [
          {'let': 'k', 'range': {'count': '2', 'max': 2, 'as': 'a'}, 'do': {'template': 'x'}},
          {'let': 'r', 'template': '{a}'},
        ],
        'byte di range in un modello': [
          {'let': 'k', 'range': {'count': '2', 'max': 2, 'as': 'a'}, 'do': {'hex': 'ff'}},
          {'let': 'r', 'template': '{k}'},
        ],
        'xor di un testo': [{'let': 'k', 'hex': 'ff'}, {'let': 'r', 'xor': {'data': 'abc', 'key': '{k}'}}],
        'xor senza chiave': [{'let': 'k', 'hex': 'ff'}, {'let': 'r', 'xor': {'data': '{k}'}}],
        'hmac di un intero': [{'let': 'n', 'intExpr': '1'}, {'let': 'r', 'hmacSha256': {'key': '{n}', 'message': 'x'}}],
        'hmac con byte nel messaggio': [{'let': 'k', 'hex': 'ff'}, {'let': 'r', 'hmacSha256': {'key': 'a', 'message': '{k}'}}],
        'fetch fuori dagli hosts': [{'let': 'r', 'fetch': 'https://example.org/x'}],
        'fetch con byte nell\'indirizzo': [{'let': 'k', 'hex': 'ff'}, {'let': 'r', 'fetch': 'https://manhwaread.com/{k}'}],
      };
      for (final MapEntry(key: name, value: recipe) in bad.entries) {
        test(name, () => expect(() => DeclarativeProvider.fromJson(probe(recipe)), refused));
      }
    });

    test('hmacSha256: i vettori della RFC 4231', () async {
      Future<String> mac(Map<String, Object?> key, String message) => result([
            {'let': 'k', ...key},
            {'let': 'm', 'hmacSha256': {'key': '{k}', 'message': message}},
            {'let': 'r', 'hex': '{m}', 'encode': true},
          ]);
      expect(await mac({'hex': '0b' * 20}, 'Hi There'), 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');
      expect(await mac({'template': 'Jefe'}, 'what do ya want for nothing?'),
          '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843');
      expect(await mac({'hex': 'aa' * 131}, 'Test Using Larger Than Block-Size Key - Hash Key First'),
          '60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54');
    });

    test('xor: la chiave si ripete; byte di un tipo sbagliato sono un guasto', () async {
      expect(await result([
        {'let': 'd', 'hex': '0102030405'},
        {'let': 'k', 'hex': 'ff00'},
        {'let': 'x', 'xor': {'data': '{d}', 'key': '{k}'}},
        {'let': 'r', 'hex': '{x}', 'encode': true},
      ]), 'fe02fc04fa');
      expect(result([
        {'let': 'd', 'get': {'var': 'data', 'json': 'data'}},
        {'let': 'k', 'hex': 'ff'},
        {'let': 'x', 'xor': {'data': '{d}', 'key': '{k}'}},
        {'let': 'r', 'template': 'x'},
      ], page: scriptPage('testo')), faultAt('chapter.recipe[2]'));
    });

    test('fetch: modello con query, try, json o testo; conta fra le richieste', () async {
      final more = {
        'https://manhwaread.com/api/pages?c=chapter-1': jsonEncode({'images': [{'src': 'a.webp'}, {'src': 'b.webp'}]}),
        'https://manhwaread.com/b/chapter-1': 'dal-secondo',
      };
      expect(await listed(listing([
        {'let': 'answer', 'fetch': {'template': 'https://manhwaread.com/api/pages', 'query': {'c': '{chapterId}'}}, 'json': true},
        {'let': 'l', 'get': {'var': 'answer', 'json': 'images', 'all': true}},
      ]), more: more), ['a.webp', 'b.webp']);
      expect(await result([
        {'let': 'r', 'fetch': {'try': ['https://manhwaread.com/a/{chapterId}', 'https://manhwaread.com/b/{chapterId}']}},
      ], more: more), 'dal-secondo');
      // La pagina del capitolo più 7 fetch fanno 8 richieste; l'ottavo fetch è la nona.
      final fetches = [for (var i = 0; i < 7; i++) {'let': 'f$i', 'fetch': 'https://manhwaread.com/b/{chapterId}'}];
      expect(await result([...fetches, {'let': 'r', 'template': '{f6}'}], more: more), 'dal-secondo');
      expect(result([...fetches, {'let': 'r', 'fetch': 'https://manhwaread.com/b/{chapterId}'}], more: more),
          throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('troppe richieste'))));
    });

    test('il tetto dei 2048 passi eseguiti si raggiunge con range', () async {
      List<Object?> ranges(int count) => [
            for (var i = 0; i < count; i++)
              {'let': 'l$i', 'range': {'count': '256', 'max': 256, 'as': 'b'}, 'do': {'intExpr': 'b'}},
            {'let': 'r', 'intExpr': 'len(l0)'},
          ];
      expect(await result(ranges(7)), '256');
      expect(result(ranges(8)), throwsA(isA<ProviderError>().having((error) => error.message, 'message', contains('2048'))));
    });

    test('mini Coffee Manga: manifest cifrato, chiave da hmac, blocchi da range, xor, json e fetch', () async {
      final key = List<int>.generate(32, (i) => (i * 37 + 11) & 0xff);
      final manifest = utf8.encode(jsonEncode({
        'e': 1,
        'qn': 'tok',
        'qv': 'z9',
        'pad': 'x' * 70, // più di due blocchi da 32 byte
      }));
      final roundKey = Hmac(sha256, key).convert(utf8.encode('rk|manhwaread.com|chapter-1')).bytes;
      final stream = [
        for (var block = 0; block * 32 < manifest.length; block++)
          ...Hmac(sha256, roundKey).convert(utf8.encode('ks|$block')).bytes,
      ];
      final cipher = [for (var at = 0; at < manifest.length; at++) manifest[at] ^ stream[at]];
      final page = scriptPage(base64Url.encode(cipher).replaceAll('=', ''));
      final recipe = [
        {'let': 'key', 'hex': hexOf(key)},
        {'let': 'rk', 'hmacSha256': {'key': '{key}', 'message': 'rk|manhwaread.com|{chapterId}'}},
        {'let': 'c64', 'get': {'var': 'data', 'json': 'data'}},
        {'let': 'cipher', 'base64': '{c64}', 'url': true},
        {
          'let': 'ks',
          'range': {'count': '(len(cipher) + 31) / 32', 'max': 256, 'as': 'b'},
          'do': {'hmacSha256': {'key': '{rk}', 'message': 'ks|{b}'}},
        },
        {'let': 'plain', 'xor': {'data': '{cipher}', 'key': '{ks}'}},
        {'let': 'manifest', 'json': '{plain}'},
        {'let': 'e', 'get': {'var': 'manifest', 'json': 'e'}, 'check': r'^1$'},
        {'let': 'qn', 'get': {'var': 'manifest', 'json': 'qn'}},
        {'let': 'qv', 'get': {'var': 'manifest', 'json': 'qv'}},
        {'let': 'answer', 'fetch': 'https://manhwaread.com/api/pages?{qn}={qv}', 'json': true},
        {'let': 'l', 'get': {'var': 'answer', 'json': 'images', 'all': true}},
      ];
      final more = {'https://manhwaread.com/api/pages?tok=z9': jsonEncode({'images': [{'src': '1.webp'}, {'src': '2.webp'}]})};
      expect(await listed(listing(recipe), page: page, more: more), ['1.webp', '2.webp']);
      // Con un'altra chiave il manifest non si decifra: guasto del passo json.
      final wrong = [...recipe]..[0] = {'let': 'key', 'hex': '00' * 32};
      expect(listed(listing(wrong), page: page, more: more), faultAt('chapter.recipe[6]'));
    });
  });
}
