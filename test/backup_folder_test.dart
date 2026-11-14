/// La cartella delle copie scelta dall'utente: una nota del dispositivo, mai
/// dentro una sorgente, e una lettura fallita non vale «nessuna cartella».
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/backup.dart';
import 'package:kagami/src/data/backup_folder.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:path/path.dart' as p;

void main() {
  late KagamiDatabase db;
  late Directory temp;
  late String support;
  late String library;
  late BackupFolderStore store;

  setUp(() async {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('kagami-backup-folder');
    support = p.join(temp.path, 'support');
    library = p.join(temp.path, 'library');
    await Directory(support).create();
    store = BackupFolderStore(support);
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('senza file non c\'è nessuna cartella', () async {
    expect(await store.read(), isA<BackupFolderNone>());
  });

  test('la scelta sta in un file di <support> e si rilegge', () async {
    final target = p.join(temp.path, 'copie');
    expect(await store.choose(target, [library]), isNull);

    expect(store.file.path, startsWith(support));
    final state = await BackupFolderStore(support).read();
    expect(state, isA<BackupFolderChosen>());
    expect((state as BackupFolderChosen).path, target);

    await store.clear();
    expect(await store.read(), isA<BackupFolderNone>());
  });

  test('dentro una sorgente, o la sua radice, si rifiuta e non si salva', () async {
    for (final path in [library, p.join(library, 'Backup'), '$library/./a/../b']) {
      expect(await store.choose(path, [library]),
          BackupFolderRefusal.insideSource,
          reason: path);
    }
    expect(await store.read(), isA<BackupFolderNone>());
    // Una cartella vicina col nome che inizia uguale non è dentro.
    expect(await store.choose('$library-copie', [library]), isNull);
  });

  test('un file illeggibile non è «nessuna cartella»', () async {
    await store.file.writeAsString('{non json');
    expect(await store.read(), isA<BackupFolderUnreadable>());
    await store.file.writeAsString('{"path": 3}');
    expect(await store.read(), isA<BackupFolderUnreadable>());
  });

  test('autoBackup scrive anche nella cartella scelta', () async {
    final target = p.join(temp.path, 'copie');
    final file = await BackupService(db).autoBackup(support, slot: 'u-A', extraDirectory: target);

    expect(file, isNotNull);
    expect(File(p.join(target, 'u-A', p.basename(file!.path))).existsSync(), isTrue);
    expect(p.isWithin(p.join(support, 'backup', 'u-A'), file.path), isTrue);
  });
}
