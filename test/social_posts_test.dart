/// Post, commenti e mi piace della Comunità (`docs/social.md`): le regole di
/// `MemoryPosts`, che rifanno quelle di `backend/rls-test.sql`; il rifiuto
/// delle serie nascoste prima della rete; il feed, la scrittura, i commenti e
/// il tondo sulla scheda di una serie.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/data/social/backend.dart';
import 'package:kagami/src/data/social/content.dart';
import 'package:kagami/src/data/social/memory_posts.dart';
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_social.dart';
import 'package:kagami/src/ui/social_posts.dart';
import 'package:kagami/src/ui/social_tabs.dart';
import 'package:kagami/src/ui/theme.dart';

PublicProfile _profile(String uid, String name, {SocialAudience audience = SocialAudience.everyone}) => buildPublicProfile(
      uid: uid,
      settings: SocialSettings(enabled: true, name: name, audience: audience),
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

SeriesSignals _series(String key, String title, {String? reached, int? rating}) => SeriesSignals(
      entry: SeriesEntry(
        key: key,
        path: '$title [x-1]',
        title: title,
        provider: 'x',
        releaseStatus: ReleaseStatus.ongoing,
        chapterCount: 100,
        archivedChapterCount: 100,
        pageCount: 1,
        bytes: 1,
        signature: 's',
      ),
      state: SeriesState(reachedChapter: reached, rating: rating),
      readCount: 0,
      unreadCount: 0,
    );

void main() {
  late MemorySocial network;
  late MemoryPosts posts;

  setUp(() async {
    network = MemorySocial('me');
    posts = MemoryPosts(network);
    await network.publish(_profile('me', 'Alice'));
    await network.as('bob').publish(_profile('bob', 'Bob'));
  });

  group('MemoryPosts', () {
    test('si vede il post di chi si vede; «solo chi seguo» è il seguito', () async {
      await network.as('carl').publish(_profile('carl', 'Carl', audience: SocialAudience.mutual));
      await posts.as('bob').publish(const PostDraft(body: 'ciao'));
      await posts.as('carl').publish(const PostDraft(body: 'segreto'));

      expect([for (final p in await posts.feed(FeedScope.everyone)) p.body], ['ciao']);
      expect(await posts.feed(FeedScope.following), isEmpty);

      await network.follow('bob', name: 'Alice');
      await network.follow('carl', name: 'Alice');
      expect([for (final p in await posts.feed(FeedScope.following)) p.body], ['ciao']);
      await network.as('carl').follow('me', name: 'Carl');
      expect({for (final p in await posts.feed(FeedScope.following)) p.body}, {'ciao', 'segreto'});

      // Chi non ha un profilo non legge niente; un bloccato non vede.
      expect(await MemoryPosts(network.as('nessuno')).feed(FeedScope.everyone), isEmpty);
      await network.as('bob').block('me');
      expect([for (final p in await posts.feed(FeedScope.everyone)) p.body], ['segreto']);
    });

    test('commenti, risposte sotto lo stesso post, e chi li toglie', () async {
      final post = await posts.as('bob').publish(const PostDraft(body: 'post di Bob'));
      final other = await posts.as('bob').publish(const PostDraft(body: 'un altro'));
      await network.as('carl').publish(_profile('carl', 'Carl'));
      final mine = await posts.comment(post.id, 'primo');
      final carls = await posts.as('carl').comment(post.id, 'di Carl');
      final reply = await posts.as('carl').comment(post.id, 'risposta', parent: mine.id);
      expect(reply.parent, mine.id);
      expect(() => posts.comment(other.id, 'fuori posto', parent: mine.id), throwsArgumentError);
      expect((await posts.feed(FeedScope.everyone)).firstWhere((p) => p.id == post.id).comments, 3);

      // Un terzo non toglie il commento di un altro; l'autore del post sì.
      await posts.removeComment(carls.id);
      expect(posts.commentIds, contains(carls.id));
      await posts.as('bob').removeComment(carls.id);
      expect(posts.commentIds, isNot(contains(carls.id)));

      // Le risposte cadono col commento.
      await posts.removeComment(mine.id);
      expect(await posts.comments(post.id), isEmpty);
    });

    test('mi piace: contati dal backend, propri, solo su ciò che si vede', () async {
      final post = await posts.as('bob').publish(const PostDraft(body: 'ciao'));
      await posts.like(post: post.id, liked: true);
      await posts.like(post: post.id, liked: true);
      final seen = (await posts.feed(FeedScope.everyone)).single;
      expect((seen.likes, seen.liked), (1, true));
      final byBob = (await posts.as('bob').feed(FeedScope.everyone)).single;
      expect((byBob.likes, byBob.liked), (1, false));
      await posts.like(post: post.id, liked: false);
      expect((await posts.feed(FeedScope.everyone)).single.likes, 0);

      await network.as('bob').block('me');
      expect(() => posts.like(post: post.id, liked: true), throwsA(isA<SocialRefused>()));
    });

    test('si toglie solo il proprio post; uscire lo cancella; il limite è 20 al giorno', () async {
      final post = await posts.as('bob').publish(const PostDraft(body: 'ciao'));
      await posts.remove(post.id);
      expect(posts.postIds, [post.id]);
      await network.as('bob').withdraw();
      expect(posts.postIds, isEmpty);

      for (var i = 0; i < 20; i++) {
        await posts.publish(PostDraft(body: 'post $i'));
      }
      expect(() => posts.publish(const PostDraft(body: 'uno di troppo')), throwsA(isA<SocialRefused>()));
    });
  });

  group('con l\'app', () {
    late KagamiDatabase db;
    final library = [_series('alfa', 'Alfa', reached: '12', rating: 8), _series('segreta', 'Segreta')];

    setUp(() => db = KagamiDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    List<Override> overrides() => [
          databaseProvider.overrideWithValue(db),
          socialBackendProvider.overrideWithValue(network),
          socialPostsProvider.overrideWithValue(posts),
          socialMeProvider.overrideWithValue('me'),
          librarySignalsProvider.overrideWithValue(library),
          hiddenSeriesKeysProvider.overrideWithValue(const {'segreta'}),
        ];

    Future<ProviderContainer> container({Set<String> muted = const {}}) async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      await container.read(socialSettingsProvider.future);
      await container.read(socialSettingsProvider.notifier).save(SocialSettings(enabled: true, name: 'Alice', muted: muted));
      return container;
    }

    test('una serie nascosta non si nomina: rifiutata prima della rete, per chiave e per titolo', () async {
      final c = await container();
      final controller = c.read(socialPostsControllerProvider.notifier);
      posts.calls.clear();
      expect(
        await controller.publish(const PostDraft(body: 'x', seriesKey: 'segreta', seriesTitle: 'Segreta')),
        PostRefusal.hiddenSeries,
      );
      expect(await controller.publish(const PostDraft(body: 'x', seriesTitle: 'SEGRETA!')), PostRefusal.hiddenSeries);
      expect(await controller.publish(const PostDraft(body: ' ', seriesKey: 'alfa', seriesTitle: 'Alfa')), PostRefusal.empty);
      expect(posts.calls, isEmpty);
      expect(await controller.publish(const PostDraft(body: 'bella', kind: PostKind.review, seriesKey: 'alfa', seriesTitle: 'Alfa', rating: 8)), isNull);
      expect(posts.calls, ['me publish']);
    });

    test('il feed toglie i silenziati e le serie nascoste; di una nascosta non si chiede niente', () async {
      await posts.as('bob').publish(const PostDraft(body: 'su Alfa', seriesTitle: 'Alfa'));
      await posts.as('bob').publish(const PostDraft(body: 'sulla segreta', seriesTitle: 'Segreta'));
      await network.as('carl').publish(_profile('carl', 'Carl'));
      await posts.as('carl').publish(const PostDraft(body: 'di Carl'));
      final c = await container(muted: {'carl'});

      expect([for (final p in await c.read(socialFeedProvider(FeedScope.everyone).future)) p.body], ['su Alfa']);
      expect([for (final p in await c.read(socialSeriesPostsProvider(seriesRef('Alfa')).future)) p.body], ['su Alfa']);
      posts.calls.clear();
      await expectLater(c.read(socialSeriesPostsProvider(seriesRef('Segreta')).future), throwsStateError);
      expect(posts.calls, isEmpty);
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<ProviderContainer> open(WidgetTester tester, Widget body) async {
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
      return c;
    }

    testWidgets('feed: spoiler e segnalati coperti col tocco, mi piace, commenti e risposte', (tester) async {
      await tester.runAsync(() async {
        final spoiler = await posts.as('bob').publish(const PostDraft(body: 'muore al 50', seriesTitle: 'Alfa', spoiler: true, chapter: 50));
        await posts.as('bob').publish(const PostDraft(body: 'detto al 10', seriesTitle: 'Alfa', spoiler: true, chapter: 10));
        final flagged = await posts.as('bob').publish(const PostDraft(body: 'brutto'));
        posts.flag(flagged.id, Post.flagged);
        expect(spoiler.chapter, 50);
      });
      await open(tester, const FeedTab());

      // Al capitolo 12: coperto lo spoiler fino al 50, visibile quello fino al 10.
      expect(find.text('muore al 50'), findsNothing);
      expect(find.text('detto al 10'), findsOneWidget);
      expect(find.text('brutto'), findsNothing);
      await tester.tap(find.text('Contenuto segnalato da più lettori'));
      await settle(tester);
      expect(find.text('brutto'), findsOneWidget);
      await tester.tap(find.textContaining('50').first);
      await settle(tester);
      expect(find.text('muore al 50'), findsOneWidget);

      await tester.tap(find.byTooltip('Mi piace').first);
      await settle(tester);
      expect(posts.calls, contains('me like'));
      expect((await tester.runAsync(() => posts.feed(FeedScope.everyone)))!.where((p) => p.liked), hasLength(1));

      await tester.tap(find.text('Commenta').first);
      await settle(tester);
      expect(find.text('Ancora nessun commento'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'bel post');
      await tester.tap(find.byTooltip('Invia'));
      await settle(tester);
      expect(find.text('bel post'), findsOneWidget);
      await tester.tap(find.text('Rispondi'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'risposta');
      await tester.tap(find.byTooltip('Invia'));
      await settle(tester);
      final postId = (await tester.runAsync(() => posts.feed(FeedScope.everyone)))!.first.id;
      final comments = (await tester.runAsync(() => posts.comments(postId)))!;
      expect([for (final c in comments) (c.body, c.parent == null)], [('bel post', true), ('risposta', false)]);
    });

    testWidgets('scrivere un post e toglierlo', (tester) async {
      await open(tester, const FeedTab());
      await tester.tap(find.text('Scrivi'));
      await settle(tester);
      await tester.tap(find.text('Pubblica'));
      await settle(tester);
      expect(find.text('Scrivi qualcosa prima di pubblicare.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Che cosa ne pensi?'), 'Il mio primo post');
      await tester.tap(find.text('Pubblica'));
      await settle(tester);
      expect(find.text('Il mio primo post'), findsOneWidget);
      expect(posts.postIds, hasLength(1));

      await tester.tap(find.byTooltip('Altre azioni'));
      await settle(tester);
      await tester.tap(find.text('Togli il post'));
      await settle(tester);
      await tester.tap(find.text('Togli il post').last);
      await settle(tester);
      expect(posts.postIds, isEmpty);
      expect(find.text('Il mio primo post'), findsNothing);
    });

    testWidgets('dalla scheda di una serie: una recensione col voto già dato; nascosta, niente tondo', (tester) async {
      await open(
        tester,
        Row(children: [SeriesSocialAction(signals: library[0]), SeriesSocialAction(signals: library[1])]),
      );
      expect(find.byTooltip('Parlane nella Comunità'), findsOneWidget);
      await tester.tap(find.byTooltip('Parlane nella Comunità'));
      await settle(tester);
      expect(find.text('Nessuno ne ha ancora parlato'), findsOneWidget);
      expect(posts.calls, ['me about ${seriesRef('Alfa')}']);

      await tester.tap(find.byTooltip('Scrivi'));
      await settle(tester);
      await tester.tap(find.text('Recensione'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Che cosa ne pensi?'), 'Da leggere');
      await tester.tap(find.text('Pubblica'));
      await settle(tester);
      final post = (await tester.runAsync(() => posts.about(seriesRef('Alfa'))))!.single;
      expect((post.kind, post.rating, post.seriesTitle), (PostKind.review, 8, 'Alfa'));
      expect(find.text('Da leggere'), findsOneWidget);
    });
  });
}
