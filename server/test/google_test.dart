import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/drive.dart';
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

  DriveTokens tokens() => DriveTokens(File(p.join(dir.path, 'drive-token.json')), client, endpoint: google.endpoint);

  test('senza permesso salvato serve drive login', () async {
    expect(await tokens().authorized, isFalse);
    await expectLater(tokens().token(), throwsA(isA<DriveNotAuthorized>()));
    expect(google.forms, isEmpty);
  });

  test('il token si rinnova dal refresh token e poi si riusa', () async {
    final t = tokens();
    await t.save('refresh-1');
    expect(await t.authorized, isTrue);
    expect(await t.token(), 'access-1');
    expect(await t.token(), 'access-1');
    expect(google.forms, hasLength(1));
    expect(google.forms.single, containsPair('grant_type', 'refresh_token'));
    expect(google.forms.single, containsPair('refresh_token', 'refresh-1'));
    google.reply = {'access_token': 'access-2', 'expires_in': 3600};
    expect(await t.token(refresh: true), 'access-2');
  });

  test('un permesso revocato è da rifare, non un errore del lavoro', () async {
    final t = tokens();
    await t.save('refresh-1');
    google
      ..status = 400
      ..reply = {'error': 'invalid_grant'};
    await expectLater(t.token(), throwsA(isA<DriveNotAuthorized>()));
  });

  test('Google irraggiungibile è la rete che manca: il giro aspetta', () async {
    final t = DriveTokens(File(p.join(dir.path, 'drive-token.json')), client,
        endpoint: Uri.parse('http://127.0.0.1:1/token'));
    await t.save('refresh-1');
    await expectLater(t.token(), throwsA(isA<DriveOffline>()));
  });

  test('l\'accesso: indirizzo con PKCE, codice dall\'indirizzo di ritorno, refresh token in cambio', () async {
    final auth = Authorization.start(client, 5555);
    final url = auth.url.queryParameters;
    expect(url['redirect_uri'], 'http://127.0.0.1:5555/');
    expect(url['scope'], driveWriteScope);
    expect(url['access_type'], 'offline');
    expect(url['code_challenge_method'], 'S256');
    final state = url['state']!;

    expect(() => auth.code(Uri.parse('http://127.0.0.1:5555/?code=x&state=altro')), throwsA(isA<DriveNotAuthorized>()));
    expect(() => auth.code(Uri.parse('http://127.0.0.1:5555/?error=access_denied&state=$state')),
        throwsA(isA<DriveNotAuthorized>()));
    final code = auth.code(Uri.parse('http://127.0.0.1:5555/?code=il-codice&state=$state&scope=x'));
    expect(code, 'il-codice');

    google.reply = {'access_token': 'a', 'refresh_token': 'refresh-nuovo', 'expires_in': 3600};
    expect(await auth.finish(code, endpoint: google.endpoint), 'refresh-nuovo');
    final form = google.forms.single;
    expect(form['grant_type'], 'authorization_code');
    expect(form['code_verifier'], isNotEmpty);
    expect(form['redirect_uri'], 'http://127.0.0.1:5555/');
  });
}
