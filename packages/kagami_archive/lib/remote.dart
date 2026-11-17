/// Il client dell'API v2 di Kagami Server (`docs/server-api.md`).
///
/// Sta nel pacchetto e non nell'app perché così il server lo prova contro la
/// sua API vera: è il contratto provato da tutt'e due i lati. Parla con
/// `dart:io` come il client di Drive.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'elsewhere.dart';
import 'google_token.dart';
import 'health.dart';
import 'jobs.dart';

export 'google_token.dart' show GoogleClient;

/// L'indirizzo di un server: ciò che l'app ricorda. Chi chiama lo dice il
/// biglietto o il token dell'account, non il collegamento.
class ServerLink {
  const ServerLink(this.url, {this.id, this.owner, this.legacy = false});

  /// Ignora la `key` dei collegamenti della v1, che il server v2 non vuole
  /// più: l'indirizzo resta buono.
  factory ServerLink.fromJson(Map<String, Object?> json) => ServerLink(
        Uri.parse(json['url'] as String),
        id: serverIdOf(json['id']),
        owner: json['owner'] is String ? (json['owner'] as String).toLowerCase() : null,
        legacy: json['id'] == null && json['owner'] == null,
      );

  final Uri url;

  /// L'id che il server ha dichiarato quando lo si è collegato (`GET /`): un
  /// server che a questo indirizzo ne dichiara un altro non riceve niente.
  /// `null` nei collegamenti di prima dei biglietti.
  final String? id;

  /// L'account che ha creato il server da questa app («Crea il tuo server»).
  /// Solo a lui, e solo così, va il token della sessione quando il server o
  /// il backend non hanno i biglietti: ciò che il server dichiara non basta.
  final String? owner;

  /// Letto da un collegamento salvato prima dei biglietti: né `id` né `owner`.
  /// Non è nella persistenza né nell'uguaglianza: lo è solo ciò che esce da
  /// [ServerLink.fromJson]. Un collegamento scritto da questa versione ha
  /// sempre l'uno o l'altro (`owner` vuoto vuol dire «non è mio»).
  final bool legacy;

  Map<String, Object?> toJson() => {'url': '$url', 'id': ?id, 'owner': ?owner};

  @override
  bool operator ==(Object other) => other is ServerLink && other.url == url && other.id == id && other.owner == owner;

  @override
  int get hashCode => Object.hash(url, id, owner);
}

/// L'id di un server se è nella forma giusta (128 bit, 32 cifre esadecimali
/// minuscole), altrimenti `null`.
String? serverIdOf(Object? value) =>
    value is String && RegExp(r'^[0-9a-f]{32}$').hasMatch(value) ? value : null;

/// Ciò che un server dice di sé senza token (`GET /`): chi è e se accetta i
/// biglietti. Un server di prima dei biglietti non ha né l'uno né l'altro.
class ServerHello {
  const ServerHello({this.id, this.features = const {}});

  factory ServerHello.fromJson(Map<String, Object?> json) => ServerHello(
        id: serverIdOf(json['id']),
        features: {...(json['features'] as List? ?? const []).whereType<String>()},
      );

  final String? id;
  final Set<String> features;

  /// Accetta `Authorization: Kagami-Ticket` per [id].
  bool get tickets => id != null && features.contains('tickets');
}

/// Il valore intero di `Authorization` con cui presentarsi a [link], che a
/// [hello] ha detto chi è: `Kagami-Ticket <biglietto>` o `Bearer <token>`;
/// con `refresh` uno nuovo, quando il server ha rifiutato quello di prima.
/// Chi non vuole mandare niente a quel server lancia una [ServerException].
typedef ServerCredentials = Future<String> Function(ServerLink link, ServerHello hello, {bool refresh});

/// L'indirizzo e la chiave pubblica del backend, come viaggiano in
/// `KAGAMI_SETUP`.
class ServerSetupBackend {
  const ServerSetupBackend({required this.url, required this.anonKey});

  final String url;
  final String anonKey;

  Map<String, Object?> toJson() => {'url': url, 'anonKey': anonKey};
}

