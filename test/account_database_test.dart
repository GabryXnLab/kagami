/// Un file SQLite per account: il nucleo che sceglie, adotta e nomina i file.
/// Sbagliare qui vuol dire scrivere i dati di un lettore nel file di un altro.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/db/account_databases.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_social.dart';
import 'package:kagami/src/ui/account_scope.dart';

import 'backend_fakes.dart';

Future<void> _putSetting(File file, String key, String value) async {
  final db = KagamiDatabase.forTesting(NativeDatabase(file));
  await db.into(db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
  await db.close();
}

Future<String?> _setting(File file, String key) async {
  final db = KagamiDatabase.forTesting(NativeDatabase(file));
  final row = await (db.select(db.appSettings)..where((t) => t.key.equals(key)))
      .getSingleOrNull();
  await db.close();
  return row?.value;
}

void main() {
  late Directory dir;
  late AccountDatabases accounts;
  late File legacy;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kagami-accounts');
    accounts = AccountDatabases(dir);
    legacy = File('${dir.path}/kagami.sqlite');
  });

  tearDown(() => dir.delete(recursive: true));

  group('nomi e validazione', () {
    test('slot e file', () {
      expect(AccountDatabases.guest, 'guest');
      expect(accounts.slotFor('abc-123'), 'u-abc-123');
      expect(accounts.fileFor('guest').path, '${dir.path}/kagami-guest.sqlite');
      expect(accounts.fileFor('u-abc-123').path,
          '${dir.path}/kagami-u-abc-123.sqlite');
    });

    test('un uid con / o .. è rifiutato', () {
      for (final bad in ['a/b', '../x', '..', '', 'a b', 'x' * 65]) {
        expect(() => accounts.slotFor(bad), throwsArgumentError, reason: bad);
      }
      expect(() => accounts.fileFor('u-../x'), throwsArgumentError);
      expect(() => accounts.fileFor('altro'), throwsArgumentError);
    });
  });

  group('nota dello slot', () {
    test('assente, scritta, riletta senza file temporanei', () async {
      expect(await accounts.readNote(), isA<SlotNoteAbsent>());
      await accounts.writeNote('u-abc');
      final note = await accounts.readNote();
      expect(note, isA<SlotNoteActive>());
      expect((note as SlotNoteActive).slot, 'u-abc');
      expect(dir.listSync().map((e) => e.path.split('/').last),
          ['kagami-slot.json']);
    });

    test('illeggibile: JSON rotto o slot non valido', () async {
      final note = File('${dir.path}/kagami-slot.json');
      await note.writeAsString('{rotto');
      expect(await accounts.readNote(), isA<SlotNoteUnreadable>());
      await note.writeAsString(jsonEncode({'slot': '../x'}));
      expect(await accounts.readNote(), isA<SlotNoteUnreadable>());
    });
  });

  group('adoptLegacy', () {
    test('le righe del vecchio file stanno nello slot adottato', () async {
      await _putSetting(legacy, 'k', 'v');
      expect(await accounts.adoptLegacy('u-a'), isTrue);
      expect(await _setting(accounts.fileFor('u-a'), 'k'), 'v');
      expect(legacy.existsSync(), isFalse);
      expect(File('${legacy.path}.adopted').existsSync(), isTrue);
      final note = await accounts.readNote();
      expect((note as SlotNoteActive).slot, 'u-a');
    });

    test('la seconda esecuzione non ha effetti', () async {
      await _putSetting(legacy, 'k', 'v');
      await accounts.adoptLegacy('u-a');
      await _putSetting(accounts.fileFor('u-a'), 'k', 'nuovo');
      expect(await accounts.adoptLegacy('u-b'), isFalse);
      expect(await _setting(accounts.fileFor('u-a'), 'k'), 'nuovo');
      expect(accounts.fileFor('u-b').existsSync(), isFalse);
      expect((await accounts.readNote() as SlotNoteActive).slot, 'u-a');
    });

    test('un target già presente resta intatto', () async {
      await _putSetting(legacy, 'k', 'vecchio');
      await _putSetting(accounts.fileFor('u-a'), 'k', 'del-target');
      await accounts.adoptLegacy('u-a');
      expect(await _setting(accounts.fileFor('u-a'), 'k'), 'del-target');
      expect(legacy.existsSync(), isFalse);
      expect(File('${legacy.path}.adopted').existsSync(), isTrue);
    });

    test('un file con il log WAL non ancora riportato è recuperato', () async {
      final src = Directory('${dir.path}/src')..createSync();
      final live = File('${src.path}/kagami.sqlite');
      final db = KagamiDatabase.forTesting(NativeDatabase(live));
      await db.customStatement('PRAGMA journal_mode=WAL');
      await db.customStatement('PRAGMA wal_autocheckpoint=0');
      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(key: 'k', value: 'nel-wal'),
          );
      // Copia mentre la connessione è aperta: la riga è solo nel -wal.
      live.copySync(legacy.path);
      File('${live.path}-wal').copySync('${legacy.path}-wal');
      expect(File('${legacy.path}-wal').lengthSync(), greaterThan(0));
      await db.close();

      await accounts.adoptLegacy('guest');
      expect(await _setting(accounts.fileFor('guest'), 'k'), 'nel-wal');
    });

    test('nota illeggibile: niente migrazione, niente riscrittura', () async {
      await _putSetting(legacy, 'k', 'v');
      final note = File('${dir.path}/kagami-slot.json');
      await note.writeAsString('{rotto');
      expect(await accounts.adoptLegacy('guest'), isFalse);
      expect(legacy.existsSync(), isTrue);
      expect(accounts.fileFor('guest').existsSync(), isFalse);
      expect(await note.readAsString(), '{rotto');
    });

    test('nota presente: niente migrazione', () async {
      await _putSetting(legacy, 'k', 'v');
      await accounts.writeNote('guest');
      expect(await accounts.adoptLegacy('u-a'), isFalse);
      expect(legacy.existsSync(), isTrue);
    });
  });

  test('KagamiDatabase.file apre il file indicato', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
    final file = accounts.fileFor('u-a');
    final db = KagamiDatabase.file(file);
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(key: 'k', value: 'v'),
        );
    await db.close();
    expect(await _setting(file, 'k'), 'v');
  });

  test('due slot sono isolati', () async {
    await _putSetting(accounts.fileFor('u-a'), 'k', 'di-a');
    await _putSetting(accounts.fileFor('u-b'), 'k', 'di-b');
    expect(await _setting(accounts.fileFor('u-a'), 'k'), 'di-a');
    expect(await _setting(accounts.fileFor('u-b'), 'k'), 'di-b');
    expect(await _setting(accounts.fileFor('guest'), 'k'), isNull);
  });

  group('nextSlot', () {
    test('null non cambia', () {
      expect(nextSlot('u-a', const SessionChanged(null)), 'u-a');
      expect(nextSlot('guest', const SessionChanged(null)), 'guest');
    });
    test('uid diverso o uguale', () {
      expect(nextSlot('guest', const SessionChanged('a')), 'u-a');
      expect(nextSlot('u-a', const SessionChanged('b')), 'u-b');
      expect(nextSlot('u-a', const SessionChanged('a')), 'u-a');
    });
    test('uscita esplicita va a guest', () {
      expect(nextSlot('u-a', const SignedOut()), 'guest');
      expect(nextSlot('guest', const SignedOut()), 'guest');
    });
  });

  group('contenitore per slot', () {
    late AccountSlots slots;
    late WidgetRef probe;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path,
      );
    });

    Widget app() => AccountScope(
          slots: slots,
          directories: const AppDirectories(support: '/tmp/x', cache: '/tmp/y'),
          child: MaterialApp(
            home: Consumer(builder: (context, ref, _) {
              probe = ref;
              return const SizedBox();
            }),
          ),
        );

    Future<void> insert(KagamiDatabase db, String key) =>
        db.into(db.appSettings).insertOnConflictUpdate(
              AppSettingsCompanion.insert(key: key, value: 'v'),
            );

    testWidgets('cambiare slot chiude il file vecchio e apre solo l\'altro',
        (tester) async {
      await tester.runAsync(() => _putSetting(accounts.fileFor('u-b'), 'di-b', 'v'));
      slots = AccountSlots(accounts, AccountDatabases.guest);
      await tester.pumpWidget(app());
      expect(probe.read(databaseSlotProvider), 'guest');
      expect(probe.read(backupSlotProvider), 'guest');
      // Nella zona reale: un database creato dentro il tempo finto non avanzerebbe.
      final old = (await tester.runAsync(() async => probe.read(databaseProvider)))!;
      await tester.runAsync(() => insert(old, 'di-guest'));

      await tester.runAsync(() => slots.switchTo('u-b'));
      await tester.pump();
      expect(probe.read(databaseSlotProvider), 'u-b');
      expect(probe.read(backupSlotProvider), 'u-b');
      final fresh = (await tester.runAsync(() async => probe.read(databaseProvider)))!;
      expect(fresh, isNot(same(old)));

      await tester.runAsync(() async {
        await expectLater(insert(old, 'tardiva'), throwsA(anything));
        final rows = await fresh.select(fresh.appSettings).get();
        expect(rows.map((r) => r.key), ['di-b']);
        await fresh.close();
        expect(await _setting(accounts.fileFor('guest'), 'di-guest'), 'v');
        expect(await _setting(accounts.fileFor('guest'), 'tardiva'), isNull);
        expect(await _setting(accounts.fileFor('u-b'), 'tardiva'), isNull);
      });
    });
  });

  group('slot che segue l\'account (F9.5)', () {
    late AccountSlots slots;
    late StreamController<String?> auth;
    late List<Object> errors;

    setUp(() {
      slots = AccountSlots(accounts, AccountDatabases.guest);
      auth = StreamController<String?>();
      errors = [];
      slots.follow(auth.stream, onError: errors.add);
    });

    tearDown(() => auth.close());

    Future<void> settle() async {
      await Future<void>.delayed(Duration.zero);
      await slots.idle;
    }

    test('una sessione persa non cambia slot, un uid sì, l\'uscita torna a guest', () async {
      auth.add('a');
      await settle();
      expect(slots.value, 'u-a');
      expect(await accounts.readNote(), isA<SlotNoteActive>().having((n) => n.slot, 'slot', 'u-a'));

      auth.add(null);
      await settle();
      expect(slots.value, 'u-a');

      auth.add('../x');
      await settle();
      expect(slots.value, 'u-a');

      auth.add('b');
      await settle();
      expect(slots.value, 'u-b');

      await slots.leave();
      expect(slots.value, 'guest');
      expect(await accounts.readNote(), isA<SlotNoteActive>().having((n) => n.slot, 'slot', 'guest'));
      expect(errors, isEmpty);
    });
  });

  group('CloudAccountNotifier con gli slot (F9.5)', () {
    late KagamiDatabase db;
    late MemoryReaderStore store;
    late _FakeAuth auth;

    setUp(() {
      db = KagamiDatabase.forTesting(NativeDatabase.memory());
      store = MemoryReaderStore();
      auth = _FakeAuth();
    });

    tearDown(() => db.close());

    ProviderContainer open(String slot, AccountSlots slots) {
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        databaseSlotProvider.overrideWithValue(slot),
        accountSlotsProvider.overrideWithValue(slots),
        cloudAuthProvider.overrideWithValue(auth),
        readerStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('signIn da guest non manda il file guest nella riga del nuovo account', () async {
      await UserRepository(db).markChapters('mangak:S1', ['C1'], true, at: DateTime.utc(2026, 5, 1));
      final slots = AccountSlots(accounts, AccountDatabases.guest);
      // L'evento di auth che cambia slot non è ancora arrivato: il vecchio
      // contenitore è ancora montato quando `signIn` torna.
      auth.next = const CloudAccount(id: 'b', email: 'b@x');
      await open(AccountDatabases.guest, slots).read(cloudAccountProvider.notifier).signIn();
      expect((store.reads, store.writes), (0, 0));
      expect(store.row, isNull);
    });

    test('signOut manda su i dati e poi torna a guest', () async {
      final slots = AccountSlots(accounts, 'u-a');
      auth.current = const CloudAccount(id: 'a', email: 'a@x');
      await open('u-a', slots).read(cloudAccountProvider.notifier).signOut();
      expect(store.writes, 1);
      expect(auth.signedOut, isTrue);
      expect(slots.value, AccountDatabases.guest);
    });

    test('la pubblicazione social non parte con una sessione che non è dello slot', () async {
      final network = MemorySocial('b');
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        databaseSlotProvider.overrideWithValue(AccountDatabases.guest),
        cloudAuthProvider.overrideWithValue(auth),
        socialBackendProvider.overrideWithValue(network),
        socialDraftProvider.overrideWith(
          (ref) async => buildPublicProfile(
            uid: 'b',
            settings: await ref.watch(socialSettingsProvider.future),
            statistics: const ReadingStatistics(
              chaptersRead: 1,
              pagesRead: 0,
              timeRead: Duration.zero,
              perDay: {},
              perMonth: {},
              topSeries: [],
              firstRead: null,
            ),
            series: const [],
            hidden: const {},
            now: DateTime(2026, 11, 14),
          ),
        ),
      ]);
      addTearDown(container.dispose);
      for (final e in const SocialSettings(enabled: true, name: 'Alice').toSettings().entries) {
        await UserRepository(db).writeSetting(e.key, e.value);
      }
      auth.current = const CloudAccount(id: 'b', email: 'b@x');
      expect(await container.read(socialControllerProvider.notifier).publish(force: true), isNull);
      expect(network.calls, isEmpty);
    });

    test('signOut con la sessione persa: niente backend, solo guest', () async {
      final slots = AccountSlots(accounts, 'u-a');
      await open('u-a', slots).read(cloudAccountProvider.notifier).signOut();
      expect((store.reads, store.writes), (0, 0));
      expect(slots.value, AccountDatabases.guest);
    });
  });
}

class _FakeAuth implements CloudAuth {
  @override
  CloudAccount? current;
  CloudAccount? next;
  bool signedOut = false;

  @override
  Stream<CloudAccount?> changes() => const Stream.empty();

  @override
  Future<CloudAccount?> signIn() async => current = next;

  @override
  Future<void> signOut() async {
    signedOut = true;
    current = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
