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

import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/elsewhere.dart';
import 'package:kagami_archive/health.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/manual.dart' show manualProvider;
import 'package:kagami_archive/providers.dart' show PageBrowser, Provider, SuppliedPages, builtInProviders, providers, selectProvider, withUserProviderSource;
import 'package:kagami_archive/repair.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:path/path.dart' as p;

import 'catalog.dart';

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
/// le ha, come per la destinazione «Drive» del telefono. Nel cestino di
/// Drive sposta solo se [owned] dice che la cartella è dell'account.
///
/// Ogni richiesta ai siti, anche dei siti inclusi e a ogni reindirizzamento,
/// rifiuta gli host che risolvono in un indirizzo privato: il server sta
/// dentro una rete (i metadati della macchina, il router, gli altri
/// servizi) che il telefono non vede, e un sito che reindirizza lì non deve
/// portarci la sua risposta fra le tavole.
ArchiveEnvironment serverEnvironment(
  ArchiveFiles files,
  SyncRemote remote,
  Directory scratch,
  ImageTools images, {
  required bool? Function(String folderId) owned,
}) =>
    ArchiveEnvironment(
      scratch: scratch,
      images: images,
      httpFor: (provider, {userAgent, cookies = const {}}) => SiteHttp(
        provider.allowedHost,
        userAgent: userAgent ?? defaultUserAgent,
        publicOnly: true,
        cookies: cookies.isEmpty ? null : (uri) => cookies[uri.host],
      ),
      storeFor: (target) {
        final folderId = target.folderId!;
        return DriveStore(
          remote: remote,
          folderId: folderId,
          staging: files.staging(folderId).path,
          uploads: driveLanes,
          owned: owned(folderId),
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
    this.elsewhere = true,
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
        elsewhere: json['elsewhere'] != false,
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

  /// Dopo il controllo, la passata «Su altri siti» sulla libreria.
  final bool elsewhere;
  final DateTime? checkedAt;
  final int checked;
  final int queued;
  final int failed;

  ServerCheck copyWith({
    bool? enabled,
    int? minutes,
    bool? library,
    Set<String>? unfollowed,
    bool? elsewhere,
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
        elsewhere: elsewhere ?? this.elsewhere,
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
        'elsewhere': elsewhere,
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
  Future<ServerCheck> configureCheck(
      {bool? enabled, int? minutes, bool? library, Set<String>? unfollowed, bool? elsewhere});

  /// Le serie della libreria sugli altri siti (quelle di [keys], o tutte) e a
  /// che punto è la passata: il corpo di `GET /v2/elsewhere`.
  Future<Map<String, Object?>> elsewhere({Set<String>? keys});

  /// Mette in attesa [keys] per la passata «Su altri siti», prima di ogni
  /// altra serie e anche se non sono da riguardare.
  void lookElsewhere(Set<String> keys);

  /// I siti degli utenti di questo account, come l'ultima lettura di
  /// `providers/` li ha lasciati.
  List<Provider> get userSites;

  /// I file di `providers/` che l'ultima lettura non ha potuto usare:
  /// `[{"file": "x.json", "message": "…"}]`.
  List<Map<String, String>> get sitesErrors;

  /// Rilegge `providers/` dalla cartella di Drive dell'account.
  Future<void> refreshSites();

  /// Esegue [body] con i siti di questo account: [providers] ne vede solo i suoi.
  R withSites<R>(R Function() body);

  /// Le serie che l'ultimo controllo ha trovato ferme alla verifica del sito.
  Future<List<GatedSeries>> gated();

  /// Quali siti non funzionano più per intero.
  Future<Map<String, SiteHealth>> sites();

  /// Il controllo delle serie ferme alla verifica, con le loro pagine
  /// aperte da una persona sul telefono ([pages], per link).
  Future<CheckReport> checkPages(Map<String, String> pages);

  /// Ripara adesso le serie della libreria il cui link è in [pages] (per link,
  /// con la pagina aperta sul telefono). Le serie che non sono in libreria non
  /// contano. Lancia [WorkerBusy] se il server sta già lavorando.
  Future<PagesRepair> repairPages(Map<String, String> pages);

  /// Mette in attesa la riparazione della libreria: tutta, un [site] o le
  /// serie in [keys]. Una sola richiesta in attesa per utente, e le nuove
  /// si sommano a lei.
  void repair({String? site, Set<String>? keys});
}

/// L'esito di [ServerJobs.repairPages]: serie riparate e serie che hanno dato errore.
class PagesRepair {
  int repaired = 0;
  final List<({String title, String error})> failed = [];
}

/// Il server sta già facendo un giro, una riparazione o un controllo.
class WorkerBusy implements Exception {
  const WorkerBusy();
}

/// Dove sta lo stato dell'ultima passata «Su altri siti», accanto a `elsewhere.json`.
const String elsewherePassFileName = 'elsewhere-pass.json';

/// Dove sta la riparazione in attesa di un utente, accanto a `check.json`.
const String repairFileName = 'repair.json';

/// Dove stanno gli id e i nomi dei siti degli utenti dell'ultima lettura, accanto
/// a `repair.json`: il comando `repair`, processo a parte senza Drive, li usa
/// per validare `--site`.
const String sitesFileName = 'sites.json';

/// Gli id dei siti scritti da [ServerWorker.refreshSites] nella cartella
/// [directory] di un utente; `null` se il file manca o non si legge.
Future<Set<String>?> readSiteIds(String directory) async {
  final json = await readJsonFile(File(p.join(directory, sitesFileName)));
  final list = json?['sites'];
  if (list is! List) return null;
  return {
    for (final entry in list)
      if (entry is Map && entry['id'] is String) entry['id'] as String,
  };
}

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
    this.sitesMaxAge = const Duration(minutes: 5),
    this.elsewhereDelay = const Duration(seconds: 2),
    this.catalog,
    this.log = _stderr,
  });

  /// Il catalogo dei siti, se configurato: si ricontrolla prima di ogni giro e
  /// di ogni controllo (`docs/catalogo.md`, «Quando si ricontrolla»).
  final ServerCatalog? catalog;

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

  /// Oltre questa età l'ultima lettura dei siti degli utenti non basta a
  /// controllare una serie di un sito non incluso: si rilegge prima.
  final Duration sitesMaxAge;

  /// L'attesa fra una richiesta e l'altra ai siti, nella passata «Su altri siti».
  final Duration elsewhereDelay;
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

  /// C'è una passata «Su altri siti» da finire. Sta in memoria: se il server
  /// riparte la rifa il prossimo controllo quotidiano, e le serie già lette
  /// non si rileggono perché `elsewhere.json` ne ricorda l'ora.
  bool _elsewhereOwed = false;
  final Set<String> _elsewhereKeys = {};
  bool _elsewhereRunning = false;

  /// Un lavoro è entrato (o qualcuno ha chiamato [wake]): la passata si ferma.
  bool _interrupt = false;
  DateTime? _passStarted;
  DateTime? _passFinished;
  int _passChecked = 0;
  int _passPending = 0;
  bool _passLoaded = false;
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

  List<Provider> _sites = const [];
  DateTime? _sitesReadAt;
  List<Map<String, String>> _sitesErrors = const [];

  @override
  List<Provider> get userSites => _sites;

  @override
  List<Map<String, String>> get sitesErrors => _sitesErrors;

  @override
  R withSites<R>(R Function() body) => withUserProviderSource(() => _sites, body);

  /// Adozione: se la lettura di `providers/` fallisce restano i siti di prima;
  /// un file non valido tiene la versione di prima di quel sito; un file
  /// sparito toglie il sito.
  @override
  Future<void> refreshSites() async {
    final folderId = folder?.call();
    if (folderId == null) return;
    final store = environment.storeFor(ArchiveTarget(destination: ArchiveDestination.drive, folderId: folderId));
    final errors = <String, String>{};
    final List<DeclarativeProvider> read;
    try {
      read = await loadSites(store, onError: (file, error) => errors[file] = '$error');
    } on Object catch (error) {
      log('Siti degli utenti: lettura non riuscita ($error), restano quelli di prima.');
      return;
    }
    final previous = {for (final site in _sites) site.id: site};
    final next = <String, Provider>{for (final site in read) site.id: site};
    for (final file in errors.keys) {
      final id = file.endsWith('.json') ? file.substring(0, file.length - 5) : file;
      final old = previous[id];
      if (old != null && !next.containsKey(id)) next[id] = old;
    }
    _sites = List.unmodifiable(next.values);
    _sitesReadAt = DateTime.now();
    try {
      await writeAtomically(
        File(p.join(files.directory.path, sitesFileName)),
        utf8.encode(jsonEncode({
          'sites': [for (final site in _sites) {'id': site.id, 'name': site.name}],
        })),
      );
    } on Object catch (error) {
      log('Siti degli utenti: file per il comando repair non scritto ($error).');
    }
    _sitesErrors = List.unmodifiable([
      for (final MapEntry(:key, :value) in errors.entries) {'file': key, 'message': value},
    ]);
  }

  void start() => withSites(_start);

  void _start() {
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
    await _repairSaved;
  }

  @override
  void wake() {
    _woken = true;
    _interrupt = true;
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
    unawaited(_repairSaved = _saveRepair());
  }

  /// L'ultima scrittura di `repair.json` partita da [repair]: [close] la
  /// aspetta, così chi chiude non trova il file ancora a metà.
  Future<void>? _repairSaved;

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
        await _sleep(queued.isEmpty && _repair == null && !_elsewhereWanted ? null : retryAfter);
        continue;
      }
      await catalog?.refresh();
      await refreshSites();
      if (_repair != null && !await _repairNow()) {
        await _sleep(retryAfter);
        continue;
      }
      if (_elsewhereWanted && !await _elsewhereNow()) {
        await _sleep(retryAfter);
        continue;
      }
      // Una riparazione con le pagine del telefono (repairPages) gira fuori da
      // questo ciclo: il giro aspetta lei, che alla fine lo risveglia.
      if (_repairing) {
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
          // La coda è vuota: se c'è una passata da finire tocca a lei.
          if (!_elsewhereWanted) await _sleep(null);
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

  bool get _elsewhereWanted => _elsewhereOwed || _elsewhereKeys.isNotEmpty;

  File get _elsewhereFile => File(p.join(files.directory.path, 'elsewhere.json'));
  File get _passFile => File(p.join(files.directory.path, elsewherePassFileName));

  Future<void> _loadPass() async {
    if (_passLoaded) return;
    _passLoaded = true;
    final json = await readJsonFile(_passFile);
    if (json == null) return;
    _passStarted = DateTime.tryParse('${json['startedAt']}');
    _passFinished = DateTime.tryParse('${json['finishedAt']}');
    _passChecked = (json['checked'] as num?)?.toInt() ?? 0;
    _passPending = (json['pending'] as num?)?.toInt() ?? 0;
  }

  Future<void> _savePass() => writeAtomically(
        _passFile,
        utf8.encode(jsonEncode({
          'startedAt': ?_passStarted?.toUtc().toIso8601String(),
          'finishedAt': ?_passFinished?.toUtc().toIso8601String(),
          'checked': _passChecked,
          'pending': _passPending,
        })),
      );

  @override
  void lookElsewhere(Set<String> keys) {
    _elsewhereKeys.addAll(keys);
    wake();
  }

  @override
  Future<Map<String, Object?>> elsewhere({Set<String>? keys}) async {
    await _loadPass();
    final all = await ElsewhereLog(_elsewhereFile).load();
    return {
      'series': {
        for (final MapEntry(:key, :value) in all.entries)
          if (keys == null || keys.contains(key)) key: value.toJson(),
      },
      'pass': {
        'running': _elsewhereRunning || _elsewhereWanted,
        'startedAt': ?_passStarted?.toUtc().toIso8601String(),
        'finishedAt': ?_passFinished?.toUtc().toIso8601String(),
        'checked': _passChecked,
        'pending': _passPending,
      },
    };
  }

  /// Quante serie la prossima passata guarderebbe ancora, senza il limite.
  Future<int> _elsewherePending(ArchiveStore store, ElsewhereLog seen, Set<String> skip) async {
    final known = {for (final provider in providers) provider.id};
    final previous = await seen.load();
    final now = DateTime.now();
    return [
      for (final row in await libraryRows(store))
        if (row['key'] case final String key
            when row['source'] is String &&
                row['path'] is String &&
                known.contains(key.split(':').first) &&
                !skip.contains(key) &&
                elsewhereDue(previous[key], now,
                    concluded: const {'completed', 'cancelled'}.contains(row['releaseStatus'])))
          key,
    ].length;
  }

  /// La passata «Su altri siti»: prima le serie chieste, poi quelle da
  /// riguardare. Mai con un lavoro in coda: si ferma fra una serie e l'altra
  /// quando ne entra uno ([wake]) e riprende a coda vuota. `false` se la rete
  /// o Drive mancano: resta in attesa, come la riparazione.
  Future<bool> _elsewhereNow() async {
    _interrupt = false;
    if (_repair != null || (await files.jobs()).isNotEmpty) return true;
    final folderId = folder?.call();
    final settings = await checkSettings();
    if (folderId == null) {
      _elsewhereOwed = false;
      _elsewhereKeys.clear();
      return true;
    }
    await _loadPass();
    final target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: folderId);
    final store = environment.storeFor(target);
    final found = ElsewhereLog(_elsewhereFile);
    bool cancelled() => _closed || _interrupt || _repair != null;
    if (_elsewhereOwed && (_passStarted == null || _passFinished != null)) {
      _passStarted = DateTime.now();
      _passFinished = null;
      _passChecked = 0;
    }
    _elsewhereRunning = true;
    _alive = DateTime.now();
    final base = _passChecked;
    Future<void> sweep({Set<String>? only}) async {
      var done = 0;
      try {
        done = await sweepElsewhere(
          store: store,
          log: found,
          httpFor: (provider) => environment.httpFor(provider),
          browser: browser,
          health: files.health,
          skip: settings.unfollowed,
          only: only,
          delay: elsewhereDelay,
          cancelled: cancelled,
          progress: (read, total, title) {
            _alive = DateTime.now();
            done = read;
            if (only != null) return;
            _passChecked = base + read;
            _passPending = total - read;
          },
        );
      } finally {
        if (only == null) _passChecked = base + done;
      }
    }

    try {
      final asked = {..._elsewhereKeys};
      if (asked.isNotEmpty) {
        _elsewhereKeys.removeAll(asked);
        final since = DateTime.now();
        try {
          await sweep(only: asked);
        } on Object {
          _elsewhereKeys.addAll(asked);
          rethrow;
        }
        if (cancelled()) {
          final seen = await found.load();
          _elsewhereKeys.addAll({
            for (final key in asked)
              if (seen[key] == null || seen[key]!.checkedAt.isBefore(since)) key,
          });
          return true;
        }
      }
      if (_elsewhereOwed) {
        await sweep();
        if (cancelled()) return true;
        // Il conteggio si fa prima: finishedAt e «running: false» devono comparire insieme,
        // senza un await in mezzo in cui GET /v2/elsewhere vede la passata finita e ancora in corso.
        final pending = await _elsewherePending(store, found, settings.unfollowed);
        _elsewhereOwed = false;
        _passFinished = DateTime.now();
        _passPending = pending;
        _elsewhereRunning = false;
        log('Su altri siti: $_passChecked serie lette, $_passPending ancora da guardare.');
      }
      return true;
    } on ProviderOffline {
      log('Su altri siti: rete assente, si riprova.');
      return false;
    } on DriveException catch (error) {
      log('Su altri siti: Drive non risponde ($error), si riprova.');
      return false;
    } finally {
      _elsewhereRunning = false;
      _alive = null;
      await _savePass();
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
  Future<ServerCheck> configureCheck(
      {bool? enabled, int? minutes, bool? library, Set<String>? unfollowed, bool? elsewhere}) async {
    final settings = (await checkSettings()).copyWith(
        enabled: enabled, minutes: minutes, library: library, unfollowed: unfollowed, elsewhere: elsewhere);
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
    final site = key.split(':').first;
    final notBuiltIn = !builtInProviders.any((provider) => provider.id == site);
    final user = _sites.any((provider) => provider.id == site);
    final readAt = _sitesReadAt;
    if ((notBuiltIn || user) && (readAt == null || DateTime.now().difference(readAt) > sitesMaxAge)) {
      await refreshSites();
    }
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
    await catalog?.refresh();
    await refreshSites();
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
    if (settings.elsewhere && folder?.call() != null) _elsewhereOwed = true;
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

  @override
  Future<PagesRepair> repairPages(Map<String, String> pages) async {
    final folderId = folder?.call();
    if (folderId == null) return PagesRepair();
    if (_repairing || _repair != null || _alive != null || _checking != null || _elsewhereRunning) {
      throw const WorkerBusy();
    }
    _repairing = true;
    _alive = DateTime.now();
    final result = PagesRepair();
    try {
      final target = ArchiveTarget(destination: ArchiveDestination.drive, folderId: folderId);
      final store = environment.storeFor(target);
      final links = {for (final url in pages.keys) _canonical(url)};
      final only = {
        for (final row in await libraryRows(store))
          if (row['key'] case final String key when row['source'] is String && row['provider'] != manualProvider)
            if (links.contains(_canonical(row['source'] as String))) key,
      };
      if (only.isEmpty) return result;
      await repairLibrary(
        store: store,
        httpFor: (provider) => environment.httpFor(provider),
        scratch: environment.scratch,
        images: environment.images,
        browser: SuppliedPages(pages),
        health: files.health,
        tracking: Tracking(files.ongoing),
        files: files,
        target: target,
        only: only,
        cancelled: () => _closed,
        progress: (_, _, _) => _alive = DateTime.now(),
        onOutcome: (outcome) async {
          await files.remember(outcome.toArchiveOutcome());
          final error = outcome.error;
          if (error == null) {
            result.repaired++;
          } else {
            result.failed.add((title: outcome.title, error: error));
          }
        },
      );
      return result;
    } finally {
      _repairing = false;
      _alive = null;
      if ((await files.jobs()).isNotEmpty) wake();
    }
  }

  static String _canonical(String url) {
    try {
      return selectProvider(url).canonical(url);
    } on Object {
      return url;
    }
  }
}
