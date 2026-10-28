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
import 'package:kagami_archive/health.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart' show PageBrowser, SuppliedPages, selectProvider;
import 'package:kagami_archive/repair.dart';
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

/// Quante richieste insieme verso Drive: il tempo di un capitolo è la latenza
/// per file (~2 s) divisa per le corsie, e Drive non ha mai risposto 429 fino
/// a 64 in parallelo. Il telefono resta a 8.
const int driveLanes = 32;

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
          uploads: driveLanes,
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
    this.unfollowed = const {},
    this.checkedAt,
    this.checked = 0,
    this.queued = 0,
    this.failed = 0,
  });

  factory ServerCheck.fromJson(Map<String, Object?> json, ServerCheck fallback) => ServerCheck(
        enabled: json['enabled'] as bool? ?? fallback.enabled,
        minutes: (json['minutes'] as num?)?.toInt() ?? fallback.minutes,
        library: json['library'] as bool? ?? fallback.library,
        unfollowed: {...?(json['unfollowed'] as List?)?.whereType<String>()},
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

  /// Le serie che l'utente ha smesso di seguire: il controllo non le guarda
  /// più, né fra quelle del server né nella libreria.
  final Set<String> unfollowed;
  final DateTime? checkedAt;
  final int checked;
  final int queued;
  final int failed;

  ServerCheck copyWith({
    bool? enabled,
    int? minutes,
    bool? library,
    Set<String>? unfollowed,
    DateTime? checkedAt,
    int? checked,
    int? queued,
    int? failed,
  }) =>
      ServerCheck(
        enabled: enabled ?? this.enabled,
        minutes: minutes ?? this.minutes,
        library: library ?? this.library,
        unfollowed: unfollowed ?? this.unfollowed,
        checkedAt: checkedAt ?? this.checkedAt,
        checked: checked ?? this.checked,
        queued: queued ?? this.queued,
        failed: failed ?? this.failed,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'minutes': minutes,
        'library': library,
        'unfollowed': [...unfollowed],
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

  /// Il controllo di una serie sola, adesso: una serie man mano arrivata in
  /// fondo a ciò che si conosceva.
  Future<void> checkSeries(String key);

  Future<ServerCheck> checkSettings();

  /// Cambia il controllo quotidiano e lo riprogramma.
  Future<ServerCheck> configureCheck({bool? enabled, int? minutes, bool? library, Set<String>? unfollowed});

  /// Le serie che l'ultimo controllo ha trovato ferme alla verifica del sito.
  Future<List<GatedSeries>> gated();

  /// Quali siti non funzionano più per intero.
  Future<Map<String, SiteHealth>> sites();

  /// Il controllo delle serie ferme alla verifica, con le loro pagine
  /// aperte da una persona sul telefono ([pages], per link).
  Future<CheckReport> checkPages(Map<String, String> pages);

  /// Mette in attesa la riparazione della libreria: tutta, un [site] o le
  /// serie in [keys]. Una sola richiesta in attesa per utente, e le nuove
  /// si sommano a lei.
  void repair({String? site, Set<String>? keys});
}

/// Dove sta la riparazione in attesa di un utente, accanto a `check.json`.
const String repairFileName = 'repair.json';

/// La riparazione in attesa. [site] e [keys] nulli vogliono dire tutta la
/// libreria.
class RepairRequest {
  RepairRequest(this.site, this.keys);

  /// `null` se il file manca o non si legge: una richiesta rovinata non deve
  /// bloccare il giro.
  static RepairRequest? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final site = json['site'];
    final keys = json['keys'];
    return RepairRequest(
      site is String ? site : null,
      keys is List ? {...keys.whereType<String>()} : null,
    );
  }

  final String? site;
  final Set<String>? keys;

  bool get all => site == null && keys == null;

  Map<String, Object?> toJson() => {'site': ?site, if (keys != null) 'keys': [...keys!]..sort()};

  bool sameAs(RepairRequest other) =>
      site == other.site &&
      (keys == null ? other.keys == null : other.keys != null && keys!.length == other.keys!.length && keys!.containsAll(other.keys!));

  /// Regola semplice: le stesse chiavi si uniscono, lo stesso sito resta lui;
  /// ogni altra combinazione (due siti, sito e chiavi, o tutta la libreria)
  /// diventa tutta la libreria, che è l'unione e costa solo qualche serie in
  /// più riletta.
  RepairRequest merge(RepairRequest other) {
    if (all || other.all) return RepairRequest(null, null);
    if (site != null && site == other.site) return this;
    final mine = keys;
    final theirs = other.keys;
    if (mine != null && theirs != null) return RepairRequest(null, {...mine, ...theirs});
    return RepairRequest(null, null);
  }
}

