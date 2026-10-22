// La raccolta in cui mettere una serie scaricata: la propone la pagina
// della serie, l'ultima scelta resta fra le impostazioni.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/archive_series.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami_archive/model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const Series _series = Series(
  provider: 'manhwaread',
  id: 'solo',
  title: 'Solo',
  url: 'https://manhwaread.com/manhwa/solo/',
  coverUrl: null,
  metadata: {},
  chapters: [Chapter('c1', 'Chapter 1', '1', 'https://manhwaread.com/manhwa/solo/c1/')],
);

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

  test("l'ultima raccolta scelta sopravvive all'app, e «nessuna» è una scelta", () async {
    expect(await container.read(archiveCollectionProvider.future), isNull);
    await container.read(archiveCollectionProvider.notifier).choose('c-1');
    final again = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(again.dispose);
    expect(await again.read(archiveCollectionProvider.future), 'c-1');
    await again.read(archiveCollectionProvider.notifier).choose(null);
    final third = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(third.dispose);
    expect(await third.read(archiveCollectionProvider.future), isNull);
  });

  testWidgets('la pagina della serie propone la raccolta e la mette nella scelta', (tester) async {
    await tester.runAsync(() => container.read(readingProvider.notifier).createCollection('Da leggere'));
    final id = container.read(collectionsProvider).single.id;
    ArchiveChoice? choice;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: kagamiTheme(Brightness.light),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => choice = await ArchiveSeriesPage.open(
              context,
              series: _series,
              metadata: normalizeMetadata(_series.metadata),
              destinations: const [ArchiveWhere.phone],
              destination: ArchiveWhere.phone,
              delayMs: 200,
              serverHint: '',
              collection: id,
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    // La voce sta in fondo alla pagina, sotto la testata della serie.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.text('Da leggere'), findsOneWidget);

    await tester.tap(find.text('Da leggere'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nessuna raccolta'));
    await tester.pumpAndSettle();
    expect(find.text('Da leggere'), findsNothing);

    await tester.tap(find.text('Nessuna raccolta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Da leggere').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.download).last);
    await tester.pumpAndSettle();
    expect(choice?.collection, id);
  });
}
