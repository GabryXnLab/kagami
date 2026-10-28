// Siti finti per i test dell'archivio: rispondono da memoria come MangaK,
// ManhwaRead, Asura Scans e Coffee Manga, con le fixture di
// `mangaarchive/tests` sul server e, per Asura e Coffee Manga, risposte del
// sito vero ridotte all'osso.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers/coffeemanga.dart';
import 'package:path/path.dart' as p;

/// Un WebP senza perdita di [width]×[height] con un corpo che dipende da
/// [payload]: basta agli header, e due tavole diverse hanno impronte diverse.
Uint8List webp(int width, int height, [String payload = '']) {
  final body = [...sha256.convert(utf8.encode(payload)).bytes];
  final bits = (width - 1) | ((height - 1) << 14);
  final chunk = [
    ...ascii.encode('VP8L'),
    ..._le32(5 + body.length),
    0x2F,
    ..._le32(bits),
    ...body,
  ];
  return Uint8List.fromList([
    ...ascii.encode('RIFF'),
    ..._le32(4 + chunk.length),
    ...ascii.encode('WEBP'),
    ...chunk,
  ]);
}

Uint8List png(int width, int height) => Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0, 0, 0, 13, ...ascii.encode('IHDR'),
      ..._be32(width), ..._be32(height), 8, 2, 0, 0, 0,
    ]);

List<int> _le32(int value) => [for (var i = 0; i < 4; i++) (value >> (8 * i)) & 0xFF];

List<int> _be32(int value) => _le32(value).reversed.toList();

HttpResult _html(String text) =>
    (body: Uint8List.fromList(utf8.encode(text)), contentType: 'text/html');

HttpResult _image(Uint8List body) => (body: body, contentType: 'image/webp');

Uint8List _nextData(Map<String, Object?> props) => Uint8List.fromList(utf8.encode(
    '<html><script id="__NEXT_DATA__" type="application/json">'
    '${jsonEncode({'props': {'pageProps': props}})}</script></html>'));

class FakeMangaK implements ProviderHttp {
  FakeMangaK({this.tallPages = false}) {
    for (final values in urls.values) {
      for (final url in values) {
        images[url] = _page(url);
      }
    }
    images[series['cover'] as String] = webp(80, 120, 'cover');
  }

  /// Con le tavole alte l'archivio le taglia in tessere.
  final bool tallPages;

  Uint8List _page(String url) => tallPages ? webp(40, 3000, url) : webp(80, 120, url);

  final Map<String, Object?> series = {
    'id': 'S1', 'url': '/test-series', 'name': 'Test / Series',
    'cover': 'https://rx.resmk.org/covers/a.webp', 'cv': 123,
    'summary': 'A story', 'tags': [{'name': 'Adventure'}], 'status': 'Ongoing',
    'authors': [{'name': 'Writer'}], 'artists': [{'name': 'Artist'}],
    'stats': {'chaptersCount': 2}, 'chapters': <Object?>[],
    'latestComments': [{'user': {'name': 'private'}}],
  };

  final List<Map<String, Object?>> chapterItems = [
    {'id': 'C2', 'name': 'Chapter 2', 'number': 2, 'url': '/test-series/chapter-2', 'updated_at': 'today'},
    {'id': 'C1', 'name': 'Chapter 1', 'number': 1, 'url': '/test-series/chapter-1', 'updated_at': 'yesterday'},
  ];

  final Map<int, List<String>> urls = {
    1: ['https://rx.qvzre.org/a.webp', 'https://rx.qvzrf.org/b.webp'],
    2: ['https://rx.qvzrg.org/c.webp'],
  };

  final Map<String, Uint8List> images = {};
  final List<String> imageRequests = [];
  String? failOnce;

  /// Quanto dura una tavola, per vedere quante ne scendono insieme.
  Duration imageDelay = Duration.zero;
  int _active = 0;
  int mostAtOnce = 0;
  void Function(String url)? onImage;

  /// Una tavola che il sito non dà più: il capitolo fallisce.
  final Set<String> broken = {};

