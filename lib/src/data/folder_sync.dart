/// La cartella del telefono e quella di Drive, tenute uguali dall'app.
///
/// Prima lo faceva FolderSync, fuori dall'app. Qui lo fa Kagami, con lo
/// stesso account con cui legge Drive: in una direzione sola o in tutt'e
/// due, a richiesta o a un'ora fissa (`FolderSyncWorker.kt`).
///
/// Il confronto non guarda i contenuti: una libreria sono decine di migliaia
/// di file e gigabyte, e calcolarne le impronte dal telefono a ogni giro è
/// proprio il costo che gli indici MALF esistono per evitare. Si ricorda
/// invece com'era ogni file all'ultimo giro ([SyncRecord]): misura e data
/// sul telefono, impronta su Drive. Cambiato da una parte sola vuol dire
/// copiarlo di là; cambiato da tutt'e due vince il più recente.
///
/// Tre regole che non dipendono dalla direzione:
///
/// * **gli indici sono del server.** `library.json`, `index.json`,
///   `pages.json`, `series.json` e `chapter.json` scendono e basta: uno
///   scritto dal telefono che salisse su Drive prenderebbe il posto di
///   quello di MangaArchive;
/// * **niente si cancella se non lo si è chiesto.** Un file tolto da una
///   parte, senza «Propaga le cancellazioni», resta dall'altra e non torna
///   indietro. Con le cancellazioni accese, da Drive si toglie solo nel
///   cestino; la decisione è [planSync], che non tocca niente e si prova da
///   sola;
/// * **«Libera spazio» decide per sé.** Quello che toglie lo annota
///   ([SyncFiles.release]) e il giro seguente lo prende per quello che è —
///   tolto da lì, di proposito — prima di confrontare ([releaseRecords]):
///   non lo riporta, anche al primo giro, e non lo toglie dall'altra parte,
///   anche con le cancellazioni accese. Le cancellazioni propagate sono
///   quelle fatte fuori dall'app;
/// * **un giro alla volta.** L'app aperta e il lavoro programmato girano
///   nello stesso processo con due motori: il lucchetto su disco
///   ([_SyncLock]) è ciò che impedisce che copino gli stessi file insieme.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../format/malf.dart';
import 'drive.dart';

/// Da che parte vanno i file.
enum SyncDirection {
  /// Da Drive al telefono.
  download,

  /// Dal telefono a Drive.
  upload,

  /// In tutt'e due.
  both;

  bool get downloads => this != upload;
  bool get uploads => this != download;

  String get label => switch (this) {
        download => 'Da Drive',
        upload => 'Verso Drive',
        both => 'Entrambe',
      };
}

/// Come l'utente ha impostato la sincronizzazione su questo telefono.
///
/// Non sta nel database, e quindi non viaggia col backup: una cartella del
/// telefono ha senso solo su quel telefono. Sta in un file perché la legge
/// anche il lavoro programmato, che gira senza l'app e senza il suo
/// database; per lo stesso motivo porta con sé cartella locale e cartella
/// di Drive, riscritte dall'app quando cambiano.
class SyncSettings {
  const SyncSettings({
    this.direction,
    this.deletions = false,
    this.scheduleMinutes,
    this.wifiOnly = true,
    this.root,
    this.folderId,
  });

  factory SyncSettings.fromJson(Map<String, Object?> json) => SyncSettings(
        direction: SyncDirection.values
            .where((value) => value.name == json['direction'])
            .firstOrNull,
        deletions: json['deletions'] == true,
        scheduleMinutes: (json['schedule'] as num?)?.toInt(),
        wifiOnly: json['wifiOnly'] != false,
        root: json['root'] as String?,
        folderId: json['folder'] as String?,
      );

  /// `null` vuol dire spenta.
  final SyncDirection? direction;

  /// Se togliere da una parte ciò che è stato tolto dall'altra.
  final bool deletions;

  /// L'ora del giro programmato, in minuti dalla mezzanotte; `null` se non
  /// ce n'è uno.
  final int? scheduleMinutes;

