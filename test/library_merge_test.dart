import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/cleanup.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/library_repository.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:path/path.dart' as p;

import 'malf_test.dart' show buildLibrary;

/// Una sorgente Drive senza rete: gli indici sono quelli che le si danno.
class FakeDrive implements LibraryShelf {
  FakeDrive({this.library = LibraryIndex.empty, this.series = const {}});

  final LibraryIndex library;
  final Map<String, SeriesIndex> series;

  @override
  LibraryOrigin get origin => LibraryOrigin.drive;

  @override
  Future<LibraryIndex> loadLibrary() async => library;

  @override
  Future<SeriesIndex?> loadSeries(SeriesEntry entry) async => series[entry.key];

  @override
  Future<PagesIndex?> loadPages(SeriesEntry entry) async => null;

  @override
  Future<Map<String, Object?>?> loadSeriesManifest(SeriesEntry entry) async =>
      null;

  @override
  String locate(SeriesEntry entry, String relative) =>
      '$remotePrefix${entry.path}/$relative';

  @override
  Future<Set<String>> withdrawnChapters(SeriesEntry entry) async => const {};
}

SeriesEntry entry(String key, {int archived = 1}) => SeriesEntry(
      key: key,
      path: 'Prova [mangak-S1]',
      title: key,
      provider: 'mangak',
      releaseStatus: ReleaseStatus.ongoing,
      chapterCount: 3,
      archivedChapterCount: archived,
      pageCount: 1,
      bytes: 1,
      signature: 's',
    );

LibraryIndex index(List<SeriesEntry> series) => LibraryIndex(
      generatedAt: null,
      series: series,
      chapterCount: 0,
      pageCount: 0,
      bytes: 0,
    );

ChapterEntry chapter(String id, int order, {bool readable = true}) =>
    ChapterEntry(
      id: id,
      order: order,
      archived: readable,
      complete: readable,
      pageCount: readable ? 1 : 0,
      bytes: 1,
      number: '${order + 1}',
      path: readable ? 'chapters/${order + 1} [$id]' : null,
    );

SeriesIndex chapters(List<ChapterEntry> rows) => SeriesIndex(
      key: 'mangak:S1',
      title: 'Prova',
      releaseStatus: ReleaseStatus.ongoing,
      signature: 's',
      chapters: rows,
    );

