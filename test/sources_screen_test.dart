/// La schermata Sorgenti, la prova di connessione, il ramo WebDAV delle
/// sorgenti e la rimozione che non tocca lo stato di lettura.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/data/sources/webdav_source.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_sources.dart';
import 'package:kagami/src/ui/sources_screen.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami/src/ui/widgets/kit.dart';
import 'package:kagami_archive/transport.dart';

import 'path_shelf_test.dart' show FakeTransport;
import 'sources_test.dart' show webdav;

void main() {
  late KagamiDatabase db;
  late Directory temp;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('kagami-sources-screen');
  });
  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  ProviderContainer container() {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appDirectoriesProvider.overrideWithValue(
        AppDirectories(support: '${temp.path}/support', cache: '${temp.path}/cache'),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('prova di connessione', () {
    final library = jsonEncode({
      'series': [
        {'key': 'a', 'title': 'A'},
        {'key': 'b', 'title': 'B'},
      ],
    });

    test('riuscita: conta le serie di library.json nella cartella', () async {
      final transport = FakeTransport()..put('manga/library.json', library);
      final result = await probeWebDav(transport, '/manga/');
      expect(result, isA<WebDavProbeOk>().having((r) => r.series, 'series', 2));
    });

    test('senza library.json, o con altro, è «nessuna libreria»', () async {
      final transport = FakeTransport()..put('manga/altro.txt', 'x');
      expect(await probeWebDav(transport, 'manga'), isA<WebDavProbeNoLibrary>());
      transport.put('manga/library.json', 'non json');
      expect(await probeWebDav(transport, 'manga'), isA<WebDavProbeNoLibrary>());
    });

    test('credenziali rifiutate e server che non risponde sono esiti distinti', () async {
      final transport = FakeTransport()..failure = const TransportAuthRequired(status: 401);
      expect(await probeWebDav(transport, ''), isA<WebDavProbeAuth>());
      transport.failure = const TransportOffline();
      expect(await probeWebDav(transport, ''), isA<WebDavProbeUnreachable>());
    });
  });

  group('sorgente WebDAV', () {
    test('senza password è da ricollegare, e senza chiedere niente al server', () async {
      final c = container();
      await c.read(librarySourcesProvider.future);
      await c.read(librarySourcesProvider.notifier).add(webdav('s-0000000a'));
      final source = c.read(storageSourcesProvider).sources.singleWhere((s) => s.config.id == 's-0000000a');
      expect(source.files, isNotNull);
      await expectLater(
        source.shelf.loadLibrary(),
        throwsA(isA<SourceUnavailable>().having((e) => e.state, 'state', SourceState.needsAuth)),
      );
    });

    test('rimuoverla toglie segreto, stato e cache, mai lo stato di lettura', () async {
      final c = container();
      await c.read(librarySourcesProvider.future);
      await c.read(librarySourcesProvider.notifier).add(webdav('s-0000000a'));
      await c.read(sourceSecretsProvider).write('s-0000000a', 'segreto');
      final state = Directory('${temp.path}/support/sources/s-0000000a/text')..createSync(recursive: true);
      final cache = Directory('${temp.path}/cache/sources/s-0000000a')..createSync(recursive: true);
      final reading = File('${temp.path}/support/reading/downloads.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');

      await c.read(librarySourcesProvider.notifier).remove('s-0000000a');

      expect(await c.read(sourceSecretsProvider).read('s-0000000a'), isNull);
      expect(state.existsSync(), isFalse);
      expect(cache.existsSync(), isFalse);
      expect(reading.existsSync(), isTrue);
    });
  });

  group('sorgente SMB', () {
    SourceConfig smb(String id, {String host = '192.168.1.10', bool seal = false, String user = 'lettore'}) =>
        SourceConfig(
          id: id,
          kind: SourceKind.smb,
          label: 'NAS $id',
          params: {'host': host, 'share': 'manga', 'folder': 'libreria', 'user': user, 'domain': '', 'seal': seal},
        );

    test('senza password è da ricollegare, e senza aprire connessioni', () async {
      final c = container();
      await c.read(librarySourcesProvider.future);
      await c.read(librarySourcesProvider.notifier).add(smb('s-0000000b'));
      final source = c.read(storageSourcesProvider).sources.singleWhere((s) => s.config.id == 's-0000000b');
      expect(source.files, isNotNull);
      await expectLater(
        source.shelf.loadLibrary(),
        throwsA(isA<SourceUnavailable>().having((e) => e.state, 'state', SourceState.needsAuth)),
      );
    });

    test('host pubblico senza cifratura: la sorgente non c\'è, con l\'avviso', () async {
      final c = container();
      await c.read(librarySourcesProvider.future);
      await c.read(librarySourcesProvider.notifier).add(smb('s-0000000c', host: 'nas.example.com'));
      final sources = c.read(storageSourcesProvider);
      expect(sources.sources.where((s) => s.config.id == 's-0000000c'), isEmpty);
      expect(sources.notices.whereType<SourceUnavailable>().map((n) => n.sourceId), contains('s-0000000c'));
      // Con la cifratura la stessa riga è una sorgente.
      await c.read(librarySourcesProvider.notifier).add(smb('s-0000000d', host: 'nas.example.com', seal: true));
      expect(c.read(storageSourcesProvider).sources.any((s) => s.config.id == 's-0000000d'), isTrue);
    });
  });

  Future<void> open(WidgetTester tester, ProviderContainer c) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => c.read(librarySourcesProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        theme: kagamiTheme(Brightness.dark),
        home: const SourcesScreen(),
      ),
    ));
    await tester.pump();
  }

  testWidgets('elenca le sorgenti con il loro stato', (tester) async {
    final c = container();
    await c.read(librarySourcesProvider.future);
    await c.read(librarySourcesProvider.notifier).add(webdav('s-0000000a'));
    await c.read(librarySourcesProvider.notifier).add(SourceConfig(
          id: 's-0000000e',
          kind: SourceKind.smb,
          label: 'Server',
          params: const {'host': '192.168.1.10', 'share': 'manga'},
        ));
    await open(tester, c);
    expect(find.text('SMB · 192.168.1.10'), findsOneWidget);

    expect(find.text('Sorgenti'), findsOneWidget);
    expect(find.text("Spazio dell'app"), findsOneWidget);
    expect(find.text('NAS s-0000000a'), findsOneWidget);
    expect(find.text('WebDAV / NAS · nas.example.com'), findsOneWidget);
    expect(find.text('Sola lettura'), findsNWidgets(2));
  });

  testWidgets('Aggiungi: spento prima della prova; http pubblico avvisa', (tester) async {
    final c = container();
    await open(tester, c);
    await tester.tap(find.text('Aggiungi sorgente'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'http://nas.example.com/dav');
    await tester.pump();
    expect(find.textContaining('Indirizzo HTTP pubblico non sicuro'), findsOneWidget);
    expect(find.textContaining('In arrivo'), findsNothing);
    final add = find.ancestor(of: find.text('Aggiungi sorgente').last, matching: find.byType(KButton));
    expect(tester.widget<KButton>(add).onPressed, isNull);
  });

  testWidgets('Aggiungi: il segmento SMB ha i suoi campi; host pubblico in chiaro è un errore', (tester) async {
    final c = container();
    await open(tester, c);
    await tester.tap(find.text('Aggiungi sorgente'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SMB'));
    await tester.pumpAndSettle();
    expect(find.text('Condivisione (es. manga)'), findsOneWidget);
    expect(find.text('Dominio (facoltativo)'), findsOneWidget);
    expect(find.text('Cifratura (SMB 3)'), findsOneWidget);
    expect(find.text('https://nas.example.com/webdav'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '192.168.1.10');
    await tester.pump();
    expect(find.textContaining('Senza cifratura password e file viaggiano in chiaro'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'nas.example.com');
    await tester.pump();
    expect(find.textContaining('In chiaro solo verso la rete di casa'), findsOneWidget);
    final add = find.ancestor(of: find.text('Aggiungi sorgente').last, matching: find.byType(KButton));
    expect(tester.widget<KButton>(add).onPressed, isNull);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.textContaining('In chiaro solo verso la rete di casa'), findsNothing);
  });
}
