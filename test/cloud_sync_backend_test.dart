/// La sincronizzazione dei dati personali contro il backend: si fonde solo se
/// un altro ha scritto, una riga che non c'è non è un errore, e un errore non
/// è mai una riga che non c'è.
///
/// Senza `TestWidgetsFlutterBinding`: sotto quello le richieste HTTP vere
/// sono bloccate, e la seconda parte parla con un PostgREST finto in locale.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/backend.dart';
import 'package:kagami/src/data/backup.dart';
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/reader_store.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_fakes.dart';

/// Un telefono: il suo database e la sua sincronizzazione.
class _Device {
  _Device(ReaderStore store, {String slot = 'u-a', String? session = 'a'})
      : db = KagamiDatabase.forTesting(NativeDatabase.memory()) {
    user = UserRepository(db);
    sync = CloudSync(BackupService(db), user, store, slot: slot, sessionUid: () => session);
  }

  final KagamiDatabase db;
  late final UserRepository user;
  late final CloudSync sync;

  Future<void> read(String chapter) =>
      user.markChapters('mangak:S1', [chapter], true, at: DateTime.utc(2026, 5, 1));

  Future<Set<String>> chapters() async =>
      (await user.loadStates())['mangak:S1']?.readChapters ?? const {};
}

void main() {
  // Due telefoni sono due database aperti insieme, di proposito.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('CloudSync', () {
    late MemoryReaderStore store;
    late _Device phone;

    setUp(() {
      store = MemoryReaderStore();
      phone = _Device(store);
    });

    tearDown(() => phone.db.close());

    test('riga assente: carica i dati di qui senza fondere', () async {
      await phone.read('C1');
      final result = (await phone.sync.sync())!;
      expect(result.merged, isFalse);
      expect(store.writes, 1);
      expect(store.row!.device, Platform.operatingSystem);
      expect(await phone.sync.lastSync(), isNotNull);

      // Quello che è salito è il backup di questo telefono.
      final other = _Device(store);
      addTearDown(other.db.close);
      expect((await other.sync.sync())!.merged, isTrue);
      expect(await other.chapters(), {'C1'});
    });

    test('fonde solo se la revisione è cambiata da quella vista', () async {
      await phone.read('C1');
      await phone.sync.sync();
      // Nessun altro ha scritto: la stessa revisione non si rifonde.
      expect((await phone.sync.sync())!.merged, isFalse);

      final tablet = _Device(store);
      addTearDown(tablet.db.close);
      await tablet.read('C2');
      // Il tablet non aveva mai visto la riga: fonde, e manda su l'unione.
      expect((await tablet.sync.sync())!.merged, isTrue);
      expect(await tablet.chapters(), {'C1', 'C2'});

      // Il telefono trova una revisione che non è la sua: fonde.
      expect((await phone.sync.sync())!.merged, isTrue);
      expect(await phone.chapters(), {'C1', 'C2'});
    });

    test('lettura fallita: sync lancia e non scrive niente', () async {
      await phone.read('C1');
      store.readError = const SocketException('giù');
      await expectLater(phone.sync.sync(), throwsA(isA<SocketException>()));
      expect(store.writes, 0);
      expect(store.row, isNull);
      expect(await phone.sync.lastSync(), isNull);
    });

    test('forget toglie la riga, i dati di qui restano', () async {
      await phone.read('C1');
      await phone.sync.sync();
      await phone.sync.forget();
      expect(store.row, isNull);
      expect(store.deletes, 1);
      expect(await phone.sync.lastSync(), isNull);
      expect(await phone.chapters(), {'C1'});
      // Dopo, la prima sincronizzazione non ha niente da fondere.
      expect((await phone.sync.sync())!.merged, isFalse);
    });

    // F9: il file di uno slot non va mai nella riga di un'altra sessione.
    for (final (slot, session) in [('guest', 'b'), ('u-a', 'b'), ('u-a', null)]) {
      test('slot $slot con sessione $session: il backend non si tocca', () async {
        final stranger = _Device(store, slot: slot, session: session);
        addTearDown(stranger.db.close);
        await stranger.read('C1');
        expect(await stranger.sync.sync(), isNull);
        expect(await stranger.sync.forget(), isFalse);
        expect((store.reads, store.writes, store.deletes), (0, 0, 0));
        expect(store.row, isNull);
      });
    }
  });

  group('SupabaseReaderStore contro un PostgREST finto', () {
    const uid = '00000000-0000-4000-8000-000000000001';
    late HttpServer server;
    late SupabaseClient client;
    late List<HttpRequest> requests;
    late List<Object?> bodies;
    // Le righe della tabella `readers`, come le darebbe il backend.
    late List<Map<String, Object?>> rows;
    // Se impostato, la prossima risposta è questo errore di PostgREST.
    Map<String, Object?>? failure;

    setUp(() async {
      requests = [];
      bodies = [];
      rows = [];
      failure = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add(request);
        final text = await utf8.decodeStream(request);
        bodies.add(text.isEmpty ? null : jsonDecode(text));
        final response = request.response
          ..headers.contentType = ContentType.json;
        if (failure case final error?) {
          response.statusCode = 401;
          response.write(jsonEncode(error));
        } else if (request.method == 'GET') {
          response.write(jsonEncode(rows));
        } else if (request.method == 'POST') {
          response.statusCode = 201;
        } else {
          response.statusCode = 204;
        }
        await response.close();
      });
      client = SupabaseClient(
        'http://${server.address.host}:${server.port}',
        'chiave',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    Future<void> signIn() async {
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final exp = DateTime.now().add(const Duration(hours: 1));
      final token = [
        part({'alg': 'HS256', 'typ': 'JWT'}),
        part({'sub': uid, 'exp': exp.millisecondsSinceEpoch ~/ 1000}),
        'firma',
      ].join('.');
      await client.auth.recoverSession(jsonEncode({
        'access_token': token,
        'token_type': 'bearer',
        'refresh_token': 'r',
        'user': {
          'id': uid,
          'aud': 'authenticated',
          'email': 'lettore@example.com',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
          'created_at': '2026-11-13T00:00:00Z',
        },
      }));
    }

    test('senza sessione non chiede niente: «non sei entrato»', () async {
      final store = SupabaseReaderStore(client);
      await expectLater(store.read(), throwsA(isA<AuthSessionMissingException>()));
      await expectLater(
        store.write(ReaderRow(payload: Uint8List(1), revision: 'r')),
        throwsA(isA<AuthSessionMissingException>()),
      );
      expect(requests, isEmpty);
      expect(backendFailure(AuthSessionMissingException()), BackendFailure.signedOut);
      // Una build senza backend è lo stesso caso.
      await expectLater(
        SupabaseReaderStore(null).read(),
        throwsA(isA<AuthSessionMissingException>()),
      );
    });

    test('riga assente: null, e la nuova nasce con l\'uid', () async {
      await signIn();
      final store = SupabaseReaderStore(client);
      expect(await store.read(), isNull);
      final get = requests.single;
      expect(get.uri.path, '/rest/v1/readers');
      expect(get.uri.queryParameters['owner'], 'eq.$uid');
      expect(get.uri.queryParameters['order'], startsWith('updated_at.desc'));
      expect(get.uri.queryParameters['limit'], '1');

      await store.write(ReaderRow(
        payload: Uint8List.fromList([1, 2, 3]),
        revision: 'rev1',
        device: 'android',
      ));
      expect(requests.last.method, 'POST');
      expect(requests.last.headers.value('prefer'), contains('merge-duplicates'));
      expect(bodies.last, {
        'id': uid,
        'data': {'payload': base64Encode([1, 2, 3]), 'revision': 'rev1', 'device': 'android'},
      });
    });

    test('una riga importata tiene il suo id', () async {
      await signIn();
      rows = [
        {
          'id': 'uid-di-allora',
          'data': {'payload': base64Encode([9]), 'revision': 'vecchia', 'device': 'ios'},
        },
      ];
      final store = SupabaseReaderStore(client);
      final row = await store.read();
      expect(row!.payload, [9]);
      expect(row.revision, 'vecchia');
      expect(row.device, 'ios');
      await store.write(ReaderRow(payload: Uint8List(0), revision: 'nuova'));
      final body = bodies.last as Map;
      expect(body['id'], 'uid-di-allora');
      expect(body.containsKey('updated_at'), isFalse);
      expect(body.containsKey('owner'), isFalse);
    });

    test('data senza payload è una riga vuota; payload rotto è un errore', () async {
      await signIn();
      final store = SupabaseReaderStore(client);
      rows = [
        {'id': uid, 'data': <String, Object?>{}},
      ];
      expect(await store.read(), isNull);
      rows = [
        {
          'id': uid,
          'data': {'payload': 'non è base64!', 'revision': 'r'},
        },
      ];
      await expectLater(store.read(), throwsA(isA<FormatException>()));
    });

    test('permesso negato o tabella assente: lancia, mai null', () async {
      await signIn();
      final store = SupabaseReaderStore(client);
      failure = {'code': '42501', 'message': 'permission denied for table readers'};
      final error = await store.read().then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<PostgrestException>());
      expect(backendFailure(error!), BackendFailure.unavailable);
    });

    test('delete toglie la riga per proprietario', () async {
      await signIn();
      await SupabaseReaderStore(client).delete();
      expect(requests.single.method, 'DELETE');
      expect(requests.single.uri.queryParameters['owner'], 'eq.$uid');
    });
  });
}
