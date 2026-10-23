/// Togliere da soli i capitoli che non servono più: quelli già letti e, di
/// una serie che non si legge da un po', anche quelli da leggere.
///
/// È «Libera spazio» ([clearReadLeftovers]) senza il foglio, acceso
/// dall'utente nelle impostazioni, e vale per ogni posto della libreria: le
/// cartelle sul telefono — cartella scelta e spazio dell'app — e Drive, dove i
/// capitoli vanno nel cestino. Lo stato di lettura sta nel database e non si
/// tocca; la cache di Drive si svuota già da sé (`planCache`).
///
/// Le regole dipendono dal tempo, quindi devono valere anche ad app chiusa.
/// Il lavoro programmato (`AutoCleanupWorker.kt`) però non ha né il database
/// né la libreria: l'app gli lascia un piano su disco ([AutoCleanupFiles]),
/// con ogni capitolo e il momento da cui si può togliere, e lui toglie ciò
/// che è scaduto. L'app rifà il piano ogni volta che lo stato si pubblica —
/// all'avvio e uscendo dal lettore —, e anche lei toglie ciò che è scaduto
/// mentre era chiusa.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;

import '../format/malf.dart';
import '../format/reading.dart';
import 'drive.dart';
import 'drive_library.dart';
import 'folder_sync.dart';
import 'library.dart';
import 'library_location.dart';
import 'library_repository.dart';
import 'network.dart';

/// Se aprendo la scheda va proposto il foglio «Libera spazio». Dove la pulizia
/// automatica dei letti è accesa li toglie già lei, a meno che la serie ne sia
/// [excluded] (una raccolta con «tieni i capitoli»): allora il foglio serve.
bool shouldOfferCleanup({required bool autoRead, required bool excluded}) =>
    !autoRead || excluded;

/// Le due regole, fra le impostazioni del database e quindi nel backup.
class AutoCleanupSettings {
  const AutoCleanupSettings({
    this.read = false,
    this.idle = false,
    this.pause = false,
    this.idleDays = defaultIdleDays,
  });

  factory AutoCleanupSettings.fromJson(Map<String, Object?> json) => AutoCleanupSettings(
        read: json['read'] == true,
        idle: json['idle'] == true,
        pause: json['pause'] == true,
        idleDays: switch (json['idleDays']) {
          final int days when days > 0 => days,
          _ => defaultIdleDays,
        },
      );

  static const int defaultIdleDays = 14;

  /// Toglie i capitoli già letti.
  final bool read;

  /// Toglie anche quelli da leggere di una serie in cui non si legge niente
  /// da [idleDays] giorni.
  final bool idle;
  final int idleDays;

  /// Mette in pausa le serie «in lettura» lasciate per [idleDays] giorni
  /// ([dueForPause]). Non tocca i file, quindi non fa parte di [active].
  final bool pause;

  bool get active => read || idle;

  AutoCleanupSettings copyWith({bool? read, bool? idle, bool? pause, int? idleDays}) => AutoCleanupSettings(
        read: read ?? this.read,
        idle: idle ?? this.idle,
        pause: pause ?? this.pause,
        idleDays: idleDays ?? this.idleDays,
      );

  Map<String, Object?> toJson() => {'read': read, 'idle': idle, 'pause': pause, 'idleDays': idleDays};

  @override
  bool operator ==(Object other) =>
      other is AutoCleanupSettings && other.read == read && other.idle == idle && other.pause == pause && other.idleDays == idleDays;

  @override
  int get hashCode => Object.hash(read, idle, pause, idleDays);
}

/// L'ultima volta che si è letto qualcosa della serie: una posizione salvata
/// o un capitolo finito ([lastRead], dal database, senza le date stimate).
/// Aprire la scheda non conta: guardare non è leggere.
DateTime? seriesActivity(SeriesState state, DateTime? lastRead) {
  DateTime? latest = lastRead;
  for (final position in state.positions.values) {
    if (latest == null || position.updatedAt.isAfter(latest)) latest = position.updatedAt;
  }
  return latest;
}

