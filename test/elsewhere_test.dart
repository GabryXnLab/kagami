// «Su altri siti»: quanto un sito è avanti, la copia in cache (dato vecchio:
// nuova richiesta; errore: resta la copia), la scelta fra server e telefono e
// le righe della sezione (il pulsante solo su quelle trovate).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/elsewhere.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/elsewhere_section.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami_archive/elsewhere.dart';
import 'package:kagami_archive/model.dart' show ProviderError;
import 'package:kagami_archive/providers.dart' show providers;
import 'package:kagami_archive/remote.dart';

ChapterEntry _chapter(String? number) => ChapterEntry(
      id: 'c$number',
      order: 0,
      archived: true,
      complete: true,
      pageCount: 1,
      bytes: 1,
      number: number,
    );

Elsewhere _seen(String key, DateTime at, [Map<String, SiteCopy> sites = const {}]) =>
    Elsewhere(key: key, checkedAt: at, sites: sites);

void main() {
  group('chaptersAhead', () {
    test('confronta il numero dell\'ultimo capitolo con il più alto dell\'indice', () {
      final mine = [_chapter('1'), _chapter('12'), _chapter('3')];
      expect(chaptersAhead('15', mine), 3);
      expect(chaptersAhead('10', mine), -2);
      expect(chaptersAhead('12', mine), 0);
    });

    test('ignora i capitoli non numerici; senza numeri da una parte non c\'è risposta', () {
      expect(chaptersAhead('5', [_chapter('Extra'), _chapter(null), _chapter('4')]), 1);
      expect(chaptersAhead('5', [_chapter('Extra')]), isNull);
      expect(chaptersAhead(null, [_chapter('4')]), isNull);
      expect(chaptersAhead('final', [_chapter('4')]), isNull);
    });
  });

  group('resolveElsewhere', () {
    late Directory dir;
    late ElsewhereLog log;
    final now = DateTime.utc(2026, 10, 28, 12);

    setUp(() {
      dir = Directory.systemTemp.createTempSync('elsewhere');
      log = ElsewhereLog(File('${dir.path}/elsewhere.json'));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('un dato recente non rifà la richiesta', () async {
      final cached = _seen('a:1', now.subtract(const Duration(hours: 2)));
      var calls = 0;
      final result = await resolveElsewhere(
        cached: cached,
        log: log,
        clock: () => now,
        lookup: (_) async {
          calls++;
          return null;
        },
      );
      expect(result, same(cached));
      expect(calls, 0);
    });

    test('un dato vecchio o assente rifà la richiesta e scrive il nuovo nel file', () async {
      final old = _seen('a:1', now.subtract(elsewhereAgain + const Duration(minutes: 1)));
      final fresh = _seen('a:1', now);
      Elsewhere? asked;
      final result = await resolveElsewhere(
        cached: old,
        log: log,
        clock: () => now,
        lookup: (previous) async {
          asked = previous;
          return fresh;
        },
      );
      expect(result, same(fresh));
      expect(asked, same(old));
      expect((await log.load())['a:1']?.checkedAt, now);
      expect(await resolveElsewhere(cached: null, log: log, clock: () => now, lookup: (_) async => fresh), same(fresh));
    });

    test('un errore lascia la copia, mai il vuoto', () async {
      final old = _seen('a:1', now.subtract(const Duration(days: 3)));
      for (final error in <Object>[
        const ProviderError('rotto'),
        const ServerException('spento'),
        const SocketException('niente rete'),
      ]) {
        final result = await resolveElsewhere(cached: old, log: log, clock: () => now, lookup: (_) async => throw error);
        expect(result, same(old));
      }
      expect(await log.load(), isEmpty);
    });
  });

  group('lookViaServer', () {
    test('rilegge finché il risultato è più recente del precedente', () async {
      final t0 = DateTime.utc(2026, 10, 27);
      final previous = _seen('a:1', t0);
      final fresh = _seen('a:1', t0.add(const Duration(days: 1)));
      var reads = 0, looks = 0;
      final result = await lookViaServer(
        key: 'a:1',
        previous: previous,
        wait: Duration.zero,
        look: () async => looks++,
        read: () async => ++reads < 3 ? previous : fresh,
      );
      expect(result, same(fresh));
      expect(looks, 1);
      expect(reads, 3);
    });

    test('scaduti i tentativi non inventa niente', () async {
      final previous = _seen('a:1', DateTime.utc(2026, 10, 27));
      var reads = 0;
      final result = await lookViaServer(
        key: 'a:1',
        previous: previous,
        attempts: 3,
        wait: Duration.zero,
        look: () async {},
        read: () async {
          reads++;
          return previous;
        },
      );
      expect(result, isNull);
      expect(reads, 3);
    });
  });

  group('scelta fra server e telefono', () {
    late Directory dir;
    late List<String> calls;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('elsewhere');
      calls = [];
    });
    tearDown(() => dir.deleteSync(recursive: true));

    ProviderContainer container({ServerLink? server}) {
      final fresh = _seen('a:1', DateTime.now());
      final result = ProviderContainer(overrides: [
        appDirectoriesProvider.overrideWithValue(AppDirectories(support: dir.path, cache: dir.path)),
        elsewhereServerProvider.overrideWith((ref) async => server),
        serverElsewhereProvider.overrideWithValue((target, previous) async {
          calls.add('server');
          return fresh;
        }),
        phoneElsewhereProvider.overrideWithValue((target, previous) async {
          calls.add('phone');
          return fresh;
        }),
      ]);
      addTearDown(result.dispose);
      return result;
    }

    Future<ElsewhereView> settled(ProviderContainer container) async {
      const target = ElsewhereTarget('a:1', ['Titolo']);
      container.listen(elsewhereProvider(target), (_, _) {});
      await container.read(elsewhereProvider(target).future);
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (!container.read(elsewhereProvider(target)).requireValue.busy) break;
      }
      return container.read(elsewhereProvider(target)).requireValue;
    }

    test('senza server cerca il telefono', () async {
      final view = await settled(container());
      expect(calls, ['phone']);
      expect(view.busy, isFalse);
      expect(view.data, isNotNull);
    });

    test('con un server che sa cercare, il server', () async {
      await settled(container(server: ServerLink(Uri.parse('http://server.test'))));
      expect(calls, ['server']);
    });

    test('la copia recente si mostra subito e non cerca nessuno', () async {
      final log = ElsewhereLog(File('${dir.path}/elsewhere.json'));
      await log.put(_seen('a:1', DateTime.now()));
      final view = await settled(container());
      expect(calls, isEmpty);
      expect(view.data, isNotNull);
    });
  });

  group('righe della sezione', () {
    final now = DateTime.utc(2026, 10, 28);
    final ids = [for (final provider in providers.take(4)) provider.id];

    Widget host(Elsewhere? data, List<String> opened, {bool busy = false}) => MaterialApp(
          theme: kagamiTheme(Brightness.light),
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ElsewhereRows(
                data: data,
                busy: busy,
                chapters: [_chapter('10'), _chapter('12')],
                onSwitch: opened.add,
              ),
            ),
          ),
        );

    testWidgets('il pulsante è solo sulle righe trovate, con avanti e indietro', (tester) async {
      final opened = <String>[];
      final data = _seen('x:1', now, {
        ids[0]: SiteCopy(
          provider: ids[0],
          state: ElsewhereState.found,
          checkedAt: now,
          url: 'https://one.test/s',
          chapters: 20,
          latest: '15',
          latestAt: '2026-10-20',
        ),
        ids[1]: SiteCopy(
          provider: ids[1],
          state: ElsewhereState.found,
          checkedAt: now,
          url: 'https://two.test/s',
          chapters: 9,
          latest: '11',
        ),
        ids[2]: SiteCopy(provider: ids[2], state: ElsewhereState.missing, checkedAt: now),
        ids[3]: SiteCopy(provider: ids[3], state: ElsewhereState.broken, checkedAt: now, message: 'cambiato'),
      });
      await tester.pumpWidget(host(data, opened));
      expect(find.text('SU ALTRI SITI'), findsOneWidget);
      expect(find.text('Passa a questo sito'), findsNWidgets(2));
      expect(find.text('20 capitoli · 3 capitoli avanti'), findsOneWidget);
      expect(find.text('9 capitoli · 1 capitolo indietro'), findsOneWidget);
      expect(find.text('Ultimo: capitolo 15, 2026-10-20'), findsOneWidget);
      expect(find.text('Qui non c\'è'), findsOneWidget);
      expect(find.text('Sito non funzionante'), findsOneWidget);
      await tester.tap(find.text('Passa a questo sito').first);
      expect(opened, ['https://one.test/s']);
    });

    testWidgets('mentre cerca lo dice, senza righe', (tester) async {
      await tester.pumpWidget(host(null, [], busy: true));
      expect(find.text('Cerco la serie sugli altri siti…'), findsOneWidget);
      expect(find.text('Passa a questo sito'), findsNothing);
    });
  });
}
