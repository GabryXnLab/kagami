import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/renderer.dart';
import 'package:kagami_server/src/browser.dart';
import 'package:kagami_server/src/browser_container.dart';
import 'package:kagami_server/src/browser_proxy.dart';
import 'package:test/test.dart';

void main() {
  // Dove Chromium non c'è (la CI senza browser) i test si saltano.
  final missing = Platform.environment['KAGAMI_CHROMIUM'] == null && !_onPath() ? 'Chromium non c\'è' : false;
  late HttpServer site;
  String? chromium;
  final logged = <String>[];

  // I processi figli di Chromium (crashpad, zygote) possono scrivere nel
  // profilo per un attimo dopo l'uscita del principale: la cancellazione
  // riprova invece di fallire su «Directory not empty» (CI del 2026-11-15).
  Future<void> deleteProfile(Directory profile) async {
    for (var attempt = 0;; attempt++) {
      try {
        if (await profile.exists()) await profile.delete(recursive: true);
        return;
      } on FileSystemException {
        if (attempt == 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  // Ogni test ha il suo profilo e il suo Chromium: nessun blocco o processo
  // di un test può toccare il seguente. Il log resta per dire, a un fallimento,
  // cosa ha visto il browser.
  Future<HeadlessBrowser> newBrowser(Duration timeout, [Directory? dir]) async {
    final profile = dir ?? await Directory.systemTemp.createTemp('kagami-browser-');
    addTearDown(() => deleteProfile(profile));
    final browser = HeadlessBrowser(chromium!, profile,
        timeout: timeout, log: logged.add, guard: false, private: (address) => address.address == '127.0.0.1');
    addTearDown(browser.close);
    return browser;
  }

  setUp(logged.clear);

  setUpAll(() async {
    chromium = await HeadlessBrowser.find();
    // Una «verifica» che lascia il posto alla pagina vera dopo un po', come
    // quella di Cloudflare, e l'user agent con cui la si è chiesta.
    // Su 127.0.0.2: 127.0.0.1 è la «rete interna» che Chromium non apre.
    site = await HttpServer.bind(InternetAddress('127.0.0.2'), 0);
    site.listen((request) {
      final agent = request.headers.value(HttpHeaders.userAgentHeader) ?? '';
      request.response
        ..headers.contentType = ContentType.html
        ..write('<html><body><p id="agent">$agent</p><script>'
            'setTimeout(() => { const list = document.createElement("div");'
            ' list.id = "chaptersList"; document.body.appendChild(list); }, 1500);'
            '</script></body></html>')
        ..close();
    });
  });

  tearDownAll(() async {
    await site.close(force: true);
  });

  test('un reindirizzamento verso la rete interna non apre niente e non torna', () async {
    // 127.0.0.1 fa da rete interna (metadati, router); il «sito» sta su
    // 127.0.0.2 e porta Chromium là con un 302 o col JavaScript.
    final internal = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => internal.close(force: true));
    final reached = <String>[];
    internal.listen((request) {
      reached.add(request.uri.path);
      request.response
        ..headers.contentType = ContentType.html
        ..write('<html><body>SEGRETO</body></html>')
        ..close();
    });
    // Un altro host che la guardia lascia aprire: la sua pagina non è del sito.
    final elsewhere = await HttpServer.bind(InternetAddress('127.0.0.3'), 0);
    addTearDown(() => elsewhere.close(force: true));
    elsewhere.listen((request) => request.response
      ..headers.contentType = ContentType.html
      ..write('<html><body>SEGRETO</body></html>')
      ..close());
    final evil = await HttpServer.bind(InternetAddress('127.0.0.2'), 0);
    addTearDown(() => evil.close(force: true));
    final secret = 'http://127.0.0.1:${internal.port}';
    evil.listen((request) {
      final to = {'/salto': '$secret/latest/meta-data/', '/altrove': 'http://127.0.0.3:${elsewhere.port}/'}[request.uri.path];
      if (to != null) {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, to)
          ..close();
        return;
      }
      request.response
        ..headers.contentType = ContentType.html
        ..write('<html><body><script>fetch("$secret/fetch", {mode: "no-cors"}).catch(() => {});'
            'setTimeout(() => { location = "$secret/js"; }, 500);</script></body></html>')
        ..close();
    });
    final browser = await newBrowser(const Duration(seconds: 6));
    const body = BrowserGate(hosts: ['127.0.0.2'], seriesReady: "!!document.body && document.body.innerText.includes('SEGRETO')", searchReady: 'true');
    for (final path in ['/salto', '/js', '/altrove']) {
      expect(await browser.seriesPage('http://127.0.0.2:${evil.port}$path', body), isNull, reason: logged.join('\n'));
    }
    expect(reached, isEmpty);
    expect(logged.join('\n'), contains('fuori dal sito'));
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));

  test('un websocket verso la rete interna non parte, uno verso il sito sì', () async {
    // CDP Fetch non vede i WebSocket: li ferma il proxy da cui passa Chromium.
    Future<(HttpServer, List<String>)> sockets(String host) async {
      final server = await HttpServer.bind(InternetAddress(host), 0);
      addTearDown(() => server.close(force: true));
      final reached = <String>[];
      server.listen((request) async {
        reached.add(request.uri.path);
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          (await WebSocketTransformer.upgrade(request)).add('ciao');
        } else {
          request.response
            ..headers.contentType = ContentType.html
            ..write('<html><body><script>'
                'const done = {};'
                'for (const [name, url] of [["interno", "ws://127.0.0.1:" + location.hash.slice(1) + "/ws"],'
                ' ["sito", "ws://127.0.0.2:" + location.port + "/ws"]]) {'
                ' const socket = new WebSocket(url);'
                ' socket.onmessage = () => { done[name] = "aperto"; };'
                ' socket.onerror = () => { done[name] = "chiuso"; };'
                '}'
                'window.outcome = done;'
                '</script></body></html>')
            ..close();
        }
      });
      return (server, reached);
    }

    final (internal, internalReached) = await sockets('127.0.0.1');
    final (page, pageReached) = await sockets('127.0.0.2');
    final browser = await newBrowser(const Duration(seconds: 20));
    const both = BrowserGate(
        hosts: ['127.0.0.2'],
        seriesReady: '!!window.outcome && Object.keys(window.outcome).length == 2',
        searchReady: 'true');
    final html = await browser.seriesPage('http://127.0.0.2:${page.port}/serie#${internal.port}', both);
    expect(html, isNotNull, reason: logged.join('\n'));
    expect(internalReached, isEmpty);
    expect(pageReached, contains('/ws'));
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));

  const gate = BrowserGate(hosts: ['127.0.0.2'], seriesReady: "!!document.getElementById('chaptersList')", searchReady: 'true');

  test('aspetta la pagina vera e la restituisce, senza dire che è senza schermo', () async {
    final browser = await newBrowser(const Duration(seconds: 60));
    final html = await browser.seriesPage('http://127.0.0.2:${site.port}/serie', gate);
    expect(html, contains('chaptersList'), reason: logged.join('\n'));
    expect(html, isNot(contains('HeadlessChrome')));
    expect(html, contains('Chrome/'));
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));

  test('il blocco lasciato dal contenitore di prima non ferma Chromium', () async {
    // Come dopo un aggiornamento: il profilo è bloccato a nome di una
    // macchina che non c'è più.
    final stale = await Directory.systemTemp.createTemp('kagami-browser-');
    await Link('${stale.path}/SingletonLock').create('98116193a76f-104169');
    await Link('${stale.path}/SingletonSocket').create('/tmp/org.chromium.Chromium.sparito/SingletonSocket');
    final browser = await newBrowser(const Duration(seconds: 60), stale);
    expect(await browser.seriesPage('http://127.0.0.2:${site.port}/serie', gate), contains('chaptersList'),
        reason: logged.join('\n'));
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));

  test('una verifica che non passa dà null', () async {
    final browser = await newBrowser(const Duration(seconds: 3));
    const never = BrowserGate(hosts: ['127.0.0.2'], seriesReady: 'false', searchReady: 'true');
    expect(await browser.seriesPage('http://127.0.0.2:${site.port}/serie', never), isNull);
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));

  test('pagina resa: il DOM costruito dal JavaScript, col tempo chiesto dal motore', () async {
    final browser = await newBrowser(const Duration(seconds: 60));
    final PageRenderer renderer = browser;
    final html = await renderer.render('http://127.0.0.2:${site.port}/serie',
        hosts: ['127.0.0.2'], ready: "!!document.querySelector(\"#chaptersList\")", timeout: const Duration(seconds: 30));
    expect(html, contains('id="chaptersList"'), reason: logged.join('\n'));
    final started = DateTime.now();
    expect(
        await renderer.render('http://127.0.0.2:${site.port}/serie',
            hosts: ['127.0.0.2'], ready: 'false', timeout: const Duration(seconds: 3)),
        isNull);
    expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 30)));
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));

  test('contenitore: il comando browser lancia Chromium con gli argomenti del locale e il proxy del server', () {
    final local = chromiumArguments('/data/browser', '127.0.0.1:4000');
    final container = chromiumArguments('/data/browser', 'kagami-server:9223');
    expect(container, containsAll(['--remote-debugging-port=0', '--proxy-server=http://kagami-server:9223',
        '--proxy-bypass-list=<-loopback>', '--user-data-dir=/data/browser', '--headless=new']));
    bool base(String a) => !a.startsWith('--proxy-server');
    expect(container.where(base), local.where(base));
    expect(devToolsEndpoint('DevTools listening on ws://127.0.0.1:41234/devtools/browser/abc'),
        'ws://127.0.0.1:41234/devtools/browser/abc');
  });

  test('contenitore: se il browser non risponde la pagina non si apre e non parte un Chromium locale', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    for (final host in ['127.0.0.1', 'kagami-browser.invalid']) {
      logged.clear();
      final browser = HeadlessBrowser.remote(host,
          debugPort: port, proxyPort: 0, guard: false, log: logged.add, timeout: const Duration(seconds: 5));
      addTearDown(browser.close);
      expect(await browser.seriesPage('http://127.0.0.2:9/serie', gate), isNull);
      expect(logged.join('\n'), contains('il contenitore del browser non risponde'), reason: host);
    }
  });

  test('contenitore: il server guida un Chromium lanciato come dal comando browser', () async {
    Future<int> free() async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      return port;
    }

    final proxyPort = await free();
    final profile = await Directory.systemTemp.createTemp('kagami-browser-');
    addTearDown(() => deleteProfile(profile));
    // Come `kagami-server browser`, ma sul loopback e su porte libere; DevTools
    // passa dall'inoltro, che ammette solo l'indirizzo del «server».
    final container = await BrowserContainer.start(chromium!, profile, '127.0.0.1:$proxyPort',
        address: InternetAddress.loopbackIPv4, port: 0, admit: GuardProxy.resolvedFrom('127.0.0.1'), log: logged.add);
    addTearDown(container.stop);
    final debugPort = container.port;
    final browser = HeadlessBrowser.remote('127.0.0.1',
        debugPort: debugPort,
        proxyPort: proxyPort,
        log: logged.add,
        guard: false,
        private: (address) => address.address == '127.0.0.1');
    addTearDown(browser.close);
    final html = await browser.seriesPage('http://127.0.0.2:${site.port}/serie', gate);
    expect(html, contains('chaptersList'), reason: logged.join('\n'));
    expect(logged.join('\n'), contains('(contenitore)'));
    await browser.close();
    expect(await container.exitCode.timeout(const Duration(seconds: 2), onTimeout: () => -1), -1,
        reason: 'chiudere il canale non spegne il Chromium del contenitore');
    expect(await container.stop(), isNot(-1));
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));

  test('contenitore: un client che chiude di colpo non fa cadere il comando browser', () async {
    final profile = await Directory.systemTemp.createTemp('kagami-browser-');
    addTearDown(() => deleteProfile(profile));
    final container = await BrowserContainer.start(chromium!, profile, '127.0.0.1:9',
        address: InternetAddress.loopbackIPv4, port: 0, admit: GuardProxy.resolvedFrom('127.0.0.1'), log: logged.add);
    addTearDown(container.stop);
    Future<String> version({bool abort = false}) async {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, container.port);
      socket.write('GET /json/${abort ? 'protocol' : 'version'} HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n');
      if (abort) {
        // Chiuso a metà di una risposta lunga: il kernel manda un reset, e
        // l'inoltro scrive ancora su un socket che non c'è più.
        await socket.first;
        // SO_LINGER a zero: la chiusura è un reset, subito.
        socket.setRawOption(RawSocketOption(RawSocketOption.levelSocket, 13, Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0])));
        socket.destroy();
        return '';
      }
      final text = StringBuffer();
      await for (final chunk in socket.timeout(const Duration(seconds: 10), onTimeout: (sink) => sink.close())) {
        text.write(utf8.decode(chunk, allowMalformed: true));
        if (text.toString().contains('"Browser"')) break;
      }
      socket.destroy();
      return '$text';
    }

    for (var i = 0; i < 20; i++) {
      await version(abort: true);
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await version(), contains('Browser'), reason: logged.join('\n'));
    expect(await container.exitCode.timeout(const Duration(milliseconds: 200), onTimeout: () => -1), -1);
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));
}

bool _onPath() => (Platform.environment['PATH'] ?? '').split(':').any((dir) =>
    dir.isNotEmpty &&
    const ['chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable']
        .any((name) => File('$dir/$name').existsSync()));
