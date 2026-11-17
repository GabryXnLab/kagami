import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/signature.dart';
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
final int length = (n.bitLength + 7) ~/ 8;
final List<int> message = utf8.encode('catalogo dei siti');

List<int> encoded(List<int> digest, {int extra = 0}) {
  final t = [
    0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
    ...digest,
  ];
  return [0x00, 0x01, for (var i = 0; i < length - t.length - 3 + extra; i++) 0xff, 0x00, ...t];
}

List<int> sign(List<int> em) => bigToBytes(bytesToBig(em).modPow(d, n), length);

void main() {
  final key = (n: n, e: e);
  final good = sign(encoded(sha256.convert(message).bytes));

  test('una firma valida è accettata', () {
    expect(rsaVerify(key, message, good), isTrue);
  });

  test('un bit cambiato nella firma la invalida', () {
    final bad = [...good]..[10] ^= 1;
    expect(rsaVerify(key, message, bad), isFalse);
  });

  test('il messaggio cambiato è rifiutato', () {
    expect(rsaVerify(key, utf8.encode('altro'), good), isFalse);
  });

  test('una firma di lunghezza sbagliata è rifiutata', () {
    expect(rsaVerify(key, message, good.sublist(1)), isFalse);
    expect(rsaVerify(key, message, [0, ...good]), isFalse);
  });

  test('una firma s >= n è rifiutata', () {
    final high = bigToBytes(n, length);
    expect(rsaVerify(key, message, high), isFalse);
    expect(rsaVerify(key, message, List<int>.filled(length, 0xff)), isFalse);
  });

  test('un blocco con byte in più dopo l\'impronta è rifiutato', () {
    final em = [...encoded(sha256.convert(message).bytes, extra: -2), 0x00, 0x00];
    expect(rsaVerify(key, message, sign(em)), isFalse);
  });
}
