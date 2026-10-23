/// La pulizia automatica: le regole del piano, che non toccano niente, e il
/// giro che toglie le cartelle scadute, su una cartella temporanea.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/auto_cleanup.dart';
import 'package:kagami/src/data/folder_sync.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:path/path.dart' as p;

void main() {
  final now = DateTime.utc(2026, 10, 22, 12);
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  StoredChapter chapter(String id, {DateTime? arrivedAt, String series = 's'}) => StoredChapter.phone(
        series: series,
        chapter: id,
        directory: '/libreria/$series/chapters/$id',
        arrivedAt: arrivedAt ?? DateTime.utc(2026, 1, 1),
      );

  group('planAutoCleanup', () {
    const state = SeriesState(readChapters: {'1'});

    test('a regole spente non toglie niente', () {
      final plan = planAutoCleanup(
        settings: const AutoCleanupSettings(),
        chapters: [chapter('1'), chapter('2')],
        state: (_) => state,
        activity: (_) => null,
      );
      expect(plan, isEmpty);
    });

    test('i letti scadono subito, i da leggere restano senza la seconda regola', () {
      final plan = planAutoCleanup(
        settings: const AutoCleanupSettings(read: true),
        chapters: [chapter('1'), chapter('2')],
        state: (_) => state,
        activity: (_) => now,
      );
      expect([for (final item in plan) item.chapter], ['1']);
      expect(plan.single.due, epoch);
    });

    test('i da leggere scadono dall\'ultima lettura della serie o dal loro arrivo, il più tardi', () {
      final plan = planAutoCleanup(
        settings: const AutoCleanupSettings(idle: true, idleDays: 14),
        chapters: [
          chapter('1'),
          chapter('2'),
          chapter('3', arrivedAt: DateTime.utc(2026, 10, 20)),
        ],
        state: (_) => state,
        activity: (_) => DateTime.utc(2026, 10, 1),
      );
      expect({for (final item in plan) item.chapter: item.due}, {
        '2': DateTime.utc(2026, 10, 15),
        '3': DateTime.utc(2026, 11, 3),
      });
    });

    test('una serie mai letta conta dall\'arrivo del capitolo', () {
      final plan = planAutoCleanup(
        settings: const AutoCleanupSettings(idle: true, idleDays: 7),
        chapters: [chapter('1', arrivedAt: DateTime.utc(2026, 10, 10))],
        state: (_) => const SeriesState(),
        activity: (_) => null,
      );
      expect(plan.single.due, DateTime.utc(2026, 10, 17));
    });

    test('su Drive la seconda regola tocca solo le serie cominciate, e i capitoli con una data', () {
      StoredChapter remote(String id, DateTime? arrivedAt) => StoredChapter.drive(
            series: 's',
            chapter: id,
            seriesPath: 'Serie',
            remote: 'chapters/$id',
            arrivedAt: arrivedAt,
          );
      final chapters = [remote('1', DateTime.utc(2026, 1, 1)), remote('2', DateTime.utc(2026, 1, 1)), remote('3', null)];
      const settings = AutoCleanupSettings(read: true, idle: true, idleDays: 14);
      final untouched = planAutoCleanup(
        settings: settings,
        chapters: chapters,
        state: (_) => const SeriesState(),
        activity: (_) => null,
      );
      expect(untouched, isEmpty);
      final started = planAutoCleanup(
        settings: settings,
        chapters: chapters,
        state: (_) => const SeriesState(readChapters: {'1'}),
        activity: (_) => DateTime.utc(2026, 9, 1),
      );
      expect({for (final item in started) item.chapter: item.due}, {'1': epoch, '2': DateTime.utc(2026, 9, 15)});
      expect(started.first.synced, 'Serie/chapters/1');
    });
  });

  test('le regole tornano intere dal JSON, e un numero di giorni rotto torna a due settimane', () {
    const settings = AutoCleanupSettings(read: true, idle: true, idleDays: 30);
    expect(AutoCleanupSettings.fromJson(settings.toJson()), settings);
    expect(AutoCleanupSettings.fromJson({'idle': true, 'idleDays': 0}).idleDays, 14);
  });

  test('«man mano» lascia stare le serie lasciate e quelle mai lette, solo con la seconda regola', () {
    const idle = AutoCleanupSettings(idle: true, idleDays: 14);
    expect(idleForReadAhead(idle, now.subtract(const Duration(days: 15)), now), isTrue);
    expect(idleForReadAhead(idle, null, now), isTrue);
    expect(idleForReadAhead(idle, now.subtract(const Duration(days: 2)), now), isFalse);
    expect(idleForReadAhead(const AutoCleanupSettings(read: true), null, now), isFalse);
  });

  group('runAutoCleanup', () {
    late Directory temp;
    late AutoCleanupFiles files;
    late SyncFiles sync;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('kagami-auto-cleanup');
      files = AutoCleanupFiles(p.join(temp.path, 'support'));
      sync = SyncFiles(p.join(temp.path, 'support'));
    });

    tearDown(() => temp.delete(recursive: true));

    Future<String> folder(String name) async {
      final directory = Directory(p.join(temp.path, 'library', name));
      await File(p.join(directory.path, '0001.webp')).create(recursive: true);
      return directory.path;
    }

    CleanupItem item(String series, String directory, DateTime due, {String? synced}) =>
        CleanupItem(series: series, chapter: p.basename(directory), directory: directory, due: due, synced: synced);

    CleanupItem remote(String series, String chapter, DateTime due) => CleanupItem(
          series: series,
          chapter: chapter,
          due: due,
          seriesPath: series,
          remote: 'chapters/$chapter',
          synced: '$series/chapters/$chapter',
        );

    test('su Drive toglie per serie, annota per la sincronizzazione e tiene la cartella nel piano', () async {
      await files.writePlan([remote('A', '1', epoch), remote('A', '2', epoch), remote('B', '1', now.add(const Duration(days: 1)))], folder: 'root');
      final calls = <String, List<String>>{};

      final outcome = await runAutoCleanup(files, sync, now: now, withdraw: (series, paths) async => calls[series] = paths);

      expect(calls, {'A': ['chapters/1', 'chapters/2']});
      expect(outcome.fromDrive, {'A': {'1', '2'}});
      expect(await sync.readReleases(), [
        (path: 'A/chapters/1', side: SyncSide.remote),
        (path: 'A/chapters/2', side: SyncSide.remote),
      ]);
      final left = await files.readPlan();
      expect(left.folder, 'root');
      expect([for (final item in left.items) item.series], ['B']);
    });

    test('senza chi toglie da Drive, i capitoli di Drive aspettano', () async {
      await files.writePlan([remote('A', '1', epoch)]);
      final outcome = await runAutoCleanup(files, sync, now: now);
      expect(outcome.removed, isEmpty);
      expect((await files.readPlan()).items, hasLength(1));
    });

    test('senza rete si riprova fra poco, senza permesso no', () async {
      await files.writePlan([remote('A', '1', epoch)]);
      final offline = await runAutoCleanup(files, sync, now: now, withdraw: (_, _) => throw const DriveOffline());
      expect(offline.next, now.add(const Duration(minutes: 30)));
      final denied = await runAutoCleanup(files, sync, now: now, withdraw: (_, _) => throw const DriveAuthRequired());
      expect(denied.next, isNull);
      expect((await files.readPlan()).items, hasLength(1));
    });

    test('toglie ciò che è scaduto, annota le cartelle sincronizzate e dice la prossima scadenza', () async {
      final read = await folder('a/chapters/1');
      final later = await folder('a/chapters/2');
      final private = await folder('b/chapters/1');
      final next = now.add(const Duration(days: 3));
      await files.writePlan([
        item('a', read, epoch, synced: 'a/chapters/1'),
        item('a', later, next, synced: 'a/chapters/2'),
        item('b', private, now),
      ]);

      final outcome = await runAutoCleanup(files, sync, now: now);

      expect(outcome.removed, {'a': {'1'}, 'b': {'1'}});
      expect(outcome.next, next);
      expect(Directory(read).existsSync(), isFalse);
      expect(Directory(private).existsSync(), isFalse);
      expect(Directory(later).existsSync(), isTrue);
      expect(await sync.readReleases(), [(path: 'a/chapters/1', side: SyncSide.local)]);
      expect([for (final left in (await files.readPlan()).items) left.directory], [later]);
    });

    test('le serie aperte nel lettore restano, anche scadute', () async {
      final open = await folder('a/chapters/1');
      await files.writePlan([item('a', open, epoch)]);

      final outcome = await runAutoCleanup(files, sync, now: now, hold: {'a'});

      expect(outcome.removed, isEmpty);
      expect(Directory(open).existsSync(), isTrue);
      expect((await files.readPlan()).items, hasLength(1));
    });

    test('con un giro di sincronizzazione in corso le cartelle sincronizzate aspettano', () async {
      final synced = await folder('a/chapters/1');
      final private = await folder('b/chapters/1');
      await files.writePlan([
        item('a', synced, epoch, synced: 'a/chapters/1'),
        item('b', private, epoch),
      ]);
      await sync.lock.create(recursive: true);

      final outcome = await runAutoCleanup(files, sync, now: now);

      expect(Directory(synced).existsSync(), isTrue);
      expect(Directory(private).existsSync(), isFalse);
      expect(await sync.readReleases(), isEmpty);
      expect(outcome.next, now.add(const Duration(minutes: 30)));
    });

    test('una cartella già sparita esce dal piano', () async {
      await files.writePlan([item('a', p.join(temp.path, 'library', 'nessuna'), epoch)]);
      final outcome = await runAutoCleanup(files, sync, now: now);
      expect(outcome.next, isNull);
      expect((await files.readPlan()).items, isEmpty);
    });
  });

  group('pausa automatica', () {
    final old = now.subtract(const Duration(days: 20));
    final recent = now.subtract(const Duration(days: 2));
    SeriesState reading({DateTime? updatedAt}) => SeriesState(status: ShelfStatus.reading, updatedAt: updatedAt);

    test('scaduta: in lettura, ferma da più dei giorni', () {
      expect(dueForPause(reading(updatedAt: old), old, 14, now), isTrue);
      expect(dueForPause(reading(), old, 14, now), isTrue);
    });

    test('non scatta se non è in lettura, senza attività o troppo presto', () {
      expect(dueForPause(const SeriesState(status: ShelfStatus.paused), old, 14, now), isFalse);
      expect(dueForPause(reading(), null, 14, now), isFalse);
      expect(dueForPause(reading(), recent, 14, now), isFalse);
    });

    test('un gesto recente sulla scheda ne rimanda la pausa', () {
      expect(dueForPause(reading(updatedAt: recent), old, 14, now), isFalse);
    });

    test('pause passa per il JSON e non rende attiva la pulizia', () {
      const settings = AutoCleanupSettings(pause: true, idleDays: 7);
      final back = AutoCleanupSettings.fromJson(settings.toJson());
      expect(back, settings);
      expect(back.pause, isTrue);
      expect(back.active, isFalse);
      expect(AutoCleanupSettings.fromJson(const {}).pause, isFalse);
    });
  });
}
