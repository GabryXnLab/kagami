/// Il client HTTP dei siti: solo gli host che il provider dichiara suoi.
///
/// Porting di `mangaarchive/http.py`. Anche un redirect passa dal controllo,
/// quindi un sito non può mandare l'app a leggere da un host qualsiasi.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'model.dart';

/// Il sito chiede la verifica di Cloudflare: da qui si passa solo con una
/// pagina aperta in una WebView, dove la verifica la supera l'utente.
class CloudflareChallenge extends ProviderError {
  const CloudflareChallenge()
      : super('Il sito chiede la verifica di Cloudflare (HTTP 403).');
}

/// La rete non c'è: non è un errore del sito, e il lavoro aspetta che torni.
class ProviderOffline extends ProviderError {
  const ProviderOffline() : super('Connessione al provider non riuscita.');
}

class HttpStatusError extends ProviderError {
  HttpStatusError(this.status, {bool cdn = false, this.retryAfter})
      : super('HTTP $status dal ${cdn ? 'CDN del ' : ''}provider.');

  final int status;

  /// Quanto il sito ha chiesto di aspettare, se l'ha detto.
  final Duration? retryAfter;
}

/// `Retry-After` in secondi; la forma con la data i siti di manga non la usano.
Duration? _retryAfter(HttpClientResponse response) {
  final seconds = int.tryParse(response.headers.value(HttpHeaders.retryAfterHeader)?.trim() ?? '');
  return seconds == null ? null : Duration(seconds: seconds.clamp(0, 300));
}

typedef HttpResult = ({Uint8List body, String contentType});

/// Ciò che un provider usa per parlare col suo sito. Un'interfaccia perché i
/// test le rispondano da memoria.
abstract interface class ProviderHttp {
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer});

  /// Se una tavola esiste sul CDN, senza scaricarla.
  Future<bool> imageExists(String url, {required String referer});

  Future<Map<String, Object?>> json(String url);
}

/// Controlla che un indirizzo sia https, senza credenziali né porta, e di un
/// host del provider.
void checkUrl(String url, bool Function(Uri uri) allowed) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      !allowed(uri)) {
    throw const ProviderError('URL esterno ai domini consentiti dal provider.');
  }
}

const String defaultUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

/// Se [address] sta in una rete che non è internet: la propria macchina, la
/// rete di casa, la condivisa degli operatori, i blocchi riservati.
bool isPrivateAddress(InternetAddress address) {
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) return _privateV4(bytes);
  if (bytes.length != 16) return true;
  final head = bytes.sublist(0, 10).every((byte) => byte == 0);
  // ::ffff:a.b.c.d (IPv4-mapped) e 64:ff9b::/96 (NAT64) portano un IPv4 dentro.
  if (head && bytes[10] == 0xff && bytes[11] == 0xff) return _privateV4(bytes.sublist(12));
  if (bytes[0] == 0x00 && bytes[1] == 0x64 && bytes[2] == 0xff && bytes[3] == 0x9b &&
      bytes.sublist(4, 12).every((byte) => byte == 0)) {
    return _privateV4(bytes.sublist(12));
  }
  // :: e ::1
  if (bytes.sublist(0, 15).every((byte) => byte == 0) && bytes[15] <= 1) return true;
  if ((bytes[0] & 0xfe) == 0xfc) return true; // fc00::/7
  if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) return true; // fe80::/10
  if (bytes[0] == 0xff) return true; // multicast
  if (bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0d && bytes[3] == 0xb8) return true; // documentazione
  return false;
}

bool _privateV4(List<int> b) {
  final (a, c) = (b[0], b[1]);
  return a == 0 ||
      a == 10 ||
      a == 127 ||
      (a == 100 && c >= 64 && c <= 127) ||
      (a == 169 && c == 254) ||
      (a == 172 && c >= 16 && c <= 31) ||
      (a == 192 && c == 168) ||
      (a == 192 && c == 0 && b[2] == 0) ||
      (a == 192 && c == 0 && b[2] == 2) ||
      (a == 198 && (c == 18 || c == 19)) ||
      (a == 198 && c == 51 && b[2] == 100) ||
      (a == 203 && c == 0 && b[2] == 113) ||
      a >= 224;
}

typedef AddressLookup = Future<List<InternetAddress>> Function(String host);

