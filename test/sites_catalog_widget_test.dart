/// La pagina Siti col catalogo: origine e versione di ogni sito, guasto con il
/// messaggio del manutentore, «serve Kagami più nuovo», la riga di stato e
/// l'interruttore «usa il catalogo», che spento non fa più richieste.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/catalog_config.dart';
import 'package:kagami/src/data/catalog_sync.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/site_replacements.dart';
import 'package:kagami/src/data/user_sites.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/sites_screen.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/providers.dart' as archive show installCatalogProviders, installUserProviders, providers;
import 'package:kagami_archive/stores.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_sites_test.dart' show siteJson;

class _FakeCatalog extends CatalogNotifier {
  _FakeCatalog(this.status);

  final CatalogStatus status;

  @override
  CatalogStatus build() => status;
}

void main() {
  late KagamiDatabase db;
  late Directory root;
  late int requests;
  late CatalogSync sync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('sites_catalog_');
    Directory('${root.path}/providers').createSync();
    requests = 0;
    sync = CatalogSync(
      directory: Directory('${root.path}/catalog'),
      config: CatalogConfig(urls: [Uri.parse('https://catalog.example/')], keys: {'k': (n: BigInt.from(3233), e: BigInt.from(17))}),
      fetch: (url, {ifNoneMatch, required maxBytes}) async {
        requests++;
        throw const SocketException('offline');
      },
    );
    archive.installCatalogProviders([
      DeclarativeProvider.parse(
        jsonEncode(siteJson('catsite', version: 4)),
        catalog: const CatalogSite(id: 'catsite', state: CatalogSiteState.broken, message: 'Il sito ha cambiato pagina', variants: []),
      ),
    ]);
  });

  tearDown(() async {
    archive.installCatalogProviders(const []);
    archive.installUserProviders(const []);
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  Future<ProviderContainer> open(WidgetTester tester, {CatalogStatus? status, CatalogSync? withSync}) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      siteReplacementsProvider.overrideWithValue(SiteReplacements(File('${root.path}/site-replacements.json'))),
      userSitesAccessProvider.overrideWithValue(({required write}) async => (store: LocalStore(root.path), close: () {})),
      siteFetcherProvider.overrideWithValue((url) async => throw const SocketException('offline')),
      userSitesServerSyncProvider.overrideWithValue(() async {}),
      catalogSyncProvider.overrideWithValue(withSync ?? sync),
      if (status != null) catalogProvider.overrideWith(() => _FakeCatalog(status)),
    ]);
    addTearDown(container.dispose);
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
    return container;
  }

  testWidgets('origine, versione, guasto col messaggio e «serve Kagami più nuovo»', (tester) async {
    File('${root.path}/providers/mine.json').writeAsStringSync(jsonEncode(siteJson('mine', version: 2, host: 'mine.example')));
    final built = archive.providers.firstWhere((site) => site.id != 'catsite');
    await open(
      tester,
      status: CatalogStatus(
        serial: 7,
        issuedAt: DateTime.utc(2026, 11, 10, 12),
        lastCheck: DateTime.utc(2026, 11, 14, 8, 30),
        sites: {
          'catsite': const CatalogSiteResult(state: CatalogSiteState.broken, message: 'Il sito ha cambiato pagina'),
          built.id: const CatalogSiteResult(state: CatalogSiteState.ok, problem: CatalogSiteProblem.needsNewerEngine),
        },
      ),
    );

    expect(find.text('Catalogo · versione 4\nFuori uso: Il sito ha cambiato pagina'), findsOneWidget);
    expect(find.text('Incluso\nServe Kagami più nuovo'), findsOneWidget);
    expect(find.text('Tuo · versione 2'), findsOneWidget);
    expect(find.textContaining('Edizione 7 del '), findsOneWidget);
    expect(find.textContaining('Ultimo controllo: '), findsOneWidget);
  });

  testWidgets('senza catalogo configurato non c\'è la riga né l\'interruttore', (tester) async {
    await open(
      tester,
      withSync: CatalogSync(directory: Directory('${root.path}/none'), config: const CatalogConfig()),
    );
    expect(find.text('Usa il catalogo'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('spento, reinstalla un catalogo vuoto e non chiede più; acceso, richiede', (tester) async {
    await open(tester);
    expect(archive.providers.any((site) => site.id == 'catsite'), isTrue);
    expect(find.text('Catalogo · versione 4\nFuori uso: Il sito ha cambiato pagina'), findsOneWidget);
    final before = requests;
    expect(before, greaterThan(0));

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(sync.enabled, isFalse);
    expect((await SharedPreferences.getInstance()).getBool(catalogEnabledKey), isFalse);
    expect(archive.providers.any((site) => site.id == 'catsite'), isFalse);
    expect(find.textContaining('l\'app non chiede niente in rete'), findsOneWidget);
    expect(find.textContaining('versione 4'), findsNothing);
    expect(await sync.refreshedVariant('catsite'), isFalse);
    expect(requests, before);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(sync.enabled, isTrue);
    expect((await SharedPreferences.getInstance()).getBool(catalogEnabledKey), isTrue);
    expect(requests, greaterThan(before));
  });

  testWidgets('lo spegnimento ricordato vale al riavvio: nessuna richiesta', (tester) async {
    SharedPreferences.setMockInitialValues({catalogEnabledKey: false});
    await open(tester);
    expect(sync.enabled, isFalse);
    expect(requests, 0);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