  /// Il giro programmato aspetta una rete che non si paga a consumo: una
  /// libreria sono gigabyte.
  final bool wifiOnly;

  final String? root;
  final String? folderId;

  bool get enabled => direction != null;

  /// Se c'è tutto quello che serve per fare un giro.
  bool get ready => direction != null && root != null && folderId != null;

  bool get scheduled => ready && scheduleMinutes != null;

  SyncSettings copyWith({
    SyncDirection? direction,
    bool clearDirection = false,
    bool? deletions,
    int? scheduleMinutes,
    bool clearSchedule = false,
    bool? wifiOnly,
    String? root,
    String? folderId,
    bool clearPlaces = false,
  }) =>
      SyncSettings(
        direction: clearDirection ? null : direction ?? this.direction,
        deletions: deletions ?? this.deletions,
        scheduleMinutes:
            clearSchedule ? null : scheduleMinutes ?? this.scheduleMinutes,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        root: clearPlaces ? root : root ?? this.root,
        folderId: clearPlaces ? folderId : folderId ?? this.folderId,
      );

  Map<String, Object?> toJson() => {
        'direction': ?direction?.name,
        'deletions': deletions,
        'schedule': ?scheduleMinutes,
        'wifiOnly': wifiOnly,
        'root': ?root,
        'folder': ?folderId,
      };

  @override
  bool operator ==(Object other) =>
      other is SyncSettings &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Com'è andato un giro.
class SyncReport {
  const SyncReport({
    required this.at,
    this.downloaded = 0,
    this.uploaded = 0,
    this.deletedLocal = 0,
    this.trashed = 0,
    this.failed = 0,
    this.error,
    this.scheduled = false,
  });

  factory SyncReport.fromJson(Map<String, Object?> json) => SyncReport(
        at: DateTime.parse(json['at'] as String),
        downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
        uploaded: (json['uploaded'] as num?)?.toInt() ?? 0,
        deletedLocal: (json['deletedLocal'] as num?)?.toInt() ?? 0,
        trashed: (json['trashed'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
        error: json['error'] as String?,
        scheduled: json['scheduled'] == true,
      );

  final DateTime at;
  final int downloaded;
  final int uploaded;
  final int deletedLocal;
  final int trashed;

  /// File che non sono passati: si riprovano al giro seguente.
  final int failed;

  /// Perché il giro si è fermato, se si è fermato.
  final String? error;

  /// Partito all'ora programmata, non da un tocco.
  final bool scheduled;

  bool get changed => downloaded + uploaded + deletedLocal + trashed > 0;

  Map<String, Object?> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'downloaded': downloaded,
        'uploaded': uploaded,
        'deletedLocal': deletedLocal,
        'trashed': trashed,
        'failed': failed,
        'error': ?error,
        if (scheduled) 'scheduled': true,
      };
}

/// A che punto è il giro in corso.
class SyncProgress {
  const SyncProgress(this.phase, {this.done = 0, this.total = 0});

  final SyncPhase phase;
  final int done;
  final int total;

  double? get fraction => total == 0 ? null : done / total;
}

enum SyncPhase {
  /// Si elencano le cartelle di Drive.
  listing,

  /// Si guarda la cartella del telefono e si decide cosa fare.
  comparing,

  /// Si copiano i file.
  transferring,
}

/// Un file del telefono: misura e data di modifica in millisecondi.
typedef LocalFile = ({int size, int modified});

/// Un file di Drive, come lo confronta il piano.
typedef RemoteFile = ({String key, int size, int modified});

/// Com'era un file all'ultimo giro in cui le due parti erano d'accordo.
///
/// Una parte `null` vuol dire che da quella parte il file è stato tolto e
/// che la cancellazione non si è propagata: il file resta dove è, e non si
/// ricopia finché non cambia.
class SyncRecord {
  const SyncRecord({this.size, this.modified, this.remote});

