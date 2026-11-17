/// Verifica di firme RSA (RSASSA-PKCS1-v1_5 con SHA-256), in Dart puro.
///
/// Sta nel pacchetto perché la usano sia il server (token degli account) sia
/// l'app (catalogo firmato dei siti): un solo codice, senza `dart:io` né
/// dipendenze oltre a `crypto`.
library;

import 'package:crypto/crypto.dart';

/// La chiave pubblica RSA di una firma.
typedef RsaKey = ({BigInt n, BigInt e});

BigInt bytesToBig(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

List<int> bigToBytes(BigInt value, int length) {
  final bytes = List<int>.filled(length, 0);
  var rest = value;
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = (rest & BigInt.from(0xff)).toInt();
    rest = rest >> 8;
  }
  return bytes;
}

/// Il prefisso DER di un `DigestInfo` SHA-256 (RFC 8017, 9.2).
const List<int> _sha256Info = [
  0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
];

/// RSASSA-PKCS1-v1_5 con SHA-256.
///
/// Non si legge il blocco decifrato per trovarne l'impronta: si costruisce
/// quello atteso e si confronta per intero. Leggerlo è l'errore di tante
/// librerie che hanno accettato firme false (Bleichenbacher, 2006).
bool rsaVerify(RsaKey key, List<int> message, List<int> signature) {
  final length = (key.n.bitLength + 7) ~/ 8;
  if (signature.length != length) return false;
  final s = bytesToBig(signature);
  if (s >= key.n) return false;
  final decoded = bigToBytes(s.modPow(key.e, key.n), length);
  final t = [..._sha256Info, ...sha256.convert(message).bytes];
  final padding = length - t.length - 3;
  if (padding < 8) return false;
  final expected = [0x00, 0x01, for (var i = 0; i < padding; i++) 0xff, 0x00, ...t];
  var diff = 0;
  for (var i = 0; i < length; i++) {
    diff |= decoded[i] ^ expected[i];
  }
  return diff == 0;
}