/// Se una serie «in lettura» va messa in pausa. Conta anche l'ultima
/// modifica allo stato: chi rimette a mano «in lettura» una serie appena
/// messa in pausa non deve vedersela rimettere in pausa, e un gesto sulla
/// scheda ne rimanda la pausa.
bool dueForPause(SeriesState state, DateTime? activity, int idleDays, DateTime now) {
  if (state.status != ShelfStatus.reading || activity == null) return false;
  final limit = Duration(days: idleDays);
  if (now.difference(activity) < limit) return false;
  final touched = state.updatedAt;
  return touched == null || now.difference(touched) >= limit;
}

/// Se «man mano» deve lasciare stare una serie perché la seconda regola ne
/// toglierebbe i capitoli da leggere. Anche una serie mai letta: i capitoli
/// che le si scaricassero davanti scadrebbero dal loro arrivo, e si
/// riscaricherebbero subito dopo.
bool idleForReadAhead(
  AutoCleanupSettings settings,
  DateTime? activity,
  DateTime now, {
  bool excluded = false,
}) =>
    !excluded &&
    settings.idle && (activity == null || now.difference(activity) >= Duration(days: settings.idleDays));

/// Un capitolo in un posto della libreria: una cartella sul telefono
/// ([directory]) o una cartella su Drive ([remote], relativa alla serie).
class StoredChapter {
  const StoredChapter.phone({
    required this.series,
    required this.chapter,
    required String this.directory,
    required DateTime this.arrivedAt,
    this.synced,
  })  : seriesPath = null,
        remote = null;

  StoredChapter.drive({
    required this.series,
    required this.chapter,
    required String this.seriesPath,
    required String this.remote,
    required this.arrivedAt,
  })  : directory = null,
        synced = '$seriesPath/$remote';

  final String series;
  final String chapter;
  final String? directory;
  final String? seriesPath;
  final String? remote;

  /// Quando il capitolo è arrivato: un capitolo appena scaricato non si
  /// toglie perché la serie non si legge da settimane. Su Drive è
  /// l'`archivedAt` dell'indice, che può mancare.
  final DateTime? arrivedAt;

  /// Il percorso relativo alla libreria, come lo vede la sincronizzazione:
  /// per una cartella del telefono solo se sta in quella scelta dall'utente.
  final String? synced;
}

/// Un capitolo che si toglierà a partire da [due].
class CleanupItem {
  const CleanupItem({
    required this.series,
    required this.chapter,
    required this.due,
    this.directory,
    this.seriesPath,
    this.remote,
    this.synced,
  });

  factory CleanupItem.fromJson(Map<String, Object?> json) => CleanupItem(
        series: json['series'] as String,
        chapter: json['chapter'] as String,
        due: DateTime.parse(json['due'] as String).toUtc(),
        directory: json['directory'] as String?,
        seriesPath: json['seriesPath'] as String?,
        remote: json['remote'] as String?,
        synced: json['synced'] as String?,
      );

  final String series;
  final String chapter;
  final DateTime due;
  final String? directory;
  final String? seriesPath;
  final String? remote;
  final String? synced;

  bool get onDrive => remote != null;

  Map<String, Object?> toJson() => {
        'series': series,
        'chapter': chapter,
        'due': due.toIso8601String(),
        'directory': ?directory,
        'seriesPath': ?seriesPath,
        'remote': ?remote,
        'synced': ?synced,
      };
}

