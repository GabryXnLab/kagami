/// Il client dell'API v2 di Kagami Server (`docs/server-api.md`).
///
/// Sta nel pacchetto e non nell'app perché così il server lo prova contro la
/// sua API vera: è il contratto provato da tutt'e due i lati. Parla con
/// `dart:io` come il client di Drive.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'google_token.dart';
import 'jobs.dart';

export 'google_token.dart' show GoogleClient;

/// L'indirizzo di un server: ciò che l'app ricorda. Chi chiama lo dice il
/// token dell'account, non il collegamento.
class ServerLink {
  const ServerLink(this.url);

  /// Ignora la `key` dei collegamenti della v1, che il server v2 non vuole
  /// più: l'indirizzo resta buono.
  factory ServerLink.fromJson(Map<String, Object?> json) => ServerLink(Uri.parse(json['url'] as String));

  final Uri url;

  Map<String, Object?> toJson() => {'url': '$url'};

  @override
  bool operator ==(Object other) => other is ServerLink && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Tutto ciò che serve al server per partire, nel comando che l'app genera
/// per il proprietario (`KAGAMI_SETUP`, docs/server-api.md): il progetto
/// dell'app di cui accettare i token, il client con cui rinnovare i permessi
/// di Drive, e il proprietario col suo permesso e la sua cartella.
class ServerSetup {
  const ServerSetup({
    required this.project,
    required this.client,
    required this.owner,
    required this.refreshToken,
    required this.folderId,
    this.folderName,
    this.name,
  });

  /// `FormatException` se [blob] non è una configurazione.
  factory ServerSetup.decode(String blob) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(blob.trim()))));
    } on FormatException {
      throw const FormatException('KAGAMI_SETUP non è una configurazione di Kagami.');
    }
    if (json is! Map<String, Object?> || json['v'] != version) {
      throw const FormatException('KAGAMI_SETUP non è una configurazione che questo server conosce.');
    }
    final client = json['client'];
    final owner = json['owner'];
    if (json['project'] is! String ||
        client is! Map ||
        client['id'] is! String ||
        client['secret'] is! String ||
        owner is! Map ||
        owner['email'] is! String ||
        owner['refreshToken'] is! String ||
        owner['folderId'] is! String) {
      throw const FormatException('KAGAMI_SETUP è incompleta: generane una nuova dall\'app.');
    }
    return ServerSetup(
      project: json['project'] as String,
      client: GoogleClient(client['id'] as String, client['secret'] as String),
      owner: (owner['email'] as String).trim().toLowerCase(),
      refreshToken: owner['refreshToken'] as String,
      folderId: owner['folderId'] as String,
      folderName: owner['folderName'] as String?,
      name: json['name'] as String?,
    );
  }

  static const int version = 1;

  final String project;
  final GoogleClient client;
  final String owner;
  final String refreshToken;
  final String folderId;
  final String? folderName;
  final String? name;

  String encode() => base64Url
      .encode(utf8.encode(jsonEncode({
        'v': version,
        'name': ?name,
        'project': project,
        'client': {'id': client.id, 'secret': client.secret},
        'owner': {
          'email': owner,
          'refreshToken': refreshToken,
          'folderId': folderId,
          'folderName': ?folderName,
        },
      })))
      .replaceAll('=', '');
}

/// I comandi che accendono il server già configurato: Docker è l'unica cosa
/// da avere, e incollarli è l'unica cosa da fare. Una riga per comando,
/// perché `&&` non lo capisce ogni terminale (il PowerShell di Windows).
///
/// Il secondo accende l'aggiornatore (`kagami-server update`), che ricrea
/// il server quando la CI pubblica un'immagine nuova. Ha il socket di Docker
/// e gira come root, quindi è un contenitore a parte: il server, che parla
/// con internet, non deve poter comandare la macchina. Senza controllo di
/// salute, che chiede al server della porta 8080 e lì non c'è.
String serverCommand(ServerSetup setup, {required String image, int port = 8080}) =>
    'docker run -d --name kagami-server --restart unless-stopped '
    '-p $port:8080 -v kagami-data:/data '
    '-e KAGAMI_SETUP=${setup.encode()} '
    '$image\n'
    '${updaterCommand(image)}';

