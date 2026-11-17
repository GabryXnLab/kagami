/// Chi chiama: l'account Google con cui si è fatto l'accesso all'app.
///
/// L'app manda il token della sua sessione: l'`access_token` del backend
/// compatibile Supabase di chi compila (`BackendVerifier`) o, nel passaggio
/// e per le app di prima, l'ID token di Firebase (`FirebaseVerifier`).
/// Quale dei due lo dice l'emittente (`iss`), letto senza fidarsi e poi
/// verificato da chi lo conosce (`TokenVerifier`). In tutti e due i casi
/// l'utente è l'indirizzo, in minuscolo: è quello che il proprietario mette
/// nell'elenco.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/signature.dart';

final Uri firebaseKeys = Uri.https(
  'www.googleapis.com',
  '/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
);

const String _firebaseIssuer = 'https://securetoken.google.com/';

class Identity {
  const Identity(this.email, {this.name});

  /// In minuscolo: Google non distingue le maiuscole negli indirizzi, e un
  /// elenco che le distinguesse chiuderebbe fuori chi le scrive diverse.
  final String email;
  final String? name;
}

/// Il token non vale: `401`, e l'app deve rifare l'accesso.
class IdentityError implements Exception {
  const IdentityError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Non si è potuto chiedere a chi rilascia i token (rete, `5xx`): il token
/// potrebbe valere, quindi non è un `401` ma un `503` da riprovare.
class IdentityUnavailable implements Exception {
  const IdentityUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class IdentityVerifier {
  Future<Identity> verify(String token);
}

/// Smista per emittente: il token di Firebase va a [firebase], ogni altro
/// al [backend]. Chi manca rifiuta i suoi token con un messaggio che dice
/// cosa fare.
class TokenVerifier implements IdentityVerifier {
  const TokenVerifier({this.backend, this.firebase});

  final IdentityVerifier? backend;
  final IdentityVerifier? firebase;

  @override
  Future<Identity> verify(String token) async {
    final issuer = Jwt.parse(token).claims['iss'];
    if (issuer is String && issuer.startsWith(_firebaseIssuer)) {
      final firebase = this.firebase;
      if (firebase == null) {
        throw const IdentityError('Questo server non accetta più l\'accesso di Firebase: aggiorna l\'app.');
      }
      return firebase.verify(token);
    }
    final backend = this.backend;
    if (backend == null) {
      throw const IdentityError(
          'Questo server non conosce il backend dell\'app: ricrealo col comando che genera l\'app.');
    }
    return backend.verify(token);
  }
}

/// Un JWT diviso, non ancora verificato.
class Jwt {
  Jwt._(this.header, this.claims, this.signed, this.signature);

  factory Jwt.parse(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw const IdentityError('Token non valido.');
    try {
      return Jwt._(_json(parts[0]), _json(parts[1]), ascii.encode('${parts[0]}.${parts[1]}'),
          base64Url.decode(base64Url.normalize(parts[2])));
    } on FormatException {
      throw const IdentityError('Token non valido.');
    }
  }

  final Map<String, Object?> header;
  final Map<String, Object?> claims;
  final List<int> signed;
  final List<int> signature;

  DateTime? time(String claim) {
    final seconds = claims[claim];
    return seconds is num ? DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round()) : null;
  }

  static Map<String, Object?> _json(String part) {
    final value = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part))));
    if (value is! Map<String, Object?>) throw const FormatException('Non è un oggetto');
    return value;
  }
}

const Duration _skew = Duration(minutes: 1);

/// Le chiavi RSA pubblicate da un emittente (JWKS), tenute per il
/// `max-age` della risposta. Un `kid` che non si conosce fa rileggere
/// l'elenco, ma al più una volta al minuto, così un token inventato non
/// diventa una richiesta all'emittente. Un 404 è «nessuna chiave», riletto
/// dopo un'ora; un emittente che non risponde è [IdentityUnavailable].
class KeySet {
  KeySet(this.url, this._clock);

  final Uri url;
  final DateTime Function() _clock;

  Map<String, RsaKey> _keys = const {};
  bool _published = false;
  DateTime _until = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _fetching;

