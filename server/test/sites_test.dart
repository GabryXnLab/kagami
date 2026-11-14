// I siti degli utenti sul server: ogni account ha i suoi, letti da `providers/`
// della sua cartella di Drive, anche con lo stesso id e file diversi.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart' show providers;
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';

Map<String, Object?> site({String host = 'examplescans.com', String name = 'Example Scans', int version = 1}) => {
      'format': 1,
      'id': 'examplescans',
      'name': name,
      'version': version,
      'home': 'https://$host',
      'hosts': [host],
      'mediaHosts': ['img.$host'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'url': 'https://$host/manga/{id}',
        'title': 'h1.title',
        'chapters': {
          'items': 'ul.chapters li',
          'url': {'css': 'a', 'attr': 'href'},
          'title': 'a',
          'id': {'from': 'url', 'regex': r'/chapter-([a-z0-9-]+)/?$'},
        },
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'div.reader img', 'url': {'attr': ['src']}},
      },
    };

final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, ...ascii.encode('IHDR'),
  0, 0, 0, 4, 0, 0, 0, 4, 8, 2, 0, 0, 0, //
]);

/// Risponde da memoria: la pagina della serie, quella del capitolo e le tavole.
class _Pages implements ProviderHttp {
  _Pages(this.host);

  final String host;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (url.startsWith('https://img.$host/')) return (body: _png, contentType: 'image/png');
    final body = switch (url) {
      _ when url == 'https://$host/manga/long-road' =>
        '<h1 class="title">The Long Road</h1><ul class="chapters"><li><a href="/manga/long-road/chapter-1/">Chapter 1</a></li></ul>',
      _ when url == 'https://$host/manga/long-road/chapter-1/' =>
        '<div class="reader"><img src="https://img.$host/1.jpg"></div>',
      _ => throw HttpStatusError(404),
    };
    return (body: Uint8List.fromList(utf8.encode(body)), contentType: 'text/html');
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => decodeJsonObject((await get(url)).body);
}

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('kagami-sites-'));
  tearDown(() => dir.delete(recursive: true));

  String root(String name) => p.join(dir.path, name, 'libreria');

  ArchiveFiles filesOf(String name) => ArchiveFiles(p.join(dir.path, name, 'dati'));

  Future<void> put(String name, String file, Object content) async {
    final target = File(p.join(root(name), 'providers', file));
    await target.parent.create(recursive: true);
    await target.writeAsString(content is String ? content : jsonEncode(content));
  }

  ServerWorker worker(String name, {String host = 'examplescans.com', Duration maxAge = const Duration(minutes: 5)}) => ServerWorker(
        filesOf(name),
        ArchiveEnvironment(
          scratch: Directory(p.join(dir.path, name, 'scratch')),
          storeFor: (_) => LocalStore(root(name)),
          httpFor: (provider, {userAgent, cookies = const {}}) => _Pages(host),
        ),
        blocked: () async => null,
        folder: () => 'f',
        retryAfter: const Duration(hours: 1),
        sitesMaxAge: maxAge,
        log: (_) {},
      );

  List<String> names(ServerWorker w) => w.withSites(() => [
        for (final provider in providers)
          if (provider.id == 'examplescans') provider.name,
      ]);

  bool accepts(ServerWorker w, String url) => w.withSites(() => providers.any((provider) => provider.accepts(url)));


  test('due account con lo stesso id e file diversi non si mescolano', () async {
    await put('a', 'examplescans.json', site(name: 'Sito di A'));
    await put('b', 'examplescans.json', site(name: 'Sito di B', host: 'examplescans.org'));
    final a = worker('a');
    final b = worker('b', host: 'examplescans.org');
    await a.refreshSites();
    await b.refreshSites();
    expect(names(a), ['Sito di A']);
    expect(names(b), ['Sito di B']);
    expect(accepts(a, 'https://examplescans.org/manga/x'), isFalse);
    expect(accepts(b, 'https://examplescans.org/manga/x'), isTrue);
    expect(providers.any((provider) => provider.id == 'examplescans'), isFalse);
  });

  test('refreshSites scrive sites.json accanto a repair.json, e readSiteIds lo rilegge', () async {
    final w = worker('a');
    expect(await readSiteIds(filesOf('a').directory.path), isNull);
    await put('a', 'examplescans.json', site());
    await w.refreshSites();
    expect(await readSiteIds(filesOf('a').directory.path), {'examplescans'});
    final raw = jsonDecode(await File(p.join(filesOf('a').directory.path, sitesFileName)).readAsString());
    expect(raw, {
      'sites': [
        {'id': 'examplescans', 'name': 'Example Scans'},
      ],
    });
  });

  test('checkSeries di un sito non incluso rilegge i siti se l\'ultima lettura è vecchia', () async {
    final w = worker('a', maxAge: Duration.zero);
    await w.refreshSites();
    await put('a', 'examplescans.json', site());
    await w.checkSeries('examplescans:long-road');
    expect(names(w), ['Example Scans']);
  });

  test('checkSeries di un sito incluso o di una lettura recente non rilegge', () async {
    final old = worker('a', maxAge: Duration.zero);
    await old.refreshSites();
    await put('a', 'examplescans.json', site());
    await old.checkSeries('manhwaread:x');
    expect(names(old), isEmpty);

    final recent = worker('b');
    await recent.refreshSites();
    await put('b', 'examplescans.json', site());
    await recent.checkSeries('examplescans:long-road');
    expect(names(recent), isEmpty);
  });

  test('un lavoro di un sito dell\'utente si scarica, con i siti letti prima del giro', () async {
    await put('a', 'examplescans.json', site());
    final w = worker('a');
    final files = filesOf('a');
    w.start();
    await files.enqueue(ArchiveJob(
      id: 'uno',
      url: 'https://examplescans.com/manga/long-road',
      title: 'The Long Road',
      target: const ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'f'),
    ));
    w.wake();
    for (var i = 0; i < 300 && (await files.history()).isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final outcome = (await files.history()).single;
    expect(outcome.ok, isTrue, reason: outcome.message);
    expect(Directory(root('a')).listSync().map((entity) => p.basename(entity.path)).any((n) => n.startsWith('The Long Road')),
        isTrue);
    await w.close();
  });

  test('un file rotto finisce in sitesErrors e il sito di prima resta; se sparisce, il sito sparisce', () async {
    await put('a', 'examplescans.json', site(version: 1));
    final w = worker('a');
    await w.refreshSites();
    expect(w.userSites.map((s) => s.id), ['examplescans']);

    await put('a', 'examplescans.json', '{non json');
    await w.refreshSites();
    expect((w.userSites.single as DeclarativeProvider).version, 1);
    expect(w.sitesErrors.single['file'], 'examplescans.json');
    expect(w.sitesErrors.single['message'], isNotEmpty);

    await put('a', 'examplescans.json', site(version: 2));
    await w.refreshSites();
    expect((w.userSites.single as DeclarativeProvider).version, 2);
    expect(w.sitesErrors, isEmpty);

    await File(p.join(root('a'), 'providers', 'examplescans.json')).delete();
    await w.refreshSites();
    expect(w.userSites, isEmpty);
  });

  group('API', () {
    late TestServer server;
    late FakeSpace me;
    final http = HttpClient();
    const owner = 'owner@example.com';

    setUp(() async {
      server = await TestServer.start(owner: owner);
      me = await server.ready(owner);
    });
    tearDown(() => server.close());

    Future<(int, Map<String, Object?>?)> call(String method, String path, {Object? body}) async {
      final request = await http.openUrl(method, server.address.replace(path: path));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer tok:$owner');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      return (response.statusCode, text.isEmpty ? null : jsonDecode(text) as Map<String, Object?>);
    }

    test('GET /v2/server elenca i siti per chi chiama, con userProviders e sitesErrors', () async {
      var (_, info) = await call('GET', '/v2/server');
      expect(info!['features'], contains('userProviders'));
      expect(info.containsKey('sitesErrors'), isFalse);
      expect((info['providers'] as List).cast<Map>().any((row) => row.containsKey('builtIn')), isFalse);

      me.jobs.userList = [DeclarativeProvider.fromJson(site(version: 3))];
      me.jobs.errors = [
        {'file': 'rotto.json', 'message': 'no'},
      ];
      (_, info) = await call('GET', '/v2/server');
      final mine = (info!['providers'] as List).cast<Map>().singleWhere((row) => row['id'] == 'examplescans');
      expect(mine, {'id': 'examplescans', 'name': 'Example Scans', 'builtIn': false, 'version': 3});
      expect(info['sitesErrors'], [
        {'file': 'rotto.json', 'message': 'no'},
      ]);
    });

    test('POST /v2/providers rilegge e risponde; senza cartella, 409', () async {
      me.jobs.userList = [DeclarativeProvider.fromJson(site())];
      final (status, body) = await call('POST', '/v2/providers', body: const {});
      expect(status, 200);
      expect(me.jobs.refreshes, 1);
      expect((body!['providers'] as List).cast<Map>().any((row) => row['id'] == 'examplescans'), isTrue);
      expect(body.containsKey('sitesErrors'), isFalse);

      me.drive.folderId = null;
      expect((await call('POST', '/v2/providers', body: const {})).$1, 409);
    });

    test('i link si validano coi siti di chi chiama', () async {
      final link = {'url': 'https://examplescans.com/manga/long-road'};
      expect((await call('POST', '/v2/jobs', body: link)).$1, 400);
      me.jobs.userList = [DeclarativeProvider.fromJson(site())];
      expect((await call('POST', '/v2/jobs', body: link)).$1, 201);
    });
  });
}
