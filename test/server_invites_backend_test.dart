/// Gli inviti a un server sul backend: la scrittura e la lettura contro un
/// PostgREST finto, e l'ascolto (rilettura, errori, funzione non disponibile)
/// contro la copia in memoria.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/backend.dart';
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/invite_store.dart';
import 'package:kagami/src/data/server_access.dart';
import 'package:kagami_archive/remote.dart' show ServerUnauthorized;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_fakes.dart';

const _me = CloudAccount(id: 'u1', email: 'Owner@Example.com', name: 'Owner');

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  final url = Uri.parse('https://server.example.com');

  group('ServerAccess sugli inviti', () {
    late MemoryInviteStore store;
    late ServerAccess access;

    setUp(() {
      store = MemoryInviteStore();
      access = ServerAccess(invites: store, account: () => _me);
    });

    test('invito: id sha256 a 32 caratteri, destinatario minuscolo, mittente dalla sessione', () async {
      await access.invite(to: 'Friend@Example.com', url: url, serverName: 'Casa');
      final invite = store.invites.values.single;
      expect(invite.id, hasLength(32));
      expect(invite.id, ServerAccess.inviteId('owner@example.com', 'friend@example.com', url));
      expect(invite.to, 'friend@example.com');
      expect(invite.from, 'owner@example.com');
      expect(invite.fromName, 'Owner');
      expect(invite.url, '$url');
      // Lo stesso amico due volte è lo stesso invito.
      await access.invite(to: 'FRIEND@example.com', url: url, serverName: 'Casa');
      expect(store.invites, hasLength(1));
    });

    test('l\'id contiene il mittente: chi scrive per primo non occupa quello del proprietario', () async {
      // Eve scrive l'invito con l'id che l'app calcolava da destinatario e indirizzo.
      final squat = ServerInvite(
        id: sha256.convert(utf8.encode('friend@example.com|$url')).toString().substring(0, 32),
        to: 'friend@example.com',
        from: 'eve@example.com',
        url: '$url',
        serverName: 'Eve',
      );
      await store.put(squat);
      await access.invite(to: 'friend@example.com', url: url, serverName: 'Casa');
      expect(store.invites, hasLength(2));
      expect(store.invites[ServerAccess.inviteId('owner@example.com', 'friend@example.com', url)]?.serverName, 'Casa');
      expect(store.invites[squat.id]?.from, 'eve@example.com');
      expect(ServerAccess.inviteId('eve@example.com', 'friend@example.com', url),
          isNot(ServerAccess.inviteId('owner@example.com', 'friend@example.com', url)));
    });

    test('un invito di prima (id senza mittente) si legge e si toglie', () async {
      final legacy = ServerInvite(
        id: sha256.convert(utf8.encode('friend@example.com|$url')).toString().substring(0, 32),
        to: 'friend@example.com',
        from: 'owner@example.com',
        url: '$url',
        serverName: 'Casa',
      );
      await store.put(legacy);
      expect([for (final i in await access.invitesFor('friend@example.com')) i.id], [legacy.id]);
      // Lo toglie il proprietario...
      await access.withdraw('friend@example.com', url);
      expect(store.invites, isEmpty);
      // ...e chi lo riceve, che non sa calcolare l'id: tutti quelli per sé a quell'indirizzo.
      final friend = ServerAccess(invites: store, account: () => const CloudAccount(id: 'u2', email: 'Friend@example.com'));
      await store.put(legacy);
      await access.invite(to: 'friend@example.com', url: url, serverName: 'Casa');
      await access.invite(to: 'friend@example.com', url: Uri.parse('https://altro.example.com'), serverName: 'Altro');
      await friend.withdraw('friend@example.com', url);
      expect([for (final i in store.invites.values) i.url], ['https://altro.example.com']);
    });

    test('senza sessione non scrive', () async {
      final nobody = ServerAccess(invites: store, account: () => null);
      await expectLater(
        nobody.invite(to: 'a@example.com', url: url, serverName: 'Casa'),
        throwsA(isA<ServerUnauthorized>()),
      );
      expect(store.invites, isEmpty);
    });

    test('elenco per destinatario e ritiro', () async {
      await access.invite(to: 'a@example.com', url: url, serverName: 'Casa');
      await access.invite(to: 'b@example.com', url: url, serverName: 'Casa');
      expect([for (final i in await access.invitesFor('A@Example.com')) i.to], ['a@example.com']);
      await access.withdraw('A@example.com', url);
      expect(await access.invitesFor('a@example.com'), isEmpty);
      expect(await access.invitesFor('b@example.com'), hasLength(1));
    });
  });

  group('watchServerInvites', () {
    late MemoryInviteStore store;
    late ServerAccess access;
    late List<List<ServerInvite>> seen;
    late StreamSubscription<List<ServerInvite>> subscription;
    late StreamController<void> resumed;

    setUp(() async {
      store = MemoryInviteStore();
      access = ServerAccess(invites: store, account: () => _me);
      await access.invite(to: 'me@example.com', url: url, serverName: 'Casa');
      seen = [];
      resumed = StreamController<void>();
      subscription = watchServerInvites(access, 'me@example.com', resumed: resumed.stream).listen(seen.add);
      await _settle();
    });

    tearDown(() async {
      await subscription.cancel();
      await resumed.close();
    });

    test('legge all\'avvio, e rilegge al ritorno in primo piano e a un evento', () async {
      expect(seen, hasLength(1));
      await access.invite(to: 'me@example.com', url: Uri.parse('https://altro.example.com'), serverName: 'Altro');
      resumed.add(null);
      await _settle();
      expect(seen.last, hasLength(2));
      await access.withdraw('me@example.com', url);
      store.notifyChanged();
      await _settle();
      expect(seen.last.single.serverName, 'Altro');
    });

    test('una rilettura che fallisce lascia l\'elenco di prima', () async {
      store.readError = const SocketException('giù');
      resumed.add(null);
      await _settle();
      expect(seen, hasLength(1));
      expect(seen.single, hasLength(1));
      store.readError = null;
      resumed.add(null);
      await _settle();
      expect(seen, hasLength(2));
    });

    test('tabella non disponibile: nessun crash e non si riprova', () async {
      store.readError = PostgrestException(message: 'permission denied', code: '42501');
      final before = store.reads;
      resumed.add(null);
      await _settle();
      expect(store.reads, before + 1);
      store.readError = null;
      resumed.add(null);
      await _settle();
      expect(store.reads, before + 1);
      expect(seen, hasLength(1));
    });
  });

  group('SupabaseInviteStore contro un PostgREST finto', () {
    late HttpServer server;
    late SupabaseClient client;
    late List<HttpRequest> requests;
    late List<Object?> bodies;
    late List<Map<String, Object?>> rows;
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
        final response = request.response..headers.contentType = ContentType.json;
        if (failure case final error?) {
          response.statusCode = 401;
          response.write(jsonEncode(error));
        } else if (request.method == 'GET') {
          response.write(jsonEncode(rows));
        } else {
          response.statusCode = request.method == 'POST' ? 201 : 204;
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
      String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final exp = DateTime.now().add(const Duration(hours: 1));
      final token = [
        part({'alg': 'HS256', 'typ': 'JWT'}),
        part({'sub': 'u1', 'exp': exp.millisecondsSinceEpoch ~/ 1000}),
        'firma',
      ].join('.');
      await client.auth.recoverSession(jsonEncode({
        'access_token': token,
        'token_type': 'bearer',
        'refresh_token': 'r',
        'user': {
          'id': 'u1',
          'aud': 'authenticated',
          'email': 'owner@example.com',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
          'created_at': '2026-11-13T00:00:00Z',
        },
      }));
    }

    test('senza sessione non chiede niente', () async {
      final store = SupabaseInviteStore(client: client);
      await expectLater(store.listFor('a@example.com'), throwsA(isA<AuthSessionMissingException>()));
      await expectLater(store.remove('x'), throwsA(isA<AuthSessionMissingException>()));
      expect(requests, isEmpty);
    });

    test('scrive con upsert le colonne dello schema, legge per to_email, ritira per id', () async {
      await signIn();
      final store = SupabaseInviteStore(client: client);
      await store.put(const ServerInvite(
        id: 'abc',
        to: 'a@example.com',
        from: 'owner@example.com',
        fromName: 'Owner',
        url: 'https://server.example.com',
        serverName: 'Casa',
      ));
      expect(requests.last.method, 'POST');
      expect(requests.last.headers.value('prefer'), contains('merge-duplicates'));
      expect(bodies.last, {
        'id': 'abc',
        'to_email': 'a@example.com',
        'from_email': 'owner@example.com',
        'from_name': 'Owner',
        'url': 'https://server.example.com',
        'server_name': 'Casa',
      });

      rows = [
        {
          'id': 'abc',
          'to_email': 'a@example.com',
          'from_email': 'owner@example.com',
          'from_name': null,
          'url': 'https://server.example.com',
          'server_name': 'Casa',
          'at': '2026-11-13T00:00:00Z',
        },
      ];
      final list = await store.listFor('A@Example.com');
      expect(requests.last.uri.path, '/rest/v1/server_invites');
      expect(requests.last.uri.queryParameters['to_email'], 'eq.a@example.com');
      expect((list.single.id, list.single.sender, list.single.serverName), ('abc', 'owner@example.com', 'Casa'));

      await store.remove('abc');
      expect(requests.last.method, 'DELETE');
      expect(requests.last.uri.queryParameters['id'], 'eq.abc');
    });

    test('tabella non concessa: lancia, ed è «non disponibile»', () async {
      await signIn();
      failure = {'code': '42501', 'message': 'permission denied for table server_invites'};
      final error = await SupabaseInviteStore(client: client)
          .listFor('a@example.com')
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(backendFailure(error!), BackendFailure.unavailable);
    });
  });
}
