import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/library_repository.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:path/path.dart' as p;

/// Libreria minima nello stesso formato scritto da MangaArchive.
Future<Directory> buildLibrary() async {
  final root = await Directory.systemTemp.createTemp('kagami-test');
  final seriesPath = 'Prova [mangak-S1]';
  final chapterPath = 'chapters/0001 - Primo [C1]';
  final folder = Directory(p.join(root.path, seriesPath, chapterPath));
  await folder.create(recursive: true);
  await File(p.join(folder.path, '0001.webp')).writeAsBytes([0]);

  Future<void> write(String path, Object data) =>
      File(p.join(root.path, path)).writeAsString(jsonEncode(data));

  await write(libraryIndexFile, {
    'format': 'malf',
    'formatVersion': 1,
    'generatedAt': '2026-09-18T10:00:00Z',
    'seriesCount': 1,
    'chapterCount': 1,
    'pageCount': 1,
    'bytes': 1,
    'series': [
      {
        'key': 'mangak:S1',
        'path': seriesPath,
        'title': 'Prova',
        'provider': 'mangak',
        'cover': 'cover.webp',
        'coverThumbnail': 'cover.thumb.webp',
        'releaseStatus': 'ongoing',
        'authors': ['Autore'],
        'chapterCount': 3,
        'archivedChapterCount': 1,
        'pageCount': 1,
        'bytes': 1,
        'latestChapterNumber': '1',
        'signature': 'abcd1234',
      },
    ],
  });
  await write(p.join(seriesPath, seriesIndexFile), {
    'format': 'malf',
    'formatVersion': 1,
    'key': 'mangak:S1',
    'title': 'Prova',
    'releaseStatus': 'ongoing',
    'signature': 'abcd1234',
    'chapters': [
      {
        'id': 'C1',
        'number': '1',
        'title': 'Primo',
        'order': 0,
        'sortKey': 1.0,
        'path': chapterPath,
        'archived': true,
        'complete': true,
        'pageCount': 1,
        'bytes': 1,
      },
      {
        'id': 'C2',
        'number': '2',
        'title': 'Annunciato',
        'order': 1,
        'sortKey': 2.0,
        'path': null,
        'archived': false,
        'complete': false,
        'pageCount': 0,
        'bytes': 0,
      },
    ],
  });
  await write(p.join(seriesPath, pagesIndexFile), {
    'format': 'malf',
    'formatVersion': 1,
    'key': 'mangak:S1',
    'signature': 'abcd1234',
    'pages': {
      'C1': [
        {'file': '0001.webp', 'width': 800, 'height': 1200, 'bytes': 1},
      ],
    },
  });
  return root;
}

