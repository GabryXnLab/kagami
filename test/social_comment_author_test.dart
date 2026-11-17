/// Il soprannome sul commento (F7.11, migrazione 0006): chi commenta col
/// profilo chiuso a chi legge porta il nome di quando ha scritto, senza foto,
/// e toccarlo dice «Profilo privato» invece di aprire il profilo.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/social/content.dart';
import 'package:kagami/src/data/social/memory_posts.dart';
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_social.dart';
import 'package:kagami/src/ui/social_profile_screen.dart';
import 'package:kagami/src/ui/social_tabs.dart';
import 'package:kagami/src/ui/theme.dart';

PublicProfile _profile(String uid, String name, {SocialAudience audience = SocialAudience.everyone, String? photo}) =>
    buildPublicProfile(
      uid: uid,
      settings: SocialSettings(enabled: true, name: name, audience: audience, showPhoto: photo != null),
      photo: photo,
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
  late Post mine;

  setUp(() async {
    network = MemorySocial('me');
    posts = MemoryPosts(network);
    await network.publish(_profile('me', 'Alice'));
    // Carl si fa vedere solo a chi lo segue a vicenda, ma commenta da me.
    await network.as('carl').publish(_profile('carl', 'Carl', audience: SocialAudience.mutual, photo: 'https://lh3.googleusercontent.com/carl'));
    mine = await posts.publish(const PostDraft(body: 'di Alice'));
    await posts.as('carl').comment(mine.id, 'bello');
  });

  test('il commento di un profilo chiuso porta il soprannome di quando è stato scritto, senza foto', () async {
    final author = (await posts.comments(mine.id)).single.author;
    expect((author.id, author.name, author.photo, author.closed), ('carl', 'Carl', null, true));

    // Cambiare soprannome dopo non riscrive il commento già fatto.
    await network.as('carl').publish(_profile('carl', 'Carlo', audience: SocialAudience.mutual));
    expect((await posts.comments(mine.id)).single.author.name, 'Carl');

    // A vicenda il profilo si apre: nome di adesso e foto.
    await network.follow('carl', name: 'Alice');
    await network.as('carl').follow('me', name: 'Carlo');
    await network.as('carl').publish(_profile('carl', 'Carlo', audience: SocialAudience.mutual, photo: 'https://lh3.googleusercontent.com/carl'));
    final open = (await posts.comments(mine.id)).single.author;
    expect((open.name, open.photo, open.closed), ('Carlo', 'https://lh3.googleusercontent.com/carl', false));
  });

  testWidgets('toccare il soprannome di un profilo chiuso dice «Profilo privato» e non apre niente', (tester) async {
    final db = KagamiDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      socialBackendProvider.overrideWithValue(network),
      socialPostsProvider.overrideWithValue(posts),
      socialMeProvider.overrideWithValue('me'),
      librarySignalsProvider.overrideWithValue(const []),
      hiddenSeriesKeysProvider.overrideWithValue(const {}),
    ]);
    addTearDown(c.dispose);
    await tester.runAsync(() async {
      await c.read(socialSettingsProvider.future);
      await c.read(socialSettingsProvider.notifier).save(const SocialSettings(enabled: true, name: 'Alice'));
    });
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: kagamiTheme(Brightness.dark),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: FeedTab()),
      ),
    ));
    await settle();
    await tester.tap(find.text('1 commento'));
    await settle();
    expect(find.text('bello'), findsOneWidget);
    await tester.tap(find.textContaining('Carl', findRichText: true));
    await settle();
    expect(find.text('Profilo privato'), findsOneWidget);
    expect(find.byType(SocialProfileScreen), findsNothing);
  });
}
