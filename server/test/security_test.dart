// Il server davanti a chi attacca (handoff F8, voce F8.3): token falsi o di
// altri, utenti che cercano lo spazio di un altro, percorsi costruiti ad
// arte, corpi enormi, indirizzi interni, file a riposo. Ogni caso è una
// minaccia di FASE-8.md (T3, T12, T13, T14, T15) o un punto della voce.
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/names.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/remote.dart' show ServerSetup;
import 'package:kagami_archive/stores.dart' show readJsonFile;
import 'package:kagami_archive/tracking.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:kagami_server/src/browser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';
import 'identity_test.dart' show b64, e, n, sign;

void main() {
  final now = DateTime.now();
  int seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

  group('token (T3)', () {
    late HttpServer backend;
    late String root;
    var jwks = true;
    Map<String, Object?> userBody = {};

    setUp(() async {
      jwks = true;
      backend = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      root = 'http://127.0.0.1:${backend.port}';
      backend.listen((request) async {
        final response = request.response..headers.contentType = ContentType.json;
        switch (request.uri.path) {
          case '/auth/v1/.well-known/jwks.json' when jwks:
            response.write(jsonEncode({
              'keys': [
                {'kty': 'RSA', 'kid': 'k1', 'n': b64(bigToBytes(n, 256)), 'e': b64(bigToBytes(e, 3))},
              ],
            }));
          case '/auth/v1/user':
            response.write(jsonEncode(userBody));
          default:
            response.statusCode = 404;
        }
        await response.close();
      });
      userBody = {
        'id': 'uid-1',
        'aud': 'authenticated',
        'email': 'amico@example.com',
        'email_confirmed_at': '2026-01-01T00:00:00Z',
        'is_anonymous': false,
        'app_metadata': {'provider': 'google', 'providers': ['google']},
      };
    });
    tearDown(() => backend.close(force: true));

    Map<String, Object?> claims([Map<String, Object?> change = const {}]) => {
          'iss': '$root/auth/v1',
          'aud': 'authenticated',
          'sub': 'uid-1',
          'role': 'authenticated',
          'iat': seconds(now.subtract(const Duration(minutes: 5))),
          'exp': seconds(now.add(const Duration(minutes: 55))),
          'email': 'amico@example.com',
          'is_anonymous': false,
          'app_metadata': {'provider': 'google', 'providers': ['google']},
          ...change,
        };

    Future<Object?> outcome(IdentityVerifier verifier, String token) async {
      try {
        return await verifier.verify(token);
      } on IdentityError catch (error) {
        return error;
      } on IdentityUnavailable catch (error) {
        return error;
      }
    }

    test('backend con JWKS: rifiuta ciò che il criterio del backend rifiuta', () async {
      final check = BackendVerifier(Uri.parse(root), 'anon');
      expect(await outcome(check, sign(claims())), isA<Identity>());
      final refused = <String, Map<String, Object?>>{
        'falso (firma di un\'altra chiave)': {'jti': 'x'},
        'scaduto': {'exp': seconds(now.subtract(const Duration(minutes: 2)))},
        'dal futuro': {'iat': seconds(now.add(const Duration(minutes: 10)))},
        'di un altro emittente': {'iss': 'https://altro.example.com/auth/v1'},
        'per un altro pubblico': {'aud': 'anon'},
        'senza email': {'email': null},
        'anonimo': {'is_anonymous': true},
        'non di Google': {'app_metadata': {'provider': 'email', 'providers': ['email']}},
        'Google e password': {'app_metadata': {'provider': 'google', 'providers': ['google', 'email']}},
        'Google e un altro provider': {'app_metadata': {'provider': 'google', 'providers': ['github', 'google']}},
        'solo «provider», senza l\'elenco': {'app_metadata': {'provider': 'google'}},
        'Google solo in user_metadata': {
          'app_metadata': <String, Object?>{},
          'user_metadata': {'providers': ['google']},
        },
      };
      for (final MapEntry(key: why, value: change) in refused.entries) {
        final token = why.startsWith('falso')
            ? sign(claims(change), exponent: BigInt.from(3))
            : sign(claims(change));
        expect(await outcome(check, token), isA<IdentityError>(), reason: why);
      }
    });

    test('backend senza JWKS (/user): anche l\'indirizzo non confermato resta fuori', () async {
      jwks = false;
      final check = BackendVerifier(Uri.parse(root), 'anon');
      expect(await outcome(check, sign(claims(), alg: 'ES256')), isA<Identity>());
      for (final change in <Map<String, Object?>>[
        {'email_confirmed_at': null},
        {'app_metadata': {'provider': 'google', 'providers': ['google', 'email']}},
        {'is_anonymous': true},
      ]) {
        userBody = {...userBody, ...change};
        expect(await outcome(BackendVerifier(Uri.parse(root), 'anon'), sign(claims({'jti': '$change'}), alg: 'ES256')),
            isA<IdentityError>(), reason: '$change');
        userBody = {...userBody, 'email_confirmed_at': '2026-01-01T00:00:00Z', 'is_anonymous': false,
          'app_metadata': {'provider': 'google', 'providers': ['google']}};
      }
      // `alg` diverso con le chiavi pubblicate: non si verifica in casa, decide /user.
      jwks = true;
      expect(await outcome(BackendVerifier(Uri.parse(root), 'anon'), sign(claims(), alg: 'none')), isA<Identity>());
    });

    test('la cache non tiene un token oltre exp', () async {
      var clock = now;
      final check = BackendVerifier(Uri.parse(root), 'anon', clock: () => clock);
      final token = sign(claims({'exp': seconds(now.add(const Duration(minutes: 10)))}));
      expect(await outcome(check, token), isA<Identity>());
      clock = now.add(const Duration(minutes: 12));
      expect('${await outcome(check, token)}', contains('scaduto'));
    });

    test('Firebase: algoritmo, progetto, provider e indirizzo', () async {
      final firebase = FirebaseVerifier('progetto', keys: Uri.parse('$root/auth/v1/.well-known/jwks.json'));
      Map<String, Object?> id([Map<String, Object?> change = const {}]) => {
            'iss': 'https://securetoken.google.com/progetto',
            'aud': 'progetto',
            'sub': 'uid-1',
            'iat': seconds(now),
            'exp': seconds(now.add(const Duration(hours: 1))),
            'email': 'amico@example.com',
            'email_verified': true,
            'firebase': {'sign_in_provider': 'google.com'},
            ...change,
          };
      expect(await outcome(firebase, sign(id())), isA<Identity>());
      expect(await outcome(firebase, sign(id(), alg: 'HS256')), isA<IdentityError>());
      expect(await outcome(firebase, sign(id({'aud': 'altro', 'iss': 'https://securetoken.google.com/altro'}))),
          isA<IdentityError>());
      expect(await outcome(firebase, sign(id({'email_verified': false}))), isA<IdentityError>());
      expect(await outcome(firebase, sign(id({'firebase': {'sign_in_provider': 'password'}}))), isA<IdentityError>());
      // Un token di Firebase a un server che non lo accetta più.
      expect(await outcome(TokenVerifier(backend: BackendVerifier(Uri.parse(root), 'anon')), sign(id())),
          isA<IdentityError>());
    });
  });

  group('nell\'API', () {
    const owner = 'owner@example.com';
    const friend = 'amico@example.com';
    var clock = DateTime.now();
    late TestServer server;
    final http = HttpClient();

    setUp(() async {
      clock = DateTime.now();
      server = await TestServer.start(owner: owner, now: () => clock);
      await server.ready(owner);
    });
    tearDown(() => server.close());

    Future<(int, Map<String, Object?>?)> call(String method, String path,
        {Object? body, String as = owner, List<int>? raw}) async {
      final request = await http.openUrl(method, server.address.resolve(path));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer tok:$as');
      if (raw != null) {
        request.contentLength = raw.length;
        request.add(raw);
      } else if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body is String ? body : jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      return (response.statusCode, text.isEmpty ? null : jsonDecode(text) as Map<String, Object?>);
    }

    String? code(Map<String, Object?>? body) => (body?['error'] as Map?)?['code'] as String?;

    test('A non legge né cambia coda, storia e serie di B; l\'identità viene solo dal token', () async {
      await server.accounts.add(friend);
      final mine = await server.ready(friend);
      final (created, job) = await call('POST', '/v2/jobs', body: {'url': 'https://mangak.io/x', 'title': 'Del proprietario'});
      expect(created, 201);
      final id = (job!['job'] as Map)['id'] as String;

      // Il corpo e la query non cambiano chi chiama.
      final (_, theirs) = await call('GET', '/v2/jobs?email=$owner&user=$owner', as: friend);
      expect(theirs!['queue'], isEmpty);
      await call('POST', '/v2/jobs?email=$owner', as: friend, body: {'url': 'https://mangak.io/y', 'email': owner});
      expect([for (final job in await mine.files.jobs()) job.url], ['https://mangak.io/y']);
      expect([for (final job in await server.spaces[owner]!.files.jobs()) job.url], ['https://mangak.io/x']);

      expect((await call('DELETE', '/v2/jobs/$id', as: friend)).$1, 404);
      expect(await server.spaces[owner]!.files.jobs(), hasLength(1));
      expect((await call('DELETE', '/v2/history', as: friend)).$1, 204);

      const target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'cartella');
      final ownerFiles = server.spaces[owner]!.files;
      await ownerFiles.ongoing.parent.create(recursive: true);
      await ownerFiles.ongoing.writeAsString(jsonEncode({
        'series': [
          TrackedSeries(provider: 'mangak', id: 'S1', title: 'Sua', url: 'https://mangak.io/x',
              target: target, chapters: const ['C1'], addedAt: DateTime.now(), ahead: 5).toJson(),
        ],
      }));
      expect((await call('GET', '/v2/ongoing', as: friend)).$2!['series'], isEmpty);
      expect((await call('PUT', '/v2/ongoing/mangak:S1', as: friend, body: {'wanted': 3})).$1, 404);
      expect((await call('DELETE', '/v2/ongoing/mangak:S1', as: friend)).$1, 404);
      expect(await Tracking(ownerFiles.ongoing).load(), hasLength(1));

      final (_, info) = await call('GET', '/v2/server', as: friend);
      expect((info!['me'] as Map)['email'], friend);
      expect((info['me'] as Map)['owner'], isFalse);
    });

    test('le rotte /v2/users solo al proprietario', () async {
      await server.accounts.add(friend);
      for (final (method, path, body) in [
        ('GET', '/v2/users', null),
        ('POST', '/v2/users', {'email': 'terzo@example.com'}),
        ('PUT', '/v2/users/$friend', {'expiresAt': null}),
        ('DELETE', '/v2/users/$friend', null),
        ('DELETE', '/v2/users/$owner', null),
      ]) {
        final (status, answer) = await call(method, path, as: friend, body: body);
        expect((status, code(answer)), (403, 'owner_only'), reason: '$method $path');
      }
      expect([for (final member in await server.accounts.list()) member.email], [owner, friend]);
    });

    test('valido ma non ammesso, o ammesso e scaduto: fuori', () async {
      expect(code((await call('GET', '/v2/jobs', as: 'estraneo@example.com')).$2), 'not_allowed');
      await server.accounts.add(friend, expiresAt: clock.add(const Duration(days: 1)));
      expect((await call('GET', '/v2/jobs', as: friend)).$1, 200);
      clock = clock.add(const Duration(days: 2));
      expect(code((await call('GET', '/v2/jobs', as: friend)).$2), 'not_allowed');
    });

    test('percorsi negli indirizzi e nei titoli: niente esce dallo spazio dell\'utente (T14)', () async {
      const marker = 'kagami-f83-fuori';
      for (final path in [
        '/v2/jobs/..%2F..%2F..%2Fusers.json',
        '/v2/ongoing/..%2F..%2Fqueue.json',
        '/v2/users/..%2F..%2Fusers.json',
      ]) {
        final (status, _) = await call(path.startsWith('/v2/ongoing') ? 'PUT' : 'DELETE', path,
            body: path.startsWith('/v2/ongoing') ? {'wanted': 1} : null);
        expect(status, anyOf(400, 404), reason: path);
      }
      for (final title in ['../../../$marker', '/tmp/$marker', '..\\..\\$marker', '$marker\u0000.json', 'x' * 100000]) {
        expect((await call('POST', '/v2/jobs', body: {'url': 'https://mangak.io/s${title.length}', 'title': title})).$1, 201);
      }
      // Gli altri file di test scrivono nella stessa cartella temporanea:
      // qui si cerca solo ciò che questo test avrebbe potuto creare.
      expect([for (final entry in server.dir.parent.listSync()) p.basename(entry.path)].where((n) => n.contains(marker)),
          isEmpty);
      final names = [
        for (final entity in server.dir.listSync(recursive: true)) p.relative(entity.path, from: server.dir.path),
      ];
      expect(names.where((name) => name.contains(marker) || name.split(p.separator).contains('..')), isEmpty);
    });

    test('corpi enormi o malformati: 4xx, e il server resta in piedi (T13)', () async {
      final big = List<int>.filled(maxBody + 1024, 0x20);
      try {
        final (status, answer) = await call('PUT', '/v2/check', raw: big);
        expect((status, code(answer)), (413, 'too_large'));
      } on SocketException {
        // Il server può chiudere prima che il client finisca di scrivere.
      } on HttpException {
        // Idem.
      }
      for (final raw in [
        utf8.encode('{"enabled": tru'),
        [0x7b, 0xff, 0xfe, 0x7d],
        utf8.encode('[1, 2, 3]'),
        utf8.encode('"testo"'),
      ]) {
        final (status, answer) = await call('PUT', '/v2/check', raw: raw);
        expect((status, code(answer)), (400, 'bad_request'));
      }
      // Annidato in profondità: il parser di Dart non è ricorsivo, e un campo
      // sconosciuto si ignora.
      expect((await call('PUT', '/v2/check', raw: utf8.encode('{"a": ${'[' * 200000}${']' * 200000}}'))).$1, 200);
      expect((await call('PUT', '/v2/check', body: {'unfollowed': List.filled(maxUnfollowed + 1, 'k')})).$1, 400);
      expect((await call('GET', '/v2/server')).$1, 200);
    });

    test('la coda di un utente ha un tetto (T13)', () async {
      final files = server.spaces[owner]!.files;
      const target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'cartella');
      await files.directory.create(recursive: true);
      await File(p.join(files.directory.path, 'queue.json')).writeAsString(jsonEncode({
        'jobs': [
          for (var i = 0; i < maxQueuedJobs; i++)
            ArchiveJob(id: 'j$i', url: 'https://mangak.io/s$i', title: '', target: target).toJson(),
        ],
      }));
      final (status, answer) = await call('POST', '/v2/jobs', body: {'url': 'https://mangak.io/nuova'});
      expect((status, code(answer)), (429, 'queue_full'));
      // Rimettere in coda una serie che c'è già non allunga la coda.
      expect((await call('POST', '/v2/jobs', body: {'url': 'https://mangak.io/s7'})).$1, 201);
      expect(await files.jobs(), hasLength(maxQueuedJobs));
    });

    test('nessuna rotta raggiunge l\'aggiornatore', () async {
      for (final path in ['/update', '/v2/update', '/v2/updater', '/v2/docker', '/v2/recreate', '/v2/server/update']) {
        for (final method in ['GET', 'POST']) {
          expect((await call(method, path)).$1, 404, reason: '$method $path');
        }
      }
    });
  });

  test('un guasto risponde 500 col corpo fisso, e il registro non ha token (T15)', () async {
    final dir = await Directory.systemTemp.createTemp('kagami-security-');
    addTearDown(() => dir.delete(recursive: true));
    final lines = <String>[];
    final api = ServerApi(
      name: 'Prova',
      identity: _Broken(),
      accounts: Accounts(File(p.join(dir.path, 'users.json')),
          owner: 'owner@example.com', open: (email) async => FakeSpace(Directory(p.join(dir.path, email)))),
      images: false,
      log: lines.add,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen(api.handle);
    final http = HttpClient();
    addTearDown(http.close);
    const token = 'segreto.del.token';
    final request = await http.getUrl(Uri.parse('http://127.0.0.1:${server.port}/v2/jobs?access_token=$token'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    expect(response.statusCode, 500);
    expect(jsonDecode(text), {
      'error': {'code': 'internal', 'message': 'Errore del server.'},
    });
    expect(text, isNot(contains('/srv/')));
    expect(lines.join('\n'), isNot(contains(token)));
  });

  group('percorsi dai nomi (T14)', () {
    const hostile = ['..', '.', '../../etc/passwd', '/etc/passwd', r'..\..\win', 'a\u0000b', 'CON', ' . . ', ''];

    test('cartelle di serie e capitoli: un solo segmento, mai . o ..', () {
      for (final value in [...hostile, 'x' * 5000, '../' * 1000]) {
        final series = Series(provider: 'mangak', id: value, title: value, url: '', coverUrl: '', metadata: const {},
            chapters: const []);
        for (final name in [seriesFolderName(series), chapterFolderName(Chapter(value, value, value, ''))]) {
          expect(name, isNot(anyOf(contains('/'), contains(r'\'), contains('\u0000'))), reason: value);
          expect(name, isNot(anyOf('.', '..')), reason: value);
          expect(name.runes.length, lessThan(200), reason: value);
        }
      }
    });

    test('la cartella di un utente è un\'impronta, qualunque sia l\'indirizzo', () {
      final paths = ServerPaths(Directory('/dati'));
      for (final email in [...hostile, '../../x@example.com', '/abs@example.com']) {
        final dir = paths.user(email).path;
        expect(p.dirname(dir), '/dati/users', reason: email);
        expect(p.basename(dir), matches(RegExp(r'^[0-9a-f]{16}$')), reason: email);
      }
    });

    test('l\'id di un sito dell\'utente non diventa un percorso', () {
      for (final id in [...hostile, 'A', 'a' * 33]) {
        expect(() => DeclarativeProvider.parse(jsonEncode({'format': siteFormat, 'id': id, 'name': 'x', 'hosts': ['example.com']})),
            throwsA(isA<SiteDefinitionError>().having((error) => error.message, 'message', startsWith('id'))),
            reason: id);
      }
    });
  });

  group('indirizzi interni (T12)', () {
    test('ogni richiesta del server ai siti, inclusi compresi, rifiuta gli indirizzi privati', () {
      final environment = serverEnvironment(
        ArchiveFiles(Directory.systemTemp.path),
        DriveSyncRemote(DriveClient(({bool refresh = false}) async => 'x', network: const ServerNetwork())),
        Directory.systemTemp,
        const NoImageTools(),
        owned: (_) => null,
      );
      for (final provider in builtInProviders) {
        final http = environment.httpFor(provider, userAgent: 'ua', cookies: const {'a': 'b'});
        expect(http, isA<SiteHttp>().having((http) => http.publicOnly, 'publicOnly', isTrue), reason: provider.id);
        (http as SiteHttp).close();
      }
    });

    test('loopback, rete privata, metadati, IPv6 locale e mappato: privati', () {
      for (final address in [
        '127.0.0.1', '10.1.2.3', '172.16.0.1', '192.168.1.1', '169.254.169.254', '100.64.0.1', '0.0.0.0',
        '::1', '::', 'fe80::1', 'fd00::1', '::ffff:127.0.0.1', '::ffff:169.254.169.254', '64:ff9b::a9fe:a9fe',
      ]) {
        expect(isPrivateAddress(InternetAddress(address)), isTrue, reason: address);
      }
      expect(isPrivateAddress(InternetAddress('1.1.1.1')), isFalse);
      expect(isPrivateAddress(InternetAddress('2606:4700:4700::1111')), isFalse);
    });

    test('un nome che risolve in privato: la richiesta non parte', () async {
      final http = SiteHttp((uri) => uri.host == 'sito.example.com',
          publicOnly: true, attempts: 1, lookup: (_) async => [InternetAddress('169.254.169.254')]);
      addTearDown(http.close);
      await expectLater(http.get('https://sito.example.com/serie'), throwsA(isA<ProviderError>()));
    });

    test('il Chromium del server non apre host privati né fuori dal sito', () async {
      final profile = await Directory.systemTemp.createTemp('kagami-security-browser-');
      addTearDown(() => profile.delete(recursive: true));
      final lines = <String>[];
      // Un eseguibile che non c'è: se il browser provasse ad aprire, il
      // registro direbbe «non si è aperta».
      final browser = HeadlessBrowser('/non/esiste/chromium', profile,
          log: lines.add, lookup: (host) async => [InternetAddress(host == 'manhwaread.com' ? '169.254.169.254' : '1.1.1.1')]);
      addTearDown(browser.close);
      const gate = BrowserGate(hosts: ['manhwaread.com', 'www.manhwaread.com'], seriesReady: 'true', searchReady: 'true');
      for (final url in [
        'https://manhwaread.com/manhwa/x/',
        'https://169.254.169.254/latest/meta-data/',
        'https://altro.example.com/x',
        'http://www.manhwaread.com/manhwa/x/',
        'file:///etc/passwd',
      ]) {
        lines.clear();
        expect(await browser.seriesPage(url, gate), isNull, reason: url);
        expect(lines.join(), contains('rifiut'), reason: url);
      }
    });
  });

  group('a riposo', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('kagami-security-'));
    tearDown(() => dir.delete(recursive: true));

    int mode(String path) => File(path).statSync().mode & 0x1ff;

    test('drive.json, users.json, shares.json e setup.json solo per l\'utente del server', () async {
      const client = GoogleClient('id', 'segreto');
      final paths = ServerPaths(Directory(p.join(dir.path, 'dati')));
      const setup = ServerSetup(
        project: 'progetto',
        client: client,
        owner: 'owner@example.com',
        refreshToken: 'refresh-1',
        folderId: 'cartella',
      );
      final blob = setup.encode();
      await applySetup(paths, blob);
      final drive = p.join(paths.user('owner@example.com').path, 'drive.json');
      final accounts = Accounts(paths.users, owner: 'owner@example.com', open: (_) async => throw UnimplementedError());
      await accounts.add('amico@example.com');
      final shares = File(p.join(dir.path, 'shares.json'));
      await ShareKeeper(shares).replace([HeldShare(folderId: 'f', permissionId: 'p', expiresAt: DateTime.utc(2030))]);
      for (final file in [paths.setup.path, drive, paths.users.path, shares.path]) {
        expect(mode(file).toRadixString(8), '600', reason: p.basename(file));
      }

      // Lo stesso KAGAMI_SETUP rilanciato non rimette il permesso di prima.
      await UserDrive(File(drive), client).put('refresh-2', 'cartella', null);
      await applySetup(paths, blob);
      expect((await readJsonFile(File(drive)))!['refreshToken'], 'refresh-2');
    }, testOn: '!windows');
  });
}

class _Broken implements IdentityVerifier {
  @override
  Future<Identity> verify(String token) async => throw StateError('guasto interno in /srv/kagami/identity.dart');
}
