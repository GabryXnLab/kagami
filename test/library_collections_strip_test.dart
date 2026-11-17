// Le raccolte dentro la libreria: chip sopra la griglia che la filtrano, e il
// segnalibro accanto alla ricerca che apre la pagina per gestirle.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/l10n.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/collections_screen.dart';
import 'package:kagami/src/ui/library_screen.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'collection_auto_test.dart' show signals;

void main() {
  testWidgets('un chip di raccolta filtra la libreria, il segnalibro apre le raccolte', (tester) async {
    final db = KagamiDatabase.forTesting(NativeDatabase.memory());
    final library = [signals('a', title: 'Alfa'), signals('b', title: 'Beta'), signals('c', title: 'Gamma')];
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      libraryProvider.overrideWithValue(Library(const [])),
      libraryCatalogProvider.overrideWith((ref) async => LibraryCatalog.empty),
      libraryIndexProvider.overrideWith((ref) async => LibraryIndex(
            generatedAt: DateTime(2026),
            series: [for (final s in library) s.entry],
            chapterCount: 3,
            pageCount: 0,
            bytes: 0,
          )),
      librarySignalsProvider.overrideWithValue(library),
      collectionsProvider.overrideWithValue(const [
        Collection(id: 'x', name: 'Estate', seriesKeys: ['b']),
      ]),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // La striscia scorre di lato: larga abbastanza da avere tutti i chip.
    tester.view.physicalSize = const Size(3000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: kagamiTheme(Brightness.light),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LibraryScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    List<String> visible() => [for (final s in container.read(visibleLibraryProvider)) s.entry.key];
    expect(visible(), ['a', 'b', 'c']);

    await tester.tap(find.text('Estate (1)'));
    await tester.pump();
    expect(container.read(libraryFilterProvider).collectionId, 'x');
    expect(visible(), ['b']);

    // Ritoccarlo toglie il filtro.
    await tester.tap(find.text('Estate (1)'));
    await tester.pump();
    expect(container.read(libraryFilterProvider).collectionId, isNull);

    await tester.tap(find.byIcon(LucideIcons.bookmark).first);
    await tester.pumpAndSettle();
    expect(find.byType(CollectionsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    // Una raccolta automatica dalla pagina torna alla libreria filtrata.
    final auto = AutoCollection.values.firstWhere((auto) => library.any(auto.matches));
    await tester.tap(find.text(auto.label).last);
    await tester.pumpAndSettle();
    expect(find.byType(CollectionsScreen), findsNothing);
    expect(container.read(libraryFilterProvider).auto, auto);
  });
}
