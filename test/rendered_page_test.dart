import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/archive/page_browser.dart';
import 'package:kagami_archive/providers.dart' show BrowserGate;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// La stessa regola sta in `PageBrowser.kt` (`hostAllowed`), che la applica a
// ogni redirect della WebView: i casi qui sono quelli che il Kotlin deve rifiutare.
// Su iOS e macOS la ripete `WebViewPageBrowser`, provato con una WebView finta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const hosts = ['site.example', 'www.site.example'];

  test('redirect: un host non dichiarato o uno schema diverso da https si rifiuta', () {
    expect(pageHostAllowed('https://site.example/series/1', hosts), isTrue);
    expect(pageHostAllowed('https://WWW.Site.Example/x', hosts), isTrue);
    expect(pageHostAllowed('https://evil.example/series/1', hosts), isFalse);
    expect(pageHostAllowed('https://cdn.site.example/x', hosts), isFalse);
    expect(pageHostAllowed('https://site.example.evil.example/', hosts), isFalse);
    expect(pageHostAllowed('https://site.example@evil.example/', hosts), isFalse);
    expect(pageHostAllowed('https://evil.example@site.example/', hosts), isFalse);
    expect(pageHostAllowed('http://site.example/', hosts), isFalse);
    expect(pageHostAllowed('file:///data/data/app/x', hosts), isFalse);
    expect(pageHostAllowed('intent://site.example/#Intent;end', hosts), isFalse);
    expect(pageHostAllowed('not a url', hosts), isFalse);
    expect(pageHostAllowed('https://site.example/', const []), isFalse);
  });

  test('redirect: gli host del sito arrivano al Kotlin e una pagina fuori host non lo raggiunge', () async {
    final calls = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('kagami/page-browser'),
      (call) async {
        calls.add(call.arguments as Map<Object?, Object?>);
        return '<html></html>';
      },
    );
    const browser = NativePageBrowser();
    const timeout = Duration(seconds: 5);
    expect(await browser.render('https://evil.example/a', hosts: hosts, ready: 'true', timeout: timeout), isNull);
    expect(calls, isEmpty);
    expect(await browser.render('https://site.example/a', hosts: hosts, ready: 'true', timeout: timeout), '<html></html>');
    expect(calls.single['hosts'], hosts);
  });

  group('ios desktop', () {
    late _FakeWebViews web;
    setUp(() => WebViewPlatform.instance = web = _FakeWebViews());
    const browser = WebViewPageBrowser(poll: Duration(milliseconds: 1));
    const timeout = Duration(seconds: 2);

    test('ogni piattaforma ha il suo browser, Linux e Windows nessuno', () {
      expect(platformPageBrowser(TargetPlatform.android), isA<NativePageBrowser>());
      expect(platformPageBrowser(TargetPlatform.iOS), isA<WebViewPageBrowser>());
      expect(platformPageBrowser(TargetPlatform.macOS), isA<WebViewPageBrowser>());
      expect(platformPageBrowser(TargetPlatform.linux), isNull);
      expect(platformPageBrowser(TargetPlatform.windows), isNull);
    });

    test('la pagina torna appena l\'espressione del motore è vera', () async {
      web.readyAfter = 3;
      expect(await browser.render('https://site.example/a', hosts: hosts, ready: 'READY', timeout: timeout),
          '<!DOCTYPE html><html>site.example/a</html>');
      expect(web.view!.scripts.where((script) => script == 'READY'), hasLength(3));
      expect(web.view!.javaScript, JavaScriptMode.unrestricted);
      // Finita la lettura, la WebView si spegne su una pagina vuota (senza attenderla).
      await Future<void>.delayed(Duration.zero);
      expect(web.view!.blanked, isTrue);
    });

    test('le stringhe in JSON di Android si decodificano', () async {
      web.json = true;
      expect(await browser.render('https://site.example/a', hosts: hosts, ready: 'READY', timeout: timeout),
          '<!DOCTYPE html><html>site.example/a</html>');
    });

    test('un indirizzo fuori host non apre nessuna WebView', () async {
      expect(await browser.render('https://evil.example/a', hosts: hosts, ready: 'READY', timeout: timeout), isNull);
      expect(await browser.render('http://site.example/a', hosts: hosts, ready: 'READY', timeout: timeout), isNull);
      expect(web.view, isNull);
    });

    test('un redirect della pagina fuori host la fa finire con null', () async {
      web.redirects = ['https://www.site.example/b', 'https://evil.example/c'];
      expect(await browser.render('https://site.example/a', hosts: hosts, ready: 'READY', timeout: timeout), isNull);
      expect(web.view!.decisions, [NavigationDecision.navigate, NavigationDecision.navigate, NavigationDecision.prevent]);
      expect(web.view!.url, 'https://www.site.example/b');
    });

    test('un iframe fuori host si ferma ma la pagina resta', () async {
      web.frames = ['https://ads.example/x'];
      expect(await browser.render('https://site.example/a', hosts: hosts, ready: 'READY', timeout: timeout),
          '<!DOCTYPE html><html>site.example/a</html>');
      expect(web.view!.decisions.last, NavigationDecision.prevent);
    });

    test('la pagina finita altrove senza passare dal delegato si scarta', () async {
      web.landOn = 'https://evil.example/z';
      expect(await browser.render('https://site.example/a', hosts: hosts, ready: 'READY', timeout: timeout), isNull);
    });

    test('la pagina mai pronta finisce con null entro il tempo', () async {
      web.readyAfter = 1 << 30;
      final start = DateTime.now();
      expect(
          await browser.render('https://site.example/a',
              hosts: hosts, ready: 'READY', timeout: const Duration(milliseconds: 50)),
          isNull);
      expect(DateTime.now().difference(start), lessThan(const Duration(seconds: 2)));
    });

    test('la pagina dietro la verifica passa dallo stesso browser', () async {
      final html = await browser.seriesPage(
          'https://site.example/s', const BrowserGate(hosts: hosts, seriesReady: 'SERIES', searchReady: 'SEARCH'));
      expect(html, '<!DOCTYPE html><html>site.example/s</html>');
      expect(web.view!.scripts.first, 'SERIES');
    });
  });
}

