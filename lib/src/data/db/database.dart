/// Il database dei dati personali.
///
/// Voti, stati, capitoli letti, cronologia, sessioni e raccolte stanno qui e
/// non più in `reading/`: un JSON riletto e riscritto per intero a ogni gesto
/// non regge una cronologia che cresce a ogni capitolo, e le domande che le
/// statistiche fanno — quanti capitoli in questo mese, quali generi, quanti
/// giorni di fila — sono raggruppamenti per data, cioè esattamente ciò per cui
/// esiste un indice.
///
/// Ogni tabella porta `profileId`: oggi il profilo è uno solo, ma la libreria
/// è condivisa e più lettori sullo stesso archivio sono la direzione prevista.
///
/// I dati della libreria (gli indici MALF) non entrano nel database: sono già
/// una forma indicizzata, scritta da qualcun altro, e duplicarli significherebbe
/// mantenere una copia da invalidare a ogni sincronizzazione.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Il profilo predefinito, finché l'app non ne sa gestire più d'uno.
const String defaultProfileId = 'local';

/// Chiave con cui si salvano le impostazioni di lettura non legate a una
/// serie: la riga con serie vuota è il valore predefinito di tutte.
const String globalSettingsKey = '';

@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Stato della serie. `lastOpenedAt` è il dato che MALF non aveva: con lui
/// "novità" è una domanda esatta — capitoli arrivati dopo l'ultima apertura —
/// invece della stima ricavata da `updatedAt`.
@DataClassName('SeriesStateRow')
class SeriesStates extends Table {
  TextColumn get profileId => text()();
  TextColumn get seriesKey => text()();
  TextColumn get status => text().withDefault(const Constant('none'))();
  IntColumn get rating => integer().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  /// Niente notifiche per i capitoli nuovi di questa serie. Il pallino sulla
  /// copertina resta: silenziare è non essere disturbati, non smettere di
  /// sapere.
  BoolColumn get muted => boolean().withDefault(const Constant(false))();

  /// Il numero dell'ultimo capitolo letto altrove, come lo scrive l'autore
  /// (`52`). Per le schede senza elenco di capitoli è l'unico dato di lettura.
  TextColumn get reachedChapter => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {profileId, seriesKey};
}

/// Quanti capitoli archiviati questo telefono ha già visto di una serie, e di
/// quanti ha già dato notizia. MALF dice quando è arrivato l'ultimo capitolo,
/// non quanti ne sono arrivati da una certa data: senza un conteggio di
/// riferimento il pallino dei capitoli nuovi non avrebbe un numero.
///
/// Non va nel backup: è ciò che ha visto e notificato *questo* telefono, e un
/// telefono nuovo deve partire da ciò che trova, non annunciare di nuovo i
/// capitoli di un altro. Che la scheda sia stata aperta altrove lo dice
/// `lastOpenedAt`, che invece viaggia.
@DataClassName('SeriesArrivalRow')
class SeriesArrivals extends Table {
  TextColumn get profileId => text()();
  TextColumn get seriesKey => text()();

  /// Capitoli archiviati all'ultima apertura della scheda: quelli oltre sono
  /// i nuovi.
  IntColumn get seenChapters => integer()();

  /// Capitoli archiviati all'ultima notifica: una notifica per arrivo, non
  /// una a ogni rilettura della libreria.
  IntColumn get notifiedChapters => integer()();

  /// I due conteggi sono dei capitoli del sito, presi su una scheda (serie
  /// senza capitoli archiviati); altrimenti degli archiviati. Quando la base
  /// cambia il riferimento si riprende da capo.
  BoolColumn get onSite => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {profileId, seriesKey};
}

