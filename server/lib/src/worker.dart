/// Il giro della coda sul server, e il controllo quotidiano delle serie in
/// corso.
///
/// È lo stesso [ArchiveRunner] del lavoro in primo piano del telefono; qui
/// cambia solo chi lo fa ripartire. Sul telefono lo riaccende Android quando
/// torna la rete; qui un ciclo che dorme finché qualcuno non mette in coda,
/// o un minuto se mancava la rete.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:path/path.dart' as p;

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

/// Il controllo quotidiano di un account, come lo sceglie dall'app: se c'è,
/// a che ora e se guarda tutta la libreria su Drive o solo le serie che il
/// server ha scaricato. Più com'è andato l'ultimo.
class ServerCheck {
  const ServerCheck({
    this.enabled = true,
    this.minutes = 4 * 60,
    this.library = true,
    this.checkedAt,
    this.checked = 0,
    this.queued = 0,
    this.failed = 0,
  });

  factory ServerCheck.fromJson(Map<String, Object?> json, ServerCheck fallback) => ServerCheck(
        enabled: json['enabled'] as bool? ?? fallback.enabled,
        minutes: (json['minutes'] as num?)?.toInt() ?? fallback.minutes,
        library: json['library'] as bool? ?? fallback.library,
        checkedAt: DateTime.tryParse('${json['checkedAt']}'),
        checked: (json['checked'] as num?)?.toInt() ?? 0,
        queued: (json['queued'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
      );

  final bool enabled;

  /// L'ora, in minuti dalla mezzanotte del server.
  final int minutes;

  /// Anche le serie della libreria che il server non ha scaricato.
  final bool library;
  final DateTime? checkedAt;
  final int checked;
  final int queued;
  final int failed;

  ServerCheck copyWith({
    bool? enabled,
    int? minutes,
    bool? library,
    DateTime? checkedAt,
    int? checked,
    int? queued,
    int? failed,
  }) =>
      ServerCheck(
        enabled: enabled ?? this.enabled,
        minutes: minutes ?? this.minutes,
        library: library ?? this.library,
        checkedAt: checkedAt ?? this.checkedAt,
        checked: checked ?? this.checked,
        queued: queued ?? this.queued,
        failed: failed ?? this.failed,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'minutes': minutes,
        'library': library,
        'checkedAt': ?checkedAt?.toIso8601String(),
        'checked': checked,
        'queued': queued,
        'failed': failed,
      };
}

/// Ciò che l'API chiede al giro.
abstract interface class JobControl {
  /// C'è qualcosa di nuovo in coda.
  void wake();

  /// Toglie un lavoro: se è quello in corso, lo ferma prima.
  Future<void> cancel(String id);

  /// Il controllo delle serie in corso, adesso.
  Future<void> checkNow();

  Future<ServerCheck> checkSettings();

  /// Cambia il controllo quotidiano e lo riprogramma.
  Future<ServerCheck> configureCheck({bool? enabled, int? minutes, bool? library});
}

class ServerWorker implements JobControl {
  ServerWorker(
    this.files,
    this.environment, {
    required this.blocked,
    this.checkMinutes,
    this.folder,
    this.retryAfter = const Duration(minutes: 1),
    this.log = _stderr,
  });

  final ArchiveFiles files;
  final ArchiveEnvironment environment;

  /// Perché il giro non può partire (Drive non autorizzato, cartella non
  /// scelta), o `null`. Si chiede prima di ogni giro: i lavori restano in
  /// coda invece di fallire uno dopo l'altro con lo stesso errore.
  final Future<String?> Function() blocked;

  /// L'ora di partenza del controllo per chi non l'ha ancora scelta
  /// (`check.minutes` di `config.json`); `null` lo vuole spento.
  final int? checkMinutes;

  /// La cartella della libreria di questo account, per guardarla tutta.
  final String? Function()? folder;
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

  File get _checkFile => File(p.join(files.directory.path, 'check.json'));

  @override
  Future<ServerCheck> checkSettings() async {
    final fallback = ServerCheck(enabled: checkMinutes != null, minutes: checkMinutes ?? 4 * 60);
    final json = await readJsonFile(_checkFile);
    return json == null ? fallback : ServerCheck.fromJson(json, fallback);
  }

  Future<void> _saveCheck(ServerCheck settings) =>
      writeAtomically(_checkFile, utf8.encode(jsonEncode(settings.toJson())));

  @override
  Future<ServerCheck> configureCheck({bool? enabled, int? minutes, bool? library}) async {
    final settings = (await checkSettings()).copyWith(enabled: enabled, minutes: minutes, library: library);
    await _saveCheck(settings);
    _checkTimer?.cancel();
    _scheduleCheck();
    return settings;
  }

  void _scheduleCheck() {
    unawaited(checkSettings().then((settings) {
      if (!settings.enabled || _closed) return;
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, settings.minutes ~/ 60, settings.minutes % 60);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      _checkTimer?.cancel();
      _checkTimer = Timer(next.difference(now), () {
        unawaited(checkNow());
        _scheduleCheck();
      });
    }));
  }

  @override
  Future<void> checkNow() => _checking ??= _check().whenComplete(() => _checking = null);

  Future<void> _check() async {
    if (await blocked() != null) return;
    final settings = await checkSettings();
    var checked = 0;
    var queued = 0;
    var failed = 0;
    try {
      final tracking = Tracking(files.ongoing);
      final report = await tracking.check(
        files,
        (provider) => environment.httpFor(provider),
        cancelled: () => _closed,
      );
      checked += report.checked;
      queued += report.queued.length;
      failed += report.failed.length;
      log('Serie in corso: ${report.checked} controllate, ${report.queued.length} con capitoli nuovi.');
      final folderId = folder?.call();
      if (settings.library && folderId != null && !_closed) {
        final target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: folderId);
        final library = await checkLibrary(
          files: files,
          store: environment.storeFor(target),
          target: target,
          httpFor: (provider) => environment.httpFor(provider),
          skip: {for (final entry in await tracking.load()) entry.key},
          cancelled: () => _closed,
        );
        checked += library.checked;
        queued += library.queued.length;
        failed += library.failed.length;
        log('Libreria su Drive: ${library.checked} serie controllate, ${library.queued.length} con capitoli '
            'nuovi, ${library.repaired.length} con l\'indice da riparare.');
      }
    } on ProviderOffline {
      log('Controllo: rete assente, si riprova al prossimo.');
      return;
    } on DriveException catch (error) {
      log('Controllo: Drive non risponde ($error), si riprova al prossimo.');
      return;
    }
    await _saveCheck((await checkSettings())
        .copyWith(checkedAt: DateTime.now(), checked: checked, queued: queued, failed: failed));
    wake();
  }
}