String updaterCommand(String image) =>
    'docker run -d --name kagami-updater --restart unless-stopped --no-healthcheck '
    '-u 0 -v /var/run/docker.sock:/var/run/docker.sock '
    '$image update';

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

/// Se in chiaro il token resta fra le proprie mura: rete di casa,
/// Tailscale (100.64.0.0/10, nomi senza punto o in `.ts.net`), questo
/// computer. Un `http://` verso tutto il resto lo manda leggibile su
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

/// Il server c'è, ma non ha riconosciuto l'account.
class ServerUnauthorized extends ServerException {
  const ServerUnauthorized([super.message = 'Il server non ha riconosciuto il tuo account: rifai l\'accesso.'])
      : super(code: 'unauthorized', status: 401);
}

/// L'account è riconosciuto ma non ammesso, o non è il proprietario.
class ServerForbidden extends ServerException {
  const ServerForbidden(super.message, {super.code}) : super(status: 403);
}

class ServerUser {
  const ServerUser({required this.email, this.owner = false, this.connected = false, this.addedAt});

  factory ServerUser.fromJson(Map<String, Object?> json) => ServerUser(
        email: json['email'] as String,
        owner: json['owner'] == true,
        connected: json['connected'] == true,
        addedAt: DateTime.tryParse('${json['addedAt']}'),
      );

  final String email;
  final bool owner;

  /// Il server ha il suo permesso di Drive: ha già collegato il server.
  final bool connected;
  final DateTime? addedAt;
}

class ServerInfo {
  const ServerInfo({
    required this.name,
    required this.version,
    required this.api,
    required this.providers,
    required this.email,
    required this.driveAuthorized,
    this.owner,
    this.isOwner = false,
    this.folderId,
    this.folderName,
    this.images = false,
    this.check = const RemoteCheck(),
    this.features = const {},
  });

  factory ServerInfo.fromJson(Map<String, Object?> json) {
    final me = json['me'] as Map? ?? const {};
    final drive = me['drive'] as Map? ?? const {};
    final check = json['check'] as Map? ?? const {};
    return ServerInfo(
      name: json['name'] as String? ?? 'Kagami Server',
      version: json['version'] as String? ?? '',
      api: (json['api'] as num?)?.toInt() ?? 0,
      owner: json['owner'] as String?,
      providers: [
        for (final row in (json['providers'] as List? ?? const []).whereType<Map>())
          if (row['id'] is String) row['id'] as String,
      ],
      email: me['email'] as String? ?? '',
      isOwner: me['owner'] == true,
      driveAuthorized: drive['authorized'] == true,
      folderId: drive['folderId'] as String?,
      folderName: drive['folderName'] as String?,
      images: json['images'] == true,
      check: RemoteCheck.fromJson(check.cast<String, Object?>()),
      features: {...(json['features'] as List? ?? const []).whereType<String>()},
    );
  }

  final String name;
  final String version;
  final int api;

  /// L'indirizzo del proprietario.
  final String? owner;

  /// Gli id dei siti che il server sa scaricare.
  final List<String> providers;

  /// Chi chiama, come lo vede il server.
  final String email;
  final bool isOwner;
  final bool driveAuthorized;
  final String? folderId;
  final String? folderName;
  final bool images;

  /// Il controllo quotidiano di chi chiama.
  final RemoteCheck check;

  /// Ciò che il server sa fare oltre alla v2 di partenza: un server di prima
  /// non lo dice, e l'app non gli chiede quelle cose.
  final Set<String> features;

  /// Scarica «man mano» (`ahead` nei lavori, `PUT /ongoing/{key}`).
  bool get ahead => features.contains('ahead');

  /// Il controllo salta le serie escluse dall'app (`unfollowed`).
  bool get unfollowed => features.contains('unfollowed');

  /// Il controllo legge anche i siti dietro la verifica del browser.
  bool get browser => features.contains('browser');

  /// Dice quali serie sono ferme alla verifica del sito
  /// ([RemoteCheck.gated]) e ne accetta le pagine aperte sul telefono
  /// ([ServerClient.checkPages]).
  bool get verify => features.contains('verify');

  /// L'ora del controllo, `null` se è spento.
  int? get checkMinutes => check.enabled ? check.minutes : null;