/// Tutto ciò che serve al server per partire, nel comando che l'app genera
/// per il proprietario (`KAGAMI_SETUP`, docs/server-api.md): il backend
/// dell'app di cui accettare i token, il client con cui rinnovare i permessi
/// di Drive, e il proprietario col suo permesso e la sua cartella.
class ServerSetup {
  const ServerSetup({
    required this.client,
    required this.owner,
    required this.refreshToken,
    required this.folderId,
    this.folderName,
    this.name,
    this.backend,
    this.project,
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
    final backend = json['backend'];
    final hasBackend = backend is Map && backend['url'] is String && backend['anonKey'] is String;
    // Il backend o, nelle configurazioni di prima, il progetto Firebase.
    if ((!hasBackend && json['project'] is! String) ||
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
      project: json['project'] as String?,
      backend: hasBackend
          ? ServerSetupBackend(url: backend['url'] as String, anonKey: backend['anonKey'] as String)
          : null,
      client: GoogleClient(client['id'] as String, client['secret'] as String),
      owner: (owner['email'] as String).trim().toLowerCase(),
      refreshToken: owner['refreshToken'] as String,
      folderId: owner['folderId'] as String,
      folderName: owner['folderName'] as String?,
      name: json['name'] as String?,
    );
  }

  static const int version = 1;

  /// Il backend compatibile Supabase di chi compila, di cui il server accetta
  /// i token.
  final ServerSetupBackend? backend;

  /// Il progetto Firebase delle configurazioni di prima del backend.
  final String? project;
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
        'backend': ?backend?.toJson(),
        'project': ?project,
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
/// L'ultimo accende l'aggiornatore (`kagami-server update`), che ricrea
/// il server quando la CI pubblica un'immagine nuova. Ha il socket di Docker
/// e gira come root, quindi è un contenitore a parte: il server, che parla
/// con internet, non deve poter comandare la macchina. Senza controllo di
/// salute, che chiede al server della porta 8080 e lì non c'è.
///
/// Chromium gira in un contenitore suo, `kagami-browser`, senza il volume
/// dei dati né `KAGAMI_SETUP`: un renderer compromesso non arriva ai
/// permessi di Drive. Sta su una rete `--internal`, senza uscita, a cui si
/// collega anche il server, unica sua strada verso internet (proxy). Rifacendo
/// i contenitori la rete c'è già: `network create` lo dice e le righe dopo
/// partono lo stesso, in ogni terminale.
/// La rete si crea solo se manca, perché rilanciare i comandi non fallisca.
///
/// `--init`: i figli di Chromium che finiscono resterebbero lì come zombi,
/// senza nessuno che li raccolga.
String serverCommand(ServerSetup setup, {required String image, int port = 8080}) =>
    'docker network create --internal kagami-browser\n'
    'docker run -d --name kagami-browser --init --restart unless-stopped --no-healthcheck '
    '--network kagami-browser -v kagami-browser:/data '
    '$image browser\n'
    'docker run -d --name kagami-server --init --restart unless-stopped '
    '-p $port:8080 -v kagami-data:/data '
    '-e KAGAMI_SETUP=${setup.encode()} '
    '-e KAGAMI_BROWSER=kagami-browser '
    '$image\n'
    'docker network connect kagami-browser kagami-server\n'
    '${updaterCommand(image)}';

String updaterCommand(String image) =>
    'docker run -d --name kagami-updater --init --restart unless-stopped --no-healthcheck '
    '-u 0 -v /var/run/docker.sock:/var/run/docker.sock '
    '$image update';

/// L'indirizzo scritto dall'utente, ripulito: senza schema è `https://`,
/// tranne verso un indirizzo privato (rete di casa, Tailscale, questo
/// computer: [isPrivateAddress]), dove è `http://` perché lì un server
/// raramente ha un certificato. Il token non parte mai in chiaro per un
/// indirizzo scritto senza schema. Senza la `/` finale. `null` se non è un
/// indirizzo.
Uri? normalizeServerUrl(String text) {
  var value = text.trim();
  if (value.isEmpty) return null;
  if (!value.contains('://')) {
    final guess = Uri.tryParse('https://$value');
    value = guess != null && guess.host.isNotEmpty && isPrivateAddress(guess) ? 'http://$value' : 'https://$value';
  }
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

/// L'accesso dell'account è scaduto (`403 expired`): un rinnovo lo riapre.
class ServerExpired extends ServerForbidden {
  const ServerExpired(super.message) : super(code: 'expired');
}

class ServerUser {
  const ServerUser({
    required this.email,
    this.owner = false,
    this.connected = false,
    this.addedAt,
    this.expiresAt,
    this.expired = false,
  });

  factory ServerUser.fromJson(Map<String, Object?> json) => ServerUser(
        email: json['email'] as String,
        owner: json['owner'] == true,
        connected: json['connected'] == true,
        addedAt: DateTime.tryParse('${json['addedAt']}'),
        expiresAt: DateTime.tryParse('${json['expiresAt']}'),
        expired: json['expired'] == true,
      );

  final String email;
  final bool owner;

  /// Il server ha il suo permesso di Drive: ha già collegato il server.
  final bool connected;
  final DateTime? addedAt;

  /// Quando l'accesso scade; `null` se non scade (`expiry`).
  final DateTime? expiresAt;
  final bool expired;
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
    this.folderOwned,
    this.images = false,
    this.check = const RemoteCheck(),
    this.features = const {},
    this.expiresAt,
    this.expired = false,
    this.id,
    this.catalogEngine,
    this.catalogSerial,
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
      folderOwned: drive['owned'] as bool?,
      images: json['images'] == true,
      check: RemoteCheck.fromJson(check.cast<String, Object?>()),
      features: {...(json['features'] as List? ?? const []).whereType<String>()},
      expiresAt: DateTime.tryParse('${me['expiresAt']}'),
      expired: me['expired'] == true,
      id: serverIdOf(json['id']),
      catalogEngine: ((json['catalog'] as Map?)?['engine'] as num?)?.toInt(),
      catalogSerial: ((json['catalog'] as Map?)?['serial'] as num?)?.toInt(),
    );
  }

  /// Motore e serial del catalogo dei siti del server (`catalog`); `null` se non ce l'ha.
  final int? catalogEngine;
  final int? catalogSerial;

  /// L'id del server (`tickets`), lo stesso di `GET /`.
  final String? id;

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

  /// Se la cartella è di chi chiama (`owner`): `null` non letto, o un server
  /// di prima.
  final bool? folderOwned;
  final bool images;

  /// Il controllo quotidiano di chi chiama.
  final RemoteCheck check;

  /// Ciò che il server sa fare oltre alla v2 di partenza: un server di prima
  /// non lo dice, e l'app non gli chiede quelle cose.
  final Set<String> features;

  /// Quando scade l'accesso di chi chiama, se scade (`expiry`).
  final DateTime? expiresAt;

  /// L'accesso è già scaduto: il server risponde `403 expired` a quasi tutto.
  final bool expired;

  /// Scarica «man mano» (`ahead` nei lavori, `PUT /ongoing/{key}`).
  bool get ahead => features.contains('ahead');

  /// Il controllo salta le serie escluse dall'app (`unfollowed`).
  bool get unfollowed => features.contains('unfollowed');

  /// Il controllo legge anche i siti dietro la verifica del browser.
  bool get browser => features.contains('browser');

  /// Ripara la libreria su Drive ([ServerClient.repair]).
  bool get repair => features.contains('repair');

  /// Cerca le serie della libreria sugli altri siti ([ServerClient.elsewhere]).
  bool get elsewhere => features.contains('elsewhere');

  /// Dice quali serie sono ferme alla verifica del sito
  /// ([RemoteCheck.gated]) e ne accetta le pagine aperte sul telefono
  /// ([ServerClient.checkPages]).
  bool get verify => features.contains('verify');

  /// Usa i siti degli utenti (`providers/` della libreria) e li rilegge con
  /// [ServerClient.refreshProviders]. Senza, quei siti l'app li tiene sul telefono.
  bool get userProviders => features.contains('userProviders');

  /// Ritira alla scadenza le condivisioni della libreria che l'app gli affida
  /// ([ServerClient.replaceShares]).
  bool get shares => features.contains('shares');

  /// Sposta nel cestino di Drive solo nella cartella di chi chiama che è sua
  /// ([folderOwned]); altrimenti risponde `not_owner`.
  bool get guardsTrash => features.contains('owner');

  /// Accetta i biglietti al posto del token della sessione.
  bool get tickets => features.contains('tickets');

  /// L'ora del controllo, `null` se è spento.
  int? get checkMinutes => check.enabled ? check.minutes : null;

  /// Se può ricevere lavori: ha il permesso di Drive di chi chiama e la sua
  /// cartella.
  bool get ready => driveAuthorized && folderId != null;

  ServerInfo withDrive({required bool authorized, String? id, String? name, bool? owned}) => ServerInfo(
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
        folderOwned: owned,
        images: images,
        check: check,
        features: features,
        id: id,
        catalogEngine: catalogEngine,
        catalogSerial: catalogSerial,
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
        folderOwned: folderOwned,
        images: images,
        check: check,
        features: features,
        id: id,
        catalogEngine: catalogEngine,
        catalogSerial: catalogSerial,
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
    this.sites = const {},
    this.elsewhere = true,
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
      sites: {
        if (json['sites'] case final Map sites)
          for (final MapEntry(:key, :value) in sites.entries)
            if (key is String && value is Map<String, Object?>) key: SiteHealth.fromJson(value),
      },
      elsewhere: json['elsewhere'] != false,
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

  /// La salute dei siti, per id del provider (`sites` fra le `features`).
  final Map<String, SiteHealth> sites;

  /// La passata «Su altri siti» dopo il controllo (`elsewhere` fra le `features`).
  final bool elsewhere;
}

/// A che punto è la passata «Su altri siti» (`GET /v2/elsewhere`).
class ElsewherePass {
  const ElsewherePass({this.running = false, this.startedAt, this.finishedAt, this.checked = 0, this.pending = 0});

  factory ElsewherePass.fromJson(Map<String, Object?> json) => ElsewherePass(
        running: json['running'] == true,
        startedAt: DateTime.tryParse('${json['startedAt']}'),
        finishedAt: DateTime.tryParse('${json['finishedAt']}'),
        checked: (json['checked'] as num?)?.toInt() ?? 0,
        pending: (json['pending'] as num?)?.toInt() ?? 0,
      );

  final bool running;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// Serie lette nell'ultima passata.
  final int checked;

  /// Serie ancora da guardare: una libreria grande si completa in più giorni.
  final int pending;

  Map<String, Object?> toJson() => {
        'running': running,
        'startedAt': ?startedAt?.toUtc().toIso8601String(),
        'finishedAt': ?finishedAt?.toUtc().toIso8601String(),
        'checked': checked,
        'pending': pending,
      };
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

/// Una condivisione della libreria che il server ritira da [expiresAt] in
/// poi (`PUT /v2/me/shares`).
class RemoteShare {
  const RemoteShare({required this.folderId, required this.permissionId, required this.expiresAt});

  static RemoteShare? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final (folderId, permissionId) = (json['folderId'], json['permissionId']);
    final expiresAt = DateTime.tryParse('${json['expiresAt']}')?.toUtc();
    if (folderId is! String || permissionId is! String || expiresAt == null) return null;
    return RemoteShare(folderId: folderId, permissionId: permissionId, expiresAt: expiresAt);
  }

  final String folderId;
  final String permissionId;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is RemoteShare &&
      other.folderId == folderId &&
      other.permissionId == permissionId &&
      other.expiresAt.isAtSameMomentAs(expiresAt);

  @override
  int get hashCode => Object.hash(folderId, permissionId, expiresAt.millisecondsSinceEpoch);

  Map<String, Object?> toJson() =>
      {'folderId': folderId, 'permissionId': permissionId, 'expiresAt': expiresAt.toUtc().toIso8601String()};
}

/// La versione dell'API che questo client parla.
const int serverApi = 2;

class ServerClient {
  /// [credentials] dà come presentarsi al server, dopo che il server ha detto
  /// chi è (`GET /`, una volta per client). [linked] è il server già
  /// collegato, se si sta parlando con un altro indirizzo: chi ne dichiara
  /// l'id non riceve niente, perché vorrebbe i biglietti di quel server.
  ServerClient(this.link, this.credentials, {this.linked}) : _http = HttpClient() {
    _http
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15);
  }

  final ServerLink link;
  final ServerCredentials credentials;
  final ServerLink? linked;
  final HttpClient _http;
  Future<ServerHello>? _hello;

  /// Chi è il server, prima di mandargli qualunque cosa: si chiede una volta,
  /// e un rifiuto si ripete a ogni richiesta.
  Future<ServerHello> hello() => _hello ??= _greet()..ignore();

  Future<ServerHello> _greet() async {
    final Map<String, Object?>? about;
    try {
      about = await _call('GET', '/', authorized: false);
    } on ServerException catch (error) {
      _hello = null;
      if (error is ServerOffline || error.status == null) rethrow;
      throw ServerException('A questo indirizzo non risponde un Kagami Server.', status: error.status);
    } on Object {
      _hello = null;
      rethrow;
    }
    if (about?['service'] != 'kagami-server') {
      _hello = null;
      throw const ServerException('A questo indirizzo non risponde un Kagami Server.');
    }
    final hello = ServerHello.fromJson(about!);
    final linked = this.linked;
    if (linked != null && linked.id != null && hello.id == linked.id && linked.url != link.url) {
      throw ServerException('Il server a ${link.url} dice di essere quello collegato a ${linked.url}: '
          'non gli si manda niente.', code: 'impostor');
    }
    if (link.id != null && hello.id != link.id) {
      throw const ServerException('A questo indirizzo ora risponde un altro server: ricollegalo.', code: 'other_server');
    }
    return hello;
  }

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
    if (about?['service'] == 'kagami-server' && about?['api'] != serverApi) {
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

  /// Fa rileggere al server `providers/` della libreria dopo che l'app ha
  /// installato, aggiornato o tolto un sito (solo con `userProviders`).
  Future<void> refreshProviders() => _call('POST', '/v$serverApi/providers');

  /// Ripara la libreria su Drive: tutta, le serie di [site] o quelle di
  /// [keys]. Gli esiti arrivano in `history`, con `repair`.
  Future<void> repair({String? site, Set<String>? keys}) => _call('POST', '/v$serverApi/repair', body: {
        'site': ?site,
        if (keys != null) 'keys': [...keys],
      });

  Future<RemoteCheck> configureCheck({
    bool? enabled,
    int? minutes,
    bool? library,
    Set<String>? unfollowed,
    bool? elsewhere,
  }) async =>
      RemoteCheck.fromJson((await _call('PUT', '/v$serverApi/check', body: {
        'enabled': ?enabled,
        'minutes': ?minutes,
        'library': ?library,
        if (unfollowed != null) 'unfollowed': [...unfollowed],
        'elsewhere': ?elsewhere,
      }))!);

  /// Le serie della libreria sugli altri siti: tutte quelle viste, o quelle
  /// di [keys] (al più 200).
  Future<({Map<String, Elsewhere> series, ElsewherePass pass})> elsewhere({Set<String>? keys}) async {
    final query = keys == null ? '' : '?keys=${keys.map(Uri.encodeComponent).join(',')}';
    final json = (await _call('GET', '/v$serverApi/elsewhere$query'))!;
    return (
      series: {
        if (json['series'] case final Map series)
          for (final MapEntry(:key, :value) in series.entries)
            if (key is String && value is Map<String, Object?>) key: Elsewhere.fromJson(key, value),
      },
      pass: ElsewherePass.fromJson(json['pass'] as Map<String, Object?>? ?? const {}),
    );
  }

  /// Chiede di guardare subito le serie di [keys] (da 1 a 50) sugli altri
  /// siti; il risultato arriva in [elsewhere].
  Future<void> lookElsewhere(Set<String> keys) =>
      _call('POST', '/v$serverApi/elsewhere', body: {'keys': [...keys]});

  /// Manda le pagine delle serie ferme alla verifica, aperte sul telefono
  /// ([pages], per link): il server le controlla subito.
  Future<({int checked, int queued, List<GatedSeries> gated})> checkPages(Map<String, String> pages) async {
    // Il server risponde a controllo finito, che per più serie con Drive di
    // mezzo va ben oltre i 30 secondi delle altre chiamate.
    final json = (await _call('POST', '/v$serverApi/check/pages', timeout: const Duration(minutes: 5), body: {
      'pages': [for (final MapEntry(:key, :value) in pages.entries) {'url': key, 'html': value}],
    }))!;
    return (
      checked: (json['checked'] as num?)?.toInt() ?? 0,
      queued: (json['queued'] as num?)?.toInt() ?? 0,
      gated: RemoteCheck.fromJson({'gated': json['gated']}).gated,
    );
  }

  /// Dà al server il permesso sul proprio Drive e la cartella dove scrivere.
  Future<({String? id, String? name, bool? owned})> grantDrive(String refreshToken, String folderId) async =>
      _drive((await _call('PUT', '/v$serverApi/me/drive', body: {'refreshToken': refreshToken, 'folderId': folderId}))!);

  /// Il server dimentica il permesso e la coda di chi chiama.
  Future<void> forgetDrive() => _call('DELETE', '/v$serverApi/me/drive');

  /// Le condivisioni che il server ha in carico (`shares` fra le `features`).
  Future<List<RemoteShare>> heldShares() async => _shares((await _call('GET', '/v$serverApi/me/shares'))!);

  /// Affida al server l'elenco intero delle condivisioni con un termine, che
  /// sostituisce il precedente (`[]`: nessuna); torna quello in carico.
  Future<List<RemoteShare>> replaceShares(List<RemoteShare> shares) async => _shares((await _call(
      'PUT', '/v$serverApi/me/shares', body: {'shares': [for (final share in shares) share.toJson()]}))!);

  static List<RemoteShare> _shares(Map<String, Object?> json) =>
      [for (final row in json['shares'] as List? ?? const []) ?RemoteShare.fromJson(row)];

  /// Dice al server di scrivere in questa cartella di Drive; ne dà il nome e
  /// se è di chi chiama (`owner`).
  Future<({String? id, String? name, bool? owned})> chooseFolder(String folderId) async =>
      _drive((await _call('PUT', '/v$serverApi/me/folder', body: {'folderId': folderId}))!);

  static ({String? id, String? name, bool? owned}) _drive(Map<String, Object?> json) {
    final drive = json['drive'] as Map;
    return (id: drive['folderId'] as String?, name: drive['folderName'] as String?, owned: drive['owned'] as bool?);
  }

  Future<List<ServerUser>> users() async => [
        for (final row in ((await _call('GET', '/v$serverApi/users'))!['users'] as List? ?? const [])
            .whereType<Map<String, Object?>>())
          ServerUser.fromJson(row),
      ];

  Future<ServerUser> addUser(String email, {DateTime? expiresAt}) async => ServerUser.fromJson(
      (await _call('POST', '/v$serverApi/users', body: {
        'email': email,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      }))!['user'] as Map<String, Object?>);

  /// Cambia la scadenza di un utente; `null` la toglie, e un accesso scaduto riparte.
  Future<ServerUser> renewUser(String email, DateTime? expiresAt) async => ServerUser.fromJson((await _call(
    'PUT',
    '/v$serverApi/users/${Uri.encodeComponent(email)}',
    body: {'expiresAt': expiresAt?.toUtc().toIso8601String()},
  ))!['user'] as Map<String, Object?>);

  Future<void> removeUser(String email) => _call('DELETE', '/v$serverApi/users/${Uri.encodeComponent(email)}');

  void close() => _http.close(force: true);

  Future<Map<String, Object?>?> _call(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authorized = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final hello = authorized ? await this.hello() : null;
    var (status, text) =
        await _send(method, path, body, hello == null ? null : await credentials(link, hello), timeout);
    // Un token o un biglietto scaduto fra due richieste: se ne chiede uno nuovo, una volta.
    if (status == HttpStatus.unauthorized && hello != null) {
      (status, text) = await _send(method, path, body, await credentials(link, hello, refresh: true), timeout);
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
    if (status == HttpStatus.forbidden && message != null) {
      throw code == 'expired' ? ServerExpired(message) : ServerForbidden(message, code: code);
    }
    if (message != null) throw ServerException(message, code: code, status: status);
    throw ServerException(
      status == HttpStatus.notFound
          ? 'A questo indirizzo non risponde un Kagami Server.'
          : 'Il server ha risposto $status.',
      status: status,
    );
  }

  Future<(int, String)> _send(
    String method,
    String path,
    Map<String, Object?>? body,
    String? authorization,
    Duration timeout,
  ) async {
    final base = link.url;
    // La query va a parte: dentro `path` il `?` si codificherebbe.
    final query = path.indexOf('?');
    final uri = query < 0
        ? base.replace(path: '${base.path}$path')
        : base.replace(path: '${base.path}${path.substring(0, query)}', query: path.substring(query + 1));
    try {
      final request = await _http.openUrl(method, uri);
      if (authorization != null) request.headers.set(HttpHeaders.authorizationHeader, authorization);
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      } else {
        request.contentLength = 0;
      }
      final response = await request.close().timeout(timeout);
      final text = await utf8.decodeStream(response).timeout(timeout);
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
