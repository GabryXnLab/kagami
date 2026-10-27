// Scaricare man mano: i capitoli chiesti arrivano in libreria anche con la
// schermata «Scarica un manga» chiusa.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/read_ahead.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/tracking.dart';

class _Reading extends Reading {
  @override
  Future<ReadingData> build() async => const ReadingData();
}

/// I giri vanno a tempo (pausa di 2 s, ripasso ogni 100 ms): con la suite
/// intera in parallelo un'attesa fissa a volte non basta.
Future<void> until(bool Function() done) async {
  final limit = DateTime.now().add(const Duration(seconds: 20));
  while (!done() && DateTime.now().isBefore(limit)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  test('i capitoli da tenere pronti si scelgono e restano', () async {
    final database = KagamiDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    ProviderContainer open() => ProviderContainer(overrides: [databaseProvider.overrideWithValue(database)]);
    final first = open();
    expect(await first.read(readAheadWindowProvider.future), readAheadWindow);
    await first.read(readAheadWindowProvider.notifier).change(12);
    first.dispose();
    final second = open();
    addTearDown(second.dispose);
    expect(await second.read(readAheadWindowProvider.future), 12);
  });

  testWidgets('un capitolo finito in coda fa rileggere la libreria da solo', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('kagami-ahead');
      addTearDown(() => dir.delete(recursive: true));
      final files = ArchiveFiles(dir.path);
      await files.directory.create(recursive: true);
      const url = 'https://example.org/manga/a';
      const target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'f');
      await files.ongoing.writeAsString(jsonEncode({
        'schemaVersion': 1,
        'series': [
          TrackedSeries(
            provider: 'example',
            id: 'a',
            title: 'A',
            url: url,
            target: target,
            chapters: const [],
            addedAt: DateTime.utc(2026),
            ahead: 5,
          ).toJson(),
        ],
      }));
      const job = ArchiveJob(id: 'ahead-a', url: url, title: 'A', target: target, ids: {'c1'}, automatic: true, ahead: 5);
      await files.enqueue(job);
      await files.remember(ArchiveOutcome(title: 'A', ok: true, message: '', finishedAt: DateTime.utc(2026, 1, 1)));

      var loads = 0;
      final container = ProviderContainer(overrides: [
        // Lo apre chi tiene le impostazioni (le serie che non si seguono).
        databaseProvider.overrideWith((ref) {
          final database = KagamiDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          return database;
        }),
        archiveFilesProvider.overrideWithValue(files),
        archiveEngineProvider.overrideWithValue(ArchiveEngine.phone),
        readingProvider.overrideWith(_Reading.new),
        libraryCatalogProvider.overrideWith((ref) async {
          loads++;
          return LibraryCatalog.empty;
        }),
        readAheadProvider.overrideWith(() => ReadAhead(followEvery: const Duration(milliseconds: 100))),
      ]);
      addTearDown(container.dispose);
      container.listen(readAheadProvider, (_, _) {});
      await Future<void>.delayed(const Duration(seconds: 3));
      final before = loads;

      // Il giro scarica il capitolo: la coda si svuota, la cronologia cresce.
      await files.remove(job.id);
      await files.remember(ArchiveOutcome(title: 'A', ok: true, message: '', finishedAt: DateTime.utc(2026, 1, 2)));
      await until(() => loads > before);
      expect(loads, greaterThan(before));

      // Un lavoro di più capitoli: il primo pronto si legge già, senza
      // aspettare la fine del lavoro.
      await files.enqueue(const ArchiveJob(
          id: 'ahead-b', url: url, title: 'A', target: target, ids: {'c2', 'c3'}, automatic: true, ahead: 5));
      await files.writeStatus(const ArchiveStatus(state: ArchiveState.running, jobId: 'ahead-b', total: 2));
      await Future<void>.delayed(const Duration(seconds: 3));
      final running = loads;
      await files.writeStatus(const ArchiveStatus(state: ArchiveState.running, jobId: 'ahead-b', total: 2, done: 1));
      await until(() => loads > running);
      expect(loads, greaterThan(running));
    });
  });
}
