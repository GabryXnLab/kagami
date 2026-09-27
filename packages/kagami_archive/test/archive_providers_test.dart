// I provider dell'archivio contro risposte finte: le stesse fixture dei test
// di `mangaarchive` sul server, perché i due lati devono leggere i siti allo
// stesso modo.
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/images.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/names.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/providers/mangak.dart';
import 'package:kagami_archive/providers/manhwaread.dart';

import 'archive_fakes.dart';

void main() {
  group('MangaK', () {
    test('metadati ed elenco completo dei capitoli', () async {
      final http = FakeMangaK();
      final provider = selectProvider('https://mangak.io/test-series');
      final series = await provider.fetchSeries('https://mangak.io/test-series', http);
      expect(series.chapters.map((c) => c.number), ['1', '2']);
      expect((series.metadata['artists'] as List).first, {'name': 'Artist'});
      expect(series.metadata.containsKey('latestComments'), isFalse);
      final content = await provider.fetchPages(series.chapters.first, http);
      expect(content.pages, hasLength(2));
      expect(content.metadata.containsKey('latest_comments'), isFalse);
      expect(() => selectProvider('https://mangak.io/test-series/chapter-1'),
          throwsA(isA<ProviderError>()));
      expect(() => provider.validateUrl('https://127.0.0.1/private'),
          throwsA(isA<ProviderError>()));
      expect(selectProvider('https://manhwaread.com/manhwa/disfarming/').id, 'manhwaread');
    });

    test('il numero è quello del nome, non il posto nell\'elenco', () async {
      final http = FakeMangaK();
      // Com'è Mr Devourer: dopo il 70.5 il `number` del sito è avanti di uno.
      http.chapterItems.insert(0, {
        'id': 'C3', 'name': 'Chapter 2.5', 'number': 3,
        'url': '/test-series/chapter-2-5', 'updated_at': 'now',
      });
      http.chapterItems.insert(0, {
        'id': 'C4', 'name': 'Chapter 3', 'number': 4,
        'url': '/test-series/chapter-3', 'updated_at': 'now',
      });
      http.chapterItems.insert(0, {
        'id': 'C5', 'name': 'Prologue', 'number': 5,
        'url': '/test-series/chapter-prologue', 'updated_at': 'now',
      });
      (http.series['stats'] as Map)['chaptersCount'] = 5;
      final series = await MangaK().fetchSeries('https://mangak.io/test-series', http);
      expect(series.chapters.map((c) => c.number), ['1', '2', '2.5', '3', 'Prologue']);
      expect(chapterFolderName(series.chapters[2]), '0002.5 - Chapter 2.5 [C3]');
      expect(series.chapters[3].metadata['number'], 4);
    });

    test('un capitolo che non si chiama chapter-… passa, uno fuori dalla serie no', () async {
      final http = FakeMangaK();
      // Com'è Kidnapped Dragons: un avviso di una tavola fra i capitoli.
      http.chapterItems.insert(0, {
        'id': 'C3', 'name': 'Notice.', 'number': 3,
        'url': '/test-series/notice', 'updated_at': 'now',
      });
      (http.series['stats'] as Map)['chaptersCount'] = 3;
      final series = await MangaK().fetchSeries('https://mangak.io/test-series', http);
      expect(series.chapters.map((c) => c.number), ['1', '2', 'Notice.']);
      expect(series.chapters.last.url, 'https://mangak.io/test-series/notice');

      for (final url in ['/other-series/chapter-3', '/test-series/notice/extra', '/test-seriesx/chapter-3']) {
        http.chapterItems.first['url'] = url;
        await expectLater(
          MangaK().fetchSeries('https://mangak.io/test-series', http),
          throwsA(isA<ProviderError>()),
          reason: url,
        );
      }
    });

    test('un elenco più corto di quanto dichiarato non passa', () async {
      final http = FakeMangaK();
      (http.series['stats'] as Map)['chaptersCount'] = 3;
      await expectLater(
        MangaK().fetchSeries('https://mangak.io/test-series', http),
        throwsA(isA<ProviderError>()),
      );
    });

    test('la ricerca è quella del sito, e tiene solo serie sue', () async {
      final http = SearchHttp(response: {
        'success': true,
        'data': {
          'items': [
            {
              'name': 'Solo Leveling', 'url': '/solo-leveling',
              'cover': 'https://rx.resmk.org/covers/c8ccb9d017d6.webp',
              'status': 'completed', 'stats': {'chapters_count': 201},
            },
            {'name': 'Capitolo', 'url': '/solo-leveling/chapter-1'},
            {'name': 'Altrove', 'url': '/altrove', 'cover': 'https://example.com/x.webp'},
          ],
          'pagination': {'total': 3},
        },
      });
      final results = await MangaK().search(' solo lev ', http);
      expect(Uri.parse(http.requests.single).queryParameters, {'q': 'solo lev', 'limit': '$searchLimit'});
      expect(results.map((r) => r.url), ['https://mangak.io/solo-leveling', 'https://mangak.io/altrove']);
      expect(results.first.title, 'Solo Leveling');
      expect(results.first.chapters, 201);
      expect(results.first.releaseStatus, 'completed');
      expect(results.first.coverUrl, 'https://rx.resmk.org/covers/c8ccb9d017d6.webp');
      expect(results.last.coverUrl, isNull);
      expect(results.last.releaseStatus, 'unknown');
    });
  });

  group('ManhwaRead', () {
    const url = 'https://manhwaread.com/manhwa/disfarming/';
    final provider = ManhwaRead();

    test('tutti i capitoli, la storia extra e i metadati', () async {
      for (final alternate in [false, true]) {
        final http = FakeManhwaRead(alternate: alternate);
        final series = await provider.fetchSeries(url, http);
        expect(series.title, 'Disfarming');
        expect(series.chapters.map((c) => c.id), ['chapter-01', 'chapter-02', 'side-story-1']);
        expect(series.chapters.map((c) => c.number), ['1', '2', 'Side Story 1']);
        expect(series.chapters[1].metadata['date'], 'Yesterday');
        expect(series.chapters[0].metadata['chapter_id'], '1');
        expect(series.chapters[0].metadata['manga_id'], '508');
        expect(series.metadata['description'], 'Story');
        expect(series.metadata['artists'], ['Illustrator']);
        expect(series.metadata['authors'], ['Writer']);
        expect(series.metadata['tags'], ['Action', 'Fantasy']);
        expect(series.metadata['genres'], ['Adventure']);
        final content = await provider.fetchPages(series.chapters.first, http);
        expect(content.metadata['description'], 'Chapter summary');
        expect(content.metadata['tags'], ['Action', 'Fantasy']);
        expect(content.pages.map((p) => p.url), FakeManhwaRead.media);
        expect(provider.accepts('${url}chapter-01/'), isFalse);
        expect(() => provider.validateUrl('https://evil.example/mr_001.jpg'),
            throwsA(isA<ProviderError>()));
      }
    });

    test('dati delle tavole rovinati', () async {
      final http = FakeManhwaRead(badPages: true);
      final series = await provider.fetchSeries(url, http);
      await expectLater(provider.fetchPages(series.chapters.first, http),
          throwsA(isA<ProviderError>()));
    });

    test('dietro Cloudflare le tavole si trovano sul CDN', () async {
      final http = FakeManhwaRead(challenge: true);
      final series = await provider.fetchSeries(url, http);
      final pages = await provider.fetchPages(series.chapters.first, http);
      expect(pages.pages.map((p) => p.url), [
        'https://manread.xyz/508/1/mr_001.jpg',
        'https://manread.xyz/508/1/mr_002.jpg',
      ]);
      expect(pages.metadata['imageSource'], 'cdn-probe');
    });

    test('la serie bloccata chiede la WebView, poi si legge dalla pagina', () async {
      final page = (await FakeManhwaRead().get(url)).body;
      await expectLater(provider.fetchSeries(url, ChallengedHttp()),
          throwsA(isA<CloudflareChallenge>()));
      await expectLater(provider.fetchSeries(url, ForbiddenHttp()),
          throwsA(isA<CloudflareChallenge>()));
      final series = await provider.fetchSeries(url, SnapshotHttp(ChallengedHttp(), url, page));
      expect((series.title, series.chapters.length), ('Disfarming', 3));
      final other = utf8.encode(utf8.decode(page).replaceFirst(
          '<html><head>', '<html><head><link rel="canonical" href="/manhwa/altro/">'));
      await expectLater(
        provider.fetchSeries(url, SnapshotHttp(ChallengedHttp(), url, Uint8List.fromList(other))),
        throwsA(isA<ProviderError>()),
      );
    });

    test('il prologo resta dove lo mette il sito', () async {
      final body = '''<body class="postid-508"><h1 class="clipboard-copy">Disfarming</h1>
            <div id="chaptersList">
              <a href="${url}prologue/" data-id="1"><span>Prologue</span></a>
              <a href="${url}chapter-01/" data-id="2"><span>Chapter 01</span></a>
              <a href="${url}chapter-02/" data-id="3"><span>Chapter 02</span></a>
            </div></body>''';
      final series = await provider.fetchSeries(url, PageHttp(body));
      expect(series.chapters.map((c) => c.title), ['Prologue', 'Chapter 01', 'Chapter 02']);
    });

    test('un elenco dal più recente si rovescia', () async {
      final body = '''<body><h1 class="text-primary">X</h1><div id="chaptersList">
              <a href="${url}chapter-2/"><span>Chapter 2</span></a>
              <a href="${url}chapter-1/"><span>Chapter 1</span></a></div></body>''';
      final series = await provider.fetchSeries(url, PageHttp(body));
      expect(series.chapters.map((c) => c.id), ['chapter-1', 'chapter-2']);
    });

    test('la ricerca legge le schede della pagina dei risultati', () async {
      final http = SearchHttp(page: '''<html><body>
        <form id="formQuickSearch"><input name="s" id="inputQuickSearch"></form>
        <div class="manga-grid grid mb-10">
          <div class="manga-item loop-item group/manga-item ">
            <div class="manga-item__img"><img alt="Disfarming" class="manga-item__img-inner"
                src="https://mancover.xyz/cover/2026/02/disfarming.webp"></div>
            <a href="https://manhwaread.com/manhwa/disfarming/" class="btn--solid"><span>Read</span></a>
            <h3><a href="https://manhwaread.com/manhwa/disfarming/" class="manga-item__link">Disfarming</a></h3>
            <span class="manga-status" data-status="completed"><span>Completed</span></span>
            <a href="https://manhwaread.com/manhwa/disfarming/chapter-12/" class="chapter-item">Chapter 12</a>
          </div>
          <div class="manga-item loop-item">
            <img alt="Other One" src="https://elsewhere.example/cover.jpg">
            <h3><a href="/manhwa/other-one" class="manga-item__link"> </a></h3>
          </div>
        </div></body></html>''');
      final results = await provider.search(' dis far ', http);
      expect(Uri.parse(http.requests.single).queryParameters, {'s': 'dis far'});
      expect(results.map((r) => r.url), [url, 'https://manhwaread.com/manhwa/other-one/']);
      expect(results.map((r) => r.title), ['Disfarming', 'Other One']);
      expect(results.first.coverUrl, 'https://mancover.xyz/cover/2026/02/disfarming.webp');
      expect(results.first.releaseStatus, 'completed');
      expect(results.last.coverUrl, isNull);
      expect(results.last.releaseStatus, 'unknown');
    });

    test('la ricerca senza risultati, e dietro Cloudflare', () async {
      expect(await provider.search('zzz', SearchHttp(page: '<p>Nothing found</p>')), isEmpty);
      expect(provider.search('zzz', SearchHttp(error: HttpStatusError(403))),
          throwsA(isA<CloudflareChallenge>()));
      expect(provider.search('zzz', ChallengedHttp()), throwsA(isA<CloudflareChallenge>()));
    });
  });

  group('metadati e nomi', () {
    test('stato canonico e forma fissa', () {
      expect(releaseStatus('Ongoing'), 'ongoing');
      expect(releaseStatus(['Completed']), 'completed');
      expect(releaseStatus({'name': 'On Hold'}), 'hiatus');
      expect(releaseStatus(null), 'unknown');
      final metadata = normalizeMetadata({
        'Summary': 'A story',
        'tags': [{'name': 'Adventure'}, {'name': 'adventure'}],
        'status': 'Ongoing',
        'authors': [{'name': 'Writer'}],
      });
      expect(metadata.keys, [...metadataFields, 'source']);
      expect(metadata['description'], 'A story');
      expect(metadata['tags'], ['Adventure']);
      expect(metadata['authors'], ['Writer']);
      expect(metadata['releaseStatus'], 'ongoing');
      expect(metadata['language'], isNull);
      expect(metadata['genres'], isEmpty);
    });

    test('nomi come quelli del server', () {
      expect(chapterPrefix('0.5'), '0000.5');
      expect(chapterPrefix('16'), '0016');
      expect(chapterPrefix(''), 'extra');
      expect(safeName('Test / Series'), 'Test Series');
      expect(safeName(' ..A: b.. '), 'A b');
      expect(safeName('ＡＢＣ'), 'ABC');
      expect(safeName('***'), 'Senza titolo');
      expect(safeName('abcdef', limit: 3), 'abc');
    });

    test('il capitolo di partenza per id, numero o valore', () {
      const chapters = [
        Chapter('a', 'Chapter 1', '1', 'u'),
        Chapter('b', 'Capitolo 16', 'Capitolo 16', 'u'),
        Chapter('c', 'Chapter 16.5', '16.5', 'u'),
      ];
      expect(startIndex(chapters, 'b'), 1);
      expect(startIndex(chapters, '16'), 1);
      expect(startIndex(chapters, '16.5'), 2);
      expect(() => startIndex(chapters, '99'), throwsA(isA<ProviderError>()));
    });

    test('formato e dimensioni dagli header', () {
      final image = webp(80, 120);
      expect(imageExtension(image), '.webp');
      expect(imageSize(image), (80, 120));
      expect(() => imageExtension(Uint8List.sublistView(image, 0, image.length - 1)),
          throwsA(isA<ProviderError>()));
      expect(imageSize(png(7, 9)), (7, 9));
      expect(imageExtension(png(7, 9)), '.png');
      expect(() => imageExtension(Uint8List.fromList(utf8.encode('<html>'))),
          throwsA(isA<ProviderError>()));
      expect(tileHeights(1536), isEmpty);
      expect(tileHeights(2049), [683, 683, 683]);
      expect(tileHeights(2048), [1024, 1024]);
      expect(tileHeights(3000), [1000, 1000, 1000]);
    });
  });
}
