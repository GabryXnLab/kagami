/// Chromium senza schermo, per i siti dietro la verifica del browser.
///
/// Il server non ha nessuno davanti che superi la verifica di Cloudflare, e
/// le richieste HTTP del motore non passano nemmeno con i cookie giusti: la
/// pagina di una serie la apre un Chromium vero, guidato col protocollo
/// DevTools su un WebSocket (`dart:io`, senza dipendenze), e si aspetta che i
/// segni della pagina vera (`BrowserGate.seriesReady`) compaiano. Passa la
/// verifica che si risolve da sola; quella che chiede di spuntare «Verify
/// you are human» qui non la spunta nessuno, di proposito, e capita
/// soprattutto dagli indirizzi dei data center: allora la pagina non
/// arriva, e la serie resta con il suo errore come prima.
///
/// Un Chromium solo per tutto il server, una pagina alla volta, acceso alla
/// prima richiesta e spento dopo qualche minuto senza: tiene centinaia di
/// megabyte. Il profilo sta fra i dati del server, così i cookie della
/// verifica superata valgono anche per il controllo del giorno dopo.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/providers.dart';

class HeadlessBrowser implements PageBrowser {
  HeadlessBrowser(
    this.executable,
    this.profile, {
    this.timeout = const Duration(seconds: 60),
    this.idle = const Duration(minutes: 5),
    this.log = _stderr,
  });

  /// Il Chromium da usare: `KAGAMI_CHROMIUM`, altrimenti il primo dei nomi
  /// soliti nel `PATH`; `null` se non ce n'è.
  static Future<String?> find() async {
    final chosen = Platform.environment['KAGAMI_CHROMIUM'];
    if (chosen != null && chosen.isNotEmpty) return await File(chosen).exists() ? chosen : null;
    for (final name in const ['chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable']) {
      for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
        if (dir.isEmpty) continue;
        final file = File('$dir/$name');
        if (await file.exists()) return file.path;
      }
    }
    return null;
  }

  final String executable;
  final Directory profile;
  final Duration timeout;
  final Duration idle;
  final void Function(String line) log;

  static void _stderr(String line) => stderr.writeln(line);

  _Chromium? _chromium;
  Future<void> _turn = Future.value();
  Timer? _sleep;

  @override
  Future<String?> seriesPage(String url, BrowserGate gate) {
    final result = _turn.then((_) => _open(url, gate));
    _turn = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<String?> _open(String url, BrowserGate gate) async {
    _sleep?.cancel();
    try {
      final chromium = _chromium ??= await _Chromium.launch(executable, profile, log);
      final html = await chromium.read(url, gate.seriesReady, timeout);
      if (html == null) log('Browser: la verifica di $url non è passata da sola.');
      return html;
    } on Object catch (error) {
      // Un Chromium caduto si riaccende alla richiesta seguente.
      log('Browser: $url non si è aperta ($error).');
      await close();
      return null;
    } finally {
      _sleep = Timer(idle, () => unawaited(close()));
    }
  }

  Future<void> close() async {
    _sleep?.cancel();
    final chromium = _chromium;
    _chromium = null;
    await chromium?.close();
  }
}

/// Un processo Chromium e il suo canale DevTools.
class _Chromium {
  _Chromium._(this._process, this._socket, this._userAgent) {
    _socket.listen(_receive, onDone: _fail, onError: (Object _) => _fail());
  }

