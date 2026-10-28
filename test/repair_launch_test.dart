// Lanciare la riparazione: chi lavora lo decide il motore dell'archivio, e
// un sito tornato sano si propone una volta sola per ritorno.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/archive/repair.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/archive_flow.dart';
import 'package:kagami/src/ui/archive_server.dart' show archiveOutcomeText;
import 'package:kagami_archive/jobs.dart' show ArchiveOutcome;
import 'package:kagami/l10n/app_localizations_it.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami_archive/health.dart';

void main() {
  late KagamiDatabase db;
  late List<String> calls;
  late Map<String, SiteHealth> health;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    calls = [];
    health = {};
  });

  tearDown(() => db.close());

  ProviderContainer make(ArchiveEngine engine, {bool serverSupports = true}) {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      archiveEngineProvider.overrideWithValue(engine),
      serverRepairRunProvider.overrideWithValue(({site, keys}) async {
        if (!serverSupports) throw const RepairUnsupported();
        calls.add('server site=$site keys=${keys?.join(',') ?? '-'}');
      }),
      phoneRepairRunProvider.overrideWithValue(({site, keys, progress}) async {
        calls.add('phone site=$site keys=${keys?.join(',') ?? '-'}');
        return 0;
      }),
      siteHealthProvider.overrideWith((ref) async => Map.of(health)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  SiteHealth broken(bool value) {
    final now = DateTime.utc(2026, 10, 28);
    return SiteHealth(broken: value, message: 'm', since: now, checkedAt: now);
  }

  test('con il motore server la riparazione va al server, non al telefono', () async {
    final container = make(ArchiveEngine.server);
    expect(await container.read(repairProvider.notifier).start(site: 'mangak'), RepairStart.server);
    expect(calls, ['server site=mangak keys=-']);
  });

  test('con il motore telefono la riparazione la fa il telefono, anche per una serie', () async {
    final container = make(ArchiveEngine.phone);
    expect(await container.read(repairProvider.notifier).start(keys: {'mangak:1'}), RepairStart.phone);
    expect(calls, ['phone site=null keys=mangak:1']);
  });

  test('un server che non ripara non ripiega sul telefono', () async {
    final container = make(ArchiveEngine.server, serverSupports: false);
    expect(await container.read(repairProvider.notifier).start(), RepairStart.unavailable);
    expect(calls, isEmpty);
    expect(container.read(repairProvider).error, isNotNull);
  });

  test('il sito tornato sano si propone una volta sola, anche riaprendo l\'app', () async {
    final container = make(ArchiveEngine.phone);
    final notifier = container.read(siteRecoveryProvider.notifier);
    await container.read(siteRecoveryProvider.future);

    await notifier.observe({'mangak'});
    expect(container.read(siteRecoveryProvider).value, isEmpty);

    await notifier.observe({});
    expect(container.read(siteRecoveryProvider).value, {'mangak'});

    // Rimasto sano: la proposta non si ripete né si moltiplica.
    await notifier.observe({});
    expect(container.read(siteRecoveryProvider).value, {'mangak'});

    await notifier.dismiss('mangak');
    await notifier.observe({});
    expect(container.read(siteRecoveryProvider).value, isEmpty);

    // Una proposta non ancora vista sopravvive alla chiusura dell'app.
    await notifier.observe({'mangak'});
    await notifier.observe({});
    final again = make(ArchiveEngine.phone);
    expect(await again.read(siteRecoveryProvider.future), {'mangak'});

    // Un nuovo guasto e un nuovo ritorno ne fanno un'altra.
    await again.read(siteRecoveryProvider.notifier).dismiss('mangak');
    await again.read(siteRecoveryProvider.notifier).observe({'mangak'});
    await again.read(siteRecoveryProvider.notifier).observe({});
    expect(again.read(siteRecoveryProvider).value, {'mangak'});
  });

  test('la salute letta dal registro porta il ritorno alla proposta', () async {
    final container = make(ArchiveEngine.phone);
    health = {'mangak': broken(true)};
    await container.read(siteRecoveryProvider.future);
    await container.read(siteHealthProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    health = {'mangak': broken(false)};
    container.invalidate(siteHealthProvider);
    await container.read(siteHealthProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(siteRecoveryProvider).value, {'mangak'});
  });

  testWidgets('la proposta nomina il sito e «Ripara» lancia la riparazione di quel sito', (tester) async {
    final container = make(ArchiveEngine.server);
    await tester.runAsync(() async {
      await container.read(siteRecoveryProvider.future);
      await container.read(siteRecoveryProvider.notifier).observe({'coffeemanga'});
      await container.read(siteRecoveryProvider.notifier).observe({});
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: kagamiTheme(Brightness.light),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SiteRecoveryCard()),
      ),
    ));
    expect(find.text('Il sito Coffee Manga funziona di nuovo: ripara le sue serie'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Ripara'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(calls, ['server site=coffeemanga keys=-']);
    expect(container.read(siteRecoveryProvider).value, isEmpty);
  });

  test('la cronologia dice cosa ha cambiato la riparazione', () {
    final l10n = AppLocalizationsIt();
    ArchiveOutcome outcome(Map<String, Object?> repair) => ArchiveOutcome(
          title: 'Fog Land',
          ok: repair['error'] == null,
          message: 'Serie riparata.',
          finishedAt: DateTime.utc(2026, 10, 28),
          repair: repair,
        );
    expect(
      archiveOutcomeText(l10n, outcome({
        'key': 'a:1',
        'adoptedFrom': 'a:0',
        'titleChanged': true,
        'added': ['1', '2'],
        'unlisted': ['9'],
      })),
      'nuova chiave adottata; titolo aggiornato; 2 capitoli nuovi; 1 capitolo non più elencato',
    );
    expect(archiveOutcomeText(l10n, outcome({'key': 'a:1'})), 'Niente da riparare');
    expect(archiveOutcomeText(l10n, outcome({'key': 'a:1', 'error': 'Sito giù'})), 'Non riparata: Sito giù');
  });
}
