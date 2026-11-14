/// Messaggi privati (`docs/social.md`, `messages`): le regole di
/// `MemoryMessages`, che rifanno quelle di `backend/rls-test.sql` (chi mi
/// accetta, rispondere sempre, la proroga con la riga `drive_shares` giusta e
/// una al giorno); non letti e conversazioni; la schermata; «Chiedi più tempo».
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/share_directory.dart';
import 'package:kagami/src/data/social/backend.dart';
import 'package:kagami/src/data/social/content.dart';
import 'package:kagami/src/data/social/memory_messages.dart';
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_shares.dart';
import 'package:kagami/src/providers_social.dart';
import 'package:kagami/src/providers_sources.dart';
import 'package:kagami/src/ui/drive_received_sheet.dart';
import 'package:kagami/src/ui/social_messages.dart';
import 'package:kagami/src/ui/theme.dart';

PublicProfile _profile(String uid, String name, {MessagePolicy messages = MessagePolicy.everyone}) => buildPublicProfile(
      uid: uid,
      settings: SocialSettings(enabled: true, name: name, messages: messages),
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

class _Sources extends LibrarySources {
  _Sources(this.list);

  final List<SourceConfig> list;

  @override
  Future<SourceList> build() async => SourceList(list);
}

void main() {
  late MemorySocial network;
  late MemoryMessages messages;
  var now = DateTime(2026, 11, 14, 10);

  setUp(() async {
    now = DateTime(2026, 11, 14, 10);
    network = MemorySocial('me', clock: () => now);
    messages = MemoryMessages(network, clock: () => now);
    await network.publish(_profile('me', 'Alice'));
    await network.as('bob').publish(_profile('bob', 'Bob'));
  });

  group('MemoryMessages', () {
    test('chi può scrivermi lo decide il destinatario; rispondere si può sempre', () async {
      await network.as('bob').publish(_profile('bob', 'Bob', messages: MessagePolicy.following));
      await expectLater(messages.send('bob', 'ciao'), throwsA(isA<SocialRefused>()));
      await network.as('bob').follow('me', name: 'Bob');
      await messages.send('bob', 'ciao');

      await network.as('bob').publish(_profile('bob', 'Bob', messages: MessagePolicy.mutual));
      await network.as('bob').unfollow('me');
      // Mi ha già scritto lui: rispondo anche se non mi accetta.
      await messages.as('bob').send('me', 'eccomi');
      await network.publish(_profile('me', 'Alice', messages: MessagePolicy.nobody));
      await messages.as('bob').send('me', 'ancora');
      await messages.send('bob', 'ok');
      await network.as('carl').publish(_profile('carl', 'Carl'));
      await expectLater(messages.as('carl').send('me', 'ciao'), throwsA(isA<SocialRefused>()));

      await expectLater(messages.send('me', 'a me'), throwsA(isA<SocialRefused>()));
      await expectLater(messages.send('nessuno', 'x'), throwsA(isA<SocialRefused>()));
    });

    test('un blocco rifiuta come qualunque altro rifiuto; testi fuori forma non entrano', () async {
      await network.as('bob').block('me');
      await expectLater(messages.send('bob', 'ciao'), throwsA(isA<SocialRefused>()));
      await expectLater(messages.as('bob').send('me', 'ciao'), throwsA(isA<SocialRefused>()));
      await network.as('bob').unblock('me');
      await expectLater(messages.send('bob', '  '), throwsArgumentError);
      await expectLater(messages.send('bob', 'x' * 2001), throwsArgumentError);
      await expectLater(messages.send('bob', 'x', kind: MessageKind.extension), throwsArgumentError);
    });

    test('60 messaggi l\'ora', () async {
      for (var i = 0; i < 60; i++) {
        await messages.send('bob', 'm$i');
      }
      await expectLater(messages.send('bob', 'uno di troppo'), throwsA(isA<SocialRefused>()));
      now = now.add(const Duration(hours: 1, minutes: 1));
      await messages.send('bob', 'di nuovo');
    });

    test('la proroga: solo con la riga giusta, a chi condivide, una al giorno per condivisione', () async {
      messages.setEmail('me', 'Me@Example.com');
      messages.addShare('s1', from: 'bob', toEmail: 'me@example.com');
      messages.addShare('s2', from: 'bob', toEmail: 'altro@example.com');
      await network.as('bob').publish(_profile('bob', 'Bob', messages: MessagePolicy.nobody));

      // Qualunque sia il `messages` di chi condivide.
      await messages.send('bob', 'Manga', kind: MessageKind.extension, share: 's1');
      await expectLater(messages.send('bob', 'Manga', kind: MessageKind.extension, share: 's1'), throwsA(isA<SocialRefused>()));
      await expectLater(messages.send('bob', 'Manga', kind: MessageKind.extension, share: 's2'), throwsA(isA<SocialRefused>()));
      await expectLater(messages.send('bob', 'Manga', kind: MessageKind.extension, share: 'no'), throwsA(isA<SocialRefused>()));
      await network.as('carl').publish(_profile('carl', 'Carl'));
      await expectLater(messages.send('carl', 'Manga', kind: MessageKind.extension, share: 's1'), throwsA(isA<SocialRefused>()));
      // Non è un permesso di scrivere testo.
      await expectLater(messages.send('bob', 'ciao'), throwsA(isA<SocialRefused>()));

      now = now.add(const Duration(days: 1, minutes: 1));
      await messages.send('bob', 'Manga', kind: MessageKind.extension, share: 's1');
    });

    test('non letti, conversazioni, segnare letto e togliere', () async {
      await network.as('carl').publish(_profile('carl', 'Carl'));
      await messages.send('bob', 'uno');
      now = now.add(const Duration(minutes: 1));
      await messages.as('bob').send('me', 'due');
      now = now.add(const Duration(minutes: 1));
      await messages.as('bob').send('me', 'tre');
      now = now.add(const Duration(minutes: 1));
      await messages.as('carl').send('me', 'dal terzo');

      var list = await messages.conversations();
      expect([for (final c in list) (c.peer, c.unread, c.last.body, c.card?.name)], [
        ('carl', 1, 'dal terzo', 'Carl'),
        ('bob', 2, 'tre', 'Bob'),
      ]);
      expect([for (final m in await messages.thread('bob')) m.body], ['tre', 'due', 'uno']);
      expect([for (final m in await messages.thread('bob', limit: 1)) m.body], ['tre']);

      // Segna letto solo ciò che ha ricevuto chi chiama: Bob legge il mio «uno», non i suoi.
      await messages.as('bob').markRead('me');
      expect((await messages.conversations()).firstWhere((c) => c.peer == 'bob').unread, 2);
      await messages.markRead('bob');
      list = await messages.conversations();
      expect([for (final c in list) (c.peer, c.unread)], [('carl', 1), ('bob', 0)]);
      expect(messages.stored.firstWhere((m) => m.body == 'uno').readAt, isNotNull);
      expect(messages.stored.firstWhere((m) => m.body == 'dal terzo').readAt, isNull);

      // Se non vedo più il profilo, la conversazione resta col solo identificativo.
      await network.as('bob').block('me');
      expect((await messages.conversations()).firstWhere((c) => c.peer == 'bob').card, isNull);

      // Toglie uno dei due, non un terzo.
      final one = messages.stored.firstWhere((m) => m.body == 'uno');
      await messages.as('carl').remove(one.id);
      expect(messages.stored.map((m) => m.body), contains('uno'));
      await messages.as('bob').remove(one.id);
      expect(messages.stored.map((m) => m.body), isNot(contains('uno')));
    });

    test('il realtime arriva solo al destinatario', () async {
      var mine = 0;
      var bobs = 0;
      final a = messages.changes().listen((_) => mine++);
      final b = messages.as('bob').changes().listen((_) => bobs++);
      await messages.send('bob', 'ciao');
      await Future<void>.delayed(Duration.zero);
      expect((mine, bobs), (0, 1));
      await a.cancel();
      await b.cancel();
    });
  });

  test('DriveShare legge from_uid', () {
    final share = DriveShare.fromRow({'id': 'x', 'from_uid': 'u-1', 'from_email': 'a@b.c', 'to_email': 'd@e.f'});
    expect(share.fromUid, 'u-1');
    expect(share.copyWith(permissionId: 'p').fromUid, 'u-1');
    expect(share.toRow().containsKey('from_uid'), isFalse);
  });

  group('con l\'app', () {
    late KagamiDatabase db;
    var list = <SourceConfig>[];
    var rows = <DriveShare>[];

    setUp(() {
      db = KagamiDatabase.forTesting(NativeDatabase.memory());
      list = [];
      rows = [];
    });
    tearDown(() => db.close());

    List<Override> overrides() => [
          databaseProvider.overrideWithValue(db),
          socialBackendProvider.overrideWithValue(network),
          socialMessagesProvider.overrideWithValue(messages),
          socialMeProvider.overrideWithValue('me'),
          incomingSharesProvider.overrideWith((ref) => Stream.value(rows)),
          librarySourcesProvider.overrideWith(() => _Sources(list)),
        ];

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

    testWidgets('conversazione: scrivere, leggere, un rifiuto che non dice perché, eliminare', (tester) async {
      await messages.as('bob').send('me', 'ciao Alice');
      final c = await open(tester, const ConversationScreen(peer: 'bob', name: 'Bob'));
      expect(find.text('ciao Alice'), findsOneWidget);
      // Aprirla segna letto.
      expect(c.read(socialUnreadProvider), 0);
      expect(messages.stored.single.readAt, isNotNull);

      await tester.enterText(find.byType(TextField), 'ciao Bob');
      await tester.tap(find.byTooltip('Invia'));
      await settle(tester);
      expect(find.text('ciao Bob'), findsOneWidget);

      await network.as('bob').block('me');
      await tester.enterText(find.byType(TextField), 'più');
      await tester.tap(find.byTooltip('Invia'));
      await settle(tester);
      expect(find.text('Non è stato possibile completare l\'azione.'), findsOneWidget);
      expect(find.textContaining('bloccat'), findsNothing);

      await tester.longPress(find.text('ciao Bob'));
      await settle(tester);
      await tester.tap(find.text('Elimina'));
      await settle(tester);
      expect(find.text('ciao Bob'), findsNothing);
      expect(messages.stored.map((m) => m.body), ['ciao Alice']);
    });

    testWidgets('un messaggio arrivato a conversazione aperta si legge e si segna letto', (tester) async {
      await open(tester, const ConversationScreen(peer: 'bob', name: 'Bob'));
      await messages.as('bob').send('me', 'nuovo');
      await settle(tester);
      expect(find.text('nuovo'), findsOneWidget);
      expect(messages.stored.single.readAt, isNotNull);
    });

    testWidgets('elenco: non letti; la proroga dice «Rinnova» solo a chi condivide', (tester) async {
      messages.setEmail('me', 'me@x.it');
      messages.setEmail('bob', 'bob@x.it');
      messages.addShare('s1', from: 'bob', toEmail: 'me@x.it');
      messages.addShare('s2', from: 'me', toEmail: 'bob@x.it');
      await messages.send('bob', 'Manga di Bob', kind: MessageKind.extension, share: 's1');
      await messages.as('bob').send('me', 'Mia', kind: MessageKind.extension, share: 's2');
      await open(tester, const ConversationsScreen());
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.text('Bob'));
      await settle(tester);
      // L'elenco resta sotto la conversazione: si guarda dentro di lei.
      Finder inThread(String text) => find.descendant(of: find.byType(ConversationScreen), matching: find.text(text));
      expect(inThread('Hai chiesto più tempo per «Manga di Bob».'), findsOneWidget);
      expect(inThread('Bob chiede più tempo per «Mia».'), findsOneWidget);
      expect(inThread('Rinnova'), findsOneWidget);
    });

    testWidgets('«Chiedi più tempo» scrive a chi condivide, con la condivisione', (tester) async {
      messages.setEmail('me', 'me@x.it');
      messages.addShare('s1', from: 'bob', toEmail: 'me@x.it');
      list = [
        SourceConfig(
          id: 'src',
          kind: SourceKind.driveShared,
          label: 'Manga di Bob',
          params: const {'folderId': 'f1', 'owner': 'bob@x.it'},
        ),
      ];
      rows = [
        DriveShare(
          id: 's1',
          to: 'me@x.it',
          from: 'bob@x.it',
          fromUid: 'bob',
          folderId: 'f1',
          folderName: 'Manga di Bob',
          permissionId: 'p',
          at: DateTime(2026, 11, 1),
          expiresAt: DateTime(2026, 12, 1),
        ),
      ];
      await open(tester, const DriveReceivedSheet());
      await tester.tap(find.text('Chiedi più tempo'));
      await settle(tester);
      expect(find.text('Richiesta inviata.'), findsOneWidget);
      final sent = messages.stored.single;
      expect((sent.from, sent.to, sent.kind, sent.share, sent.body), ('me', 'bob', MessageKind.extension, 's1', 'Manga di Bob'));

      // Una al giorno: la seconda è rifiutata dalle regole e non scrive niente.
      await tester.tap(find.text('Chiedi più tempo'));
      await settle(tester);
      expect(messages.stored, hasLength(1));
    });
  });
}
