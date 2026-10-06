/// La coda dei download e il suo stato, in file nello spazio dell'app.
///
/// Un download lungo gira nel lavoro in primo piano (`ArchiveWorker.kt`),
/// in un motore Dart senza schermo che non ha né l'app né il suo grafo delle
/// dipendenze: tutto quello che serve a un giro sta scritto qui, e
/// l'interfaccia legge l'avanzamento dallo stesso posto. È lo stesso schema
/// della sincronizzazione (`sync/`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'stores.dart';

/// Dove finisce ciò che si scarica.
enum ArchiveDestination {
  /// Nella cartella di Drive della libreria, e il telefono non tiene niente.
  drive,

  /// Su Drive, e i capitoli restano anche sul telefono.
  driveAndPhone,

  /// Solo sul telefono: la cartella scelta o lo spazio dell'app.
  phone;

  bool get usesDrive => this != phone;
  bool get keepsOnPhone => this != drive;

  String get label => switch (this) {
        drive => 'Drive',
        driveAndPhone => 'Drive e telefono',
        phone => 'Telefono',
      };
}

/// La destinazione con i posti già risolti: il lavoro senza schermo non sa
/// quale cartella è stata scelta nell'app.
class ArchiveTarget {
  const ArchiveTarget({
    required this.destination,
    this.folderId,
    this.root,
    this.private = false,
  });

  factory ArchiveTarget.fromJson(Map<String, Object?> json) => ArchiveTarget(
        destination: ArchiveDestination.values.byName(json['destination'] as String),
        folderId: json['folderId'] as String?,
        root: json['root'] as String?,
        private: json['private'] == true,
      );

  final ArchiveDestination destination;

  /// La cartella di Drive della libreria.
  final String? folderId;

  /// La cartella del telefono.
  final String? root;

  /// Se [root] è lo spazio privato dell'app, che la galleria non guarda.
  final bool private;

  Map<String, Object?> toJson() => {
        'destination': destination.name,
        'folderId': ?folderId,
        'root': ?root,
        if (private) 'private': true,
      };
}

/// Una serie da scaricare, com'è stata chiesta.
class ArchiveJob {
  const ArchiveJob({
    required this.id,
    required this.url,
    required this.title,
    required this.target,
    this.start,
    this.ids,
    this.delayMs = 200,
    this.snapshot,
    this.userAgent,
    this.cookies = const {},
    this.automatic = false,
    this.ahead,
  });

  factory ArchiveJob.fromJson(Map<String, Object?> json) => ArchiveJob(
        id: json['id'] as String,
        url: json['url'] as String,
        title: json['title'] as String? ?? '',
        target: ArchiveTarget.fromJson(json['target'] as Map<String, Object?>),
        start: json['start'] as String?,
        ids: (json['ids'] as List?)?.whereType<String>().toSet(),
        delayMs: (json['delayMs'] as num?)?.toInt() ?? 200,
        snapshot: json['snapshot'] as String?,
        userAgent: json['userAgent'] as String?,
        cookies: {
          for (final MapEntry(:key, :value) in (json['cookies'] as Map? ?? const {}).entries)
            '$key': '$value',
        },
        automatic: json['automatic'] == true,
        ahead: (json['ahead'] as num?)?.toInt(),
      );

  final String id;
  final String url;
  final String title;
  final ArchiveTarget target;

  /// Dal capitolo con questo numero o id in poi.
  final String? start;

  /// Solo questi capitoli, per id.
  final Set<String>? ids;

  /// La pausa fra una richiesta e l'altra, in millisecondi.
  final int delayMs;

  /// La pagina della serie letta nella WebView, per i siti dietro
  /// Cloudflare: un file nello spazio dell'app.
  final String? snapshot;

  /// User agent e cookie della WebView che ha superato la verifica: le
  /// pagine dei capitoli passano solo con questi.
  final String? userAgent;
  final Map<String, String> cookies;

  /// Messo in coda dal controllo delle serie in corso, non da una persona.
  final bool automatic;

  /// Scaricando «man mano»: quanti capitoli da leggere tenere pronti. Il
  /// giro lo annota fra le serie seguite ([Tracking]), e da lì l'app mette in
  /// coda i seguenti a mano a mano che si leggono.
  final int? ahead;

  /// Lo stesso lavoro con [more] capitoli in più.
  ArchiveJob including(Set<String> more) => ArchiveJob(
        id: id,
        url: url,
        title: title,
        target: target,
        start: start,
        ids: {...?ids, ...more},
        delayMs: delayMs,
        snapshot: snapshot,
        userAgent: userAgent,
        cookies: cookies,
        automatic: automatic,
        ahead: ahead,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'target': target.toJson(),
        'start': ?start,
        if (ids != null) 'ids': ids!.toList(),
        'delayMs': delayMs,
        'snapshot': ?snapshot,
        'userAgent': ?userAgent,
        if (cookies.isNotEmpty) 'cookies': cookies,
        if (automatic) 'automatic': true,
        'ahead': ?ahead,
      };
}

enum ArchiveState { idle, running, waiting }

