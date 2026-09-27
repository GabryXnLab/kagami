// Siti finti per i test dell'archivio: rispondono da memoria come MangaK e
// ManhwaRead, con le fixture di `mangaarchive/tests` sul server.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';

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
      if (failOnce == url || broken.contains(url)) {
        failOnce = null;
        throw const ProviderError('Immagine temporaneamente indisponibile.');
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
