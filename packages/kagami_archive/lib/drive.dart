/// Il client REST di Google Drive: elenchi, ricerche, download e caricamenti.
///
/// Niente pacchetto `googleapis`: all'app servono tre chiamate — elencare,
/// cercare, scaricare — e `dart:io` le fa senza portarsi dietro la
/// descrizione di tutte le API di Google.
///
/// Drive non ha percorsi, ha identificativi: `Serie/chapters/0001/0001.webp`
/// è una catena di quattro cartelle da elencare. Chi usa questo client tiene
/// da parte gli elenchi (vedere `drive_library.dart`), perché ripagare quella
/// catena a ogni tavola vorrebbe dire aspettare la rete quattro volte prima
/// di cominciare a scaricare.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Il permesso chiesto all'utente.
///
/// Sola lettura: le cartelle le scrive rclone dal server, e a un lettore
/// basta leggerle. Lo scope è "restricted" per Google — le cartelle non le ha
/// create l'app, quindi `drive.file` non le vedrebbe — e va dichiarato nella
/// schermata di consenso del progetto Firebase, dove è dichiarato anche
/// quello completo: chiederlo qui sarebbe chiedere di poter
/// cancellare tutto il Drive dell'utente per mostrargli delle tavole.
const String driveScope = 'https://www.googleapis.com/auth/drive.readonly';

/// Il permesso di scrivere, chiesto solo a chi accende una sincronizzazione
/// che carica su Drive (`folder_sync.dart`). Deve essere quello completo: le
/// cartelle della libreria le ha create rclone, e `drive.file` lascerebbe
/// scrivere solo nei file creati dall'app.
const String driveWriteScope = 'https://www.googleapis.com/auth/drive';

const String folderMimeType = 'application/vnd.google-apps.folder';

/// Un file o una cartella di Drive, con quanto serve a riconoscerlo.
class DriveItem {
  const DriveItem({
    required this.id,
    required this.name,
    this.folder = false,
    this.size,
    this.md5,
    this.modified,
    this.parents = const [],
  });

  factory DriveItem.fromJson(Map<String, Object?> json) => DriveItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        folder: json['mimeType'] == folderMimeType || json['folder'] == true,
        size: int.tryParse('${json['size']}'),
        md5: json['md5Checksum'] as String?,
        modified: DateTime.tryParse('${json['modifiedTime']}'),
        parents: (json['parents'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  final String id;
  final String name;
  final bool folder;
  final int? size;
  final String? md5;
  final DateTime? modified;
  final List<String> parents;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (folder) 'folder': true,
        'size': ?size,
        'md5Checksum': ?md5,
        'modifiedTime': ?modified?.toIso8601String(),
        if (parents.isNotEmpty) 'parents': parents,
      };

  /// Il nome con cui il contenuto si ritrova in cache: l'impronta quando
  /// Drive la dà, perché due versioni dello stesso file non si confondano.
  String get contentKey =>
      md5 ?? '$id-${modified?.millisecondsSinceEpoch ?? 0}';
}

class DriveException implements Exception {
  const DriveException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// La rete non c'è, o non ce la fa. Non è un guasto: è uno stato che passa,
/// e chi lo riceve aspetta che passi invece di arrendersi.
class DriveOffline extends DriveException {
  const DriveOffline([super.message = 'Nessuna connessione']);
}

/// Se un errore passerà da solo quando torna la rete.
bool isNetworkFailure(Object? error) => error is DriveOffline;

/// L'utente non ha ancora dato il permesso di leggere Drive, o l'ha tolto:
/// serve un suo gesto, e l'interfaccia deve offrirglielo invece di un errore.
class DriveAuthRequired extends DriveException {
  const DriveAuthRequired()
      : super('Serve il permesso di leggere Google Drive');
}

/// Se c'è rete, per chi parla con Drive. Nell'app è il monitor del
/// telefono (`NetworkMonitor`); un'interfaccia perché il client non dipenda
/// da Flutter.
abstract interface class NetworkState {
  bool get isOnline;

  /// Una richiesta è fallita per la rete: vale la pena ricontrollare.
  void failed();

  /// Una richiesta è riuscita: la rete c'è.
  void succeeded();

