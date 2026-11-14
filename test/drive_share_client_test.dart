/// I permessi di una cartella di Drive contro un server vero, sul telefono
/// stesso: cosa si chiede a Drive per condividere, rinnovare, ritirare ed
/// elencare, e cosa si fa quando rifiuta la scadenza.
///
/// In un file a parte per lo stesso motivo di `drive_client_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/drive.dart';

import 'network_helpers.dart';

typedef _Call = ({String method, String path, Map<String, String> query, Object? body});

void main() {
  late HttpServer server;
  final calls = <_Call>[];

  /// Cosa risponde il finto Drive a ogni richiesta: stato e corpo.
  late (int, Object?) Function(_Call call) answer;

  setUp(() async {
    calls.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final text = await utf8.decodeStream(request);
      final call = (
        method: request.method,
        path: request.uri.path,
        query: request.uri.queryParameters,
        body: text.isEmpty ? null : jsonDecode(text),
      );
      calls.add(call);
      final (status, body) = answer(call);
      request.response.statusCode = status;
      if (body != null) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
      }
      await request.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  DriveClient client() {
    final drive = DriveClient(
      ({refresh = false}) async => 'token',
      network: monitor(),
      endpoint: (path, query) => Uri.http('${server.address.address}:${server.port}', path, query),
    );
    addTearDown(drive.close);
    return drive;
  }

  final expiry = DateTime.utc(2027, 1, 2, 3, 4, 5);
  Map<String, Object?> permission({bool expires = false}) => {
        'id': 'P1',
        'type': 'user',
        'role': 'reader',
        'emailAddress': 'Amica@Example.com',
        if (expires) 'expirationTime': '2027-01-02T03:04:05.000Z',
      };

  test('condividere: un lettore, senza email di Google, con la scadenza', () async {
    answer = (_) => (200, permission(expires: true));
    final granted = await client().share('F1', 'amica@example.com', expiresAt: expiry);

    final call = calls.single;
    expect((call.method, call.path), ('POST', '/drive/v3/files/F1/permissions'));
    expect(call.query['sendNotificationEmail'], 'false');
    expect(call.query['supportsAllDrives'], 'true');
    expect(call.body, {
      'type': 'user',
      'role': 'reader',
      'emailAddress': 'amica@example.com',
      'expirationTime': '2027-01-02T03:04:05.000Z',
    });
    // L'indirizzo è quello di Drive, minuscolo: è con quello che l'altro
    // account si riconosce.
    expect((granted.id, granted.email, granted.role), ('P1', 'amica@example.com', 'reader'));
    expect(granted.expiresAt, expiry);
  });

  test('senza termine la scadenza non si manda', () async {
    answer = (_) => (200, permission());
    final granted = await client().share('F1', 'amica@example.com');
    expect((calls.single.body as Map).containsKey('expirationTime'), isFalse);
    expect(granted.expiresAt, isNull);
  });

  for (final refused in [400, 403]) {
    test('Drive rifiuta la scadenza ($refused): il permesso si crea senza, e si vede', () async {
      answer = (call) => (call.body as Map).containsKey('expirationTime')
          ? (refused, {'error': {'code': refused, 'message': 'Expiration dates cannot be set on this item.'}})
          : (200, permission());
      final granted = await client().share('F1', 'amica@example.com', expiresAt: expiry);
      expect(calls, hasLength(2));
      expect((calls.last.body as Map).containsKey('expirationTime'), isFalse);
      expect(granted.id, 'P1');
      expect(granted.expiresAt, isNull);
    });
  }

  test('un rifiuto che non riguarda la scadenza resta un errore', () async {
    answer = (_) => (403, {'error': {'code': 403, 'message': 'insufficientFilePermissions'}});
    await expectLater(
      client().share('F1', 'amica@example.com', expiresAt: expiry),
      throwsA(isA<DriveException>().having((e) => e.status, 'status', 403)),
    );
    expect(calls, hasLength(2));
  });

  test('senza lo scope completo serve il permesso, e non si riprova', () async {
    answer = (_) => (403, {'error': {'code': 403, 'message': 'insufficientPermissions'}});
    await expectLater(
      client().share('F1', 'amica@example.com', expiresAt: expiry),
      throwsA(isA<DriveAuthRequired>()),
    );
    expect(calls, hasLength(1));
  });

  test('rinnovare: la scadenza nuova sullo stesso permesso', () async {
    answer = (_) => (200, permission(expires: true));
    final renewed = await client().renewShare('F1', 'P1', expiry);
    final call = calls.single;
    expect((call.method, call.path), ('PATCH', '/drive/v3/files/F1/permissions/P1'));
    expect(call.query.containsKey('removeExpiration'), isFalse);
    expect(call.body, {'role': 'reader', 'expirationTime': '2027-01-02T03:04:05.000Z'});
    expect(renewed.expiresAt, expiry);
  });

  test('rinnovare senza termine toglie la scadenza', () async {
    answer = (_) => (200, permission());
    await client().renewShare('F1', 'P1', null);
    expect(calls.single.query['removeExpiration'], 'true');
    expect(calls.single.body, {'role': 'reader'});
  });

  test('rinnovare con la scadenza rifiutata: il permesso resta, senza', () async {
    answer = (call) => (call.body as Map).containsKey('expirationTime') ? (400, null) : (200, permission());
    final renewed = await client().renewShare('F1', 'P1', expiry);
    expect(calls.last.query['removeExpiration'], 'true');
    expect(renewed.expiresAt, isNull);
  });

  test('rinnovare un permesso che non c\'è più: 404, da ricreare', () async {
    answer = (_) => (404, null);
    await expectLater(
      client().renewShare('F1', 'P1', expiry),
      throwsA(isA<DriveException>().having((e) => e.status, 'status', 404)),
    );
    expect(calls, hasLength(1));
  });

  test('ritirare: tolto, o già tolto', () async {
    answer = (_) => (204, null);
    await client().unshare('F1', 'P1');
    expect((calls.single.method, calls.single.path), ('DELETE', '/drive/v3/files/F1/permissions/P1'));
    expect(calls.single.query['supportsAllDrives'], 'true');

    answer = (_) => (404, null);
    await client().unshare('F1', 'P1');
  });

  test('ritirare senza risposta di Drive lancia: il permesso è ancora lì', () async {
    answer = (_) => (403, {'error': {'code': 403, 'message': 'insufficientFilePermissions'}});
    await expectLater(client().unshare('F1', 'P1'), throwsA(isA<DriveException>()));

    final offline = monitor(reachable: false);
    await (offline as Switchable).goOffline();
    final drive = DriveClient(({refresh = false}) async => 'token', network: offline);
    addTearDown(drive.close);
    await expectLater(drive.unshare('F1', 'P1'), throwsA(isA<DriveOffline>()));
  });

  test('elencare: tutte le pagine, il proprietario e i link compresi', () async {
    answer = (call) => call.query['pageToken'] == null
        ? (200, {
            'nextPageToken': 'poi',
            'permissions': [
              {'id': 'me', 'type': 'user', 'role': 'owner', 'emailAddress': 'io@example.com'},
              permission(expires: true),
            ],
          })
        : (200, {
            'permissions': [
              {'id': 'anyoneWithLink', 'type': 'anyone', 'role': 'reader'},
            ],
          });
    final permissions = await client().sharedWith('F1');
    expect(calls.map((call) => (call.method, call.path)).toSet(), {('GET', '/drive/v3/files/F1/permissions')});
    expect(calls.last.query['pageToken'], 'poi');
    expect(calls.first.query['fields'], contains('expirationTime'));
    expect(
      [for (final p in permissions) (p.id, p.type, p.role, p.email)],
      [
        ('me', 'user', 'owner', 'io@example.com'),
        ('P1', 'user', 'reader', 'amica@example.com'),
        ('anyoneWithLink', 'anyone', 'reader', null),
      ],
    );
    expect(permissions[1].expiresAt, expiry);
  });

  test('owned: ownedByMe vero, falso o assente (Drive condiviso); un errore esce', () async {
    var owned = <String, Object?>{'id': 'F', 'ownedByMe': true};
    answer = (_) => (200, owned);
    expect(await client().owned('F'), isTrue);
    expect(calls.single.path, '/drive/v3/files/F');
    expect(calls.single.query['fields'], 'id,ownedByMe');
    owned = {'id': 'F', 'ownedByMe': false};
    expect(await client().owned('F'), isFalse);
    owned = {'id': 'F'};
    expect(await client().owned('F'), isFalse);
    answer = (_) => (404, {'error': 'notFound'});
    await expectLater(client().owned('F'), throwsA(isA<DriveException>()));
  });
}
