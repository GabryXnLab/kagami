// La verifica dei token con una chiave RSA di prova: la firma la fa il
// test, con l'esponente privato, come la farebbe Google.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:test/test.dart';

// Una chiave da 2048 bit generata con openssl solo per questi test.
final BigInt n = BigInt.parse(
  'ae665da81bedb563d693f9c0dac2f913bd5408f1b055a255a489a2c14ac728f8ebc63fb5b982f99ab9e50f49e6691f6c'
  '6279d1cdfceb42320d4f92c40b6e1032eb4531554aaf230cb5acc3beb036adf3129536a05fbd2ea371b935ee08e4604e'
  '8a4834da05e1e5e5a1e33b5d8c5a611b47071ee6cdd78aa92eada4eb6f1ac8f291aa7a2596e3a347a054a20909239d6c'
  '2cdff636f2b5c9532d219e437e8699e0b6b9246298569b415a29d4efa6680654c7127165c5e82efbd5be160c647eb73b'
  '56fb7e8c42fabedda3c4d2a59b53fa7b93eef3675bbd05ef9673eb5b27a4de3a59e6dc752efd49e65eb6d8cb4a90e0bb'
  'de4d616c95747386bd439ccf631577c3',
  radix: 16,
);
final BigInt d = BigInt.parse(
  '105e6a46f78c199cd677356cb2510a28c8a48fb703951e089f74b852751979512d16ad447a0b7edaff6758f12ce4f6a9'
  '3e70444ec05637c9d3dc56a050eefd2a9250d5bf0acf4d0bb4823e831cd89cfe0b634c3e6ee350f27a9f91736c8be6e0'
  '28497bb06fa1e813e4071c66278b6a16dc7ff618b55442defb3dc56a1597b42981e1bb6a22f6095bf28f5192a8ff1500'
  'fbbc8c7968220575b83841daf12f68713a1def78d9b5077dfd6cc15e1c7c1340bb5fbe5a81c8b80abd17aa3c481dbd4d'
  '93ef37c2a4040cd78b87c3a0a3cb4c87e40abea58b33e8732d24444219329658cdc9861c3d487dd1aabb986deb81642a'
  '0b142b7fad5b0a9fd00a179db4078a65',
  radix: 16,
);
final BigInt e = BigInt.from(65537);

String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String sign(Map<String, Object?> claims, {String kid = 'k1', String alg = 'RS256', BigInt? exponent}) {
  final head = b64(utf8.encode(jsonEncode({'alg': alg, 'kid': kid, 'typ': 'JWT'})));
  final body = b64(utf8.encode(jsonEncode(claims)));
  final length = (n.bitLength + 7) ~/ 8;
  final t = [
    0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
    ...sha256.convert(ascii.encode('$head.$body')).bytes,
  ];
  final em = [0x00, 0x01, for (var i = 0; i < length - t.length - 3; i++) 0xff, 0x00, ...t];
  final signature = bigToBytes(bytesToBig(em).modPow(exponent ?? d, n), length);
  return '$head.$body.${b64(signature)}';
}

