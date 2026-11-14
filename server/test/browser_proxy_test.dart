import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_server/src/browser_proxy.dart';
import 'package:test/test.dart';

void main() {
  // Senza Chromium: il proxy parlato come lo parla lui, con CONNECT.
  test('websocket: il tunnel verso la rete interna si rifiuta, quello verso il sito si apre', () async {
    Future<(HttpServer, List<String>)> sockets(String host) async {
      final server = await HttpServer.bind(InternetAddress(host), 0);
      addTearDown(() => server.close(force: true));
      final reached = <String>[];
      server.listen((request) async {
        reached.add(request.uri.path);
        (await WebSocketTransformer.upgrade(request)).add('ciao');
      });
      return (server, reached);
    }

    final (internal, internalReached) = await sockets('127.0.0.1');
    final (site, siteReached) = await sockets('127.0.0.2');
    final logged = <String>[];
    final proxy = await GuardProxy.start((host) async => host == '127.0.0.1' ? null : InternetAddress(host), log: logged.add);
    addTearDown(proxy.close);

    Future<String> through(String authority) async {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port);
      addTearDown(socket.destroy);
      final text = StringBuffer();
      final done = socket.cast<List<int>>().transform(latin1.decoder).forEach((chunk) {
        text.write(chunk);
        if (text.toString().contains('ciao')) socket.destroy();
      });
      socket.write('CONNECT $authority HTTP/1.1\r\nHost: $authority\r\n\r\n');
      socket.write('GET /ws HTTP/1.1\r\nHost: $authority\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
          'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n');
      await done.timeout(const Duration(seconds: 10), onTimeout: () {});
      return text.toString();
    }

    expect(await through('127.0.0.1:${internal.port}'), startsWith('HTTP/1.1 403'));
    expect(internalReached, isEmpty);
    expect(logged.join('\n'), contains('bloccata'));

    final opened = await through('127.0.0.2:${site.port}');
    expect(opened, startsWith('HTTP/1.1 200'));
    expect(opened, contains('101 Switching Protocols'));
    expect(siteReached, ['/ws']);
  });

  test('websocket: senza il permesso del chiaro una richiesta http non passa', () async {
    final proxy = await GuardProxy.start((host) async => InternetAddress(host));
    addTearDown(proxy.close);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port);
    addTearDown(socket.destroy);
    socket.write('GET http://127.0.0.2:9/ HTTP/1.1\r\nHost: 127.0.0.2:9\r\n\r\n');
    final answer = await socket.cast<List<int>>().transform(latin1.decoder).join().timeout(const Duration(seconds: 10));
    expect(answer, startsWith('HTTP/1.1 403'));
  });

  test('contenitore: il proxy chiude chi non viene dal contenitore del browser', () async {
    Future<String> request(GuardProxy proxy) async {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port);
      addTearDown(socket.destroy);
      // Il proxy può chiudere prima di aver letto: il «broken pipe» qui è l'esito atteso.
      socket.done.ignore();
      socket.write('GET http://127.0.0.2:9/ HTTP/1.1\r\nHost: 127.0.0.2:9\r\n\r\n');
      // Anche il «connection reset» di chi chiude senza leggere vuol dire chiuso.
      return socket.cast<List<int>>().transform(latin1.decoder).handleError((Object _) {}).join()
          .timeout(const Duration(seconds: 10));
    }

    Future<GuardProxy> start(ProxyAdmission admit, List<String> log) async {
      final proxy = await GuardProxy.start((host) async => InternetAddress(host),
          address: InternetAddress.anyIPv4, admit: admit, log: log.add);
      addTearDown(proxy.close);
      return proxy;
    }

    // Il predicato iniettato: nessuno è ammesso, la connessione si chiude senza risposta.
    final refusedLog = <String>[];
    expect(await request(await start((_) async => false, refusedLog)), isEmpty);
    expect(refusedLog.join('\n'), contains('127.0.0.1'));
    // Quello vero: il contenitore risolve altrove, il loopback non passa.
    final elsewhereLog = <String>[];
    final elsewhere = await start(GuardProxy.resolvedFrom('browser', lookup: (_) async => [InternetAddress('10.9.8.7')]), elsewhereLog);
    expect(await request(elsewhere), isEmpty);
    expect(elsewhereLog.join('\n'), contains('chiusa'));
    // Dal contenitore la richiesta arriva alla guardia di sempre (http in chiaro: 403).
    final admitted = await start(GuardProxy.resolvedFrom('127.0.0.1'), []);
    expect(await request(admitted), startsWith('HTTP/1.1 403'));
  });

  test('contenitore: Chromium che chiude di colpo un tunnel non fa cadere il server', () async {
    // Un sito che manda molto: il proxy sta ancora scrivendo quando il capo di
    // Chromium sparisce con un reset.
    final site = await ServerSocket.bind(InternetAddress('127.0.0.2'), 0);
    addTearDown(site.close);
    site.listen((socket) {
      socket.done.catchError((Object _) {});
      socket.add(Uint8List(8 << 20));
    }, onError: (Object _) {});
    final proxy = await GuardProxy.start((host) async => InternetAddress(host));
    addTearDown(proxy.close);
    for (var i = 0; i < 10; i++) {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port);
      socket.write('CONNECT 127.0.0.2:${site.port} HTTP/1.1\r\nHost: 127.0.0.2\r\n\r\n');
      await socket.first;
      socket.setRawOption(RawSocketOption(RawSocketOption.levelSocket, 13, Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0])));
      socket.destroy();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port);
    addTearDown(socket.destroy);
    socket.write('CONNECT 127.0.0.2:${site.port} HTTP/1.1\r\nHost: 127.0.0.2\r\n\r\n');
    expect(latin1.decode(await socket.first), startsWith('HTTP/1.1 200'));
  });
}