/// Mette in attesa una riparazione scrivendo il file dell'utente (unendola a
/// quella già lì): è come ci arriva dal comando `repair`, da un altro processo.
Future<RepairRequest> queueRepair(ArchiveFiles files, RepairRequest request) async {
  final file = File(p.join(files.directory.path, repairFileName));
  final merged = RepairRequest.fromJson(await readJsonFile(file))?.merge(request) ?? request;
  await writeAtomically(file, utf8.encode(jsonEncode(merged.toJson())));
  return merged;
}

class ServerWorker implements JobControl {
  ServerWorker(
    this.files,
    this.environment, {
    required this.blocked,
    this.checkMinutes,
    this.folder,
    this.browser,
    this.retryAfter = const Duration(minutes: 1),
    this.checkRetry = const Duration(minutes: 30),
    this.repairWatch = const Duration(minutes: 1),
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

  /// Chi legge le pagine dei siti dietro la verifica del browser; senza, i
  /// controlli li saltano.
  final PageBrowser? browser;
  final Duration retryAfter;

  /// Un controllo andato a vuoto per la rete o per Drive si riprova dopo
  /// questo, non il giorno dopo.
  final Duration checkRetry;

  /// Ogni quanto si guarda se il comando `repair` ha scritto il file.
  final Duration repairWatch;
  final void Function(String line) log;

  static void _stderr(String line) => stderr.writeln(line);

  bool _closed = false;
  Completer<void>? _sleeping;

  /// Una sveglia arrivata mentre il giro lavorava: il sonno seguente non
  /// comincia nemmeno.
  bool _woken = false;
  Timer? _checkTimer;
  Timer? _retryTimer;
  String? _running;
  String? _cancelling;
  Future<void>? _loop;
  Future<void>? _checking;
  RepairRequest? _repair;
  bool _repairing = false;
  Timer? _repairWatch;

  /// L'ultimo segno di vita del giro in corso; `null` se non gira.
  DateTime? _alive;
  DateTime? _checkingSince;

  /// Il giro senza segni di vita da più di [run], o il controllo cominciato
  /// da più di [check]. È un'attesa che nessun limite ha preso: in Dart un
  /// `await` non si interrompe da fuori, e l'unico rimedio è ripartire.
  /// Vedere `serve`.
  String? stuck({required Duration run, required Duration check}) {
    if (_closed) return null;
    final now = DateTime.now();
    final alive = _alive;
    if (alive != null && now.difference(alive) > run) {
      return 'il giro non dà segni di vita da ${now.difference(alive).inMinutes} minuti';
    }
    final since = _checkingSince;
    if (since != null && now.difference(since) > check) {
      return 'il controllo è cominciato ${now.difference(since).inMinutes} minuti fa e non finisce';
    }
    return null;
  }

  void start() {
    _loop = _run();
    // Il comando `repair` è un altro processo e non può chiamare wake(): il
    // file lo guardiamo noi, ogni minuto. Più semplice di un watcher sul
    // disco (inotify non regge su tutti i volumi Docker) e un minuto di
    // ritardo su una riparazione è niente.
    _repairWatch = Timer.periodic(repairWatch, (_) => unawaited(_checkRepairFile()));
    _scheduleCheck();
  }

  Future<void> close() async {
    _closed = true;
    _checkTimer?.cancel();
    _retryTimer?.cancel();
    _repairWatch?.cancel();
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

  @override
  void repair({String? site, Set<String>? keys}) {
    final request = RepairRequest(site, keys);
    _repair = _repair?.merge(request) ?? request;
    wake();
    unawaited(_saveRepair());
  }

  File get _repairFile => File(p.join(files.directory.path, repairFileName));

  /// Porta in memoria ciò che c'è nel file (scritto prima di un riavvio o dal
  /// comando `repair`), sommandolo.
  Future<void> _pullRepair() async {
    final stored = RepairRequest.fromJson(await readJsonFile(_repairFile));
    if (stored != null) _repair = _repair?.merge(stored) ?? stored;
  }

  /// Scrive la richiesta in attesa, sommata a quella che un altro processo ha
  /// messo nel file nel frattempo.
  Future<void> _saveRepair() async {
    await _pullRepair();
    final request = _repair;
    if (request != null) await writeAtomically(_repairFile, utf8.encode(jsonEncode(request.toJson())));
  }

  Future<void> _checkRepairFile() async {
    if (_closed || _repairing) return;
    await _pullRepair();
    if (_repair != null) wake();
  }

  Future<void> _run() async {
    while (!_closed) {
      _woken = false;
      await _pullRepair();
      final reason = await blocked();
      if (_closed) break;
      if (reason != null) {
        final queued = await files.jobs();
        if (queued.isNotEmpty) {
          await files.writeStatus(const ArchiveStatus().copyWith(state: ArchiveState.waiting, message: reason));
        }
        await _sleep(queued.isEmpty && _repair == null ? null : retryAfter);
        continue;
      }
      if (_repair != null && !await _repairNow()) {
        await _sleep(retryAfter);
        continue;
      }
      _alive = DateTime.now();
      final end = await ArchiveRunner(
        files,
        environment,
        // Una riparazione in attesa ferma il giro fra un capitolo e l'altro: il
        // lavoro resta in coda e riprende dopo.
        cancelled: () => _closed || _cancelling != null || _repair != null,
        onStatus: (status) {
          _alive = DateTime.now();
          _running = status.state == ArchiveState.running ? status.jobId : null;
        },
        onError: (error, stack) async => log('Errore nel giro: $error\n$stack'),
      ).run();
      _alive = null;
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

  /// Esegue la riparazione in attesa. `false` se la rete o Drive mancano:
  /// la richiesta resta in attesa, come i lavori del giro.
  Future<bool> _repairNow() async {
    final request = _repair!;
    final folderId = folder?.call();
    _repair = null;
    if (folderId == null) {
      await _forgetRepair(request);
      return true;
    }
    _repairing = true;
    final target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: folderId);
    _alive = DateTime.now();
    try {
      final outcomes = await repairLibrary(
        store: environment.storeFor(target),
        httpFor: (provider) => environment.httpFor(provider),
        scratch: environment.scratch,
        images: environment.images,
        browser: browser,
        health: files.health,
        tracking: Tracking(files.ongoing),
        files: files,
        target: target,
        only: request.keys,
        site: request.site,
        cancelled: () => _closed,
        progress: (done, total, title) {
          _alive = DateTime.now();
          unawaited(files.writeStatus(ArchiveStatus(
            state: ArchiveState.running,
            jobId: 'repair',
            title: title,
            total: total,
            done: done,
            message: '$title (${done + 1}/$total)',
          )));
        },
        onOutcome: (outcome) => files.remember(outcome.toArchiveOutcome()),
      );
      log('Riparazione: ${outcomes.length} serie, ${outcomes.where((o) => o.error != null).length} con errori.');
      if (!_closed) await _forgetRepair(request);
      return true;
    } on ProviderOffline {
      _repair = _repair?.merge(request) ?? request;
      await _saveRepair();
      log('Riparazione: rete assente, si riprova.');
      return false;
    } on DriveException catch (error) {
      _repair = _repair?.merge(request) ?? request;
      await _saveRepair();
      log('Riparazione: Drive non risponde ($error), si riprova.');
      return false;
    } finally {
      _repairing = false;
      _alive = null;
      await files.writeStatus(const ArchiveStatus());
      if ((await files.jobs()).isNotEmpty) wake();
    }
  }

  /// Cancella il file solo se è ancora la richiesta appena eseguita: se il
  /// comando `repair` ne ha scritta una più larga mentre giravamo, resta e
  /// gira dopo.
  Future<void> _forgetRepair(RepairRequest done) async {
    final stored = RepairRequest.fromJson(await readJsonFile(_repairFile));
    if (stored == null) return;
    if (stored.sameAs(done)) {
      try {
        await _repairFile.delete();
      } on PathNotFoundException {
        // già tolto
      }
    } else {
      _repair = _repair?.merge(stored) ?? stored;
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
  Future<ServerCheck> configureCheck({bool? enabled, int? minutes, bool? library, Set<String>? unfollowed}) async {
    final settings = (await checkSettings())
        .copyWith(enabled: enabled, minutes: minutes, library: library, unfollowed: unfollowed);
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
  Future<void> checkNow() => _checking ??= () {
        _checkingSince = DateTime.now();
        return _check().whenComplete(() {
          _checking = null;
          _checkingSince = null;
        });
      }();

  @override
  Future<void> checkSeries(String key) async {
    if (await blocked() != null) return;
    try {
      final report = await Tracking(files.ongoing).check(
        files,
        (provider) => environment.httpFor(provider),
        browser: browser,
        cancelled: () => _closed,
        only: {key},
        skip: (await checkSettings()).unfollowed,
      );
      if (report.queued.isNotEmpty) wake();
    } on ProviderOffline {
      log('Controllo di $key: rete assente.');
    }
  }

  void _retryCheck(String why) {
    log('Controllo: $why, si riprova fra ${checkRetry.inMinutes} minuti.');
    _retryTimer?.cancel();
    if (!_closed) _retryTimer = Timer(checkRetry, () => unawaited(checkNow()));
  }

  /// Le serie che segue il server e, con `library`, le altre della libreria
  /// su Drive; con [only] solo quelle.
  Future<CheckReport> _sweep(ServerCheck settings, {PageBrowser? browser, Set<String>? only}) async {
    final tracking = Tracking(files.ongoing);
    final report = await tracking.check(
      files,
      (provider) => environment.httpFor(provider),
      browser: browser,
      cancelled: () => _closed,
      only: only,
      skip: settings.unfollowed,
    );
    log('Serie in corso: ${report.checked} controllate, ${report.queued.length} con capitoli nuovi.');
    final folderId = folder?.call();
    if (settings.library && folderId != null && !_closed) {
      final target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: folderId);
      final library = await checkLibrary(
        files: files,
        store: environment.storeFor(target),
        target: target,
        httpFor: (provider) => environment.httpFor(provider),
        browser: browser,
        skip: {for (final entry in await tracking.load()) entry.key, ...settings.unfollowed},
        only: only,
        cancelled: () => _closed,
      );
      report.absorb(library);
      log('Libreria su Drive: ${library.checked} serie controllate, ${library.queued.length} con capitoli '
          'nuovi, ${library.repaired.length} con l\'indice da riparare.');
    }
    if (report.gated.isNotEmpty) {
      log('Ferme alla verifica del sito, da passare dall\'app: ${report.gated.length}.');
    }
    await files.recordGated(report.gated, only: only);
    return report;
  }

  Future<void> _check() async {
    if (await blocked() != null) return;
    final settings = await checkSettings();
    final CheckReport report;
    try {
      report = await _sweep(settings, browser: browser);
    } on ProviderOffline {
      _retryCheck('rete assente');
      return;
    } on DriveException catch (error) {
      _retryCheck('Drive non risponde ($error)');
      return;
    }
    await _saveCheck((await checkSettings()).copyWith(
      checkedAt: DateTime.now(),
      checked: report.checked,
      queued: report.queued.length,
      failed: report.failed.length,
    ));
    wake();
  }

  @override
  Future<List<GatedSeries>> gated() => files.gated();

  @override
  Future<Map<String, SiteHealth>> sites() => files.health.load();

  @override
  Future<CheckReport> checkPages(Map<String, String> pages) async {
    final supplied = SuppliedPages(pages);
    final links = {for (final url in pages.keys) _canonical(url)};
    final only = {
      for (final entry in await files.gated())
        if (links.contains(_canonical(entry.url))) entry.key,
    };
    if (only.isEmpty || await blocked() != null) return CheckReport();
    final report = await _sweep(await checkSettings(), browser: supplied, only: only);
    if (report.queued.isNotEmpty || report.repaired.isNotEmpty) wake();
    return report;
  }

  static String _canonical(String url) {
    try {
      return selectProvider(url).canonical(url);
    } on Object {
      return url;
    }
  }
}
