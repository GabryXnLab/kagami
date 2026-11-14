/// Il proxy da cui passa ogni connessione del Chromium del server.
///
/// `Fetch` di DevTools ferma le richieste HTTP, ma non vede i WebSocket: una
/// pagina potrebbe aprirne uno verso la rete interna. Chromium allora non si
/// collega a niente da sé (`--proxy-server`, loopback compreso): ogni
/// connessione, `CONNECT` per `https`, `wss` e `ws`, arriva qui, l'host si
/// risolve una volta sola e, se non è privato, ci si collega proprio
/// all'indirizzo controllato. Così si chiude anche la finestra del DNS
/// rebinding fra il controllo e la connessione.
///
/// Con Chromium nel suo contenitore (`KAGAMI_BROWSER`) il proxy ascolta su
/// tutte le interfacce del server, ma risponde solo al contenitore del
/// browser: chi altro arrivasse alla porta lo userebbe per uscire dal server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// L'indirizzo pubblico a cui collegarsi per [host], o `null` se non si
/// risolve o risolve in un indirizzo privato.
typedef PublicResolver = Future<InternetAddress?> Function(String host);

/// Se la connessione che viene da [remote] si serve.
typedef ProxyAdmission = Future<bool> Function(InternetAddress remote);

class GuardProxy {
  GuardProxy._(this._server, this._resolve, this._plain, this._log, this._admit) {
    _server.listen((client) => unawaited(_serve(client)));
  }

  /// Con [plain] passano anche le richieste `http` in chiaro, una per
  /// connessione: solo per i test, che servono il sito sul loopback.
  /// Senza [admit] ascolta sul loopback, per il Chromium della stessa
  /// macchina; con [admit] su [address] e [port], e serve solo chi ammette.
  static Future<GuardProxy> start(PublicResolver resolve,
          {bool plain = false,
          void Function(String)? log,
          InternetAddress? address,
          int port = 0,
          ProxyAdmission? admit}) async =>
      GuardProxy._(await ServerSocket.bind(address ?? InternetAddress.loopbackIPv4, port), resolve, plain,
          log ?? (_) {}, admit);

  /// Ammette solo gli indirizzi in cui risolve [host] al momento della
  /// connessione: il contenitore del browser ricreato cambia indirizzo.
  static ProxyAdmission resolvedFrom(String host, {Future<List<InternetAddress>> Function(String host)? lookup}) =>
      (remote) async {
        final literal = InternetAddress.tryParse(host);
        try {
          final addresses = literal != null ? [literal] : await (lookup ?? InternetAddress.lookup)(host).timeout(const Duration(seconds: 10));
          return addresses.any((address) => address.address == remote.address);
        } on Exception {
          return false;
        }
      };

  final ServerSocket _server;
  final PublicResolver _resolve;
  final bool _plain;
  final void Function(String) _log;
  final ProxyAdmission? _admit;
  final Set<Socket> _open = {};

  int get port => _server.port;

  Future<void> close() async {
    await _server.close();
    for (final socket in [..._open]) {
      socket.destroy();
    }
    _open.clear();
  }

  Future<void> _serve(Socket client) async {
    _open.add(client);
    Socket? upstream;
    try {
      final admit = _admit;
      if (admit != null && !await admit(client.remoteAddress)) {
        _log('Browser: connessione al proxy da ${client.remoteAddress.address} chiusa (non è il contenitore del browser).');
        return;
      }
      final input = StreamIterator(client);
      final head = BytesBuilder(copy: false);
      var end = -1;
      while ((end = _headEnd(head)) < 0) {
        if (head.length > 16 * 1024 || !await input.moveNext().timeout(const Duration(seconds: 30))) return;
        head.add(input.current);
      }
      final bytes = head.takeBytes();
      final lines = latin1.decode(bytes.sublist(0, end)).split('\r\n');
      final request = lines.first.split(' ');
      if (request.length != 3) return;
      final connect = request[0] == 'CONNECT';
      final target = Uri.tryParse(connect ? '//${request[1]}' : request[1]);
      if (target == null ||
          target.host.isEmpty ||
          (connect ? !target.hasPort : !(_plain && target.scheme == 'http'))) {
        return await _refuse(client, request[1], 'richiesta non ammessa');
      }
      final address = await _resolve(target.host);
      if (address == null) return await _refuse(client, request[1], 'indirizzo privato o che non si risolve');
      upstream = await Socket.connect(address, target.port, timeout: const Duration(seconds: 30));
      _open.add(upstream);
      if (connect) {
        client.add(latin1.encode('HTTP/1.1 200 Connection Established\r\n\r\n'));
      } else {
        // Una richiesta per connessione: Chromium riusa le connessioni col
        // proxy anche per altri host, e questa resta legata all'indirizzo
        // controllato.
        final path = '${target.path.isEmpty ? '/' : target.path}${target.hasQuery ? '?${target.query}' : ''}';
        final headers = lines.skip(1).where((line) {
          final name = line.split(':').first.trim().toLowerCase();
          return line.isNotEmpty && name != 'connection' && name != 'proxy-connection';
        });
        upstream.add(latin1.encode('${request[0]} $path ${request[2]}\r\n${headers.join('\r\n')}\r\nConnection: close\r\n\r\n'));
      }
      upstream.add(bytes.sublist(end + 4));
      final to = upstream;
      final down = to.cast<List<int>>().forEach(client.add);
      final up = () async {
        while (await input.moveNext()) {
          to.add(input.current);
        }
      }();
      // Il capo che finisce per secondo può fallire (connection reset) a
      // proxy già chiuso: senza gestore l'errore arriverebbe alla zona.
      await Future.any([down, up].map((side) => side.catchError((Object _) {})));
      await client.flush();
    } on Object catch (_) {
      // Un capo caduto: si chiude l'altro.
    } finally {
      client.destroy();
      upstream?.destroy();
      _open
        ..remove(client)
        ..remove(upstream);
    }
  }

  Future<void> _refuse(Socket client, String target, String why) async {
    _log('Browser: connessione a $target bloccata ($why).');
    client.add(latin1.encode('HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'));
    await client.flush();
  }

  static int _headEnd(BytesBuilder head) {
    final bytes = head.toBytes();
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 && bytes[i + 1] == 10 && bytes[i + 2] == 13 && bytes[i + 3] == 10) return i;
    }
    return -1;
  }
}
