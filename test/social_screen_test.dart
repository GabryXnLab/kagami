/// La schermata «Comunità»: spenta non chiama il backend e mostra l'anteprima
/// senza le serie nascoste; accesa pubblica, mostra le classifiche, il profilo
/// di un altro lettore, e spegnere cancella (`docs/social.md`).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/social/backend.dart';
import 'package:kagami/src/data/social/memory_posts.dart';
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_social.dart';
import 'package:kagami/src/ui/social_profile_screen.dart';
import 'package:kagami/src/ui/social_screen.dart';
import 'package:kagami/src/ui/theme.dart';

PublicProfile _profileOf(String uid, SocialSettings settings, {int chapters = 8, Set<String> hidden = const {}}) =>
    buildPublicProfile(
      uid: uid,
      settings: settings,
      statistics: ReadingStatistics(
        chaptersRead: chapters,
        pagesRead: 0,
        timeRead: Duration.zero,
        perDay: const {},
        perMonth: const {},
        topSeries: const [],
        firstRead: null,
        excluding: hidden,
      ),
      series: [
        ProfileSeries(key: 'alfa', title: 'Alfa', genres: const ['Azione'], read: chapters),
        const ProfileSeries(key: 'segreta', title: 'Segreta', genres: ['Orrore'], read: 30),
      ],
      hidden: hidden,
      now: DateTime(2026, 11, 14),
    );

void main() {
  late KagamiDatabase db;
  late MemorySocial network;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    network = MemorySocial('me');
  });

  tearDown(() => db.close());

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        socialBackendProvider.overrideWithValue(network),
        socialPostsProvider.overrideWithValue(MemoryPosts(network)),
        socialMeProvider.overrideWithValue('me'),
        socialDraftProvider.overrideWith((ref) async {
          final settings = await ref.watch(socialSettingsProvider.future);
          return _profileOf('me', settings, hidden: const {'segreta'});
        }),
      ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> open(WidgetTester tester, {Widget home = const SocialScreen()}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: kagamiTheme(Brightness.dark),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await settle(tester);
    return container;
  }

  testWidgets('spenta: anteprima senza serie nascoste e nessuna chiamata al backend', (tester) async {
    await open(tester);
    expect(find.textContaining('La Comunità è spenta'), findsOneWidget);
    expect(find.text('Alfa'), findsNothing); // titoli: interruttore spento
    expect(find.textContaining('Segreta'), findsNothing);
    expect(find.text('Serie nascoste escluse'), findsOneWidget);
    expect(network.calls, isEmpty);
  });

  testWidgets('accendere pubblica il profilo, spegnere lo cancella', (tester) async {
    final container = await open(tester);

    // Senza soprannome valido il pulsante non fa niente.
    await tester.tap(find.text('Accendi la Comunità'));
    await settle(tester);
    expect(network.calls, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'Alice');
    await settle(tester);
    await tester.tap(find.text('Accendi la Comunità'));
    await settle(tester);

    expect(network.profiles['me']!.name, 'Alice');
    expect(network.profiles['me']!.series, isNull);
    expect(container.read(socialSettingsProvider).value!.enabled, isTrue);
    expect(find.text('Classifiche'), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('TU'), findsOneWidget);

    await tester.tap(find.text('Feed'));
    await settle(tester);
    expect(find.text('Nessun post per ora'), findsOneWidget);

    await tester.tap(find.byTooltip('Spegni la Comunità e cancella tutto'));
    await settle(tester);
    await tester.tap(find.text('Spegni la Comunità e cancella tutto').last);
    await settle(tester);
    expect(network.profiles, isEmpty);
    expect(container.read(socialSettingsProvider).value!.enabled, isFalse);
    expect(find.text('Accendi la Comunità'), findsOneWidget);
  });

  testWidgets('un backend senza Comunità lo dice e non accende', (tester) async {
    final container = await open(tester);
    network.failure = const SocialUnavailable();
    await tester.enterText(find.byType(TextField).first, 'Alice');
    await settle(tester);
    await tester.tap(find.text('Accendi la Comunità'));
    await settle(tester);
    expect(find.text('Questo backend non ha la Comunità'), findsOneWidget);
    expect(container.read(socialSettingsProvider).value!.enabled, isFalse);
  });

  testWidgets('il profilo di un altro mostra affinità e numeri, e si può seguire', (tester) async {
    const mine = SocialSettings(enabled: true, name: 'Alice');
    await network.publish(_profileOf('me', mine));
    await network.as('bob').publish(_profileOf('bob', const SocialSettings(enabled: true, name: 'Bob'), chapters: 12));
    final container = await open(tester, home: const SocialProfileScreen(uid: 'bob'));
    await container.read(socialSettingsProvider.notifier).save(mine);
    container.invalidate(socialProfileProvider('bob'));
    await settle(tester);

    expect(find.text('Bob'), findsWidgets);
    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining('affinità'), findsOneWidget);
    expect(find.textContaining('follower'), findsNothing);

    await tester.tap(find.text('Segui'));
    await settle(tester);
    expect(network.follows['me']!.containsKey('bob'), isTrue);
    expect(find.text('Seguito'), findsOneWidget);
  });
}