  void addChapter(int number, String name, String id, List<String> pages) {
    chapterItems.insert(0, {'id': id, 'name': name, 'number': number, 'url': '/test-series/chapter-$number', 'updated_at': 'now'});
    urls[number] = pages;
    for (final url in pages) {
      images[url] = _page(url);
    }
    (series['stats'] as Map)['chaptersCount'] = chapterItems.length;
  }

  @override
  Future<Map<String, Object?>> json(String url) async {
    _check(url, 'https://api.mangak.io/titles/S1/chapters?cv=123');
    return {'success': true, 'data': {'chapters': chapterItems}};
  }

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (url == 'https://mangak.io/test-series') {
      return (body: _nextData({'initialManga': series}), contentType: 'text/html');
    }
    for (final MapEntry(key: number, value: pages) in urls.entries) {
      if (url == 'https://mangak.io/test-series/chapter-$number') {
        final details = [for (final page in pages) {'url': page, 'width': 720, 'height': 3000}];
        return (
          body: _nextData({
            'initialChapter': {
              'id': 'C$number', 'name': 'Chapter $number', 'images': pages,
              'pages': details, 'latest_comments': [{'user': 'private'}],
            },
          }),
          contentType: 'text/html',
        );
      }
    }
    final image = images[url];
    if (image != null) {
      imageRequests.add(url);
      onImage?.call(url);
      if (failOnce == url || broken.contains(url)) {
        failOnce = null;
        throw const ProviderError('Immagine temporaneamente indisponibile.');
      }
      if (imageDelay > Duration.zero) {
        _active++;
        if (_active > mostAtOnce) mostAtOnce = _active;
        await Future<void>.delayed(imageDelay);
        _active--;
      }
      return _image(image);
    }
    throw StateError(url);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) => throw UnimplementedError();
}

void _check(Object? actual, Object? expected) {
  if (actual != expected) throw StateError('$actual != $expected');
}

class FakeManhwaRead implements ProviderHttp {
  FakeManhwaRead({this.alternate = false, this.badPages = false, this.challenge = false});

  static const String url = 'https://manhwaread.com/manhwa/disfarming/';
  static const String cover = 'https://mancover.xyz/cover/disfarming.webp';
  static const List<String> media = [
    'https://manread.xyz/508/123/mr_001.jpg',
    'https://manread.xyz/508/123/mr_002.jpg',
  ];

  final bool alternate;
  final bool badPages;
  final bool challenge;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (url == FakeManhwaRead.url) {
      final container = alternate ? '<div id="groupChapterList">' : '<div id="chaptersList">';
      return _html('''<html><head><meta property="og:image" content="$cover">
                        <meta name="description" content="Story"></head>
                        <body class="postid-508"><h1 class="text-3xl text-primary">Disfarming</h1>
                        <div><span><strong>Artist(s)</strong></span><a>Illustrator</a></div>
                        <div><span>Author</span><a>Writer</a></div>
                        <div><span>Tags</span><a>Action</a><a>Fantasy</a></div>
                        <div><span>Genres</span><a>Adventure</a></div>$container
                        <a class="chapter-item" data-id="3" href="${FakeManhwaRead.url}side-story-1/">
                          <span class="chapter-item__name">Side Story 1</span></a>
                        <a class="chapter-item" data-id="2" href="${FakeManhwaRead.url}chapter-02/">
                          <span class="chapter-item__name">Chapter 02</span>
                          <span class="chapter-item__date">Yesterday</span></a>
                        <a class="chapter-item" data-id="1" href="${FakeManhwaRead.url}chapter-01/">
                          <span class="chapter-item__name">Chapter 01</span></a>
                        </div><a href="https://example.org/advert">Ad</a></body></html>''');
    }
    if (url == '${FakeManhwaRead.url}chapter-01/') {
      if (challenge) throw const CloudflareChallenge();
      final images = [{'src': 'mr_001.jpg'}, {'src': 'mr_002.jpg'}];
      var encoded = base64.encode(utf8.encode(jsonEncode(images))).replaceAll('=', '');
      if (badPages) encoded = 'invalid*';
      final data = jsonEncode({'data': encoded, 'base': 'https://manread.xyz/508/123'});
      return _html('<meta name="description" content="Chapter summary">'
          '<meta name="keywords" content="Action, Fantasy">'
          '<script>window.chapterData = $data;</script>');
    }
    if (url == cover) return _image(webp(80, 120, 'cover'));
    if (media.contains(url)) {
      if (referer != '${FakeManhwaRead.url}chapter-01/') throw StateError('Referer mancante');
      return _image(webp(80, 120, url));
    }
    throw StateError(url);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async {
    if (referer != '${FakeManhwaRead.url}chapter-01/') throw StateError('Referer mancante');
    return const {
      'https://manread.xyz/508/1/mr_001.jpg',
      'https://manread.xyz/508/1/mr_002.jpg',
    }.contains(url);
  }