/// Il piano, senza toccare niente: per ogni capitolo, se e da quando una
/// delle due regole lo toglie.
///
/// Un capitolo letto si toglie subito. Uno da leggere quando sono passati
/// [AutoCleanupSettings.idleDays] giorni sia dall'ultima lettura della serie
/// sia dal suo arrivo — la posizione dentro il capitolo, se c'è, resta nel
/// database come il resto. Su Drive la seconda regola vale solo per le serie
/// già cominciate: lì c'è tutto l'archivio, e una serie messa da parte per
/// dopo perderebbe ogni capitolo due settimane dopo l'archiviazione.
List<CleanupItem> planAutoCleanup({
  required AutoCleanupSettings settings,
  required Iterable<StoredChapter> chapters,
  required SeriesState Function(String series) state,
  required DateTime? Function(String series) activity,
  bool Function(String series)? excluded,
}) {
  final items = <CleanupItem>[];
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  for (final chapter in chapters) {
    if (excluded != null && excluded(chapter.series)) continue;
    final read = state(chapter.series).readChapters.contains(chapter.chapter);
    DateTime? due;
    if (read) {
      if (settings.read) due = epoch;
    } else if (settings.idle) {
      final last = activity(chapter.series);
      final arrived = chapter.arrivedAt;
      final drive = chapter.remote != null;
      if (arrived != null && (!drive || last != null)) {
        final since = last != null && last.isAfter(arrived) ? last : arrived;
        due = since.toUtc().add(Duration(days: settings.idleDays));
      }
    }
    if (due == null) continue;
    items.add(CleanupItem(
      series: chapter.series,
      chapter: chapter.chapter,
      due: due,
      directory: chapter.directory,
      seriesPath: chapter.seriesPath,
      remote: chapter.remote,
      synced: chapter.synced,
    ));
  }
  return items;
}

/// I capitoli che stanno davvero sul telefono, per una serie, nelle cartelle
/// della libreria che la tengono. Una lettura di cartella per scaffale, e una
/// di stato per capitolo.
Future<List<StoredChapter>> phoneChaptersOf(
  SeriesEntry entry,
  SeriesChapters chapters,
  List<LibraryShelf> holders,
) async {
  final found = <StoredChapter>[];
  for (final shelf in holders.whereType<LibraryRepository>()) {
    final present = await shelf.presentChapters(entry);
    if (present.isEmpty) continue;
    for (final chapter in chapters.index.chapters) {
      final path = chapter.path;
      if (path == null) continue;
      final relative = p.posix.normalize(path);
      if (!present.contains(relative)) continue;
      final directory = shelf.locate(entry, path);
      final DateTime arrivedAt;
      try {
        arrivedAt = (await Directory(directory).stat()).modified.toUtc();
      } on IOException {
        continue;
      }
      found.add(StoredChapter.phone(
        series: entry.key,
        chapter: chapter.id,
        directory: directory,
        arrivedAt: arrivedAt,
        synced: shelf.private ? null : '${entry.path}/$relative',
      ));
    }
  }
  return found;
}

/// I capitoli di una serie che Drive serve ancora: quelli del suo indice
/// meno quelli già tolti.
Future<List<StoredChapter>> driveChaptersOf(SeriesEntry entry, DriveRepository drive) async {
  final index = await drive.loadSeries(entry);
  if (index == null) return const [];
  final withdrawn = await drive.withdrawnChapters(entry);
  return [
    for (final chapter in index.readable)
      if (!withdrawn.contains(p.posix.normalize(chapter.path!)))
        StoredChapter.drive(
          series: entry.key,
          chapter: chapter.id,
          seriesPath: entry.path,
          remote: p.posix.normalize(chapter.path!),
          arrivedAt: chapter.archivedAt?.toUtc(),
        ),
  ];
}

/// Il piano su disco, nello spazio dell'app: lo scrive l'app, lo legge anche
/// il lavoro programmato. Porta la cartella di Drive, perché il lavoro sappia
/// dove togliere senza le impostazioni dell'app.
class AutoCleanupFiles {
  AutoCleanupFiles(String supportDirectory) : directory = Directory(p.join(supportDirectory, 'cleanup'));

  final Directory directory;

  File get plan => File(p.join(directory.path, 'plan.json'));

