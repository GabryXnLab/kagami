/// L'API v1, quella di `docs/server-api.md`: JSON su HTTP, chiave in
/// `Authorization: Bearer`.
///
/// Il server non fa TLS: ascolta in chiaro e l'HTTPS lo mette chi lo espone
/// (Tailscale, un reverse proxy), che lo sa fare meglio e rinnova i
/// certificati da sé. In casa o dentro Tailscale il chiaro non esce dalla
/// rete, o è già cifrato da WireGuard.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'keys.dart';
import 'worker.dart';

/// Il corpo più grande accettato: la pagina di una serie di ManhwaRead, che
/// il telefono manda quando il sito è dietro Cloudflare, sta abbondantemente
/// sotto.
const int maxBody = 16 * 1024 * 1024;

class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;
}

/// Lo stato di Drive del server, che l'API mostra e cambia.
abstract interface class DriveSetup {
  Future<bool> get authorized;
  String? get folderId;
  String? get folderName;

  /// Controlla che il server veda e possa usare la cartella, e la sceglie.
  Future<DriveItem> choose(String folderId);
}

class ServerApi {
  ServerApi({
    required this.name,
    required this.keys,
    required this.files,
    required this.jobs,
    required this.drive,
    required this.images,
    required this.checkMinutes,
    this.log = _stderr,
  });

  final String name;
  final ApiKeys keys;
  final ArchiveFiles files;
  final JobControl jobs;
  final DriveSetup drive;

  /// Se il server fa miniature e tessere (c'è `vips`).
  final bool images;
  final int? checkMinutes;
  final void Function(String line) log;

  static void _stderr(String line) => stderr.writeln(line);

  Future<void> handle(HttpRequest request) async {
    final started = DateTime.now();
    final response = request.response;
    response.headers
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Cache-Control', 'no-store');
    var status = HttpStatus.ok;
    try {
      final (code, body) = await _route(request);
      status = code;
      await _send(response, code, body);
    } on ApiError catch (error) {
      status = error.status;
      await _send(response, error.status, {
        'error': {'code': error.code, 'message': error.message},
      });
    } on Object catch (error, stack) {
      status = HttpStatus.internalServerError;
      log('Errore su ${request.method} ${request.uri.path}: $error\n$stack');
      await _send(response, status, {
        'error': {'code': 'internal', 'message': 'Errore del server.'},
      }).catchError((_) {});
    }
    // Solo metodo, percorso ed esito: la chiave non finisce mai nel registro.
    log('${request.method} ${request.uri.path} $status ${DateTime.now().difference(started).inMilliseconds} ms');
  }

  Future<void> _send(HttpResponse response, int status, Object? body) async {
    response.statusCode = status;
    if (body != null) {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
    }
    await response.close();
  }

  Future<(int, Object?)> _route(HttpRequest request) async {
    final segments = request.uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final method = request.method;
    // La sola risposta senza chiave: dice che qui c'è un Kagami Server, e
    // serve a Docker per sapere se è vivo. Nient'altro.
    if (segments.isEmpty && method == 'GET') {
      return (HttpStatus.ok, {'service': 'kagami-server', 'api': apiVersion});
    }
    if (segments.isEmpty || segments.first != 'v$apiVersion') {
      throw const ApiError(HttpStatus.notFound, 'not_found', 'Indirizzo sconosciuto.');
    }
    await _authenticate(request);
    final path = segments.skip(1).toList();
    return switch ((method, path)) {
      ('GET', ['server']) => (HttpStatus.ok, await _server()),
      ('GET', ['jobs']) => (HttpStatus.ok, await _jobs()),
      ('POST', ['jobs']) => (HttpStatus.created, await _enqueue(await _body(request))),
      ('DELETE', ['jobs', final id]) => await _cancel(id),
      ('DELETE', ['history']) => await _clearHistory(),
      ('GET', ['ongoing']) => (HttpStatus.ok, await _ongoing()),
      ('DELETE', ['ongoing', final key]) => await _forget(key),
      ('POST', ['check']) => _check(),
      ('PUT', ['drive', 'folder']) => (HttpStatus.ok, await _folder(await _body(request))),
      _ => throw const ApiError(HttpStatus.notFound, 'not_found', 'Indirizzo sconosciuto.'),
    };
  }

  Future<void> _authenticate(HttpRequest request) async {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    const scheme = 'Bearer ';
    final presented = header.startsWith(scheme) ? header.substring(scheme.length).trim() : '';
    if (presented.isEmpty || await keys.verify(presented) == null) {
      request.response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer realm="kagami-server"');
      throw const ApiError(HttpStatus.unauthorized, 'unauthorized', 'Chiave API mancante o non valida.');
    }
  }

