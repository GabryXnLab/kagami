/// Il client dell'API v1 di Kagami Server (`docs/server-api.md`).
///
/// Sta nel pacchetto e non nell'app perché così il server lo prova contro la
/// sua API vera: è il contratto provato da tutt'e due i lati. Parla con
/// `dart:io` come il client di Drive.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'jobs.dart';

/// Indirizzo e chiave di un server: ciò che l'utente incolla nell'app.
class ServerLink {
  const ServerLink(this.url, this.key);

  factory ServerLink.fromJson(Map<String, Object?> json) =>
      ServerLink(Uri.parse(json['url'] as String), json['key'] as String);

  /// Il link di abbinamento `kagami://server?url=…&key=…` che stampa
  /// `kagami-server key create --url`; `null` se [text] non lo è.
  static ServerLink? parsePairing(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != 'kagami' || uri.host != 'server') return null;
    final url = uri.queryParameters['url'];
    final key = uri.queryParameters['key'];
    final address = url == null ? null : normalizeServerUrl(url);
    if (address == null || key == null || key.isEmpty) return null;
    return ServerLink(address, key);
  }

  final Uri url;
  final String key;

  Map<String, Object?> toJson() => {'url': '$url', 'key': key};

  @override
  bool operator ==(Object other) => other is ServerLink && other.url == url && other.key == key;

  @override
  int get hashCode => Object.hash(url, key);
}

/// L'indirizzo scritto dall'utente, ripulito: senza schema è `http://`
/// (in casa e dentro Tailscale lo si scrive così), senza la `/` finale.
/// `null` se non è un indirizzo.
Uri? normalizeServerUrl(String text) {
  var value = text.trim();
  if (value.isEmpty) return null;
  if (!value.contains('://')) value = 'http://$value';
  final uri = Uri.tryParse(value);
  if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) return null;
  final path = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null, path: path);
}

/// Se in chiaro la chiave resta fra le proprie mura: rete di casa,
/// Tailscale (100.64.0.0/10, nomi senza punto o in `.ts.net`), questo
/// computer. Un `http://` verso tutto il resto la manda leggibile su
/// internet, e l'app lo dice.
bool isPrivateAddress(Uri url) {
  final host = url.host.toLowerCase();
  final ip = InternetAddress.tryParse(host);
  if (ip != null) {
    if (ip.isLoopback || ip.isLinkLocal) return true;
    final bytes = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4) {
      final [a, b, _, _] = bytes;
      return a == 10 ||
          (a == 172 && b >= 16 && b < 32) ||
          (a == 192 && b == 168) ||
          (a == 100 && b >= 64 && b < 128);
    }
    // fc00::/7, gli indirizzi privati di IPv6 (anche quelli di Tailscale).
    return (bytes[0] & 0xfe) == 0xfc;
  }
  if (!host.contains('.')) return true;
  return const ['.local', '.lan', '.home', '.home.arpa', '.internal', '.ts.net']
      .any(host.endsWith);
}

class ServerException implements Exception {
  const ServerException(this.message, {this.code, this.status});

  final String message;

  /// Il `code` dell'errore dell'API, se il server ha risposto.
  final String? code;
  final int? status;

  @override
  String toString() => message;
}

/// Il server non si raggiunge: rete, indirizzo, server spento.
class ServerOffline extends ServerException {
  const ServerOffline([super.message = 'Il server non risponde.']);
}

/// Il server c'è, ma la chiave non vale.
class ServerUnauthorized extends ServerException {
  const ServerUnauthorized()
      : super('La chiave non è valida: creane una con «kagami-server key create».',
            code: 'unauthorized', status: 401);
}

class ServerInfo {
  const ServerInfo({
    required this.name,
    required this.version,
    required this.api,
    required this.providers,
    required this.driveAuthorized,
    this.folderId,
    this.folderName,
    this.images = false,
    this.checkMinutes,
  });

  factory ServerInfo.fromJson(Map<String, Object?> json) {
    final drive = json['drive'] as Map? ?? const {};
    final check = json['check'] as Map? ?? const {};
    return ServerInfo(
      name: json['name'] as String? ?? 'Kagami Server',
      version: json['version'] as String? ?? '',
      api: (json['api'] as num?)?.toInt() ?? 0,
      providers: [
        for (final row in (json['providers'] as List? ?? const []).whereType<Map>())
          if (row['id'] is String) row['id'] as String,
      ],
      driveAuthorized: drive['authorized'] == true,
      folderId: drive['folderId'] as String?,
      folderName: drive['folderName'] as String?,
      images: json['images'] == true,
      checkMinutes: (check['minutes'] as num?)?.toInt(),
    );
  }

  final String name;
  final String version;
  final int api;

  /// Gli id dei siti che il server sa scaricare.
  final List<String> providers;
  final bool driveAuthorized;
  final String? folderId;
  final String? folderName;
  final bool images;
  final int? checkMinutes;

  /// Se può ricevere lavori: ha il permesso di Drive e la cartella.
  bool get ready => driveAuthorized && folderId != null;

  ServerInfo withFolder(String? id, String? name) => ServerInfo(
        name: this.name,
        version: version,
        api: api,
        providers: providers,
        driveAuthorized: driveAuthorized,
        folderId: id,
        folderName: name,
        images: images,
        checkMinutes: checkMinutes,
      );
}

class RemoteJob {
  const RemoteJob({required this.id, required this.url, required this.title, this.automatic = false});