  @override
  Future<Map<String, Object?>> json(String url) => throw UnimplementedError();
}

/// L'API di Asura Scans: la serie, l'elenco dal più recente con un capitolo
/// in accesso anticipato, e le tavole di ogni capitolo.
class FakeAsuraScans implements ProviderHttp {
  FakeAsuraScans() {
    for (final pages in chapterPages.values) {
      for (final page in pages) {
        images[page] = webp(80, 120, page);
      }
    }
    images[cover] = webp(80, 120, 'cover');
  }

  static const String api = 'https://api.asurascans.com/api';
  static const String cover = 'https://cdn.asurascans.com/asura-images/covers/war-of-extinction.f60b25.webp';

  final Map<String, Object?> series = {
    'id': '6090', 'slug': 'war-of-extinction', 'title': 'War of Extinction',
    'alt_titles': ['멸망전쟁'],
    'description': '<p>Heavenly Demons. Hunters.</p><p>[Game Character<br>Abilities Synchronized.]</p>',
    'cover': cover, 'status': 'ongoing', 'type': 'manhwa',
    'author': 'Writer', 'artist': 'Studio', 'chapter_count': 3,
    'created_at': '0001-01-01T00:00:00Z', 'updated_at': '2026-10-06T15:05:06Z',
    'public_url': '/comics/war-of-extinction-bd5bdaf8', 'source_url': '/s/6090',
    'genres': [{'id': 1, 'name': 'Action', 'slug': 'action'}, {'id': 16, 'name': 'Fantasy', 'slug': 'fantasy'}],
  };

  final List<Map<String, Object?>> chapters = [
    {'id': 103, 'number': 3, 'slug': 'chapter-3', 'is_premium': true, 'series_slug': 'war-of-extinction'},
    {'id': 102, 'number': 2, 'title': 'The Arena', 'slug': 'chapter-2', 'is_premium': false, 'series_slug': 'war-of-extinction'},
    {
      'id': 101, 'number': 1, 'slug': 'ac158a3a-7e87-4492-b792-cf36c9ef9dd5', 'is_premium': false,
      'series_slug': 'war-of-extinction', 'published_at': '2026-09-17T02:01:53Z',
    },
  ];

  final Map<int, List<String>> chapterPages = {
    101: [
      'https://cdn.asurascans.com/asura-images/chapters/war-of-extinction/1/7812b6.webp?v=1789613919',
      'https://cdn.asurascans.com/asura-images/chapters/war-of-extinction/1/b69f1b.webp?v=1789613919',
    ],
    102: ['https://cdn.asurascans.com/asura-images/chapters/war-of-extinction/2/8cdc64.webp?v=1790787858'],
  };

  final Map<String, Uint8List> images = {};
  final List<String> requests = [];

  /// I capitoli che l'API dà chiusi, come durante l'accesso anticipato.
  final Set<int> locked = {};

  Map<String, Object?> _chapter(int id) {
    final item = chapters.firstWhere((c) => c['id'] == id);
    return {
      'access_gate': '',
      'is_locked': locked.contains(id),
      'chapter': {
        ...item,
        if (!locked.contains(id))
          'pages': [
            for (final (i, url) in chapterPages[id]!.indexed)
              {'url': url, if (i == 0) 'width': 900, if (i == 0) 'height': 16000},
          ],
      },
    };
  }

