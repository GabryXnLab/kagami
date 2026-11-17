/// Blocca e segnala (`docs/social.md`): le regole di `MemoryReports`, il
/// blocco che toglie legami e contenuti nei due versi senza dirlo all'altro,
/// e il menu su un post e su un profilo.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/social/backend.dart';
import 'package:kagami/src/data/social/content.dart';
import 'package:kagami/src/data/social/memory_posts.dart';
import 'package:kagami/src/data/social/memory_reports.dart';
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_social.dart';
import 'package:kagami/src/ui/social_profile_screen.dart';
import 'package:kagami/src/ui/social_tabs.dart';
import 'package:kagami/src/ui/theme.dart';

PublicProfile _profile(String uid, String name) => buildPublicProfile(
      uid: uid,
      settings: SocialSettings(enabled: true, name: name),
      statistics: const ReadingStatistics(
        chaptersRead: 1,
        pagesRead: 0,
        timeRead: Duration.zero,
        perDay: {},
        perMonth: {},
        topSeries: [],
        firstRead: null,
        excluding: {},
      ),
      series: const [],
      hidden: const {},
      now: DateTime(2026, 11, 14),
    );

void main() {
  late MemorySocial network;
  late MemoryPosts posts;
  late MemoryReports reports;
  late KagamiDatabase db;

  setUp(() async {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    network = MemorySocial('me');
    posts = MemoryPosts(network);
    reports = MemoryReports(network);
    await network.publish(_profile('me', 'Alice'));
    await network.as('bob').publish(_profile('bob', 'Bob'));
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        socialBackendProvider.overrideWithValue(network),
        socialPostsProvider.overrideWithValue(posts),
        socialReportsProvider.overrideWithValue(reports),
        socialMeProvider.overrideWithValue('me'),
      ];

  group('MemoryReports', () {
    test('una per persona e oggetto; il resto con le regole della tabella', () async {
      const post = Report(target: ReportTarget.post, user: 'bob', targetId: 'p1', reason: ReportReason.spam, snapshot: 'testo');
      await reports.report(post);
      await reports.report(const Report(target: ReportTarget.post, user: 'bob', targetId: 'p1', reason: ReportReason.other));
      await reports.report(const Report(target: ReportTarget.user, user: 'bob', reason: ReportReason.harassment));
      expect(reports.stored.map((s) => s.report.target), [ReportTarget.post, ReportTarget.user]);
      expect(reports.stored.first.report.snapshot, 'testo');

      // target_id c'è se e solo se non è una persona.
      await expectLater(
        reports.report(const Report(target: ReportTarget.comment, user: 'bob', reason: ReportReason.spam)),
        throwsArgumentError,
      );
      // Senza profilo si è rifiutati, come ogni altro rifiuto.
      await expectLater(
        MemoryReports(network.as('zed')).report(const Report(target: ReportTarget.user, user: 'bob', reason: ReportReason.spam)),
        throwsA(isA<SocialRefused>()),
      );
    });

    test('venti al giorno', () async {
      for (var i = 0; i < 20; i++) {
        await reports.report(Report(target: ReportTarget.post, user: 'bob', targetId: 'p$i', reason: ReportReason.spam));
      }
      await expectLater(
        reports.report(const Report(target: ReportTarget.post, user: 'bob', targetId: 'p20', reason: ReportReason.spam)),
        throwsA(isA<SocialRefused>()),
      );
    });
  });

  group('blocco', () {
    test('toglie i legami e ciò che si vede, nei due versi; sbloccare lo restituisce', () async {
      await posts.as('bob').publish(const PostDraft(body: 'di Bob'));
      await network.follow('bob', name: 'Alice');
      await network.as('bob').follow('me', name: 'Bob');
      final c = ProviderContainer(overrides: overrides());
      addTearDown(c.dispose);
      await c.read(socialSettingsProvider.future);
      await c.read(socialSettingsProvider.notifier).save(const SocialSettings(enabled: true, name: 'Alice'));
      expect(await c.read(socialFeedProvider(FeedScope.everyone).future), hasLength(1));

      await network.block('bob');
      c.invalidate(socialFeedProvider);
      expect(await c.read(socialFeedProvider(FeedScope.everyone).future), isEmpty);
      expect((await network.graph()).following, isEmpty);
      expect((await network.as('bob').graph()).following, isEmpty);
      expect(await network.as('bob').profile('me'), isNull);
      expect(await network.blocked(), {'bob'});

      await network.unblock('bob');
      expect(await network.as('bob').profile('me'), isNotNull);
      expect(await network.blocked(), isEmpty);
    });
  });

  group('menu', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> open(WidgetTester tester, Widget body) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: overrides());
      addTearDown(c.dispose);
      await tester.runAsync(() async {
        await c.read(socialSettingsProvider.future);
        await c.read(socialSettingsProvider.notifier).save(const SocialSettings(enabled: true, name: 'Alice'));
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: kagamiTheme(Brightness.dark),
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: body),
        ),
      ));
      await settle(tester);
    }

    testWidgets('su un post altrui: segnala con la copia del testo, poi blocca', (tester) async {
      late Post post;
      await tester.runAsync(() async => post = await posts.as('bob').publish(const PostDraft(body: 'di Bob')));
      await open(tester, const FeedTab());
      expect(find.text('di Bob'), findsOneWidget);

      await tester.tap(find.byTooltip('Altre azioni'));
      await settle(tester);
      await tester.tap(find.text('Segnala'));
      await settle(tester);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Invia')).onPressed, isNull);
      await tester.tap(find.text('Spam o pubblicità'));
      await settle(tester);
      await tester.tap(find.text('Invia'));
      await settle(tester);
      final sent = reports.stored.single;
      expect((sent.reporter, sent.report.target, sent.report.targetId, sent.report.user), ('me', ReportTarget.post, post.id, 'bob'));
      expect((sent.report.reason, sent.report.snapshot), (ReportReason.spam, 'di Bob'));
      expect(find.text('Segnalazione inviata.'), findsOneWidget);

      await tester.tap(find.byTooltip('Altre azioni'));
      await settle(tester);
      await tester.tap(find.text('Blocca Bob'));
      await settle(tester);
      expect(await tester.runAsync(network.blocked), isEmpty);
      await tester.tap(find.text('Blocca'));
      await settle(tester);
      expect(await tester.runAsync(network.blocked), {'bob'});
      expect(find.text('di Bob'), findsNothing);
    });

    testWidgets('un blocco rifiutato dice solo «non è stato possibile»', (tester) async {
      await tester.runAsync(() async => posts.as('bob').publish(const PostDraft(body: 'di Bob')));
      await open(tester, const FeedTab());
      network.failure = const SocialRefused();
      await tester.tap(find.byTooltip('Altre azioni'));
      await settle(tester);
      await tester.tap(find.text('Blocca Bob'));
      await settle(tester);
      await tester.tap(find.text('Blocca'));
      await settle(tester);
      expect(find.text("Non è stato possibile completare l'azione."), findsOneWidget);
    });

    testWidgets('sul profilo: segnala la persona', (tester) async {
      await open(tester, const SocialProfileScreen(uid: 'bob'));
      await tester.tap(find.byTooltip('Altre azioni'));
      await settle(tester);
      await tester.tap(find.text('Segnala'));
      await settle(tester);
      await tester.tap(find.text('Molestie o insistenza'));
      await settle(tester);
      await tester.tap(find.text('Invia'));
      await settle(tester);
      final report = reports.stored.single.report;
      expect((report.target, report.targetId, report.user, report.reason), (ReportTarget.user, null, 'bob', ReportReason.harassment));
      expect(report.snapshot, startsWith('Bob'));
    });
  });
}