void main() {
  late Directory root;

  setUp(() async => root = await buildLibrary());
  tearDown(() async => root.delete(recursive: true));

  test('legge la libreria e riconosce i capitoli mancanti', () async {
    final index = await LibraryRepository(root.path).loadLibrary();
    expect(index.series, hasLength(1));
    final entry = index.series.single;
    expect(entry.key, 'mangak:S1');
    expect(entry.isOngoing, isTrue);
    expect(entry.missingChapterCount, 2);
    expect(entry.authors, ['Autore']);
    expect(entry.gridImagePath(root.path), endsWith('cover.thumb.webp'));
  });

  test('un capitolo annunciato ma non scaricato non è leggibile', () async {
    final repository = LibraryRepository(root.path);
    final entry = (await repository.loadLibrary()).series.single;
    final series = await repository.loadSeries(entry);
    expect(series!.chapters, hasLength(2));
    expect(series.readable.map((chapter) => chapter.id), ['C1']);
    expect(series.chapters.first.label(), 'Capitolo 1 · Primo');
  });

  test('il numero ripetuto nel titolo non fa un secondo nome', () {
    ChapterEntry chapter(String number, String title) => ChapterEntry(
          id: 'x', order: 0, archived: true, complete: true, pageCount: 1,
          bytes: 1, number: number, title: title,
        );
    expect(chapter('70.5', 'Chapter 70.5').label(), 'Capitolo 70.5');
    expect(chapter('0', 'Chapter 0').label(), 'Capitolo 0');
    expect(chapter('12', 'Chapter 12: La torre').label(), 'Capitolo 12 · La torre');
    expect(chapter('12', '12').label(), 'Capitolo 12');
    // Un numero diverso nel titolo non si nasconde: è un'informazione.
    expect(chapter('73', 'Chapter 70.5').label(), 'Capitolo 73 · Chapter 70.5');
    expect(chapter('Side Story 1', 'Side Story 1').label(), 'Side Story 1');
  });

  test('le pagine hanno percorso e proporzioni', () async {
    final repository = LibraryRepository(root.path);
    final entry = (await repository.loadLibrary()).series.single;
    final series = await repository.loadSeries(entry);
    final pages = await repository.loadPages(entry);
    final paths = repository.pagePaths(entry, series!.readable.single, pages!);
    expect(paths, hasLength(1));
    expect(File(paths.single).existsSync(), isTrue);
    expect(pages.of('C1').single.aspectRatio, closeTo(0.666, 0.001));
  });

  test('una cartella senza indice si distingue da una illeggibile', () async {
    final empty = await Directory.systemTemp.createTemp('kagami-vuota');
    await expectLater(
      LibraryRepository(empty.path).loadLibrary(),
      throwsA(isA<LibraryException>()
          .having((e) => e.problem, 'problem', LibraryProblem.notIndexed)),
    );
    await expectLater(
      LibraryRepository(p.join(empty.path, 'assente')).loadLibrary(),
      throwsA(isA<LibraryException>()
          .having((e) => e.problem, 'problem', LibraryProblem.missing)),
    );
    await empty.delete(recursive: true);
  });

  test('il merge unisce i capitoli letti dei due dispositivi', () {
    final vecchio = DateTime.utc(2026, 1, 1);
    final nuovo = DateTime.utc(2026, 6, 1);
    final mio = SeriesState(
      status: ShelfStatus.reading,
      readChapters: const {'C1'},
      updatedAt: vecchio,
    );
    final altro = SeriesState(
      status: ShelfStatus.paused,
      rating: 7,
      readChapters: const {'C2'},
      updatedAt: nuovo,
    );
    final merged = mio.mergeWith(altro);
    expect(merged.readChapters, {'C1', 'C2'});
    expect(merged.status, ShelfStatus.paused);
    expect(merged.rating, 7);
    expect(merged.updatedAt, nuovo);
  });

  test('il merge tiene per ogni capitolo la posizione più recente', () {
    ReadingProgress at(String chapter, int page, int day) => ReadingProgress(
          chapterId: chapter,
          page: page,
          pageCount: 20,
          updatedAt: DateTime.utc(2026, 6, day),
        );
    final mio = SeriesState(
      positions: {'C1': at('C1', 5, 3), 'C2': at('C2', 1, 1)},
    );
    final altro = SeriesState(
      positions: {'C2': at('C2', 9, 2), 'C3': at('C3', 4, 4)},
    );
    final merged = mio.mergeWith(altro);
    expect(merged.positions.keys, unorderedEquals(['C1', 'C2', 'C3']));
    expect(merged.positions['C1']!.page, 5);
    expect(merged.positions['C2']!.page, 9);
    expect(merged.progress!.chapterId, 'C3');
  });

  test('le tessere valgono solo se ricompongono la tavola', () {
    final good = PageEntry.fromJson({
      'file': '0001.webp',
      'width': 720,
      'height': 3000,
      'tiles': [
        {'file': '0001-01.webp', 'height': 1500, 'bytes': 10},
        {'file': '0001-02.webp', 'height': 1500},
      ],
    });
    expect([for (final tile in good.tiles) tile.file], ['0001-01.webp', '0001-02.webp']);

    final short = PageEntry.fromJson({
      'file': '0001.webp',
      'width': 720,
      'height': 3000,
      'tiles': [
        {'file': '0001-01.webp', 'height': 1500},
      ],
    });
    expect(short.tiles, isEmpty);
    expect(PageEntry.fromJson({'file': '0002.webp'}).tiles, isEmpty);
  });
}
