// La sentinella: classificazione per sito, fase che fallisce, forma del JSON.
// Provider finti e un server HTTP locale per l'immagine: nessuna rete vera.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/probe.dart';
import 'package:test/test.dart';

final Uint8List _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13]);

class _Http implements ProviderHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) => throw UnimplementedError();
  @override
  Future<bool> imageExists(String url, {required String referer}) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> json(String url) => throw UnimplementedError();
}

class _Site extends Provider {
  _Site({this.onSearch, this.onSeries, this.onPages});

  final Future<List<SearchResult>> Function()? onSearch;
  final Future<Series> Function()? onSeries;
  final Future<ChapterContent> Function()? onPages;

  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get home => 'https://fake.test/';
  @override
  bool accepts(String url) => true;
  @override
  String? seriesOfChapter(String url) => null;
  @override
  bool allowedHost(Uri uri) => true;
  @override
  void validateUrl(String url) {}

  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) =>
      onSearch?.call() ??
      Future.value([SearchResult(provider: id, title: 'T', url: 'https://fake.test/s')]);

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) =>
      onSeries?.call() ??
      Future.value(Series(
        provider: id,
        id: 's',
        title: 'T',
        url: url,
        coverUrl: null,
        metadata: const {},
        chapters: [const Chapter('1', 'Capitolo 1', '1', 'https://fake.test/s/1')],
      ));

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) =>
      onPages?.call() ?? Future.value(const ChapterContent([Page('https://img.test/1.png')], {}));
}

Future<SiteProbe> _run(_Site site, {List<Canary> canary = const [Canary(query: 'q')], Uint8List? image}) =>
    probeSite(site, canary, (_) => _Http(), fetchImage: (url, referer) async => image ?? _png);

