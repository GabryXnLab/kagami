/// Il client HTTP dei siti: solo gli host che il provider dichiara suoi.
///
/// Porting di `mangaarchive/http.py`. Anche un redirect passa dal controllo,
/// quindi un sito non può mandare l'app a leggere da un host qualsiasi.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  HttpStatusError(this.status, {bool cdn = false})
      : super('HTTP $status dal ${cdn ? 'CDN del ' : ''}provider.');

  final int status;
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

class SiteHttp implements ProviderHttp {
  SiteHttp(
    this.allowed, {
    this.attempts = 3,
    this.delay = const Duration(milliseconds: 500),
    this.userAgent = defaultUserAgent,
    this.cookies,
  }) : _client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 30)
          ..idleTimeout = const Duration(seconds: 15);

  final bool Function(Uri uri) allowed;
  final int attempts;
  final Duration delay;

  /// Dopo una verifica di Cloudflare superata nella WebView, le richieste
  /// passano solo con lo stesso user agent e gli stessi cookie.
  final String userAgent;
  final String? Function(Uri uri)? cookies;

  final HttpClient _client;

  void close() => _client.close(force: true);

  Future<HttpClientResponse> _open(
    String method,
    String url,
    Map<String, String> headers,
  ) async {
    var uri = Uri.parse(url);
    for (var hop = 0; hop < 10; hop++) {
      checkUrl(uri.toString(), allowed);
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

  Future<T> _retrying<T>(Future<T> Function() once) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await once();
      } on HttpStatusError catch (error) {
        if (!_retryable(error.status) || attempt == attempts - 1) rethrow;
      } on ProviderOffline {
        if (attempt == attempts - 1) rethrow;
      }
      await Future<void>.delayed(delay * (1 << attempt));
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
          throw HttpStatusError(response.statusCode);
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
          throw HttpStatusError(response.statusCode, cdn: true);
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
      throw const ProviderError('Risposta JSON non valida.');
    }
    return decodeJsonObject(result.body);
  }
}

Map<String, Object?> decodeJsonObject(Uint8List body) {
  final Object? value;
  try {
    value = jsonDecode(utf8.decode(body));
  } on FormatException {
    throw const ProviderError('JSON del provider non valido.');
  }
  if (value is! Map<String, Object?>) {
    throw const ProviderError('JSON del provider non valido.');
  }
  return value;
}