  @override
  Future<Map<String, Object?>> json(String url) async {
    requests.add(url);
    if (url == '$api/series/war-of-extinction') {
      return {'series': series, 'recommended_series': <Object?>[], 'linked_ebook': null};
    }
    if (url == '$api/series/war-of-extinction/chapters') return {'data': chapters};
    for (final item in chapters) {
      if (url == '$api/series/war-of-extinction/chapters/${item['slug']}') return {'data': _chapter(item['id'] as int)};
    }
    if (url.startsWith('$api/series/')) throw HttpStatusError(404);
    throw StateError(url);
  }

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    requests.add(url);
    final image = images[url];
    if (image != null) return _image(image);
    throw StateError(url);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) => throw UnimplementedError();
}

/// Una pagina dell'app Inertia di Coffee Manga: lo stato sta in `data-page`.
String coffeePage(String component, Map<String, Object?> props, {String head = ''}) =>
    '<html><head>$head</head><body><div id="app"><script data-page="app" type="application/json">'
    '${jsonEncode({'component': component, 'props': props, 'url': '/', 'version': 'x'})}'
    '</script></div></body></html>';

/// Coffee Manga: le pagine vere ridotte a ciò che il provider legge, con il
/// manifest cifrato come lo fa il sito (chiave dal bundle, HMAC a blocchi).
class FakeCoffeeManga implements ProviderHttp {
  FakeCoffeeManga() {
    for (final pages in chapterPages.values) {
      for (final page in pages) {
        images[page] = webp(80, 120, page);
      }
    }
    images[cover] = webp(80, 120, 'cover');
  }

  static const String host = 'https://coffeemanga.net';
  static const String slug = 'the-house-without-time';
  static const String url = '$host/manga/$slug/';
  static const String cover = '$host/img/COVERBIG/rs:fill:772:1112/g:sm/Y292ZXI';
  static const String bundleUrl = '$host/build/assets/g2/app-TEST.js';

  /// Dal più recente, come li dà il sito; il 3 è riservato ai VIP.
  /// `(slug, numero, id nella pagina del capitolo, riservato)`.
  final List<(String, String, int, bool)> chapters = [
    ('chapter-3', '3', 183003, true),
    ('chapter-1-5', '1.5', 183002, false),
    ('chapter-1', '1', 183001, false),
  ];
  static const int perPage = 2;

  /// Il `v` del manifest di ogni capitolo: quale forma di risposta e quale
  /// codifica dei dati.
  final Map<String, int> versions = {'chapter-1': 1, 'chapter-1-5': 5};

  /// Quanti capitoli dichiara la pagina; `null` per quelli dell'elenco.
  int? declared;

  /// Il testo del bundle: la vera `TE()` con il suo array, in mezzo ad altro.
  String bundle = 'var a=1;${File('test/fixtures/coffeemanga_key.js').readAsStringSync()}const OE=new Uint32Array([1]);';

  /// Le richieste al manifest rispondono 428, come quando serve Turnstile.
  bool turnstile = false;

  final Map<String, List<String>> chapterPages = {
    'chapter-1': [for (final n in [1, 2, 3]) '$host/img/SIG$n/raw:1/MDAx$n'],
    // L'ultima striscia di un capitolo, di pochi pixel, non ha la variante `raw`.
    'chapter-1-5': ['$host/img/SIG9/rs:fit:600:0/MDAx9'],
  };

  final Map<String, Uint8List> images = {};
  final List<String> requests = [];

  List<Map<String, Object?>> _items(List<(String, String, int, bool)> source) => [
        for (final (chapterSlug, number, _, locked) in source)
          {
            'slug': chapterSlug,
            'label': 'Chapter $number',
            'url': '/manga/$slug/$chapterSlug/',
            'published_at': '2026-06-18T15:32:17+00:00',
            'access': locked ? 'vip' : 'free',
            'locked': locked,
            'number': number,
            'title': null,
            'pages': 14,
          },
      ];

