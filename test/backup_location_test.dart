/// Le copie automatiche non stanno mai nella libreria (D5): vanno nello spazio
/// dell'app, e ciò che Kagami vi aveva messo prima si sposta una volta.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/backup.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/reading_migration.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late KagamiDatabase db;
  late UserRepository repository;
  late Directory temp;
  late String root;
  late String support;

  File inRoot(String path) => File(p.joinAll([root, ...path.split('/')]));
  File inSupport(String path) => File(p.joinAll([support, ...path.split('/')]));

  Future<void> put(File file, String content) async {
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<List<String>> filesUnder(String directory) async => [
        await for (final e in Directory(directory).list(recursive: true))
          if (e is File) p.relative(e.path, from: directory),
      ];

  Future<bool> migrate() => moveReadingOutOfLibrary(
        repository: repository,
        root: root,
        support: support,
        slot: 'u-A',
      );

  setUp(() async {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    repository = UserRepository(db);
    temp = await Directory.systemTemp.createTemp('kagami-backup-location');
    root = p.join(temp.path, 'library');
    support = p.join(temp.path, 'support');
    await Directory(root).create();
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('la copia automatica va nello spazio dell\'app e la libreria resta vuota', () async {
    final file = await BackupService(db).autoBackup(support, slot: 'u-A');

    expect(file, isNotNull);
    expect(p.isWithin(p.join(support, 'backup', 'u-A'), file!.path), isTrue);
    expect(await filesUnder(root), isEmpty);
    expect(await BackupService(db).backupsIn(support, slot: 'u-A'), hasLength(1));
    // Una al giorno.
    expect(await BackupService(db).autoBackup(support, slot: 'u-A'), isNull);
  });

  test('la migrazione sposta le copie, ne tiene cinque e toglie la cartella', () async {
    for (var day = 1; day <= 7; day++) {
      await put(inRoot('reading/backup/kagami-2026010$day-1000.json.gz'), 'copia $day');
    }
    await put(inRoot('reading/downloads.json'), '{}');

    expect(await migrate(), isTrue);

    final kept = await BackupService(db).backupsIn(support, slot: 'u-A');
    expect(kept.map((f) => p.basename(f.path)), [
      for (var day = 7; day >= 3; day--) 'kagami-2026010$day-1000.json.gz',
    ]);
    expect(await kept.first.readAsString(), 'copia 7');
    expect(await Directory(p.join(root, 'reading', 'backup')).exists(), isFalse);
    expect(await inRoot('reading/downloads.json').exists(), isTrue);
    expect(await repository.readSetting('moved.reading:$root'), isNotNull);
  });

  test('una copia fallita lascia l\'originale e non mette il segno', () async {
    await put(inRoot('reading/backup/kagami-20260101-1000.json.gz'), 'copia');
    // Una cartella al posto della destinazione: la copia non può riuscire.
    await Directory(p.join(support, 'backup', 'u-A', 'kagami-20260101-1000.json.gz'))
        .create(recursive: true);

    expect(await migrate(), isFalse);

    expect(await inRoot('reading/backup/kagami-20260101-1000.json.gz').readAsString(), 'copia');
    expect(await repository.readSetting('moved.reading:$root'), isNull);

    // Sistemato il guaio, l'avvio dopo riprova e ce la fa.
    await Directory(p.join(support, 'backup', 'u-A', 'kagami-20260101-1000.json.gz')).delete();
    expect(await migrate(), isTrue);
    expect(await inSupport('backup/u-A/kagami-20260101-1000.json.gz').readAsString(), 'copia');
    expect(await inRoot('reading/backup/kagami-20260101-1000.json.gz').exists(), isFalse);
  });

  test('lo stato storico non ancora importato resta dov\'è', () async {
    await put(inRoot('reading/state.json'), '{"series":{}}');
    await put(inRoot('reading/collections.json'), '{"collections":[]}');

    // Niente segno: importato più tardi, deve ancora poter uscire.
    expect(await migrate(), isFalse);

    expect(await inRoot('reading/state.json').exists(), isTrue);
    expect(await inRoot('reading/collections.json').exists(), isTrue);
    expect(await inSupport('legacy/state.json').exists(), isFalse);

    await repository.importLegacyReading(root);
    expect(await migrate(), isTrue);
    expect(await inRoot('reading/state.json').exists(), isFalse);
    expect(await inSupport('legacy/state.json').exists(), isTrue);
  });

  test('importato, lo stato storico esce dalla libreria; il secondo giro non fa niente', () async {
    await put(inRoot('reading/state.json'), '{"series":{}}');
    await put(inRoot('reading/collections.json'), '{"collections":[]}');
    await repository.importLegacyReading(root);

    expect(await migrate(), isTrue);

    expect(await inRoot('reading/state.json').exists(), isFalse);
    expect(await inRoot('reading/collections.json').exists(), isFalse);
    expect(await inSupport('legacy/state.json').readAsString(), '{"series":{}}');
    expect(await inSupport('legacy/collections.json').readAsString(), '{"collections":[]}');

    await put(inRoot('reading/backup/kagami-20260101-1000.json.gz'), 'tardiva');
    expect(await migrate(), isFalse);
    expect(await inRoot('reading/backup/kagami-20260101-1000.json.gz').exists(), isTrue);
  });

  test('la potatura di uno slot non tocca le copie dell\'altro, né in extra', () async {
    final extra = p.join(temp.path, 'copie');
    for (final slot in ['u-A', 'u-B']) {
      for (var day = 1; day <= 6; day++) {
        final copy = File(p.join(support, 'backup', slot, 'kagami-2026010$day-1000.json.gz'));
        await put(copy, slot);
        await copy.setLastModified(DateTime(2026, 1, day));
        await put(File(p.join(extra, slot, 'kagami-2026010$day-1000.json.gz')), slot);
      }
    }
    await put(File(p.join(support, 'backup', 'u-B', 'kagami-20260107-1000.json.gz')), 'u-B');

    final service = BackupService(db);
    // Nessuna copia recente in A: ne fa una nuova e pota A.
    final file = await service.autoBackup(support, slot: 'u-A', extraDirectory: extra);

    expect(p.isWithin(p.join(extra, 'u-A'), p.join(extra, 'u-A', p.basename(file!.path))), isTrue);
    expect(File(p.join(extra, 'u-A', p.basename(file.path))).existsSync(), isTrue);
    expect(await service.backupsIn(support, slot: 'u-A'), hasLength(keptBackups));
    expect(await service.backupsIn(support, slot: 'u-B'), hasLength(7));
    expect(await BackupService.listIn(Directory(p.join(extra, 'u-B'))), hasLength(6));
    expect(await BackupService.listIn(Directory(p.join(extra, 'u-A'))), hasLength(keptBackups));
  });
}