/// A che punto è il giro in corso.
class ArchiveStatus {
  const ArchiveStatus({
    this.state = ArchiveState.idle,
    this.jobId,
    this.title = '',
    this.total = 0,
    this.done = 0,
    this.failed = 0,
    this.pagesDownloaded = 0,
    this.pagesSkipped = 0,
    this.bytes = 0,
    this.message = '',
    this.updatedAt,
  });

  factory ArchiveStatus.fromJson(Map<String, Object?> json) => ArchiveStatus(
        state: ArchiveState.values.asNameMap()[json['state']] ?? ArchiveState.idle,
        jobId: json['jobId'] as String?,
        title: json['title'] as String? ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        done: (json['done'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
        pagesDownloaded: (json['pagesDownloaded'] as num?)?.toInt() ?? 0,
        pagesSkipped: (json['pagesSkipped'] as num?)?.toInt() ?? 0,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        message: json['message'] as String? ?? '',
        updatedAt: DateTime.tryParse('${json['updatedAt']}'),
      );

  final ArchiveState state;
  final String? jobId;
  final String title;
  final int total;
  final int done;
  final int failed;
  final int pagesDownloaded;
  final int pagesSkipped;
  final int bytes;
  final String message;
  final DateTime? updatedAt;

  double get fraction => total == 0 ? 0 : done / total;

  ArchiveStatus copyWith({
    ArchiveState? state,
    String? title,
    int? total,
    int? done,
    int? failed,
    int? pagesDownloaded,
    int? pagesSkipped,
    int? bytes,
    String? message,
  }) =>
      ArchiveStatus(
        state: state ?? this.state,
        jobId: jobId,
        title: title ?? this.title,
        total: total ?? this.total,
        done: done ?? this.done,
        failed: failed ?? this.failed,
        pagesDownloaded: pagesDownloaded ?? this.pagesDownloaded,
        pagesSkipped: pagesSkipped ?? this.pagesSkipped,
        bytes: bytes ?? this.bytes,
        message: message ?? this.message,
        updatedAt: DateTime.now(),
      );

  Map<String, Object?> toJson() => {
        'state': state.name,
        'jobId': ?jobId,
        'title': title,
        'total': total,
        'done': done,
        'failed': failed,
        'pagesDownloaded': pagesDownloaded,
        'pagesSkipped': pagesSkipped,
        'bytes': bytes,
        'message': message,
        'updatedAt': ?updatedAt?.toIso8601String(),
      };
}

/// Com'è andato un download finito.
class ArchiveOutcome {
  const ArchiveOutcome({
    required this.title,
    required this.ok,
    required this.message,
    required this.finishedAt,
    this.seriesKey,
    this.url,
  });

  factory ArchiveOutcome.fromJson(Map<String, Object?> json) => ArchiveOutcome(
        title: json['title'] as String? ?? '',
        ok: json['ok'] == true,
        message: json['message'] as String? ?? '',
        finishedAt: DateTime.tryParse('${json['finishedAt']}') ?? DateTime.now(),
        seriesKey: json['key'] as String?,
        url: json['url'] as String?,
      );

  final String title;
  final bool ok;
  final String message;
  final DateTime finishedAt;
  final String? seriesKey;

  /// Il link chiesto: un download fallito si riprova da lì.
  final String? url;

  Map<String, Object?> toJson() => {
        'title': title,
        'ok': ok,
        'message': message,
        'finishedAt': finishedAt.toIso8601String(),
        'key': ?seriesKey,
        'url': ?url,
      };
}

/// Le impostazioni del controllo delle serie in corso.
class CheckSettings {
  const CheckSettings({this.minutes, this.wifiOnly = true});

  factory CheckSettings.fromJson(Map<String, Object?> json) => CheckSettings(
        minutes: (json['minutes'] as num?)?.toInt(),
        wifiOnly: json['wifiOnly'] != false,
      );

  /// L'ora del controllo, in minuti dalla mezzanotte; `null` se è spento.
  final int? minutes;
  final bool wifiOnly;

  Map<String, Object?> toJson() => {'minutes': ?minutes, 'wifiOnly': wifiOnly};
}

class ArchiveFiles {
  ArchiveFiles(String supportDirectory)
      : directory = Directory(p.join(supportDirectory, 'archive'));

  final Directory directory;

  File get _queue => File(p.join(directory.path, 'queue.json'));
  File get _status => File(p.join(directory.path, 'status.json'));
  File get _history => File(p.join(directory.path, 'history.json'));
  File get _settings => File(p.join(directory.path, 'settings.json'));
  File get _mutex => File(p.join(directory.path, 'queue.lock'));
  File get runLock => File(p.join(directory.path, 'run.lock'));
  File get ongoing => File(p.join(directory.path, 'ongoing.json'));
  File get _delegated => File(p.join(directory.path, 'server-check.json'));

  /// La cartella di Drive di cui il server collegato controlla ogni giorno
  /// tutta la libreria: le serie del telefono che scendono lì le segue lui,
  /// e controllarle anche da qui scaricherebbe due volte gli stessi capitoli
  /// nella stessa cartella. Un file, perché lo legge anche il controllo ad
  /// app chiusa, che il server non lo conosce.
  Future<String?> delegatedFolder() async => (await readJsonFile(_delegated))?['folderId'] as String?;

  Future<void> delegate(String? folderId) async {
    if (folderId == null) {
      if (await _delegated.exists()) await _delegated.delete();
    } else if (await delegatedFolder() != folderId) {
      await writeAtomically(_delegated, utf8.encode(jsonEncode({'folderId': folderId})));
    }
  }

  /// Le tavole dei capitoli preparati per Drive, finché Drive non le ha.
  Directory staging(String folderId) => Directory(p.join(directory.path, 'staging', folderId));

  Directory get snapshots => Directory(p.join(directory.path, 'pages'));

  /// Le modifiche alla coda passano una alla volta: la scrivono sia l'app
  /// sia il lavoro, in due motori diversi dello stesso processo.
  Future<T> _exclusive<T>(Future<T> Function() body) async {
    await directory.create(recursive: true);
    for (var attempt = 0;; attempt++) {
      try {
        await _mutex.create(exclusive: true);
        break;
      } on FileSystemException {
        // Uno lasciato da un motore morto a metà non vale per sempre.
        final stale = await _mutex.exists() &&
            DateTime.now().difference(await _mutex.lastModified()) > const Duration(seconds: 30);
        if (stale) await _mutex.delete().catchError((_) => _mutex);
        if (attempt > 200) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    try {
      return await body();
    } finally {
      await _mutex.delete().catchError((_) => _mutex);
    }
  }

  Future<List<ArchiveJob>> jobs() async => [
        for (final row in ((await readJsonFile(_queue))?['jobs'] as List? ?? const [])
            .whereType<Map<String, Object?>>())
          ArchiveJob.fromJson(row),
      ];

  Future<void> _writeJobs(List<ArchiveJob> jobs) => writeAtomically(
        _queue,
        utf8.encode(jsonEncode({'jobs': [for (final job in jobs) job.toJson()]})),
      );

  Future<void> enqueue(ArchiveJob job) => _exclusive(() async {
        final queue = await jobs();
        // Quello che sta girando non si tocca: lo toglie il giro quando
        // finisce, e con lui ciò che gli si fosse aggiunto.
        final current = await status();
        final running = current.state == ArchiveState.running ? current.jobId : null;
        final same = queue.indexWhere((other) => other.url == job.url && other.id != running);
        if (same < 0) {
          queue.add(job);
        } else if (!job.automatic) {
          // La stessa serie due volte in coda è un doppione: vale l'ultima
          // richiesta, che è quella che l'utente ha in mente.
          queue[same] = job;
        } else if (queue[same].ids != null) {
          // Un lavoro messo in coda dall'app non prende il posto di un
          // altro: gli aggiunge i suoi capitoli. Uno che prende tutta la
          // serie, o da un capitolo in poi, li comprende già.
          queue[same] = queue[same].including(job.ids ?? const {});
        }
        await _writeJobs(queue);
      });

  /// Il prossimo lavoro, che resta in coda finché non finisce.
  Future<ArchiveJob?> next() async => (await jobs()).firstOrNull;

  Future<void> remove(String id) => _exclusive(() async {
        final queue = await jobs();
        final job = queue.where((job) => job.id == id).firstOrNull;
        if (job == null) return;
        await _writeJobs([for (final other in queue) if (other.id != id) other]);
        final snapshot = job.snapshot;
        if (snapshot != null) await File(snapshot).delete().catchError((_) => File(snapshot));
      });

  Future<ArchiveStatus> status() async =>
      ArchiveStatus.fromJson(await readJsonFile(_status) ?? const {});

  Future<void> writeStatus(ArchiveStatus status) =>
      writeAtomically(_status, utf8.encode(jsonEncode(status.toJson())));

  Future<List<ArchiveOutcome>> history() async => [
        for (final row in ((await readJsonFile(_history))?['outcomes'] as List? ?? const [])
            .whereType<Map<String, Object?>>())
          ArchiveOutcome.fromJson(row),
      ];

  /// Gli ultimi esiti. Scaricando man mano ogni capitolo è un lavoro, e la
  /// stessa serie ne lascia parecchi: l'interfaccia li raccoglie per serie.
  Future<void> remember(ArchiveOutcome outcome) async {
    final rows = [outcome, ...await history()].take(60);
    await writeAtomically(
      _history,
      utf8.encode(jsonEncode({'outcomes': [for (final row in rows) row.toJson()]})),
    );
  }

  Future<void> clearHistory() async {
    if (await _history.exists()) await _history.delete();
  }

  Future<CheckSettings> settings() async =>
      CheckSettings.fromJson(await readJsonFile(_settings) ?? const {});

  Future<void> writeSettings(CheckSettings settings) =>
      writeAtomically(_settings, utf8.encode(jsonEncode(settings.toJson())));

  /// Un giro è in corso: nel lavoro in primo piano.
  Future<bool> running() async {
    if (!await runLock.exists()) return false;
    return DateTime.now().difference(await runLock.lastModified()) < const Duration(minutes: 2);
  }
}
