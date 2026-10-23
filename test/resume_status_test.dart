/// Leggere riporta «in lettura» una serie in pausa, abbandonata o da leggere.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';

void main() {
  late KagamiDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await container.read(readingProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  for (final (from, to) in [
    (ShelfStatus.none, ShelfStatus.reading),
    (ShelfStatus.planned, ShelfStatus.reading),
    (ShelfStatus.paused, ShelfStatus.reading),
    (ShelfStatus.dropped, ShelfStatus.reading),
    (ShelfStatus.completed, ShelfStatus.completed),
  ]) {
    test('saveProgress da $from porta a $to', () async {
      final reading = container.read(readingProvider.notifier);
      await reading.setStatus('k', from);
      await reading.saveProgress('k', chapterId: 'c1', page: 1, pageCount: 10);
      expect(container.read(readingProvider).value!.of('k').status, to);
    });
  }

  test('noteProgress da pausa riporta in lettura', () async {
    final reading = container.read(readingProvider.notifier);
    await reading.setStatus('k', ShelfStatus.paused);
    await reading.noteProgress('k', chapterId: 'c1', page: 1, offset: 0, pageCount: 10);
    await reading.saveProgress('k', chapterId: 'c1', page: 2, pageCount: 10);
    expect(container.read(readingProvider).value!.of('k').status, ShelfStatus.reading);
  });
}