  factory SyncRecord.of(LocalFile local, RemoteFile remote) =>
      SyncRecord(size: local.size, modified: local.modified, remote: remote.key);

  static SyncRecord fromJson(List<Object?> row) => SyncRecord(
        size: (row[0] as num?)?.toInt(),
        modified: (row[1] as num?)?.toInt(),
        remote: row[2] as String?,
      );

  final int? size;
  final int? modified;
  final String? remote;

  bool get hasLocal => size != null;
  bool get hasRemote => remote != null;
  bool get whole => hasLocal && hasRemote;

  bool localChanged(LocalFile file) =>
      file.size != size || file.modified != modified;

  List<Object?> toJson() => [size, modified, remote];

  @override
  bool operator ==(Object other) =>
      other is SyncRecord &&
      other.size == size &&
      other.modified == modified &&
      other.remote == remote;

  @override
  int get hashCode => Object.hash(size, modified, remote);
}

enum SyncActionKind { download, upload, deleteLocal, trashRemote }

typedef SyncAction = ({SyncActionKind kind, String path});

/// Cosa fare: le copie e le cancellazioni, e i ricordi da aggiornare
/// subito perché non richiedono di muovere niente (`null` toglie il
/// ricordo).
typedef SyncPlan = ({
  List<SyncAction> actions,
  Map<String, SyncRecord?> records,
});

/// I file che scrive MangaArchive. Dal telefono non salgono mai.
const Set<String> serverOwnedFiles = {
  libraryIndexFile,
  seriesIndexFile,
  pagesIndexFile,
  'series.json',
  'chapter.json',
};

bool isServerOwned(String path) =>
    serverOwnedFiles.contains(p.posix.basename(path));

/// Se un percorso fa parte della libreria. Restano fuori i file nascosti —
/// FolderSync e Android ne lasciano — e i pezzi a metà dei download
/// (`.part`, `.tmp`), che diventano file veri solo a copia finita.
bool isSyncable(String path) {
  for (final segment in p.posix.split(path)) {
    if (segment.startsWith('.') ||
        segment.endsWith('.part') ||
        segment.endsWith('.tmp')) {
      return false;
    }
  }
  return true;
}

/// Decide cosa fare, senza toccare niente.
SyncPlan planSync({
  required Map<String, LocalFile> local,
  required Map<String, RemoteFile> remote,
  required Map<String, SyncRecord> state,
  required SyncDirection direction,
  required bool deletions,
}) {
  final actions = <SyncAction>[];
  final records = <String, SyncRecord?>{};
  void act(SyncActionKind kind, String path) =>
      actions.add((kind: kind, path: path));

  for (final path in {...local.keys, ...remote.keys, ...state.keys}) {
    final here = local[path];
    final there = remote[path];
    final before = state[path];
    if (here == null && there == null) {
      if (before != null) records[path] = null;
      continue;
    }
    final owned = isServerOwned(path);
    // Gli indici seguono solo la discesa: in sola salita non si toccano.
    if (owned && direction == SyncDirection.upload) continue;
    final down = direction.downloads;
    final up = direction.uploads && !owned;

    if (here != null && there != null) {
      if (before == null || !before.whole) {
        // Mai confrontati: due file della stessa misura si prendono per
        // uguali. È ciò che rende istantaneo il primo giro su una cartella
        // che FolderSync ha già riempito.
        if (here.size == there.size) {
          records[path] = SyncRecord.of(here, there);
        } else {
          final pick = _winner(here, there, down: down, up: up);
          if (pick != null) act(pick, path);
        }
        continue;
      }
      final hereChanged = before.localChanged(here);
      final thereChanged = before.remote != there.key;
      if (!hereChanged && !thereChanged) continue;
      if (hereChanged && thereChanged) {
        final pick = _winner(here, there, down: down, up: up);
        if (pick != null) act(pick, path);
      } else if (thereChanged && down) {
        act(SyncActionKind.download, path);
      } else if (hereChanged && up) {
        act(SyncActionKind.upload, path);
      }
      continue;
    }

    if (here != null) {
      if (before == null) {
        if (up) act(SyncActionKind.upload, path);
      } else if (before.hasRemote) {
        // Era su Drive e non c'è più.
        if (deletions && down) {
          act(SyncActionKind.deleteLocal, path);
        } else {
          records[path] =
              SyncRecord(size: here.size, modified: here.modified);
        }
      }
      continue;
    }

    there!;
    if (before == null) {
      if (down) act(SyncActionKind.download, path);
    } else if (before.hasLocal) {
      // Era sul telefono e non c'è più.
      if (deletions && up) {
        act(SyncActionKind.trashRemote, path);
      } else {
        records[path] = SyncRecord(remote: there.key);
      }
    } else if (before.remote != there.key && down) {
      // Tolto dal telefono, ma su Drive è arrivata una versione nuova.
      act(SyncActionKind.download, path);
    }
  }
  return (actions: actions, records: records);
}

/// Da che parte «Libera spazio» ha tolto una cartella.
enum SyncSide { local, remote }

/// Una cartella della libreria tolta di proposito da una parte sola.
typedef SyncRelease = ({String path, SyncSide side});

/// I ricordi che rendono una cartella tolta da [SyncRelease.side] un file
/// da lasciare stare, non da riportare né da togliere anche dall'altra
/// parte. `null` toglie il ricordo: il file non c'è più da nessuna parte.
///
/// Si scrivono per tutto ciò che sta sotto la cartella, anche per i file
/// mai visti da un giro: è il caso della sincronizzazione accesa dopo aver
/// liberato spazio, che altrimenti riscaricherebbe tutto al primo giro.
Map<String, SyncRecord?> releaseRecords({
  required Map<String, LocalFile> local,
  required Map<String, RemoteFile> remote,
  required Map<String, SyncRecord> state,
  required List<SyncRelease> releases,
}) {
  final result = <String, SyncRecord?>{};
  for (final release in releases) {
    final prefix = '${release.path}/';
    switch (release.side) {
      case SyncSide.local:
        for (final path in {...remote.keys, ...state.keys}) {
          if (!path.startsWith(prefix) || local.containsKey(path)) continue;
          final key = remote[path]?.key ?? result[path]?.remote ?? state[path]?.remote;
          result[path] = key == null ? null : SyncRecord(remote: key);
        }
      case SyncSide.remote:
        for (final path in {...local.keys, ...state.keys}) {
          if (!path.startsWith(prefix) || remote.containsKey(path)) continue;
          final file = local[path];
          result[path] = file == null
              ? null
              : SyncRecord(size: file.size, modified: file.modified);
        }
    }
  }
  return result;
}

/// Quando le due copie sono diverse e non si sa chi ha ragione: la più
/// recente, se la direzione lascia scegliere.
SyncActionKind? _winner(
  LocalFile here,
  RemoteFile there, {
  required bool down,
  required bool up,
}) {
  if (down && up) {
    return here.modified > there.modified
        ? SyncActionKind.upload
        : SyncActionKind.download;
  }
  if (down) return SyncActionKind.download;
  if (up) return SyncActionKind.upload;
  return null;
}

/// Un altro giro è già in corso: nell'app o nel lavoro programmato.
class SyncBusy implements Exception {
  const SyncBusy();

