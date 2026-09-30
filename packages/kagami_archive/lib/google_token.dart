/// L'endpoint dei token di Google, per i permessi di Drive che durano.
///
/// Il token che Google dà al telefono vale un'ora, e una serie sul server ne
/// dura parecchie. Un permesso che si rinnova da solo (refresh token) Google
/// lo dà solo a un client OAuth col suo segreto, in cambio del codice che
/// l'app riceve per quel client (`serverAuthCode`). Il client è il «Web» del
/// progetto Firebase dell'app: il codice lo riscatta l'app, che mette il
/// permesso nel comando di avvio (proprietario) o lo manda al server (gli
/// altri), e il server lo rinnova con lo stesso client.
///
/// Sta nel pacchetto perché lo usano tutt'e due: l'app per riscattare, il
/// server per rinnovare.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'drive.dart';

final Uri googleTokenEndpoint = Uri.https('oauth2.googleapis.com', '/token');

class GoogleClient {
  const GoogleClient(this.id, this.secret);

  final String id;
  final String secret;
}

/// Google ha rifiutato il permesso: revocato, scaduto, di un altro client.
/// Si rimedia solo rifacendolo dall'app.
class GrantRejected extends DriveAuthRequired {
  const GrantRejected(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

/// Una richiesta all'endpoint dei token. Un errore di rete è [DriveOffline],
/// come per le chiamate a Drive: chi aspetta riprova invece di arrendersi.
Future<Map<String, Object?>> requestGoogleToken(Map<String, String> form, {Uri? endpoint}) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await http.postUrl(endpoint ?? googleTokenEndpoint);
    request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.write(Uri(queryParameters: form).query);
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) throw const DriveException('Risposta di Google non valida');
    if (response.statusCode == HttpStatus.ok && json['access_token'] is String) return json;
    // `invalid_grant`: permesso revocato, scaduto o client cambiato. Gli
    // altri errori del client sono configurazione sbagliata: ugualmente, si
    // rimedia solo rifacendo il permesso.
    if (response.statusCode == HttpStatus.badRequest || response.statusCode == HttpStatus.unauthorized) {
      throw GrantRejected('Google ha rifiutato il permesso di Drive (${json['error']})');
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

/// Il refresh token in cambio del codice che Android dà per [client]. Il
/// codice vale una volta sola e pochi minuti: si riscatta appena arriva.
Future<String> redeemServerCode(GoogleClient client, String code, {Uri? endpoint}) async {
  final json = await requestGoogleToken({
    'client_id': client.id,
    'client_secret': client.secret,
    'code': code,
    // I codici del telefono non hanno un indirizzo di ritorno: Google vuole
    // il campo, vuoto.
    'redirect_uri': '',
    'grant_type': 'authorization_code',
  }, endpoint: endpoint);
  final refresh = json['refresh_token'];
  if (refresh is! String || refresh.isEmpty) {
    throw const GrantRejected('Google non ha dato un permesso duraturo: riprova.');
  }
  return refresh;
}