  Future<RsaKey?> key(String kid) async {
    final now = _clock();
    final stale = now.isAfter(_until);
    final unknown = _published && !_keys.containsKey(kid) && now.difference(_fetchedAt) > const Duration(minutes: 1);
    if (stale || unknown) {
      try {
        await (_fetching ??= _fetch().whenComplete(() => _fetching = null));
      } on IdentityUnavailable {
        // Con le chiavi di prima, se ci sono: l'emittente che non risponde
        // non deve chiudere fuori tutti finché valgono ancora.
        if (_keys.isEmpty) rethrow;
      }
    }
    return _keys[kid];
  }

  Future<void> _fetch() async {
    _fetchedAt = _clock();
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await http.getUrl(url);
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decodeStream(response);
      if (response.statusCode == HttpStatus.notFound) {
        _keys = const {};
        _published = false;
        _until = _clock().add(const Duration(hours: 1));
        return;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw IdentityUnavailable('${url.host} non ha dato le sue chiavi (${response.statusCode}).');
      }
      final json = jsonDecode(body);
      final rows = json is Map ? json['keys'] : null;
      if (rows is! List) throw IdentityUnavailable('Chiavi di ${url.host} non valide.');
      _keys = {
        for (final row in rows.whereType<Map>())
          if (row['kid'] is String && row['n'] is String && row['e'] is String)
            row['kid'] as String: (n: _big(row['n'] as String), e: _big(row['e'] as String)),
      };
      _published = true;
      final maxAge = RegExp(r'max-age=(\d+)').firstMatch(response.headers.value('cache-control') ?? '');
      _until = _clock().add(Duration(seconds: int.tryParse(maxAge?.group(1) ?? '') ?? 3600));
    } on IdentityUnavailable {
      rethrow;
    } on Exception {
      throw IdentityUnavailable('${url.host} non risponde: non posso verificare chi sei.');
    } finally {
      http.close(force: true);
    }
  }

  static BigInt _big(String base64) => bytesToBig(base64Url.decode(base64Url.normalize(base64)));
}