  @override
  String toString() => 'Una sincronizzazione è già in corso';
}

class SyncCancelled implements Exception {
  const SyncCancelled();

  @override
  String toString() => 'Sincronizzazione interrotta';
}

/// I file della sincronizzazione nello spazio dell'app: impostazioni,
/// ricordi dell'ultimo giro, esito, lucchetto.
class SyncFiles {
  SyncFiles(String supportDirectory)
      : directory = Directory(p.join(supportDirectory, 'sync'));

  final Directory directory;

  File get settings => File(p.join(directory.path, 'settings.json'));
  File get state => File(p.join(directory.path, 'state.json'));
  File get report => File(p.join(directory.path, 'last.json'));
  File get lock => File(p.join(directory.path, 'lock'));
  File get releases => File(p.join(directory.path, 'released.json'));

  /// Annota che «Libera spazio» ha tolto queste cartelle (percorsi relativi
  /// alla libreria) da [side]. Si annota anche a sincronizzazione spenta:
  /// accesa dopo, non deve riportarle.
  Future<void> release(Iterable<String> paths, SyncSide side) async {
    final rows = await readReleases();
    final added = [
      for (final path in paths) (path: path, side: side),
    ];
    if (added.isEmpty) return;
    await _writeReleases([...rows, ...added]);
  }

