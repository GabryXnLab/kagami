/// `formerKeys` di una sorgente non mia (FASE-5b §3, F5.14): nascondono solo
/// righe della stessa sorgente, e spostano i miei dati solo se nessuna mia
/// sorgente tiene la chiave vecchia.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/adoption.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';

import 'library_merge_sources_test.dart' show FakeRemote;
import 'library_merge_test.dart' show FakeDrive, entry, index;

const _old = 'coffeemanga:7743';
const _fresh = 'coffeemanga:the-house';

SeriesEntry _adopted() => SeriesEntry.fromJson({...entry(_fresh).toJson(), 'formerKeys': [_old]});

void main() {
  late KagamiDatabase db;
  late UserRepository repository;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    repository = UserRepository(db);
  });
  tearDown(() => db.close());

  Future<int> adopt(LibraryCatalog catalog) => adoptFormerKeys(
        series: catalog.index.series,
        keysWithData: repository.keysWithData,
        loadIndex: (_) async => SeriesIndex.fromJson({'key': _fresh, 'chapters': const []}),
        move: (from, to, chapters) => repository.moveSeries(from, to, chapters: chapters),
        keep: ownedKeys(catalog),
      );

  test('una condivisione che nomina una chiave del mio Drive: la mia riga resta e i dati non si muovono', () async {
    final mine = FakeDrive(library: index([entry(_old)]));
    final shared = FakeRemote('s-aaaaaaaa');
    final catalog = Library.merge({mine: mine.library, shared: index([_adopted()])});
    expect(catalog.holders[_old], [mine]);
    expect(catalog.holders[_fresh], [shared]);
    expect(catalog.index.series.map((row) => row.key), containsAll([_old, _fresh]));

    await repository.saveSeriesState(_old, SeriesState(status: ShelfStatus.reading, rating: 7));
    expect(await adopt(catalog), 0);
    final states = await repository.loadStates();
    expect(states[_old]!.rating, 7);
    expect(states.containsKey(_fresh), isFalse);
  });

  test('una chiave letta solo da lì: la riga vecchia sparisce e i dati passano alla nuova', () async {
    final shared = FakeRemote('s-aaaaaaaa');
    final catalog = Library.merge({
      FakeDrive(): LibraryIndex.empty,
      shared: index([_adopted(), entry(_old)]),
    });
    expect(catalog.holders.containsKey(_old), isFalse);

    await repository.saveSeriesState(_old, SeriesState(status: ShelfStatus.reading, rating: 7));
    expect(await adopt(catalog), 1);
    final states = await repository.loadStates();
    expect(states.containsKey(_old), isFalse);
    expect(states[_fresh]!.rating, 7);
  });

  test('i formerKeys di una condivisione non nascondono le righe di un\'altra condivisione', () {
    final first = FakeRemote('s-aaaaaaaa');
    final second = FakeRemote('s-bbbbbbbb');
    final catalog = Library.merge({first: index([_adopted()]), second: index([entry(_old)])});
    expect(catalog.holders[_old], [second]);
  });

  test('i formerKeys del mio Drive valgono per tutte le sorgenti, come prima', () async {
    final mine = FakeDrive();
    final shared = FakeRemote('s-aaaaaaaa');
    final catalog = Library.merge({mine: index([_adopted()]), shared: index([entry(_old)])});
    expect(catalog.holders.containsKey(_old), isFalse);

    await repository.saveSeriesState(_old, SeriesState(status: ShelfStatus.reading, rating: 7));
    expect(await adopt(catalog), 1);
    expect((await repository.loadStates())[_fresh]!.rating, 7);
  });
}
