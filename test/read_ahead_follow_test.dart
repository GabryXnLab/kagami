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
import 'package:kagami/src/providers.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/tracking.dart';

class _Reading extends Reading {
  @override
  Future<ReadingData> build() async => const ReadingData();
}

void main() {
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
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(loads, greaterThan(before));
    });
  });
}
