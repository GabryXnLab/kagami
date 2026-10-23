/// Il foglio che invita a votare: le tre risposte.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami/src/ui/widgets/rating_sheet.dart';
import 'package:kagami/l10n/app_localizations.dart';

void main() {
  late KagamiDatabase db;
  late ProviderContainer container;
  var rated = 0;

  setUp(() {
    rated = 0;
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          theme: kagamiTheme(Brightness.dark),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => offerRating(context, ref, onRate: () async => rated++),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('Vota chiama onRate', (tester) async {
    await open(tester);
    expect(find.text('Che voto gli dai?'), findsOneWidget);
    await tester.tap(find.text('Vota'));
    await tester.pumpAndSettle();
    expect(rated, 1);
    expect(find.text('Che voto gli dai?'), findsNothing);
  });

  testWidgets('Ignora chiude senza spegnere l\'invito', (tester) async {
    await open(tester);
    await tester.tap(find.text('Ignora'));
    await tester.pumpAndSettle();
    expect(rated, 0);
    expect(await container.read(ratingInviteProvider.future), isTrue);
  });

  testWidgets('Non chiedere più spegne l\'invito', (tester) async {
    // Come nella scheda, dove l'invito è già stato letto prima di aprire il foglio.
    await container.read(ratingInviteProvider.future);
    await open(tester);
    await tester.tap(find.text('Non chiedere più'));
    await tester.pumpAndSettle();
    expect(await container.read(ratingInviteProvider.future), isFalse);
  });
}
