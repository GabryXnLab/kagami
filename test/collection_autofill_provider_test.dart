/// L'autoinserimento a tempo, con i provider veri: aspettato il catalogo, una
/// serie comparsa dopo entra da sola nella raccolta con regole; prima che il
/// catalogo sia letto non si tocca niente.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';

SeriesEntry entry(String key, {String? type}) => SeriesEntry(
      key: key,
      path: key,
      title: key,
      provider: 'mangak',
      releaseStatus: ReleaseStatus.ongoing,
      chapterCount: 1,
      archivedChapterCount: 1,
      pageCount: 0,
      bytes: 0,
      signature: 'x',
      type: type,
    );

LibraryIndex index(List<SeriesEntry> series) => LibraryIndex(
      generatedAt: null,
      series: series,
      chapterCount: series.length,
      pageCount: 0,
      bytes: 0,
    );

/// I giri dell'autoinserimento partono un secondo dopo il cambiamento: si
/// aspetta la condizione, non un tempo fisso.
Future<void> until(bool Function() done, {Duration limit = const Duration(seconds: 2)}) async {
  final end = DateTime.now().add(limit);
  while (!done() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  late KagamiDatabase db;
  late Completer<LibraryIndex> catalog;
  late ProviderContainer container;

  setUp(() async {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    catalog = Completer<LibraryIndex>();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        libraryIndexProvider.overrideWith((ref) => catalog.future),
      ],
    );
    await container.read(readingProvider.future);
    container.listen(collectionAutoFillProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Collection collection() => container.read(readingProvider).value!.collections.single;

  test('una serie comparsa dopo entra fra le automatiche entro due secondi', () async {
    await container
        .read(readingProvider.notifier)
        .createCollection('Manhwa', rules: const CollectionRules(types: {'manhwa'}));
    expect(collection().autoKeys, isEmpty);

    // Il catalogo arriva dopo la raccolta, e solo ora contiene la serie.
    catalog.complete(index([entry('altra', type: 'Manga'), entry('nuova', type: 'Manhwa')]));
    await until(() => collection().autoKeys.contains('nuova'));

    final c = collection();
    expect(c.autoKeys, {'nuova'});
    expect(c.seriesKeys, ['nuova']);
  });

  test('con il catalogo non ancora letto non cambia niente', () async {
    await container
        .read(readingProvider.notifier)
        .createCollection('Manhwa', rules: const CollectionRules(types: {'manhwa'}));
    // Il catalogo resta in caricamento: il giro deve fermarsi invece di
    // scambiare «non so» per «non c'è».
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final c = collection();
    expect(c.seriesKeys, isEmpty);
    expect(c.autoKeys, isEmpty);
    expect(c.skipped, isEmpty);
    expect(container.read(libraryIndexProvider).value, isNull);
  });
}
