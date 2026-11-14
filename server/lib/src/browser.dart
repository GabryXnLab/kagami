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
///
/// Ogni richiesta di Chromium (pagina, reindirizzamenti, script, worker)
/// passa dal server prima di partire (`Fetch` di DevTools sul browser intero):
/// un host che risolve in un indirizzo privato non si apre, e con la guardia
/// accesa nemmeno ciò che non è `https`. La pagina torna solo se è finita su
/// un host del sito. I WebSocket, che `Fetch` non vede, li ferma il proxy da
/// cui passa ogni connessione di Chromium (`browser_proxy.dart`).
///
/// Con `KAGAMI_BROWSER` Chromium gira nel contenitore `kagami-browser`
/// (`kagami-server browser`, `browser_container.dart`), senza il volume dei dati: un
/// renderer compromesso, senza sandbox, non trova `drive.json`. Il server lo
/// guida da lontano ([HeadlessBrowser.remote]) e gli fa da unico proxy verso
/// internet; se il contenitore non risponde la pagina non si apre, e non si
/// ripiega mai sul Chromium locale.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/http.dart' show AddressLookup, isPrivateAddress;
import 'package:kagami_archive/providers.dart';

import 'browser_container.dart' show browserDebugPort, browserProxyPort;
import 'browser_proxy.dart';

/// Gli argomenti di Chromium, uguali per il locale e per il contenitore:
/// [proxy] è l'`host:porta` del proxy del server. DevTools ascolta solo sul
/// loopback, su una porta libera scritta sullo standard error: Chromium 157
/// ignora `--remote-debugging-address` (misurato), e verso la rete del
/// contenitore la apre `BrowserContainer`.
List<String> chromiumArguments(String profile, String proxy) => [
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
      '--user-data-dir=$profile',
      // Ogni connessione, WebSocket compresi, passa dal proxy che controlla
      // l'indirizzo; `<-loopback>` toglie l'eccezione di Chromium per il loopback.
      '--proxy-server=http://$proxy',
      '--proxy-bypass-list=<-loopback>',
      'about:blank',
    ];

/// L'indirizzo DevTools che Chromium scrive sullo standard error appena
/// pronto, o `null` se [line] non lo è.
String? devToolsEndpoint(String line) => RegExp(r'DevTools listening on (ws://\S+)').firstMatch(line)?.group(1);

/// Toglie i blocchi del profilo. Portano il nome della macchina: il
/// contenitore ricreato ha un nome nuovo, e Chromium crede il profilo in uso
/// altrove e se ne va (21). Il profilo è solo di un processo, uno alla volta.
Future<void> clearProfileLocks(Directory profile) async {
  await profile.create(recursive: true);
  for (final name in const ['SingletonLock', 'SingletonCookie', 'SingletonSocket']) {
    try {
      await Link('${profile.path}/$name').delete();
    } on FileSystemException {
      // Non c'era.
    }
  }
}

class HeadlessBrowser implements PageBrowser {
  HeadlessBrowser(
    String this.executable,
    Directory this.profile, {
    this.timeout = const Duration(seconds: 60),
    this.idle = const Duration(minutes: 5),
    this.log = _stderr,
    AddressLookup? lookup,
    this.guard = true,
    this.private = isPrivateAddress,
  })  : remote = null,
        debugPort = 0,
        proxyPort = 0,
        lookup = lookup ?? InternetAddress.lookup;

  /// Chromium nel contenitore [remote] (`KAGAMI_BROWSER`): DevTools su
  /// [debugPort], e il proxy del server su tutte le interfacce, porta
  /// [proxyPort], aperto solo a quel contenitore.
  HeadlessBrowser.remote(
    String this.remote, {
    this.debugPort = browserDebugPort,
    this.proxyPort = browserProxyPort,
    this.timeout = const Duration(seconds: 60),
    this.idle = const Duration(minutes: 5),
    this.log = _stderr,
    AddressLookup? lookup,
    this.guard = true,
    this.private = isPrivateAddress,
  })  : executable = null,
        profile = null,
        lookup = lookup ?? InternetAddress.lookup;

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

  final String? executable;
  final Directory? profile;

  /// Il nome del contenitore del browser; `null` per il Chromium locale.
  final String? remote;
  final int debugPort;
  final int proxyPort;
  final Duration timeout;
  final Duration idle;
  final void Function(String line) log;
  final AddressLookup lookup;

  /// Spento solo dai test, che servono il sito in chiaro sul loopback.
  final bool guard;

  /// Gli indirizzi che Chromium non apre mai: i test vi mettono solo
  /// 127.0.0.1, la loro «rete interna».
  final bool Function(InternetAddress address) private;

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

