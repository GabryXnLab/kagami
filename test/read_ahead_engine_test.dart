// «Man mano» con il motore server: le serie di un sito degli utenti che il
// server non sa usare le segue comunque il telefono, le altre restano al server.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/catalog_sync.dart' show CatalogNotifier, CatalogStatus, catalogProvider;
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/user_sites.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart' as archive show installUserProviders;
import 'package:kagami_archive/tracking.dart';

import 'user_sites_test.dart' show siteJson;

class _Reading extends Reading {
  @override
  Future<ReadingData> build() async => const ReadingData();
}

/// Rilegge la libreria quando la cronologia del telefono cambia: è il segno che
/// il giro del telefono ha considerato la serie.
Future<int> _loadsAfterHistoryChange({required bool serverHasUserSites}) async {
  final dir = await Directory.systemTemp.createTemp('kagami-ahead-engine');
  addTearDown(() => dir.delete(recursive: true));
  final files = ArchiveFiles(dir.path);
  await files.directory.create(recursive: true);
  const target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'f');
  await files.ongoing.writeAsString(jsonEncode({
    'schemaVersion': 1,
    'series': [
      TrackedSeries(
        provider: 'examplescans',
        id: 'a',
        title: 'A',
        url: 'https://examplescans.com/manga/a',
        target: target,
        chapters: const [],
        addedAt: DateTime.utc(2026),
        ahead: 5,
      ).toJson(),
    ],
  }));
  await files.remember(ArchiveOutcome(title: 'A', ok: true, message: '', finishedAt: DateTime.utc(2026, 1, 1)));
  // Un lavoro in coda tiene acceso il ripasso, come in read_ahead_follow_test.
  const job = ArchiveJob(
      id: 'ahead-a', url: 'https://examplescans.com/manga/a', title: 'A', target: target, ids: {'c1'}, automatic: true, ahead: 5);
  await files.enqueue(job);

  var loads = 0;
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWith((ref) {
      final database = KagamiDatabase.forTesting(NativeDatabase.memory());
      ref.onDispose(database.close);
      return database;
    }),
    archiveFilesProvider.overrideWithValue(files),
    archiveEngineProvider.overrideWithValue(ArchiveEngine.server),
    catalogProvider.overrideWith(_NoCatalog.new),
    serverSitesProvider.overrideWith((ref) async => (userSites: serverHasUserSites, catalogEngine: null, catalogSerial: null)),
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
  await files.remove(job.id);
  await files.remember(ArchiveOutcome(title: 'A', ok: true, message: '', finishedAt: DateTime.utc(2026, 1, 2)));
  final limit = DateTime.now().add(const Duration(seconds: 8));
  while (loads == before && DateTime.now().isBefore(limit)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return loads - before;
}

/// Il catalogo del telefono, senza avviare la rete né le cartelle dell'app.
class _NoCatalog extends CatalogNotifier {
  @override
  CatalogStatus build() => const CatalogStatus();
}

void main() {
  setUp(() => archive.installUserProviders([DeclarativeProvider.fromJson(siteJson('examplescans'))]));
  tearDown(() => archive.installUserProviders(const []));

  testWidgets('un sito degli utenti che il server non sa usare lo segue il telefono', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() async {
      expect(await _loadsAfterHistoryChange(serverHasUserSites: false), greaterThan(0));
    });
  });

  testWidgets('se il server sa usare i siti degli utenti, resta suo', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() async {
      expect(await _loadsAfterHistoryChange(serverHasUserSites: true), 0);
    });
  });
}
