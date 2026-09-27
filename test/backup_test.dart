/// Il backup è ciò che fa sopravvivere i dati personali a una
/// reinstallazione: se sbaglia, non se ne accorge nessuno finché non è tardi.
library;

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/backup.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/reading.dart';

void main() {
  late KagamiDatabase source;
  late UserRepository repository;

  setUp(() async {
    source = KagamiDatabase.forTesting(NativeDatabase.memory());
    repository = UserRepository(source);
    await repository.saveSeriesState(
      'mangak:S1',
      SeriesState(
        status: ShelfStatus.reading,
        rating: 8,
        favorite: true,
        notes: 'da finire',
        updatedAt: DateTime.utc(2026, 5, 1),
      ),
    );
    await repository.markChapters(
      'mangak:S1',
      ['C1', 'C2'],
      true,
      at: DateTime.utc(2026, 5, 2),
    );
    await repository.saveProgress(
      'mangak:S1',
      ReadingProgress(
        chapterId: 'C3',
        page: 7,
        pageCount: 30,
        offset: 0.25,
        updatedAt: DateTime.utc(2026, 5, 3),
      ),
    );
    await repository.replaceCollections([
      Collection(id: 'c1', name: 'Serali', seriesKeys: const ['mangak:S1']),
    ]);
    await repository.addBookmark(
      seriesKey: 'mangak:S1',
      chapterId: 'C2',
      page: 3,
    );
  });

  tearDown(() => source.close());

  test('un backup ricostruisce i dati su un dispositivo vuoto', () async {
    final bytes = await BackupService(source).export();

    final target = KagamiDatabase.forTesting(NativeDatabase.memory());
    final restored = UserRepository(target);
    final summary = await BackupService(target).inspect(bytes);
    expect(summary!.series, 1);
    expect(summary.chapters, 2);
    expect(summary.collections, 1);

    expect(await BackupService(target).import(bytes, ImportMode.merge), isTrue);
    final state = (await restored.loadStates())['mangak:S1']!;
    expect(state.status, ShelfStatus.reading);
    expect(state.rating, 8);
    expect(state.favorite, isTrue);
    expect(state.notes, 'da finire');
    expect(state.readChapters, {'C1', 'C2'});
    expect(state.progress!.page, 7);
    expect(state.progress!.offset, closeTo(0.25, 0.001));
    expect((await restored.loadCollections()).single.name, 'Serali');
    expect((await restored.bookmarks('mangak:S1')).single.page, 3);
    await target.close();
  });

  test('fondere unisce i capitoli letti dei due dispositivi', () async {
    final bytes = await BackupService(source).export();

    final target = KagamiDatabase.forTesting(NativeDatabase.memory());
    final other = UserRepository(target);
    await other.markChapters(
      'mangak:S1',
      ['C9'],
      true,
      at: DateTime.utc(2026, 4, 1),
    );
    await other.saveSeriesState(
      'mangak:S1',
      SeriesState(status: ShelfStatus.paused, updatedAt: DateTime.utc(2026, 6, 1)),
    );

    await BackupService(target).import(bytes, ImportMode.merge);
    final state = (await other.loadStates())['mangak:S1']!;
    // I capitoli si sommano sempre; sul resto vince il record più recente,
    // che qui è quello già presente sul dispositivo.
    expect(state.readChapters, {'C1', 'C2', 'C9'});
    expect(state.status, ShelfStatus.paused);
    await target.close();
  });

  test('sostituire lascia solo quello che c\'era nel file', () async {
    final bytes = await BackupService(source).export();

    final target = KagamiDatabase.forTesting(NativeDatabase.memory());
    final other = UserRepository(target);
    await other.markChapters('mangak:S9', ['X1'], true);
    await BackupService(target).import(bytes, ImportMode.replace);
    final states = await other.loadStates();
    expect(states.keys, ['mangak:S1']);
    await target.close();
  });

  test('fondere due volte la stessa copia non raddoppia sessioni e segnalibri',
      () async {
    await repository.logSession(
      seriesKey: 'mangak:S1',
      chapterId: 'C2',
      startedAt: DateTime.utc(2026, 5, 2, 20),
      endedAt: DateTime.utc(2026, 5, 2, 20, 30),
      pagesRead: 12,
    );
    // È ciò che fa ogni sincronizzazione: fondere la copia in rete, che ha
    // le stesse righe del telefono, e rimandare su il risultato.
    for (var round = 0; round < 3; round++) {
      final remote = await BackupService(source).export();
      await BackupService(source).import(remote, ImportMode.merge);
    }
    expect(await source.select(source.readingSessions).get(), hasLength(1));
    expect(await source.select(source.bookmarks).get(), hasLength(1));
  });

  test('fondendo, un\'impostazione scelta dopo l\'ultimo invio non torna '
      'indietro', () async {
    // La copia in rete: la cartella di Drive scollegata tempo fa.
    await repository.writeSetting('drive.folder', '',
        at: DateTime.utc(2026, 5, 1));
    await repository.writeSetting('reader.theme', 'scuro',
        at: DateTime.utc(2026, 5, 1));
    final remote = await BackupService(source).export();

    // Il telefono: la cartella appena scelta, il tema fermo a prima.
    final target = KagamiDatabase.forTesting(NativeDatabase.memory());
    final phone = UserRepository(target);
    await phone.writeSetting('drive.folder', '{"id":"F","name":"Manga"}');
    await phone.writeSetting('reader.theme', 'chiaro',
        at: DateTime.utc(2026, 4, 1));

    await BackupService(target).import(remote, ImportMode.merge);
    expect(await phone.readSetting('drive.folder'), '{"id":"F","name":"Manga"}');
    expect(await phone.readSetting('reader.theme'), 'scuro');
    await target.close();
  });

  test('un\'impostazione senza data, da un backup di prima, cede a una datata',
      () async {
    final target = KagamiDatabase.forTesting(NativeDatabase.memory());
    final phone = UserRepository(target);
    await phone.writeSetting('drive.folder', '{"id":"F","name":"Manga"}');
    await source.into(source.appSettings).insert(
          AppSettingsCompanion.insert(key: 'drive.folder', value: ''),
        );
    final old = await BackupService(source).export();

    await BackupService(target).import(old, ImportMode.merge);
    expect(await phone.readSetting('drive.folder'), '{"id":"F","name":"Manga"}');
    await BackupService(target).import(old, ImportMode.replace);
    expect(await phone.readSetting('drive.folder'), '');
    await target.close();
  });

  test('un file che non è un backup di Kagami non tocca niente', () async {
    final target = KagamiDatabase.forTesting(NativeDatabase.memory());
    final service = BackupService(target);
    expect(await service.inspect(Uint8List.fromList([1, 2, 3])), isNull);
    expect(
      await service.import(Uint8List.fromList([1, 2, 3]), ImportMode.replace),
      isFalse,
    );
    await target.close();
  });
}
