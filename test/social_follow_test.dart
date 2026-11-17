/// Segui, «solo chi seguo», chi mi segue, affinità, titoli in comune e
/// silenziare una persona (`docs/social.md`, «Chi vede cosa»).
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
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_social.dart';
import 'package:kagami/src/ui/social_profile_screen.dart';
import 'package:kagami/src/ui/social_tabs.dart';
import 'package:kagami/src/ui/theme.dart';

PublicProfile _reader(String uid, String name, {List<(String, int)> genres = const [], List<(String, int)>? series}) =>
    PublicProfile(id: uid, name: name, genres: genres, series: series, chapters: 5);

void main() {
  late KagamiDatabase db;
  late MemorySocial network;
  late MemoryPosts posts;

  setUp(() async {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    network = MemorySocial('me');
    posts = MemoryPosts(network);
    await network.publish(_reader('me', 'Alice', genres: [('Azione', 60), ('Sport', 40)], series: [('One-Punch Man', 3)]));
    await network.as('bob').publish(_reader('bob', 'Bob', genres: [('azione', 50), ('Orrore', 50)], series: [('one punch man', 9), ('Altra', 1)]));
    await network.as('carl').publish(_reader('carl', 'Carl'));
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> open(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<Override> overrides = [
      databaseProvider.overrideWithValue(db),
      socialBackendProvider.overrideWithValue(network),
      socialPostsProvider.overrideWithValue(posts),
      socialMeProvider.overrideWithValue('me'),
      socialDraftProvider.overrideWith((ref) async => network.profiles['me']!),
    ];
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await container.read(socialSettingsProvider.future);
    await container.read(socialSettingsProvider.notifier).save(const SocialSettings(enabled: true, name: 'Alice'));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: kagamiTheme(Brightness.dark),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    ));
    await settle(tester);
    return container;
  }

  test('affinità e titoli in comune si calcolano da due profili visibili', () {
    final me = network.profiles['me']!;
    final bob = network.profiles['bob']!;
    expect(affinity(me, bob), 50);
    expect(affinity(me, network.profiles['carl']!), 0);
    expect(inCommon(me, bob), ['One-Punch Man']);
    expect(inCommon(me, _reader('x', 'X')), isEmpty);
  });

  test('«solo chi seguo» mostra i post di chi seguo', () async {
    await posts.as('bob').publish(const PostDraft(body: 'di Bob'));
    await posts.as('carl').publish(const PostDraft(body: 'di Carl'));
    await network.follow('bob', name: 'Alice');
    expect([for (final p in await posts.feed(FeedScope.everyone)) p.body], unorderedEquals(['di Bob', 'di Carl']));
    expect([for (final p in await posts.feed(FeedScope.following)) p.body], ['di Bob']);
    await network.unfollow('bob');
    expect(await posts.feed(FeedScope.following), isEmpty);
  });

  testWidgets('chi mi segue compare in Persone e si ricambia', (tester) async {
    await network.as('carl').follow('me', name: 'Carl');
    final container = await open(tester, const PeopleTab());
    expect(find.text('TI SEGUONO'), findsOneWidget);
    expect(find.text('Carl'), findsOneWidget);

    await tester.tap(find.text('Segui anche tu'));
    await settle(tester);
    expect(network.follows['me']!.keys, contains('carl'));
    expect(find.text('TI SEGUONO'), findsNothing);
    expect(find.text('SEGUITI'), findsOneWidget);
    expect(container.read(socialGraphProvider).value!.mutual('carl'), isTrue);
  });

  testWidgets('silenziare nasconde post e commenti, e si ricorda nelle impostazioni', (tester) async {
    final post = await posts.as('bob').publish(const PostDraft(body: 'di Bob'));
    await posts.as('carl').comment(post.id, 'commento di Carl');
    await posts.as('bob').comment(post.id, 'commento di Bob');
    final container = await open(tester, const SocialProfileScreen(uid: 'bob'));
    expect([for (final p in await container.read(socialFeedProvider(FeedScope.everyone).future)) p.body], ['di Bob']);

    await tester.tap(find.byTooltip('Altre azioni'));
    await settle(tester);
    await tester.tap(find.text('Silenzia'));
    await settle(tester);

    expect(container.read(socialSettingsProvider).value!.muted, {'bob'});
    expect(await container.read(userRepositoryProvider).readSetting('social.muted'), contains('bob'));
    expect(await container.read(socialFeedProvider(FeedScope.everyone).future), isEmpty);
    expect([for (final c in await container.read(socialCommentsProvider(post.id).future)) c.body], ['commento di Carl']);
    expect(find.textContaining('Silenziato'), findsOneWidget);

    await tester.tap(find.byTooltip('Altre azioni'));
    await settle(tester);
    await tester.tap(find.text('Riattiva'));
    await settle(tester);
    expect(container.read(socialSettingsProvider).value!.muted, isEmpty);
    expect(await container.read(socialFeedProvider(FeedScope.everyone).future), hasLength(1));
  });
}
