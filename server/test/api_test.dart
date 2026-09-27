import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/jobs.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  late ArchiveFiles files;
  late FakeJobs jobs;
  late FakeDrive drive;
  late String secret;
  final http = HttpClient();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kagami-api-');
    files = ArchiveFiles(dir.path);
    jobs = FakeJobs()..files = files;
    drive = FakeDrive();
    final keys = ApiKeys(File(p.join(dir.path, 'keys.json')));
    (_, secret) = await keys.create('test');
    final api = ServerApi(
      name: 'Prova',
      keys: keys,
      files: files,
      jobs: jobs,
      drive: drive,
      images: false,
      checkMinutes: 240,
      log: (_) {},
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(api.handle);
  });
  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  Future<(int, Map<String, Object?>?)> call(String method, String path, {Object? body, String? key}) async {
    final request = await http.openUrl(method, Uri.parse('http://127.0.0.1:${server.port}$path'));
    final token = key ?? secret;
    if (token.isNotEmpty) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body is String ? body : jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text) as Map<String, Object?>);
  }

  test('senza chiave, o con una sbagliata, solo la risposta che dice chi è', () async {
    final (open, about) = await call('GET', '/', key: '');
    expect(open, 200);
    expect(about, {'service': 'kagami-server', 'api': 1});
    final (status, body) = await call('GET', '/v1/server', key: '');
    expect(status, 401);
    expect((body!['error'] as Map)['code'], 'unauthorized');
    expect((await call('GET', '/v1/jobs', key: 'kagami_falsa')).$1, 401);
    expect((await call('POST', '/v1/jobs', key: 'kagami_falsa', body: {'url': 'x'})).$1, 401);
  });

  test('il server si presenta: versione, siti, Drive', () async {
    final (status, body) = await call('GET', '/v1/server');
    expect(status, 200);
    expect(body!['api'], 1);
    expect(body['name'], 'Prova');
    expect([for (final row in body['providers'] as List) (row as Map)['id']], containsAll(['mangak', 'manhwaread']));
    expect(body['drive'], {'authorized': true, 'folderId': 'cartella-libreria', 'folderName': 'MangaArchive'});
    expect(body['check'], {'minutes': 240});
  });

  test('un lavoro entra in coda nella cartella della libreria, sveglia il giro e si vede', () async {
    final (status, body) = await call('POST', '/v1/jobs', body: {
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
    expect(queued.target.folderId, 'cartella-libreria');

    final (_, list) = await call('GET', '/v1/jobs');
    expect([for (final row in list!['queue'] as List) (row as Map)['id']], [job['id']]);
    expect((list['status'] as Map)['state'], 'idle');
    expect(list['history'], isEmpty);
    // Il bersaglio interno non esce dall'API.
    expect((list['queue'] as List).single, isNot(contains('target')));
  });

  test('richieste sbagliate: link di nessun sito, campi di un altro tipo, JSON rotto', () async {
    Future<String> code(Object body) async => ((await call('POST', '/v1/jobs', body: body)).$2!['error'] as Map)['code'] as String;
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
    final (status, _) = await call('POST', '/v1/jobs', body: {
      'url': 'https://manhwaread.com/manhwa/disfarming/',
      'snapshot': '<html>la serie</html>',
    });
    expect(status, 201);
    final job = (await files.jobs()).single;
    expect(await File(job.snapshot!).readAsString(), '<html>la serie</html>');
  });

  test('senza Drive pronto il lavoro non entra: lo si dice', () async {
    drive.ready = false;
    final (status, body) = await call('POST', '/v1/jobs', body: {'url': 'https://mangak.io/x'});
    expect(status, 409);
    expect((body!['error'] as Map)['code'], 'drive_not_ready');
  });

  test('un lavoro si toglie; uno che non c\'è è 404', () async {
    final (_, body) = await call('POST', '/v1/jobs', body: {'url': 'https://mangak.io/x'});
    final id = (body!['job'] as Map)['id'] as String;
    expect((await call('DELETE', '/v1/jobs/$id')).$1, 204);
    expect(jobs.cancelled, [id]);
    expect((await call('DELETE', '/v1/jobs/$id')).$1, 404);
  });

  test('controllo delle serie in corso a richiesta, e cartella di Drive scelta dall\'app', () async {
    expect((await call('POST', '/v1/check')).$1, 202);
    expect(jobs.checks, 1);

    final link = 'https://drive.google.com/drive/folders/1AbC_d-EF?usp=sharing';
    final (status, body) = await call('PUT', '/v1/drive/folder', body: {'folderId': link});
    expect(status, 200);
    expect((body!['drive'] as Map)['folderId'], '1AbC_d-EF');
    final (bad, error) = await call('PUT', '/v1/drive/folder', body: {'folderId': 'non-esiste'});
    expect(bad, 400);
    expect((error!['error'] as Map)['code'], 'bad_folder');
  });

  test('indirizzi sconosciuti sono 404, anche con la chiave giusta', () async {
    expect((await call('GET', '/v1/niente')).$1, 404);
    expect((await call('GET', '/v2/server')).$1, 404);
    expect((await call('PATCH', '/v1/jobs')).$1, 404);
  });
}
