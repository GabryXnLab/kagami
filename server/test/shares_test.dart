/// Le condivisioni ritirate alla scadenza: `shares`, `PUT /v2/me/shares`
/// (docs/server-api.md).
library;

import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  const owner = 'owner@example.com';
  const friend = 'amico@example.com';
  late TestServer server;
  late DateTime clock;
  final http = HttpClient();

  setUp(() async {
    clock = DateTime.utc(2026, 11, 14, 12);
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
  Map<String, Object?> share(String id, Duration d) => {'folderId': 'cartella', 'permissionId': id, 'expiresAt': at(d)};
  Future<List<String>> held([String as = owner]) async => [
        for (final row in ((await call('GET', '/v2/me/shares', as: as)).$2!['shares'] as List).cast<Map>())
          row['permissionId'] as String,
      ];
  FakeDrive driveOf(String email) => server.spaces[email]!.drive;

  test('il server elenca shares; l\'elenco si sostituisce intero e torna in UTC', () async {
    final (_, info) = await call('GET', '/v2/server');
    expect(info!['features'], contains('shares'));
    expect(await held(), isEmpty);

    final (status, body) = await call('PUT', '/v2/me/shares', body: {
      'shares': [
        share('a', const Duration(days: 1)),
        {'folderId': 'cartella', 'permissionId': 'b', 'expiresAt': '2026-12-01T13:00:00+01:00'},
      ],
    });
    expect(status, 200);
    expect(body!['shares'], [
      share('a', const Duration(days: 1)),
      {'folderId': 'cartella', 'permissionId': 'b', 'expiresAt': '2026-12-01T12:00:00.000Z'},
    ]);
    expect(await held(), ['a', 'b']);

    await call('PUT', '/v2/me/shares', body: {'shares': [share('c', const Duration(days: 2))]});
    expect(await held(), ['c']);
    await call('PUT', '/v2/me/shares', body: {'shares': <Object?>[]});
    expect(await held(), isEmpty);
  });

  test('ognuno ha il suo elenco', () async {
    await server.accounts.add(friend);
    await server.ready(friend);
    await call('PUT', '/v2/me/shares', body: {'shares': [share('mia', const Duration(days: 1))]});
    expect(await held(friend), isEmpty);
  });

  test('scaduta: unshare e voce tolta; non scaduta: non toccata', () async {
    await call('PUT', '/v2/me/shares', body: {
      'shares': [share('vecchia', const Duration(hours: 1)), share('nuova', const Duration(days: 3))],
    });
    await server.accounts.sweepShares();
    expect(driveOf(owner).unshared, isEmpty);

    clock = clock.add(const Duration(hours: 2));
    await server.accounts.sweepShares();
    expect(driveOf(owner).unshared, ['cartella/vecchia']);
    expect(await held(), ['nuova']);
  });

  test('Drive che non risponde: la voce resta e si riprova al giro dopo, le altre vanno avanti', () async {
    await server.accounts.add(friend);
    await server.ready(friend);
    await call('PUT', '/v2/me/shares', body: {'shares': [share('x', Duration.zero)]});
    await call('PUT', '/v2/me/shares', body: {'shares': [share('y', Duration.zero)]}, as: friend);
    driveOf(owner).unshareError = const DriveOffline('Google non risponde');

    final lines = <String>[];
    await server.accounts.sweepShares(say: lines.add);
    expect(await held(), ['x']);
    expect(lines.single, contains('si riprova'));
    expect(await held(friend), isEmpty, reason: 'un utente che non va non ferma gli altri');

    driveOf(owner).unshareError = const DriveException('Errore di Drive', status: 500);
    await server.accounts.sweepShares();
    expect(await held(), ['x']);

    driveOf(owner).unshareError = null;
    await server.accounts.sweepShares();
    expect(driveOf(owner).unshared, ['cartella/x', 'cartella/x', 'cartella/x']);
    expect(await held(), isEmpty);
  });

  test('senza il permesso di Drive dell\'utente la voce resta, senza crash', () async {
    await call('PUT', '/v2/me/shares', body: {'shares': [share('x', Duration.zero)]});
    expect((await call('DELETE', '/v2/me/drive')).$1, 204);
    await server.accounts.sweepShares();
    expect(await held(), ['x']);
  });

  test('una voce rinnovata dall\'app mentre il server la ritira resta', () async {
    final keeper = ShareKeeper(File(p.join(server.dir.path, 'renewed.json')));
    final old = HeldShare(folderId: 'f', permissionId: 'p', expiresAt: clock);
    final renewed = HeldShare(folderId: 'f', permissionId: 'p', expiresAt: clock.add(const Duration(days: 30)));
    await keeper.replace([old]);
    await keeper.sweep(clock, (_, _) => keeper.replace([renewed]));
    expect(await keeper.list(), [renewed]);
  });

  test('con il Drive vero: 404 è già tolto e la voce esce, un permesso tolto pure', () async {
    final drive = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => drive.close(force: true));
    final seen = <String>[];
    drive.listen((request) async {
      seen.add('${request.method} ${request.uri.path}');
      final gone = request.uri.path.endsWith('/sparito');
      request.response.statusCode = gone ? 404 : 204;
      if (gone) {
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"error": {"code": 404, "message": "Permission not found"}}');
      }
      await request.response.close();
    });
    final client = DriveClient(({bool refresh = false}) async => 'token',
        network: const ServerNetwork(),
        endpoint: (path, query) => Uri.parse('http://127.0.0.1:${drive.port}$path').replace(queryParameters: query));
    addTearDown(client.close);
    final keeper = ShareKeeper(File(p.join(server.dir.path, 'real.json')));
    await keeper.replace([
      HeldShare(folderId: 'f', permissionId: 'sparito', expiresAt: clock),
      HeldShare(folderId: 'f', permissionId: 'vivo', expiresAt: clock),
    ]);
    expect(await keeper.sweep(clock, client.unshare), isEmpty);
    expect(seen, ['DELETE /drive/v3/files/f/permissions/sparito', 'DELETE /drive/v3/files/f/permissions/vivo']);
    expect(await keeper.list(), isEmpty);
  });

  test('accesso scaduto: lo spazio si cancella con l\'elenco, e il server non ritira più niente', () async {
    final (added, _) = await call('POST', '/v2/users', body: {'email': friend, 'expiresAt': at(const Duration(days: 1))});
    expect(added, 201);
    await server.ready(friend);
    await call('PUT', '/v2/me/shares', body: {'shares': [share('x', const Duration(hours: 1))]}, as: friend);
    final space = server.spaces[friend]!;

    clock = clock.add(const Duration(days: 2));
    await server.accounts.sweepShares();
    await server.accounts.sweep();
    expect(space.drive.unshared, isEmpty);
    expect(space.destroyed, isTrue);
    expect(await space.shares.file.exists(), isFalse);
  });

  test('validazione del corpo: niente cambia se una voce non va', () async {
    await call('PUT', '/v2/me/shares', body: {'shares': [share('tiene', const Duration(days: 1))]});
    final long = 'x' * 129;
    for (final body in <Object?>[
      <String, Object?>{},
      {'shares': 'no'},
      {'shares': ['no']},
      {'shares': [{'folderId': 'f', 'permissionId': 'p'}]},
      {'shares': [{'folderId': 'f', 'permissionId': 'p', 'expiresAt': 'domani'}]},
      {'shares': [{'folderId': 'f', 'permissionId': 'p', 'expiresAt': 3}]},
      {'shares': [{'folderId': '', 'permissionId': 'p', 'expiresAt': at(Duration.zero)}]},
      {'shares': [{'folderId': long, 'permissionId': 'p', 'expiresAt': at(Duration.zero)}]},
      {'shares': [{'folderId': 'f', 'permissionId': 7, 'expiresAt': at(Duration.zero)}]},
      {'shares': [share('doppia', Duration.zero), share('doppia', const Duration(days: 1))]},
      {'shares': [for (var i = 0; i <= maxShares; i++) share('$i', Duration.zero)]},
    ]) {
      final (status, response) = await call('PUT', '/v2/me/shares', body: body);
      expect((status, code(response)), (400, 'bad_request'), reason: jsonEncode(body).substring(0, 60.clamp(0, jsonEncode(body).length)));
    }
    expect(await held(), ['tiene']);
    // Una data già passata è accettata: si ritira al primo giro.
    expect((await call('PUT', '/v2/me/shares', body: {'shares': [share('passata', const Duration(days: -1))]})).$1, 200);
  });
}
