/// Le proprietà delle raccolte: regole, caratteristiche, serie automatiche e
/// saltate sopravvivono a JSON e database, e quelle vecchie restano leggibili.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';

void main() {
  const rules = CollectionRules(
    types: {'manhwa'},
    tags: {'Azione', 'Magia'},
    shelf: {ShelfStatus.reading},
    release: {ReleaseStatus.ongoing},
    providers: {'mangak'},
    favorite: true,
    minRating: 8,
  );
  const traits = CollectionTraits(muted: true, keepChapters: true);

  test('regole e caratteristiche tornano uguali dal JSON', () {
    final collection = Collection(
      id: 'c',
      name: 'Auto',
      seriesKeys: const ['a', 'b'],
      rules: rules,
      traits: traits,
      autoKeys: const {'a'},
      skipped: const {'z'},
    );
    final back = Collection.fromJson(collection.toJson());
    expect(back.rules, rules);
    expect(back.rules.hashCode, rules.hashCode);
    expect(back.traits, traits);
    expect(back.autoKeys, {'a'});
    expect(back.skipped, {'z'});
  });

  test('una raccolta senza campi nuovi non li scrive e si legge ancora', () {
    final json = Collection(id: 'c', name: 'N', seriesKeys: const ['a']).toJson();
    for (final key in ['rules', 'traits', 'auto', 'skipped']) {
      expect(json.containsKey(key), isFalse);
    }
    final old = Collection.fromJson({'id': 'c', 'name': 'N', 'series': ['a']});
    expect(old.rules.isEmpty, isTrue);
    expect(old.traits.isEmpty, isTrue);
    expect(old.autoKeys, isEmpty);
    expect(old.skipped, isEmpty);
  });

  test('le caratteristiche si sommano in OR', () {
    const a = CollectionTraits(muted: true);
    const b = CollectionTraits(noAutoPause: true);
    expect(a | b, const CollectionTraits(muted: true, noAutoPause: true));
  });

  group('database e Reading', () {
    late KagamiDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = KagamiDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      await container.read(readingProvider.future);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Reading notifier() => container.read(readingProvider.notifier);
    ReadingData data() => container.read(readingProvider).value!;

    test('il database conserva le proprietà', () async {
      await UserRepository(db).replaceCollections([
        Collection(
          id: 'c',
          name: 'Auto',
          seriesKeys: const ['a'],
          rules: rules,
          traits: traits,
          autoKeys: const {'a'},
          skipped: const {'z'},
        ),
        Collection(id: 'd', name: 'Semplice', seriesKeys: const []),
      ]);
      final back = await UserRepository(db).loadCollections();
      expect(back.first.rules, rules);
      expect(back.first.traits, traits);
      expect(back.first.autoKeys, {'a'});
      expect(back.first.skipped, {'z'});
      expect(back.last.rules.isEmpty, isTrue);
    });

    test('traitsOf unisce quelle delle raccolte che contengono la serie',
        () async {
      await notifier().createCollection('Uno', traits: const CollectionTraits(muted: true));
      await notifier().createCollection('Due', traits: const CollectionTraits(keepChapters: true));
      await notifier().createCollection('Tre', traits: const CollectionTraits(noAutoPause: true));
      final ids = data().collections.map((c) => c.id).toList();
      await notifier().setSeriesInCollection(ids[0], 's', true);
      await notifier().setSeriesInCollection(ids[1], 's', true);
      expect(
        data().traitsOf('s'),
        const CollectionTraits(muted: true, keepChapters: true),
      );
      expect(data().traitsOf('altra').isEmpty, isTrue);
    });

    test('togliere una serie automatica la mette fra le saltate, aggiungerla la rende manuale',
        () async {
      await UserRepository(db).replaceCollections([
        Collection(
          id: 'auto',
          name: 'Auto',
          seriesKeys: const ['a'],
          rules: rules,
          autoKeys: const {'a'},
        ),
      ]);
      container.invalidate(readingProvider);
      await container.read(readingProvider.future);
      const id = 'auto';

      await notifier().setSeriesInCollection(id, 'a', false);
      var c = data().collections.single;
      expect(c.seriesKeys, isEmpty);
      expect(c.autoKeys, isEmpty);
      expect(c.skipped, {'a'});

      await notifier().setSeriesInCollection(id, 'a', true);
      c = data().collections.single;
      expect(c.seriesKeys, ['a']);
      expect(c.autoKeys, isEmpty);
      expect(c.skipped, isEmpty);

      await notifier().setSeriesInCollection(id, 'a', false);
      expect(data().collections.single.skipped, isEmpty);
    });
  });
}
