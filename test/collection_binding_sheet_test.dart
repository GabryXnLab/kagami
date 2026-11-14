/// Il foglio delle proprietà e le raccolte vincolanti: l'interruttore, il
/// conto delle serie che uscirebbero e le famiglie di tipo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami/src/ui/widgets/collection_properties_sheet.dart';
import 'package:kagami/src/ui/widgets/kit.dart';

import 'collection_auto_test.dart' show signals;
import 'collection_properties_sheet_test.dart' show entry;

void main() {
  Future<void> open(
    WidgetTester tester, {
    CollectionRules rules = const CollectionRules(),
    List<SeriesSignals> members = const [],
    LibraryFacets? facets,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        theme: kagamiTheme(Brightness.dark),
        home: Scaffold(
          body: CollectionPropertiesForm(
            facets: facets ?? LibraryFacets.of(const []),
            rules: rules,
            traits: const CollectionTraits(),
            members: members,
          ),
        ),
      ),
    );
  }

  Switch bindingSwitch(WidgetTester tester) => tester.widget<Switch>(
        find.descendant(
          of: find.ancestor(of: find.text('Vincolante'), matching: find.byType(KTile)),
          matching: find.byType(Switch),
        ),
      );

  testWidgets('l\'interruttore è disattivato finché non c\'è un criterio', (tester) async {
    await open(tester);
    expect(bindingSwitch(tester).onChanged, isNull);
    expect(bindingSwitch(tester).value, isFalse);

    await tester.tap(find.text('Manhwa').first);
    await tester.pumpAndSettle();
    expect(bindingSwitch(tester).onChanged, isNotNull);
  });

  testWidgets('accendendolo dice quante serie usciranno', (tester) async {
    await open(
      tester,
      rules: const CollectionRules(types: {'manhwa'}),
      members: [
        signals('a', type: 'Manhwa'),
        signals('b', type: 'Manga'),
        signals('c'),
      ],
    );
    expect(find.textContaining('usciranno'), findsNothing);
    await tester.ensureVisible(find.text('Vincolante'));
    await tester.tap(find.text('Vincolante'));
    await tester.pumpAndSettle();
    expect(bindingSwitch(tester).value, isTrue);
    expect(find.textContaining('2 serie che non rientrano'), findsOneWidget);
  });

  testWidgets('le quattro famiglie ci sono sempre, poi i tipi che non lo sono', (tester) async {
    await open(
      tester,
      facets: LibraryFacets.of([entry('a', type: 'manhwa'), entry('b', type: 'Novel')]),
    );
    for (final label in ['Manga', 'Manhwa', 'Manhua', 'Altro', 'novel']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // «manhwa» è una famiglia: non compare una seconda volta in minuscolo.
    expect(find.text('manhwa'), findsNothing);
  });
}
