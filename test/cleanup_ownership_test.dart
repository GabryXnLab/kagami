/// Kagami cancella solo dove l'utente possiede (FASE-5b §5, F5.21): la
/// pulizia e «Elimina» usano lo scaffale del Drive dell'account, mai quello di
/// una condivisione, e solo se la cartella è sua.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/auto_cleanup.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/drive_library.dart';
import 'package:kagami/src/data/drive_ownership.dart';
import 'package:kagami/src/data/folder_sync.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/series_removal.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:path/path.dart' as p;

import 'drive_library_test.dart' show FakeClient;

void main() {
  late Directory temp;

  /// Una libreria su Drive con la serie `mangak:S1` e il capitolo [chapter].
  FakeClient drive(String root, String chapter) => FakeClient()
    ..add('LIB-$root', libraryIndexFile, root, content: jsonEncode({
      'format': 'malf',
      'series': [
        {'key': 'mangak:S1', 'path': 'Prova [mangak-S1]', 'title': 'Prova', 'archivedChapterCount': 1},
      ],
    }))
    ..add('S-$root', 'Prova [mangak-S1]', root)
    ..add('IDX-$root', seriesIndexFile, 'S-$root', content: jsonEncode({
      'key': 'mangak:S1',
      'chapters': [
        {'id': chapter, 'order': 0, 'complete': true, 'archived': true, 'pageCount': 1,
         'path': 'chapters/0001 - Primo [$chapter]'},
      ],
    }))
    ..add('CH-$root', 'chapters', 'S-$root')
    ..add(chapter, '0001 - Primo [$chapter]', 'CH-$root');

  DriveRepository shelf(FakeClient client, String folder, {LibraryOrigin origin = LibraryOrigin.drive}) =>
      DriveRepository(
        client: client,
        folderId: folder,
        stateDirectory: p.join(temp.path, 'state'),
        files: DriveFileCache(Directory(p.join(temp.path, 'cache')), limitBytes: 1 << 20),
        sourceId: origin == LibraryOrigin.drive ? 'drive' : 's-0000000a',
        origin: origin,
      );

  late FakeClient mine;
  late FakeClient theirs;
  late DriveRepository own;
  late DriveRepository shared;
  late SeriesEntry entry;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kagami-ownership');
    mine = drive('R', 'C1');
    theirs = drive('X', 'C9');
    own = shelf(mine, 'R');
    shared = shelf(theirs, 'X', origin: LibraryOrigin.remote);
    entry = (await own.loadLibrary()).series.single;
    await own.pruned;
    mine.calls.clear();
    theirs.calls.clear();
  });
  tearDown(() async => temp.delete(recursive: true));

  group('lo scaffale della pulizia', () {
    test('serie tenuta da condivisione e Drive proprio: solo percorsi del proprio', () async {
      final chapters = await cleanupDriveChapters(entry, [shared, own], owned: true);
      expect([for (final chapter in chapters) chapter.chapter], ['C1']);
      expect(theirs.calls, isEmpty);
    });

    test('serie solo da una condivisione: nessuna voce di Drive', () async {
      expect(await cleanupDriveChapters(entry, [shared], owned: true), isEmpty);
      expect(theirs.calls, isEmpty);
    });

    test('proprietà non letta o falsa: nessuna voce di Drive', () async {
      expect(await cleanupDriveChapters(entry, [own], owned: null), isEmpty);
      expect(await cleanupDriveChapters(entry, [own], owned: false), isEmpty);
      expect(mine.calls, isEmpty);
    });
  });

  test('withdrawPaths su uno scaffale non proprio lancia senza cestinare', () async {
    const path = 'chapters/0001 - Primo [C9]';
    await expectLater(shared.withdrawPaths(entry.path, [path], theirs), throwsStateError);
    await expectLater(shared.withdrawChapters(entry, [path], theirs), throwsStateError);
    expect(theirs.calls.where((call) => call.startsWith('trash')), isEmpty);
  });

  group('removeSeries', () {
    late ArchiveFiles archive;
    setUp(() => archive = ArchiveFiles(p.join(temp.path, 'support')));

    test('cartella non propria o non letta: nessuna chiamata a Drive', () async {
      for (final owned in [null, false]) {
        await removeSeries(entry, holders: [own], archive: archive, writer: mine, folderId: 'R', driveOwned: owned);
      }
      expect(mine.calls, isEmpty);
    });

    test('solo da una condivisione: non si propone e non tocca Drive', () async {
      expect(canRemoveSeries([shared], driveOwned: true), isFalse);
      expect(canRemoveSeries([own], driveOwned: false), isFalse);
      expect(canRemoveSeries([own], driveOwned: true), isTrue);
      await removeSeries(entry, holders: [shared], archive: archive, writer: theirs, folderId: 'X', driveOwned: true);
      expect(theirs.calls, isEmpty);
    });
  });

  group('il piano porta account e cartella', () {
    late AutoCleanupFiles files;
    late SyncFiles sync;
    final now = DateTime.utc(2026, 11, 14);
    final item = CleanupItem(
      series: 'mangak:S1',
      chapter: 'C1',
      due: DateTime.utc(2026),
      seriesPath: 'Prova [mangak-S1]',
      remote: 'chapters/0001 - Primo [C1]',
    );

    setUp(() {
      files = AutoCleanupFiles(p.join(temp.path, 'support'));
      sync = SyncFiles(p.join(temp.path, 'support'));
    });

    test('scritto e riletto', () async {
      await files.writePlan([item], account: 'a@x.it', folder: 'R');
      final plan = await files.readPlan();
      expect((plan.account, plan.folder), ('a@x.it', 'R'));
    });

    test("piano di un altro account o di un'altra cartella: parte di Drive saltata e tenuta", () async {
      await files.writePlan([item], account: 'a@x.it', folder: 'R');
      var calls = 0;
      for (final target in [(account: 'b@x.it', folder: 'R'), (account: 'a@x.it', folder: 'Y'), null]) {
        final outcome = await runAutoCleanup(files, sync,
            now: now, target: target, withdraw: (_, _) async => calls++);
        expect(outcome.removed, isEmpty);
      }
      expect(calls, 0);
      expect((await files.readPlan()).items, hasLength(1));

      final outcome = await runAutoCleanup(files, sync,
          now: now, target: (account: 'a@x.it', folder: 'R'), withdraw: (_, _) async => calls++);
      expect(calls, 1);
      expect(outcome.fromDrive, {'mangak:S1': {'C1'}});
    });
  });

  group('proprietà della cartella', () {
    test('salvata per cartella: si chiede solo se manca o è di un\'altra', () async {
      final asked = <String>[];
      final saved = <String>[];
      Future<bool?> resolve(String? stored, String folder) => resolveFolderOwnership(
            folderId: folder,
            stored: stored,
            ask: (id) async {
              asked.add(id);
              return false;
            },
            save: (value) async => saved.add(value),
          );
      expect(await resolve('R:true', 'R'), isTrue);
      expect(asked, isEmpty);
      expect(await resolve('R:true', 'Y'), isFalse);
      expect(asked, ['Y']);
      expect(saved, ['Y:false']);
    });

    test('non letta: null, niente salvato, si richiede al giro dopo', () async {
      final saved = <String>[];
      final owned = await resolveFolderOwnership(
        folderId: 'R',
        stored: null,
        ask: (_) => throw const DriveOffline(),
        save: (value) async => saved.add(value),
      );
      expect(owned, isNull);
      expect(saved, isEmpty);
    });
  });
}
