// La diagnosi dei ProviderChanged (`docs/siti.md`, «Diagnosi»): fase e campo
// che l'interprete e i provider Dart danno a chi ripara il sito.
import 'dart:convert';
import 'dart:typed_data';

import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers/mangak.dart';
import 'package:test/test.dart';

import 'declarative_test.dart' show MapHttp, chapterPage, htmlSite, seriesPage;

const String _seriesUrl = 'https://examplescans.com/manga/long-road';

class _Offline extends MapHttp {
  _Offline() : super({});

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async => throw const ProviderOffline();
}

class _Page implements ProviderHttp {
  _Page(this.body);

  final String body;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async =>
      (body: Uint8List.fromList(utf8.encode(body)), contentType: 'text/html');

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => throw UnimplementedError();
}

Future<SiteFault?> _faultOf(Future<Object?> operation) async {
  try {
    await operation;
  } on ProviderChanged catch (error) {
    return error.fault;
  }
  fail('doveva sollevare ProviderChanged');
}

void main() {
  final site = DeclarativeProvider.fromJson(htmlSite());
  final chapter = Chapter('1', 'Chapter 1', '1', 'https://examplescans.com/manga/long-road/chapter-1/');

  test('titolo assente: fase series, campo series.title', () async {
    final fault = await _faultOf(site.fetchSeries(_seriesUrl, MapHttp({_seriesUrl: '<p>niente</p>'})));
    expect(fault!.phase, 'series');
    expect(fault.field, 'series.title');
    expect(fault.url, _seriesUrl);
  });

  test('elenco capitoli vuoto: fase chapters, campo series.chapters.items', () async {
    final fault = await _faultOf(site.fetchSeries(_seriesUrl, MapHttp({_seriesUrl: '<h1 class="title">X</h1>'})));
    expect(fault!.phase, 'chapters');
    expect(fault.field, 'series.chapters.items');
    expect(fault.detail, 'elenco vuoto');
  });

  test('id doppi: fase chapters, campo series.chapters.id', () async {
    final twice = seriesPage.replaceAll('chapter-1-5', 'chapter-2');
    final fault = await _faultOf(site.fetchSeries(_seriesUrl, MapHttp({_seriesUrl: twice})));
    expect(fault!.field, 'series.chapters.id');
    expect(fault.detail, contains('due capitoli con id 2'));
  });

  test('tavole assenti: fase pages, campo chapter.pages.items', () async {
    final fault = await _faultOf(site.fetchPages(chapter, MapHttp({chapter.url: '<p></p>'})));
    expect(fault!.phase, 'pages');
    expect(fault.field, 'chapter.pages.items');
    expect(fault.url, chapter.url);
    final ok = await site.fetchPages(chapter, MapHttp({chapter.url: chapterPage}));
    expect(ok.pages, hasLength(2));
  });

  test('require che non vale: campo series.require', () async {
    final json = jsonDecode(jsonEncode(htmlSite())) as Map<String, Object?>;
    json['format'] = 2;
    (json['series'] as Map)['require'] = [
      {'css': 'h1.nope', 'exists': true},
    ];
    final fault = await _faultOf(DeclarativeProvider.fromJson(json).fetchSeries(_seriesUrl, MapHttp({_seriesUrl: seriesPage})));
    expect(fault!.phase, 'series');
    expect(fault.field, 'series.require');
  });

  test('un errore di rete non è un guasto della definizione', () async {
    await expectLater(site.fetchSeries(_seriesUrl, _Offline()), throwsA(isA<ProviderOffline>()));
    await expectLater(site.fetchSeries(_seriesUrl, MapHttp({})), throwsA(isA<HttpStatusError>()));
  });

  test('un provider Dart dà almeno la fase', () async {
    final fault = await _faultOf(MangaK().fetchSeries('https://mangak.io/test-series', _Page('<p>cambiato</p>')));
    expect(fault!.phase, 'series');
  });

  test('detail è di una riga e al più 200 caratteri', () {
    final fault = SiteFault('pages', detail: 'a\n\n  b${'x' * 400}');
    expect(fault.detail!.length, lessThanOrEqualTo(SiteFault.maxDetail));
    expect(fault.detail, startsWith('a b'));
  });

  group('trace: alternative vincenti e sito degradato', () {
    DeclarativeProvider traced(void Function(Map<String, dynamic> series) edit) {
      final json = jsonDecode(jsonEncode(htmlSite())) as Map<String, dynamic>;
      json['format'] = 2;
      edit(json['series'] as Map<String, dynamic>);
      return DeclarativeProvider.fromJson(json);
    }

    Future<List<String>> degradedOf(DeclarativeProvider site, ProviderHttp http) async {
      final trace = SiteTrace();
      final series = await trace.run(() => site.fetchSeries(_seriesUrl, http));
      expect(series.chapters, hasLength(3));
      return trace.degraded;
    }

    test('first che vince alla seconda alternativa', () async {
      final site = traced((series) => series['title'] = {'first': ['h1.nope', 'h1.title']});
      expect(await degradedOf(site, MapHttp({_seriesUrl: seriesPage})), ['series.title#2']);
    });

    test('try che risponde al secondo indirizzo', () async {
      final site = traced((series) => series['url'] = {
            'try': ['https://examplescans.com/old/{id}', 'https://examplescans.com/manga/{id}'],
          });
      expect(await degradedOf(site, MapHttp({_seriesUrl: seriesPage})), ['series.url#2']);
    });

    test('alternative vincenti alla prima: elenco vuoto', () async {
      final site = traced((series) {
        series['title'] = {'first': ['h1.title', 'h1.nope']};
        series['url'] = {'try': ['https://examplescans.com/manga/{id}', 'https://examplescans.com/old/{id}']};
      });
      expect(await degradedOf(site, MapHttp({_seriesUrl: seriesPage})), isEmpty);
    });

    test('un campo dei capitoli che ripiega su ogni elemento compare una volta, in ordine', () async {
      final site = traced((series) {
        series['title'] = {'first': ['h1.nope', 'h1.title']};
        (series['chapters'] as Map<String, dynamic>)['title'] = {'first': ['b', 'em', 'a']};
      });
      expect(await degradedOf(site, MapHttp({_seriesUrl: seriesPage})), ['series.chapters.title#3', 'series.title#2']);
    });

    test('senza traccia nessun costo né effetto; due operazioni insieme non si mescolano', () async {
      final degraded = traced((series) => series['title'] = {'first': ['h1.nope', 'h1.title']});
      expect((await degraded.fetchSeries(_seriesUrl, MapHttp({_seriesUrl: seriesPage}))).title, 'The Long Road');
      final clean = SiteTrace();
      final other = SiteTrace();
      await Future.wait([
        clean.run(() => site.fetchSeries(_seriesUrl, MapHttp({_seriesUrl: seriesPage}))),
        other.run(() => degraded.fetchSeries(_seriesUrl, MapHttp({_seriesUrl: seriesPage}))),
      ]);
      expect(clean.degraded, isEmpty);
      expect(other.degraded, ['series.title#2']);
    });
  });
}
