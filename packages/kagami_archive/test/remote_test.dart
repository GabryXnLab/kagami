import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/remote.dart';
import 'package:test/test.dart';

void main() {
  test('la configurazione del comando va e torna, e una incompleta si rifiuta', () {
    const setup = ServerSetup(
      backend: ServerSetupBackend(url: 'https://backend.example.com', anonKey: 'chiave'),
      project: 'progetto',
      client: GoogleClient('id.apps.googleusercontent.com', 'segreto'),
      owner: 'Proprietario@Gmail.com',
      refreshToken: '1//refresh',
      folderId: 'cartella',
      folderName: 'MangaArchive',
      name: 'Casa',
    );
    final blob = setup.encode();
    expect(blob, isNot(contains('=')));
    final back = ServerSetup.decode(blob);
    expect(back.project, 'progetto');
    expect(back.backend?.url, 'https://backend.example.com');
    expect(back.backend?.anonKey, 'chiave');
    expect(back.client.id, 'id.apps.googleusercontent.com');
    expect(back.client.secret, 'segreto');
    expect(back.owner, 'proprietario@gmail.com');
    expect(back.refreshToken, '1//refresh');
    expect(back.folderId, 'cartella');
    expect(back.folderName, 'MangaArchive');
    expect(back.name, 'Casa');
    expect(() => ServerSetup.decode('non-json'), throwsFormatException);
    expect(() => ServerSetup.decode(base64Url.encode(utf8.encode('{"v":1,"project":"p"}'))), throwsFormatException);

    // Il solo backend è valido; né backend né progetto no.
    const owner = {'email': 'a@example.com', 'refreshToken': 'r', 'folderId': 'f'};
    String blobOf(Map<String, Object?> extra) => base64Url.encode(utf8.encode(jsonEncode({
          'v': 1,
          'client': {'id': 'i', 'secret': 's'},
          'owner': owner,
          ...extra,
        })));
    final onlyBackend = ServerSetup.decode(blobOf({'backend': {'url': 'https://b.example.com', 'anonKey': 'k'}}));
    expect(onlyBackend.project, isNull);
    expect(onlyBackend.backend?.anonKey, 'k');
    expect(jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(onlyBackend.encode()))))
        as Map<String, Object?>, isNot(contains('project')));
    expect(ServerSetup.decode(blobOf({'project': 'p'})).backend, isNull);
    expect(() => ServerSetup.decode(blobOf({})), throwsFormatException);
    expect(() => ServerSetup.decode(blobOf({'backend': {'url': 'https://b.example.com'}})), throwsFormatException);
  });

  test('il comando accende il browser in un contenitore suo, su una rete senza uscita', () {
    const setup = ServerSetup(
      project: 'progetto',
      client: GoogleClient('id.apps.googleusercontent.com', 'segreto'),
      owner: 'proprietario@example.com',
      refreshToken: 'refresh',
      folderId: 'cartella',
    );
    final blob = setup.encode();
    final command = serverCommand(setup, image: 'ghcr.io/esempio/kagami-server');
    final [network, browser, server, connect, updater] = command.split('\n');
    expect(network,
        'docker network create --internal kagami-browser');
    expect(browser,
        'docker run -d --name kagami-browser --init --restart unless-stopped --no-healthcheck '
        '--network kagami-browser -v kagami-browser:/data ghcr.io/esempio/kagami-server browser');
    expect(server, startsWith('docker run -d --name kagami-server --init '));
    expect(server, contains('-e KAGAMI_SETUP=$blob '));
    expect(server, contains('-e KAGAMI_BROWSER=kagami-browser '));
    expect(server, contains('-v kagami-data:/data '));
    expect(server, endsWith(' ghcr.io/esempio/kagami-server'));
    expect(connect, 'docker network connect kagami-browser kagami-server');
    expect(updater, startsWith('docker run -d --name kagami-updater --init '));
    expect(updater, contains('-v /var/run/docker.sock:/var/run/docker.sock'));
    expect(updater, endsWith(' ghcr.io/esempio/kagami-server update'));
    expect(updater, isNot(contains('KAGAMI_SETUP')));
    expect(browser, isNot(contains('KAGAMI_SETUP')));
    expect(browser, isNot(contains('kagami-data')));
  });

  test('un collegamento della v1 perde la chiave e tiene l\'indirizzo', () {
    final link = ServerLink.fromJson({'url': 'http://nas:8080', 'key': 'kagami_vecchia'});
    expect(link.url, Uri.parse('http://nas:8080'));
    expect(link.toJson(), {'url': 'http://nas:8080'});
  });

  test('l\'indirizzo scritto a mano si ripulisce', () {
    expect(normalizeServerUrl('192.168.1.20:8080'), Uri.parse('http://192.168.1.20:8080'));
    expect(normalizeServerUrl(' https://kagami.esempio.it/ '), Uri.parse('https://kagami.esempio.it'));
    expect(normalizeServerUrl('https://esempio.it/kagami/'), Uri.parse('https://esempio.it/kagami'));
    expect(normalizeServerUrl(''), isNull);
    expect(normalizeServerUrl('ftp://esempio.it'), isNull);
  });

  test('in chiaro va bene solo fra le proprie mura', () {
    bool private(String url) => isPrivateAddress(Uri.parse(url));
    for (final url in [
      'http://192.168.1.20:8080',
      'http://10.0.0.5',
      'http://172.20.1.1',
      'http://100.101.102.103:8080',
      'http://127.0.0.1:8080',
      'http://[fd7a:115c:a1e0::1]:8080',
      'http://nas:8080',
      'http://nas.local',
      'http://casa.tail1234.ts.net',
    ]) {
      expect(private(url), isTrue, reason: url);
    }
    for (final url in ['http://203.0.113.10:8080', 'http://kagami.esempio.it', 'http://172.32.0.1', 'http://100.128.0.1']) {
      expect(private(url), isFalse, reason: url);
    }
  });

  test('userProviders si legge dalle features e refreshProviders chiama POST /v2/providers', () async {
    expect(ServerInfo.fromJson({'features': ['userProviders']}).userProviders, isTrue);
    expect(ServerInfo.fromJson({'features': ['repair']}).userProviders, isFalse);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <String>[];
    server.listen((request) async {
      if (request.uri.path == '/') return _hello(request);
      seen.add('${request.method} ${request.uri.path}');
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"providers": [], "sitesErrors": []}');
      await request.response.close();
    });
    final client = ServerClient(ServerLink(Uri.parse('http://127.0.0.1:${server.port}')), (_, _, {refresh = false}) async => 'Bearer t');
    addTearDown(client.close);
    await client.refreshProviders();
    expect(seen, ['POST /v2/providers']);
  });

  test('catalog: engine e serial si leggono dal campo catalog, assenti sono null', () {
    final info = ServerInfo.fromJson({'features': ['catalog'], 'catalog': {'engine': 2, 'serial': 42}});
    expect((info.catalogEngine, info.catalogSerial), (2, 42));
    final none = ServerInfo.fromJson({});
    expect((none.catalogEngine, none.catalogSerial), (null, null));
  });

  test('shares si legge dalle features e replaceShares manda l\'elenco intero a PUT /v2/me/shares', () async {
    expect(ServerInfo.fromJson({'features': ['shares']}).shares, isTrue);
    expect(ServerInfo.fromJson({'features': ['expiry']}).shares, isFalse);
    expect(ServerInfo.fromJson({}).shares, isFalse);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <String>[];
    server.listen((request) async {
      if (request.uri.path == '/') return _hello(request);
      final body = await utf8.decodeStream(request);
      seen.add('${request.method} ${request.uri.path} $body');
      request.response
        ..headers.contentType = ContentType.json
        ..write(request.method == 'PUT' ? body : '{"shares": [{"folderId": "f"}]}');
      await request.response.close();
    });
    final client = ServerClient(ServerLink(Uri.parse('http://127.0.0.1:${server.port}')), (_, _, {refresh = false}) async => 'Bearer t');
    addTearDown(client.close);
    final share = RemoteShare(folderId: 'f', permissionId: 'p', expiresAt: DateTime.utc(2026, 12, 1));
    expect(await client.replaceShares([share]), [share]);
    expect(await client.heldShares(), isEmpty, reason: 'una voce incompleta si salta');
    expect(seen, [
      'PUT /v2/me/shares {"shares":[{"folderId":"f","permissionId":"p","expiresAt":"2026-12-01T00:00:00.000Z"}]}',
      'GET /v2/me/shares ',
    ]);
  });
}

/// `GET /` di un server: chi è, senza token.
Future<void> _hello(HttpRequest request) async {
  request.response
    ..headers.contentType = ContentType.json
    ..write('{"service": "kagami-server", "api": 2}');
  await request.response.close();
}
