import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/archive/bulk_import.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami_archive/manual.dart';

SeriesEntry _entry(String key, {String? source}) => SeriesEntry(
      key: key,
      path: key,
      title: 'Serie $key',
      provider: key.split(':').first,
      releaseStatus: ReleaseStatus.ongoing,
      chapterCount: 0,
      archivedChapterCount: 0,
      pageCount: 0,
      bytes: 0,
      signature: 's',
      source: source,
    );

LibraryIndex _index(List<SeriesEntry> series) =>
    LibraryIndex(generatedAt: null, series: series, chapterCount: 0, pageCount: 0, bytes: 0);

void main() {
  group('parseImportText', () {
    test('prende i link dal testo libero, senza doppioni né punteggiatura', () {
      final items = parseImportText('''
Solo Leveling – https://mangak.io/solo-leveling/chapter-52
(vedi https://example.org/serie/a/), poi https://EXAMPLE.org/serie/a#top.
<https://example.org/b> e ftp://example.org/no
https://mangak.io/solo-leveling/chapter-52/
''');
      expect(items.map((item) => item.url), [
        'https://mangak.io/solo-leveling/chapter-52',
        'https://example.org/serie/a/',
        'https://example.org/b',
      ]);
      expect(items.first.chapter, isNull);
    });

    test('legge il JSON e ne porta i campi per riga', () {
      final items = parseImportText('''
[
  {"url": "https://mangak.io/x", "chapter": 52, "status": "paused", "rating": 8, "notes": " bello "},
  {"url": "https://example.org/y", "title": "Y", "status": "boh", "rating": 11},
  {"title": "senza link"},
  "https://example.org/z",
  {"url": "https://mangak.io/x/"}
]''');
      expect(items.map((item) => item.url), ['https://mangak.io/x', 'https://example.org/y', 'https://example.org/z']);
      final first = items.first;
      expect(first.chapter, '52');
      expect(first.status, ShelfStatus.paused);
      expect(first.rating, 8);
      expect(first.notes, 'bello');
      expect(items[1].title, 'Y');
      expect(items[1].status, isNull);
      expect(items[1].rating, isNull);
    });

    test('un JSON rotto è testo come un altro', () {
      final items = parseImportText('[ "https://example.org/a", ');
      expect(items.single.url, 'https://example.org/a');
    });
  });

  test('lo stato di una scheda manuale segue il capitolo raggiunto', () {
    expect(const ImportItem('https://a.org').manualStatus, ShelfStatus.none);
    expect(const ImportItem('https://a.org', chapter: '3').manualStatus, ShelfStatus.reading);
    expect(
      const ImportItem('https://a.org', chapter: '3', status: ShelfStatus.dropped).manualStatus,
      ShelfStatus.dropped,
    );
  });

  group('routeImport', () {
    final manual = 'https://example.org/serie/m';
    final index = _index([
      _entry('mangak:S1', source: 'https://mangak.io/gia-qui'),
      _entry(manualSeriesKey(manual), source: manual),
    ]);

    test('un sito supportato si legge, anche dal link di un capitolo', () {
      final route = routeImport(const ImportItem('https://mangak.io/nuova/chapter-3'), index);
      expect(route, isA<ImportSite>());
      expect((route as ImportSite).link.seriesUrl, 'https://mangak.io/nuova');
      expect(route.link.chapterUrl, 'https://mangak.io/nuova/chapter-3');
    });

    test('la serie del capitolo già in libreria è già presente', () {
      final route = routeImport(const ImportItem('https://mangak.io/gia-qui/chapter-9'), index);
      expect((route as ImportKnown).title, 'Serie mangak:S1');
    });

    test('una scheda manuale con lo stesso link è già presente', () {
      expect(routeImport(const ImportItem('https://EXAMPLE.org/serie/m/'), index), isA<ImportKnown>());
      expect(routeImport(const ImportItem('https://example.org/serie/n'), index), isA<ImportManual>());
    });

    test('un lavoro già in coda conta come presente', () {
      final route = routeImport(
        const ImportItem('https://mangak.io/in-coda/chapter-1'),
        index,
        queued: {normalizeLink('https://mangak.io/in-coda')},
      );
      expect((route as ImportKnown).title, isNull);
    });
  });

  test('entryForKey trova la serie per chiave', () {
    final index = _index([_entry('mangak:S1')]);
    expect(entryForKey(index, 'mangak:S1')?.title, 'Serie mangak:S1');
    expect(entryForKey(index, 'mangak:S2'), isNull);
  });

  test('il titolo di ripiego è host e percorso', () {
    expect(fallbackTitle('https://www.example.org/manga/Il%20titolo/'), 'example.org/manga/Il titolo');
    expect(fallbackTitle('https://example.org/'), 'example.org');
  });
}