  /// Se può ricevere lavori: ha il permesso di Drive di chi chiama e la sua
  /// cartella.
  bool get ready => driveAuthorized && folderId != null;

  ServerInfo withDrive({required bool authorized, String? id, String? name}) => ServerInfo(
        name: this.name,
        version: version,
        api: api,
        owner: owner,
        providers: providers,
        email: email,
        isOwner: isOwner,
        driveAuthorized: authorized,
        folderId: id,
        folderName: name,
        images: images,
        check: check,
        features: features,
      );

  ServerInfo withCheck(RemoteCheck check) => ServerInfo(
        name: name,
        version: version,
        api: api,
        owner: owner,
        providers: providers,
        email: email,
        isOwner: isOwner,
        driveAuthorized: driveAuthorized,
        folderId: folderId,
        folderName: folderName,
        images: images,
        check: check,
        features: features,
      );
}

/// Il controllo quotidiano sul server: se c'è, a che ora, se guarda tutta la
/// libreria su Drive, e com'è andato l'ultimo.
class RemoteCheck {
  const RemoteCheck({
    this.enabled = false,
    this.minutes = 4 * 60,
    this.library = false,
    this.unfollowed = const {},
    this.checkedAt,
    this.checked = 0,
    this.queued = 0,
    this.failed = 0,
    this.gated = const [],
  });

