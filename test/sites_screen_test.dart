/// La pagina Siti: l'elenco con un sito aggiunto e uno rovinato, l'aggiunta da
/// testo incollato con l'anteprima degli host, e l'errore di un testo non valido.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/site_replacements.dart';
import 'package:kagami/src/data/user_sites.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/sites_screen.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami_archive/providers.dart' as archive show installUserProviders;
import 'package:kagami_archive/stores.dart';

import 'user_sites_test.dart' show siteJson;

void main() {
  late KagamiDatabase db;
  late Directory root;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('sites_screen_');
    Directory('${root.path}/providers').createSync();
  });

  tearDown(() async {
    archive.installUserProviders(const []);
    await db.close();
    root.deleteSync(recursive: true);
  });

  File file(String id) => File('${root.path}/providers/$id.json');

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      siteReplacementsProvider.overrideWithValue(SiteReplacements(File('${root.path}/site-replacements.json'))),
      userSitesAccessProvider.overrideWithValue(({required write}) async => (store: LocalStore(root.path), close: () {})),
      siteFetcherProvider.overrideWithValue((url) async => throw const SocketException('offline')),
      userSitesServerSyncProvider.overrideWithValue(() async {}),
    ]);
    addTearDown(container.dispose);
    // La lettura iniziale usa timer veri: va fatta fuori dal tempo finto.
    await tester.runAsync(() => container.read(userSitesProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          theme: kagamiTheme(Brightness.dark),
          home: const SitesScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('elenca i siti aggiunti e segna il file rovinato', (tester) async {
    file('examplescans').writeAsStringSync(jsonEncode(siteJson('examplescans', version: 3)));
    file('bad').writeAsStringSync('non è json');
    await open(tester);

    expect(find.text('Example examplescans'), findsOneWidget);
    expect(find.text('versione 3'), findsOneWidget);
    expect(find.text('bad'), findsOneWidget);
    expect(find.text('File rovinato'), findsOneWidget);
  });

  testWidgets('testo incollato: anteprima con gli host, poi installa', (tester) async {
    await open(tester);
    await tester.tap(find.text('Aggiungi un sito'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('siteSource')), jsonEncode(siteJson('examplescans')));
    await tester.tap(find.text('Controlla'));
    await settle(tester);

    expect(find.text('Example examplescans'), findsOneWidget);
    expect(find.text('examplescans.com'), findsOneWidget);
    expect(find.textContaining('Sostituisce'), findsNothing);

    await tester.ensureVisible(find.text('Installa'));
    await tester.tap(find.text('Installa'));
    // La scrittura è I/O vero e il suo seguito gira nella zona finta: si alternano attesa e pump
    // finché il file c'è, invece di un numero fisso di giri. Il foglio poi si chiude con
    // un'animazione di rotta, che avanza solo col tempo finto di pumpAndSettle.
    for (var i = 0; i < 400 && !file('examplescans').existsSync(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    await settle(tester);
    await tester.pumpAndSettle();

    expect(file('examplescans').existsSync(), isTrue);
    expect(find.text('Example examplescans'), findsOneWidget);
    expect(find.text('Aggiungi un sito'), findsOneWidget);
  });

  testWidgets('un id incluso nell\'app dice quale sito sostituisce', (tester) async {
    await open(tester);
    await tester.tap(find.text('Aggiungi un sito'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('siteSource')), jsonEncode(siteJson('coffeemanga')));
    await tester.tap(find.text('Controlla'));
    await settle(tester);

    expect(find.textContaining('Sostituisce'), findsOneWidget);
  });

  testWidgets('un testo non valido mostra l\'errore generico e quello tecnico', (tester) async {
    await open(tester);
    await tester.tap(find.text('Aggiungi un sito'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('siteSource')), 'questo non è un sito');
    await tester.tap(find.text('Controlla'));
    await settle(tester);

    expect(find.text('Il file non è valido'), findsOneWidget);
    expect(find.text('Installa'), findsNothing);
  });
}
