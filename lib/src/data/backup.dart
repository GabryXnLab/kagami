/// Portare via i propri dati, e riportarli indietro.
///
/// Da quando lo stato utente vive nel database dell'app e non più in
/// `reading/`, il backup è l'unica cosa che lo fa sopravvivere a una
/// reinstallazione o a un cambio di telefono: non è una comodità, è il
/// meccanismo che prima era la cartella sincronizzata.
///
/// Per questo, accanto all'esportazione a mano, ne esiste una automatica che
/// scrive dentro la libreria: quella cartella è già sincronizzata verso Drive,
/// quindi una copia lì è fuori dal telefono senza chiedere niente a nessuno.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../format/malf.dart';
import '../format/reading.dart';
import 'db/database.dart';
import 'user_repository.dart';

const String backupFormat = 'kagami-backup';
const int backupVersion = 1;

/// Quante copie automatiche tenere. Servono a rimediare a un errore recente,
/// non a fare da archivio storico.
const int keptBackups = 5;

/// Ogni quanto rifare la copia automatica.
const Duration autoBackupInterval = Duration(days: 1);

/// Cosa fare dei dati già presenti quando si importa.
enum ImportMode {
  /// Unisce: i capitoli letti si sommano e per il resto vince il record più
  /// recente. È la scelta giusta quando si ricostruisce un dispositivo.
  merge,

  /// Sostituisce: i dati locali spariscono e restano solo quelli del file.
  replace,
}

/// Cosa conteneva il file: serve a dirlo prima di scrivere qualcosa.
class BackupSummary {
  const BackupSummary({
    required this.createdAt,
    required this.series,
    required this.chapters,
    required this.collections,
  });

  final DateTime? createdAt;
  final int series;
  final int chapters;
  final int collections;
}

class BackupService {
  BackupService(this.db, {this.profileId = defaultProfileId});

  final KagamiDatabase db;
  final String profileId;

  String fileName([DateTime? when]) {
    final now = (when ?? DateTime.now()).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'kagami-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.json.gz';
  }

  /// Tutti i dati personali in un archivio compresso. Il JSON dentro è
  /// leggibile: un backup che solo l'app sa aprire è un backup a metà.
  Future<Uint8List> export() async {
    final states = await (db.select(db.seriesStates)
          ..where((row) => row.profileId.equals(profileId)))
        .get();
    final reads = await (db.select(db.chapterReads)
          ..where((row) => row.profileId.equals(profileId)))
        .get();
    final progresses = await (db.select(db.progresses)
          ..where((row) => row.profileId.equals(profileId)))
        .get();
    final sessions = await (db.select(db.readingSessions)
          ..where((row) => row.profileId.equals(profileId)))
        .get();
    final settings = await db.select(db.appSettings).get();
    final bookmarks = await (db.select(db.bookmarks)
          ..where((row) => row.profileId.equals(profileId)))
        .get();
    final readerSettings = await (db.select(db.readerSettingsRows)
          ..where((row) => row.profileId.equals(profileId)))
        .get();

    final data = <String, Object?>{
      'format': backupFormat,
      'formatVersion': backupVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'series': [
        for (final row in states)
          {
            'key': row.seriesKey,
            'status': row.status,
            if (row.rating != null) 'rating': row.rating,
            'favorite': row.favorite,
            if (row.notes != null) 'notes': row.notes,
            if (row.startedAt != null)
              'startedAt': row.startedAt!.toIso8601String(),
            if (row.finishedAt != null)
              'finishedAt': row.finishedAt!.toIso8601String(),
            if (row.lastOpenedAt != null)
              'lastOpenedAt': row.lastOpenedAt!.toIso8601String(),
            if (row.muted) 'muted': true,
            if (row.reachedChapter != null)
              'reachedChapter': row.reachedChapter,
            'updatedAt': row.updatedAt.toIso8601String(),
          },
      ],
      'chapterReads': [
        for (final row in reads)
          {
            'key': row.seriesKey,
            'chapterId': row.chapterId,
            'readAt': row.readAt.toIso8601String(),
            'estimated': row.estimated,
          },
      ],
      'progress': [
        for (final row in progresses)
          {
            'key': row.seriesKey,
            'chapterId': row.chapterId,
            'page': row.page,
            'pageCount': row.pageCount,
            if (row.offset > 0) 'offset': row.offset,
            'updatedAt': row.updatedAt.toIso8601String(),
          },
      ],
      'sessions': [
        for (final row in sessions)
          {
            'key': row.seriesKey,
            'chapterId': row.chapterId,
            'startedAt': row.startedAt.toIso8601String(),
            'endedAt': row.endedAt.toIso8601String(),
            'pagesRead': row.pagesRead,
          },
      ],
      'bookmarks': [
        for (final row in bookmarks)
          {
            'key': row.seriesKey,
            'chapterId': row.chapterId,
            'page': row.page,
            if (row.note != null) 'note': row.note,
            'createdAt': row.createdAt.toIso8601String(),
          },
      ],
      'collections': [
        for (final collection
            in await UserRepository(db, profileId: profileId).loadCollections())
          collection.toJson(),
      ],
      'readerSettings': [
        for (final row in readerSettings)
          {
            'key': row.seriesKey,
            'mode': row.mode,
            'direction': row.direction,
            'fit': row.fit,
            'background': row.background,
            'brightness': row.brightness,
            'keepAwake': row.keepAwake,
            'doublePage': row.doublePage,
            'showPageNumber': row.showPageNumber,
            'showProgress': row.showProgress,
            'showScrollTop': row.showScrollTop,
            'autoScroll': row.autoScroll,
          },
      ],
      'settings': {
        for (final row in settings) row.key: row.value,
      },
      // A parte, perché i backup di prima leggono `settings` come testo.
      'settingsUpdatedAt': {
        for (final row in settings)
          if (row.updatedAt case final at?) row.key: at.toUtc().toIso8601String(),
      },
    };
    return Uint8List.fromList(
      gzip.encode(utf8.encode(const JsonEncoder.withIndent('  ').convert(data))),
    );
  }