  /// Un server di prima dà solo `minutes`, `null` se è spento, e guarda solo
  /// le serie che ha scaricato lui.
  factory RemoteCheck.fromJson(Map<String, Object?> json) {
    final minutes = (json['minutes'] as num?)?.toInt();
    return RemoteCheck(
      enabled: json['enabled'] as bool? ?? minutes != null,
      minutes: (json['time'] as num?)?.toInt() ?? minutes ?? 4 * 60,
      library: json['library'] == true,
      unfollowed: {...?(json['unfollowed'] as List?)?.whereType<String>()},
      checkedAt: DateTime.tryParse('${json['checkedAt']}'),
      checked: (json['checked'] as num?)?.toInt() ?? 0,
      queued: (json['queued'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      gated: [
        for (final row in (json['gated'] as List? ?? const []).whereType<Map<String, Object?>>())
          if (row['key'] is String && row['url'] is String) GatedSeries.fromJson(row),
      ],
    );
  }

  final bool enabled;
  final int minutes;
  final bool library;

  /// Le serie che il controllo salta.
  final Set<String> unfollowed;
  final DateTime? checkedAt;
  final int checked;
  final int queued;
  final int failed;

  /// Le serie che il controllo ha trovato ferme alla verifica del sito.
  final List<GatedSeries> gated;
}

class RemoteJob {
  const RemoteJob({
    required this.id,
    required this.url,
    required this.title,
    this.automatic = false,
    this.start,
    this.ids,
    this.ahead,
  });

  factory RemoteJob.fromJson(Map<String, Object?> json) => RemoteJob(
        id: json['id'] as String,
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        automatic: json['automatic'] == true,
        start: json['start'] == null ? null : '${json['start']}',
        ids: (json['ids'] as List?)?.whereType<String>().toSet(),
        ahead: (json['ahead'] as num?)?.toInt(),
      );

  final String id;
  final String url;
  final String title;

  /// Messo in coda dal controllo delle serie in corso del server, o dall'app
  /// per una serie man mano.
  final bool automatic;
  final String? start;

  /// Solo questi capitoli; `null` con [start] o per la serie intera.
  final Set<String>? ids;

  /// Scaricando man mano: quanti capitoli tenere pronti.
  final int? ahead;
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
  const RemoteSeries({
    required this.key,
    required this.title,
    required this.chapters,
    this.url = '',
    this.checkedAt,
    this.problem,
    this.ahead,
    this.wanted = 0,
  });

  factory RemoteSeries.fromJson(Map<String, Object?> json) => RemoteSeries(
        key: json['key'] as String,
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        chapters: (json['chapters'] as num?)?.toInt() ?? 0,
        checkedAt: DateTime.tryParse('${json['checkedAt']}'),
        problem: json['problem'] as String?,
        ahead: (json['ahead'] as num?)?.toInt(),
        wanted: (json['wanted'] as num?)?.toInt() ?? 0,
      );

  final String key;
  final String title;
  final String url;
  final int chapters;
  final DateTime? checkedAt;
  final String? problem;

  /// Scaricata man mano: quanti capitoli tenere pronti.
  final int? ahead;

  /// Quanti capitoli nuovi del sito l'app ha chiesto.
  final int wanted;
}

/// La versione dell'API che questo client parla.
const int serverApi = 2;

class ServerClient {
  /// [token] dà il token d'identità dell'account; con `refresh` uno nuovo,
  /// quando il server ha rifiutato quello di prima.
  ServerClient(this.link, this.token) : _http = HttpClient() {
    _http
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15);
  }

  final ServerLink link;
  final Future<String> Function({bool refresh}) token;
  final HttpClient _http;

  Future<ServerInfo> info() async {
    final Map<String, Object?>? json;
    try {
      json = await _call('GET', '/v$serverApi/server');
    } on ServerException catch (error) {
      if (error.status == HttpStatus.notFound) await _older();
      rethrow;
    }
    final info = ServerInfo.fromJson(json!);
    if (json['service'] != 'kagami-server') {
      throw const ServerException('A questo indirizzo non risponde un Kagami Server.');
    }
    return info;
  }

  /// Un server che non conosce `/v2` ma risponde a `/` parla un'API vecchia:
  /// l'indirizzo è giusto, va aggiornato lui.
  Future<void> _older() async {
    final Map<String, Object?>? about;
    try {
      about = await _call('GET', '/', authorized: false);
    } on ServerException {
      return;
    }
    if (about?['service'] == 'kagami-server') {
      throw ServerException('Il server parla l\'API ${about!['api']}, questa versione dell\'app la $serverApi: '
          'aggiornalo rifacendo il comando di avvio.');
    }
  }

  Future<RemoteQueue> queue() async => RemoteQueue.fromJson((await _call('GET', '/v$serverApi/jobs'))!);

  Future<RemoteJob> enqueue({
    required String url,
    String title = '',
    String? start,
    Set<String>? ids,
    int? delayMs,
    String? snapshot,
    int? ahead,
    bool automatic = false,
  }) async {
    final json = await _call('POST', '/v$serverApi/jobs', body: {
      'url': url,
      'title': title,
      'start': ?start,
      if (ids != null) 'ids': ids.toList(),
      'delayMs': ?delayMs,
      'snapshot': ?snapshot,
      'ahead': ?ahead,
      if (automatic) 'automatic': true,
    });
    return RemoteJob.fromJson(json!['job'] as Map<String, Object?>);
  }

  Future<void> cancel(String id) => _call('DELETE', '/v$serverApi/jobs/${Uri.encodeComponent(id)}');

  Future<void> clearHistory() => _call('DELETE', '/v$serverApi/history');

  Future<List<RemoteSeries>> ongoing() async => [
        for (final row in ((await _call('GET', '/v$serverApi/ongoing'))!['series'] as List? ?? const [])
            .whereType<Map<String, Object?>>())
          RemoteSeries.fromJson(row),
      ];

  Future<void> forget(String key) => _call('DELETE', '/v$serverApi/ongoing/${Uri.encodeComponent(key)}');

  /// Chiede [count] capitoli nuovi del sito per una serie man mano.
  Future<void> want(String key, int count) =>
      _call('PUT', '/v$serverApi/ongoing/${Uri.encodeComponent(key)}', body: {'wanted': count});

  Future<void> check() => _call('POST', '/v$serverApi/check');

  Future<RemoteCheck> configureCheck({bool? enabled, int? minutes, bool? library, Set<String>? unfollowed}) async =>
      RemoteCheck.fromJson((await _call('PUT', '/v$serverApi/check', body: {
        'enabled': ?enabled,
        'minutes': ?minutes,
        'library': ?library,
        if (unfollowed != null) 'unfollowed': [...unfollowed],
      }))!);

  /// Manda le pagine delle serie ferme alla verifica, aperte sul telefono
  /// ([pages], per link): il server le controlla subito.
  Future<({int checked, int queued, List<GatedSeries> gated})> checkPages(Map<String, String> pages) async {
    final json = (await _call('POST', '/v$serverApi/check/pages', body: {
      'pages': [for (final MapEntry(:key, :value) in pages.entries) {'url': key, 'html': value}],
    }))!;
    return (
      checked: (json['checked'] as num?)?.toInt() ?? 0,
      queued: (json['queued'] as num?)?.toInt() ?? 0,
      gated: RemoteCheck.fromJson({'gated': json['gated']}).gated,
    );
  }

  /// Dà al server il permesso sul proprio Drive e la cartella dove scrivere.
  Future<({String? id, String? name})> grantDrive(String refreshToken, String folderId) async =>
      _drive((await _call('PUT', '/v$serverApi/me/drive', body: {'refreshToken': refreshToken, 'folderId': folderId}))!);

  /// Il server dimentica il permesso e la coda di chi chiama.
  Future<void> forgetDrive() => _call('DELETE', '/v$serverApi/me/drive');

  /// Dice al server di scrivere in questa cartella di Drive; ne dà il nome.
  Future<({String? id, String? name})> chooseFolder(String folderId) async =>
      _drive((await _call('PUT', '/v$serverApi/me/folder', body: {'folderId': folderId}))!);

  static ({String? id, String? name}) _drive(Map<String, Object?> json) {
    final drive = json['drive'] as Map;
    return (id: drive['folderId'] as String?, name: drive['folderName'] as String?);
  }

  Future<List<ServerUser>> users() async => [
        for (final row in ((await _call('GET', '/v$serverApi/users'))!['users'] as List? ?? const [])
            .whereType<Map<String, Object?>>())
          ServerUser.fromJson(row),
      ];

  Future<ServerUser> addUser(String email) async =>
      ServerUser.fromJson((await _call('POST', '/v$serverApi/users', body: {'email': email}))!['user']
          as Map<String, Object?>);

  Future<void> removeUser(String email) => _call('DELETE', '/v$serverApi/users/${Uri.encodeComponent(email)}');

  void close() => _http.close(force: true);

  Future<Map<String, Object?>?> _call(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authorized = true,
  }) async {
    var (status, text) = await _send(method, path, body, authorized ? await token() : null);
    // Un token scaduto fra due richieste: se ne chiede uno nuovo, una volta.
    if (status == HttpStatus.unauthorized && authorized) {
      (status, text) = await _send(method, path, body, await token(refresh: true));
    }
    Object? json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      json = null;
    }
    if (status >= 200 && status < 300) {
      if (text.isNotEmpty && json is! Map<String, Object?>) {
        throw const ServerException('A questo indirizzo non risponde un Kagami Server.');
      }
      return json as Map<String, Object?>?;
    }
    final error = json is Map ? json['error'] : null;
    final message = error is Map && error['message'] is String ? error['message'] as String : null;
    final code = error is Map ? error['code'] as String? : null;
    if (status == HttpStatus.unauthorized) {
      throw message == null ? const ServerUnauthorized() : ServerUnauthorized(message);
    }
    if (status == HttpStatus.forbidden && message != null) throw ServerForbidden(message, code: code);
    if (message != null) throw ServerException(message, code: code, status: status);
    throw ServerException(
      status == HttpStatus.notFound
          ? 'A questo indirizzo non risponde un Kagami Server.'
          : 'Il server ha risposto $status.',
      status: status,
    );
  }

  Future<(int, String)> _send(String method, String path, Map<String, Object?>? body, String? bearer) async {
    final base = link.url;
    final uri = base.replace(path: '${base.path}$path');
    try {
      final request = await _http.openUrl(method, uri);
      if (bearer != null) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      } else {
        request.contentLength = 0;
      }
      final response = await request.close().timeout(const Duration(seconds: 30));
      final text = await utf8.decodeStream(response).timeout(const Duration(seconds: 30));
      return (response.statusCode, text);
    } on SocketException {
      throw const ServerOffline();
    } on HandshakeException {
      throw const ServerOffline('Il certificato HTTPS del server non è valido.');
    } on HttpException {
      throw const ServerOffline('La connessione con il server si è interrotta.');
    } on TimeoutException {
      throw const ServerOffline('Il server non risponde.');
    }
  }
}
