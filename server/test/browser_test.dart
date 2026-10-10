import 'dart:io';

import 'package:kagami_archive/providers.dart';
import 'package:kagami_server/src/browser.dart';
import 'package:test/test.dart';

void main() {
  // Dove Chromium non c'è (la CI senza browser) i test si saltano.
  final missing = Platform.environment['KAGAMI_CHROMIUM'] == null && !_onPath() ? 'Chromium non c\'è' : false;
  late HttpServer site;
  late Directory profile;
  String? chromium;

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
    profile = await Directory.systemTemp.createTemp('kagami-browser-');
  });

  tearDownAll(() async {
    await site.close(force: true);
    await profile.delete(recursive: true);
  });

  const gate = BrowserGate(hosts: ['127.0.0.1'], seriesReady: "!!document.getElementById('chaptersList')", searchReady: 'true');

  test('aspetta la pagina vera e la restituisce, senza dire che è senza schermo', () async {
    final browser = HeadlessBrowser(chromium!, profile, timeout: const Duration(seconds: 20), log: (_) {});
    addTearDown(browser.close);
    final html = await browser.seriesPage('http://127.0.0.1:${site.port}/serie', gate);
    expect(html, contains('chaptersList'));
    expect(html, isNot(contains('HeadlessChrome')));
    expect(html, contains('Chrome/'));
  }, skip: missing, timeout: const Timeout(Duration(minutes: 2)));

  test('una verifica che non passa dà null', () async {
    final browser = HeadlessBrowser(chromium!, profile, timeout: const Duration(seconds: 3), log: (_) {});
    addTearDown(browser.close);
    const never = BrowserGate(hosts: ['127.0.0.1'], seriesReady: 'false', searchReady: 'true');
    expect(await browser.seriesPage('http://127.0.0.1:${site.port}/serie', never), isNull);
  }, skip: missing, timeout: const Timeout(Duration(minutes: 2)));
}

bool _onPath() => (Platform.environment['PATH'] ?? '').split(':').any((dir) =>
    dir.isNotEmpty &&
    const ['chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable']
        .any((name) => File('$dir/$name').existsSync()));
