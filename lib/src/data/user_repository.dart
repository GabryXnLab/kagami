/// L'unico punto da cui l'app legge e scrive i dati personali.
///
/// Sopra c'è il grafo dei provider, che tiene in memoria la fotografia dello
/// stato; sotto c'è il database. Qui in mezzo stanno le due traduzioni: dalle
/// righe ai modelli di dominio ([SeriesState], [Collection]) e viceversa.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../format/malf.dart';
import '../format/reading.dart';
import 'arrivals.dart';
import 'db/database.dart';

/// Quanto può stare ferma una sessione di lettura prima di considerarla
/// finita. Un lettore lasciato aperto per la notte non è tempo di lettura.
const Duration sessionIdleLimit = Duration(minutes: 30);

/// Una riga di cronologia: un capitolo e quando lo si è finito.
class HistoryEntry {
  const HistoryEntry({
    required this.seriesKey,
    required this.chapterId,
    required this.readAt,
  });

  final String seriesKey;
  final String chapterId;
  final DateTime readAt;

  /// Il giorno locale a cui appartiene, che è il modo in cui la cronologia si
  /// raggruppa e in cui l'utente ricorda di aver letto.
  DateTime get day {
    final local = readAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class UserRepository {
  UserRepository(this.db, {this.profileId = defaultProfileId});

  final KagamiDatabase db;
  final String profileId;

  // ---------------------------------------------------------------- lettura

  /// Lo stato di tutte le serie, in tre query invece di una per serie.
  Future<Map<String, SeriesState>> loadStates() async {
    final rows = await (db.select(db.seriesStates)
          ..where((row) => row.profileId.equals(profileId)))
        .get();
    final reads = await (db.select(db.chapterReads)
          ..where((row) => row.profileId.equals(profileId)))
        .get();
    final progresses = await (db.select(db.progresses)
          ..where((row) => row.profileId.equals(profileId)))
        .get();

    final chapters = <String, Set<String>>{};
    for (final read in reads) {
      chapters.putIfAbsent(read.seriesKey, () => <String>{}).add(read.chapterId);
    }
    final positions = <String, Map<String, ReadingProgress>>{};
    for (final row in progresses) {
      positions.putIfAbsent(row.seriesKey, () => {})[row.chapterId] =
          ReadingProgress(
        chapterId: row.chapterId,
        page: row.page,
        pageCount: row.pageCount,
        updatedAt: row.updatedAt,
        offset: row.offset,
      );
    }

    final states = <String, SeriesState>{
      for (final row in rows)
        row.seriesKey: SeriesState(
          status: ShelfStatus.parse(row.status),
          rating: row.rating,
          favorite: row.favorite,
          readChapters: chapters[row.seriesKey] ?? const {},
          positions: positions[row.seriesKey] ?? const {},
          notes: row.notes,
          updatedAt: row.updatedAt,
          lastOpenedAt: row.lastOpenedAt,
          muted: row.muted,
        ),
    };
    // Una serie può avere capitoli letti senza riga di stato solo se qualcosa
    // è andato storto a metà scrittura: meglio mostrarla letta che perderla.
    for (final key in chapters.keys.followedBy(positions.keys)) {
      states.putIfAbsent(
        key,
        () => SeriesState(
          readChapters: chapters[key] ?? const {},
          positions: positions[key] ?? const {},
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
    return states;
  }

  Future<List<Collection>> loadCollections() async {
    final rows = await (db.select(db.collectionRows)
          ..where((row) => row.profileId.equals(profileId))
          ..orderBy([(row) => OrderingTerm(expression: row.position)]))
        .get();
    final items = await (db.select(db.collectionItems)
          ..orderBy([(row) => OrderingTerm(expression: row.position)]))
        .get();
    final members = <String, List<String>>{};
    for (final item in items) {
      members.putIfAbsent(item.collectionId, () => []).add(item.seriesKey);
    }
    return [
      for (final row in rows)
        Collection(
          id: row.id,
          name: row.name,
          seriesKeys: members[row.id] ?? const [],
          color: row.color,
          order: row.position,
          updatedAt: row.updatedAt,
        ),
    ];
  }

  // ---------------------------------------------------------------- scrittura

  /// Salva i campi della serie. I capitoli letti e la posizione hanno una
  /// tabella ciascuno e passano dai metodi dedicati.
  Future<void> saveSeriesState(String key, SeriesState state) async {
    final existing = await _row(key);
    final now = DateTime.now().toUtc();
    await db.into(db.seriesStates).insertOnConflictUpdate(
          SeriesStatesCompanion.insert(
            profileId: profileId,
            seriesKey: key,
            status: Value(state.status.wireValue ?? 'none'),
            rating: Value(state.rating),
            favorite: Value(state.favorite),
            notes: Value(state.notes),
            // Non si riscrive: la mette `_ensureStarted`, magari proprio
            // mentre questa riga si legge, e una copia letta prima la
            // cancellerebbe.
            finishedAt: Value(
              state.status == ShelfStatus.completed
                  ? (existing?.finishedAt ?? now)
                  : null,
            ),
            lastOpenedAt: Value(state.lastOpenedAt ?? existing?.lastOpenedAt),
            muted: Value(state.muted),
            updatedAt: state.updatedAt ?? now,
          ),
        );
  }

  /// Segna o toglie capitoli letti. [at] serve all'importazione, che di una
  /// data vera non ne ha: quelle dedotte restano marcate come tali.
  Future<void> markChapters(
    String key,
    Iterable<String> chapterIds,
    bool read, {
    DateTime? at,
    bool estimated = false,
  }) async {
    final ids = chapterIds.toList(growable: false);
    if (ids.isEmpty) return;
    final when = at ?? DateTime.now().toUtc();
    await db.transaction(() async {
      if (!read) {
        await (db.delete(db.chapterReads)
              ..where((row) =>
                  row.profileId.equals(profileId) &
                  row.seriesKey.equals(key) &
                  row.chapterId.isIn(ids)))
            .go();
        return;
      }
      await db.batch((batch) {
        batch.insertAllOnConflictUpdate(db.chapterReads, [
          for (final id in ids)
            ChapterReadsCompanion.insert(
              profileId: profileId,
              seriesKey: key,
              chapterId: id,
              readAt: when,
              estimated: Value(estimated),
            ),
        ]);
      });
      await _ensureStarted(key, when);
    });
  }

  /// Una posizione più vecchia di quella già scritta per lo stesso capitolo
  /// non la sostituisce: fondendo un backup vince la più recente, come per
  /// il resto dello stato.
  Future<void> saveProgress(String key, ReadingProgress progress) async {
    final row = ProgressesCompanion.insert(
      profileId: profileId,
      seriesKey: key,
      chapterId: progress.chapterId,
      page: progress.page,
      pageCount: progress.pageCount,
      offset: Value(progress.offset),
      updatedAt: progress.updatedAt,
    );
    await db.into(db.progresses).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            where: (old) =>
                old.updatedAt.isSmallerOrEqualValue(progress.updatedAt),
          ),
        );
    await _ensureStarted(key, progress.updatedAt);
  }

  /// Quando l'utente ha guardato la serie l'ultima volta: è il riferimento con
  /// cui si dice se un capitolo è "nuovo".
  Future<void> touchSeries(String key) async {
    final now = DateTime.now().toUtc();
    final existing = await _row(key);
    if (existing == null) {
      await db.into(db.seriesStates).insert(
            SeriesStatesCompanion.insert(
              profileId: profileId,
              seriesKey: key,
              lastOpenedAt: Value(now),
              updatedAt: now,
            ),
          );
      return;
    }
    await (db.update(db.seriesStates)
          ..where((row) =>
              row.profileId.equals(profileId) & row.seriesKey.equals(key)))
        .write(SeriesStatesCompanion(lastOpenedAt: Value(now)));
  }

  /// Le raccolte si riscrivono per intero: sono poche decine e il codice che
  /// ne mantenesse le differenze costerebbe più di quanto risparmia.
  Future<void> replaceCollections(List<Collection> collections) =>
      db.transaction(() async {
        await (db.delete(db.collectionRows)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
        await db.batch((batch) {
          batch.insertAll(db.collectionRows, [
            for (var index = 0; index < collections.length; index++)
              CollectionRowsCompanion.insert(
                id: collections[index].id,
                profileId: profileId,
                name: collections[index].name,
                color: Value(collections[index].color),
                position: Value(index),
                updatedAt: collections[index].updatedAt ?? DateTime.now().toUtc(),
              ),
          ]);
          batch.insertAll(db.collectionItems, [
            for (final collection in collections)
              for (var index = 0; index < collection.seriesKeys.length; index++)
                CollectionItemsCompanion.insert(
                  collectionId: collection.id,
                  seriesKey: collection.seriesKeys[index],
                  position: Value(index),
                ),
          ]);
        });
      });

  Future<SeriesStateRow?> _row(String key) => (db.select(db.seriesStates)
        ..where((row) =>
            row.profileId.equals(profileId) & row.seriesKey.equals(key)))
      .getSingleOrNull();

  /// La data della prima lettura, che serve a dire quando una serie è stata
  /// iniziata: si scrive una volta sola e non si tocca più.
  ///
  /// Senza leggere prima: la posizione e il capitolo finito arrivano insieme
  /// a fine capitolo, e due "non c'è ancora, la inserisco" in parallelo
  /// finivano con il secondo respinto dal vincolo di unicità.
  Future<void> _ensureStarted(String key, DateTime when) async {
    await db.into(db.seriesStates).insert(
          SeriesStatesCompanion.insert(
            profileId: profileId,
            seriesKey: key,
            startedAt: Value(when),
            updatedAt: when,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await (db.update(db.seriesStates)
          ..where((row) =>
              row.profileId.equals(profileId) &
              row.seriesKey.equals(key) &
              row.startedAt.isNull()))
        .write(SeriesStatesCompanion(startedAt: Value(when)));
  }

  // ------------------------------------------------------------ importazione

  /// Porta dentro il vecchio `reading/` la prima volta che si apre una
  /// libreria che ne ha uno.
  ///
  /// Da qui in poi quei file non si scrivono più: restano dov'erano, perché
  /// l'app non cancella niente dalla libreria, ma non sono più la verità. I
  /// capitoli letti non avevano una data: prendono quella dello stato della
  /// serie e restano marcati come dedotti, così le statistiche per giorno non
  /// li scambiano per letture di quel momento.
  Future<bool> importLegacyReading(String root) async {
    final marker = 'imported.reading:$root';
    if (await readSetting(marker) != null) return false;

    final states = await _readJson(
      File(p.join(root, readingDirectory, 'state.json')),
    );
    final collections = await _readJson(
      File(p.join(root, readingDirectory, 'collections.json')),
    );
    await writeSetting(marker, DateTime.now().toUtc().toIso8601String());
    if (states == null && collections == null) return false;

    final series = states?['series'];
    if (series is Map) {
      for (final entry in series.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! Map<String, Object?>) continue;
        final state = SeriesState.fromJson(value);
        await saveSeriesState(key, state);
        await markChapters(
          key,
          state.readChapters,
          true,
          at: state.updatedAt,
          estimated: true,
        );
        for (final progress in state.positions.values) {
          await saveProgress(key, progress);
        }
      }
    }

    final rows = collections?['collections'];
    if (rows is List) {
      final existing = await loadCollections();
      final imported = rows
          .whereType<Map<String, Object?>>()
          .where((row) => row['id'] is String)
          .map(Collection.fromJson)
          .toList();
      await replaceCollections([...existing, ...imported]);
    }
    return true;
  }

  Future<Map<String, Object?>?> _readJson(File file) async {
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, Object?> ? data : null;
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  // ---------------------------------------------------------- cronologia

  /// Le ultime letture, dalla più recente. Le date dedotte dall'importazione
  /// restano fuori: non sono momenti in cui l'utente ha letto qualcosa.
  Future<List<HistoryEntry>> history({int limit = 200, int offset = 0}) async {
    final rows = await (db.select(db.chapterReads)
          ..where((row) =>
              row.profileId.equals(profileId) & row.estimated.equals(false))
          ..orderBy([
            (row) => OrderingTerm(
                  expression: row.readAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(limit, offset: offset))
        .get();
    return [
      for (final row in rows)
        HistoryEntry(
          seriesKey: row.seriesKey,
          chapterId: row.chapterId,
          readAt: row.readAt,
        ),
    ];
  }

  /// Toglie una riga dalla cronologia. Il capitolo torna da leggere: la
  /// cronologia e lo stato "letto" sono lo stesso dato, e fingere il contrario
  /// vorrebbe dire tenerne due copie che si contraddicono.
  Future<void> forget(String key, String chapterId) =>
      markChapters(key, [chapterId], false);

  Future<void> clearHistory() => db.transaction(() async {
        await (db.delete(db.chapterReads)
              ..where((row) =>
                  row.profileId.equals(profileId) &
                  row.estimated.equals(false)))
            .go();
        await (db.delete(db.readingSessions)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
      });

  // ------------------------------------------------------------- sessioni

  /// Registra il tempo passato su un capitolo.
  ///
  /// Se l'ultima sessione della stessa serie si è chiusa da poco la si allunga
  /// invece di aprirne una nuova: chi legge cinque capitoli di fila ha fatto
  /// una sessione, non cinque, e il conteggio dei giorni di lettura non deve
  /// dipendere da quante volte si è toccato "avanti".
  Future<void> logSession({
    required String seriesKey,
    required String chapterId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int pagesRead,
  }) async {
    if (!endedAt.isAfter(startedAt)) return;
    final last = await (db.select(db.readingSessions)
          ..where((row) =>
              row.profileId.equals(profileId) &
              row.seriesKey.equals(seriesKey))
          ..orderBy([
            (row) => OrderingTerm(
                  expression: row.endedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (last != null &&
        startedAt.difference(last.endedAt).abs() < sessionIdleLimit) {
      await (db.update(db.readingSessions)..where((row) => row.id.equals(last.id)))
          .write(
        ReadingSessionsCompanion(
          chapterId: Value(chapterId),
          endedAt: Value(endedAt),
          pagesRead: Value(last.pagesRead + pagesRead),
        ),
      );
      return;
    }
    await db.into(db.readingSessions).insert(
          ReadingSessionsCompanion.insert(
            profileId: profileId,
            seriesKey: seriesKey,
            chapterId: chapterId,
            startedAt: startedAt,
            endedAt: endedAt,
            pagesRead: Value(pagesRead),
          ),
        );
  }

  // ------------------------------------------------------------ segnalibri

  Future<List<BookmarkRow>> bookmarks(String seriesKey) =>
      (db.select(db.bookmarks)
            ..where((row) =>
                row.profileId.equals(profileId) &
                row.seriesKey.equals(seriesKey))
            ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]))
          .get();

  Future<void> addBookmark({
    required String seriesKey,
    required String chapterId,
    required int page,
  }) =>
      // Lo stesso tocco due volte nello stesso istante è un segnalibro solo.
      db.into(db.bookmarks).insert(
            BookmarksCompanion.insert(
              profileId: profileId,
              seriesKey: seriesKey,
              chapterId: chapterId,
              page: page,
              createdAt: DateTime.now().toUtc(),
            ),
            mode: InsertMode.insertOrIgnore,
          );

  Future<void> deleteBookmark(int id) =>
      (db.delete(db.bookmarks)..where((row) => row.id.equals(id))).go();

  /// Cancella tutto ciò che riguarda il profilo. La libreria non si tocca:
  /// l'app non ha mai cancellato niente da lì e non comincia ora.
  Future<void> wipe() => db.transaction(() async {
        await (db.delete(db.chapterReads)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
        await (db.delete(db.progresses)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
        await (db.delete(db.readingSessions)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
        await (db.delete(db.bookmarks)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
        await (db.delete(db.collectionRows)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
        await (db.delete(db.seriesStates)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
        await (db.delete(db.seriesArrivals)
              ..where((row) => row.profileId.equals(profileId)))
            .go();
      });

  // ---------------------------------------------------- capitoli nuovi

  Future<Map<String, ArrivalMark>> loadArrivals() async {
    final rows = await (db.select(db.seriesArrivals)
          ..where((row) => row.profileId.equals(profileId)))
        .get();
    return {
      for (final row in rows)
        row.seriesKey: ArrivalMark(
          seen: row.seenChapters,
          notified: row.notifiedChapters,
        ),
    };
  }

  Future<void> saveArrivals(Map<String, ArrivalMark> marks) async {
    if (marks.isEmpty) return;
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.seriesArrivals, [
        for (final MapEntry(:key, :value) in marks.entries)
          SeriesArrivalsCompanion.insert(
            profileId: profileId,
            seriesKey: key,
            seenChapters: value.seen,
            notifiedChapters: value.notified,
          ),
      ]);
    });
  }

  // -------------------------------------------------------- impostazioni

  Future<String?> readSetting(String key) async {
    final row = await (db.select(db.appSettings)
          ..where((row) => row.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> writeSetting(String key, String value, {DateTime? at}) =>
      db.into(db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: key,
              value: value,
              updatedAt: Value(at ?? DateTime.now().toUtc()),
            ),
          );
}