  /// Perché [url] non si apre, o `null`: solo `https` su un host del sito,
  /// che non risolve in un indirizzo privato.
  Future<String?> _refused(String url, BrowserGate gate) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.hasPort || uri.userInfo.isNotEmpty) return 'non è https';
    if (!gate.hosts.contains(uri.host)) return 'host fuori dal sito';
    return _unreachable(uri.host);
  }

  /// Perché Chromium non deve chiedere [url], o `null`. Vale per ogni
  /// richiesta della pagina, reindirizzamenti compresi: è ciò che impedisce a
  /// un sito di portare il server sui metadati della macchina o sul router.
  /// Con la guardia solo `https`, così un nome che fra questa risoluzione e
  /// quella di Chromium cambia indirizzo (DNS rebinding) trova un certificato
  /// che non è il suo.
  Future<String?> _forbidden(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || (!guard && uri.scheme == 'http'))) return 'schema non ammesso';
    return _unreachable(uri.host);
  }

  Future<String?> _unreachable(String host) async => (await _reach(host)).refused;

  /// L'indirizzo a cui collegarsi per [host], o perché non ce n'è.
  Future<({InternetAddress? address, String? refused})> _reach(String host) async {
    final literal = InternetAddress.tryParse(host.startsWith('[') ? host.substring(1, host.length - 1) : host);
    try {
      final addresses = literal != null ? [literal] : await lookup(host).timeout(const Duration(seconds: 30));
      if (addresses.isEmpty || addresses.any(private)) return (address: null, refused: 'l\'host risolve in un indirizzo privato');
      return (address: addresses.first, refused: null);
    } on Exception {
      return (address: null, refused: 'l\'host non si risolve');
    }
  }

  Future<String?> _open(String url, BrowserGate gate) async {
    final refused = guard ? await _refused(url, gate) : null;
    if (refused != null) {
      log('Browser: $url rifiutata ($refused).');
      return null;
    }
    _sleep?.cancel();
    var connecting = _chromium == null;
    try {
      final chromium = _chromium ??= await _start();
      connecting = false;
      final page = await chromium.read(url, gate.seriesReady, timeout);
      if (page == null) {
        log('Browser: la verifica di $url non è passata da sola.');
        return null;
      }
      // Un reindirizzamento può finire su un altro host pubblico: la sua
      // pagina non è del sito, e non va nell'archivio.
      final landed = Uri.tryParse(page.url);
      if (landed == null || !gate.hosts.contains(landed.host) || (guard && landed.scheme != 'https')) {
        log('Browser: $url è finita fuori dal sito (${page.url}).');
        return null;
      }
      return page.html;
    } on Object catch (error) {
      // Un Chromium caduto si riaccende alla richiesta seguente.
      log(connecting && remote != null
          ? 'Browser: il contenitore del browser non risponde ($remote: $error); $url non si apre.'
          : 'Browser: $url non si è aperta ($error).');
      await close();
      return null;
    } finally {
      _sleep = Timer(idle, () => unawaited(close()));
    }
  }

  Future<_Chromium> _start() {
    Future<GuardProxy> proxy({InternetAddress? address, int port = 0, ProxyAdmission? admit}) =>
        GuardProxy.start((host) async => (await _reach(host)).address,
            plain: !guard, log: log, address: address, port: port, admit: admit);
    final remote = this.remote;
    if (remote == null) return _Chromium.launch(executable!, profile!, log, _screen, proxy);
    return _Chromium.connect(remote, debugPort, log, _screen,
        () => proxy(address: InternetAddress.anyIPv4, port: proxyPort, admit: GuardProxy.resolvedFrom(remote)));
  }

  Future<bool> _screen(String url) async {
    final forbidden = await _forbidden(url);
    if (forbidden != null) log('Browser: richiesta a $url bloccata ($forbidden).');
    return forbidden == null;
  }

  Future<void> close() async {
    _sleep?.cancel();
    final chromium = _chromium;
    _chromium = null;
    await chromium?.close();
  }
}

/// Il canale DevTools di un Chromium: un processo di questo server o, con
/// [_process] `null`, quello del contenitore del browser.
class _Chromium {
  _Chromium._(this._process, this._socket, this._userAgent, this._screen, this._proxy) {
    _socket.listen(_receive, onDone: _fail, onError: (Object _) => _fail());
  }