  List<(String, String, int, bool)> _slice(int page) =>
      chapters.skip((page - 1) * perPage).take(perPage).toList();

  Map<String, Object?> _pagination() => {
        'page': 1,
        'last': (chapters.length / perPage).ceil(),
        'total': declared ?? chapters.length,
        'per_page': perPage,
        'json': '/manga/$slug/chapters/__PAGE__.json',
      };

  String _series() => coffeePage('Catalog/Series', {
        'rating': {'avg': 4.43, 'count': 7},
        'series': {
          'slug': slug,
          'url': '/manga/$slug/',
          'title': 'The House Without Time',
          'type': 'manhwa',
          'status': 'ongoing',
          'cover': '$host/img/COVERSMALL/rs:fill:193:278/g:sm/Y292ZXI',
          'cover_lg': '$host/img/COVERMID/rs:fill:386:556/g:sm/Y292ZXI',
          'cover_canonical': cover,
          'alt_titles': ['Shard of Time / 시간이 머문 집'],
          'synopsis': 'A broken girl meets an old man.',
          'release_year': 2025,
          'genres': [
            {'slug': 'fantasy', 'name': 'Fantasy', 'url': '/manga-genre/fantasy/'},
            {'slug': 'action', 'name': 'Action', 'url': '/manga-genre/action/'},
          ],
          'tags': [{'slug': 'fantasy-adventure', 'name': 'fantasy-adventure', 'url': '/manga-tag/fantasy-adventure/'}],
          'authors': [{'slug': 'writer', 'name': 'Writer'}, 'Other Writer'],
          'artists': [],
          'chapter_count': chapters.length,
        },
        'chapters': _items(_slice(1)),
        'chapters_pagination': _pagination(),
        'locked_count': chapters.where((c) => c.$4).length,
      });

  Map<String, Object?> _tavola(String raw, int n) => {
        'n': n,
        'src': null,
        'srcset': raw.contains('/raw:1/')
            ? '${raw.replaceFirst('/raw:1/', '/rs:fit:520:0/')} 520w, $raw 709w'
            : '${raw.replaceFirst('/rs:fit:600:0/', '/rs:fit:520:0/')} 520w, $raw 600w',
        'width': 709,
        'height': 1000 + n,
      };

  Uint8List _key() => coffeeMangaKey(bundle);

  Uint8List _hmac(List<int> key, String message) =>
      Uint8List.fromList(Hmac(sha256, key).convert(utf8.encode(message)).bytes);

  String _q(String chapterSlug) => 'q-$chapterSlug';

  String _chapter(String chapterSlug) {
    final (_, number, id, locked) = chapters.firstWhere((c) => c.$1 == chapterSlug);
    final raw = chapterPages[chapterSlug] ?? const <String>[];
    final manifest = utf8.encode(jsonEncode({
      'e': 'meaqclptin',
      'p': ['pa', 'pb', 'pc'],
      'v': versions[chapterSlug] ?? 1,
      'k': 'd0c5bcb3134cb9fe8dc6913211696ed8',
      'c': 'x-262bcfe4',
      'q': _q(chapterSlug),
      'n': null,
    }));
    final secret = _hmac(_key(), 'rk|coffeemanga.net|$id');
    final cipher = Uint8List.fromList(manifest);
    for (var block = 0, offset = 0; offset < cipher.length; block++, offset += 32) {
      final mask = _hmac(secret, 'ks|$block');
      for (var i = 0; i < 32 && offset + i < cipher.length; i++) {
        cipher[offset + i] ^= mask[i];
      }
    }
    return coffeePage(
      'Reader/Chapter',
      {
        'series': {'slug': slug, 'title': 'The House Without Time'},
        'chapter': {'slug': chapterSlug, 'id': id, 'locked': locked, 'number': '$number.000'},
        'pages': [if (raw.isNotEmpty) _tavola(raw.first, 1)],
        'dims': [for (final n in List.generate(raw.length, (i) => i + 1).skip(1)) [709, 1000 + n]],
        'total': raw.length,
        'reader': {'x': base64Url.encode(cipher).replaceAll('=', '')},
      },
      head: '<script type="module" src="$bundleUrl"></script>',
    );
  }

