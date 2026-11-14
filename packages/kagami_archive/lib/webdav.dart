/// Una libreria MALF su WebDAV (un NAS, Nextcloud, un cloud che lo parla),
/// in sola lettura. Gemello di `drive.dart` per tempi massimi, abbandono
/// delle richieste e ripresa dei download, ma senza `NetworkState`: un NAS
/// di casa risponde anche quando Internet non c'è, e la rete che manca si
/// scopre provando.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import 'remote.dart' show isPrivateAddress;
import 'transport.dart';

const String _dav = 'DAV:';

/// L'indirizzo di una sorgente WebDAV, controllato prima di costruire il
/// trasporto: `https`, oppure `http` solo verso un host della rete di casa
/// (chi chiama avvisa che lì la password viaggia in chiaro: `scheme ==
/// 'http'`). Niente credenziali nell'indirizzo, niente `?` né `#`.
///
/// [FormatException] con il motivo, da mostrare all'utente.
Uri webDavAddress(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || uri.host.isEmpty || !(uri.scheme == 'https' || uri.scheme == 'http')) {
    throw const FormatException('Serve un indirizzo https://');
  }
  if (uri.userInfo.isNotEmpty) {
    throw const FormatException('Utente e password vanno nei loro campi, non nell’indirizzo');
  }
  if (uri.hasQuery || uri.hasFragment) {
    throw const FormatException('L’indirizzo non può contenere «?» o «#»');
  }
  if (uri.scheme == 'http' && !isPrivateAddress(uri)) {
    throw const FormatException('In chiaro (http) solo verso la rete di casa: serve https://');
  }
  return uri.replace(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    pathSegments: uri.pathSegments.where((segment) => segment.isNotEmpty),
  );
}

class WebDavTransport implements StorageTransport {
  /// [address] passa da [webDavAddress]: un indirizzo non ammesso è un
  /// [FormatException] qui.
  WebDavTransport(
    Uri address, {
    String? user,
    String? password,
    @visibleForTesting Duration connect = const Duration(seconds: 10),
    @visibleForTesting this.answer = const Duration(seconds: 20),
    @visibleForTesting this.stall = const Duration(seconds: 20),
    @visibleForTesting this.retryDelay = const Duration(milliseconds: 500),
    @visibleForTesting this.attempts = 4,
    @visibleForTesting this.textLimit = textLimitBytes,
    @visibleForTesting this.downloadLimit = downloadLimitBytes,
  })  : _base = webDavAddress(address.toString()),
        _auth = user == null || user.isEmpty
            ? null
            : 'Basic ${base64.encode(utf8.encode('$user:${password ?? ''}'))}',
        _http = HttpClient() {
    _http
      ..connectionTimeout = connect
      ..maxConnectionsPerHost = 8
      ..idleTimeout = const Duration(seconds: 30);
  }

  final Uri _base;
  final String? _auth;
  final HttpClient _http;

  /// Quanto si aspetta la risposta a una richiesta già mandata.
  final Duration answer;

  /// Quanto silenzio a metà di un corpo vale un'interruzione.
  final Duration stall;

  /// La prima attesa dopo un 429 o un 5xx; raddoppia a ogni tentativo.
  final Duration retryDelay;
  final int attempts;

  /// Il tetto di [text] (`textLimitBytes`).
  final int textLimit;

  /// Il tetto di [download] (`downloadLimitBytes`), sul file intero.
  final int downloadLimit;

  static const int _writeBlock = 256 * 1024;
  static const int _maxHops = 5;
  static const Set<int> _redirects = {301, 302, 303, 307, 308};

  static const String _propfind = '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:"><d:prop>'
      '<d:resourcetype/><d:getcontentlength/><d:getlastmodified/><d:getetag/>'
      '</d:prop></d:propfind>';

  late final List<String> _baseSegments = _base.pathSegments.where((s) => s.isNotEmpty).toList();

  Uri _uri(List<String> segments, {bool folder = false}) => _base.replace(
        pathSegments: [..._baseSegments, ...segments, if (folder) ''],
      );

