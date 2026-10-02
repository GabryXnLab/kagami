import 'dart:convert';

import 'package:kagami_archive/remote.dart';
import 'package:test/test.dart';

void main() {
  test('la configurazione del comando va e torna, e una incompleta si rifiuta', () {
    const setup = ServerSetup(
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
    expect(back.client.id, 'id.apps.googleusercontent.com');
    expect(back.client.secret, 'segreto');
    expect(back.owner, 'proprietario@gmail.com');
    expect(back.refreshToken, '1//refresh');
    expect(back.folderId, 'cartella');
    expect(back.folderName, 'MangaArchive');
    expect(back.name, 'Casa');
    expect(() => ServerSetup.decode('non-json'), throwsFormatException);
    expect(() => ServerSetup.decode(base64Url.encode(utf8.encode('{"v":1,"project":"p"}'))), throwsFormatException);

    final command = serverCommand(setup, image: 'ghcr.io/esempio/kagami-server');
    expect(command, startsWith('docker run -d --name kagami-server'));
    expect(command, contains('-e KAGAMI_SETUP=$blob '));
    final [server, updater] = command.split('\n');
    expect(server, endsWith(' ghcr.io/esempio/kagami-server'));
    expect(updater, startsWith('docker run -d --name kagami-updater'));
    expect(updater, contains('-v /var/run/docker.sock:/var/run/docker.sock'));
    expect(updater, endsWith(' ghcr.io/esempio/kagami-server update'));
    expect(updater, isNot(contains('KAGAMI_SETUP')));
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
}
