/// Chi chiama: l'account Google con cui si è fatto l'accesso all'app.
///
/// L'app manda il token d'identità di Firebase, un JWT firmato da Google che
/// dura un'ora e che l'app rinnova da sé. Il server lo verifica con le chiavi
/// pubbliche di Google, senza chiamare nessuno per ogni richiesta, e ne
/// ricava l'indirizzo: è quello che il proprietario mette nell'elenco.
///
/// Il token di Firebase e non quello di Google Sign-In perché Firebase lo
/// rinnova senza mostrare niente, e perché il suo `aud` è il progetto
/// dell'app: un token rilasciato a un altro sito per lo stesso account qui
/// non vale.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

final Uri firebaseKeys = Uri.https(
  'www.googleapis.com',
  '/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
);

class Identity {
  const Identity(this.email, {this.name});

  /// In minuscolo: Google non distingue le maiuscole negli indirizzi, e un
  /// elenco che le distinguesse chiuderebbe fuori chi le scrive diverse.
  final String email;
  final String? name;
}

class IdentityError implements Exception {
  const IdentityError(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class IdentityVerifier {
  Future<Identity> verify(String token);
}

/// La chiave pubblica RSA di una firma.
typedef RsaKey = ({BigInt n, BigInt e});

class FirebaseVerifier implements IdentityVerifier {
  FirebaseVerifier(this.project, {Uri? keys, DateTime Function()? clock})
      : _keysUrl = keys ?? firebaseKeys,
        _clock = clock ?? DateTime.now;

  final String project;
  final Uri _keysUrl;
  final DateTime Function() _clock;

  Map<String, RsaKey> _keys = const {};
  DateTime _keysUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _fetching;

  static const Duration _skew = Duration(minutes: 1);

  @override
  Future<Identity> verify(String token) async {
    final parts = token.split('.');
    if (parts.length != 3) throw const IdentityError('Token non valido.');
    final Map<String, Object?> header;
    final Map<String, Object?> claims;
    final List<int> signature;
    try {
      header = _json(parts[0]);
      claims = _json(parts[1]);
      signature = base64Url.decode(base64Url.normalize(parts[2]));
    } on FormatException {
      throw const IdentityError('Token non valido.');
    }
    if (header['alg'] != 'RS256') throw const IdentityError('Token non valido.');
    final key = await _key('${header['kid']}');
    if (key == null || !rsaVerify(key, ascii.encode('${parts[0]}.${parts[1]}'), signature)) {
      throw const IdentityError('Firma del token non valida.');
    }

    final now = _clock();
    DateTime? at(Object? seconds) =>
        seconds is num ? DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round()) : null;
    final expires = at(claims['exp']);
    final issued = at(claims['iat']);
    if (expires == null || !now.isBefore(expires.add(_skew))) {
      throw const IdentityError('Token scaduto.');
    }
    if (issued == null || issued.isAfter(now.add(_skew))) throw const IdentityError('Token non valido.');
    if (claims['aud'] != project || claims['iss'] != 'https://securetoken.google.com/$project') {
      throw const IdentityError('Il token è di un\'altra app.');
    }
    final subject = claims['sub'];
    if (subject is! String || subject.isEmpty) throw const IdentityError('Token non valido.');
    final firebase = claims['firebase'];
    if (firebase is! Map || firebase['sign_in_provider'] != 'google.com') {
      throw const IdentityError('Serve l\'accesso con un account Google.');
    }
    final email = claims['email'];
    if (email is! String || email.isEmpty || claims['email_verified'] != true) {
      throw const IdentityError('L\'account non ha un indirizzo verificato.');
    }
    return Identity(email.trim().toLowerCase(), name: claims['name'] as String?);
  }

  static Map<String, Object?> _json(String part) {
    final value = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part))));
    if (value is! Map<String, Object?>) throw const FormatException('Non è un oggetto');
    return value;
  }

  /// La chiave con questo `kid`. Google le ruota ogni qualche ora: una che
  /// non si conosce fa rileggere l'elenco, ma al più una volta al minuto,
  /// così un token inventato non diventa una richiesta a Google.
  Future<RsaKey?> _key(String kid) async {
    final now = _clock();
    final stale = now.isAfter(_keysUntil);
    final unknown = !_keys.containsKey(kid) && now.difference(_fetchedAt) > const Duration(minutes: 1);
    if (stale || unknown) {
      try {
        await (_fetching ??= _fetch().whenComplete(() => _fetching = null));
      } on IdentityError {
        // Con le chiavi di prima, se ci sono: Google che non risponde non
        // deve chiudere fuori tutti finché valgono ancora.
        if (_keys.isEmpty) rethrow;
      }
    }
    return _keys[kid];
  }

  Future<void> _fetch() async {
    _fetchedAt = _clock();
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await http.getUrl(_keysUrl);
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decodeStream(response);
      if (response.statusCode != HttpStatus.ok) {
        throw IdentityError('Google non ha dato le sue chiavi (${response.statusCode}).');
      }
      final json = jsonDecode(body);
      final rows = json is Map ? json['keys'] : null;
      if (rows is! List) throw const IdentityError('Chiavi di Google non valide.');
      _keys = {
        for (final row in rows.whereType<Map>())
          if (row['kid'] is String && row['n'] is String && row['e'] is String)
            row['kid'] as String: (n: _big(row['n'] as String), e: _big(row['e'] as String)),
      };
      final maxAge = RegExp(r'max-age=(\d+)').firstMatch(response.headers.value('cache-control') ?? '');
      _keysUntil = _clock().add(Duration(seconds: int.tryParse(maxAge?.group(1) ?? '') ?? 3600));
    } on IdentityError {
      rethrow;
    } on Exception {
      throw const IdentityError('Google non risponde: non posso verificare chi sei.');
    } finally {
      http.close(force: true);
    }
  }

  static BigInt _big(String base64) => bytesToBig(base64Url.decode(base64Url.normalize(base64)));
}

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
