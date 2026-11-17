/// Impostazioni → «Privacy e Comunità»: spenta di default e si accende, le
/// scelte si salvano, e l'elenco dei bloccati mostra il soprannome salvato al
/// blocco e lo toglie con «Sblocca» (`docs/social.md`).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/social/memory_posts.dart';
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_social.dart';
import 'package:kagami/src/ui/privacy_screen.dart';
import 'package:kagami/src/ui/theme.dart';

/// Il punto da cui l'app blocca: `setBlocked` vuole un `WidgetRef`.
class _BlockHost extends ConsumerWidget {
  const _BlockHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        onPressed: () => setBlocked(ref, 'bob', blocked: true, name: 'Bob'),
        child: const Text('blocca-bob'),
      );
}

void main() {
  late KagamiDatabase db;
  late MemorySocial network;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    network = MemorySocial('me');
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: <Override>[
      databaseProvider.overrideWithValue(db),
      socialBackendProvider.overrideWithValue(network),
      socialPostsProvider.overrideWithValue(MemoryPosts(network)),
      socialMeProvider.overrideWithValue('me'),
      socialDraftProvider.overrideWith((ref) async {
        final settings = await ref.watch(socialSettingsProvider.future);
        return buildPublicProfile(
          uid: 'me',
          settings: settings,
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
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: kagamiTheme(Brightness.dark),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Stack(children: [PrivacyScreen(), Align(alignment: Alignment.bottomCenter, child: _BlockHost())]),
      ),
    ));
    await settle(tester);
    return container;
  }

  Future<String?> stored(WidgetTester tester, ProviderContainer container, String key) =>
      tester.runAsync(() => container.read(userRepositoryProvider).readSetting(key)).then((value) => value);

  testWidgets('spenta di default, e con un soprannome si accende', (tester) async {
    final container = await open(tester);
    expect(container.read(socialSettingsProvider).value!.enabled, isFalse);
    expect(find.textContaining('Con la Comunità spenta'), findsOneWidget);

    await tester.runAsync(() => container.read(socialSettingsProvider.notifier).save(const SocialSettings(name: 'Mia')));
    await settle(tester);
    await tester.tap(find.text('Comunità'));
    await settle(tester);
    expect(container.read(socialSettingsProvider).value!.enabled, isTrue);
    expect(network.profiles.containsKey('me'), isTrue);
  });

  testWidgets('livello, interruttore e chi può scrivermi si salvano', (tester) async {
    final container = await open(tester);
    await tester.tap(find.text('Amici reciproci').first);
    await settle(tester);
    await tester.tap(find.text('Mostra i titoli più letti'));
    await settle(tester);
    await tester.tap(find.text('Nessuno'));
    await settle(tester);

    final settings = container.read(socialSettingsProvider).value!;
    expect(settings.audience, SocialAudience.mutual);
    expect(settings.showSeries, isTrue);
    expect(settings.messages, MessagePolicy.nobody);
    expect(await stored(tester, container, 'social.audience'), 'mutual');
    expect(await stored(tester, container, 'social.messages'), 'nobody');
  });

  testWidgets('bloccati: il soprannome salvato al blocco, «Sblocca» lo toglie', (tester) async {
    final container = await open(tester);
    expect(find.text('Non hai bloccato nessuno.'), findsOneWidget);
    await tester.runAsync(() async {
      await container.read(socialSettingsProvider.notifier).save(const SocialSettings(name: 'Mia', enabled: true));
      await network.publish(await container.read(socialDraftProvider.future));
    });
    container.invalidate(socialBlockedProvider);

    await tester.tap(find.text('blocca-bob'));
    await settle(tester);
    expect(find.text('Bob'), findsOneWidget);
    expect(await tester.runAsync(network.blocked), {'bob'});

    await tester.tap(find.text('Sblocca'));
    await settle(tester);
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Non hai bloccato nessuno.'), findsOneWidget);
    expect(await tester.runAsync(network.blocked), isEmpty);
    expect(await stored(tester, container, socialBlockedNamesKey), '{}');
  });
}
