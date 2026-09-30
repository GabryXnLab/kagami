/// La pagina di un sito dietro Cloudflare, aperta in una WebView perché la
/// verifica la superi chi usa il telefono.
///
/// Sul server lo fa Chromium con Scrapling; sul telefono c'è già un browser,
/// e una verifica che chiede un tocco la può fare solo una persona. Appena
/// la pagina mostra ciò che si aspettava — l'elenco dei capitoli, o la
/// ricerca del sito — l'app se la prende, con lo user agent e i cookie della
/// WebView perché le richieste seguenti passano solo con quelli, e torna
/// indietro da sola.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import '../l10n.dart';
import 'theme.dart';

class BrowserPass {
  const BrowserPass({required this.html, required this.userAgent, required this.cookies});

  final Uint8List html;
  final String userAgent;

  /// Il cookie da mandare, per host.
  final Map<String, String> cookies;
}

/// Oltre, non è la pagina di una serie.
const int _maxHtml = 8000000;

/// Il segno che la verifica è passata sulla pagina di una serie: c'è l'elenco
/// dei capitoli, nelle forme che il provider sa leggere.
const String _chapters =
    "!!document.querySelector('#chaptersList, #groupChapterList, .chapters-list, li.wp-manga-chapter')";

/// Che cosa l'utente vedrà comparire a verifica superata.
enum BrowserWaiting { chapters, search }

class BrowserCheckPage extends StatefulWidget {
  const BrowserCheckPage({
    required this.url,
    required this.hosts,
    this.ready = _chapters,
    this.waitingFor = BrowserWaiting.chapters,
    super.key,
  });

  final String url;

  /// Gli host di cui portarsi dietro i cookie.
  final List<String> hosts;

  /// Il JavaScript che dice se la pagina vera è arrivata.
  final String ready;

  /// Che cosa l'utente vedrà comparire a verifica superata.
  final BrowserWaiting waitingFor;

  static Future<BrowserPass?> open(
    BuildContext context,
    String url,
    List<String> hosts, {
    String ready = _chapters,
    BrowserWaiting waitingFor = BrowserWaiting.chapters,
  }) =>
      Navigator.of(context).push<BrowserPass>(
        MaterialPageRoute(
          builder: (_) => BrowserCheckPage(
            url: url,
            hosts: hosts,
            ready: ready,
            waitingFor: waitingFor,
          ),
        ),
      );

  @override
  State<BrowserCheckPage> createState() => _BrowserCheckPageState();
}

class _BrowserCheckPageState extends State<BrowserCheckPage> {
  static const MethodChannel _cookies = MethodChannel('kagami/archive');

  WebViewController? _controller;
  Timer? _poll;
  bool _taking = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onPageFinished: (_) => unawaited(_probe()),
      ))
      ..loadRequest(Uri.parse(widget.url));
    // La verifica spesso si risolve da sola e ricarica la pagina senza
    // passare da una navigazione nuova: si guarda anche a intervalli.
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => unawaited(_probe()));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  static Object? _value(Object? raw) {
    // Android restituisce i risultati come JSON: una stringa arriva tra
    // virgolette, un booleano come «true».
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } on FormatException {
        return raw;
      }
    }
    return raw;
  }

  Future<void> _probe() async {
    final controller = _controller;
    if (controller == null || _taking || !mounted) return;
    // Timer e fine pagina chiamano insieme: il segno va messo prima del primo
    // await, o due controlli vedono la pagina pronta e chiudono due schermate.
    _taking = true;
    var taken = false;
    try {
      if (_value(await controller.runJavaScriptReturningResult(widget.ready)) != true) return;
      final html = _value(await controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      ));
      final agent = _value(await controller.runJavaScriptReturningResult('navigator.userAgent'));
      if (html is! String || agent is! String) return;
      final bytes = utf8.encode(html);
      if (bytes.length > _maxHtml) return;
      final cookies = <String, String>{};
      for (final host in widget.hosts) {
        final cookie = await _cookies.invokeMethod<String>('cookies', {'url': 'https://$host/'});
        if (cookie != null && cookie.isNotEmpty) cookies[host] = cookie;
      }
      _poll?.cancel();
      if (mounted) {
        taken = true;
        Navigator.of(context).pop(BrowserPass(html: bytes, userAgent: agent, cookies: cookies));
      }
    } on PlatformException {
      // Si riprova al giro seguente.
    } finally {
      if (!taken) _taking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.browserTitle),
        bottom: _progress > 0 && _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100, minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Text(
              controller == null
                  ? l10n.browserPhoneOnly
                  : switch (widget.waitingFor) {
                      BrowserWaiting.chapters => l10n.browserInstructionsChapters,
                      BrowserWaiting.search => l10n.browserInstructionsSearch,
                    },
              style: KagamiType.body(13, height: 1.45, color: context.tokens.muted),
            ),
          ),
          if (controller != null) Expanded(child: WebViewWidget(controller: controller)),
        ],
      ),
    );
  }
}

/// Una WebView che non si vede, per i siti che rispondono solo a un browser
/// vero: Cloudflare non lascia passare `SiteHttp` nemmeno con i cookie della
/// verifica, mentre una pagina aperta da una WebView passa. I cookie delle
/// WebView sono gli stessi per tutta l'app, quindi una verifica fatta in
/// [BrowserCheckPage] vale anche qui.
///
/// Sa fare solo [get], navigando: una richiesta nuova ferma quella prima,
/// come succede scrivendo nella barra di ricerca. Deve stare nell'albero
/// ([view]) perché Android la faccia girare.
class BrowserFetcher implements ProviderHttp {
  BrowserFetcher({required this.ready});

  /// Il JavaScript che dice che la pagina vera, non la verifica, è arrivata.
  final String ready;

  WebViewController? _controller;
  int _generation = 0;

  static bool get available => Platform.isAndroid;

  WebViewController get _web =>
      _controller ??= WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);

  /// La WebView da mettere nella schermata, sotto a un contenuto opaco: la
  /// verifica di Cloudflare si risolve da sola solo in una pagina grande
  /// quanto quella di un browser, non in una di un pixel.
  Widget view() => IgnorePointer(
        child: ExcludeSemantics(child: WebViewWidget(controller: _web)),
      );

  Future<Object?> _run(String script) async {
    try {
      return _BrowserCheckPageState._value(await _web.runJavaScriptReturningResult(script));
    } on PlatformException {
      // La pagina sta ancora cambiando.
      return null;
    }
  }

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (!available) throw ProviderError(currentL10n().browserSearchPhoneOnly);
    final mine = ++_generation;
    // Il segno resta sulla pagina vecchia: finché c'è, la nuova non è arrivata.
    await _run('window.kagamiOld = true');
    await _web.loadRequest(Uri.parse(url));
    // Una verifica che si risolve da sola ci mette qualche secondo; una che
    // chiede un tocco non si risolve qui.
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mine != _generation) throw ProviderError(currentL10n().browserSearchSuperseded);
      if (await _run("!window.kagamiOld && document.readyState != 'loading' && ($ready)") != true) {
        continue;
      }
      final html = await _run('document.documentElement.outerHTML');
      if (html is! String) continue;
      final body = utf8.encode(html);
      if (body.length > limit) throw ProviderError(currentL10n().browserResponseTooLarge);
      return (body: body, contentType: 'text/html');
    }
    if (await _run('!!window._cf_chl_opt') == true) throw const CloudflareChallenge();
    throw const ProviderOffline();
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> json(String url) => throw UnimplementedError();
}