  Future<({String? folder, List<CleanupItem> items})> readPlan() async {
    const empty = (folder: null, items: <CleanupItem>[]);
    try {
      final json = jsonDecode(await plan.readAsString());
      if (json is! Map<String, Object?>) return empty;
      return (
        folder: json['folder'] as String?,
        items: [
          for (final row in json['items'] as List? ?? const [])
            if (row is Map<String, Object?>) CleanupItem.fromJson(row),
        ],
      );
    } on PathNotFoundException {
      return empty;
    } on FormatException {
      return empty;
    } on TypeError {
      return empty;
    }
  }

  /// Scritto a parte e poi rinominato, come i file della sincronizzazione:
  /// l'altro motore lo può leggere proprio ora.
  Future<void> writePlan(List<CleanupItem> items, {String? folder}) async {
    await directory.create(recursive: true);
    final pending = File('${plan.path}.part');
    await pending.writeAsString(
      jsonEncode({
        'folder': ?folder,
        'items': [for (final item in items) item.toJson()],
      }),
      flush: true,
    );
    await pending.rename(plan.path);
  }
}

/// Sposta nel cestino di Drive i capitoli [paths] della serie in
/// [seriesPath] ([DriveRepository.withdrawPaths]).
typedef DriveWithdraw = Future<void> Function(String seriesPath, List<String> paths);

/// Com'è andato un giro: i capitoli tolti, per serie, e quando scade il
/// prossimo (`null`, niente in attesa).
typedef AutoCleanupOutcome = ({Map<String, Set<String>> removed, Map<String, Set<String>> fromDrive, DateTime? next});

/// Toglie i capitoli del piano scaduti a [now], tranne quelli delle serie in
/// [hold] (aperte nel lettore), e riscrive il piano con ciò che resta. Quelli
/// su Drive solo con [withdraw]; senza, aspettano l'app.
///
/// Con un giro di sincronizzazione in corso aspettano le cartelle
/// sincronizzate e Drive, come nel foglio: il giro le potrebbe riscrivere o
/// confrontare prima dell'annotazione. Anche senza rete o senza permesso di
/// scrivere su Drive si riprova fra [retry].
Future<AutoCleanupOutcome> runAutoCleanup(
  AutoCleanupFiles files,
  SyncFiles sync, {
  DateTime? now,
  Set<String> hold = const {},
  DriveWithdraw? withdraw,
  Duration retry = const Duration(minutes: 30),
}) async {
  final at = (now ?? DateTime.now()).toUtc();
  final plan = await files.readPlan();
  final items = plan.items;
  final due = [
    for (final item in items)
      if (!item.due.isAfter(at) && !hold.contains(item.series) && (!item.onDrive || withdraw != null)) item,
  ];
  if (due.isEmpty) return (removed: const <String, Set<String>>{}, fromDrive: const <String, Set<String>>{}, next: _next(items, at));
  final busy = due.any((item) => item.synced != null) && await sync.busy();
  var waiting = busy;
  final taken = [
    for (final item in due)
      if (!busy || item.synced == null) item,
  ];
  final done = <CleanupItem>{};
  // Annotate prima di togliere: un'annotazione su una cartella che c'è
  // ancora non fa niente, una cancellazione non annotata il giro seguente
  // la porterebbe anche dall'altra parte.
  final phone = [for (final item in taken) if (!item.onDrive) item];
  await sync.release([for (final item in phone) ?item.synced], SyncSide.local);
  for (final item in phone) {
    final directory = Directory(item.directory!);
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      done.add(item);
    } on FileSystemException {
      // Una cartella che non si toglie ora si riprova al giro dopo.
    }
  }
  final remote = <String, List<CleanupItem>>{};
  for (final item in taken) {
    if (item.onDrive) remote.putIfAbsent(item.seriesPath!, () => []).add(item);
  }
  for (final MapEntry(key: seriesPath, value: group) in remote.entries) {
    try {
      await sync.release([for (final item in group) ?item.synced], SyncSide.remote);
      await withdraw!(seriesPath, [for (final item in group) item.remote!]);
      done.addAll(group);
    } on DriveAuthRequired {
      // Il permesso di scrivere lo chiede l'app, accendendo la regola:
      // riprovare da qui ogni mezz'ora non lo darebbe. Si riprova dall'app.
    } on DriveException {
      // Senza rete o con Drive che non risponde: si riprova, e la serie
      // resta servita finché non è tolta davvero.
      waiting = true;
    }
  }
  final left = [
    for (final item in items)
      if (!done.contains(item)) item,
  ];
  await files.writePlan(left, folder: plan.folder);
  final next = _next(left, at);
  Map<String, Set<String>> bySeries(Iterable<CleanupItem> items) {
    final result = <String, Set<String>>{};
    for (final item in items) {
      result.putIfAbsent(item.series, () => {}).add(item.chapter);
    }
    return result;
  }

  return (
    removed: bySeries(done),
    fromDrive: bySeries(done.where((item) => item.onDrive)),
    next: waiting && (next == null || next.isAfter(at.add(retry))) ? at.add(retry) : next,
  );
}

