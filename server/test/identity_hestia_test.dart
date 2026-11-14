// I token del backend compatibile Supabase di chi compila: JWKS quando
// l'emittente lo pubblica, `GET /auth/v1/user` quando no, e il passaggio
// da Firebase. Il backend è un HttpServer sul loopback.
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/google_token.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';
import 'identity_test.dart' show b64, e, n, sign;

void main() {
  final now = DateTime.now();
  int seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

  late HttpServer backend;
  late String root;
  var jwks = true;
  var userStatus = 200;
  var jwksFetches = 0;
  var userFetches = 0;
  final userHeaders = <(String?, String?)>[];
  Map<String, Object?> userBody = {};

  setUp(() async {
    jwks = true;
    userStatus = 200;
    jwksFetches = 0;
    userFetches = 0;
    userHeaders.clear();
    userBody = {
      'id': 'uid-1',
      'email': 'Amico@Example.com',
      'email_confirmed_at': '2026-01-01T00:00:00Z',
      'is_anonymous': false,
      'app_metadata': {'provider': 'google', 'providers': ['google']},
      'user_metadata': {'full_name': 'Amico'},
    };
    backend = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    root = 'http://127.0.0.1:${backend.port}';
    backend.listen((request) async {
      final response = request.response;
      switch (request.uri.path) {
        case '/auth/v1/.well-known/jwks.json':
          jwksFetches++;
          if (!jwks) {
            response.statusCode = 404;
          } else {
            response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                'keys': [
                  {'kty': 'RSA', 'alg': 'RS256', 'kid': 'k1', 'n': b64(bigToBytes(n, 256)), 'e': b64(bigToBytes(e, 3))},
                ],
              }));
          }
        case '/auth/v1/user':
          userFetches++;
          userHeaders.add((request.headers.value(HttpHeaders.authorizationHeader), request.headers.value('apikey')));
          response.statusCode = userStatus;
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(userStatus == 200 ? userBody : {'msg': 'invalid JWT'}));
        default:
          response.statusCode = 404;
      }
      await response.close();
    });
  });
  tearDown(() => backend.close(force: true));

  Map<String, Object?> claims([Map<String, Object?> change = const {}]) => {
        'iss': '$root/auth/v1',
        'aud': 'authenticated',
        'sub': 'uid-1',
        'role': 'authenticated',
        'iat': seconds(now.subtract(const Duration(minutes: 5))),
        'exp': seconds(now.add(const Duration(minutes: 55))),
        'email': 'Amico@Example.com',
        'is_anonymous': false,
        'app_metadata': {'provider': 'google', 'providers': ['google']},
        'user_metadata': {'full_name': 'Amico'},
        ...change,
      };

  BackendVerifier verifier() => BackendVerifier(Uri.parse('$root/'), 'chiave-anon');

  Future<Object> refused(IdentityVerifier verifier, String token) async {
    try {
      await verifier.verify(token);
    } on IdentityError catch (error) {
      return error;
    } on IdentityUnavailable catch (error) {
      return error;
    }
    fail('il token doveva essere rifiutato');
  }

  test('con il JWKS: firma RS256 verificata in casa, senza chiedere /user', () async {
    final check = verifier();
    final who = await check.verify(sign(claims()));
    expect((who.email, who.name), ('amico@example.com', 'Amico'));
    expect(await check.verify(sign(claims({'sub': 'uid-1', 'jti': 'altro'}))), isA<Identity>());
    expect((jwksFetches, userFetches), (1, 0));

    final parts = sign(claims()).split('.');
    final forged = b64(utf8.encode(jsonEncode(claims({'email': 'owner@example.com'}))));
    final error = await refused(check, '${parts[0]}.$forged.${parts[2]}');
    expect(error, isA<IdentityError>());
    expect('$error', contains('Firma'));
  });

  test('senza JWKS (404) chiede /user una volta per token, poi la cache', () async {
    jwks = false;
    final check = verifier();
    final token = sign(claims(), alg: 'ES256');
    final who = await check.verify(token);
    expect(who.email, 'amico@example.com');
    expect(await check.verify(token), same(who));
    expect(userFetches, 1, reason: 'la seconda verifica viene dalla cache');
    expect(userHeaders.single, ('Bearer $token', 'chiave-anon'));

    // Anche un RS256 senza chiavi pubblicate passa da /user.
    await check.verify(sign(claims({'jti': 'due'})));
    expect(userFetches, 2);
    expect(jwksFetches, 1, reason: 'il 404 si ricorda per un\'ora');
  });

  test('la cache ha un limite', () async {
    jwks = false;
    final check = BackendVerifier(Uri.parse(root), 'chiave-anon', cacheSize: 2);
    final tokens = [for (var i = 0; i < 3; i++) sign(claims({'jti': '$i'}), alg: 'ES256')];
    for (final token in tokens) {
      await check.verify(token);
    }
    await check.verify(tokens[0]);
    expect(userFetches, 4, reason: 'il primo era uscito dalla cache');
  });

  test('scaduto, di un altro emittente o rifiutato dal backend: non valido', () async {
    final check = verifier();
    expect('${await refused(check, sign(claims({'exp': seconds(now.subtract(const Duration(minutes: 2)))})))}',
        contains('scaduto'));
    expect('${await refused(check, sign(claims({'iss': 'https://altro.example.com/auth/v1'})))}',
        contains('altro backend'));
    jwks = false;
    userStatus = 401;
    final error = await refused(verifier(), sign(claims(), alg: 'ES256'));
    expect(error, isA<IdentityError>());
    expect(userFetches, 1);
  });

  test('senza google fra i provider, o anonimo: rifiutato; user_metadata non conta', () async {
    final check = verifier();
    for (final change in [
      {'app_metadata': {'provider': 'email', 'providers': ['email']}},
      {'app_metadata': <String, Object?>{}, 'user_metadata': {'provider': 'google', 'providers': ['google']}},
      {'is_anonymous': true},
    ]) {
      final error = await refused(check, sign(claims(change)));
      expect('$error', contains('Google'), reason: '$change');
    }
    jwks = false;
    userBody = {...userBody, 'app_metadata': {'provider': 'email', 'providers': ['email']}};
    expect('${await refused(verifier(), sign(claims(), alg: 'ES256'))}', contains('Google'));
  });

  test('backend irraggiungibile o in errore: non disponibile, non «non valido»', () async {
    jwks = false;
    userStatus = 502;
    expect(await refused(verifier(), sign(claims(), alg: 'ES256')), isA<IdentityUnavailable>());

    final port = backend.port;
    await backend.close(force: true);
    final gone = BackendVerifier(Uri.parse('http://127.0.0.1:$port'), 'chiave-anon');
    expect(await refused(gone, sign(claims(), alg: 'ES256')), isA<IdentityUnavailable>());
    expect(await refused(gone, sign(claims())), isA<IdentityUnavailable>(), reason: 'neanche il JWKS risponde');
  });

  group('passaggio da Firebase', () {
    final setup = AppliedSetup(
      project: 'progetto',
      client: const GoogleClient('id', 'segreto'),
      owner: 'owner@example.com',
    );
    final firebaseToken = sign({
      'iss': 'https://securetoken.google.com/progetto',
      'aud': 'progetto',
      'sub': 'uid-1',
      'iat': seconds(now),
      'exp': seconds(now.add(const Duration(hours: 1))),
      'email': 'amico@example.com',
      'email_verified': true,
      'firebase': {'sign_in_provider': 'google.com'},
    });

    test('il Firebase di una configurazione di prima resta, finché non c\'è un backend', () {
      final old = identityFor(setup, const {}) as TokenVerifier;
      expect(old.backend, isNull);
      expect((old.firebase as FirebaseVerifier).project, 'progetto');

      final withBackend = AppliedSetup(
        project: 'progetto',
        client: setup.client,
        owner: setup.owner,
        backend: SetupBackend(Uri.parse(root), 'chiave-anon'),
      );
      final current = identityFor(withBackend, const {}) as TokenVerifier;
      expect(current.backend, isA<BackendVerifier>());
      expect(current.firebase, isNull);
      final both = identityFor(withBackend, const {'KAGAMI_FIREBASE_PROJECT': 'progetto'}) as TokenVerifier;
      expect(both.backend, isA<BackendVerifier>());
      expect(both.firebase, isA<FirebaseVerifier>());

      final fromEnv = identityFor(setup, {'KAGAMI_BACKEND_URL': root, 'KAGAMI_BACKEND_ANON_KEY': 'k'}) as TokenVerifier;
      expect((fromEnv.backend as BackendVerifier).issuer, '$root/auth/v1');
      expect(fromEnv.firebase, isA<FirebaseVerifier>(), reason: 'la configurazione non ha backend');

      final blob = base64Url.encode(utf8.encode(jsonEncode({'backend': {'url': root, 'anonKey': 'k'}})));
      expect(SetupBackend.fromBlob(blob)!.url, Uri.parse(root));
      expect(SetupBackend.fromBlob('non-un-blob'), isNull);
    });

    test('il token si smista per emittente; Firebase solo se acceso', () async {
      final firebase = FirebaseVerifier(
        'progetto',
        keys: Uri.parse('$root/auth/v1/.well-known/jwks.json'),
      );
      final both = TokenVerifier(backend: verifier(), firebase: firebase);
      expect((await both.verify(firebaseToken)).email, 'amico@example.com');
      expect((await both.verify(sign(claims()))).email, 'amico@example.com');

      final backendOnly = TokenVerifier(backend: verifier());
      expect('${await refused(backendOnly, firebaseToken)}', contains('Firebase'));
      final firebaseOnly = TokenVerifier(firebase: firebase);
      expect('${await refused(firebaseOnly, sign(claims()))}', contains('backend'));
    });
  });

  group('nell\'API', () {
    late Directory dir;
    late HttpServer api;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('kagami-identity-');
      final accounts = Accounts(
        File(p.join(dir.path, 'users.json')),
        owner: 'amico@example.com',
        open: (email) async => FakeSpace(Directory(p.join(dir.path, 'users', email))),
      );
      api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      api.listen(ServerApi(
        name: 'Prova',
        identity: TokenVerifier(backend: verifier()),
        accounts: accounts,
        images: false,
        log: (_) {},
      ).handle);
    });
    tearDown(() async {
      await api.close(force: true);
      await dir.delete(recursive: true);
    });

    Future<(int, String?)> get(String token) async {
      final http = HttpClient();
      final request = await http.getUrl(Uri.parse('http://127.0.0.1:${api.port}/v2/server'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      final body = jsonDecode(await utf8.decodeStream(response)) as Map;
      http.close();
      return (response.statusCode, (body['error'] as Map?)?['code'] as String?);
    }

    test('valido 200, scaduto 401, backend giù 503', () async {
      expect((await get(sign(claims()))).$1, 200);
      expect(await get(sign(claims({'exp': seconds(now.subtract(const Duration(minutes: 5)))}))),
          (401, 'unauthorized'));
      jwks = false;
      userStatus = 500;
      final api2 = await get(sign(claims({'jti': 'nuovo'}), alg: 'ES256'));
      expect(api2, (503, 'identity_unavailable'));
    });
  });
}