  Future<List<SyncRelease>> readReleases() async {
    final json = await _read(releases);
    if (json is! List) return const [];
    return [
      for (final row in json)
        if (row is Map && row['path'] is String)
          (
            path: row['path'] as String,
            side: row['side'] == SyncSide.remote.name
                ? SyncSide.remote
                : SyncSide.local,
          ),
    ];
  }

  /// Toglie le annotazioni di cui un giro ha già tenuto conto. Rilegge il
  /// file: mentre il giro andava, «Libera spazio» può averne aggiunte.
  Future<void> consumeReleases(List<SyncRelease> consumed) async {
    if (consumed.isEmpty) return;
    final done = consumed.toSet();
    await _writeReleases([
      for (final row in await readReleases())
        if (!done.remove(row)) row,
    ]);
  }

  Future<void> _writeReleases(List<SyncRelease> rows) => _write(
        releases,
        jsonEncode([
          for (final row in rows) {'path': row.path, 'side': row.side.name},
        ]),
      );

  Future<SyncSettings> readSettings() async {
    final json = await _read(settings);
    return json is Map<String, Object?>
        ? SyncSettings.fromJson(json)
        : const SyncSettings();
  }

  Future<void> writeSettings(SyncSettings value) =>
      _write(settings, jsonEncode(value.toJson()));

  Future<SyncReport?> readReport() async {
    final json = await _read(report);
    try {
      return json is Map<String, Object?> ? SyncReport.fromJson(json) : null;
    } on Object {
      return null;
    }
  }

  Future<void> writeReport(SyncReport value) =>
      _write(report, jsonEncode(value.toJson()));

  /// Se un giro è in corso adesso, qui o nell'altro motore.
  Future<bool> busy() => _SyncLock(lock).held();

  static Future<Object?> _read(File file) async {
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }
  }

  /// Scritto a parte e poi rinominato: l'altro motore può leggerlo proprio
  /// ora, e un file a metà non lo deve vedere.
  static Future<void> _write(File file, String text) async {
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.part');
    await pending.writeAsString(text, flush: true);
    await pending.rename(file.path);
  }
}

/// Il lucchetto di un giro: un file che chi lo tiene ritocca ogni tanto.
///
/// Un lucchetto del sistema operativo non servirebbe: i due motori stanno
/// nello stesso processo, e per il sistema sono la stessa persona. Uno
/// lasciato da un giro morto a metà — l'app uccisa — vale finché non è
/// vecchio di [_stale].
class _SyncLock {
  _SyncLock(this.file);

  final File file;
  Timer? _beat;

  static const Duration _stale = Duration(minutes: 2);
  static const Duration _interval = Duration(seconds: 30);

  Future<bool> held() async {
    if (!await file.exists()) return false;
    final touched = await file.lastModified();
    return DateTime.now().difference(touched) < _stale;
  }

  Future<void> acquire() async {
    if (await held()) throw const SyncBusy();
    await file.parent.create(recursive: true);
    await file.writeAsString('$pid');
    _beat = Timer.periodic(_interval, (_) {
      file.setLastModified(DateTime.now()).catchError((_) {});
    });
  }

  Future<void> release() async {
    _beat?.cancel();
    await file.delete().catchError((_) => file);
  }
}

/// Un giro di sincronizzazione.
class FolderSync {
  FolderSync({
    required this.remote,
    required this.root,
    required this.folderId,
    required this.direction,
    required this.deletions,
    required this.files,
    this.scheduled = false,
  });