/// La prima scadenza dopo [at]: quelle già passate sono capitoli tenuti
/// fermi dal lettore, che l'app riprova da sé uscendone.
DateTime? _next(List<CleanupItem> items, DateTime at) {
  DateTime? next;
  for (final item in items) {
    if (!item.due.isAfter(at)) continue;
    if (next == null || item.due.isBefore(next)) next = item.due;
  }
  return next;
}

/// Programma il lavoro che toglie i capitoli ad app chiusa, alla prossima
/// scadenza del piano, o lo toglie se non ce ne sono.
class AutoCleanupScheduler {
  const AutoCleanupScheduler();

  static const MethodChannel _channel = MethodChannel('kagami/cleanup-schedule');

  bool get _native => !kIsWeb && Platform.isAndroid;

  Future<void> apply(DateTime? next) async {
    if (!_native) return;
    if (next == null) {
      await _channel.invokeMethod<void>('cancel');
    } else {
      await _channel.invokeMethod<void>('schedule', {'at': next.millisecondsSinceEpoch});
    }
  }
}

/// Il giro dentro il motore acceso da `AutoCleanupWorker.kt`, ad app chiusa.
/// Dice sempre `done`, con la prossima scadenza (-1, nessuna): è ciò che il
/// lavoro aspetta per spegnere il motore e mettere in coda il seguente.
///
/// Drive si apre solo se c'è qualcosa da togliere lì: il token lo dà
/// `google_sign_in` senza attività, dal permesso di scrivere già concesso
/// accendendo la regola.
Future<void> runScheduledAutoCleanup() async {
  const channel = MethodChannel('kagami/cleanup-worker');
  DateTime? next;
  DriveClient? client;
  try {
    final directories = await AppDirectories.resolve();
    final files = AutoCleanupFiles(directories.support);
    final folder = (await files.readPlan()).folder;
    DriveRepository? repository;
    final outcome = await runAutoCleanup(
      files,
      SyncFiles(directories.support),
      withdraw: folder == null
          ? null
          : (seriesPath, paths) async {
              if (repository == null) {
                await GoogleSignIn.instance.initialize();
                client = DriveClient(DriveAuth().writeToken, network: NetworkMonitor.instance);
                repository = DriveRepository(
                  client: client!,
                  folderId: folder,
                  stateDirectory: p.join(directories.support, 'drive'),
                  // Togliere capitoli non passa dalla cache: il limite non conta.
                  files: DriveFileCache(Directory(p.join(directories.cache, 'drive')), limitBytes: 1 << 30),
                );
              }
              await repository!.withdrawPaths(seriesPath, paths, client!);
            },
    );
    next = outcome.next;
  } finally {
    client?.close();
    await channel.invokeMethod<void>('done', {'next': next?.millisecondsSinceEpoch ?? -1});
  }
}
