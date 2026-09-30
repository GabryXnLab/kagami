import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/remote.dart' show ServerSetup;
import 'package:kagami_archive/stores.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// L'endpoint dei token di Google, in locale: risponde ciò che gli si dice
/// e ricorda cosa ha ricevuto.
class FakeGoogle {
  late HttpServer server;
  final List<Map<String, String>> forms = [];
  int status = 200;
  Map<String, Object?> reply = {'access_token': 'access-1', 'expires_in': 3600};

  Uri get endpoint => Uri.parse('http://127.0.0.1:${server.port}/token');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      forms.add(Uri.splitQueryString(await utf8.decodeStream(request)));
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(reply));
      await request.response.close();
    });
  }
}

void main() {
  late Directory dir;
  late FakeGoogle google;
  const client = GoogleClient('id.apps.googleusercontent.com', 'segreto');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kagami-google-');
    google = FakeGoogle();
    await google.start();
  });
  tearDown(() async {
    await google.server.close(force: true);
    await dir.delete(recursive: true);
  });

  File file() => File(p.join(dir.path, 'drive.json'));

  Future<UserDrive> drive({Uri? endpoint}) async {
    final drive = UserDrive(file(), client, endpoint: endpoint ?? google.endpoint);
    await drive.load();
    return drive;
  }

  test('senza permesso salvato va ridato dall\'app, senza chiedere niente a Google', () async {
    final d = await drive();
    expect(await d.authorized, isFalse);
    await expectLater(d.token(), throwsA(isA<DriveNotAuthorized>()));
    expect(await d.blocked(), contains('collegalo dall\'app'));
    expect(google.forms, isEmpty);
  });

  test('il token si rinnova dal refresh token col client della configurazione, poi si riusa', () async {
    final d = await drive();
    await d.put('refresh-1', 'cartella', 'Manga');
    expect(await d.authorized, isTrue);
    expect(await d.token(), 'access-1');
    expect(await d.token(), 'access-1');
    expect(google.forms, hasLength(1));
    expect(google.forms.single, containsPair('grant_type', 'refresh_token'));
    expect(google.forms.single, containsPair('refresh_token', 'refresh-1'));
    expect(google.forms.single, containsPair('client_secret', 'segreto'));
    google.reply = {'access_token': 'access-2', 'expires_in': 3600};
    expect(await d.token(refresh: true), 'access-2');

    // Riletto dal disco: permesso e cartella restano.
    final again = UserDrive(file(), client, endpoint: google.endpoint);
    await again.load();
    expect((await again.authorized, again.folderId, again.folderName), (true, 'cartella', 'Manga'));
    await again.forget();
    expect(await file().exists(), isFalse);
  });

  test('un permesso revocato è da rifare, non un errore del lavoro', () async {
    final d = await drive();
    await d.put('refresh-1', 'cartella', null);
    google
      ..status = 400
      ..reply = {'error': 'invalid_grant'};
    await expectLater(d.token(), throwsA(isA<DriveNotAuthorized>()));
    expect(await d.blocked(), contains('invalid_grant'));
  });

  test('un permesso nuovo che Google rifiuta non prende il posto del vecchio', () async {
    final d = await drive();
    await d.put('refresh-1', 'cartella', null);
    google
      ..status = 400
      ..reply = {'error': 'invalid_grant'};
    await expectLater(d.grant('refresh-2', 'altra'), throwsA(isA<DriveNotAuthorized>()));
    expect(d.folderId, 'cartella');
    expect((await readJsonFile(file()))!['refreshToken'], 'refresh-1');
  });

  test('Google irraggiungibile è la rete che manca: il giro aspetta', () async {
    final d = await drive(endpoint: Uri.parse('http://127.0.0.1:1/token'));
    await d.put('refresh-1', 'cartella', null);
    await expectLater(d.token(), throwsA(isA<DriveOffline>()));
    expect(await d.blocked(), contains('si riprova'));
  });

  test('il codice del telefono si riscatta per un refresh token', () async {
    google.reply = {'access_token': 'a', 'refresh_token': 'refresh-nuovo', 'expires_in': 3600};
    expect(await redeemServerCode(client, 'il-codice', endpoint: google.endpoint), 'refresh-nuovo');
    final form = google.forms.single;
    expect(form['grant_type'], 'authorization_code');
    expect(form['code'], 'il-codice');
    expect(form['redirect_uri'], '');

    google.reply = {'access_token': 'a', 'expires_in': 3600};
    await expectLater(redeemServerCode(client, 'x', endpoint: google.endpoint), throwsA(isA<GrantRejected>()));
  });

  test('la configurazione si applica una volta: rilanciare lo stesso comando non la riapplica', () async {
    final paths = ServerPaths(Directory(p.join(dir.path, 'dati')));
    const setup = ServerSetup(
      project: 'progetto',
      client: client,
      owner: 'owner@example.com',
      refreshToken: 'refresh-1',
      folderId: 'cartella',
      folderName: 'Manga',
      name: 'Casa',
    );
    final blob = setup.encode();
    expect(await applySetup(paths, null), isNull);
    final applied = (await applySetup(paths, blob))!;
    expect((applied.project, applied.owner, applied.name, applied.client.secret),
        ('progetto', 'owner@example.com', 'Casa', 'segreto'));
    final ownerDrive = File(p.join(paths.user('owner@example.com').path, 'drive.json'));
    expect(await readJsonFile(ownerDrive), {'refreshToken': 'refresh-1', 'folderId': 'cartella', 'folderName': 'Manga'});

    // Il server ha rinnovato il permesso dall'app: lo stesso blob non lo
    // rimette com'era.
    await UserDrive(ownerDrive, client).put('refresh-2', 'cartella', 'Manga');
    expect((await applySetup(paths, blob))!.hash, applied.hash);
    expect((await readJsonFile(ownerDrive))!['refreshToken'], 'refresh-2');
    // Senza blob vale quella di prima.
    expect((await applySetup(paths, null))!.owner, 'owner@example.com');
    await expectLater(applySetup(paths, 'rotto'), throwsFormatException);
  });
}