  /// Controlla adesso se c'è rete.
  Future<bool> check();
}

/// Le chiamate a Drive.
class DriveClient {
  DriveClient(
    this._token, {
    required this.network,
    @visibleForTesting Uri Function(String path, Map<String, String> query)?
        endpoint,
    @visibleForTesting this.stall = const Duration(seconds: 20),
    @visibleForTesting this.multipartLimit = 5 * 1024 * 1024,
  })  : _endpoint = endpoint ?? _drive,
        _http = HttpClient() {
    _http
      ..connectionTimeout = const Duration(seconds: 10)
      // Le tavole si scaricano in parallelo: con la stessa connessione si
      // risparmiano le strette di mano TLS, che su una rete mobile sono la
      // parte lenta.
      ..maxConnectionsPerHost = 8
      ..idleTimeout = const Duration(seconds: 30);
  }

  final Future<String> Function({bool refresh}) _token;
  final NetworkState network;
  final HttpClient _http;

  final Uri Function(String path, Map<String, String> query) _endpoint;

  /// Quanto silenzio di una connessione aperta vale un'interruzione.
  final Duration stall;

  /// Fin qui un file sale in una richiesta sola: è la misura che Google
  /// indica per il caricamento multipart.
  final int multipartLimit;

  /// Fino a quando Drive ha chiesto di rallentare: vedere [_send].
  DateTime _calm = DateTime.fromMillisecondsSinceEpoch(0);
  final Random _random = Random();

  /// Ogni quanti byte ricevuti si scrive sul disco.
  static const int _writeBlock = 256 * 1024;

  static Uri _drive(String path, Map<String, String> query) =>
      Uri.https('www.googleapis.com', path, query);
  static const String _fields =
      'nextPageToken,files(id,name,mimeType,size,md5Checksum,modifiedTime,parents)';

  /// Una ricerca, con tutte le sue pagine.
  Future<List<DriveItem>> query(String q, {String orderBy = 'name'}) async {
    final items = <DriveItem>[];
    String? page;
    do {
      final response = await _get(_endpoint('/drive/v3/files', {
        'q': q,
        'fields': _fields,
        'pageSize': '1000',
        'orderBy': orderBy,
        'supportsAllDrives': 'true',
        'includeItemsFromAllDrives': 'true',
        'pageToken': ?page,
      }));
      // Una pagina può essere mille voci: decodificarla qui toglieva
      // fotogrammi alla schermata che si stava aprendo.
      final source = await utf8.decodeStream(_watch(response));
      final result = await Isolate.run(() => _parsePage(source));
      if (result == null) {
        throw const DriveException('Risposta di Drive non valida');
      }
      items.addAll(result.items);
      page = result.next;
    } while (page != null);
    return items;
  }

