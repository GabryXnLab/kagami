/// Il comando `browser`: Chromium nel contenitore `kagami-browser`.
///
/// Il contenitore non ha il volume dei dati né `KAGAMI_SETUP`: un renderer
/// compromesso, senza sandbox, trova solo il proprio profilo. Il server lo
/// guida via DevTools sulla porta [browserDebugPort] della rete interna, e
/// Chromium esce solo dal proxy del server (`KAGAMI_BROWSER_PROXY`).
///
/// Chromium 157 ignora `--remote-debugging-address` e tiene DevTools sul
/// loopback (misurato): la porta verso la rete la apre questo processo, che
/// la inoltra a quella di Chromium e la serve solo al server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'browser.dart';
import 'browser_proxy.dart';

/// La porta DevTools del contenitore del browser.
const int browserDebugPort = 9222;

/// La porta del proxy del server per il contenitore del browser.
const int browserProxyPort = 9223;

class BrowserContainer {
  BrowserContainer._(this._process, this._server, this._inner, this._admit, this._log) {
    // Un errore del socket in ascolto o di un capo resettato non deve far
    // uscire il processo: è il contenitore intero (qualunque client, anche uno
    // rifiutato, lo farebbe cadere).
    _server.listen((client) => unawaited(_forward(client)), onError: (Object _) {});
    unawaited(_process.exitCode.then((_) => _close()));
  }

  /// Toglie i blocchi del profilo, lancia Chromium col proxy [proxy]
  /// (`host:porta`) e apre DevTools su [address]:[port] a chi [admit] ammette.
  static Future<BrowserContainer> start(String executable, Directory profile, String proxy,
      {InternetAddress? address, int port = browserDebugPort, ProxyAdmission? admit, void Function(String)? log}) async {
    await clearProfileLocks(profile);
    final process = await Process.start(executable, chromiumArguments(profile.path, proxy));
    unawaited(process.stdout.drain<void>());
    final inner = Completer<int>();
    final void Function(String) say = log ?? stderr.writeln;
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      // Restano nei log del contenitore.
      say(line);
      final endpoint = devToolsEndpoint(line);
      if (endpoint != null && !inner.isCompleted) inner.complete(Uri.parse(endpoint).port);
    });
    unawaited(process.exitCode.then((code) {
      if (!inner.isCompleted) inner.completeError(StateError('Chromium è uscito subito ($code)'));
    }));
    try {
      final chromiumPort = await inner.future.timeout(const Duration(seconds: 90));
      final server = await ServerSocket.bind(address ?? InternetAddress.anyIPv4, port);
      return BrowserContainer._(process, server, chromiumPort, admit, say);
    } on Object {
      process.kill();
      await process.exitCode;
      rethrow;
    }
  }

  final Process _process;
  final ServerSocket _server;
  final int _inner;
  final ProxyAdmission? _admit;
  final void Function(String) _log;
  final Set<Socket> _open = {};

  int get port => _server.port;
  Future<int> get exitCode => _process.exitCode;

  /// Ferma Chromium con [signal] e ne dà il codice d'uscita.
  Future<int> stop([ProcessSignal signal = ProcessSignal.sigterm]) async {
    _process.kill(signal);
    final code = await _process.exitCode.timeout(const Duration(seconds: 10), onTimeout: () {
      _process.kill(ProcessSignal.sigkill);
      return _process.exitCode;
    });
    await _close();
    return code;
  }

  Future<void> _close() async {
    await _server.close();
    for (final socket in [..._open]) {
      socket.destroy();
    }
    _open.clear();
  }

  Future<void> _forward(Socket client) async {
    _open.add(client);
    unawaited(client.done.catchError((Object _) {}));
    Socket? chromium;
    try {
      final admit = _admit;
      if (admit != null && !await admit(client.remoteAddress)) {
        _log('Browser: DevTools chiuso a ${client.remoteAddress.address} (non è il server).');
        return;
      }
      chromium = await Socket.connect(InternetAddress.loopbackIPv4, _inner, timeout: const Duration(seconds: 10));
      _open.add(chromium);
      unawaited(chromium.done.catchError((Object _) {}));
      final to = chromium;
      // Il capo che finisce per secondo può fallire a inoltro già chiuso.
      await Future.any([client.cast<List<int>>().forEach(to.add), to.cast<List<int>>().forEach(client.add)]
          .map((side) => side.catchError((Object _) {})));
    } on Object catch (_) {
      // Un capo caduto: si chiude l'altro.
    } finally {
      client.destroy();
      chromium?.destroy();
      _open
        ..remove(client)
        ..remove(chromium);
    }
  }
}

/// Il comando `browser`: tiene acceso [BrowserContainer] finché Chromium
/// vive, gli inoltra SIGTERM e SIGINT e ne dà il codice d'uscita (128 più il
/// segnale, come una shell, se è uscito per un segnale).
Future<int> runBrowser(String executable, Directory profile, String proxy) async {
  final container = await BrowserContainer.start(executable, profile, proxy,
      admit: GuardProxy.resolvedFrom(Uri.parse('http://$proxy').host));
  final signals = [
    for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint])
      signal.watch().listen((received) => unawaited(container.stop(received))),
  ];
  final code = await container.exitCode;
  for (final watching in signals) {
    await watching.cancel();
  }
  return code < 0 ? 128 - code : code;
}