  HttpResult _json(Object? value) =>
      (body: Uint8List.fromList(utf8.encode(jsonEncode(value))), contentType: 'application/json');

  HttpResult _manifest(String chapterSlug, int id) {
    final v = versions[chapterSlug] ?? 1;
    final data = jsonEncode([
      for (final (i, raw) in (chapterPages[chapterSlug] ?? const <String>[]).indexed) _tavola(raw, i + 1),
    ]);
    final mask = [for (var i = 0; i < 32; i += 2) int.parse('d0c5bcb3134cb9fe8dc6913211696ed8'.substring(i, i + 2), radix: 16)];
    final d = switch (v % 3) {
      0 => data,
      1 => base64.encode(utf8.encode(data)),
      _ => base64.encode([for (final (i, b) in utf8.encode(data).indexed) b ^ mask[i % mask.length]]),
    };
    final envelope = {'c': id, 'e': 1793216018, 'd': d, 's': 'sig'};
    return _json(switch (v ~/ 3) {
      0 => envelope,
      1 => [envelope['c'], envelope['e'], envelope['d'], envelope['s']],
      _ => {'r': envelope},
    });
  }

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    requests.add(url);
    final image = images[url];
    if (image != null) return _image(image);
    if (url == FakeCoffeeManga.url) return _html(_series());
    if (url == bundleUrl) return (body: Uint8List.fromList(utf8.encode(bundle)), contentType: 'text/javascript');
    final more = RegExp('^$host/manga/$slug/chapters/(\\d+)\\.json\$').firstMatch(url);
    if (more != null) return _json({'items': _items(_slice(int.parse(more[1]!)))});
    for (final (chapterSlug, _, id, _) in chapters) {
      if (url == '$host/manga/$slug/$chapterSlug/') return _html(_chapter(chapterSlug));
      if (url == '$host/meaqclptin/$id?pa=$slug&pc=${_q(chapterSlug)}') {
        if (turnstile) throw HttpStatusError(428);
        return _manifest(chapterSlug, id);
      }
    }
    throw HttpStatusError(404);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> json(String url) => throw UnimplementedError();
}

class ChallengedHttp implements ProviderHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) =>
      throw const CloudflareChallenge();

  @override
  Future<bool> imageExists(String url, {required String referer}) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> json(String url) => throw UnimplementedError();
}

class ForbiddenHttp extends ChallengedHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) =>
      throw HttpStatusError(403);
}

class PageHttp extends ChallengedHttp {
  PageHttp(this.body);

  final String body;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async => _html(body);
}

/// Risponde alle ricerche con ciò che gli si dà, e ricorda cosa gli è stato
/// chiesto.
class SearchHttp extends ChallengedHttp {
  SearchHttp({this.response = const {}, this.page = '', this.error});

  final Map<String, Object?> response;
  final String page;
  final ProviderError? error;
  final List<String> requests = [];

  @override
  Future<Map<String, Object?>> json(String url) async {
    requests.add(url);
    if (error case final error?) throw error;
    return response;
  }

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    requests.add(url);
    if (error case final error?) throw error;
    return _html(page);
  }
}

/// Come il Kotlin: una miniatura e tessere che dipendono dalla tavola.
class FakeImageTools implements ImageTools {
  int tilesMade = 0;

  @override
  Future<Uint8List?> thumbnail(File cover) async =>
      Uint8List.fromList(utf8.encode('thumb:${cover.lengthSync()}'));

  @override
  Future<List<Uint8List>?> tiles(File page, List<int> heights) async {
    tilesMade++;
    final digest = sha256.convert(page.readAsBytesSync()).toString();
    return [for (var i = 0; i < heights.length; i++) Uint8List.fromList(utf8.encode('$digest-$i'))];
  }
}

/// Drive in memoria, con i byte e l'MD5 che il vero restituisce.
class FakeDrive implements SyncRemote {
  static const String root = 'ROOT';

