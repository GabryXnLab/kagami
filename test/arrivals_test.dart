/// Capitoli nuovi: il numero sul pallino e di quali arrivi dare notizia.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/arrivals.dart';
import 'package:kagami/src/data/backup.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/malf.dart';
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

  group('le schede', () {
    // Una scheda: 40 capitoli sul sito, nessuno archiviato, letta altrove
    // fino al 30 (letti stimati).
    final letti = {for (var i = 1; i <= 30; i++) '$i'};

    SeriesEntry card({int chapters = 40, int archived = 0, DateTime? fetched}) =>
        entry(
          key: 'mangak:s',
          chapters: chapters,
          archived: archived,
          added: fetched ?? giugno,
        );

    test('vista la prima volta prende come riferimento i capitoli del sito', () {
      final plan = planArrivals([card()], {'mangak:s': following(read: letti)}, const {});
      expect(plan.alerts, isEmpty);
      expect(
        plan.marks['mangak:s'],
        const ArrivalMark(seen: 40, notified: 40, onSite: true),
      );
    });

    test('i capitoli nuovi del sito si annunciano come tali', () {
      final plan = planArrivals(
        [card(chapters: 43)],
        {'mangak:s': following(read: letti)},
        {'mangak:s': const ArrivalMark(seen: 40, notified: 40, onSite: true)},
      );
      expect(plan.alerts.single.count, 3);
      expect(plan.alerts.single.onSite, isTrue);
      expect(
        plan.marks['mangak:s'],
        const ArrivalMark(seen: 40, notified: 43, onSite: true),
      );
    });

    test('il pallino conta i capitoli del sito non letti altrove', () {
      final signals = SeriesSignals.of(
        card(chapters: 43),
        following(read: letti),
        seenChapters: 40,
      );
      expect(signals.unreadCount, 0);
      expect(signals.newChapters, 3);
      final ahead = SeriesSignals.of(
        card(chapters: 43),
        following(read: {for (var i = 1; i <= 42; i++) '$i'}),
        seenChapters: 40,
      );
      expect(ahead.newChapters, 1);
    });

    test('aperta altrove dopo l\'ultima lettura del sito non ha nuovi', () {
      final signals = SeriesSignals.of(
        card(chapters: 43),
        following(read: letti, opened: luglio),
        seenChapters: 40,
      );
      expect(signals.newChapters, 0);
    });

    test('una scheda manuale non ha mai capitoli nuovi', () {
      final manual = entry(key: 'manual:m', provider: 'manual', chapters: 0, archived: 0);
      final plan = planArrivals(
        [manual],
        {'manual:m': following(read: const {})},
        {'manual:m': const ArrivalMark(seen: 0, notified: 0, onSite: true)},
      );
      expect(plan.alerts, isEmpty);
      expect(plan.marks, isEmpty);
    });

    test('al primo download il riferimento riparte, senza annunci', () {
      final marks = {
        'mangak:s': const ArrivalMark(seen: 40, notified: 43, onSite: true),
      };
      final downloaded = card(chapters: 43, archived: 1);
      expect(marks['mangak:s']!.seenFor(downloaded), isNull);
      expect(
        SeriesSignals.of(downloaded, following(read: letti), seenChapters: null)
            .newChapters,
        0,
      );
      final plan = planArrivals([downloaded], {'mangak:s': following(read: letti)}, marks);
      expect(plan.alerts, isEmpty);
      expect(plan.marks['mangak:s'], const ArrivalMark(seen: 1, notified: 1));

      // E non resta bloccato sopra: il capitolo archiviato dopo si annuncia.
      final next = planArrivals(
        [card(chapters: 43, archived: 2)],
        {'mangak:s': following(read: const {})},
        plan.marks,
      );
      expect(next.alerts.single.count, 1);
      expect(next.alerts.single.onSite, isFalse);
    });

    test('una serie che torna scheda riparte dai capitoli del sito', () {
      final plan = planArrivals(
        [card(chapters: 50)],
        {'mangak:s': following(read: letti)},
        {'mangak:s': const ArrivalMark(seen: 3, notified: 3)},
      );
      expect(plan.alerts, isEmpty);
      expect(
        plan.marks['mangak:s'],
        const ArrivalMark(seen: 50, notified: 50, onSite: true),
      );
    });

    test('aprire la scheda tiene la base', () {
      expect(
        const ArrivalMark(seen: 40, notified: 43, onSite: true).acknowledged(43),
        const ArrivalMark(seen: 43, notified: 43, onSite: true),
      );
      expect(
        ArrivalMark.of(card(chapters: 43)),
        const ArrivalMark(seen: 43, notified: 43, onSite: true),
      );
    });

    test('ad app chiusa i conti del sito stanno sotto una chiave loro', () {
      final marks = {
        'mangak:s': const ArrivalMark(seen: 40, notified: 40, onSite: true),
        'mangak:t': const ArrivalMark(seen: 1, notified: 1),
      };
      final recorded = recordedArrivals(marks, {
        'mangak:s@site': 42,
        // Annunciato quand'era una scheda: ora che è scaricata non conta.
        'mangak:t@site': 60,
      });
      expect(recorded, {
        'mangak:s': const ArrivalMark(seen: 40, notified: 42, onSite: true),
      });
      expect(recordKey('mangak:s', onSite: true), 'mangak:s@site');
      expect(recordKey('mangak:s', onSite: false), 'mangak:s');
    });

    test('il controllo ad app chiusa riceve il sito e i letti fra i capitoli del sito', () {
      final list = watchList(
        '/manga',
        [
          SeriesSignals.of(
            card(chapters: 43),
            following(read: letti, opened: giugno),
          ),
          // Riferimento preso prima del primo download: lo riprende l'app.
          SeriesSignals.of(
            entry(key: 'mangak:u', chapters: 20, archived: 2),
            following(),
          ),
        ],
        {
          'mangak:s': const ArrivalMark(seen: 40, notified: 40, onSite: true),
          'mangak:u': const ArrivalMark(seen: 20, notified: 20, onSite: true),
        },
      );
      expect(list['series'], {
        'mangak:s': {
          'title': 'Serie',
          'seen': 40,
          'notified': 40,
          'read': 30,
          'opened': giugno.millisecondsSinceEpoch,
          'site': 'MangaK',
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
        'b': const ArrivalMark(seen: 1, notified: 1, onSite: true),
      });
      expect(await repository.loadArrivals(), {
        'a': const ArrivalMark(seen: 3, notified: 3),
        'b': const ArrivalMark(seen: 1, notified: 1, onSite: true),
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
