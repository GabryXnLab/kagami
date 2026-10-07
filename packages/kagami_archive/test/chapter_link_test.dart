// Il link di una pagina di capitolo, incollato al posto di quello della serie:
// ogni sito ne ricava la serie e il capitolo, con le fixture di sempre.
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:test/test.dart';

import 'archive_fakes.dart';

void main() {
  Future<void> check({
    required String seriesUrl,
    required String chapterUrl,
    required String expectedSeries,
    required String providerId,
    required Future<Series> Function(Provider) load,
    required String number,
    required List<String> sameChapter,
  }) async {
    final series = resolveLink(seriesUrl);
    expect(series.provider.id, providerId);
    expect(series.seriesUrl, seriesUrl);
    expect(series.chapterUrl, isNull);

    final chapter = resolveLink(chapterUrl);
    expect(chapter.provider.id, providerId);
    expect(chapter.seriesUrl, expectedSeries);
    expect(chapter.chapterUrl, chapterUrl);
    expect(chapter.provider.accepts(chapter.seriesUrl), isTrue);

    final loaded = await load(chapter.provider);
    for (final link in [chapterUrl, ...sameChapter]) {
      expect(chapterOfLink(loaded, link)?.number, number, reason: link);
    }
    expect(chapterOfLink(loaded, '${chapterUrl}99'), isNull);
    // Le serie e i link di un altro sito non sono capitoli di questa.
    expect(chapterOfLink(loaded, 'https://example.com/x/chapter-1'), isNull);
  }

  test('MangaK', () async {
    await check(
      seriesUrl: 'https://mangak.io/test-series',
      chapterUrl: 'https://mangak.io/test-series/chapter-2',
      expectedSeries: 'https://mangak.io/test-series',
      providerId: 'mangak',
      load: (p) => p.fetchSeries('https://mangak.io/test-series', FakeMangaK()),
      number: '2',
      sameChapter: ['https://mangak.io/test-series/chapter-2/', 'https://mangak.io/test-series/chapter-2?utm=1'],
    );
  });

  test('ManhwaRead', () async {
    await check(
      seriesUrl: FakeManhwaRead.url,
      chapterUrl: '${FakeManhwaRead.url}chapter-02/',
      expectedSeries: FakeManhwaRead.url,
      providerId: 'manhwaread',
      load: (p) => p.fetchSeries(FakeManhwaRead.url, FakeManhwaRead()),
      number: '2',
      sameChapter: [
        '${FakeManhwaRead.url}chapter-02',
        'https://www.manhwaread.com/manhwa/disfarming/chapter-02/?x=1',
      ],
    );
  });

  test('Asura Scans', () async {
    const series = 'https://asurascans.com/comics/war-of-extinction-bd5bdaf8';
    await check(
      seriesUrl: series,
      chapterUrl: '$series/chapter/2',
      expectedSeries: 'https://asurascans.com/comics/war-of-extinction',
      providerId: 'asurascans',
      load: (p) => p.fetchSeries(series, FakeAsuraScans()),
      number: '2',
      sameChapter: [
        'https://asurascans.com/comics/war-of-extinction/chapter/2/',
        'https://www.asurascans.com/comics/war-of-extinction-12345678/chapter/2',
      ],
    );
  });

  test('un link di nessun sito è UnsupportedLink, e resta un ProviderError', () {
    for (final url in [
      'https://example.com/manhwa/x/chapter-1/',
      'http://mangak.io/test-series/chapter-1',
      'https://mangak.io/',
      'non è un link',
    ]) {
      expect(() => resolveLink(url), throwsA(isA<UnsupportedLink>()), reason: url);
    }
    expect(() => selectProvider('https://example.com/a'), throwsA(isA<UnsupportedLink>()));
    expect(() => resolveLink('https://example.com/a'), throwsA(isA<ProviderError>()));
  });
}
