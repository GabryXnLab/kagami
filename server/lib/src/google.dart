/// Il permesso del server di scrivere su Drive.
///
/// Il telefono non può prestarlo: il suo token dura un'ora e una serie ne
/// dura parecchie, e un token che si rinnova da solo (refresh token) Google
/// lo dà solo a un client OAuth col suo segreto. Quindi il server ha un
/// permesso suo, dato una volta dal proprietario con `drive login`, che
/// segue il flusso delle app installate: PKCE, ritorno su un indirizzo di
/// loopback, e per un server senza schermo l'indirizzo di ritorno copiato
/// dal browser e incollato nel terminale, come fa rclone.
///
/// Il client OAuth è del proprietario (tipo «Desktop», nel suo progetto
/// Google Cloud). Kagami non ne distribuisce uno: lo scope completo di Drive
/// è «restricted», e aprirlo a chiunque vorrebbe la verifica di Google. Con
/// l'app OAuth in stato «Testing» il permesso scade dopo sette giorni: va
/// messa «In production», anche non verificata.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/stores.dart';

import 'config.dart';

final Uri googleAuthorize = Uri.https('accounts.google.com', '/o/oauth2/v2/auth');
final Uri googleToken = Uri.https('oauth2.googleapis.com', '/token');

class GoogleClient {
  const GoogleClient(this.id, this.secret);

  final String id;
  final String secret;
}

/// Il permesso non c'è o non vale più: serve `drive login`.
class DriveNotAuthorized extends DriveAuthRequired {
  const DriveNotAuthorized([this.reason = 'Il server non ha il permesso di scrivere su Drive: '
      'esegui «kagami-server drive login».']);

  final String reason;

  @override
  String toString() => reason;
}

/// I token d'accesso, dal refresh token salvato in `drive-token.json`.
class DriveTokens {
  DriveTokens(this.file, this.client, {this.endpoint});

  final File file;
  final GoogleClient? client;
  final Uri? endpoint;

  String? _access;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);

  Future<bool> get authorized async => (await _refreshToken()) != null;

  Future<String?> _refreshToken() async => (await readJsonFile(file))?['refreshToken'] as String?;

  /// Il token per [DriveClient]. Un errore di rete è [DriveOffline], come per
  /// le chiamate a Drive: il giro aspetta e riprova invece di fallire il
  /// lavoro.
  Future<String> token({bool refresh = false}) async {
    final access = _access;
    if (!refresh && access != null && DateTime.now().isBefore(_expires)) return access;
    final client = this.client;
    if (client == null) {
      throw const DriveNotAuthorized('Manca il client OAuth di Google: esegui «kagami-server drive login».');
    }
    final saved = await _refreshToken();
    if (saved == null) throw const DriveNotAuthorized();
    final json = await exchange(endpoint ?? googleToken, {
      'client_id': client.id,
      'client_secret': client.secret,
      'refresh_token': saved,
      'grant_type': 'refresh_token',
    });
    final fresh = json['access_token'] as String;
    final seconds = (json['expires_in'] as num?)?.toInt() ?? 3600;
    // Qualche minuto prima della scadenza: un caricamento cominciato con un
    // token al limite finirebbe con un 401 a metà.
    _expires = DateTime.now().add(Duration(seconds: max(60, seconds - 300)));
    return _access = fresh;
  }

  Future<void> save(String refreshToken) async {
    await writeSecret(file, jsonEncode({'refreshToken': refreshToken, 'scope': driveWriteScope}));
    _access = null;
  }
}

/// Una richiesta all'endpoint dei token di Google.
Future<Map<String, Object?>> exchange(Uri endpoint, Map<String, String> form) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await http.postUrl(endpoint);
    request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.write(Uri(queryParameters: form).query);
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) throw const DriveException('Risposta di Google non valida');
    if (response.statusCode == HttpStatus.ok && json['access_token'] is String) return json;
    final error = json['error'];
    // `invalid_grant`: permesso revocato, scaduto o client cambiato. Gli
    // altri errori del client sono configurazione sbagliata: ugualmente, si
    // rimedia solo rifacendo l'accesso.
    if (response.statusCode == HttpStatus.badRequest || response.statusCode == HttpStatus.unauthorized) {
      throw DriveNotAuthorized('Google ha rifiutato il permesso del server ($error): '
          'esegui di nuovo «kagami-server drive login».');
    }
    throw DriveException('Google ha risposto ${response.statusCode}', status: response.statusCode);
  } on SocketException {
    throw const DriveOffline();
  } on HandshakeException {
    throw const DriveOffline();
  } on HttpException {
    throw const DriveOffline('La connessione con Google si è interrotta');
  } on TimeoutException {
    throw const DriveOffline('Google non risponde');
  } on FormatException {
    throw const DriveException('Risposta di Google non valida');
  } finally {
    http.close(force: true);
  }
}

