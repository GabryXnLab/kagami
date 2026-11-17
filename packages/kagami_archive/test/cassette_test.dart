import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/cassette.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:test/test.dart';

import 'archive_fakes.dart';

class _Live implements ProviderHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (url.endsWith('/page')) return (body: utf8.encode('<html>ciao</html>'), contentType: 'text/html; charset=utf-8');
    if (url.endsWith('/api')) return (body: utf8.encode('{"a":1}'), contentType: 'application/json');
    throw HttpStatusError(url.endsWith('/gone') ? 404 : 403);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async => url.endsWith('.webp');

  @override
  Future<Map<String, Object?>> json(String url) async => decodeJsonObject((await get(url)).body);
}

/// Come in catalog_parity_test: le API rispondono dal `json` del finto.
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

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cassette'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<RecordingHttp> record() async {
    final rec = RecordingHttp(_Live());
    await rec.get('https://x.io/page', referer: 'https://x.io/');
    await rec.json('https://x.io/api');
    await rec.imageExists('https://x.io/a.webp', referer: 'https://x.io/');
    await rec.imageExists('https://x.io/b.png', referer: 'https://x.io/');
    for (final url in ['https://x.io/gone', 'https://x.io/denied']) {
      await expectLater(rec.get(url), throwsA(isA<HttpStatusError>()));
    }
    return rec;
  }

  test('registra, salva, rileggi, replay identico', () async {
    (await record()).save(dir);
    final replay = ReplayHttp.load(dir);
    final page = await replay.get('https://x.io/page');
    expect(utf8.decode(page.body), '<html>ciao</html>');
    expect(page.contentType, 'text/html');
    expect(await replay.json('https://x.io/api'), {'a': 1});
    expect(await replay.imageExists('https://x.io/a.webp', referer: 'https://x.io/'), isTrue);
    expect(await replay.imageExists('https://x.io/b.png', referer: 'https://x.io/'), isFalse);
    await expectLater(replay.get('https://x.io/gone'), throwsA(isA<HttpStatusError>().having((e) => e.status, 'status', 404)));
    await expectLater(replay.get('https://x.io/denied'), throwsA(isA<HttpStatusError>().having((e) => e.status, 'status', 403)));
  });

  test('richiesta non prevista nomina l\'indirizzo', () async {
    (await record()).save(dir);
    await expectLater(
      ReplayHttp.load(dir).get('https://x.io/altro'),
      throwsA(isA<CassetteMiss>().having((e) => e.toString(), 'testo', contains('https://x.io/altro'))),
    );
  });

  test('un nome di file ostile è rifiutato', () async {
    for (final name in ['../evil', '/etc/passwd', 'a/b.html', '..']) {
      File('${dir.path}/cassette.json').writeAsStringSync(jsonEncode({
        'entries': {'https://x.io/': {'status': 200, 'contentType': 'text/html', 'file': name}},
      }));
      expect(() => Cassette.load(dir), throwsA(isA<CassetteFormatError>()), reason: name);
    }
  });

  test('nel file salvato non ci sono header né cookie', () async {
    (await record()).save(dir);
    final text = File('${dir.path}/cassette.json').readAsStringSync().toLowerCase();
    expect(text, isNot(contains('cookie')));
    expect(text, isNot(contains('referer')));
    for (final entry in (jsonDecode(text)['entries'] as Map).values) {
      expect((entry as Map).keys.toSet().difference({'status', 'contenttype', 'file'}), isEmpty);
    }
  });

  test('expect.json va e torna', () {
    const expectation = CassetteExpect(
      query: 'solo leveling', url: 'https://x.io/s', seriesId: '123', title: 'Solo', minChapters: 200, firstPage: 'https://x.io/1.webp',
    );
    expectation.save(dir);
    final back = CassetteExpect.load(dir);
    expect((back.query, back.url, back.seriesId, back.title, back.minChapters, back.firstPage),
        ('solo leveling', 'https://x.io/s', '123', 'Solo', 200, 'https://x.io/1.webp'));
  });

  test('mangak del catalogo gira su una cassetta registrata dai finti', () async {
    const url = 'https://mangak.io/test-series';
    final site = DeclarativeProvider.parse(
      File('../../catalog/sites/mangak.json').readAsStringSync(),
      catalog: CatalogSite(id: 'mangak', state: CatalogSiteState.ok, variants: const []),
    );
    final rec = RecordingHttp(_ApiAsGet(FakeMangaK()));
    final live = await site.fetchSeries(url, rec);
    final pages = await site.fetchPages(live.chapters.first, rec);
    rec.save(dir);

    final replay = ReplayHttp.load(dir);
    final series = await site.fetchSeries(url, replay);
    expect([for (final c in series.chapters) c.id], [for (final c in live.chapters) c.id]);
    final again = await site.fetchPages(series.chapters.first, replay);
    expect([for (final p in again.pages) p.url], [for (final p in pages.pages) p.url]);
  });
}
