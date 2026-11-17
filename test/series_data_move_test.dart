/// «Porta qui i miei dati» fra due serie in libreria (FASE-5b §3, F5.16):
/// capitoli abbinati per numero, fusione come nel backup, niente senza sì.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/series_data_move.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';

ChapterEntry _chapter(String id, int order, String? number) => ChapterEntry.fromJson({
      'id': id,
      'order': order,
      'archived': true,
      'complete': true,
      'pageCount': 10,
      'bytes': 1,
      'number': number,
    });

const _from = 'mangak:S1';
const _to = 'coffeemanga:7743';

void main() {
  late KagamiDatabase db;
  late UserRepository repository;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    repository = UserRepository(db);
  });
  tearDown(() => db.close());

  final fromChapters = [_chapter('a1', 0, '1'), _chapter('a2', 1, '2.0'), _chapter('a3', 2, '3'), _chapter('x', 3, null)];
  final toChapters = [_chapter('b2', 1, '2'), _chapter('b1', 0, '1'), _chapter('b4', 3, '4'), _chapter('b2bis', 4, '2')];

  SeriesDataMove plan(Set<String> read) => planSeriesDataMove(
        from: _from,
        to: _to,
        fromChapters: fromChapters,
        toChapters: toChapters,
        readInFrom: read,
      );

  test('abbina per numero, anche «2.0» con «2»; il primo in ordine vince; senza numero o senza pari no', () {
    final result = plan({'a1', 'a3', 'x'});
    expect(result.chapters, {'a1': 'b1', 'a2': 'b2'});
    expect(result.matchedReads, 1);
    expect(result.lostReads, 2);
  });

  test('senza conferma non si muove niente', () async {
    await repository.markChapters(_from, ['a1'], true);
    var moved = false;
    final done = await runSeriesDataMove(
      plan({'a1'}),
      confirm: (_) async => false,
      move: (_) async => moved = true,
    );
    expect(done, isFalse);
    expect(moved, isFalse);
    expect((await repository.loadStates())[_from]!.readChapters, {'a1'});
  });

  test('con la conferma: i letti si uniscono, sul resto vince il più recente, i senza pari cadono', () async {
    await repository.saveSeriesState(
      _to,
      SeriesState(status: ShelfStatus.paused, rating: 5, updatedAt: DateTime.utc(2026, 7, 1)),
    );
    await repository.markChapters(_to, ['b4'], true);
    await repository.saveSeriesState(
      _from,
      SeriesState(status: ShelfStatus.reading, rating: 9, updatedAt: DateTime.utc(2026, 8, 1)),
    );
    await repository.markChapters(_from, ['a1', 'a2', 'a3'], true);
    await repository.saveProgress(
      _from,
      ReadingProgress(chapterId: 'a3', page: 4, pageCount: 20, updatedAt: DateTime.utc(2026, 6, 1)),
    );
    await repository.addBookmark(seriesKey: _from, chapterId: 'a3', page: 2);
    await repository.addBookmark(seriesKey: _from, chapterId: 'a2', page: 5);

    final done = await runSeriesDataMove(
      plan({'a1', 'a2', 'a3'}),
      confirm: (plan) async => plan.lostReads == 1,
      move: (plan) async {
        await repository.dropChaptersExcept(plan.from, plan.chapters.keys.toSet());
        await repository.moveSeries(plan.from, plan.to, chapters: plan.chapters);
      },
    );

    expect(done, isTrue);
    final states = await repository.loadStates();
    expect(states.containsKey(_from), isFalse);
    expect(states[_to]!.readChapters, {'b1', 'b2', 'b4'});
    expect(states[_to]!.rating, 9);
    expect(states[_to]!.status, ShelfStatus.reading);
    expect(states[_to]!.progress, isNull);
    expect((await repository.bookmarks(_to)).single.chapterId, 'b2');
  });

  test('vince il più recente anche quando è quello di arrivo', () async {
    await repository.saveSeriesState(
      _to,
      SeriesState(status: ShelfStatus.paused, rating: 5, updatedAt: DateTime.utc(2026, 9, 1)),
    );
    await repository.saveSeriesState(
      _from,
      SeriesState(status: ShelfStatus.reading, rating: 9, updatedAt: DateTime.utc(2026, 8, 1)),
    );
    await repository.moveSeries(_from, _to);
    expect((await repository.loadStates())[_to]!.rating, 5);
  });
}