  static Future<_Chromium> launch(String executable, Directory profile, void Function(String) log) async {
    await profile.create(recursive: true);
    final process = await Process.start(executable, [
      '--headless=new',
      // Dentro Docker, da utente normale, la sandbox di Chromium non ha i
      // namespace che le servono.
      '--no-sandbox',
      '--disable-gpu',
      '--disable-dev-shm-usage',
      '--disable-blink-features=AutomationControlled',
      '--no-first-run',
      '--no-default-browser-check',
      '--window-size=1280,2000',
      '--remote-debugging-port=0',
      '--user-data-dir=${profile.path}',
      'about:blank',
    ]);
    unawaited(process.stdout.drain<void>());
    final endpoint = Completer<String>();
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      final found = RegExp(r'DevTools listening on (ws://\S+)').firstMatch(line);
      if (found != null && !endpoint.isCompleted) endpoint.complete(found.group(1));
    });
    unawaited(process.exitCode.then((code) {
      if (!endpoint.isCompleted) endpoint.completeError(StateError('Chromium è uscito subito ($code)'));
    }));
    try {
      final socket = await WebSocket.connect(await endpoint.future.timeout(const Duration(seconds: 30)));
      final chromium = _Chromium._(process, socket, '');
      final version = await chromium._send('Browser.getVersion');
      // L'user agent di un Chromium senza schermo lo dice: è la prima cosa
      // che Cloudflare guarda.
      chromium._userAgent = '${version['userAgent']}'.replaceAll('HeadlessChrome', 'Chrome');
      log('Browser: ${version['product']}.');
      return chromium;
    } on Object {
      process.kill();
      rethrow;
    }
  }

  final Process _process;
  final WebSocket _socket;
  String _userAgent;
  int _next = 0;
  final Map<int, Completer<Map<String, Object?>>> _pending = {};

  void _receive(Object? message) {
    if (message is! String) return;
    final json = jsonDecode(message) as Map<String, Object?>;
    final id = json['id'];
    if (id is! int) return;
    final waiting = _pending.remove(id);
    if (waiting == null) return;
    final error = json['error'];
    if (error is Map) {
      waiting.completeError(StateError('${error['message']}'));
    } else {
      waiting.complete((json['result'] as Map<String, Object?>?) ?? const {});
    }
  }

  void _fail() {
    for (final waiting in _pending.values) {
      waiting.completeError(StateError('Chromium ha chiuso il canale.'));
    }
    _pending.clear();
  }

  Future<Map<String, Object?>> _send(String method, [Map<String, Object?> params = const {}, String? session]) {
    final id = ++_next;
    final waiting = _pending[id] = Completer<Map<String, Object?>>();
    _socket.add(jsonEncode({'id': id, 'method': method, 'params': params, 'sessionId': ?session}));
    return waiting.future.timeout(const Duration(seconds: 30));
  }

  Future<Object?> _evaluate(String expression, String session) async {
    final result = await _send('Runtime.evaluate', {'expression': expression, 'returnByValue': true}, session);
    return (result['result'] as Map?)?['value'];
  }

  /// Apre [url] in una scheda nuova e ne dà l'HTML appena [ready] è vero;
  /// `null` se entro [timeout] non lo diventa.
  Future<String?> read(String url, String ready, Duration timeout) async {
    final target = '${(await _send('Target.createTarget', {'url': 'about:blank'}))['targetId']}';
    try {
      final session = '${(await _send('Target.attachToTarget', {'targetId': target, 'flatten': true}))['sessionId']}';
      await _send('Network.setUserAgentOverride', {'userAgent': _userAgent}, session);
      await _send('Page.navigate', {'url': url}, session);
      final until = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        // A metà verifica la pagina si ricarica da sola e il contesto in cui
        // si valuta sparisce: si riprova al giro dopo.
        final Object? found;
        try {
          found = await _evaluate(ready, session);
        } on StateError {
          continue;
        }
        if (found == true) {
          final html = await _evaluate('document.documentElement.outerHTML', session);
          return html is String ? '<!DOCTYPE html>$html' : null;
        }
      }
      return null;
    } finally {
      await _send('Target.closeTarget', {'targetId': target}).catchError((Object _) => const <String, Object?>{});
    }
  }

  Future<void> close() async {
    await _socket.close().catchError((Object _) {});
    _process.kill();
    await _process.exitCode.timeout(const Duration(seconds: 10), onTimeout: () {
      _process.kill(ProcessSignal.sigkill);
      return -1;
    });
  }
}
