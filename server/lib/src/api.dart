/// L'API v2, quella di `docs/server-api.md`: JSON su HTTP, token d'identità
/// dell'account Google in `Authorization: Bearer`.
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
import 'google.dart';
import 'identity.dart';
import 'users.dart';
import 'worker.dart' show ServerCheck;

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

/// Quante serie escluse dal controllo accetta `PUT /v2/check`.
const int maxUnfollowed = 5000;

/// Quante pagine accetta `POST /v2/check/pages` in una volta.
const int maxPages = 50;

class ServerApi {
  ServerApi({
    required this.name,
    required this.identity,
    required this.accounts,
    required this.images,
    this.browser = false,
    this.log = _stderr,
  });

  final String name;

  /// `null` finché il server non ha una configurazione: ogni richiesta
  /// risponde `not_configured`.
  final IdentityVerifier? identity;
  final Accounts? accounts;

  /// Se il server fa miniature e tessere (c'è `vips`).
  final bool images;

  /// Se il server ha un Chromium per i siti dietro la verifica del browser.
  final bool browser;
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
    // Solo metodo, percorso ed esito: il token non finisce mai nel registro.
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
    // La sola risposta senza token: dice che qui c'è un Kagami Server, e
    // serve a Docker per sapere se è vivo. Nient'altro.
    if (segments.isEmpty && method == 'GET') {
      return (HttpStatus.ok, {'service': 'kagami-server', 'api': apiVersion});
    }
    if (segments.isEmpty || segments.first != 'v$apiVersion') {
      throw const ApiError(HttpStatus.notFound, 'not_found', 'Indirizzo sconosciuto.');
    }
    final identity = this.identity;
    final accounts = this.accounts;
    if (identity == null || accounts == null) {
      throw const ApiError(HttpStatus.serviceUnavailable, 'not_configured',
          'Il server è partito senza configurazione: avvialo col comando generato dall\'app.');
    }
    final email = await _authenticate(request, identity, accounts);
    final me = await accounts.space(email);
    final path = segments.skip(1).toList();
    return switch ((method, path)) {
      ('GET', ['server']) => (HttpStatus.ok, await _server(accounts, email, me)),
      ('PUT', ['me', 'drive']) => (HttpStatus.ok, await _grant(me, await _body(request))),
      ('DELETE', ['me', 'drive']) => await _forgetDrive(me),
      ('PUT', ['me', 'folder']) => (HttpStatus.ok, await _folder(me, await _body(request))),
      ('GET', ['jobs']) => (HttpStatus.ok, await _jobs(me)),
      ('POST', ['jobs']) => (HttpStatus.created, await _enqueue(me, await _body(request))),
      ('DELETE', ['jobs', final id]) => await _cancel(me, id),
      ('DELETE', ['history']) => await _clearHistory(me),
      ('GET', ['ongoing']) => (HttpStatus.ok, await _ongoing(me)),
      ('DELETE', ['ongoing', final key]) => await _forget(me, key),
      ('PUT', ['ongoing', final key]) => (HttpStatus.ok, await _want(me, key, await _body(request))),
      ('POST', ['check']) => _check(me),
      ('PUT', ['check']) => (HttpStatus.ok, await _configureCheck(me, await _body(request))),
      ('POST', ['check', 'pages']) => (HttpStatus.ok, await _checkPages(me, await _body(request))),
      ('GET', ['users']) => (HttpStatus.ok, await _users(_owner(accounts, email))),
      ('POST', ['users']) => (HttpStatus.created, await _addUser(_owner(accounts, email), await _body(request))),
      ('DELETE', ['users', final who]) => await _removeUser(_owner(accounts, email), who),
      _ => throw const ApiError(HttpStatus.notFound, 'not_found', 'Indirizzo sconosciuto.'),
    };
  }

  /// L'indirizzo di chi chiama, se il token vale e l'account è ammesso.
  Future<String> _authenticate(HttpRequest request, IdentityVerifier identity, Accounts accounts) async {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    const scheme = 'Bearer ';
    final presented = header.startsWith(scheme) ? header.substring(scheme.length).trim() : '';
    final Identity who;
    try {
      if (presented.isEmpty) throw const IdentityError('Manca il token dell\'account: fai l\'accesso nell\'app.');
      who = await identity.verify(presented);
    } on IdentityError catch (error) {
      request.response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer realm="kagami-server"');
      throw ApiError(HttpStatus.unauthorized, 'unauthorized', error.message);
    }
    if (await accounts.find(who.email) == null) {
      throw ApiError(HttpStatus.forbidden, 'not_allowed',
          '${who.email} non è fra gli account ammessi: chiedi al proprietario del server di aggiungerlo.');
    }
    return who.email;
  }

  static Accounts _owner(Accounts accounts, String email) => email == accounts.owner
      ? accounts
      : throw const ApiError(HttpStatus.forbidden, 'owner_only', 'Solo il proprietario del server può farlo.');

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

  Future<Map<String, Object?>> _server(Accounts accounts, String email, UserSpace me) async => {
        'service': 'kagami-server',
        'version': serverVersion,
        'api': apiVersion,
        'name': name,
        'owner': accounts.owner,
        'providers': [
          for (final provider in providers) {'id': provider.id, 'name': provider.name},
        ],
        'images': images,
        // Ciò che questo server sa fare oltre alla v2 di partenza: l'app
        // offre una funzione solo a un server che la elenca.
        'features': ['ahead', 'unfollowed', 'verify', if (browser) 'browser'],
        'check': {
          ..._checkJson(await me.jobs.checkSettings()),
          'gated': [for (final entry in await me.jobs.gated()) entry.toJson()],
        },
        'me': {'email': email, 'owner': email == accounts.owner, 'drive': await _drive(me.drive)},
      };

  static Future<Map<String, Object?>> _drive(DriveSetup drive) async => {
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
        'ahead': ?job.ahead,
      };

  Future<Map<String, Object?>> _jobs(UserSpace me) async => {
        'status': (await me.files.status()).toJson(),
        'queue': [for (final job in await me.files.jobs()) _job(job)],
        'history': [for (final outcome in await me.files.history()) outcome.toJson()],
      };

  Future<Map<String, Object?>> _enqueue(UserSpace me, Map<String, Object?> body) async {
    final files = me.files;
    final drive = me.drive;
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
    final ahead = body['ahead'];
    if (ahead != null && (ahead is! int || ahead < 1 || ahead > 50)) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', '«ahead» va da 1 a 50.');
    }
    if (ahead != null && provider.needsBrowser) {
      throw ApiError(HttpStatus.badRequest, 'bad_request',
          'Man mano non si può con ${provider.name}: ogni lettura vuole la verifica del browser.');
    }
    final automatic = body['automatic'];
    if (automatic != null && automatic is! bool) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', '«automatic» è vero o falso.');
    }
    final snapshot = body['snapshot'];
    if (snapshot != null && (snapshot is! String || !provider.needsBrowser)) {
      throw ApiError(HttpStatus.badRequest, 'bad_request',
          'La pagina della serie si manda solo per i siti con la verifica del browser, non per ${provider.name}.');
    }
    final folderId = drive.folderId;
    if (!await drive.authorized || folderId == null) {
      throw const ApiError(HttpStatus.conflict, 'drive_not_ready',
          'Il server non ha ancora il tuo Drive: collegalo dall\'app e scegli la cartella della libreria.');
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
      automatic: automatic == true,
      ahead: ahead as int?,
    );
    await files.enqueue(job);
    me.jobs.wake();
    return {'job': _job(job)};
  }

  Future<(int, Object?)> _cancel(UserSpace me, String id) async {
    final known = (await me.files.jobs()).any((job) => job.id == id);
    if (!known) throw const ApiError(HttpStatus.notFound, 'not_found', 'Nessun lavoro in coda con questo id.');
    await me.jobs.cancel(id);
    return (HttpStatus.noContent, null);
  }

  Future<(int, Object?)> _clearHistory(UserSpace me) async {
    await me.files.clearHistory();
    return (HttpStatus.noContent, null);
  }

  Future<Map<String, Object?>> _ongoing(UserSpace me) async => {
        'series': [
          for (final entry in await Tracking(me.files.ongoing).load())
            {
              'key': entry.key,
              'title': entry.title,
              'url': entry.url,
              'chapters': entry.chapters.length,
              'addedAt': entry.addedAt.toIso8601String(),
              'checkedAt': ?entry.checkedAt?.toIso8601String(),
              'problem': ?entry.problem,
              'ahead': ?entry.ahead,
              if (entry.ahead != null) 'wanted': entry.wanted,
            },
        ],
      };

  /// L'app, che sa cosa si legge, chiede per una serie man mano quanti
  /// capitoli nuovi servono. Se il sito non è stato guardato da un po', lo
  /// si guarda subito per quella serie sola.
  Future<Map<String, Object?>> _want(UserSpace me, String key, Map<String, Object?> body) async {
    final wanted = body['wanted'];
    if (wanted is! int || wanted < 0 || wanted > 50) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', '«wanted» va da 0 a 50.');
    }
    final tracking = Tracking(me.files.ongoing);
    final entry = (await tracking.load()).where((entry) => entry.key == key).firstOrNull;
    if (entry == null) throw const ApiError(HttpStatus.notFound, 'not_found', 'Il server non segue questa serie.');
    if (entry.ahead == null) {
      throw const ApiError(HttpStatus.conflict, 'not_ahead', 'La serie non si scarica man mano.');
    }
    await tracking.want(key, wanted);
    final checked = entry.checkedAt;
    final checking = wanted > 0 && (checked == null || DateTime.now().difference(checked) > recheck);
    if (checking) unawaited(me.jobs.checkSeries(key));
    return {'key': key, 'wanted': wanted, 'checking': checking};
  }

  /// Quanto aspettare prima di riguardare il sito per una serie man mano
  /// arrivata in fondo: ogni uscita dal lettore la chiede di nuovo.
  static const Duration recheck = Duration(hours: 6);

  Future<(int, Object?)> _forget(UserSpace me, String key) async {
    final tracking = Tracking(me.files.ongoing);
    if (!(await tracking.load()).any((entry) => entry.key == key)) {
      throw const ApiError(HttpStatus.notFound, 'not_found', 'Il server non segue questa serie.');
    }
    await tracking.forget(key);
    return (HttpStatus.noContent, null);
  }

  /// `minutes` è `null` col controllo spento, come per i client di prima.
  static Map<String, Object?> _checkJson(ServerCheck settings) => {
        'minutes': settings.enabled ? settings.minutes : null,
        'time': settings.minutes,
        'enabled': settings.enabled,
        'library': settings.library,
        'unfollowed': [...settings.unfollowed],
        'checkedAt': ?settings.checkedAt?.toIso8601String(),
        'checked': settings.checked,
        'queued': settings.queued,
        'failed': settings.failed,
      };

  Future<Map<String, Object?>> _configureCheck(UserSpace me, Map<String, Object?> body) async {
    final enabled = body['enabled'];
    final minutes = body['minutes'];
    final library = body['library'];
    final unfollowed = body['unfollowed'];
    if ((enabled != null && enabled is! bool) || (library != null && library is! bool)) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', '«enabled» e «library» sono sì o no.');
    }
    if (minutes != null && (minutes is! int || minutes < 0 || minutes >= 24 * 60)) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', '«minutes» va da 0 a 1439.');
    }
    if (unfollowed != null &&
        (unfollowed is! List || unfollowed.length > maxUnfollowed || unfollowed.any((key) => key is! String))) {
      throw const ApiError(
          HttpStatus.badRequest, 'bad_request', '«unfollowed» è un elenco di chiavi di serie, al più $maxUnfollowed.');
    }
    return _checkJson(await me.jobs.configureCheck(
      enabled: enabled as bool?,
      minutes: minutes as int?,
      library: library as bool?,
      unfollowed: unfollowed == null ? null : {for (final key in unfollowed as List) key as String},
    ));
  }

  /// Le pagine delle serie ferme alla verifica, aperte sul telefono da chi
  /// l'ha passata: il controllo di quelle serie si fa adesso, e la risposta
  /// dice com'è andato.
  Future<Map<String, Object?>> _checkPages(UserSpace me, Map<String, Object?> body) async {
    final pages = body['pages'];
    if (pages is! List ||
        pages.isEmpty ||
        pages.length > maxPages ||
        pages.any((page) => page is! Map || page['url'] is! String || page['html'] is! String)) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request',
          '«pages» è un elenco di pagine, da 1 a $maxPages, ognuna con «url» e «html».');
    }
    final report = await me.jobs.checkPages({
      for (final page in pages.cast<Map>()) page['url'] as String: page['html'] as String,
    });
    return {
      'checked': report.checked,
      'queued': report.queued.length,
      'failed': report.failed.length,
      'gated': [for (final entry in report.gated) entry.toJson()],
    };
  }

  (int, Object?) _check(UserSpace me) {
    unawaited(me.jobs.checkNow());
    return (HttpStatus.accepted, null);
  }

  Future<Map<String, Object?>> _grant(UserSpace me, Map<String, Object?> body) async {
    final refresh = body['refreshToken'];
    final folder = body['folderId'];
    if (refresh is! String || refresh.isEmpty || folder is! String || folder.isEmpty) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', 'Servono «refreshToken» e «folderId».');
    }
    await _onDrive(() => me.drive.grant(refresh, folderIdFrom(folder)));
    me.jobs.wake();
    return {'drive': await _drive(me.drive)};
  }

  Future<(int, Object?)> _forgetDrive(UserSpace me) async {
    for (final job in await me.files.jobs()) {
      await me.jobs.cancel(job.id);
    }
    await me.drive.forget();
    return (HttpStatus.noContent, null);
  }

  Future<Map<String, Object?>> _folder(UserSpace me, Map<String, Object?> body) async {
    final id = body['folderId'];
    if (id is! String || id.isEmpty) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', 'Manca «folderId».');
    }
    if (!await me.drive.authorized) {
      throw const ApiError(HttpStatus.conflict, 'drive_not_ready',
          'Il server non ha ancora il permesso del tuo Drive: collegalo dall\'app.');
    }
    await _onDrive(() => me.drive.choose(folderIdFrom(id)));
    me.jobs.wake();
    return {'drive': await _drive(me.drive)};
  }

  /// Un gesto su Drive, con gli errori di Google tradotti in quelli dell'API.
  static Future<void> _onDrive(Future<void> Function() action) async {
    try {
      await action();
    } on DriveOffline catch (error) {
      throw ApiError(HttpStatus.serviceUnavailable, 'drive_offline', '$error');
    } on DriveAuthRequired catch (error) {
      throw ApiError(HttpStatus.badRequest, 'bad_grant', '$error');
    } on DriveException catch (error) {
      throw ApiError(HttpStatus.badRequest, 'bad_folder', '$error');
    }
  }

  static Map<String, Object?> _member(Member member, bool connected) => {
        'email': member.email,
        'owner': member.owner,
        'addedAt': member.addedAt.toIso8601String(),
        'connected': connected,
      };

  Future<Map<String, Object?>> _users(Accounts accounts) async => {
        'users': [
          for (final member in await accounts.list())
            _member(member, await (await accounts.space(member.email)).drive.authorized),
        ],
      };

  Future<Map<String, Object?>> _addUser(Accounts accounts, Map<String, Object?> body) async {
    final email = body['email'] is String ? normalizeEmail(body['email'] as String) : null;
    if (email == null) throw const ApiError(HttpStatus.badRequest, 'bad_request', 'Scrivi un indirizzo email valido.');
    final member = await accounts.add(email);
    return {'user': _member(member, await (await accounts.space(email)).drive.authorized)};
  }

  Future<(int, Object?)> _removeUser(Accounts accounts, String who) async {
    final email = normalizeEmail(who);
    if (email == accounts.owner) {
      throw const ApiError(HttpStatus.badRequest, 'bad_request', 'Il proprietario non si può togliere.');
    }
    if (email == null || !await accounts.remove(email)) {
      throw const ApiError(HttpStatus.notFound, 'not_found', 'Questo account non è fra quelli ammessi.');
    }
    return (HttpStatus.noContent, null);
  }
}

/// L'id da un link di Drive (`…/folders/<id>…`) o l'id stesso.
String folderIdFrom(String value) =>
    RegExp(r'folders/([A-Za-z0-9_-]+)').firstMatch(value)?.group(1) ?? value.trim();