/// Un capitolo finito, con la data: è insieme lo stato "letto" e la riga di
/// cronologia. Rileggerlo aggiorna `readAt`, perché la domanda che la
/// cronologia risponde è "quando l'ho letto l'ultima volta".
///
/// `estimated` distingue le date vere da quelle dedotte importando il vecchio
/// `reading/state.json`, che i capitoli letti li elencava senza data: nelle
/// statistiche per giorno vanno escluse, altrimenti inventano un picco.
@TableIndex(name: 'chapter_reads_read_at', columns: {#readAt})
@TableIndex(name: 'chapter_reads_series', columns: {#profileId, #seriesKey})
@DataClassName('ChapterReadRow')
class ChapterReads extends Table {
  TextColumn get profileId => text()();
  TextColumn get seriesKey => text()();
  TextColumn get chapterId => text()();
  DateTimeColumn get readAt => dateTime()();
  BoolColumn get estimated => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {profileId, seriesKey, chapterId};
}

/// Dove si è arrivati dentro un capitolo: una riga per capitolo aperto, e la
/// più recente è quella da cui la serie riprende. Una riga per serie faceva
/// dimenticare il punto di un capitolo lasciato a metà appena se ne apriva un
/// altro.
@DataClassName('ProgressRow')
class Progresses extends Table {
  TextColumn get profileId => text()();
  TextColumn get seriesKey => text()();
  TextColumn get chapterId => text()();
  IntColumn get page => integer()();
  IntColumn get pageCount => integer()();

  /// Quanto si è già scorso della tavola, da 0 a 1: su un webtoon una tavola
  /// è dieci schermate, e la pagina da sola non è una posizione.
  RealColumn get offset => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {profileId, seriesKey, chapterId};
}

/// Una sessione di lettura: da qui viene il tempo passato a leggere, che
/// nessun conteggio di capitoli sa dare. Si chiude da sé dopo un periodo di
/// inattività, altrimenti un lettore lasciato aperto per la notte varrebbe
/// otto ore.
@TableIndex(name: 'reading_sessions_started', columns: {#startedAt})
// Una sessione si riconosce dal suo inizio: il capitolo e la fine cambiano
// mentre si legge. Senza questo vincolo ogni fusione di un backup — cioè
// ogni sincronizzazione dell'account — raddoppiava tutte le sessioni.
@TableIndex(
  name: 'reading_sessions_unique',
  columns: {#profileId, #seriesKey, #startedAt},
  unique: true,
)
@DataClassName('ReadingSessionRow')
class ReadingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text()();
  TextColumn get seriesKey => text()();
  TextColumn get chapterId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get pagesRead => integer().withDefault(const Constant(0))();
}

@DataClassName('CollectionRow')
class CollectionRows extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// L'appartenenza a una raccolta, con la posizione scelta dall'utente: una
/// serie può stare in più raccolte e in ognuna a un posto diverso.
@DataClassName('CollectionItemRow')
class CollectionItems extends Table {
  TextColumn get collectionId =>
      text().references(CollectionRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get seriesKey => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {collectionId, seriesKey};
}

/// Una pagina messa da parte durante la lettura.
@TableIndex(
  name: 'bookmarks_unique',
  columns: {#profileId, #seriesKey, #chapterId, #page, #createdAt},
  unique: true,
)
@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text()();
  TextColumn get seriesKey => text()();
  TextColumn get chapterId => text()();
  IntColumn get page => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Come si legge una serie. La riga con [globalSettingsKey] al posto della
/// serie è il valore predefinito, che una serie senza riga propria eredita.
@DataClassName('ReaderSettingsRow')
class ReaderSettingsRows extends Table {
  TextColumn get profileId => text()();
  TextColumn get seriesKey => text()();
  TextColumn get mode => text()();
  TextColumn get direction => text()();
  TextColumn get fit => text()();
  TextColumn get background => text()();
  RealColumn get brightness => real().withDefault(const Constant(1))();
  BoolColumn get keepAwake => boolean().withDefault(const Constant(true))();
  BoolColumn get doublePage => boolean().withDefault(const Constant(false))();
  BoolColumn get showPageNumber => boolean().withDefault(const Constant(true))();

  /// La barra di avanzamento del capitolo e il pulsante che riporta in cima:
  /// utili su una striscia lunga, di troppo su un capitolo di venti tavole.
  BoolColumn get showProgress => boolean().withDefault(const Constant(true))();
  BoolColumn get showScrollTop =>
      boolean().withDefault(const Constant(true))();

  /// Tavole al minuto dello scorrimento automatico, 0 se spento: è il modo in
  /// cui si legge un webtoon senza tenere il dito sullo schermo.
  RealColumn get autoScroll => real().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {profileId, seriesKey};
}

/// Le impostazioni dell'app, coppie chiave-valore: tema, densità della
/// griglia, incognito, backup automatico. Stanno qui e non in
/// `SharedPreferences` perché il backup deve portarsele dietro.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  /// Quando è stata scritta: fondendo due copie vince la più recente. Senza,
  /// la sincronizzazione d'avvio rimetteva sopra una scelta appena fatta —
  /// la cartella di Drive — il valore vecchio rimasto in rete.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Profiles,
    SeriesStates,
    ChapterReads,
    Progresses,
    ReadingSessions,
    CollectionRows,
    CollectionItems,
    Bookmarks,
    ReaderSettingsRows,
    AppSettings,
    SeriesArrivals,
  ],
)
class KagamiDatabase extends _$KagamiDatabase {
  KagamiDatabase() : super(_open());

  /// Database in memoria per i test: nessun file, nessun isolate.
  KagamiDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await _ensureProfile();
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(
              readerSettingsRows,
              readerSettingsRows.showProgress,
            );
            await migrator.addColumn(
              readerSettingsRows,
              readerSettingsRows.showScrollTop,
            );
          }
          if (from < 3) {
            await migrator.addColumn(progresses, progresses.offset);
          }
          if (from < 4) {
            // SQLite non cambia la chiave primaria di una tabella esistente:
            // la si ricrea, e le righe per serie diventano per capitolo.
            await migrator.alterTable(TableMigration(progresses));
          }
          if (from < 5) {
            await migrator.addColumn(seriesStates, seriesStates.muted);
            await migrator.createTable(seriesArrivals);
          }
          if (from < 6) {
            await migrator.addColumn(appSettings, appSettings.updatedAt);
          }
          if (from < 7) {
            // Le copie lasciate dalle fusioni di prima: resta la prima.
            await customStatement(
              'DELETE FROM reading_sessions WHERE id NOT IN (SELECT MIN(id) '
              'FROM reading_sessions GROUP BY profile_id, series_key, '
              'started_at)',
            );
            await customStatement(
              'DELETE FROM bookmarks WHERE id NOT IN (SELECT MIN(id) FROM '
              'bookmarks GROUP BY profile_id, series_key, chapter_id, page, '
              'created_at)',
            );
            await migrator.createIndex(readingSessionsUnique);
            await migrator.createIndex(bookmarksUnique);
          }
          if (from < 8) {
            await migrator.addColumn(seriesStates, seriesStates.reachedChapter);
          }
          if (from < 9) {
            await migrator.addColumn(seriesArrivals, seriesArrivals.onSite);
          }
        },
        beforeOpen: (details) async {
          // Le chiavi esterne in SQLite sono spente salvo richiesta: servono a
          // far sparire le appartenenze quando una raccolta viene eliminata.
          await customStatement('PRAGMA foreign_keys = ON');
          if (!details.wasCreated) await _ensureProfile();
        },
      );

  Future<void> _ensureProfile() => into(profiles).insert(
        ProfilesCompanion.insert(
          id: defaultProfileId,
          name: 'Locale',
          createdAt: DateTime.now().toUtc(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

/// Il database sta nella cartella privata dell'app e non nella libreria: è
/// sostituibile — il backup è ciò che lo porta su un altro dispositivo — e
/// tenerlo su una cartella sincronizzata da FolderSync significherebbe far
/// copiare a metà un file che SQLite sta scrivendo.
///
/// Le query girano in un isolate separato: sono poche e piccole, ma quelle
/// delle statistiche scorrono tutta la cronologia e non devono mai far saltare
/// un fotogramma della griglia.
QueryExecutor _open() => driftDatabase(name: 'kagami');