/// L'ID token di Firebase: firmato da Google, `aud` il progetto dell'app.
/// Il server lo accetta solo se conosce il progetto (`KAGAMI_FIREBASE_PROJECT`,
/// o il `project` di una configurazione senza backend, quella di prima).
class FirebaseVerifier implements IdentityVerifier {
  FirebaseVerifier(this.project, {Uri? keys, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _keys = KeySet(keys ?? firebaseKeys, clock ?? DateTime.now);

  final String project;
  final DateTime Function() _clock;
  final KeySet _keys;

  @override
  Future<Identity> verify(String token) async {
    final jwt = Jwt.parse(token);
    final claims = jwt.claims;
    if (jwt.header['alg'] != 'RS256') throw const IdentityError('Token non valido.');
    final key = await _keys.key('${jwt.header['kid']}');
    if (key == null || !rsaVerify(key, jwt.signed, jwt.signature)) {
      throw const IdentityError('Firma del token non valida.');
    }

    final now = _clock();
    final expires = jwt.time('exp');
    final issued = jwt.time('iat');
    if (expires == null || !now.isBefore(expires.add(_skew))) {
      throw const IdentityError('Token scaduto.');
    }
    if (issued == null || issued.isAfter(now.add(_skew))) throw const IdentityError('Token non valido.');
    if (claims['aud'] != project || claims['iss'] != '$_firebaseIssuer$project') {
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
}

/// L'`access_token` del backend compatibile Supabase di chi compila
/// (`KAGAMI_BACKEND_URL`): emittente `<url>/auth/v1`.
///
/// Firma RS256 con le chiavi pubbliche dell'emittente, se le pubblica
/// (`/auth/v1/.well-known/jwks.json`); altrimenti (404, chiave sconosciuta,
/// ES256 o HS256) chiede al backend chi è con `GET /auth/v1/user`, e tiene
/// la risposta fino all'`exp` del token. Nessun segreto del backend sul
/// server: solo la chiave pubblica `anon`, che il gateway vuole in `apikey`.
class BackendVerifier implements IdentityVerifier {
  BackendVerifier(Uri url, this.anonKey, {DateTime Function()? clock, this.cacheSize = 512})
      : issuer = '${url.toString().replaceAll(RegExp(r'/+$'), '')}/auth/v1',
        _clock = clock ?? DateTime.now,
        _keys = KeySet(Uri.parse('${url.toString().replaceAll(RegExp(r'/+$'), '')}/auth/v1/.well-known/jwks.json'),
            clock ?? DateTime.now);

  final String issuer;
  final String anonKey;
  final int cacheSize;
  final DateTime Function() _clock;
  final KeySet _keys;

  /// Impronta del token → chi è e fino a quando. In ordine d'inserimento:
  /// pieno, esce il più vecchio.
  final LinkedHashMap<String, (Identity, DateTime)> _cache = LinkedHashMap();

  @override
  Future<Identity> verify(String token) async {
    final jwt = Jwt.parse(token);
    if (jwt.claims['iss'] != issuer) throw const IdentityError('Il token è di un altro backend.');
    if (jwt.claims['aud'] != 'authenticated') throw const IdentityError('Token non valido.');
    final now = _clock();
    final expires = jwt.time('exp');
    if (expires == null || !now.isBefore(expires.add(_skew))) throw const IdentityError('Token scaduto.');
    final issued = jwt.time('iat');
    if (issued != null && issued.isAfter(now.add(_skew))) throw const IdentityError('Token non valido.');

    final hash = sha256.convert(utf8.encode(token)).toString();
    final cached = _cache[hash];
    if (cached != null && now.isBefore(cached.$2)) return cached.$1;

    RsaKey? key;
    if (jwt.header['alg'] == 'RS256') {
      try {
        key = await _keys.key('${jwt.header['kid']}');
      } on IdentityUnavailable {
        // Resta `/user`: se non risponde neanche lui, lo dice lui.
      }
    }
    final Map<Object?, Object?> user;
    if (key != null) {
      if (!rsaVerify(key, jwt.signed, jwt.signature)) throw const IdentityError('Firma del token non valida.');
      final subject = jwt.claims['sub'];
      if (subject is! String || subject.isEmpty) throw const IdentityError('Token non valido.');
      user = jwt.claims;
    } else {
      user = await _user(token);
    }
    final who = _identity(user);
    // Solo `/user` lo dice; il JWT no, e lì basta Google come unico accesso.
    if (key == null && user['email_confirmed_at'] == null) {
      throw const IdentityError('L\'account non ha un indirizzo verificato.');
    }

    _cache.removeWhere((_, entry) => !now.isBefore(entry.$2));
    while (_cache.length >= cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[hash] = (who, expires.add(_skew));
    return who;
  }

  /// Chi è secondo il backend. Solo `app_metadata` decide: `user_metadata`
  /// lo scrive l'utente. Google dev'essere l'unico accesso, come per
  /// `kagami_me()` (`backend/migrations/0008_hardening.sql`): accanto a una
  /// password o a un altro provider l'indirizzo potrebbe non averlo
  /// verificato Google.
  static Identity _identity(Map<Object?, Object?> user) {
    final meta = user['app_metadata'];
    final providers = meta is Map ? meta['providers'] : null;
    final onlyGoogle = providers is List && providers.length == 1 && providers.single == 'google';
    if (user['is_anonymous'] == true || !onlyGoogle) {
      throw const IdentityError('Serve l\'accesso con un account Google.');
    }
    final email = user['email'];
    if (email is! String || email.trim().isEmpty) throw const IdentityError('L\'account non ha un indirizzo.');
    final profile = user['user_metadata'];
    final name = profile is Map ? profile['full_name'] ?? profile['name'] : null;
    return Identity(email.trim().toLowerCase(), name: name is String ? name : null);
  }

  Future<Map<Object?, Object?>> _user(String token) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await http.getUrl(Uri.parse('$issuer/user'));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set('apikey', anonKey);
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decodeStream(response).timeout(const Duration(seconds: 20));
      if (response.statusCode == HttpStatus.unauthorized || response.statusCode == HttpStatus.forbidden) {
        throw const IdentityError('Il backend non riconosce il token: rifai l\'accesso nell\'app.');
      }
      if (response.statusCode != HttpStatus.ok) {
        throw IdentityUnavailable('Il backend non risponde (${response.statusCode}): non posso verificare chi sei.');
      }
      final json = jsonDecode(body);
      if (json is! Map) throw const FormatException('Non è un oggetto');
      return json;
    } on IdentityError {
      rethrow;
    } on IdentityUnavailable {
      rethrow;
    } on Exception {
      throw const IdentityUnavailable('Il backend non risponde: non posso verificare chi sei.');
    } finally {
      http.close(force: true);
    }
  }
}