  final SyncRemote remote;
  final String root;
  final String folderId;
  final SyncDirection direction;
  final bool deletions;
  final SyncFiles files;
  final bool scheduled;

  /// Copie insieme: le tavole sono piccole, e con una sola la sincronizzazione
  /// aspetterebbe la rete fra un file e l'altro.
  static const int _atOnce = 3;

  /// Cartelle chieste a Drive in una ricerca sola: ogni `in parents` allunga
  /// l'indirizzo, e trenta stanno larghe sotto il limite.
  static const int _batch = 30;

  final Map<String, DriveItem> _remoteFiles = {};
  final Map<String, String> _remoteFolders = {};
  final Map<String, Future<String>> _creating = {};
  late Map<String, SyncRecord> _state;
  bool _dirty = false;

  Future<SyncReport> run({
    void Function(SyncProgress progress)? onProgress,
    bool Function()? cancelled,
  }) async {
    final lock = _SyncLock(files.lock);
    await lock.acquire();
    var downloaded = 0, uploaded = 0, deletedLocal = 0, trashed = 0, failed = 0;
    String? error;
    try {
      onProgress?.call(const SyncProgress(SyncPhase.listing));
      _state = await _loadState();
      await _listRemote(cancelled);
      onProgress?.call(const SyncProgress(SyncPhase.comparing));
      final remoteView = {
        for (final MapEntry(:key, :value) in _remoteFiles.entries)
          key: (
            key: value.contentKey,
            size: value.size ?? 0,
            modified: value.modified?.millisecondsSinceEpoch ?? 0,
          ),
      };
      final root = this.root;
      final state = _state;
      final direction = this.direction;
      final deletions = this.deletions;
      final releases = await files.readReleases();
      // Decine di migliaia di `stat()` e un confronto altrettanto lungo: fuori
      // dal thread dell'interfaccia, che nell'app aperta è lo stesso di Dart.
      final (released, plan) = await Isolate.run(() {
        final local = _scanLocal(root);
        final released = releaseRecords(
          local: local,
          remote: remoteView,
          state: state,
          releases: releases,
        );
        return (
          released,
          planSync(
            local: local,
            remote: remoteView,
            state: {
              for (final MapEntry(:key, :value) in state.entries)
                if (!released.containsKey(key)) key: value,
              for (final MapEntry(:key, :value) in released.entries)
                key: ?value,
            },
            direction: direction,
            deletions: deletions,
          ),
        );
      });
      _apply(released);
      _apply(plan.records);
      // I ricordi nuovi si salvano prima di dimenticare le annotazioni: un
      // giro che si interrompe adesso non deve perdere né gli uni né le altre.
      await _saveState();
      await files.consumeReleases(releases);

      final queue = [...plan.actions];
      final total = queue.length;
      var done = 0;
      var lastSave = DateTime.now();
      onProgress?.call(SyncProgress(SyncPhase.transferring, total: total));
      final touched = <String>{};
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          if (cancelled?.call() ?? false) throw const SyncCancelled();
          final action = queue.removeAt(0);
          try {
            await _perform(action);
            switch (action.kind) {
              case SyncActionKind.download:
                downloaded++;
              case SyncActionKind.upload:
                uploaded++;
              case SyncActionKind.deleteLocal:
                deletedLocal++;
                touched.add(p.posix.dirname(action.path));
              case SyncActionKind.trashRemote:
                trashed++;
            }
          } on DriveOffline {
            rethrow;
          } on DriveAuthRequired {
            rethrow;
          } on DriveException {
            failed++;
          } on FileSystemException {
            failed++;
          }
          onProgress?.call(
            SyncProgress(SyncPhase.transferring, done: ++done, total: total),
          );
          // Un giro lungo interrotto a metà — rete, sistema, app chiusa —
          // riprende da dove era, non da capo.
          if (DateTime.now().difference(lastSave) > const Duration(seconds: 20)) {
            lastSave = DateTime.now();
            await _saveState();
          }
        }
      }

