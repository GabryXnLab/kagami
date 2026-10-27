import 'dart:io';

import 'package:kagami_archive/providers.dart';
import 'package:kagami_server/src/browser.dart';
import 'package:test/test.dart';

void main() {
  // Dove Chromium non c'è (la CI senza browser) i test si saltano.
  final missing = Platform.environment['KAGAMI_CHROMIUM'] == null && !_onPath() ? 'Chromium non c\'è' : false;
  late HttpServer site;
  String? chromium;
  final logged = <String>[];

  // Ogni test ha il suo profilo e il suo Chromium: nessun blocco o processo
  // di un test può toccare il seguente. Il log resta per dire, a un fallimento,
  // cosa ha visto il browser.
  Future<HeadlessBrowser> newBrowser(Duration timeout, [Directory? dir]) async {
    final profile = dir ?? await Directory.systemTemp.createTemp('kagami-browser-');
    addTearDown(() => _deleteProfileEventually(profile));
    final browser = HeadlessBrowser(chromium!, profile, timeout: timeout, log: logged.add);
    addTearDown(browser.close);
    return browser;
  }

  setUp(logged.clear);

  setUpAll(() async {
    chromium = await HeadlessBrowser.find();
    // Una «verifica» che lascia il posto alla pagina vera dopo un po', come
    // quella di Cloudflare, e l'user agent con cui la si è chiesta.
    site = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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

  const gate = BrowserGate(hosts: ['127.0.0.1'], seriesReady: "!!document.getElementById('chaptersList')", searchReady: 'true');

  test('aspetta la pagina vera e la restituisce, senza dire che è senza schermo', () async {
    final browser = await newBrowser(const Duration(seconds: 60));
    final html = await browser.seriesPage('http://127.0.0.1:${site.port}/serie', gate);
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
    expect(await browser.seriesPage('http://127.0.0.1:${site.port}/serie', gate), contains('chaptersList'),
        reason: logged.join('\n'));
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));

  test('una verifica che non passa dà null', () async {
    final browser = await newBrowser(const Duration(seconds: 3));
    const never = BrowserGate(hosts: ['127.0.0.1'], seriesReady: 'false', searchReady: 'true');
    expect(await browser.seriesPage('http://127.0.0.1:${site.port}/serie', never), isNull);
  }, skip: missing, timeout: const Timeout(Duration(minutes: 4)));
}

bool _onPath() => (Platform.environment['PATH'] ?? '').split(':').any((dir) =>
    dir.isNotEmpty &&
    const ['chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable']
        .any((name) => File('$dir/$name').existsSync()));

Future<void> _deleteProfileEventually(Directory profile) async {
  for (var attempt = 0; attempt < 6; attempt++) {
    try {
      if (await profile.exists()) await profile.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 5) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
    }
  }
}