/// Un accesso in corso: l'indirizzo da aprire e come finirlo.
class Authorization {
  Authorization._(this.client, this.redirect, this._verifier, this._state);

  /// Prepara l'accesso con ritorno su `http://127.0.0.1:<port>/`.
  factory Authorization.start(GoogleClient client, int port) {
    final random = Random.secure();
    String token(int bytes) =>
        base64Url.encode([for (var i = 0; i < bytes; i++) random.nextInt(256)]).replaceAll('=', '');
    return Authorization._(client, Uri.parse('http://127.0.0.1:$port/'), token(48), token(16));
  }

  final GoogleClient client;
  final Uri redirect;
  final String _verifier;
  final String _state;

  /// L'indirizzo da aprire nel browser, su qualunque dispositivo.
  Uri get url => googleAuthorize.replace(queryParameters: {
        'client_id': client.id,
        'redirect_uri': '$redirect',
        'response_type': 'code',
        'scope': driveWriteScope,
        // `offline` e `consent` insieme: senza, un secondo accesso non
        // riceve di nuovo il refresh token.
        'access_type': 'offline',
        'prompt': 'consent',
        'code_challenge': base64Url.encode(sha256.convert(ascii.encode(_verifier)).bytes).replaceAll('=', ''),
        'code_challenge_method': 'S256',
        'state': _state,
      });

  /// Il codice dall'indirizzo di ritorno, arrivato al server o incollato.
  String code(Uri returned) {
    final query = returned.queryParameters;
    if (query['error'] != null) throw DriveNotAuthorized('Google ha negato l\'accesso: ${query['error']}');
    if (query['state'] != _state) {
      throw const DriveNotAuthorized('L\'indirizzo non è quello di questo accesso: rifai «drive login».');
    }
    final code = query['code'];
    if (code == null || code.isEmpty) throw const DriveNotAuthorized('Nell\'indirizzo manca il codice.');
    return code;
  }

  /// Il refresh token in cambio del codice.
  Future<String> finish(String code, {Uri? endpoint}) async {
    final json = await exchange(endpoint ?? googleToken, {
      'client_id': client.id,
      'client_secret': client.secret,
      'code': code,
      'code_verifier': _verifier,
      'redirect_uri': '$redirect',
      'grant_type': 'authorization_code',
    });
    final refresh = json['refresh_token'];
    if (refresh is! String) {
      throw const DriveNotAuthorized('Google non ha dato un permesso duraturo: rifai «drive login».');
    }
    return refresh;
  }
}

/// L'accesso da terminale: stampa l'indirizzo e aspetta il ritorno, dal
/// browser sulla stessa macchina o incollato da chi l'ha aperto altrove.
Future<String> loginFromTerminal(GoogleClient client, {required Stream<String> lines, required void Function(String) say}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final auth = Authorization.start(client, server.port);
  final returned = Completer<Uri>();
  server.listen((request) async {
    request.response
      ..headers.contentType = ContentType.html
      ..write('<!doctype html><meta charset="utf-8"><p>Kagami Server: accesso ricevuto, '
          'puoi chiudere questa pagina.</p>');
    await request.response.close();
    if (!returned.isCompleted && request.uri.queryParameters.containsKey('state')) {
      returned.complete(request.requestedUri);
    }
  });
  say('Apri questo indirizzo nel browser, su qualsiasi dispositivo, e concedi l\'accesso:\n\n${auth.url}\n');
  say('Se il browser non è su questa macchina, alla fine mostrerà una pagina che non si carica '
      '(http://127.0.0.1:${server.port}/…): copia l\'indirizzo intero dalla barra e incollalo qui.');
  final subscription = lines.listen((line) {
    final text = line.trim();
    if (text.isEmpty || returned.isCompleted) return;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.queryParameters.containsKey('state')) {
      say('Non sembra l\'indirizzo di ritorno: deve contenere «code=» e «state=».');
      return;
    }
    returned.complete(uri);
  });
  try {
    final uri = await returned.future.timeout(
      const Duration(minutes: 15),
      onTimeout: () => throw const DriveNotAuthorized('Accesso non completato entro 15 minuti: rifai «drive login».'),
    );
    return await auth.finish(auth.code(uri));
  } finally {
    await subscription.cancel();
    await server.close(force: true);
  }
}
