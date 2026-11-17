/// La scadenza degli accessi: `expiry` (docs/server-api.md, «Utenti»).
library;

import 'dart:convert';
import 'dart:io';

import 'package:kagami_server/kagami_server.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  const owner = 'owner@example.com';
  const friend = 'amico@example.com';
  late TestServer server;
  late DateTime clock;
  final http = HttpClient();

  setUp(() async {
    clock = DateTime.utc(2026, 11, 13, 12);
    server = await TestServer.start(owner: owner, now: () => clock);
    await server.ready(owner);
  });
  tearDown(() => server.close());

  Future<(int, Map<String, Object?>?)> call(String method, String path, {Object? body, String as = owner}) async {
    final request = await http.openUrl(method, server.address.replace(path: path));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer tok:$as');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text) as Map<String, Object?>);
  }

  String? code(Map<String, Object?>? body) => (body?['error'] as Map?)?['code'] as String?;
  String at(Duration d) => clock.add(d).toIso8601String();

  Future<void> admit(Duration d) async {
    final (status, body) = await call('POST', '/v2/users', body: {'email': friend, 'expiresAt': at(d)});
    expect(status, 201);
    expect((body!['user'] as Map)['expiresAt'], at(d));
    await server.ready(friend);
  }

  test('il server elenca expiry, e me.expiresAt per chi scade', () async {
    final (_, info) = await call('GET', '/v2/server');
    expect(info!['features'], contains('expiry'));
    expect((info['me'] as Map).containsKey('expiresAt'), isFalse);
    await admit(const Duration(days: 7));
    final (_, mine) = await call('GET', '/v2/server', as: friend);
    expect((mine!['me'] as Map)['expiresAt'], at(const Duration(days: 7)));
    expect((mine['me'] as Map).containsKey('expired'), isFalse);
  });

  test('alla scadenza lo spazio è cancellato subito, a ogni richiesta', () async {
    await admit(const Duration(days: 7));
    expect((await call('GET', '/v2/jobs', as: friend)).$1, 200);
    final space = server.spaces[friend]!;
    clock = clock.add(const Duration(days: 8));

    final (status, body) = await call('GET', '/v2/jobs', as: friend);
    expect((status, code(body)), (403, 'not_allowed'));
    expect(space.destroyed, isTrue);
    expect(await server.accounts.find(friend), isNull);

    final (_, list) = await call('GET', '/v2/users');
    expect((list!['users'] as List).cast<Map>().any((r) => r['email'] == friend), isFalse);
  });

  test('anche la passata oraria toglie lo scaduto, senza periodo di grazia', () async {
    await admit(const Duration(days: 1));
    final space = server.spaces[friend]!;
    clock = clock.add(const Duration(hours: 23));
    await server.accounts.sweep();
    expect(space.destroyed, isFalse);
    clock = clock.add(const Duration(hours: 2));
    await server.accounts.sweep();
    expect(space.destroyed, isTrue);
    expect(await server.accounts.find(friend), isNull);
  });

  test('prima della scadenza il rinnovo tiene lo spazio, dopo non c\'è più chi rinnovare', () async {
    await admit(const Duration(days: 7));
    final space = server.spaces[friend]!;
    clock = clock.add(const Duration(days: 6));
    final (status, body) = await call('PUT', '/v2/users/$friend', body: {'expiresAt': at(const Duration(days: 30))});
    expect(status, 200);
    expect(server.spaces[friend], same(space));
    clock = clock.add(const Duration(days: 10));
    expect((await call('GET', '/v2/jobs', as: friend)).$1, 200);

    // null toglie la scadenza.
    final (_, open) = await call('PUT', '/v2/users/$friend', body: {'expiresAt': null});
    expect((open!['user'] as Map).containsKey('expiresAt'), isFalse);

    await call('PUT', '/v2/users/$friend', body: {'expiresAt': at(const Duration(days: 1))});
    clock = clock.add(const Duration(days: 2));
    await server.accounts.sweep();
    expect((await call('PUT', '/v2/users/$friend', body: {'expiresAt': null})).$1, 404);
  });

  test('prima della scadenza l\'utente può ritirare il permesso di Drive', () async {
    await admit(const Duration(days: 7));
    expect((await call('DELETE', '/v2/me/drive', as: friend)).$1, 204);
    expect(await server.spaces[friend]!.drive.authorized, isFalse);
  });

  test('POST su un account già ammesso cambia la scadenza', () async {
    await admit(const Duration(days: 7));
    final (_, body) = await call('POST', '/v2/users', body: {'email': friend, 'expiresAt': at(const Duration(days: 90))});
    expect((body!['user'] as Map)['expiresAt'], at(const Duration(days: 90)));
    final (_, same) = await call('POST', '/v2/users', body: {'email': friend});
    expect((same!['user'] as Map)['expiresAt'], at(const Duration(days: 90)));
  });

  test('la scadenza sopravvive alla rilettura di users.json', () async {
    await admit(const Duration(days: 7));
    final again = Accounts(server.accounts.file, owner: owner, open: (_) => throw UnimplementedError(), now: () => clock);
    expect((await again.find(friend))!.expiresAt, DateTime.parse(at(const Duration(days: 7))));
  });

  test('date passate o illeggibili, proprietario e sconosciuti', () async {
    for (final value in [at(const Duration(days: -1)), 'domani', 3]) {
      final (status, body) = await call('POST', '/v2/users', body: {'email': friend, 'expiresAt': value});
      expect((status, code(body)), (400, 'bad_request'), reason: '$value');
    }
    expect(code((await call('PUT', '/v2/users/$owner', body: {'expiresAt': null})).$2), 'bad_request');
    expect((await call('PUT', '/v2/users/nessuno@example.com', body: {'expiresAt': null})).$1, 404);
    await server.accounts.add(friend);
    expect(code((await call('PUT', '/v2/users/$owner', body: {'expiresAt': at(const Duration(days: 1))}, as: friend)).$2),
        'owner_only');
  });
}