  static Future<_Chromium> launch(String executable, Directory profile, void Function(String) log,
      Future<bool> Function(String url) screen, Future<GuardProxy> Function() guardProxy) async {
    await clearProfileLocks(profile);
    final proxy = await guardProxy();
    final Process process;
    try {
      process = await Process.start(executable, chromiumArguments(profile.path, '127.0.0.1:${proxy.port}'));
    } on Object {
      await proxy.close();
      rethrow;
    }
    unawaited(process.stdout.drain<void>());
    final endpoint = Completer<String>();
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      final found = devToolsEndpoint(line);
      if (found != null && !endpoint.isCompleted) endpoint.complete(found);
    });
    unawaited(process.exitCode.then((code) {
      if (!endpoint.isCompleted) endpoint.completeError(StateError('Chromium è uscito subito ($code)'));
    }));
    try {
      // Il primo avvio con un profilo nuovo, su un computer carico, supera i 30 s:
      // chi scade qui lascia la serie con il suo errore senza che Chromium
      // abbia sbagliato niente.
      return await _attach(process, await endpoint.future.timeout(const Duration(seconds: 90)), log, screen, proxy);
    } on Object {
      // Si aspetta l'uscita: il profilo resta bloccato finché il processo vive,
      // e l'avvio successivo lo troverebbe in uso.
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 10), onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      });
      await proxy.close();
      rethrow;
    }
  }

  /// Si collega a DevTools del contenitore [host]. Per indirizzo e non per
  /// nome: Chromium rifiuta un `Host` che non sia un IP o `localhost`.
  static Future<_Chromium> connect(String host, int port, void Function(String) log,
      Future<bool> Function(String url) screen, Future<GuardProxy> Function() guardProxy) async {
    final literal = InternetAddress.tryParse(host);
    final address = literal ?? (await InternetAddress.lookup(host).timeout(const Duration(seconds: 10))).first;
    final proxy = await guardProxy();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(Uri(scheme: 'http', host: address.address, port: port, path: '/json/version'))
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = jsonDecode(await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 10)));
      final url = body is Map ? body['webSocketDebuggerUrl'] : null;
      if (url is! String) throw StateError('/json/version senza webSocketDebuggerUrl');
      final endpoint = Uri.parse(url).replace(host: address.address, port: port);
      return await _attach(null, endpoint.toString(), log, screen, proxy);
    } on Object {
      await proxy.close();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<_Chromium> _attach(Process? process, String endpoint, void Function(String) log,
      Future<bool> Function(String url) screen, GuardProxy proxy) async {
    final socket = await WebSocket.connect(endpoint).timeout(const Duration(seconds: 30));
    final chromium = _Chromium._(process, socket, '', screen, proxy);
    try {
      // Sul browser intero, non sulla scheda: così passano di qui anche i
      // worker e i service worker che la pagina accende.
      await chromium._send('Fetch.enable', {
        'patterns': [
          {'urlPattern': '*'},
        ],
      });
      final version = await chromium._send('Browser.getVersion');
      // L'user agent di un Chromium senza schermo lo dice: è la prima cosa
      // che Cloudflare guarda.
      chromium._userAgent = '${version['userAgent']}'.replaceAll('HeadlessChrome', 'Chrome');
      log('Browser: ${version['product']}${process == null ? ' (contenitore)' : ''}.');
      return chromium;
    } on Object {
      await socket.close().catchError((Object _) {});
      rethrow;
    }
  }

  final Process? _process;
  final WebSocket _socket;
  String _userAgent;
  final Future<bool> Function(String url) _screen;
  final GuardProxy _proxy;
  int _next = 0;
  final Map<int, Completer<Map<String, Object?>>> _pending = {};

  /// Le schede aperte da [read] e non ancora chiuse.
  final Set<String> _targets = {};

  void _receive(Object? message) {
    if (message is! String) return;
    final json = jsonDecode(message) as Map<String, Object?>;
    final id = json['id'];
    if (json['method'] == 'Fetch.requestPaused') unawaited(_paused(json['params'] as Map<String, Object?>));
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

  /// Una richiesta ferma prima di partire: prosegue solo se [_screen] la ammette.
  Future<void> _paused(Map<String, Object?> params) async {
    final request = params['requestId'];
    final url = '${(params['request'] as Map?)?['url']}';
    try {
      final allowed = await _screen(url);
      await _send(allowed ? 'Fetch.continueRequest' : 'Fetch.failRequest',
          {'requestId': request, if (!allowed) 'errorReason': 'BlockedByClient'});
    } on Object {
      // La scheda chiusa nel frattempo, o Chromium caduto: niente da sbloccare.
    }
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

  /// Apre [url] in una scheda nuova e ne dà l'HTML, con l'indirizzo su cui
  /// la scheda è finita, appena [ready] è vero; `null` se entro [timeout]
  /// non lo diventa.
  Future<({String url, String html})?> read(String url, String ready, Duration timeout) async {
    final target = '${(await _send('Target.createTarget', {'url': 'about:blank'}))['targetId']}';
    _targets.add(target);
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
          final page = await _evaluate('[location.href, document.documentElement.outerHTML]', session);
          if (page is! List || page.length != 2 || page[0] is! String || page[1] is! String) return null;
          return (url: page[0] as String, html: '<!DOCTYPE html>${page[1]}');
        }
      }
      return null;
    } finally {
      await _closeTarget(target);
    }
  }

  Future<void> _closeTarget(String target) async {
    _targets.remove(target);
    await _send('Target.closeTarget', {'targetId': target}).catchError((Object _) => const <String, Object?>{});
  }

  /// Chiude il canale; il Chromium del contenitore resta acceso, senza le
  /// schede di questo server.
  Future<void> close() async {
    for (final target in [..._targets]) {
      await _closeTarget(target);
    }
    await _socket.close().catchError((Object _) {});
    final process = _process;
    if (process != null) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 10), onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      });
    }
    await _proxy.close();
  }
}