/// Una WebView finta: la navigazione passa dal delegato come su iOS, dove
/// ogni redirect chiede `decidePolicyForNavigationAction`.
class _FakeWebViews extends WebViewPlatform {
  _FakeView? view;
  int readyAfter = 1;
  bool json = false;
  List<String> redirects = const [];
  List<String> frames = const [];
  String? landOn;

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) =>
      view = _FakeView(this, params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      _FakeDelegate(params);
}

class _FakeDelegate extends PlatformNavigationDelegate {
  _FakeDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onRequest;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async =>
      onRequest = onNavigationRequest;
}

class _FakeView extends PlatformWebViewController {
  _FakeView(this.web, super.params) : super.implementation();

  final _FakeWebViews web;
  _FakeDelegate? delegate;
  JavaScriptMode? javaScript;
  String? url;
  bool blanked = false;
  final decisions = <NavigationDecision>[];
  final scripts = <String>[];

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async => javaScript = javaScriptMode;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async =>
      delegate = handler as _FakeDelegate;

  Future<bool> _ask(String target, {bool main = true}) async {
    final decision = await delegate!.onRequest!(NavigationRequest(url: target, isMainFrame: main));
    decisions.add(decision);
    return decision == NavigationDecision.navigate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    for (final target in [params.uri.toString(), ...web.redirects]) {
      if (!await _ask(target)) return;
      url = target;
    }
    for (final frame in web.frames) {
      await _ask(frame, main: false);
    }
    if (web.landOn != null) url = web.landOn;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    final decision = await delegate!.onRequest!(const NavigationRequest(url: 'about:blank', isMainFrame: true));
    blanked = decision == NavigationDecision.navigate;
  }

  @override
  Future<String?> currentUrl() async => url;

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    if (javaScript == 'document.documentElement.outerHTML') {
      final html = '<html>${Uri.parse(url!).host}${Uri.parse(url!).path}</html>';
      return web.json ? jsonEncode(html) : html;
    }
    scripts.add(javaScript);
    return scripts.length >= web.readyAfter;
  }
}
