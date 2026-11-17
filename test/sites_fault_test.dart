/// Il guasto di un sito: nella prova prima dell'installazione la pagina Siti mostra fase e campo,
/// e su Sentry vanno solo fase e campo (mai `detail` né l'indirizzo).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/catalog_config.dart';
import 'package:kagami/src/data/catalog_recheck.dart';
import 'package:kagami/src/data/catalog_sync.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/site_replacements.dart';
import 'package:kagami/src/data/user_sites.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/sites_screen.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart' as archive show installUserProviders;
import 'package:kagami_archive/stores.dart';

import 'user_sites_test.dart' show siteJson;

class _EmptyPage implements ProviderHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async =>
      (body: Uint8List.fromList(utf8.encode('<html><body><p>niente</p></body></html>')), contentType: 'text/html');

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => {};
}

void main() {
  test('i tag Sentry hanno fase e campo, mai detail né url', () {
    final error = ProviderChanged('x',
        fault: SiteFault('series', field: 'series.title', detail: 'ricerca privata', url: 'https://a.com/?s=privato'));
    expect(sentryTags(error, 'a', '3'), {'site': 'a', 'version': '3', 'phase': 'series', 'field': 'series.title'});
    expect(sentryTags(ProviderChanged('x'), 'a', '3'), {'site': 'a', 'version': '3'});
  });

  testWidgets('la prova di un sito rotto mostra fase e campo', (tester) async {
    final db = KagamiDatabase.forTesting(NativeDatabase.memory());
    final root = Directory.systemTemp.createTempSync('sites_fault_');
    Directory('${root.path}/providers').createSync();
    addTearDown(() async {
      archive.installUserProviders(const []);
      await db.close();
      root.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      siteReplacementsProvider.overrideWithValue(SiteReplacements(File('${root.path}/site-replacements.json'))),
      userSitesAccessProvider.overrideWithValue(({required write}) async => (store: LocalStore(root.path), close: () {})),
      userSitesServerSyncProvider.overrideWithValue(() async {}),
      catalogSyncProvider.overrideWithValue(CatalogSync(directory: Directory('${root.path}/catalog'), config: const CatalogConfig())),
      siteProbeHttpProvider.overrideWithValue((site) => _EmptyPage()),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(userSitesProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        theme: kagamiTheme(Brightness.dark),
        home: const AddSitePage(),
      ),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    await tester.enterText(find.byKey(const Key('siteSource')), jsonEncode(siteJson('examplescans')));
    await tester.tap(find.text('Controlla'));
    await settle();
    await tester.enterText(find.byKey(const Key('siteProbe')), 'https://examplescans.com/manga/foo');
    await tester.tap(find.text('Prova'));
    await settle();

    expect(find.text('La prova non è riuscita'), findsOneWidget);
    expect(find.textContaining('Fase: series · campo: series.title'), findsOneWidget);
  });
}
