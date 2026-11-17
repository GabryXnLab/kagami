/// L'identità di una serie non dipende dalla sorgente (FASE-5b §3, F5.13): ciò
/// che l'utente fa leggendo da una libreria condivisa è legato alla chiave
/// `<provider>:<id>` e ritrova la serie quando la stessa chiave arriva dal
/// suo Drive. Più la guardia contro una pulizia dello stato delle serie assenti.
library;

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/data/reader_settings.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';

import 'library_merge_sources_test.dart' show FakeRemote;
import 'library_merge_test.dart' show FakeDrive, entry, index;

const _key = 'mangak:S1';

SeriesEntry _row(String title) => SeriesEntry.fromJson({
      ...entry(_key).toJson(),
      'title': title,
      'type': 'Manga',
    });

final _stamp = DateTime.utc(2026, 11, 10, 12);

void main() {
  late KagamiDatabase db;
  late UserRepository user;
  late ReaderSettingsStore reader;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    user = UserRepository(db);
    reader = ReaderSettingsStore(db);
  });

  tearDown(() => db.close());

  const bound = Collection(
    id: 'auto',
    name: 'Manga',
    seriesKeys: [_key],
    rules: CollectionRules(types: {'manga'}, binding: true),
  );
  const manual = Collection(id: 'mia', name: 'Da rileggere', seriesKeys: [_key]);

  /// Ciò che si fa leggendo da una condivisione, tutto sotto la chiave.
  Future<void> readFromShare() async {
    await user.markChapters(_key, ['C1'], true, at: _stamp);
    await user.saveProgress(
      _key,
      ReadingProgress(chapterId: 'C2', page: 3, pageCount: 10, updatedAt: _stamp),
    );
    await user.saveSeriesState(
      _key,
      SeriesState(status: ShelfStatus.reading, rating: 8, updatedAt: _stamp),
    );
    await user.addBookmark(seriesKey: _key, chapterId: 'C2', page: 4);
    await reader.save(
      _key,
      const ReaderSettings(direction: ReaderDirection.rightToLeft, doublePage: true),
    );
  }

  /// Tutte le righe di stato della chiave, lette dal database e non dal catalogo.
  Future<void> expectStateIntact() async {
    expect(await user.keysWithData(), contains(_key));
    final state = (await user.loadStates())[_key]!;
    expect(state.readChapters, {'C1'});
    expect(state.positions['C2']!.page, 3);
    expect(state.positions['C2']!.pageCount, 10);
    expect(state.rating, 8);
    expect(state.status, ShelfStatus.reading);
    expect(await user.bookmarks(_key), hasLength(1));
    final settings = await reader.forSeries(_key);
    expect(settings.direction, ReaderDirection.rightToLeft);
    expect(settings.doublePage, isTrue);
    final collections = {for (final c in await user.loadCollections()) c.id: c};
    expect(collections['mia']!.seriesKeys, [_key]);
    expect(collections['auto']!.seriesKeys, [_key]);
    expect(collections['auto']!.rules.isBinding, isTrue);
  }

  Future<List<SeriesSignals>> signalsOf(LibraryCatalog catalog) async {
    final states = await user.loadStates();
    return [
      for (final row in catalog.index.series)
        SeriesSignals.of(row, states[row.key] ?? const SeriesState()),
    ];
  }

  final shared = FakeRemote('s-aaaaaaaa');

  test('letto da una condivisione, scaduta la sorgente lo stato resta', () async {
    final first = Library.merge({
      FakeDrive(): LibraryIndex.empty,
      shared: index([_row('Da Amica')]),
    });
    expect(first.holders[_key], [shared]);
    await readFromShare();
    await user.replaceCollections([manual, bound]);
    await expectStateIntact();

    // La sorgente scade o viene tolta: la serie esce dal catalogo.
    final expired = Library.merge({FakeDrive(): LibraryIndex.empty});
    expect(expired.index.series, isEmpty);
    expect(expired.holders, isEmpty);

    // La raccolta vincolante non toglie una serie assente.
    final loaded = {for (final c in await user.loadCollections()) c.id: c};
    final after = syncAutoMembers(loaded['auto']!, await signalsOf(expired));
    expect(after.seriesKeys, [_key]);
    await expectStateIntact();
  });

  test('la stessa chiave dal Drive dell\'account ritrova tutto, senza gesti', () async {
    await readFromShare();
    await user.replaceCollections([manual, bound]);

    final drive = FakeDrive();
    final catalog = Library.merge({drive: index([_row('Dal Drive')])});
    expect(catalog.holders[_key], [drive]);

    final signals = await signalsOf(catalog);
    final row = signals.single;
    expect(row.entry.key, _key);
    expect(row.state.readChapters, {'C1'});
    expect(row.state.positions['C2']!.page, 3);
    expect(row.state.rating, 8);
    expect(row.state.status, ShelfStatus.reading);

    final loaded = {for (final c in await user.loadCollections()) c.id: c};
    // La vincolante combacia (tipo manga): la serie resta.
    expect(syncAutoMembers(loaded['auto']!, signals).seriesKeys, [_key]);
    expect(syncAutoMembers(loaded['mia']!, signals).seriesKeys, [_key]);
    await expectStateIntact();
  });

  test('due sorgenti insieme: una riga sola, quella del Drive dell\'account', () async {
    final drive = FakeDrive();
    final catalog = Library.merge({
      drive: index([_row('Dal Drive')]),
      shared: index([_row('Da Amica')]),
    });
    expect(catalog.index.series, hasLength(1));
    expect(catalog.index.series.single.title, 'Dal Drive');
    expect(catalog.holders[_key], [drive, shared]);

    // Lo stato non sa chi serve la serie: la stessa scrittura dà le stesse righe.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final other = KagamiDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);
    await user.markChapters(_key, ['C1'], true, at: _stamp);
    await UserRepository(other).markChapters(_key, ['C1'], true, at: _stamp);
    final mine = await db.select(db.chapterReads).get();
    expect(mine, hasLength(1));
    expect(await other.select(other.chapterReads).get(), mine);
  });

  test('nessuna cancellazione di stato per chiave di serie fuori dall\'elenco chiuso', () {
    // Chi aggiunge qui una pulizia delle serie assenti dal catalogo rompe
    // l'identità fra sorgenti: lo stato di una serie scaduta deve restare.
    // Ogni voce è `file|tabella` e quante volte compare.
    const allowed = <String, int>{
      // Rimozione esplicita di una serie, adozione (moveSeries), cronologia,
      // segnalibro, capitoli rinominati, azzeramento del profilo.
      'src/data/user_repository.dart|chapterReads': 3,
      'src/data/user_repository.dart|progresses': 1,
      'src/data/user_repository.dart|bookmarks': 2,
      'src/data/user_repository.dart|seriesStates': 2,
      'src/data/user_repository.dart|collectionItems': 1,
      // Il quarto: «Porta qui i miei dati» (F5.16), dopo la conferma, toglie i
      // capitoli letti senza corrispondente della serie da cui si porta.
      'src/data/user_repository.dart|DELETE FROM': 4,
      // Ripristino del backup in modalità «sostituisci».
      'src/data/backup.dart|chapterReads': 1,
      'src/data/backup.dart|progresses': 1,
      'src/data/backup.dart|bookmarks': 1,
      'src/data/backup.dart|readerSettingsRows': 1,
      'src/data/backup.dart|seriesStates': 1,
      // Migrazione: doppioni di segnalibri e sessioni.
      'src/data/db/database.dart|DELETE FROM': 2,
    };
    const tables = 'seriesStates|progresses|chapterReads|collectionItems|bookmarks|readerSettingsRows';
    final pattern = RegExp('\\.delete\\(\\s*\\w+\\.($tables)\\)|(DELETE FROM)');
    final found = <String, int>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart') || file.path.endsWith('.g.dart')) continue;
      final name = file.path.substring('lib/'.length);
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        final id = '$name|${match.group(1) ?? match.group(2)}';
        found[id] = (found[id] ?? 0) + 1;
      }
    }
    expect(found, allowed,
        reason: 'una cancellazione nuova di righe di stato per serie: se non è un gesto '
            'esplicito dell\'utente non va fatta; se lo è, aggiungila a `allowed` col suo perché');
  });
}
