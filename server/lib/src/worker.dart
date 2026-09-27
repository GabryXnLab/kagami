/// Il giro della coda sul server, e il controllo quotidiano delle serie in
/// corso.
///
/// È lo stesso [ArchiveRunner] del lavoro in primo piano del telefono; qui
/// cambia solo chi lo fa ripartire. Sul telefono lo riaccende Android quando
/// torna la rete; qui un ciclo che dorme finché qualcuno non mette in coda,
/// o un minuto se mancava la rete.
library;

import 'dart:async';
import 'dart:io';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_archive/tracking.dart';

/// La rete del server: c'è. Un errore è un guasto di quel momento, e il giro
/// lo tratta come il telefono tratta la rete che manca: aspetta e riprova.
class ServerNetwork implements NetworkState {
  const ServerNetwork();

  @override
  bool get isOnline => true;

  @override
  void failed() {}

  @override
  void succeeded() {}

  @override
  Future<bool> check() async => true;
}

/// Dove scrive il server: solo nella cartella di Drive della libreria. Le
/// tavole passano dalla cartella di preparazione e la lasciano appena Drive
/// le ha, come per la destinazione «Drive» del telefono.
ArchiveEnvironment serverEnvironment(ArchiveFiles files, DriveClient client, Directory scratch, ImageTools images) =>
    ArchiveEnvironment(
      scratch: scratch,
      images: images,
      storeFor: (target) {
        final folderId = target.folderId!;
        return DriveStore(
          remote: DriveSyncRemote(client),
          folderId: folderId,
          staging: files.staging(folderId).path,
        );
      },
    );

/// Ciò che l'API chiede al giro.
abstract interface class JobControl {
  /// C'è qualcosa di nuovo in coda.
  void wake();

  /// Toglie un lavoro: se è quello in corso, lo ferma prima.
  Future<void> cancel(String id);

  /// Il controllo delle serie in corso, adesso.
  Future<void> checkNow();
}

class ServerWorker implements JobControl {
  ServerWorker(
    this.files,
    this.environment, {
    required this.blocked,
    this.checkMinutes,
    this.retryAfter = const Duration(minutes: 1),
    this.log = _stderr,
  });

  final ArchiveFiles files;
  final ArchiveEnvironment environment;

  /// Perché il giro non può partire (Drive non autorizzato, cartella non
  /// scelta), o `null`. Si chiede prima di ogni giro: i lavori restano in
  /// coda invece di fallire uno dopo l'altro con lo stesso errore.
  final Future<String?> Function() blocked;

  final int? checkMinutes;
  final Duration retryAfter;
  final void Function(String line) log;

  static void _stderr(String line) => stderr.writeln(line);

  bool _closed = false;
  Completer<void>? _sleeping;

  /// Una sveglia arrivata mentre il giro lavorava: il sonno seguente non
  /// comincia nemmeno.
  bool _woken = false;
  Timer? _checkTimer;
  String? _running;
  String? _cancelling;
  Future<void>? _loop;
  Future<void>? _checking;

  void start() {
    _loop = _run();
    _scheduleCheck();
  }

  Future<void> close() async {
    _closed = true;
    _checkTimer?.cancel();
    wake();
    await _loop;
    await _checking;
  }

  @override
  void wake() {
    _woken = true;
    final sleeping = _sleeping;
    if (sleeping != null && !sleeping.isCompleted) sleeping.complete();
  }

  Future<void> _sleep(Duration? upTo) async {
    if (_woken) {
      _woken = false;
      return;
    }
    final sleeping = _sleeping = Completer<void>();
    final timer = upTo == null ? null : Timer(upTo, wake);
    await sleeping.future;
    _woken = false;
    timer?.cancel();
  }

  @override
  Future<void> cancel(String id) async {
    if (_running == id) {
      _cancelling = id;
    } else {
      await files.remove(id);
    }
  }

  Future<void> _run() async {
    while (!_closed) {
      _woken = false;
      final reason = await blocked();
      if (_closed) break;
      if (reason != null) {
        final queued = await files.jobs();
        if (queued.isNotEmpty) {
          await files.writeStatus(const ArchiveStatus().copyWith(state: ArchiveState.waiting, message: reason));
        }
        await _sleep(queued.isEmpty ? null : retryAfter);
        continue;
      }
      final end = await ArchiveRunner(
        files,
        environment,
        cancelled: () => _closed || _cancelling != null,
        onStatus: (status) => _running = status.state == ArchiveState.running ? status.jobId : null,
        onError: (error, stack) async => log('Errore nel giro: $error\n$stack'),
      ).run();
      _running = null;
      final cancelling = _cancelling;
      if (cancelling != null) {
        _cancelling = null;
        await files.remove(cancelling);
        await files.writeStatus(const ArchiveStatus().copyWith(message: 'Annullato'));
        continue;
      }
      if (_closed) break;
      switch (end) {
        case RunEnd.done:
          await _sleep(null);
        case RunEnd.retry:
          await _sleep(retryAfter);
        case RunEnd.stopped:
          break;
      }
    }
  }

  void _scheduleCheck() {
    final minutes = checkMinutes;
    if (minutes == null || _closed) return;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    _checkTimer = Timer(next.difference(now), () {
      unawaited(checkNow());
      _scheduleCheck();
    });
  }

  @override
  Future<void> checkNow() => _checking ??= _check().whenComplete(() => _checking = null);

  Future<void> _check() async {
    if (await blocked() != null) return;
    try {
      final report = await Tracking(files.ongoing).check(
        files,
        (provider) => environment.httpFor(provider),
        cancelled: () => _closed,
      );
      log('Serie in corso: ${report.checked} controllate, ${report.queued.length} con capitoli nuovi.');
      if (report.queued.isNotEmpty) wake();
    } on ProviderOffline {
      log('Serie in corso: rete assente, si riprova al prossimo controllo.');
    }
  }
}