  final Map<String, DriveItem> items = {};
  final Map<String, Uint8List> contents = {};
  var _next = 0;
  int uploads = 0;

  /// I nomi caricati, nell'ordine in cui sono arrivati, e quanti insieme al
  /// massimo.
  final List<String> uploaded = [];
  int _active = 0;
  int mostAtOnce = 0;
  void Function(String name)? onUpload;

  /// Il caricamento che fallisce, per nome.
  String? failUpload;

  /// Quanto dura in più il caricamento di un file, per nome.
  final Map<String, Duration> slow = {};

  DriveItem _put(DriveItem item) => items[item.id] = item;

  String folder(String path) {
    var parent = root;
    for (final name in path.split('/').where((part) => part.isNotEmpty)) {
      final found = items.values.where((i) => i.folder && i.name == name && i.parents.contains(parent));
      parent = found.isNotEmpty
          ? found.first.id
          : _put(DriveItem(id: 'f${_next++}', name: name, folder: true, parents: [parent])).id;
    }
    return parent;
  }

  /// Un file messo da un altro, il server.
  void place(String path, List<int> bytes) {
    final parent = folder(p.posix.dirname(path) == '.' ? '' : p.posix.dirname(path));
    // Un file che c'è già si riscrive al suo posto, come farebbe Drive.
    final id = find(path)?.id ?? 'x${_next++}';
    _put(DriveItem(id: id, name: p.posix.basename(path), size: bytes.length, md5: md5.convert(bytes).toString(), parents: [parent]));
    contents[id] = Uint8List.fromList(bytes);
  }

  DriveItem? find(String path) {
    var parent = root;
    final parts = path.split('/');
    for (var i = 0; i < parts.length; i++) {
      final found = items.values.where((item) => item.name == parts[i] && item.parents.contains(parent)).toList();
      if (found.isEmpty) return null;
      if (i == parts.length - 1) return found.first;
      parent = found.first.id;
    }
    return null;
  }

  Uint8List? read(String path) => contents[find(path)?.id];

  List<String> namesIn(String path) => [
        for (final item in items.values)
          if (item.parents.contains(path.isEmpty ? root : find(path)!.id)) item.name,
      ]..sort();

  @override
  Future<List<DriveItem>> childrenOf(List<String> folderIds) async =>
      [for (final item in items.values) if (item.parents.any(folderIds.contains)) item];

  @override
  Future<DriveItem> createFolder(String name, String parentId) async =>
      _put(DriveItem(id: 'f${_next++}', name: name, folder: true, parents: [parentId]));

  @override
  Future<void> download(String id, File target) async {
    await target.writeAsBytes(contents[id]!);
  }

  @override
  Future<void> trash(String id) async => items.remove(id);

  int renames = 0;

  @override
  Future<DriveItem> rename(String id, String name) async {
    renames++;
    return _put(DriveItem(id: id, name: name, folder: items[id]!.folder, size: items[id]!.size, md5: items[id]!.md5, parents: items[id]!.parents));
  }

  @override
  Future<DriveItem> upload(File file, {String? id, String? name, String? parentId, DateTime? modified}) async {
    final bytes = await file.readAsBytes();
    final previous = id == null ? null : items[id];
    if ((name ?? previous?.name) == failUpload) throw const DriveOffline();
    _active++;
    mostAtOnce = _active > mostAtOnce ? _active : mostAtOnce;
    // Un caricamento vero dura: gli altri devono potersi sovrapporre.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final extra = slow[name ?? previous!.name];
    if (extra != null) await Future<void>.delayed(extra);
    _active--;
    uploads++;
    uploaded.add(name ?? previous!.name);
    onUpload?.call(name ?? previous!.name);
    final item = _put(DriveItem(
      id: id ?? 'u${_next++}',
      name: name ?? previous!.name,
      size: bytes.length,
      md5: md5.convert(bytes).toString(),
      parents: previous?.parents ?? [parentId!],
    ));
    contents[item.id] = bytes;
    return item;
  }
}