  Future<Map<String, Object?>> _body(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > maxBody) {
        throw const ApiError(HttpStatus.requestEntityTooLarge, 'too_large', 'Richiesta troppo grande.');
      }
    }
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is Map<String, Object?>) return json;
    } on FormatException {
      // Sotto, con lo stesso messaggio.
    }
    throw const ApiError(HttpStatus.badRequest, 'bad_request', 'Il corpo deve essere un oggetto JSON.');
  }

  Future<Map<String, Object?>> _server() async => {
        'service': 'kagami-server',
        'version': serverVersion,
        'api': apiVersion,
        'name': name,
        'providers': [
          for (final provider in providers) {'id': provider.id, 'name': provider.name},
        ],
        'drive': await _drive(),
        'images': images,
        'check': {'minutes': checkMinutes},
      };

  Future<Map<String, Object?>> _drive() async => {
        'authorized': await drive.authorized,
        'folderId': drive.folderId,
        'folderName': drive.folderName,
      };

  static Map<String, Object?> _job(ArchiveJob job) => {
        'id': job.id,
        'url': job.url,
        'title': job.title,
        'start': ?job.start,
        if (job.ids != null) 'ids': job.ids!.toList(),
        'delayMs': job.delayMs,
        if (job.automatic) 'automatic': true,
      };

  Future<Map<String, Object?>> _jobs() async => {
        'status': (await files.status()).toJson(),
        'queue': [for (final job in await files.jobs()) _job(job)],
        'history': [for (final outcome in await files.history()) outcome.toJson()],
      };

  Future<Map<String, Object?>> _enqueue(Map<String, Object?> body) async {
    final url = body['url'];
    if (url is! String || url.isEmpty) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', 'Manca il link della serie.');
    }
    final Provider provider;
    try {
      provider = selectProvider(url);
    } on ProviderError catch (error) {
      throw ApiError(HttpStatus.badRequest, 'unsupported_url', '$error');
    }
    final start = switch (body['start']) {
      null => null,
      final String value when value.isNotEmpty => value,
      final num value => '$value',
      _ => throw const ApiError(HttpStatus.badRequest, 'bad_request', 'Capitolo iniziale non valido.'),
    };
    final ids = switch (body['ids']) {
      null => null,
      final List<Object?> list when list.every((id) => id is String) => list.cast<String>().toSet(),
      _ => throw const ApiError(HttpStatus.badRequest, 'bad_request', '«ids» deve essere un elenco di id.'),
    };
    if (start != null && ids != null) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', '«start» e «ids» non vanno insieme.');
    }
    final delay = body['delayMs'];
    if (delay != null && (delay is! int || delay < 0 || delay > 5000)) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', '«delayMs» va da 0 a 5000.');
    }
    final snapshot = body['snapshot'];
    if (snapshot != null && (snapshot is! String || !provider.needsBrowser)) {
      throw ApiError(HttpStatus.badRequest, 'bad_request',
          'La pagina della serie si manda solo per i siti con la verifica del browser, non per ${provider.name}.');
    }
    final folderId = drive.folderId;
    if (!await drive.authorized || folderId == null) {
      throw const ApiError(HttpStatus.conflict, 'drive_not_ready',
          'Il server non ha ancora Drive: serve «kagami-server drive login» e una cartella della libreria.');
    }
    final random = Random.secure();
    final id = 'srv-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(1 << 32).toRadixString(36)}';
    String? page;
    if (snapshot is String) {
      await files.snapshots.create(recursive: true);
      page = p.join(files.snapshots.path, '$id.html');
      await File(page).writeAsString(snapshot);
    }
    final job = ArchiveJob(
      id: id,
      url: url,
      title: body['title'] is String ? body['title'] as String : '',
      target: ArchiveTarget(destination: ArchiveDestination.drive, folderId: folderId),
      start: start,
      ids: ids,
      delayMs: delay as int? ?? 200,
      snapshot: page,
    );
    await files.enqueue(job);
    jobs.wake();
    return {'job': _job(job)};
  }

  Future<(int, Object?)> _cancel(String id) async {
    final known = (await files.jobs()).any((job) => job.id == id);
    if (!known) throw const ApiError(HttpStatus.notFound, 'not_found', 'Nessun lavoro in coda con questo id.');
    await jobs.cancel(id);
    return (HttpStatus.noContent, null);
  }

  Future<(int, Object?)> _clearHistory() async {
    await files.clearHistory();
    return (HttpStatus.noContent, null);
  }

  Future<Map<String, Object?>> _ongoing() async => {
        'series': [
          for (final entry in await Tracking(files.ongoing).load())
            {
              'key': entry.key,
              'title': entry.title,
              'url': entry.url,
              'chapters': entry.chapters.length,
              'addedAt': entry.addedAt.toIso8601String(),
              'checkedAt': ?entry.checkedAt?.toIso8601String(),
              'problem': ?entry.problem,
            },
        ],
      };

  Future<(int, Object?)> _forget(String key) async {
    final tracking = Tracking(files.ongoing);
    if (!(await tracking.load()).any((entry) => entry.key == key)) {
      throw const ApiError(HttpStatus.notFound, 'not_found', 'Il server non segue questa serie.');
    }
    await tracking.forget(key);
    return (HttpStatus.noContent, null);
  }

  (int, Object?) _check() {
    unawaited(jobs.checkNow());
    return (HttpStatus.accepted, null);
  }

  Future<Map<String, Object?>> _folder(Map<String, Object?> body) async {
    final id = body['folderId'];
    if (id is! String || id.isEmpty) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', 'Manca «folderId».');
    }
    if (!await drive.authorized) {
      throw const ApiError(HttpStatus.conflict, 'drive_not_ready',
          'Il server non ha ancora il permesso di Drive: serve «kagami-server drive login».');
    }
    try {
      await drive.choose(folderIdFrom(id));
    } on DriveOffline catch (error) {
      throw ApiError(HttpStatus.serviceUnavailable, 'drive_offline', '$error');
    } on DriveException catch (error) {
      throw ApiError(HttpStatus.badRequest, 'bad_folder', '$error');
    }
    return {'drive': await _drive()};
  }
}

/// L'id da un link di Drive (`…/folders/<id>…`) o l'id stesso.
String folderIdFrom(String value) =>
    RegExp(r'folders/([A-Za-z0-9_-]+)').firstMatch(value)?.group(1) ?? value.trim();
