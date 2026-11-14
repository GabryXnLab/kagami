// F8.6 (T1): il server riconosce chi chiama da un biglietto per il suo id,
// che verifica col backend con la sola chiave anon; il client dell'app non
// manda niente a un server che si spaccia per un altro. F8.5: chiede col
// nome del suo proprietario, perché il biglietto valga solo per un indirizzo
// che lui ha garantito.
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/remote.dart';
import 'package:kagami_server/src/config.dart';
import 'package:kagami_server/src/ticket.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  const owner = 'owner@example.com';
  final id = 'a' * 32, other = 'b' * 32;
  final good = '1' * 96, forOther = '2' * 96, stale = '3' * 96;
  late HttpServer backend;
  late List<Map<String, Object?>> asked;
  late List<Map<String, String?>> headers;
  var status = 200;
  // Da quanto il proprietario ha garantito l'indirizzo; il backend (0015) conta solo gli ultimi 90 giorni.
  var originAge = Duration.zero;
  var now = DateTime.utc(2026, 11, 14, 12);
  late TestServer server;

  setUp(() async {
    asked = [];
    headers = [];
    status = 200;
    originAge = Duration.zero;
    now = DateTime.utc(2026, 11, 14, 12);
    // Il backend finto: kagami_ticket_who come la migrazione 0013 (l'indirizzo
    // del biglietto garantito da `owner`: qui lo è solo per il proprietario vero).
    backend = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    backend.listen((request) async {
      final body = jsonDecode(await utf8.decodeStream(request)) as Map<String, Object?>;
      asked.add(body);
      headers.add({
        'path': request.uri.path,
        'apikey': request.headers.value('apikey'),
        'authorization': request.headers.value('authorization'),
      });
      final rows = switch ((body['ticket'], body['audience'])) {
        _ when body['owner'] != owner || originAge > const Duration(days: 90) => const [],
        (final t, final a) when t == good && a == id => [
            {'email': 'Amico@example.com', 'expires_at': now.add(const Duration(minutes: 10)).toIso8601String()},
          ],
        (final t, final a) when t == forOther && a == other => [
            {'email': 'amico@example.com', 'expires_at': now.add(const Duration(minutes: 10)).toIso8601String()},
          ],
        _ => const [],
      };
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(status == 200 ? jsonEncode(rows) : '{"code": "PGRST202"}');
      await request.response.close();
    });
    final tickets =
        TicketVerifier(Uri.parse('http://127.0.0.1:${backend.port}/'), 'chiave-anon', id, 'Owner@Example.com', clock: () => now);
    server = await TestServer.start(owner: owner, id: id, tickets: tickets);
    await server.accounts.add('amico@example.com');
    await server.ready('amico@example.com');
  });
  tearDown(() async {
    await server.close();
    await backend.close(force: true);
  });

  ServerClient withTicket(String ticket, {ServerLink? link, ServerLink? linked, List<ServerHello>? seen}) =>
      ServerClient(link ?? ServerLink(server.address), (_, hello, {bool refresh = false}) async {
        seen?.add(hello);
        return 'Kagami-Ticket $ticket';
      }, linked: linked);

  test('GET / e /v2/server dichiarano l\'id e i biglietti', () async {
    final client = withTicket(good);
    addTearDown(client.close);
    final hello = await client.hello();
    expect(hello.id, id);
    expect(hello.tickets, isTrue);
    final info = await client.info();
    expect(info.id, id);
    expect(info.tickets, isTrue);
    expect(info.email, 'amico@example.com');
    // Il backend ha visto il biglietto per l'id del server, il suo proprietario e la sola chiave anon.
    expect(asked.single, {'ticket': good, 'audience': id, 'owner': owner});
    expect(headers.single, {
      'path': '/rest/v1/rpc/kagami_ticket_who',
      'apikey': 'chiave-anon',
      'authorization': 'Bearer chiave-anon',
    });
  });

  test('l\'esito sta in cache fino al termine del biglietto, non oltre', () async {
    final client = withTicket(good);
    addTearDown(client.close);
    await client.info();
    await client.queue();
    expect(asked, hasLength(1));
    now = now.add(const Duration(minutes: 11));
    await client.queue();
    expect(asked, hasLength(2));
  });

  test('biglietto di un altro server, scaduto, inventato o malformato: 401', () async {
    for (final ticket in [forOther, stale, 'f' * 96, 'zz', '${good}x']) {
      final client = withTicket(ticket);
      await expectLater(client.info(), throwsA(isA<ServerUnauthorized>()), reason: ticket);
      client.close();
    }
    // Il malformato non arriva neanche al backend.
    expect(asked.map((row) => row['ticket']), isNot(contains('zz')));
  });

  test('origine garantita da più di 90 giorni: 401 finché il proprietario non la rinnova', () async {
    originAge = const Duration(days: 91);
    var client = withTicket(good);
    await expectLater(client.info(), throwsA(isA<ServerUnauthorized>()));
    client.close();
    originAge = Duration.zero; // dichiarata di nuovo
    client = withTicket(good);
    addTearDown(client.close);
    await client.info();
  });

  test('backend senza la funzione: 401; backend guasto: 503', () async {
    status = 404;
    final client = withTicket(good);
    await expectLater(client.info(), throwsA(isA<ServerUnauthorized>()));
    status = 500;
    await expectLater(
        client.info(), throwsA(isA<ServerException>().having((e) => e.code, 'code', 'identity_unavailable')));
    client.close();
  });

  test('un server senza backend non dichiara i biglietti e li rifiuta', () async {
    final bare = await TestServer.start(owner: owner, id: id);
    addTearDown(bare.close);
    final client = withTicket(good, link: ServerLink(bare.address));
    addTearDown(client.close);
    expect((await client.hello()).tickets, isFalse);
    await expectLater(client.info(), throwsA(isA<ServerUnauthorized>()));
  });

  test('chi dichiara l\'id del server collegato da un altro indirizzo non riceve niente', () async {
    final seen = <ServerHello>[];
    final linked = ServerLink(Uri.parse('https://vero.example'), id: id);
    final impostor = withTicket(good, linked: linked, seen: seen);
    await expectLater(impostor.info(), throwsA(isA<ServerException>().having((e) => e.code, 'code', 'impostor')));
    impostor.close();
    // Un altro id allo stesso collegamento: un altro server.
    final moved = withTicket(good, link: ServerLink(server.address, id: other), seen: seen);
    await expectLater(moved.info(), throwsA(isA<ServerException>().having((e) => e.code, 'code', 'other_server')));
    moved.close();
    expect(seen, isEmpty, reason: 'le credenziali non si chiedono neanche');
    expect(asked, isEmpty);
  });

  test('l\'id nasce una volta e resta', () async {
    final dir = await Directory.systemTemp.createTemp('kagami-id-');
    addTearDown(() => dir.delete(recursive: true));
    final paths = ServerPaths(dir);
    final first = await serverIdentity(paths);
    expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(await serverIdentity(paths), first);
    expect(await serverIdentity(ServerPaths(await Directory.systemTemp.createTemp('kagami-id-'))), isNot(first));
  });
}
