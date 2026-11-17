// F8.6 (T1): l'app non mette mai il token della sessione in una richiesta a
// un server altrui. Biglietto se il server lo accetta; il token solo al
// server che il collegamento dice creato da questo account. F8.5: il
// biglietto è per l'indirizzo a cui l'app parla, che per il proprio server
// l'app garantisce prima; un server che dichiara l'id di un altro riceve un
// biglietto per il suo indirizzo, che sull'altro non vale.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/server_access.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami_archive/jobs.dart' show CheckScope;
import 'package:kagami_archive/remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  const me = 'Io@example.com';
  final id = 'c' * 32;
  final withTickets = ServerHello(id: id, features: const {'tickets'});
  const older = ServerHello();
  final url = Uri.parse('https://server.example');

  late List<bool> sessions;
  late List<String> tickets;
  late List<String> vouched;
  late Object? ticketFailure;
  late Object? vouchFailure;

  ServerAccess access() => ServerAccess(
        account: () => const CloudAccount(id: 'u', email: me),
        session: ({bool refresh = false}) async {
          sessions.add(refresh);
          return 'sessione';
        },
        ticket: (audience, origin) async {
          if (ticketFailure != null) throw ticketFailure!;
          tickets.add('$audience $origin');
          return 'biglietto-${tickets.length}';
        },
        vouch: (audience, origin) async {
          if (vouchFailure != null) throw vouchFailure!;
          vouched.add('$audience $origin');
        },
      );

  setUp(() {
    sessions = [];
    tickets = [];
    vouched = [];
    ticketFailure = null;
    vouchFailure = null;
  });

  Matcher refused(String code) => throwsA(isA<ServerException>().having((e) => e.code, 'code', code));

  test('a un server coi biglietti va un biglietto per il suo id, mai il token', () async {
    final a = access();
    final link = ServerLink(url.replace(host: 'a.example'));
    expect(await a.idToken(link, withTickets), 'Kagami-Ticket biglietto-1');
    expect(await a.idToken(link, withTickets), 'Kagami-Ticket biglietto-1', reason: 'riusato finché vale');
    expect(await a.idToken(link, withTickets, refresh: true), 'Kagami-Ticket biglietto-2');
    expect(tickets, ['$id https://a.example', '$id https://a.example']);
    expect(vouched, isEmpty, reason: 'un server altrui non si garantisce');
    // Anche al proprio server: il token non serve.
    expect(await a.idToken(ServerLink(url, owner: 'io@example.com'), withTickets), startsWith('Kagami-Ticket '));
    expect(sessions, isEmpty);
  });

  test('un server che dichiara l\'id di un altro riceve un biglietto per il suo indirizzo', () async {
    // M, a un primo collegamento, dice di essere il server con l'id [id]: il
    // biglietto porta l'indirizzo di M, che il proprietario di quel server non
    // ha garantito, quindi lì non vale.
    final a = access();
    await a.idToken(ServerLink(Uri.parse('https://M.example:443/kagami/')), withTickets);
    expect(tickets, ['$id https://m.example/kagami']);
    expect(vouched, isEmpty);
  });

  test('il proprio server: l\'indirizzo si garantisce prima del biglietto, una volta', () async {
    final a = access();
    final mine = ServerLink(Uri.parse('https://mio.example'), owner: 'io@example.com');
    await a.idToken(mine, withTickets);
    await a.idToken(mine, withTickets, refresh: true);
    expect(vouched, ['$id https://mio.example']);
    expect(tickets, ['$id https://mio.example', '$id https://mio.example']);
    // Un altro indirizzo dello stesso server si garantisce a parte.
    await a.idToken(ServerLink(Uri.parse('http://100.64.0.9:8080'), owner: 'io@example.com'), withTickets);
    expect(vouched.last, '$id http://100.64.0.9:8080');
  });

  test('backend senza kagami_server_origin: token solo al proprio server', () async {
    vouchFailure = const PostgrestException(message: 'nessuna funzione', code: 'PGRST202');
    final a = access();
    final hello = ServerHello(id: 'e' * 32, features: const {'tickets'});
    expect(await a.idToken(ServerLink(Uri.parse('https://suo.example'), owner: 'io@example.com'), hello), 'Bearer sessione');
    expect(tickets, isEmpty);
    // Un altro guasto non apre la strada al token, e non chiede biglietti senza garanzia.
    vouchFailure = const SocketException('giù');
    await expectLater(a.idToken(ServerLink(Uri.parse('https://suo2.example'), owner: 'io@example.com'), hello),
        throwsA(isA<SocketException>()));
    expect(sessions, [false]);
    expect(tickets, isEmpty);
  });

  test('a un server altrui senza biglietti non si manda niente', () async {
    final a = access();
    await expectLater(a.idToken(ServerLink(url), older), refused('update_server'));
    await expectLater(a.idToken(ServerLink(url, owner: 'altro@example.com'), older), refused('update_server'));
    expect(sessions, isEmpty);
    expect(tickets, isEmpty);
  });

  test('il proprio server senza biglietti riceve il token', () async {
    expect(await access().idToken(ServerLink(url, owner: 'io@example.com'), older), 'Bearer sessione');
    expect(sessions, [false]);
  });

  test('backend senza kagami_ticket: token solo al proprio server', () async {
    ticketFailure = const PostgrestException(message: 'nessuna funzione', code: 'PGRST202');
    final a = access();
    // Un altro server: i biglietti già avuti stanno in una cache dell'app.
    final withTickets = ServerHello(id: 'd' * 32, features: const {'tickets'});
    await expectLater(a.idToken(ServerLink(url.replace(host: 'b.example')), withTickets), refused('tickets_unavailable'));
    expect(sessions, isEmpty);
    expect(await a.idToken(ServerLink(url.replace(host: 'b.example'), owner: 'io@example.com'), withTickets),
        'Bearer sessione');
    // Un altro guasto del backend non apre la strada al token.
    ticketFailure = const SocketException('giù');
    await expectLater(a.idToken(ServerLink(url.replace(host: 'c.example')), withTickets), throwsA(isA<SocketException>()));
    expect(sessions, [false]);
  });

  test('sul filo: un server di prima, altrui, non vede nessun Authorization', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final authorizations = <String?>[];
    server.listen((request) async {
      authorizations.add(request.headers.value(HttpHeaders.authorizationHeader));
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"service": "kagami-server", "api": 2}');
      await request.response.close();
    });
    final client = ServerClient(ServerLink(Uri.parse('http://127.0.0.1:${server.port}')), access().idToken);
    addTearDown(client.close);
    await expectLater(client.info(), refused('update_server'));
    expect(authorizations, [null], reason: 'solo GET /, senza credenziali');
    expect(sessions, isEmpty);
  });

  group('collegamenti di prima dei biglietti', () {
    const stored = '{"url": "https://server.example"}';

    test('un collegamento salvato prima è legacy; uno scritto adesso no', () {
      expect(ServerLink.fromJson(jsonDecode(stored) as Map<String, Object?>).legacy, isTrue);
      expect(ServerLink.fromJson({'url': '$url', 'owner': ''}).legacy, isFalse);
      expect(ServerLink.fromJson({'url': '$url', 'id': id}).legacy, isFalse);
      expect(ServerLink(url).legacy, isFalse);
    });

    test('senza biglietti il legacy riceve ancora il token, finché non è adottato', () async {
      final link = ServerLink.fromJson(jsonDecode(stored) as Map<String, Object?>);
      expect(await access().idToken(link, older), 'Bearer sessione');
      await expectLater(access().idToken(ServerLink(url, owner: ''), older), refused('update_server'));
    });

    Future<({HttpServer server, ProviderContainer container, KagamiDatabase db})> open(
        Map<String, Object?> info, {String hello = '{"service":"kagami-server","api":2}'}) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response
          ..headers.contentType = ContentType.json
          ..write(request.uri.path == '/' ? hello : jsonEncode(info));
        await request.response.close();
      });
      final db = KagamiDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      await container.read(userRepositoryProvider).writeSetting(
          'server.link', '{"url": "http://127.0.0.1:${server.port}"}');
      return (server: server, container: container, db: db);
    }

    Map<String, Object?> info(String owner, {required bool mine}) => {
          'service': 'kagami-server',
          'api': 2,
          'owner': owner,
          'me': {'email': me.toLowerCase(), 'owner': mine, 'drive': <String, Object?>{}},
        };

    test('il primo contatto con il proprio server salva id e owner, una volta', () async {
      final opened = await open(info(me.toLowerCase(), mine: true),
          hello: '{"service":"kagami-server","api":2,"id":"$id","features":["tickets"]}');
      final notifier = opened.container.read(serverLinkProvider.notifier);
      final link = (await opened.container.read(serverLinkProvider.future))!;
      final client = ServerClient(link, access().idToken);
      addTearDown(client.close);
      await notifier.adopt(client, me);
      final saved = opened.container.read(serverLinkProvider).value!;
      expect((saved.id, saved.owner, saved.legacy), (id, 'io@example.com', false));
      expect(
          jsonDecode((await opened.container.read(userRepositoryProvider).readSetting('server.link'))!),
          {'url': '${link.url}', 'id': id, 'owner': 'io@example.com'});
    });

    test('un server che non dice di essere mio resta senza token da qui in poi', () async {
      final opened = await open(info('altro@example.com', mine: false));
      final link = (await opened.container.read(serverLinkProvider.future))!;
      final client = ServerClient(link, access().idToken);
      addTearDown(client.close);
      await opened.container.read(serverLinkProvider.notifier).adopt(client, me);
      final saved = opened.container.read(serverLinkProvider).value!;
      expect((saved.owner, saved.legacy), ('', false));
      await expectLater(access().idToken(saved, older), refused('update_server'));
    });

    test('un server che non risponde non adotta niente', () async {
      final opened = await open(info(me, mine: true));
      final link = (await opened.container.read(serverLinkProvider.future))!;
      await opened.server.close(force: true);
      final client = ServerClient(link, access().idToken);
      addTearDown(client.close);
      await opened.container.read(serverLinkProvider.notifier).adopt(client, me);
      expect(opened.container.read(serverLinkProvider).value!.legacy, isTrue);
    });

    test('il controllo ad app chiusa usa id e owner del collegamento salvato', () {
      const scope = CheckScope(toServer: true, server: 'https://server.example', serverId: 'c', serverOwner: 'io@example.com');
      final back = CheckScope.fromJson(jsonDecode(jsonEncode(scope.toJson())) as Map<String, Object?>);
      expect((back.serverId, back.serverOwner), ('c', 'io@example.com'));
    });
  });
}
