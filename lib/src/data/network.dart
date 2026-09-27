/// Se c'è rete, e quando torna.
///
/// Con Drive la rete è una sorgente come il disco, ma molto meno affidabile:
/// va e viene in galleria, va a scatti in treno, manca in aereo. Due cose
/// devono succedere lo stesso:
///
/// * **senza rete non si aspetta.** Una richiesta che non può riuscire deve
///   fallire subito, così la tavola dice «senza connessione» invece di girare
///   per trenta secondi. Per saperlo serve uno stato, non un tentativo;
/// * **quando la rete torna si riparte da soli.** Chi è rimasto indietro —
///   tavole, copertine, download — ascolta [NetworkMonitor.online] e riprova.
///
/// Lo stato arriva da due parti. Su Android dal sistema (`NetworkWatcher.kt`),
/// che sa quando la rete cambia; dappertutto da una sonda leggera, una
/// richiesta da zero byte a Google, che conferma quello che il sistema dice e
/// fa da sola dove il sistema non c'è. Una richiesta fallita per la rete
/// chiede una conferma alla sonda: una tavola persa su una connessione a
/// scatti non deve far credere all'app di essere offline.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kagami_archive/drive.dart' show NetworkState;

const EventChannel networkChannel = EventChannel('kagami/network');

class NetworkMonitor implements NetworkState {
  NetworkMonitor({Future<bool> Function()? probe, this.channel = networkChannel})
      : _probe = probe ?? _defaultProbe;

  static final NetworkMonitor instance = NetworkMonitor();

  final EventChannel? channel;
  final Future<bool> Function() _probe;

  /// Parte ottimista: all'avvio il sistema dice subito com'è, e credere di
  /// essere offline prima di saperlo farebbe fallire le prime richieste.
  final ValueNotifier<bool> online = ValueNotifier(true);

  @override
  bool get isOnline => online.value;

  StreamSubscription<Object?>? _events;
  Future<bool>? _checking;
  Timer? _retry;
  int _misses = 0;

  /// Ascolta il sistema. Senza il canale — build Linux, test — resta la
  /// sonda, chiamata quando qualcosa fallisce.
  void start() {
    if (_events != null || channel == null) return;
    _events = channel!.receiveBroadcastStream().listen(
      (event) {
        if (event == false) _set(false);
        // In entrambi i casi si conferma: il sistema può dire "niente" su una
        // VPN che funziona, e "tutto bene" un istante prima che lo sia.
        unawaited(check());
      },
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  /// Chiede alla sonda com'è la rete adesso. Più richieste insieme ne fanno
  /// partire una sola.
  @override
  Future<bool> check() => _checking ??= _run().whenComplete(() {
        _checking = null;
      });

  Future<bool> _run() async {
    final ok = await _probe().catchError((Object _) => false);
    _set(ok);
    return ok;
  }

  /// Una richiesta vera è fallita per la rete: la si fa confermare.
  @override
  void failed() => unawaited(check());

  /// Una richiesta vera è riuscita: nessuna sonda vale di più.
  @override
  void succeeded() => _set(true);

  /// Si completa quando c'è rete; subito, se c'è già.
  Future<void> whenOnline() {
    if (isOnline) return Future.value();
    final done = Completer<void>();
    void listener() {
      if (!isOnline) return;
      online.removeListener(listener);
      done.complete();
    }

    online.addListener(listener);
    return done.future;
  }

  void _set(bool value) {
    if (value) {
      _misses = 0;
      _retry?.cancel();
      _retry = null;
    } else {
      _scheduleRetry();
    }
    online.value = value;
  }

  /// Offline, si riprova da soli: presto all'inizio — un tunnel dura poco —
  /// poi sempre più di rado, fino a un minuto, per non tenere accesa la radio
  /// di un telefono in aereo.
  void _scheduleRetry() {
    if (_retry?.isActive ?? false) return;
    final seconds = (2 << _misses).clamp(2, 60);
    _misses++;
    _retry = Timer(Duration(seconds: seconds), () {
      _retry = null;
      unawaited(check());
    });
  }

  @visibleForTesting
  void dispose() {
    _retry?.cancel();
    unawaited(_events?.cancel());
  }

  /// La richiesta che Android stesso usa per sapere se c'è internet: una
  /// risposta vuota, 204, e nient'altro. Un portale che chiede la password
  /// risponde altro, e giustamente non conta.
  static Future<bool> _defaultProbe() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(Uri.https('connectivitycheck.gstatic.com', '/generate_204'))
          .timeout(const Duration(seconds: 5));
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
      return response.statusCode == HttpStatus.noContent;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
