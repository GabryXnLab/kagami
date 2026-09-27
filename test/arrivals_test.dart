/// Capitoli nuovi: il numero sul pallino e di quali arrivi dare notizia.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/arrivals.dart';
import 'package:kagami/src/data/backup.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/reading.dart';

import 'library_view_test.dart' show entry;

void main() {
  final gennaio = DateTime.utc(2026, 1, 1);
  final giugno = DateTime.utc(2026, 6, 1);
  final luglio = DateTime.utc(2026, 7, 1);

  SeriesState following({
    Set<String> read = const {'1'},
    ShelfStatus status = ShelfStatus.reading,
    DateTime? opened,
    bool muted = false,
  }) =>
      SeriesState(
        status: status,
        readChapters: read,
        updatedAt: gennaio,
        lastOpenedAt: opened ?? gennaio,
        muted: muted,
      );

  group('il pallino', () {
    test('conta gli arrivi dopo l\'ultima apertura, non l\'arretrato', () {
      final signals = SeriesSignals.of(
        entry(key: 'a', archived: 12, latest: giugno),
        following(),
        seenChapters: 10,
      );
      expect(signals.unreadCount, 11);
      expect(signals.newChapters, 2);
    });

    test('scende leggendo i capitoli nuovi', () {
      final signals = SeriesSignals.of(
        entry(key: 'a', archived: 3, latest: giugno),
        following(read: const {'1', '2'}),
        seenChapters: 1,
      );
      expect(signals.newChapters, 1);
    });

    test('non c\'è su una serie non seguita o abbandonata', () {
      final never = SeriesSignals.of(
        entry(key: 'a', archived: 5, latest: giugno),
        const SeriesState(),
        seenChapters: 2,
      );
      final dropped = SeriesSignals.of(
        entry(key: 'a', archived: 5, latest: giugno),
        following(status: ShelfStatus.dropped),
        seenChapters: 2,
      );
      expect(never.newChapters, 0);
      expect(dropped.newChapters, 0);
    });

    test('senza riferimento non c\'è niente di nuovo', () {
      final signals = SeriesSignals.of(
        entry(key: 'a', archived: 5, latest: giugno),
        following(),
      );
      expect(signals.newChapters, 0);
    });

    test('una scheda aperta altrove dopo l\'arrivo li ha già visti', () {
      final signals = SeriesSignals.of(
        entry(key: 'a', archived: 5, latest: giugno),
        following(opened: luglio),
        seenChapters: 2,
      );
      expect(signals.newChapters, 0);
    });

    test('il filtro lascia solo le serie con capitoli nuovi', () {
      final all = [
        SeriesSignals.of(
          entry(key: 'a', archived: 5, latest: giugno),
          following(),
          seenChapters: 4,
        ),
        SeriesSignals.of(
          entry(key: 'b', archived: 5, latest: giugno),
          following(),
          seenChapters: 5,
        ),
      ];
      const filter = LibraryFilter(onlyNew: true);
      expect(filter.activeCount, 1);
      expect(applyFilter(all, filter).map((s) => s.entry.key), ['a']);
    });
  });

  group('le notifiche', () {
    test('una serie vista la prima volta non si annuncia', () {
      final plan = planArrivals(
        [entry(key: 'a', archived: 7, latest: giugno)],
        {'a': following()},
        const {},
      );
      expect(plan.alerts, isEmpty);
      expect(plan.marks['a'], const ArrivalMark(seen: 7, notified: 7));
    });

    test('un arrivo si annuncia una volta sola', () {
      final series = [entry(key: 'a', archived: 9, latest: giugno)];
      final states = {'a': following()};
      final first = planArrivals(
        series,
        states,
        {'a': const ArrivalMark(seen: 7, notified: 7)},
      );
      expect(first.alerts.single.count, 2);
      expect(first.marks['a'], const ArrivalMark(seen: 7, notified: 9));

      final again = planArrivals(series, states, first.marks);
      expect(again.alerts, isEmpty);
      expect(again.marks, isEmpty);
    });

    test('silenziata o non seguita tace, ma il riferimento avanza', () {
      final marks = {
        'a': const ArrivalMark(seen: 1, notified: 1),
        'b': const ArrivalMark(seen: 1, notified: 1),
      };
      final plan = planArrivals(
        [
          entry(key: 'a', archived: 3, latest: giugno),
          entry(key: 'b', archived: 3, latest: giugno),
        ],
        {'a': following(muted: true)},
        marks,
      );
      expect(plan.alerts, isEmpty);
      expect(plan.marks['a']!.notified, 3);
      expect(plan.marks['b']!.notified, 3);
    });

    test('capitoli che tornano dopo una lettura parziale non sono arrivi', () {
      final marks = {'a': const ArrivalMark(seen: 9, notified: 9)};
      final partial = planArrivals(
        [entry(key: 'a', archived: 4, latest: giugno)],
        {'a': following()},
        marks,
      );
      expect(partial.marks, isEmpty);
      final whole = planArrivals(
        [entry(key: 'a', archived: 9, latest: giugno)],
        {'a': following()},
        marks,
      );
      expect(whole.alerts, isEmpty);
      expect(
        const ArrivalMark(seen: 9, notified: 9).acknowledged(4),
        const ArrivalMark(seen: 9, notified: 9),
      );
    });

    test('aprire la scheda azzera i nuovi', () {
      expect(
        const ArrivalMark(seen: 3, notified: 5).acknowledged(6),
        const ArrivalMark(seen: 6, notified: 6),
      );
    });
  });

  group('ad app chiusa', () {
    test('un arrivo annunciato dal telefono non suona di nuovo', () {
      final marks = {
        'a': const ArrivalMark(seen: 5, notified: 5),
        'b': const ArrivalMark(seen: 5, notified: 8),
      };
      final recorded = recordedArrivals(marks, {'a': 7, 'b': 6, 'c': 3});
      expect(recorded, {'a': const ArrivalMark(seen: 5, notified: 7)});
      final plan = planArrivals(
        [entry(key: 'a', archived: 7, latest: giugno)],
        {'a': following()},
        {...marks, ...recorded},
      );
      expect(plan.alerts, isEmpty);
    });

    test('guarda solo le serie seguite e non silenziate', () {
      final list = watchList(
        '/manga',
        [
          SeriesSignals.of(
            entry(key: 'a', title: 'Seguita', archived: 5),
            following(read: const {'1', '2'}, opened: giugno),
          ),
          SeriesSignals.of(entry(key: 'b', archived: 5), following(muted: true)),
          SeriesSignals.of(entry(key: 'c', archived: 5), const SeriesState()),
        ],
        {
          for (final key in ['a', 'b', 'c'])
            key: const ArrivalMark(seen: 4, notified: 5),
        },
      );
      expect(list['root'], '/manga');
      expect(list['series'], {
        'a': {
          'title': 'Seguita',
          'seen': 4,
          'notified': 5,
          'read': 2,
          'opened': giugno.millisecondsSinceEpoch,
        },
      });
    });
  });

  group('sul database', () {
    late KagamiDatabase db;
    late UserRepository repository;

    setUp(() {
      db = KagamiDatabase.forTesting(NativeDatabase.memory());
      repository = UserRepository(db);
    });

    tearDown(() => db.close());

    test('i riferimenti tornano indietro e si aggiornano', () async {
      await repository.saveArrivals({
        'a': const ArrivalMark(seen: 2, notified: 3),
      });
      await repository.saveArrivals({
        'a': const ArrivalMark(seen: 3, notified: 3),
        'b': const ArrivalMark(seen: 1, notified: 1),
      });
      expect(await repository.loadArrivals(), {
        'a': const ArrivalMark(seen: 3, notified: 3),
        'b': const ArrivalMark(seen: 1, notified: 1),
      });
    });

    test('il silenzio viaggia col backup, i riferimenti no', () async {
      await repository.saveSeriesState(
        'a',
        SeriesState(status: ShelfStatus.reading, muted: true, updatedAt: giugno),
      );
      await repository.saveArrivals({
        'a': const ArrivalMark(seen: 2, notified: 2),
      });
      final bytes = await BackupService(db).export();

      final other = KagamiDatabase.forTesting(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).import(bytes, ImportMode.merge);
      final restored = UserRepository(other);
      expect((await restored.loadStates())['a']!.muted, isTrue);
      expect(await restored.loadArrivals(), isEmpty);
    });
  });
}