      await Future.wait([for (var i = 0; i < _atOnce; i++) worker()]);
      await _prune(touched);
    } on SyncBusy {
      rethrow;
    } on Object catch (caught) {
      error = switch (caught) {
        DriveException(:final message) => message,
        SyncCancelled() => '$caught',
        FileSystemException() => 'La cartella del telefono non si legge',
        _ => 'Sincronizzazione non riuscita',
      };
    } finally {
      try {
        if (_dirty) await _saveState();
      } finally {
        await lock.release();
      }
    }
    final report = SyncReport(
      at: DateTime.now().toUtc(),
      downloaded: downloaded,
      uploaded: uploaded,
      deletedLocal: deletedLocal,
      trashed: trashed,
      failed: failed,
      error: error,
      scheduled: scheduled,
    );
    await files.writeReport(report);
    return report;
  }

  /// Tutto l'albero di Drive, un livello alla volta e molte cartelle per
  /// richiesta: Drive non sa cercare "tutto quello che sta sotto".
  Future<void> _listRemote(bool Function()? cancelled) async {
    _remoteFolders[''] = folderId;
    final pathOf = <String, String>{folderId: ''};
    var level = [folderId];
    while (level.isNotEmpty) {
      final next = <String>[];
      for (var start = 0; start < level.length; start += _batch) {
        if (cancelled?.call() ?? false) throw const SyncCancelled();
        final batch = level.sublist(
          start,
          (start + _batch).clamp(0, level.length),
        );
        for (final item in await remote.childrenOf(batch)) {
          final parent = item.parents.firstWhere(
            pathOf.containsKey,
            orElse: () => '',
          );
          final base = pathOf[parent];
          if (base == null || item.name.contains('/')) continue;
          final path = base.isEmpty ? item.name : '$base/${item.name}';
          if (!isSyncable(path)) continue;
          if (item.folder) {
            if (_remoteFolders.containsKey(path)) continue;
            _remoteFolders[path] = item.id;
            pathOf[item.id] = path;
            next.add(item.id);
          } else if (item.size != null) {
            // Senza misura è un documento di Google, non un file: non si
            // scarica così com'è e non fa parte di un archivio MALF.
            final other = _remoteFiles[path];
            // Due file con lo stesso nome nella stessa cartella, che Drive
            // permette: conta il più recente.
            if (other == null ||
                (item.modified ?? DateTime(0))
                    .isAfter(other.modified ?? DateTime(0))) {
              _remoteFiles[path] = item;
            }
          }
        }
      }
      level = next;
    }
  }

  Future<void> _perform(SyncAction action) async {
    final path = action.path;
    final file = File(p.joinAll([root, ...p.posix.split(path)]));
    switch (action.kind) {
      case SyncActionKind.download:
        final item = _remoteFiles[path]!;
        await file.parent.create(recursive: true);
        final partial = File('${file.path}.part');
        await remote.download(item.id, partial);
        await partial.rename(file.path);
        final modified = item.modified;
        if (modified != null) {
          // Con la data di Drive il confronto fra le due copie resta giusto
          // anche per chi non ha ancora un ricordo di questo file.
          await file.setLastModified(modified).catchError((_) {});
        }
        _record(path, await _local(file), item);
      case SyncActionKind.upload:
        final stat = await file.stat();
        final existing = _remoteFiles[path];
        final item = await remote.upload(
          file,
          id: existing?.id,
          name: existing == null ? p.posix.basename(path) : null,
          parentId: existing == null
              ? await _folder(p.posix.dirname(path))
              : null,
          modified: stat.modified,
        );
        _remoteFiles[path] = item;
        _record(path, (size: stat.size, modified: stat.modified.millisecondsSinceEpoch), item);
      case SyncActionKind.deleteLocal:
        await file.delete();
        _state.remove(path);
        _dirty = true;
      case SyncActionKind.trashRemote:
        await remote.trash(_remoteFiles[path]!.id);
        _remoteFiles.remove(path);
        _state.remove(path);
        _dirty = true;
    }
  }

  /// La cartella di Drive per un percorso, creata se manca. Due caricamenti
  /// nella stessa cartella nuova aspettano la stessa creazione, altrimenti
  /// Drive ne farebbe due con lo stesso nome.
  Future<String> _folder(String path) {
    if (path == '.' || path.isEmpty) return Future.value(folderId);
    final known = _remoteFolders[path];
    if (known != null) return Future.value(known);
    return _creating[path] ??= () async {
      final parent = await _folder(p.posix.dirname(path));
      final created = await remote.createFolder(p.posix.basename(path), parent);
      _remoteFolders[path] = created.id;
      return created.id;
    }();
  }

  /// Le cartelle rimaste vuote dopo le cancellazioni se ne vanno anche loro:
  /// una cartella di capitolo vuota direbbe che il capitolo è sul telefono.
  Future<void> _prune(Set<String> directories) async {
    final seen = <String>{};
    for (var directory in directories) {
      while (directory != '.' && directory.isNotEmpty && seen.add(directory)) {
        final folder = Directory(p.joinAll([root, ...p.posix.split(directory)]));
        try {
          if (!await folder.list().isEmpty) break;
          await folder.delete();
        } on FileSystemException {
          break;
        }
        directory = p.posix.dirname(directory);
      }
    }
  }

  static Future<LocalFile> _local(File file) async {
    final stat = await file.stat();
    return (size: stat.size, modified: stat.modified.millisecondsSinceEpoch);
  }

  void _record(String path, LocalFile local, DriveItem item) {
    _state[path] =
        SyncRecord(size: local.size, modified: local.modified, remote: item.contentKey);
    _dirty = true;
  }

  void _apply(Map<String, SyncRecord?> records) {
    for (final MapEntry(:key, :value) in records.entries) {
      if (value == null) {
        _state.remove(key);
      } else {
        _state[key] = value;
      }
    }
    if (records.isNotEmpty) _dirty = true;
  }

  /// I ricordi valgono per una coppia di cartelle: cambiata una delle due,
  /// si riparte da capo, confrontando le misure.
  Future<Map<String, SyncRecord>> _loadState() async {
    final file = files.state;
    final root = this.root;
    final folderId = this.folderId;
    return Isolate.run(() {
      if (!file.existsSync()) return <String, SyncRecord>{};
      try {
        final json = jsonDecode(file.readAsStringSync());
        if (json is! Map ||
            json['root'] != root ||
            json['folder'] != folderId ||
            json['files'] is! Map) {
          return <String, SyncRecord>{};
        }
        return {
          for (final MapEntry(:key, :value) in (json['files'] as Map).entries)
            if (key is String && value is List) key: SyncRecord.fromJson(value),
        };
      } on FormatException {
        return <String, SyncRecord>{};
      }
    });
  }

  Future<void> _saveState() async {
    _dirty = false;
    final file = files.state;
    final snapshot = {
      'root': root,
      'folder': folderId,
      'files': {
        for (final MapEntry(:key, :value) in _state.entries) key: value.toJson(),
      },
    };
    final text = await Isolate.run(() => jsonEncode(snapshot));
    await SyncFiles._write(file, text);
  }
}

/// La cartella del telefono, file per file, con percorsi come quelli di
/// Drive. Gira in un isolate: sono decine di migliaia di `stat()`.
Map<String, LocalFile> _scanLocal(String root) {
  final result = <String, LocalFile>{};
  final directory = Directory(root);
  if (!directory.existsSync()) {
    throw FileSystemException('Cartella non trovata', root);
  }
  for (final entity in directory.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = p.posix.joinAll(p.split(p.relative(entity.path, from: root)));
    if (!isSyncable(path)) continue;
    final stat = entity.statSync();
    result[path] = (size: stat.size, modified: stat.modified.millisecondsSinceEpoch);
  }
  return result;
}