void main() {
  late HttpServer google;
  var fetches = 0;
  var kid = 'k1';
  final now = DateTime.utc(2026, 9, 30, 12);
  late FirebaseVerifier verifier;

  setUp(() async {
    fetches = 0;
    kid = 'k1';
    google = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    google.listen((request) async {
      fetches++;
      request.response
        ..headers.set('cache-control', 'public, max-age=21600')
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'keys': [
            {'kty': 'RSA', 'alg': 'RS256', 'kid': kid, 'n': b64(bigToBytes(n, 256)), 'e': b64(bigToBytes(e, 3))},
          ],
        }));
      await request.response.close();
    });
    verifier = FirebaseVerifier(
      'progetto',
      keys: Uri.parse('http://127.0.0.1:${google.port}/keys'),
      clock: () => now,
    );
  });
  tearDown(() => google.close(force: true));

  int seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

  Map<String, Object?> claims([Map<String, Object?> change = const {}]) => {
        'iss': 'https://securetoken.google.com/progetto',
        'aud': 'progetto',
        'sub': 'uid-1',
        'iat': seconds(now.subtract(const Duration(minutes: 5))),
        'exp': seconds(now.add(const Duration(minutes: 55))),
        'email': 'Amico@Example.com',
        'email_verified': true,
        'name': 'Amico',
        'firebase': {'sign_in_provider': 'google.com'},
        ...change,
      };

  Future<String> refused(String token) async {
    try {
      await verifier.verify(token);
    } on IdentityError catch (error) {
      return error.message;
    }
    fail('il token doveva essere rifiutato');
  }

  test('un token di Google per questo progetto dice chi è, in minuscolo', () async {
    final who = await verifier.verify(sign(claims()));
    expect((who.email, who.name), ('amico@example.com', 'Amico'));
    await verifier.verify(sign(claims()));
    expect(fetches, 1, reason: 'le chiavi si tengono finché valgono');
  });

  test('firma sbagliata, contenuto cambiato, algoritmo diverso: rifiutati', () async {
    final good = sign(claims());
    final parts = good.split('.');
    final forged = b64(utf8.encode(jsonEncode(claims({'email': 'owner@example.com'}))));
    expect(await refused('${parts[0]}.$forged.${parts[2]}'), contains('Firma'));
    expect(await refused(sign(claims(), exponent: d - BigInt.one)), contains('Firma'));
    expect(await refused(sign(claims(), alg: 'none')), contains('non valido'));
    expect(await refused('${parts[0]}.${parts[1]}.'), contains('Firma'));
    expect(await refused('non-un-token'), contains('non valido'));
  });

  test('un token di un\'altra app, scaduto o dal futuro non vale', () async {
    expect(await refused(sign(claims({'aud': 'altro'}))), contains('altra app'));
    expect(await refused(sign(claims({'iss': 'https://securetoken.google.com/altro'}))), contains('altra app'));
    expect(await refused(sign(claims({'exp': seconds(now.subtract(const Duration(minutes: 2)))}))), contains('scaduto'));
    // Un minuto di tolleranza fra gli orologi.
    await verifier.verify(sign(claims({'exp': seconds(now.subtract(const Duration(seconds: 30)))})));
    expect(await refused(sign(claims({'iat': seconds(now.add(const Duration(minutes: 5)))}))), contains('non valido'));
  });

  test('serve un account Google con l\'indirizzo verificato', () async {
    expect(await refused(sign(claims({'firebase': {'sign_in_provider': 'password'}}))), contains('Google'));
    expect(await refused(sign(claims({'email_verified': false}))), contains('verificato'));
    expect(await refused(sign(claims({'email': null}))), contains('verificato'));
  });

  test('una chiave nuova di Google fa rileggere l\'elenco, ma non più di una volta al minuto', () async {
    await verifier.verify(sign(claims()));
    kid = 'k2';
    expect(await refused(sign(claims(), kid: 'k2')), contains('Firma'));
    expect(fetches, 1, reason: 'riletto da meno di un minuto');
    final later = FirebaseVerifier(
      'progetto',
      keys: Uri.parse('http://127.0.0.1:${google.port}/keys'),
      clock: () => now,
    );
    await later.verify(sign(claims(), kid: 'k2'));
  });

  test('la firma PKCS#1 si confronta intera', () {
    final message = utf8.encode('messaggio');
    final length = (n.bitLength + 7) ~/ 8;
    final t = [
      0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
      ...sha256.convert(message).bytes,
    ];
    List<int> signed(List<int> em) => bigToBytes(bytesToBig(em).modPow(d, n), length);
    final good = [0x00, 0x01, for (var i = 0; i < length - t.length - 3; i++) 0xff, 0x00, ...t];
    expect(rsaVerify((n: n, e: e), message, signed(good)), isTrue);
    // Lo stesso DigestInfo con del rumore dopo: chi legge il blocco invece
    // di confrontarlo la accetterebbe.
    final trailing = [0x00, 0x01, for (var i = 0; i < 8; i++) 0xff, 0x00, ...t, for (var i = 0; i < length - t.length - 11; i++) 0x42];
    expect(rsaVerify((n: n, e: e), message, signed(trailing)), isFalse);
    expect(rsaVerify((n: n, e: e), utf8.encode('altro'), signed(good)), isFalse);
    expect(rsaVerify((n: n, e: e), message, signed(good).sublist(1)), isFalse);
  });
}