void main() {
  group('libreria unita', () {
    test('ogni serie sa dove sta, e la riga di Drive vince', () {
      final local = LibraryRepository('/nessuna');
      final drive = FakeDrive();
      final catalog = Library.merge({
        local: index([
          entry('solo:telefono'),
          entry('in:pari', archived: 3),
          entry('indietro', archived: 1),
        ]),
        drive: index([
          entry('solo:drive'),
          entry('in:pari', archived: 3),
          entry('indietro', archived: 3),
        ]),
      });
      expect(catalog.places, {
        'solo:telefono': SeriesPlace.local,
        'in:pari': SeriesPlace.local,
        'indietro': SeriesPlace.mixed,
        'solo:drive': SeriesPlace.drive,
      });
      expect(
        catalog.index.series
            .firstWhere((row) => row.key == 'indietro')
            .archivedChapterCount,
        3,
      );
      expect(catalog.holders['indietro'], [local, drive]);
    });

    test('i capitoli in più su Drive compaiono e si leggono da Drive', () {
      final local = LibraryRepository('/nessuna');
      final drive = FakeDrive();
      final merged = Library.mergeChapters(
        {
          local: chapters([chapter('C1', 0), chapter('C2', 1, readable: false)]),
          drive: chapters([chapter('C1', 0), chapter('C2', 1), chapter('C3', 2)]),
        },
        {
          local: {'chapters/1 [C1]'},
        },
      )!;
      expect(merged.index.chapters.map((c) => c.id), ['C1', 'C2', 'C3']);
      expect(merged.originOf('C1'), LibraryOrigin.local);
      expect(merged.originOf('C2'), LibraryOrigin.drive);
      expect(merged.originOf('C3'), LibraryOrigin.drive);
      expect(merged.index.readable, hasLength(3));
    });

    test('un capitolo annunciato in locale ma senza file si legge da Drive',
        () {
      final local = LibraryRepository('/nessuna');
      final merged = Library.mergeChapters(
        {
          local: chapters([chapter('C1', 0)]),
          FakeDrive(): chapters([chapter('C1', 0)]),
        },
        {local: const {}},
      )!;
      expect(merged.originOf('C1'), LibraryOrigin.drive);
    });

    test('senza nessuno che lo serva, un capitolo non è leggibile', () {
      final local = LibraryRepository('/nessuna');
      final merged = Library.mergeChapters(
        {local: chapters([chapter('C1', 0)])},
        {local: const {}},
      )!;
      expect(merged.originOf('C1'), isNull);
      expect(merged.index.readable, isEmpty);
    });

    test('un capitolo tolto da Drive non si legge più da lì', () {
      final local = LibraryRepository('/nessuna');
      final drive = FakeDrive();
      final merged = Library.mergeChapters(
        {
          local: chapters([chapter('C1', 0), chapter('C2', 1)]),
          drive: chapters([chapter('C1', 0), chapter('C2', 1)]),
        },
        {local: {'chapters/1 [C1]'}},
        {drive: {'chapters/1 [C1]', 'chapters/2 [C2]'}},
      )!;
      // Sul telefono c'è ancora: si legge da lì.
      expect(merged.originOf('C1'), LibraryOrigin.local);
      // Da nessuna parte: resta in elenco, come non scaricato.
      expect(merged.originOf('C2'), isNull);
      expect(merged.index.chapters.map((c) => c.id), ['C1', 'C2']);
    });

    test('le tavole di Drive diventano indirizzi remoti', () async {
      final drive = FakeDrive();
      final series = entry('mangak:S1');
      final merged = Library.mergeChapters({
        drive: chapters([chapter('C1', 0)]),
      })!;
      final pages = PagesIndex(key: 'k', signature: 's', pages: {
        'C1': const [PageEntry(file: '0001.webp')],
      });
      final paths = Library([drive])
          .pagePaths(series, merged.index.chapters.single, pages, merged);
      expect(paths.single, 'drive:Prova [mangak-S1]/chapters/1 [C1]/0001.webp');
      expect(isRemote(paths.single), isTrue);
    });
  });

  group('cartella locale', () {
    late Directory root;

    setUp(() async => root = await buildLibrary());
    tearDown(() async => root.delete(recursive: true));

    test('i capitoli presenti sono le cartelle, non i download a metà',
        () async {
      final repository = LibraryRepository(root.path);
      final series = (await repository.loadLibrary()).series.single;
      await Directory(
        p.join(root.path, series.path, 'chapters', '0002 - Secondo [C2].part'),
      ).create();
      expect(
        await repository.presentChapters(series),
        {'chapters/0001 - Primo [C1]'},
      );
    });

    test('le serie scaricate si aggiungono a library.json', () async {
      final downloaded = entry('scaricata:S2');
      final file = File(p.join(root.path, readingDirectory, downloadsFile));
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'series': [downloaded.toJson()],
      }));
      final library = await LibraryRepository(root.path).loadLibrary();
      expect(library.series.map((row) => row.key), ['mangak:S1', 'scaricata:S2']);
    });

    test('senza library.json, con Drive, la cartella non è un errore',
        () async {
      final empty = await Directory.systemTemp.createTemp('kagami-vuota');
      final library =
          await LibraryRepository(empty.path, requireIndex: false).loadLibrary();
      expect(library.series, isEmpty);
      await empty.delete(recursive: true);
    });

    test('un capitolo letto si toglie dal telefono e non resta leggibile',
        () async {
      final repository = LibraryRepository(root.path);
      final entry = (await repository.loadLibrary()).series.single;
      final library = Library([repository]);
      final chapters = (await library.loadSeries(entry, [repository]))!;
      expect(chapters.servedBy.keys, ['C1']);

      expect(
        (await findReadLeftovers(
          entry: entry,
          chapters: chapters,
          holders: [repository],
          read: const {},
        )).isEmpty,
        isTrue,
      );
      final leftovers = await findReadLeftovers(
        entry: entry,
        chapters: chapters,
        holders: [repository],
        read: const {'C1', 'C2'},
      );
      expect(leftovers.folders.keys, ['C1']);
      expect(leftovers.folderBytes, 1);
      expect(leftovers.synced, isTrue);
      expect(leftovers.onDrive, isFalse);

      await clearReadLeftovers(
        leftovers,
        series: entry.key,
        folders: true,
        cache: true,
      );
      expect(await repository.presentChapters(entry), isEmpty);
      // Anche senza Drive l'indice non si prende più in parola: il capitolo
      // cancellato è un capitolo non scaricato, non uno da aprire a vuoto.
      final after = (await library.loadSeries(entry, [repository]))!;
      expect(after.servedBy, isEmpty);
      expect(after.index.chapters.first.isReadable, isFalse);
    });

    test('una sorgente che non risponde non toglie le altre', () async {
      final catalog = await Library([
        LibraryRepository(root.path),
        _Broken(),
      ]).load();
      expect(catalog.index.series, hasLength(1));
      expect(catalog.notices.single, isA<DriveException>());
    });
  });

  group('cache delle tavole', () {
    late Directory directory;

    setUp(() async => directory = await Directory.systemTemp.createTemp('kagami-cache'));
    tearDown(() async => directory.delete(recursive: true));

    test('butta per prima la tavola usata meno di recente', () async {
      final cache = DriveFileCache(directory, limitBytes: 25);
      Future<String> put(String key) =>
          cache.store(key, (file) => file.writeAsBytes(List.filled(10, 0)));
      await put('a');
      await put('b');
      cache.peek('a');
      await put('c');
      expect(cache.peek('b'), isNull);
      expect(cache.peek('a'), isNotNull);
      expect(cache.peek('c'), isNotNull);
      expect(cache.bytes, 20);

      final reopened = DriveFileCache(directory, limitBytes: 25);
      await reopened.ready();
      expect(reopened.bytes, 20);
    });

    test('l\'impronta di un indirizzo è stabile e distingue', () {
      expect(addressKey('a/b.webp'), addressKey('a/b.webp'));
      expect(addressKey('a/b.webp'), isNot(addressKey('a/c.webp')));
      expect(addressKey('a/b.webp'), matches(RegExp(r'^a[0-9a-f]{16}$')));
    });
  });
}

class _Broken extends FakeDrive {
  @override
  Future<LibraryIndex> loadLibrary() async =>
      throw const DriveException('Nessuna connessione');
}
