/// Il database dei dati personali, su un'istanza in memoria: nessun file,
/// nessun isolate, così le regole si provano senza una libreria vera.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';
import 'package:path/path.dart' as p;

void main() {
  late KagamiDatabase db;
  late UserRepository repository;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    repository = UserRepository(db);
  });

  tearDown(() => db.close());

  test('stato, capitoli letti e posizione tornano indietro interi', () async {
    const key = 'mangak:S1';
    await repository.saveSeriesState(
      key,
      SeriesState(
        status: ShelfStatus.reading,
        rating: 9,
        favorite: true,
        notes: 'bello',
        updatedAt: DateTime.utc(2026, 6, 1),
      ),
    );
    await repository.markChapters(key, ['C1', 'C2'], true);
    await repository.saveProgress(
      key,
      ReadingProgress(
        chapterId: 'C2',
        page: 4,
        pageCount: 20,
        offset: 0.5,
        updatedAt: DateTime.utc(2026, 6, 2),
      ),
    );

    final state = (await repository.loadStates())[key]!;
    expect(state.status, ShelfStatus.reading);
    expect(state.rating, 9);
    expect(state.favorite, isTrue);
    expect(state.notes, 'bello');
    expect(state.readChapters, {'C1', 'C2'});
    // La posizione dentro la tavola torna indietro com'era: su un webtoon è
    // la differenza fra riprendere dov'eri e riprendere dieci schermate
    // prima.
    expect(state.progress!.offset, closeTo(0.5, 0.001));
    expect(state.progress!.fraction, closeTo(0.225, 0.001));
  });

  test('ogni capitolo lasciato a metà ricorda il suo punto', () async {
    const key = 'mangak:S1';
    ReadingProgress at(String chapter, int page, int day) => ReadingProgress(
          chapterId: chapter,
          page: page,
          pageCount: 20,
          updatedAt: DateTime.utc(2026, 6, day),
        );
    await repository.saveProgress(key, at('C1', 7, 2));
    await repository.saveProgress(key, at('C2', 3, 3));
    // Una posizione più vecchia per lo stesso capitolo non vince.
    await repository.saveProgress(key, at('C1', 2, 1));

    final state = (await repository.loadStates())[key]!;
    expect(state.positions['C1']!.page, 7);
    expect(state.positions['C2']!.page, 3);
    expect(state.progress!.chapterId, 'C2');
  });

  test('togliere un capitolo letto non tocca gli altri', () async {
    const key = 'mangak:S1';
    await repository.markChapters(key, ['C1', 'C2', 'C3'], true);
    await repository.markChapters(key, ['C2'], false);
    expect((await repository.loadStates())[key]!.readChapters, {'C1', 'C3'});
  });

  test('la prima lettura fissa la data di inizio e non la sposta più', () async {
    const key = 'mangak:S1';
    final prima = DateTime.utc(2026, 1, 1);
    await repository.markChapters(key, ['C1'], true, at: prima);
    await repository.markChapters(key, ['C2'], true, at: DateTime.utc(2026, 5, 1));
    final row = await (db.select(db.seriesStates)
          ..where((row) => row.seriesKey.equals(key)))
        .getSingle();
    expect(row.startedAt, prima);
  });

  test('le raccolte conservano il loro ordine e quello delle serie', () async {
    await repository.replaceCollections([
      Collection(id: 'b', name: 'Seconda', seriesKeys: const ['s2', 's1']),
      Collection(id: 'a', name: 'Prima', seriesKeys: const ['s3']),
    ]);
    final collections = await repository.loadCollections();
    expect(collections.map((c) => c.name), ['Seconda', 'Prima']);
    expect(collections.first.seriesKeys, ['s2', 's1']);
  });

  test('la cronologia esclude le date dedotte e parte dalla più recente',
      () async {
    await repository.markChapters('s1', ['C1'], true, at: DateTime.utc(2026, 1, 1));
    await repository.markChapters('s1', ['C2'], true, at: DateTime.utc(2026, 2, 1));
    await repository.markChapters(
      's2',
      ['C9'],
      true,
      at: DateTime.utc(2026, 3, 1),
      estimated: true,
    );
    final history = await repository.history();
    expect(history.map((row) => row.chapterId), ['C2', 'C1']);
  });

  test('letture ravvicinate restano una sessione sola', () async {
    final start = DateTime.utc(2026, 4, 1, 20);
    await repository.logSession(
      seriesKey: 's1',
      chapterId: 'C1',
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 10)),
      pagesRead: 20,
    );
    await repository.logSession(
      seriesKey: 's1',
      chapterId: 'C2',
      startedAt: start.add(const Duration(minutes: 12)),
      endedAt: start.add(const Duration(minutes: 25)),
      pagesRead: 18,
    );
    final sessions = await db.select(db.readingSessions).get();
    expect(sessions, hasLength(1));
    expect(sessions.single.pagesRead, 38);
    expect(sessions.single.chapterId, 'C2');

    // Oltre il limite di inattività è un'altra lettura, non la stessa.
    await repository.logSession(
      seriesKey: 's1',
      chapterId: 'C3',
      startedAt: start.add(const Duration(hours: 3)),
      endedAt: start.add(const Duration(hours: 3, minutes: 5)),
      pagesRead: 9,
    );
    expect(await db.select(db.readingSessions).get(), hasLength(2));
  });

  test("l'importazione da reading/ avviene una volta sola", () async {
    final root = await Directory.systemTemp.createTemp('kagami-legacy');
    final reading = Directory(p.join(root.path, 'reading'));
    await reading.create(recursive: true);
    await File(p.join(reading.path, 'state.json')).writeAsString(jsonEncode({
      'series': {
        'mangak:S1': {
          'status': 'reading',
          'rating': 8,
          'readChapters': ['C1'],
          'updatedAt': '2026-03-01T00:00:00.000Z',
        },
      },
    }));
    await File(p.join(reading.path, 'collections.json')).writeAsString(
      jsonEncode({
        'collections': [
          {'id': 'c1', 'name': 'Preferiti', 'series': ['mangak:S1']},
        ],
      }),
    );

    expect(await repository.importLegacyReading(root.path), isTrue);
    final state = (await repository.loadStates())['mangak:S1']!;
    expect(state.status, ShelfStatus.reading);
    expect(state.rating, 8);
    expect(state.readChapters, {'C1'});
    expect((await repository.loadCollections()).single.name, 'Preferiti');

    // I capitoli importati non hanno una data vera: restano marcati, perché le
    // statistiche per giorno non li devono contare come letture di quel momento.
    final read = await db.select(db.chapterReads).getSingle();
    expect(read.estimated, isTrue);
    expect(read.readAt, DateTime.utc(2026, 3, 1));

    expect(await repository.importLegacyReading(root.path), isFalse);
    expect(await repository.loadCollections(), hasLength(1));
    await root.delete(recursive: true);
  });

  test('posizione e capitolo finito insieme non si respingono', () async {
    const key = 'mangak:S9';
    final when = DateTime.utc(2026, 9, 24);
    await Future.wait([
      repository.saveProgress(
        key,
        ReadingProgress(
          chapterId: 'C1',
          page: 18,
          pageCount: 20,
          offset: 0.2,
          updatedAt: when,
        ),
      ),
      repository.saveProgress(
        key,
        ReadingProgress(
          chapterId: 'C1',
          page: 19,
          pageCount: 20,
          offset: 0,
          updatedAt: when,
        ),
      ),
      repository.markChapters(key, ['C1'], true, at: when),
      repository.saveSeriesState(key, const SeriesState()),
    ]);

    final row = await (db.select(db.seriesStates)
          ..where((row) => row.seriesKey.equals(key)))
        .getSingle();
    expect(row.startedAt, isNotNull);
  });

  group('«arrivato a»', () {
    const key = 'mangak:S1';
    final chapters = [
      for (var i = 0; i < 5; i++)
        ChapterEntry(
          id: 'C$i',
          order: i,
          archived: false,
          complete: false,
          pageCount: 0,
          bytes: 0,
          number: '${i + 1}',
        ),
    ];
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      await container.read(readingProvider.future);
    });

    tearDown(() => container.dispose());

    Reading notifier() => container.read(readingProvider.notifier);

    test('segna letti stimati i capitoli fino a quello e porta a in lettura',
        () async {
      await notifier().setChapterRead(key, 'C0', true);
      await notifier().setReachedThrough(key, chapters, 'C2');

      final state = (await repository.loadStates())[key]!;
      expect(state.readChapters, {'C0', 'C1', 'C2'});
      expect(state.reachedChapter, '3');
      expect(state.status, ShelfStatus.reading);
      expect(container.read(readingProvider).value!.of(key).reachedChapter, '3');

      final reads = await db.select(db.chapterReads).get();
      expect(reads.firstWhere((r) => r.chapterId == 'C0').estimated, isFalse);
      expect(reads.firstWhere((r) => r.chapterId == 'C2').estimated, isTrue);
    });

    test('non iniziato azzera il numero e non toglie i letti', () async {
      await notifier().setReachedThrough(key, chapters, 'C1');
      await notifier().setReachedThrough(key, chapters, null);

      final state = (await repository.loadStates())[key]!;
      expect(state.reachedChapter, isNull);
      expect(state.readChapters, {'C0', 'C1'});
    });

    test('uno stato già deciso non viene toccato', () async {
      await notifier().setStatus(key, ShelfStatus.paused);
      await notifier().setReachedThrough(key, chapters, 'C0');
      expect((await repository.loadStates())[key]!.status, ShelfStatus.paused);
    });

    test('senza elenco di capitoli resta solo il numero', () async {
      await notifier().setReachedChapter('manual:x', ' 52 ');
      var state = (await repository.loadStates())['manual:x']!;
      expect(state.reachedChapter, '52');
      expect(state.readChapters, isEmpty);

      await notifier().setReachedChapter('manual:x', '');
      state = (await repository.loadStates())['manual:x']!;
      expect(state.reachedChapter, isNull);
    });

    test('la scheda di una serie non ancora in libreria si scrive in un colpo',
        () async {
      await notifier().saveCard(
        'manual:y',
        status: ShelfStatus.reading,
        rating: 7,
        notes: 'nota',
        favorite: true,
        reachedChapter: '12',
      );
      final state = (await repository.loadStates())['manual:y']!;
      expect(state.status, ShelfStatus.reading);
      expect(state.rating, 7);
      expect(state.notes, 'nota');
      expect(state.favorite, isTrue);
      expect(state.reachedChapter, '12');
    });
  });

  group('moveSeries', () {
    const from = 'manual:abc';
    const to = 'mangak:S1';

    test('porta stato, date, raccolte e impostazioni sulla chiave vera', () async {
      await repository.saveSeriesState(
        from,
        SeriesState(
          status: ShelfStatus.reading,
          rating: 8,
          favorite: true,
          notes: 'nota',
          muted: true,
          reachedChapter: '52',
          updatedAt: DateTime.utc(2026, 6, 1),
        ),
      );
      await repository.markChapters(from, ['C1'], true, estimated: true);
      await repository.touchSeries(from);
      await repository.replaceCollections([
        Collection(id: 'a', name: 'A', seriesKeys: const ['x', from, 'y']),
      ]);

      await repository.moveSeries(from, to);

      final states = await repository.loadStates();
      expect(states.containsKey(from), isFalse);
      final state = states[to]!;
      expect(state.status, ShelfStatus.reading);
      expect(state.rating, 8);
      expect(state.favorite, isTrue);
      expect(state.notes, 'nota');
      expect(state.muted, isTrue);
      expect(state.reachedChapter, '52');
      expect(state.readChapters, {'C1'});
      expect(state.lastOpenedAt, isNotNull);
      final collections = await repository.loadCollections();
      expect(collections.single.seriesKeys, ['x', to, 'y']);
    });

    test('fonde con ciò che la serie vera ha già: il più recente vince, i letti si uniscono',
        () async {
      await repository.saveSeriesState(
        to,
        SeriesState(status: ShelfStatus.paused, rating: 5, updatedAt: DateTime.utc(2026, 7, 1)),
      );
      await repository.markChapters(to, ['C0'], true);
      await repository.saveSeriesState(
        from,
        SeriesState(status: ShelfStatus.reading, rating: 9, updatedAt: DateTime.utc(2026, 6, 1)),
      );
      await repository.markChapters(from, ['C1'], true, estimated: true);
      await repository.replaceCollections([
        Collection(id: 'a', name: 'A', seriesKeys: const [from, to]),
      ]);

      await repository.moveSeries(from, to);

      final states = await repository.loadStates();
      expect(states.containsKey(from), isFalse);
      expect(states[to]!.status, ShelfStatus.paused);
      expect(states[to]!.rating, 5);
      expect(states[to]!.readChapters, {'C0', 'C1'});
      expect((await repository.loadCollections()).single.seriesKeys, [to]);
    });

    test('una serie senza dati non lascia niente né crea righe', () async {
      await repository.moveSeries(from, to);
      expect(await repository.loadStates(), isEmpty);
    });
  });
}