class SiteHttp implements ProviderHttp {
  /// Con [publicOnly] ogni richiesta, anche ogni salto di redirect, risolve
  /// prima l'host e rifiuta se uno qualsiasi degli indirizzi è privato: per i
  /// siti degli utenti, il cui file arriva da chiunque. Resta aperta la
  /// finestra fra risoluzione e connessione (DNS rebinding): vedi `docs/siti.md`.
  SiteHttp(
    this.allowed, {
    this.attempts = 5,
    this.delay = const Duration(milliseconds: 500),
    this.userAgent = defaultUserAgent,
    this.cookies,
    this.publicOnly = false,
    AddressLookup? lookup,
  })  : lookup = lookup ?? InternetAddress.lookup,
         _client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 30)
          ..idleTimeout = const Duration(seconds: 15);

  final bool Function(Uri uri) allowed;
  final int attempts;
  final Duration delay;

  /// Dopo una verifica di Cloudflare superata nella WebView, le richieste
  /// passano solo con lo stesso user agent e gli stessi cookie.
  final String userAgent;
  final String? Function(Uri uri)? cookies;
  final bool publicOnly;
  final AddressLookup lookup;

  final HttpClient _client;

  Future<void> _checkPublic(String host) async {
    if (!publicOnly) return;
    final addresses = await lookup(host).timeout(const Duration(seconds: 30));
    if (addresses.isEmpty || addresses.any(isPrivateAddress)) {
      throw const ProviderError('L’host del sito risolve su un indirizzo privato.');
    }
  }

  void close() => _client.close(force: true);

  Future<HttpClientResponse> _open(
    String method,
    String url,
    Map<String, String> headers,
  ) async {
    var uri = Uri.parse(url);
    for (var hop = 0; hop < 10; hop++) {
      checkUrl(uri.toString(), allowed);
      await _checkPublic(uri.host);
      final request = await _client.openUrl(method, uri).timeout(const Duration(seconds: 30));
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      final cookie = cookies?.call(uri);
      if (cookie != null && cookie.isNotEmpty) request.headers.set('Cookie', cookie);
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (!response.isRedirect) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null) break;
      uri = uri.resolve(location);
    }
    throw const ProviderError('Troppi redirect dal provider.');
  }

  static bool _retryable(int status) => const {429, 500, 502, 503, 504}.contains(status);

  /// Fino a quando il sito ha chiesto di lasciarlo in pace. Vale per tutte
  /// le richieste in volo, non solo per quella respinta: le tavole scendono
  /// su più corsie, e se ognuna riprovasse per conto suo il sito vedrebbe
  /// la stessa raffica che l'ha fatto arrabbiare.
  DateTime _calm = DateTime.fromMillisecondsSinceEpoch(0);
  final Random _random = Random();

  Future<void> _waitCalm() async {
    final wait = _calm.difference(DateTime.now());
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }

  Future<T> _retrying<T>(Future<T> Function() once) async {
    for (var attempt = 0;; attempt++) {
      await _waitCalm();
      Duration? asked;
      try {
        return await once();
      } on HttpStatusError catch (error) {
        if (!_retryable(error.status) || attempt == attempts - 1) rethrow;
        asked = error.retryAfter;
      } on ProviderOffline {
        if (attempt == attempts - 1) rethrow;
      }
      // Attesa che raddoppia, con un po' di caso perché le corsie non
      // ripartano tutte nello stesso istante.
      final backoff = delay * (1 << attempt) * (0.75 + _random.nextDouble() / 2);
      final wait = asked != null && asked > backoff ? asked : backoff;
      final until = DateTime.now().add(wait);
      if (until.isAfter(_calm)) _calm = until;
    }
  }

  static String _type(HttpClientResponse response) =>
      response.headers.contentType?.mimeType.toLowerCase() ?? '';

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) {
    checkUrl(url, allowed);
    if (referer != null) checkUrl(referer, allowed);
    return _retrying(() async {
      try {
        final response = await _open('GET', url, {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/json,image/*;q=0.9,*/*;q=0.5',
          'Referer': ?referer,
        });
        if (response.statusCode != 200) {
          final challenged = response.headers.value('cf-mitigated') == 'challenge';
          await response.drain<void>();
          if (challenged) throw const CloudflareChallenge();
          throw HttpStatusError(response.statusCode, retryAfter: _retryAfter(response));
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(const Duration(seconds: 30))) {
          builder.add(chunk);
          if (builder.length > limit) {
            throw const ProviderError('Risposta troppo grande.');
          }
        }
        return (body: builder.takeBytes(), contentType: _type(response));
      } on SocketException {
        throw const ProviderOffline();
      } on TimeoutException {
        throw const ProviderOffline();
      } on HttpException {
        throw const ProviderOffline();
      }
    });
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) {
    checkUrl(url, allowed);
    checkUrl(referer, allowed);
    return _retrying(() async {
      try {
        final response = await _open('HEAD', url, {
          'User-Agent': userAgent,
          'Referer': referer,
          'Accept': 'image/*',
        });
        await response.drain<void>();
        if (response.statusCode == 404) return false;
        if (response.statusCode != 200) {
          throw HttpStatusError(response.statusCode, cdn: true, retryAfter: _retryAfter(response));
        }
        if (!_type(response).startsWith('image/')) {
          throw const ProviderError('Il CDN non ha restituito un’immagine.');
        }
        return true;
      } on SocketException {
        throw const ProviderOffline();
      } on TimeoutException {
        throw const ProviderOffline();
      } on HttpException {
        throw const ProviderOffline();
      }
    });
  }

  @override
  Future<Map<String, Object?>> json(String url) async {
    final result = await get(url);
    if (result.contentType != 'application/json') {
      throw const ProviderChanged('Risposta JSON non valida.');
    }
    return decodeJsonObject(result.body);
  }
}

Map<String, Object?> decodeJsonObject(Uint8List body) {
  final Object? value;
  try {
    value = jsonDecode(utf8.decode(body));
  } on FormatException {
    throw const ProviderChanged('JSON del provider non valido.');
  }
  if (value is! Map<String, Object?>) {
    throw const ProviderChanged('JSON del provider non valido.');
  }
  return value;
}

/// Una pagina della serie già in mano, letta nella WebView di un sito
/// protetto (`Provider.browser`): la serie si legge da lì, capitoli e tavole
/// passano da [inner] come sempre.
class SnapshotHttp implements ProviderHttp {
  SnapshotHttp(this.inner, this.url, this.body);

  final ProviderHttp inner;
  final String url;
  final Uint8List body;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (url == this.url) return (body: body, contentType: 'text/html');
    return inner.get(url, limit: limit, referer: referer);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) =>
      inner.imageExists(url, referer: referer);

  @override
  Future<Map<String, Object?>> json(String url) => inner.json(url);
}
