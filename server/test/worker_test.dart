import 'dart:async';
import 'dart:io';

import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late ArchiveFiles files;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kagami-worker-');
    files = ArchiveFiles(dir.path);
  });
  tearDown(() => dir.delete(recursive: true));

  ArchiveEnvironment environment() => ArchiveEnvironment(
        scratch: Directory(p.join(dir.path, 'scratch')),
        storeFor: (_) => LocalStore(p.join(dir.path, 'libreria')),
      );

  ArchiveJob job(String id, String url) => ArchiveJob(
        id: id,
        url: url,
        title: id,
        target: const ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'f'),
      );

  Future<void> until(Future<bool> Function() condition) async {
    for (var i = 0; i < 200; i++) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('la condizione non si è avverata');
  }

  test('il giro prende quello che arriva mentre dorme, e la coda si svuota', () async {
    final worker = ServerWorker(files, environment(), blocked: () async => null, log: (_) {});
    worker.start();
    await files.enqueue(job('uno', 'https://example.com/non-un-sito'));
    worker.wake();
    // L'esito si scrive dopo aver tolto il lavoro dalla coda: si aspetta lui.
    await until(() async => (await files.history()).isNotEmpty);
    expect(await files.jobs(), isEmpty);
    final outcome = (await files.history()).single;
    expect(outcome.ok, isFalse);
    expect(outcome.message, contains('Link non supportato'));

    // Arrivato dopo, a giro addormentato.
    await files.enqueue(job('due', 'https://example.com/altro'));
    worker.wake();
    await until(() async => (await files.history()).length == 2);
    await worker.close();
  });

  test('con Drive non pronto i lavori restano in coda, e lo stato dice perché', () async {
    await files.enqueue(job('uno', 'https://example.com/x'));
    final worker = ServerWorker(
      files,
      environment(),
      blocked: () async => 'Manca la cartella della libreria.',
      retryAfter: const Duration(milliseconds: 50),
      log: (_) {},
    );
    worker.start();
    await until(() async => (await files.status()).state == ArchiveState.waiting);
    expect((await files.status()).message, 'Manca la cartella della libreria.');
    expect(await files.jobs(), hasLength(1));
    await worker.close();
  });

  test('il controllo quotidiano: ora da config.json, poi quella scelta dall\'app, e com\'è andato', () async {
    final worker = ServerWorker(files, environment(), blocked: () async => null, checkMinutes: 300,
        folder: () => 'f', log: (_) {});
    expect(((await worker.checkSettings()).enabled, (await worker.checkSettings()).minutes), (true, 300));
    await worker.configureCheck(minutes: 60, library: false);
    final again = ServerWorker(files, environment(), blocked: () async => null, log: (_) {});
    final settings = await again.checkSettings();
    expect((settings.enabled, settings.minutes, settings.library), (true, 60, false));
    await worker.configureCheck(library: true);
    // La libreria è vuota: niente in coda, ma il controllo resta annotato.
    await worker.checkNow();
    expect((await worker.checkSettings()).checkedAt, isNotNull);
    expect(await files.jobs(), isEmpty);
    await worker.close();
    expect((await ServerWorker(files, environment(), blocked: () async => null).checkSettings()).minutes, 60);
  });

  test('spento in config.json (check.minutes null), il controllo parte spento', () async {
    final worker = ServerWorker(files, environment(), blocked: () async => null, log: (_) {});
    expect((await worker.checkSettings()).enabled, isFalse);
  });

  test('un lavoro in attesa si toglie dalla coda', () async {
    final worker = ServerWorker(files, environment(), blocked: () async => 'fermo', log: (_) {});
    await files.enqueue(job('uno', 'https://example.com/x'));
    await worker.cancel('uno');
    expect(await files.jobs(), isEmpty);
  });
}