  factory RemoteJob.fromJson(Map<String, Object?> json) => RemoteJob(
        id: json['id'] as String,
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        automatic: json['automatic'] == true,
      );

  final String id;
  final String url;
  final String title;

  /// Messo in coda dal controllo delle serie in corso del server.
  final bool automatic;
}

/// La coda del server: gli stessi campi di quella del telefono.
class RemoteQueue {
  const RemoteQueue({this.status = const ArchiveStatus(), this.jobs = const [], this.history = const []});

  factory RemoteQueue.fromJson(Map<String, Object?> json) => RemoteQueue(
        status: ArchiveStatus.fromJson(json['status'] as Map<String, Object?>? ?? const {}),
        jobs: [
          for (final row in (json['queue'] as List? ?? const []).whereType<Map<String, Object?>>())
            RemoteJob.fromJson(row),
        ],
        history: [
          for (final row in (json['history'] as List? ?? const []).whereType<Map<String, Object?>>())
            ArchiveOutcome.fromJson(row),
        ],
      );

  final ArchiveStatus status;
  final List<RemoteJob> jobs;
  final List<ArchiveOutcome> history;

  /// Il lavoro in corso, se il giro ne ha uno.
  RemoteJob? get current => status.state == ArchiveState.running
      ? jobs.where((job) => job.id == status.jobId).firstOrNull
      : null;
}

class RemoteSeries {
  const RemoteSeries({required this.key, required this.title, required this.chapters, this.checkedAt, this.problem});

  factory RemoteSeries.fromJson(Map<String, Object?> json) => RemoteSeries(
        key: json['key'] as String,
        title: json['title'] as String? ?? '',
        chapters: (json['chapters'] as num?)?.toInt() ?? 0,
        checkedAt: DateTime.tryParse('${json['checkedAt']}'),
        problem: json['problem'] as String?,
      );

  final String key;
  final String title;
  final int chapters;
  final DateTime? checkedAt;
  final String? problem;
}

class ServerClient {
  ServerClient(this.link) : _http = HttpClient() {
    _http
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15);
  }

  final ServerLink link;
  final HttpClient _http;

  Future<ServerInfo> info() async {
    final json = await _call('GET', '/v1/server');
    final info = ServerInfo.fromJson(json!);
    if (json['service'] != 'kagami-server') {
      throw const ServerException('A questo indirizzo non risponde un Kagami Server.');
    }
    return info;
  }

  Future<RemoteQueue> queue() async => RemoteQueue.fromJson((await _call('GET', '/v1/jobs'))!);

  Future<RemoteJob> enqueue({
    required String url,
    String title = '',
    String? start,
    Set<String>? ids,
    int? delayMs,
    String? snapshot,
  }) async {
    final json = await _call('POST', '/v1/jobs', body: {
      'url': url,
      'title': title,
      'start': ?start,
      if (ids != null) 'ids': ids.toList(),
      'delayMs': ?delayMs,
      'snapshot': ?snapshot,
    });
    return RemoteJob.fromJson(json!['job'] as Map<String, Object?>);
  }

  Future<void> cancel(String id) => _call('DELETE', '/v1/jobs/${Uri.encodeComponent(id)}');

  Future<void> clearHistory() => _call('DELETE', '/v1/history');

  Future<List<RemoteSeries>> ongoing() async => [
        for (final row in ((await _call('GET', '/v1/ongoing'))!['series'] as List? ?? const [])
            .whereType<Map<String, Object?>>())
          RemoteSeries.fromJson(row),
      ];

  Future<void> forget(String key) => _call('DELETE', '/v1/ongoing/${Uri.encodeComponent(key)}');

  Future<void> check() => _call('POST', '/v1/check');

  /// Dice al server di scrivere in questa cartella di Drive; ne dà il nome.
  Future<({String? id, String? name})> chooseFolder(String folderId) async {
    final drive = (await _call('PUT', '/v1/drive/folder', body: {'folderId': folderId}))!['drive'] as Map;
    return (id: drive['folderId'] as String?, name: drive['folderName'] as String?);
  }

  void close() => _http.close(force: true);

  Future<Map<String, Object?>?> _call(String method, String path, {Map<String, Object?>? body}) async {
    final base = link.url;
    final uri = base.replace(path: '${base.path}$path');
    final HttpClientResponse response;
    final String text;
    try {
      final request = await _http.openUrl(method, uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${link.key}');
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      } else {
        request.contentLength = 0;
      }
      response = await request.close().timeout(const Duration(seconds: 30));
      text = await utf8.decodeStream(response).timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const ServerOffline();
    } on HandshakeException {
      throw const ServerOffline('Il certificato HTTPS del server non è valido.');
    } on HttpException {
      throw const ServerOffline('La connessione con il server si è interrotta.');
    } on TimeoutException {
      throw const ServerOffline('Il server non risponde.');
    }
    Object? json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      json = null;
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (text.isNotEmpty && json is! Map<String, Object?>) {
        throw const ServerException('A questo indirizzo non risponde un Kagami Server.');
      }
      return json as Map<String, Object?>?;
    }
    if (status == HttpStatus.unauthorized) throw const ServerUnauthorized();
    final error = json is Map ? json['error'] : null;
    if (error is Map && error['message'] is String) {
      throw ServerException(error['message'] as String, code: error['code'] as String?, status: status);
    }
    throw ServerException(
      status == HttpStatus.notFound
          ? 'A questo indirizzo non risponde un Kagami Server.'
          : 'Il server ha risposto $status.',
      status: status,
    );
  }
}