  static ({List<DriveItem> items, String? next})? _parsePage(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, Object?>) return null;
    return (
      items: (json['files'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .where((row) => row['id'] is String)
          .map(DriveItem.fromJson)
          .toList(growable: false),
      next: json['nextPageToken'] as String?,
    );
  }

  Future<List<DriveItem>> children(String folderId) =>
      query("'${quote(folderId)}' in parents and trashed = false");

  Future<List<DriveItem>> folders(String parentId) => query(
        "'${quote(parentId)}' in parents and mimeType = '$folderMimeType' "
        'and trashed = false',
      );

  /// Le cartelle che altri hanno condiviso: la libreria sta spesso sul
  /// Drive di chi fa girare il server, non su quello di chi legge.
  Future<List<DriveItem>> sharedFolders() => query(
        "sharedWithMe and mimeType = '$folderMimeType' and trashed = false",
      );

  /// Il contenuto di un file come testo.
  Future<String> text(String id) async =>
      utf8.decodeStream(_watch(await _get(_media(id))));

  /// Scarica un file a flusso: una tavola non passa mai intera dalla memoria.
  ///
  /// Se [target] c'è già, è l'inizio di un tentativo andato male, e si chiede
  /// a Drive solo il resto. Su una rete che cade ogni trenta secondi è la
  /// differenza fra una tavola che arriva e una che ricomincia da capo per
  /// sempre.
  Future<void> download(String id, File target) async {
    final have = await target.exists() ? await target.length() : 0;
    final HttpClientResponse response;
    try {
      response = await _get(_media(id), from: have);
    } on DriveException catch (error) {
      // Il pezzo che c'era è già tutto il file: il tentativo di prima era
      // finito, ma non era stato rinominato. Si ricomincia pulito.
      if (error.status == 416 && have > 0) {
        await target.delete();
        return download(id, target);
      }
      rethrow;
    }
    // Pezzo per pezzo e non con un `IOSink`: se la connessione cade, quello
    // che era arrivato deve essere già sul disco, perché è da lì che il
    // prossimo tentativo riparte. Un `IOSink` che riceve un errore può
    // chiudersi buttando ciò che aveva ancora in mano.
    final file = await target.open(
      mode: response.statusCode == HttpStatus.partialContent
          ? FileMode.append
          : FileMode.write,
    );
    // I pezzi della rete sono di pochi kilobyte, e ognuno scritto da solo è
    // un giro sul thread dell'interfaccia: con tre tavole in arrivo sono
    // centinaia al secondo, e si vedono come scatti nello scorrimento. Si
    // scrive a blocchi, e quello che resta si scrive comunque prima di
    // chiudere, anche quando la connessione cade.
    final pending = BytesBuilder(copy: false);
    try {
      await for (final chunk in _watch(response)) {
        pending.add(chunk);
        if (pending.length >= _writeBlock) await file.writeFrom(pending.takeBytes());
      }
    } on DriveException {
      rethrow;
    } on Object {
      network.failed();
      throw const DriveOffline('La connessione si è interrotta');
    } finally {
      if (pending.isNotEmpty) await file.writeFrom(pending.takeBytes());
      await file.close();
    }
  }

  Uri _media(String id) => _endpoint('/drive/v3/files/$id', {
        'alt': 'media',
        'supportsAllDrives': 'true',
      });

  /// Una connessione che resta aperta senza portare niente è peggio di una
  /// che cade: non dà errore, aspetta. Dopo un po' di silenzio la si chiude
  /// e ci pensa chi riprova — dal punto in cui era arrivata.
  Stream<List<int>> _watch(Stream<List<int>> body) => body.timeout(
        stall,
        onTimeout: (sink) {
          network.failed();
          sink
            ..addError(const DriveOffline('La connessione si è fermata'))
            ..close();
        },
      );

  Future<HttpClientResponse> _get(Uri uri, {int from = 0}) =>
      _send('GET', uri, from: from);

  /// Una richiesta a Drive, con tutto quello che serve a farla riuscire:
  /// token rinnovato, attese quando Drive rallenta, rete che manca.
  ///
  /// [write] scrive il corpo, e a ogni tentativo da capo: un file da caricare
  /// si rilegge dal disco invece di restare in memoria.
  Future<HttpClientResponse> _send(
    String method,
    Uri uri, {
    int from = 0,
    Map<String, String> headers = const {},
    Future<void> Function(HttpClientRequest request)? write,
  }) async {
    // Senza rete non si prova nemmeno: la risposta la si sa già, e darla
    // subito è ciò che fa comparire l'avviso sulla tavola invece di un
    // cerchio che gira.
    if (!network.isOnline) throw const DriveOffline();
    var refreshed = false;
    var refresh = false;
    for (var attempt = 0;; attempt++) {
      final calm = _calm.difference(DateTime.now());
      if (calm > Duration.zero) await Future<void>.delayed(calm);
      final String token;
      try {
        token = await _token(refresh: refresh);
      } on DriveAuthRequired {
        // Senza rete il sistema non sa rinnovare il permesso, e dirlo come
        // "serve il permesso" manderebbe l'utente a cercare il guasto sbagliato.
        if (!await network.check()) throw const DriveOffline();
        rethrow;
      }
      refresh = false;
      final HttpClientResponse response;
      try {
        final request = await _http.openUrl(method, uri);
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        if (from > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
        headers.forEach(request.headers.set);
        if (write != null) {
          await write(request);
        } else if (method != 'GET') {
          request.contentLength = 0;
        }
        response = await request.close().timeout(const Duration(seconds: 20));
      } on SocketException {
        network.failed();
        throw const DriveOffline();
      } on HandshakeException {
        network.failed();
        throw const DriveOffline();
      } on HttpException {
        network.failed();
        throw const DriveOffline('La connessione si è interrotta');
      } on TimeoutException {
        network.failed();
        throw const DriveOffline('La rete è troppo lenta');
      }
      final status = response.statusCode;
      if (status == HttpStatus.ok ||
          status == HttpStatus.created ||
          status == HttpStatus.partialContent) {
        network.succeeded();
        return response;
      }
      final body = await utf8.decodeStream(response).catchError((_) => '');
      if (status == HttpStatus.unauthorized && !refreshed) {
        refreshed = true;
        refresh = true;
        continue;
      }
      // Drive rallenta chi chiede troppo in fretta, e il lettore chiede
      // sessanta tavole in un colpo, l'archiviatore centinaia di file:
      // aspettare è la risposta giusta, arrendersi no. L'attesa vale per
      // tutte le richieste di questo client, non solo per quella respinta,
      // altrimenti le altre corsie continuano a sbattere contro lo stesso
      // limite e lo allungano.
      final throttled = status == 429 ||
          status >= 500 ||
          (status == HttpStatus.forbidden && body.contains('ateLimitExceeded'));
      if (throttled && attempt < 7) {
        final backoff = Duration(milliseconds: (500 << attempt) * (0.75 + _random.nextDouble() / 2) ~/ 1);
        final seconds = int.tryParse(response.headers.value(HttpHeaders.retryAfterHeader)?.trim() ?? '');
        final asked = seconds == null ? null : Duration(seconds: seconds.clamp(0, 120));
        final until = DateTime.now().add(asked != null && asked > backoff ? asked : backoff);
        if (until.isAfter(_calm)) _calm = until;
        continue;
      }
      if (status == HttpStatus.unauthorized ||
          (status == HttpStatus.forbidden &&
              body.contains('insufficientPermissions'))) {
        throw const DriveAuthRequired();
      }
      throw DriveException(
        status == HttpStatus.notFound
            ? 'File non trovato su Drive'
            : 'Drive ha risposto $status',
        status: status,
      );
    }
  }

  static const String _itemFields =
      'id,name,mimeType,size,md5Checksum,modifiedTime,parents';

  /// Un file o una cartella per identificativo: dice se c'è, se lo si vede
  /// e come si chiama.
  Future<DriveItem> file(String id) async => _item(await _get(_endpoint(
        '/drive/v3/files/${Uri.encodeComponent(id)}',
        {'fields': _itemFields, 'supportsAllDrives': 'true'},
      )));

  /// Crea una cartella dentro [parentId].
  Future<DriveItem> createFolder(String name, String parentId) => _json(
        'POST',
        _endpoint('/drive/v3/files', {
          'fields': _itemFields,
          'supportsAllDrives': 'true',
        }),
        {
          'name': name,
          'mimeType': folderMimeType,
          'parents': [parentId],
        },
      );

  /// Carica [file]: nuovo dentro [parentId], o al posto del contenuto di
  /// [id]. La data di modifica è quella del telefono, così chi confronta le
  /// due copie confronta le date giuste e non quella del caricamento.
  ///
  /// Un file piccolo — una tavola, una tessera, un indice — sale in una
  /// richiesta sola, metadati e byte insieme: Drive conta le richieste, non
  /// i byte, e un capitolo sono centinaia di file. Uno grande sale col
  /// caricamento riprendibile, in due tempi — prima i metadati, poi i byte a
  /// flusso — perché è l'unico che accetti file di qualunque misura senza
  /// tenerli in memoria. Se si interrompe si ricomincia il file.
  Future<DriveItem> upload(
    File file, {
    String? id,
    String? name,
    String? parentId,
    DateTime? modified,
  }) async {
    assert(id != null || (name != null && parentId != null));
    final length = await file.length();
    final metadata = <String, Object?>{
      'name': ?name,
      if (parentId != null && id == null) 'parents': [parentId],
      'modifiedTime': ?modified?.toUtc().toIso8601String(),
    };
    final path = id == null ? '/upload/drive/v3/files' : '/upload/drive/v3/files/$id';
    if (length <= multipartLimit) {
      final bytes = await file.readAsBytes();
      final boundary = 'kagami-${_random.nextInt(1 << 32)}-${DateTime.now().microsecondsSinceEpoch}';
      final head = utf8.encode('--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '${jsonEncode(metadata)}\r\n'
          '--$boundary\r\n'
          'Content-Type: application/octet-stream\r\n\r\n');
      final tail = utf8.encode('\r\n--$boundary--\r\n');
      return _item(await _send(
        id == null ? 'POST' : 'PATCH',
        _endpoint(path, {
          'uploadType': 'multipart',
          'supportsAllDrives': 'true',
          'fields': _itemFields,
        }),
        write: (request) async {
          request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/related; boundary=$boundary');
          request.contentLength = head.length + bytes.length + tail.length;
          request
            ..add(head)
            ..add(bytes)
            ..add(tail);
        },
      ));
    }
    final session = await _send(
      id == null ? 'POST' : 'PATCH',
      _endpoint(path, {
        'uploadType': 'resumable',
        'supportsAllDrives': 'true',
      }),
      headers: {'X-Upload-Content-Length': '$length'},
      write: _jsonBody(metadata),
    );
    await session.drain<void>();
    final location = session.headers.value(HttpHeaders.locationHeader);
    if (location == null) {
      throw const DriveException('Drive non ha aperto il caricamento');
    }
    final target = Uri.parse(location);
    final response = await _send(
      'PUT',
      target.replace(queryParameters: {
        ...target.queryParameters,
        'fields': _itemFields,
      }),
      write: (request) async {
        request.contentLength = length;
        await request.addStream(file.openRead());
      },
    );
    return _item(response);
  }

  /// Sposta nel cestino: da lì si recupera per trenta giorni, ed è l'unico
  /// modo in cui l'app toglie qualcosa da Drive.
  Future<void> trash(String id) async {
    await _json(
      'PATCH',
      _endpoint('/drive/v3/files/$id', {
        'fields': 'id',
        'supportsAllDrives': 'true',
      }),
      {'trashed': true},
    );
  }

  Future<DriveItem> _json(String method, Uri uri, Map<String, Object?> body) async =>
      _item(await _send(method, uri, write: _jsonBody(body)));

  static Future<void> Function(HttpClientRequest) _jsonBody(
    Map<String, Object?> json,
  ) =>
      (request) async {
        final bytes = utf8.encode(jsonEncode(json));
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      };

  Future<DriveItem> _item(HttpClientResponse response) async {
    final json = jsonDecode(await utf8.decodeStream(_watch(response)));
    if (json is! Map<String, Object?> || json['id'] is! String) {
      throw const DriveException('Risposta di Drive non valida');
    }
    return DriveItem.fromJson(json);
  }

  void close() => _http.close(force: true);

  /// Le virgolette nelle ricerche di Drive: i titoli dei manga ne sono pieni.
  static String quote(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}

/// La parte di Drive che serve alla sincronizzazione. Un'interfaccia perché
/// i test la fanno in memoria.
abstract interface class SyncRemote {
  /// I figli di più cartelle insieme.
  Future<List<DriveItem>> childrenOf(List<String> folderIds);

  Future<void> download(String id, File target);

  Future<DriveItem> upload(
    File file, {
    String? id,
    String? name,
    String? parentId,
    DateTime? modified,
  });

  Future<DriveItem> createFolder(String name, String parentId);

  Future<void> trash(String id);
}

/// [SyncRemote] con il client vero.
class DriveSyncRemote implements SyncRemote {
  const DriveSyncRemote(this.client);

  final DriveClient client;

  @override
  Future<List<DriveItem>> childrenOf(List<String> folderIds) => client.query(
        '(${folderIds.map((id) => "'${DriveClient.quote(id)}' in parents").join(' or ')}) '
        'and trashed = false',
      );

  @override
  Future<void> download(String id, File target) =>
      client.download(id, target);

  @override
  Future<DriveItem> upload(
    File file, {
    String? id,
    String? name,
    String? parentId,
    DateTime? modified,
  }) =>
      client.upload(
        file,
        id: id,
        name: name,
        parentId: parentId,
        modified: modified,
      );

  @override
  Future<DriveItem> createFolder(String name, String parentId) =>
      client.createFolder(name, parentId);

  @override
  Future<void> trash(String id) => client.trash(id);
}