  /// Legge un file senza toccare niente: è ciò che permette di dire all'utente
  /// cosa sta per importare prima che lo importi.
  Future<BackupSummary?> inspect(Uint8List bytes) async {
    final data = _decode(bytes);
    if (data == null) return null;
    return BackupSummary(
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
      series: (data['series'] as List? ?? const []).length,
      chapters: (data['chapterReads'] as List? ?? const []).length,
      collections: (data['collections'] as List? ?? const []).length,
    );
  }

  Future<bool> import(Uint8List bytes, ImportMode mode) async {
    final data = _decode(bytes);
    if (data == null) return false;
    final repository = UserRepository(db, profileId: profileId);

    await db.transaction(() async {
      if (mode == ImportMode.replace) {
        await (db.delete(db.chapterReads)..where(_is)).go();
        await (db.delete(db.progresses)..where(_is)).go();
        await (db.delete(db.readingSessions)..where(_is)).go();
        await (db.delete(db.bookmarks)..where(_is)).go();
        await (db.delete(db.readerSettingsRows)..where(_is)).go();
        await (db.delete(db.seriesStates)..where(_is)).go();
        await (db.delete(db.collectionRows)..where(_is)).go();
      }

      for (final row in _rows(data['series'])) {
        final key = row['key'];
        if (key is! String) continue;
        final incoming = SeriesState(
          status: ShelfStatus.parse(row['status']),
          rating: (row['rating'] as num?)?.toInt(),
          favorite: row['favorite'] == true,
          notes: row['notes'] as String?,
          updatedAt: _time(row['updatedAt']),
          lastOpenedAt: _time(row['lastOpenedAt']),
          muted: row['muted'] == true,
          reachedChapter: row['reachedChapter'] as String?,
        );
        // In fusione vince il record più recente, campo per campo: è la stessa
        // regola con cui si fondevano due dispositivi che scrivevano in
        // `reading/`, e per lo stesso motivo.
        final existing = mode == ImportMode.merge
            ? (await repository.loadStates())[key]
            : null;
        await repository.saveSeriesState(
          key,
          existing == null ? incoming : existing.mergeWith(incoming),
        );
      }

      for (final row in _rows(data['chapterReads'])) {
        final key = row['key'];
        final chapterId = row['chapterId'];
        if (key is! String || chapterId is! String) continue;
        await db.into(db.chapterReads).insertOnConflictUpdate(
              ChapterReadsCompanion.insert(
                profileId: profileId,
                seriesKey: key,
                chapterId: chapterId,
                readAt: _time(row['readAt']) ?? DateTime.now().toUtc(),
                estimated: Value(row['estimated'] == true),
              ),
            );
      }

      for (final row in _rows(data['progress'])) {
        final key = row['key'];
        final chapterId = row['chapterId'];
        if (key is! String || chapterId is! String) continue;
        await repository.saveProgress(
          key,
          ReadingProgress(
            chapterId: chapterId,
            page: (row['page'] as num?)?.toInt() ?? 0,
            pageCount: (row['pageCount'] as num?)?.toInt() ?? 0,
            offset: ((row['offset'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
            updatedAt: _time(row['updatedAt']) ?? DateTime.now().toUtc(),
          ),
        );
      }

      // Sessioni e segnalibri non hanno un «più recente»: o ci sono già o
      // no. L'indice unico scarta quelli già presenti, anche i doppioni che
      // un backup di prima si porta dentro.
      final sessions = [
        for (final row in _rows(data['sessions']))
          if ((
            row['key'],
            row['chapterId'],
            _time(row['startedAt']),
            _time(row['endedAt']),
          )
              case (
                final String key,
                final String chapterId,
                final DateTime startedAt,
                final DateTime endedAt,
              ))
            ReadingSessionsCompanion.insert(
              profileId: profileId,
              seriesKey: key,
              chapterId: chapterId,
              startedAt: startedAt,
              endedAt: endedAt,
              pagesRead: Value((row['pagesRead'] as num?)?.toInt() ?? 0),
            ),
      ];
      final bookmarks = [
        for (final row in _rows(data['bookmarks']))
          if ((row['key'], row['chapterId'])
              case (final String key, final String chapterId))
            BookmarksCompanion.insert(
              profileId: profileId,
              seriesKey: key,
              chapterId: chapterId,
              page: (row['page'] as num?)?.toInt() ?? 0,
              note: Value(row['note'] as String?),
              createdAt: _time(row['createdAt']) ?? DateTime.now().toUtc(),
            ),
      ];
      await db.batch((batch) {
        batch.insertAll(db.readingSessions, sessions,
            mode: InsertMode.insertOrIgnore);
        batch.insertAll(db.bookmarks, bookmarks,
            mode: InsertMode.insertOrIgnore);
      });

      for (final row in _rows(data['readerSettings'])) {
        final key = row['key'];
        if (key is! String) continue;
        await db.into(db.readerSettingsRows).insertOnConflictUpdate(
              ReaderSettingsRowsCompanion.insert(
                profileId: profileId,
                seriesKey: key,
                mode: row['mode'] as String? ?? 'continuous',
                direction: row['direction'] as String? ?? 'rtl',
                fit: row['fit'] as String? ?? 'width',
                background: row['background'] as String? ?? 'black',
                brightness: Value((row['brightness'] as num?)?.toDouble() ?? 1),
                keepAwake: Value(row['keepAwake'] != false),
                doublePage: Value(row['doublePage'] == true),
                showPageNumber: Value(row['showPageNumber'] != false),
                showProgress: Value(row['showProgress'] != false),
                showScrollTop: Value(row['showScrollTop'] != false),
                autoScroll: Value((row['autoScroll'] as num?)?.toDouble() ?? 0),
              ),
            );
      }

      final collections = _rows(data['collections'])
          .where((row) => row['id'] is String)
          .map(Collection.fromJson)
          .toList();
      if (collections.isNotEmpty) {
        final existing = mode == ImportMode.merge
            ? await repository.loadCollections()
            : const <Collection>[];
        final byId = {
          for (final collection in existing) collection.id: collection,
          for (final collection in collections) collection.id: collection,
        };
        await repository.replaceCollections(byId.values.toList());
      }

      final settings = data['settings'];
      if (settings is Map) {
        final times = data['settingsUpdatedAt'];
        final local = {
          for (final row in await db.select(db.appSettings).get())
            row.key: row.updatedAt,
        };
        for (final MapEntry(:key, :value) in settings.entries) {
          if (key is! String || value is! String) continue;
          final at = _time(times is Map ? times[key] : null);
          // In fusione vince la scrittura più recente, come per le serie. Un
          // valore senza data viene da un backup di prima e cede a uno
          // datato; fra due senza data resta la regola di allora, il file.
          if (mode == ImportMode.merge && local.containsKey(key)) {
            final mine = local[key];
            if (mine != null && (at == null || !at.isAfter(mine))) continue;
          }
          // La data resta quella del file, anche assente: a importare non si
          // sceglie niente di nuovo.
          await db.into(db.appSettings).insertOnConflictUpdate(
                AppSettingsCompanion.insert(
                  key: key,
                  value: value,
                  updatedAt: Value(at),
                ),
              );
        }
      }
    });
    return true;
  }

  /// La copia automatica dentro la libreria, se è ora di rifarla.
  ///
  /// Sta in `reading/backup/` perché `reading/` è la cartella che MALF dà al
  /// client, ed è già sincronizzata: una copia lì viaggia verso Drive con i
  /// manga, senza che l'app debba sapere cos'è Drive.
  Future<File?> autoBackup(String libraryRoot) async {
    final directory = Directory(p.join(libraryRoot, readingDirectory, 'backup'));
    await directory.create(recursive: true);
    final existing = await _backups(directory);
    if (existing.isNotEmpty) {
      final last = await existing.first.stat();
      if (DateTime.now().difference(last.modified) < autoBackupInterval) {
        return null;
      }
    }
    final file = File(p.join(directory.path, fileName()));
    await file.writeAsBytes(await export(), flush: true);
    for (final old in (await _backups(directory)).skip(keptBackups)) {
      await old.delete();
    }
    return file;
  }

  /// Le copie automatiche, dalla più recente.
  Future<List<File>> backupsIn(String libraryRoot) => _backups(
        Directory(p.join(libraryRoot, readingDirectory, 'backup')),
      );

  Future<List<File>> _backups(Directory directory) async {
    if (!await directory.exists()) return const [];
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json.gz'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Le righe del profilo corrente. Ogni tabella dei dati personali ha la
  /// stessa colonna, quindi la condizione è sempre questa.
  Expression<bool> _is(dynamic row) =>
      (row.profileId as GeneratedColumn<String>).equals(profileId);

  Map<String, Object?>? _decode(Uint8List bytes) {
    try {
      final text = utf8.decode(gzip.decode(bytes));
      final data = jsonDecode(text);
      if (data is! Map<String, Object?>) return null;
      if (data['format'] != backupFormat) return null;
      if ((data['formatVersion'] as num? ?? 0) > backupVersion) return null;
      return data;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static List<Map<String, Object?>> _rows(Object? value) =>
      value is List ? value.whereType<Map<String, Object?>>().toList() : const [];

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