  bool _sameOrigin(Uri uri) =>
      uri.scheme == _base.scheme && uri.host.toLowerCase() == _base.host && uri.port == _base.port;

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final segments = transportSegments(path);
    final entries = await _find(segments, depth: 1, folder: true);
    final self = segments.join('/');
    return [for (final entry in entries) if (entry.path != self) entry];
  }

  @override
  Future<RemoteEntry?> stat(String path) async {
    final segments = transportSegments(path);
    final List<RemoteEntry> entries;
    try {
      entries = await _find(segments, depth: 0);
    } on TransportNotFound {
      return null;
    }
    final self = segments.join('/');
    for (final entry in entries) {
      if (entry.path == self) return entry;
    }
    throw const TransportException('Risposta WebDAV senza la voce chiesta');
  }

  @override
  Future<String> text(String path) async {
    final response = await _send('GET', _uri(transportSegments(path)));
    final builder = BytesBuilder(copy: false);
    await _collect(response, (chunk) {
      if (builder.length + chunk.length > textLimit) {
        throw TransportException('Il file $path supera $textLimit byte');
      }
      builder.add(chunk);
    });
    try {
      return utf8.decode(builder.takeBytes());
    } on FormatException {
      throw TransportException('Il file $path non è testo UTF-8');
    }
  }

  @override
  Future<void> download(String path, File target, {int resumeFrom = 0}) async {
    final segments = transportSegments(path);
    if (resumeFrom < 0 ||
        (resumeFrom > 0 && (!await target.exists() || await target.length() < resumeFrom))) {
      throw ArgumentError.value(resumeFrom, 'resumeFrom', 'oltre ciò che c’è in target');
    }
    final HttpClientResponse response;
    try {
      response = await _send('GET', _uri(segments), headers: {
        if (resumeFrom > 0) HttpHeaders.rangeHeader: 'bytes=$resumeFrom-',
      });
    } on TransportException catch (error) {
      // Il pezzo che c'era non vale più (il file è cambiato o era già
      // tutto): si ricomincia pulito, una volta.
      if (error.status == HttpStatus.requestedRangeNotSatisfiable && resumeFrom > 0) {
        await target.delete();
        return download(path, target);
      }
      rethrow;
    }
    final partial = response.statusCode == HttpStatus.partialContent;
    if (partial) {
      final range = RegExp(r'^bytes\s+(\d+)-')
          .firstMatch(response.headers.value(HttpHeaders.contentRangeHeader) ?? '');
      if (range == null || int.parse(range[1]!) != resumeFrom) {
        _drop(response);
        throw const TransportException('La sorgente ha mandato un pezzo diverso da quello chiesto', status: 206);
      }
    }
    final RandomAccessFile file;
    try {
      // 200 al posto di 206: il server non riprende, e il file si riscrive.
      file = await target.open(mode: partial ? FileMode.append : FileMode.write);
      if (partial) {
        await file.truncate(resumeFrom);
        await file.setPosition(resumeFrom);
      }
    } on Object {
      _drop(response);
      rethrow;
    }
    // A blocchi e scritto anche quando la connessione cade: è da lì che il
    // prossimo tentativo riparte (lo stesso motivo di `DriveClient.download`).
    final pending = BytesBuilder(copy: false);
    var total = partial ? resumeFrom : 0;
    var tooBig = false;
    try {
      await _collect(response, (chunk) async {
        // In corsa: oltre il tetto si smette di leggere, senza aspettare la fine.
        total += chunk.length;
        if (total > downloadLimit) {
          tooBig = true;
          throw TransportException('Il file $path supera $downloadLimit byte');
        }
        pending.add(chunk);
        if (pending.length >= _writeBlock) await file.writeFrom(pending.takeBytes());
      });
    } finally {
      if (!tooBig && pending.isNotEmpty) await file.writeFrom(pending.takeBytes());
      await file.close();
      // Un pezzo di un file troppo grande non è un punto da cui riprendere.
      if (tooBig) await target.delete();
    }
  }

  @override
  void close() => _http.close(force: true);

  Future<List<RemoteEntry>> _find(List<String> segments, {required int depth, bool folder = false}) async {
    final response = await _send(
      'PROPFIND',
      _uri(segments, folder: folder),
      headers: {'Depth': '$depth', HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8'},
      body: utf8.encode(_propfind),
    );
    final builder = BytesBuilder(copy: false);
    await _collect(response, builder.add);
    return _parse(utf8.decode(builder.takeBytes(), allowMalformed: true));
  }

  /// Il `multistatus` per nome locale e namespace `DAV:`: i server scelgono
  /// prefissi diversi (`d:`, `D:`, `lp1:`, nessuno).
  List<RemoteEntry> _parse(String body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException {
      throw const TransportException('Risposta WebDAV non valida');
    }
    final entries = <RemoteEntry>[];
    for (final response in document.findAllElements('response', namespaceUri: _dav)) {
      final href = response.getElement('href', namespaceUri: _dav)?.innerText.trim();
      final segments = href == null ? null : _relative(href);
      if (segments == null) continue;
      final props = [
        for (final propstat in response.findElements('propstat', namespaceUri: _dav))
          if (_ok(propstat.getElement('status', namespaceUri: _dav)?.innerText))
            ?propstat.getElement('prop', namespaceUri: _dav),
      ];
      if (props.isEmpty) continue;
      XmlElement? prop(String name) {
        for (final element in props) {
          final found = element.getElement(name, namespaceUri: _dav);
          if (found != null) return found;
        }
        return null;
      }

      final folder = prop('resourcetype')?.getElement('collection', namespaceUri: _dav) != null;
      DateTime? modified;
      final date = prop('getlastmodified')?.innerText.trim();
      if (date != null && date.isNotEmpty) {
        try {
          modified = HttpDate.parse(date);
        } on HttpException {
          modified = null;
        }
      }
      final etag = prop('getetag')?.innerText.trim();
      entries.add(RemoteEntry(
        path: segments.join('/'),
        name: segments.isEmpty ? '' : segments.last,
        folder: folder,
        size: folder ? null : int.tryParse(prop('getcontentlength')?.innerText.trim() ?? ''),
        modified: modified,
        etag: etag == null || etag.isEmpty ? null : etag,
      ));
    }
    return entries;
  }

  static bool _ok(String? status) =>
      status == null || RegExp(r'^\s*HTTP/\S+\s+200\b').hasMatch(status);

  /// Un `href` (assoluto o solo percorso, codificato o no, con o senza `/`
  /// finale) come segmenti relativi alla radice; `null` se sta fuori.
  List<String>? _relative(String href) {
    var path = href;
    final origin = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]*').firstMatch(path);
    if (origin != null) path = path.substring(origin.end);
    final segments = [
      for (final segment in path.split('/'))
        if (segment.isNotEmpty) _decode(segment),
    ];
    if (segments.length < _baseSegments.length) return null;
    for (var i = 0; i < _baseSegments.length; i++) {
      if (segments[i] != _baseSegments[i]) return null;
    }
    return segments.sublist(_baseSegments.length);
  }

  /// Un segmento codificato si decodifica; uno che non lo è (un `%` da solo
  /// in un titolo) resta com'è.
  static String _decode(String segment) {
    try {
      return Uri.decodeComponent(segment);
    } on ArgumentError {
      return segment;
    } on FormatException {
      return segment;
    }
  }

  /// Una richiesta con le sue regole: reindirizzamenti solo verso lo stesso
  /// host, nuovi tentativi su 429 e 5xx, ogni altro esito tradotto.
  Future<HttpClientResponse> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    var hops = 0;
    for (var attempt = 0;;) {
      final response = await _once(method, uri, headers, body);
      final status = response.statusCode;
      if (status == HttpStatus.ok || status == HttpStatus.partialContent || status == HttpStatus.multiStatus) {
        return response;
      }
      _drop(response);
      if (_redirects.contains(status)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || ++hops > _maxHops) {
          throw TransportException('Troppi reindirizzamenti dalla sorgente', status: status);
        }
        final next = uri.resolve(location);
        // Le credenziali vanno solo all'host configurato: un rimando
        // altrove si ferma qui, senza mandarle.
        if (!_sameOrigin(next)) {
          throw TransportException('La sorgente rimanda a un altro indirizzo (${next.host})', status: status);
        }
        uri = next;
        continue;
      }
      if (status == HttpStatus.unauthorized || status == HttpStatus.forbidden) {
        throw TransportAuthRequired(status: status);
      }
      if (status == HttpStatus.notFound) throw const TransportNotFound();
      if ((status == HttpStatus.tooManyRequests || status >= 500) && attempt < attempts - 1) {
        await Future<void>.delayed(retryDelay * (1 << attempt));
        attempt++;
        continue;
      }
      throw TransportException('La sorgente ha risposto $status', status: status);
    }
  }

  Future<HttpClientResponse> _once(
    String method,
    Uri uri,
    Map<String, String> headers,
    List<int>? body,
  ) async {
    HttpClientRequest? request;
    try {
      final opening = _http.openUrl(method, uri);
      request = await opening.timeout(answer, onTimeout: () {
        unawaited(opening.then(_abandon, onError: (Object _) {}));
        throw TimeoutException('Nessuna connessione', answer);
      });
      request.followRedirects = false;
      if (_auth != null && _sameOrigin(uri)) {
        request.headers.set(HttpHeaders.authorizationHeader, _auth);
      }
      headers.forEach(request.headers.set);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      } else {
        request.contentLength = 0;
      }
      return await request.close().timeout(answer);
    } on Object catch (error) {
      // Una richiesta lasciata a metà tiene la sua connessione per sempre.
      if (request != null) _abandon(request);
      if (error is SocketException ||
          error is TlsException ||
          error is HttpException ||
          error is TimeoutException) {
        throw const TransportOffline();
      }
      rethrow;
    }
  }

  static void _abandon(HttpClientRequest request) {
    request.done.ignore();
    request.abort();
  }

  /// Una risposta che non si legge: si chiude la connessione invece di
  /// leggerne il corpo, che può essere lungo o non arrivare mai.
  static void _drop(HttpClientResponse response) {
    unawaited(response.detachSocket().then((socket) => socket.destroy(), onError: (Object _) {}));
  }

  /// Il corpo a pezzi, con il silenzio a metà che diventa [TransportOffline].
  Future<void> _collect(HttpClientResponse response, FutureOr<void> Function(List<int> chunk) add) async {
    try {
      await for (final chunk in response.timeout(stall, onTimeout: (sink) {
        sink
          ..addError(const TransportOffline('La connessione si è fermata'))
          ..close();
      })) {
        await add(chunk);
      }
    } on TransportException {
      rethrow;
    } on FileSystemException {
      rethrow;
    } on Object {
      throw const TransportOffline('La connessione si è interrotta');
    }
  }
}
