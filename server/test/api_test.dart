import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  const owner = 'owner@example.com';
  late TestServer server;
  late FakeSpace me;
  late ArchiveFiles files;
  late FakeJobs jobs;
  late FakeDrive drive;
  final http = HttpClient();

  setUp(() async {
    server = await TestServer.start(owner: owner);
    me = await server.ready(owner);
    files = me.files;
    jobs = me.jobs;
    drive = me.drive;
  });
  tearDown(() => server.close());

  Future<(int, Map<String, Object?>?)> call(String method, String path, {Object? body, String as = owner}) async {
    final request = await http.openUrl(method, server.address.replace(path: path));
    if (as.isNotEmpty) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${as.contains('@') ? 'tok:$as' : as}');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body is String ? body : jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text) as Map<String, Object?>);
  }

  String? code(Map<String, Object?>? body) => (body?['error'] as Map?)?['code'] as String?;

  test('senza token, o con uno falso, solo la risposta che dice chi è', () async {
    final (open, about) = await call('GET', '/', as: '');
    expect(open, 200);
    expect(about, {'service': 'kagami-server', 'api': 2});
    final (status, body) = await call('GET', '/v2/server', as: '');
    expect(status, 401);
    expect(code(body), 'unauthorized');
    expect((await call('GET', '/v2/jobs', as: 'falso')).$1, 401);
    expect((await call('POST', '/v2/jobs', as: 'falso', body: {'url': 'x'})).$1, 401);
  });

  test('un account valido ma non ammesso è 403, finché il proprietario non lo aggiunge', () async {
    final (status, body) = await call('GET', '/v2/server', as: 'amico@example.com');
    expect(status, 403);
    expect(code(body), 'not_allowed');
    expect((body!['error'] as Map)['message'], contains('amico@example.com'));

    final (added, user) = await call('POST', '/v2/users', body: {'email': ' Amico@Example.com '});
    expect(added, 201);
    expect(user!['user'], containsPair('email', 'amico@example.com'));
    expect(user['user'], containsPair('connected', false));
    final (now, info) = await call('GET', '/v2/server', as: 'AMICO@example.com');
    expect(now, 200);
    expect(info!['me'], {
      'email': 'amico@example.com',
      'owner': false,
      'drive': {'authorized': false, 'folderId': null, 'folderName': null},
    });
  });

  test('il server si presenta: versione, proprietario, siti, il Drive di chi chiama', () async {
    final (status, body) = await call('GET', '/v2/server');
    expect(status, 200);
    expect(body!['api'], 2);
    expect(body['name'], 'Prova');
    expect(body['owner'], owner);
    expect([for (final row in body['providers'] as List) (row as Map)['id']], containsAll(['mangak', 'manhwaread', 'asurascans']));
    expect(body['me'], {
      'email': owner,
      'owner': true,
      'drive': {'authorized': true, 'folderId': 'cartella-$owner', 'folderName': 'Manga'},
    });
    expect(body['check'], {
      'minutes': 240, 'time': 240, 'enabled': true, 'library': true, 'unfollowed': <Object?>[],
      'checked': 0, 'queued': 0, 'failed': 0, 'gated': <Object?>[],
    });
    expect(body['features'], containsAll(['ahead', 'unfollowed', 'verify']));
  });

  test('gli utenti sono del proprietario: gli altri ricevono owner_only', () async {
    await server.accounts.add('amico@example.com');
    for (final (method, path, body) in [
      ('GET', '/v2/users', null),
      ('POST', '/v2/users', {'email': 'terzo@example.com'}),
      ('DELETE', '/v2/users/owner@example.com', null),
    ]) {
      final (status, reply) = await call(method, path, body: body, as: 'amico@example.com');
      expect((status, code(reply)), (403, 'owner_only'), reason: '$method $path');
    }
    final (_, list) = await call('GET', '/v2/users');
    expect([for (final row in list!['users'] as List) ((row as Map)['email'], row['owner'], row['connected'])], [
      (owner, true, true),
      ('amico@example.com', false, false),
    ]);
    expect(code((await call('POST', '/v2/users', body: {'email': 'non-un-indirizzo'})).$2), 'bad_request');
    expect(code((await call('DELETE', '/v2/users/$owner')).$2), 'bad_request');
    expect((await call('DELETE', '/v2/users/nessuno@example.com')).$1, 404);
  });

  test('togliere un utente lo chiude fuori e cancella il suo spazio', () async {
    await server.accounts.add('amico@example.com');
    final friend = await server.ready('amico@example.com');
    expect((await call('GET', '/v2/jobs', as: 'amico@example.com')).$1, 200);
    expect((await call('DELETE', '/v2/users/amico@example.com')).$1, 204);
    expect(friend.destroyed, isTrue);
    expect(code((await call('GET', '/v2/jobs', as: 'amico@example.com')).$2), 'not_allowed');
  });

  test('ognuno vede solo la sua coda, e i suoi lavori vanno nella sua cartella', () async {
    await server.accounts.add('amico@example.com');
    final friend = await server.ready('amico@example.com');
    final (status, body) = await call('POST', '/v2/jobs', as: 'amico@example.com', body: {'url': 'https://mangak.io/x'});
    expect(status, 201);
    expect((await friend.files.jobs()).single.target.folderId, 'cartella-amico@example.com');
    expect(friend.jobs.woken, 1);
    expect(await files.jobs(), isEmpty);
    expect(jobs.woken, 0);
    final (_, mine) = await call('GET', '/v2/jobs');
    expect(mine!['queue'], isEmpty);
    // Il lavoro di un altro, per me, non esiste.
    final id = (body!['job'] as Map)['id'];
    expect((await call('DELETE', '/v2/jobs/$id')).$1, 404);
  });

  test('il permesso di Drive dall\'app: provato prima di salvarlo, dimenticato scollegando', () async {
    await server.accounts.add('amico@example.com');
    const friend = 'amico@example.com';
    expect(code((await call('POST', '/v2/jobs', as: friend, body: {'url': 'https://mangak.io/x'})).$2), 'drive_not_ready');
    expect(code((await call('PUT', '/v2/me/folder', as: friend, body: {'folderId': 'f'})).$2), 'drive_not_ready');
    expect(code((await call('PUT', '/v2/me/drive', as: friend, body: {'refreshToken': 'r'})).$2), 'bad_request');
    expect(code((await call('PUT', '/v2/me/drive', as: friend, body: {'refreshToken': 'revocato', 'folderId': 'f'})).$2),
        'bad_grant');
    expect(code((await call('PUT', '/v2/me/drive', as: friend, body: {'refreshToken': 'r', 'folderId': 'non-esiste'})).$2),
        'bad_folder');

    final (status, body) = await call('PUT', '/v2/me/drive', as: friend, body: {
      'refreshToken': '1//buono',
      'folderId': 'https://drive.google.com/drive/folders/1XyZ?usp=sharing',
    });
    expect(status, 200);
    expect(body!['drive'], {'authorized': true, 'folderId': '1XyZ', 'folderName': 'Scelta'});
    final space = server.spaces[friend]!;
    expect(space.drive.refresh, '1//buono');
    expect((await call('POST', '/v2/jobs', as: friend, body: {'url': 'https://mangak.io/x'})).$1, 201);

    expect((await call('DELETE', '/v2/me/drive', as: friend)).$1, 204);
    expect(space.drive.ready, isFalse);
    expect(await space.files.jobs(), isEmpty);
  });

  test('un lavoro entra in coda nella cartella della libreria, sveglia il giro e si vede', () async {
    final (status, body) = await call('POST', '/v2/jobs', body: {
      'url': 'https://mangak.io/dungeon-odyssey',
      'title': 'Dungeon Odyssey',
      'start': 16,
    });
    expect(status, 201);
    final job = body!['job'] as Map;
    expect(job['start'], '16');
    expect(jobs.woken, 1);
    final queued = (await files.jobs()).single;
    expect(queued.target.destination, ArchiveDestination.drive);
    expect(queued.target.folderId, 'cartella-$owner');

    final (_, list) = await call('GET', '/v2/jobs');
    expect([for (final row in list!['queue'] as List) (row as Map)['id']], [job['id']]);
    expect((list['status'] as Map)['state'], 'idle');
    expect(list['history'], isEmpty);
    // Il bersaglio interno non esce dall'API.
    expect((list['queue'] as List).single, isNot(contains('target')));
  });

  test('richieste sbagliate: link di nessun sito, campi di un altro tipo, JSON rotto', () async {
    Future<String> code(Object body) async => ((await call('POST', '/v2/jobs', body: body)).$2!['error'] as Map)['code'] as String;
    expect(await code({'url': 'https://example.com/serie'}), 'unsupported_url');
    expect(await code({}), 'bad_request');
    expect(await code({'url': 'https://mangak.io/x', 'ids': [1, 2]}), 'bad_request');
    expect(await code({'url': 'https://mangak.io/x', 'start': '3', 'ids': ['a']}), 'bad_request');
    expect(await code({'url': 'https://mangak.io/x', 'delayMs': 99999}), 'bad_request');
    // La pagina della serie serve solo ai siti dietro la verifica del browser.
    expect(await code({'url': 'https://mangak.io/x', 'snapshot': '<html>'}), 'bad_request');
    expect(await code('{rotto'), 'bad_request');
    expect(await files.jobs(), isEmpty);
    expect(jobs.woken, 0);
  });

  test('la pagina di ManhwaRead mandata dal telefono diventa un file del lavoro', () async {
    final (status, _) = await call('POST', '/v2/jobs', body: {
      'url': 'https://manhwaread.com/manhwa/disfarming/',
      'snapshot': '<html>la serie</html>',
    });
    expect(status, 201);
    final job = (await files.jobs()).single;
    expect(await File(job.snapshot!).readAsString(), '<html>la serie</html>');
  });

  test('senza Drive pronto il lavoro non entra: lo si dice', () async {
    drive.ready = false;
    final (status, body) = await call('POST', '/v2/jobs', body: {'url': 'https://mangak.io/x'});
    expect(status, 409);
    expect((body!['error'] as Map)['code'], 'drive_not_ready');
  });

  test('un lavoro si toglie; uno che non c\'è è 404', () async {
    final (_, body) = await call('POST', '/v2/jobs', body: {'url': 'https://mangak.io/x'});
    final id = (body!['job'] as Map)['id'] as String;
    expect((await call('DELETE', '/v2/jobs/$id')).$1, 204);
    expect(jobs.cancelled, [id]);
    expect((await call('DELETE', '/v2/jobs/$id')).$1, 404);
  });

  test('controllo delle serie in corso a richiesta, e cartella di Drive scelta dall\'app', () async {
    expect((await call('POST', '/v2/check')).$1, 202);
    expect(jobs.checks, 1);
    final (changed, check) = await call('PUT', '/v2/check', body: {'enabled': false, 'minutes': 90, 'library': false});
    expect(changed, 200);
    expect((check!['minutes'], check['time'], check['enabled'], check['library']), (null, 90, false, false));
    expect((await call('PUT', '/v2/check', body: {'minutes': 1440})).$1, 400);
    final (_, excluded) = await call('PUT', '/v2/check', body: {'unfollowed': ['mangak:A1']});
    expect(excluded!['unfollowed'], ['mangak:A1']);
    expect(excluded['time'], 90);
    expect((await call('PUT', '/v2/check', body: {'unfollowed': [1]})).$1, 400);
    expect((await call('PUT', '/v2/check', body: {'unfollowed': 'mangak:A1'})).$1, 400);
    final (checkedPages, pages) = await call('POST', '/v2/check/pages', body: {
      'pages': [{'url': 'https://manhwaread.com/manhwa/d/', 'html': '<html></html>'}],
    });
    expect(checkedPages, 200);
    expect((pages!['checked'], pages['queued']), (1, 1));
    expect(pages['gated'], isEmpty);
    expect((await call('POST', '/v2/check/pages', body: {'pages': <Object?>[]})).$1, 400);
    expect((await call('POST', '/v2/check/pages', body: {'pages': [{'url': 'x'}]})).$1, 400);

    final link = 'https://drive.google.com/drive/folders/1AbC_d-EF?usp=sharing';
    final (status, body) = await call('PUT', '/v2/me/folder', body: {'folderId': link});
    expect(status, 200);
    expect((body!['drive'] as Map)['folderId'], '1AbC_d-EF');
    final (bad, error) = await call('PUT', '/v2/me/folder', body: {'folderId': 'non-esiste'});
    expect(bad, 400);
    expect((error!['error'] as Map)['code'], 'bad_folder');
  });

  test('man mano: il lavoro lo porta, la serie seguita dice quanti ne servono e l\'app li chiede', () async {
    final (_, info) = await call('GET', '/v2/server');
    expect(info!['features'], contains('ahead'));
    final (status, body) = await call('POST', '/v2/jobs', body: {
      'url': 'https://mangak.io/x',
      'ids': ['C1', 'C2'],
      'ahead': 5,
    });
    expect(status, 201);
    expect((body!['job'] as Map)['ahead'], 5);
    expect((await files.jobs()).single.ahead, 5);
    // Quelli che l'app mette in coda dopo si aggiungono, non sostituiscono.
    await call('POST', '/v2/jobs', body: {'url': 'https://mangak.io/x', 'ids': ['C3'], 'ahead': 5, 'automatic': true});
    expect((await files.jobs()).single.ids, {'C1', 'C2', 'C3'});
    expect((await call('POST', '/v2/jobs', body: {'url': 'https://mangak.io/x', 'ahead': 0})).$1, 400);
    expect((await call('POST', '/v2/jobs', body: {
      'url': 'https://manhwaread.com/manhwa/disfarming/',
      'ahead': 5,
    })).$1, 400);

    const target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'cartella-$owner');
    await files.ongoing.parent.create(recursive: true);
    await files.ongoing.writeAsString(jsonEncode({
      'series': [
        TrackedSeries(provider: 'mangak', id: 'S1', title: 'Man mano', url: 'https://mangak.io/x',
            target: target, chapters: const ['C1'], addedAt: DateTime.now(), ahead: 5).toJson(),
        TrackedSeries(provider: 'mangak', id: 'S2', title: 'Tutta', url: 'https://mangak.io/y',
            target: target, chapters: const ['C1'], addedAt: DateTime.now(), checkedAt: DateTime.now()).toJson(),
      ],
    }));
    final (_, ongoing) = await call('GET', '/v2/ongoing');
    final rows = (ongoing!['series'] as List).cast<Map>();
    expect((rows.first['ahead'], rows.first['wanted']), (5, 0));
    expect(rows.last.containsKey('ahead'), isFalse);

    final (wanted, answer) = await call('PUT', '/v2/ongoing/mangak:S1', body: {'wanted': 2});
    expect(wanted, 200);
    expect(answer!['checking'], isTrue);
    expect(jobs.seriesChecks, ['mangak:S1']);
    expect((await Tracking(files.ongoing).load()).first.wanted, 2);
    expect(code((await call('PUT', '/v2/ongoing/mangak:S2', body: {'wanted': 1})).$2), 'not_ahead');
    expect((await call('PUT', '/v2/ongoing/mangak:NO', body: {'wanted': 1})).$1, 404);
    expect((await call('PUT', '/v2/ongoing/mangak:S1', body: {'wanted': -1})).$1, 400);
  });

  test('indirizzi sconosciuti sono 404, anche con un token buono', () async {
    expect((await call('GET', '/v2/niente')).$1, 404);
    expect((await call('GET', '/v1/server')).$1, 404);
    expect((await call('PATCH', '/v2/jobs')).$1, 404);
  });

  test('senza configurazione ogni richiesta dice not_configured', () async {
    final bare = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    bare.listen(ServerApi(name: 'Vuoto', identity: null, accounts: null, images: false, log: (_) {})
        .handle);
    final request = await http.getUrl(Uri.parse('http://127.0.0.1:${bare.port}/v2/server'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer tok:$owner');
    final response = await request.close();
    final body = jsonDecode(await utf8.decodeStream(response)) as Map<String, Object?>;
    expect((response.statusCode, code(body)), (503, 'not_configured'));
    await bare.close(force: true);
  });
}
