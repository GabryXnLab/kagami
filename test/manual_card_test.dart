import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/archive/manual_card.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami_archive/stores.dart';

void main() {
  late KagamiDatabase db;
  late ProviderContainer container;
  late Directory root;

  setUp(() async {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await container.read(readingProvider.future);
    root = await Directory.systemTemp.createTemp('kagami-manual');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  test('la scheda con link si riscrive senza doppioni e porta lo stato', () async {
    final store = LocalStore(root.path);
    final reading = container.read(readingProvider.notifier);
    const link = 'https://example.org/serie/solo/';
    final first = await saveManualCard(
      store,
      reading,
      const ManualCard(title: 'Solo', link: link, reached: '52', status: ShelfStatus.reading, rating: 8, favorite: true),
      scratch: Directory('${root.path}/scratch'),
    );
    final again = await saveManualCard(
      store,
      reading,
      const ManualCard(title: 'Solo Leveling', link: 'HTTPS://Example.org/serie/solo', reached: '53'),
      scratch: Directory('${root.path}/scratch'),
    );
    expect(again.key, first.key);
    expect(again.folder, first.folder);
    final rows = await File('${root.path}/reading/downloads.json').readAsString();
    expect('"key"'.allMatches(rows).length, 1);
    final state = container.read(readingProvider).value!.of(first.key);
    expect(state.reachedChapter, '53');
    expect(state.rating, isNull);
    expect(first.row['source'], link);
  });

  test('entryForLink trova la scheda dal link, anche scritto un po\' diverso', () {
    final entry = SeriesEntry(
      key: 'mangak:S1',
      path: 'x',
      title: 'X',
      provider: 'mangak',
      releaseStatus: ReleaseStatus.ongoing,
      chapterCount: 0,
      archivedChapterCount: 0,
      pageCount: 0,
      bytes: 0,
      signature: 's',
      source: 'https://example.org/serie/x/',
    );
    final index = LibraryIndex(generatedAt: null, series: [entry], chapterCount: 0, pageCount: 0, bytes: 0);
    expect(entryForLink(index, 'https://EXAMPLE.org/serie/x'), same(entry));
    expect(entryForLink(index, 'https://example.org/serie/y'), isNull);
  });
}