void main() {
  test('un sito sano è ok, con origine e senza fase', () async {
    final result = await _run(_Site());
    expect(result.status, ProbeStatus.ok);
    expect(result.phase, isNull);
    expect(result.origin, 'builtIn');
    expect(result.failed, isFalse);
  });

  test('senza canarino il sito è saltato, non rotto', () async {
    final result = await probeSite(_Site(), null, (_) => _Http());
    expect(result.status, ProbeStatus.skipped);
    expect(result.failed, isFalse);
  });

  test('ricerca vuota, ProviderChanged e struttura inattesa sono changed, con la fase', () async {
    var r = await _run(_Site(onSearch: () async => const []));
    expect((r.status, r.phase), (ProbeStatus.changed, 'search'));
    r = await _run(_Site(onSeries: () async => throw const ProviderChanged('niente titolo')), canary: const [Canary(url: 'https://fake.test/s')]);
    expect((r.status, r.phase, r.message), (ProbeStatus.changed, 'series', 'niente titolo'));
    r = await _run(_Site(onPages: () async => throw StateError('boom')));
    expect((r.status, r.phase), (ProbeStatus.changed, 'pages'));
    r = await _run(_Site(onPages: () async => const ChapterContent([], {})));
    expect((r.status, r.phase), (ProbeStatus.changed, 'pages'));
  });

  test('rete, 5xx e timeout sono offline; 404 è changed', () async {
    var r = await _run(_Site(onSearch: () async => throw const ProviderOffline()));
    expect((r.status, r.phase), (ProbeStatus.offline, 'search'));
    r = await _run(_Site(onSeries: () async => throw HttpStatusError(503)));
    expect((r.status, r.phase), (ProbeStatus.offline, 'series'));
    r = await _run(_Site(onSeries: () async => throw HttpStatusError(404)));
    expect(r.status, ProbeStatus.changed);
    r = await probeSite(_Site(onSearch: () => Completer<List<SearchResult>>().future), const [Canary(query: 'q')], (_) => _Http(),
        timeout: const Duration(milliseconds: 50));
    expect(r.status, ProbeStatus.offline);
  });

  test('la verifica di Cloudflare è gated', () async {
    var r = await _run(_Site(onSearch: () async => throw const CloudflareChallenge()));
    expect((r.status, r.phase), (ProbeStatus.gated, 'search'));
    r = await _run(_Site(onSeries: () async => throw HttpStatusError(403)));
    expect(r.status, ProbeStatus.gated);
  });

  test('la prima tavola deve essere un\'immagine', () async {
    final r = await _run(_Site(), image: Uint8List.fromList(utf8.encode('<html>blocked</html>')));
    expect((r.status, r.phase), (ProbeStatus.changed, 'image'));
  });

  test('fetchImagePrefix legge i primi byte da un server locale e rifiuta un 5xx', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      if (request.uri.path == '/ok.png') {
        request.response.add(_png);
      } else {
        request.response.statusCode = 502;
      }
      await request.response.close();
    });
    final base = 'http://127.0.0.1:${server.port}';
    final head = await fetchImagePrefix('$base/ok.png', '$base/');
    expect(looksLikeImage(head), isTrue);
    expect(() => fetchImagePrefix('$base/rotta.png', '$base/'), throwsA(isA<HttpStatusError>()));
  });

  test('il canarino si legge da JSON e il rapporto ha la forma attesa', () async {
    final canaries = Canary.parse('{"sites":{"a":{"query":"q","url":"https://a.test/s"},"b":{"query":"x"}}}');
    expect(canaries['a']!.single.url, 'https://a.test/s');
    expect(canaries['b']!.single.url, isNull);
    expect(() => Canary.parse('{}'), throwsFormatException);
    final r = await _run(_Site());
    final report = probeReport([r], checkedAt: DateTime.utc(2026, 11, 15), engine: 1, serial: 7);
    expect(report.keys, ['checkedAt', 'engine', 'serial', 'sites']);
    expect(report['checkedAt'], '2026-11-15T00:00:00.000Z');
    final site = (report['sites']! as List).single as Map;
    expect(site.keys, containsAll(['site', 'status', 'phase', 'message', 'durationMs', 'version', 'origin', 'fault', 'degraded', 'canaries']));
    expect(probeLine(r), startsWith('ok'));
  });

  test('fault: dal ProviderChanged, dal 4xx e dal conteggio dei capitoli', () async {
    var r = await _run(_Site(onSeries: () async => throw ProviderChanged('x', fault: SiteFault('series', field: 'series.title', detail: 'vuoto'))),
        canary: const [Canary(url: 'https://fake.test/s')]);
    expect(r.fault!.field, 'series.title');
    expect(r.toJson()['fault'], {'phase': 'series', 'field': 'series.title', 'detail': 'vuoto'});
    r = await _run(_Site(onSeries: () async => throw HttpStatusError(404)));
    expect((r.fault!.phase, r.fault!.detail), ('series', 'HTTP 404'));
    r = await _run(_Site(), canary: const [Canary(query: 'q', minChapters: 5)]);
    expect((r.status, r.phase, r.fault!.field), (ProbeStatus.changed, 'chapters', 'series.chapters'));
  });

  test('degraded dalla traccia e canarini multipli: vince il migliore, i falliti sono canary#n', () async {
    final degradedSite = _Site(onSeries: () async {
      SiteTrace.current!.note('series.title', 2);
      return Series(provider: 'fake', id: 's', title: 'T', url: 'u', coverUrl: null, metadata: const {}, chapters: [const Chapter('1', 'C', '1', 'u/1')]);
    });
    var r = await _run(degradedSite);
    expect(r.status, ProbeStatus.ok);
    expect(r.degraded, ['series.title#2']);
    var calls = 0;
    final flaky = _Site(onSearch: () async {
      if (++calls == 2) throw const ProviderChanged('rotto');
      return [SearchResult(provider: 'fake', title: 'T', url: 'https://fake.test/s')];
    });
    r = await _run(flaky, canary: const [Canary(query: 'a'), Canary(query: 'b'), Canary(query: 'c')]);
    expect(r.status, ProbeStatus.ok);
    expect(r.degraded, ['canary#2']);
    final json = r.toJson()['canaries']! as List;
    expect(json.map((c) => (c as Map)['status']), ['ok', 'changed', 'ok']);
    expect((json[1] as Map)['fault'], isNotNull);
    r = await _run(_Site(onSearch: () async => const []), canary: const [Canary(query: 'a'), Canary(query: 'b')]);
    expect(r.status, ProbeStatus.changed);
  });

  test('canaries.json: lista fino a 3, oggetto singolo ancora valido, minChapters', () {
    final c = Canary.parse('{"sites":{"a":[{"query":"q","minChapters":200},{"url":"u"}],"b":{"query":"x"}}}');
    expect(c['a']!.length, 2);
    expect(c['a']!.first.minChapters, 200);
    expect(c['b']!.length, 1);
    expect(() => Canary.parse('{"sites":{"a":[{},{},{},{}]}}'), throwsFormatException);
  });
}
