/// Il browser invisibile dell'app, per piattaforma: le pagine dietro la
/// verifica del sito ([PageBrowser]) e quelle che il sito vuole rese
/// ([PageRenderer], `browser.pages` di `docs/siti.md`), con lo stesso
/// contratto su Android, iOS e macOS.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/renderer.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Un browser che fa tutte e due le cose, come quello del server.
abstract interface class AppPageBrowser implements PageBrowser, PageRenderer {}

/// Il browser di [platform] (quella su cui gira l'app, se manca): il Kotlin su
/// Android, la WKWebView di `webview_flutter` su iOS e macOS; `null` su Linux e
/// Windows, dove `webview_flutter` non c'è e le pagine rese falliscono con
/// `RendererMissing`.
AppPageBrowser? platformPageBrowser([TargetPlatform? platform]) => switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.android => const NativePageBrowser(),
      TargetPlatform.iOS || TargetPlatform.macOS => const WebViewPageBrowser(),
      _ => null,
    };

/// Una WebView invisibile e grande quanto lo schermo, dal Kotlin
/// (`PageBrowser.kt`): c'è anche ad app chiusa, dove una WebView di Flutter
/// non si può aprire. I cookie sono quelli di tutte le WebView dell'app, quindi
/// una verifica superata a mano vale anche qui finché Cloudflare la tiene.
/// È anche il [PageRenderer] del telefono (`browser.pages` dei siti): il
/// Kotlin dà `outerHTML` appena l'espressione del motore è vera.
class NativePageBrowser implements AppPageBrowser {
  const NativePageBrowser();

  static const MethodChannel _channel = MethodChannel('kagami/page-browser');

  @override
  Future<String?> seriesPage(String url, BrowserGate gate) =>
      _open(url, gate.hosts, gate.seriesReady, const Duration(seconds: 45));

  @override
  Future<String?> render(String url, {required List<String> hosts, required String ready, required Duration timeout}) =>
      _open(url, hosts, ready, timeout);

  Future<String?> _open(String url, List<String> hosts, String ready, Duration timeout) async {
    // Prima del canale lo stesso controllo che il Kotlin rifà a ogni redirect.
    if (!pageHostAllowed(url, hosts)) return null;
    try {
      return await _channel.invokeMethod<String>('seriesPage', {
        'url': url,
        'hosts': hosts,
        'ready': ready,
        'timeoutMs': timeout.inMilliseconds,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Lo stesso browser di [NativePageBrowser] dove il Kotlin non c'è: una
/// `WebViewController` di `webview_flutter` senza widget (su iOS e macOS la
/// WKWebView nasce col controller e carica anche fuori da una finestra).
/// Stesso contratto di `PageBrowser.kt`: solo `https` su un host dichiarato,
/// un redirect della pagina altrove la fa finire con `null`, l'espressione
/// del motore si prova ogni [poll] fino a [timeout], e la pagina letta si
/// ricontrolla sull'indirizzo finale. I cookie sono quelli di
/// `BrowserCheckPage`, la verifica passata a mano vale anche qui.
class WebViewPageBrowser implements AppPageBrowser {
  const WebViewPageBrowser({this.poll = const Duration(seconds: 1)});

  final Duration poll;

  @override
  Future<String?> seriesPage(String url, BrowserGate gate) =>
      _open(url, gate.hosts, gate.seriesReady, const Duration(seconds: 45));

  @override
  Future<String?> render(String url, {required List<String> hosts, required String ready, required Duration timeout}) =>
      _open(url, hosts, ready, timeout);

  Future<String?> _open(String url, List<String> hosts, String ready, Duration timeout) async {
    if (!pageHostAllowed(url, hosts)) return null;
    final lower = [for (final host in hosts) host.toLowerCase()];
    var blocked = false;
    var done = false;
    final WebViewController view;
    try {
      view = WebViewController();
      await view.setJavaScriptMode(JavaScriptMode.unrestricted);
      await view.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          // La pagina vuota con cui la si spegne, a lettura finita.
          if (done && request.url == 'about:blank') return NavigationDecision.navigate;
          if (pageHostAllowed(request.url, lower)) return NavigationDecision.navigate;
          if (request.isMainFrame) blocked = true;
          return NavigationDecision.prevent;
        },
      ));
      await view.loadRequest(Uri.parse(url));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
    final deadline = DateTime.now().add(timeout);
    String? html;
    try {
      while (!blocked && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(poll);
        if (blocked) break;
        if (!_isTrue(await _evaluate(view, ready))) continue;
        final page = _string(await _evaluate(view, 'document.documentElement.outerHTML'));
        if (page != null) html = '<!DOCTYPE html>$page';
        break;
      }
      // Ricontrollo finale: la pagina letta dev'essere su un host dichiarato.
      if (blocked || !pageHostAllowed(await view.currentUrl() ?? '', lower)) html = null;
    } on PlatformException {
      html = null;
    } finally {
      done = true;
      unawaited(view.loadHtmlString('<html></html>').catchError((Object _) {}));
    }
    return html;
  }

  /// Il valore dell'espressione, `null` se la pagina non è ancora valutabile
  /// (sta caricando, o il risultato è `undefined`).
  static Future<Object?> _evaluate(WebViewController view, String script) async {
    try {
      return await view.runJavaScriptReturningResult(script);
    } on PlatformException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  // WKWebView dà un booleano o un NSNumber; Android `true` già decodificato.
  static bool _isTrue(Object? value) => value == true || value == 1 || value == 'true';

  // Android dà le stringhe in JSON, WKWebView così come sono.
  static String? _string(Object? value) {
    if (value is! String) return null;
    if (!value.startsWith('"')) return value;
    try {
      final decoded = jsonDecode(value);
      return decoded is String ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

/// La regola dell'host della pagina resa: `https` e un host dichiarato dal
/// sito, uguale e senza credenziali. `PageBrowser.kt` la ripete (`hostAllowed`)
/// a ogni redirect della WebView e sulla pagina finale: se la cambi qui,
/// cambia anche là (`test/rendered_page_test.dart`).
bool pageHostAllowed(String url, List<String> hosts) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return false;
  return hosts.contains(uri.host.toLowerCase());
}
