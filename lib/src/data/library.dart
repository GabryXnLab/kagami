/// La libreria come la vede l'utente: una sola, qualunque sia la sua origine.
///
/// Le serie possono stare in una cartella del telefono, nello spazio privato
/// dell'app — dove finiscono i download quando una cartella non c'è — o su
/// Google Drive, e spesso stanno in più di un posto: la cartella locale è di
/// solito una copia di quella su Drive, magari più vecchia o parziale. Qui
/// quei posti diventano una libreria sola, **per chiave di serie e per
/// capitolo**: un capitolo si legge dal telefono se è sul telefono, altrimenti
/// da Drive. L'interfaccia non deve sapere niente di più di quale icona
/// mostrare.
library;

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../format/malf.dart';
import '../l10n.dart';
import 'library_repository.dart';

/// Da dove arriva qualcosa: basta a scegliere l'icona e il modo di leggerlo.
enum LibraryOrigin { local, drive }

/// Dove sta una serie, come lo dice l'icona sulla copertina.
enum SeriesPlace {
  /// Tutto quello che c'è da leggere è sul telefono.
  local,

  /// Niente è sul telefono: si legge da Drive.
  drive,

  /// Una parte è sul telefono e il resto — di solito i capitoli arrivati
  /// dopo — è soltanto su Drive.
  mixed,
}

/// Una sorgente di libreria MALF: una cartella del telefono o una su Drive.
///
/// I modelli sono gli stessi, perché il formato è lo stesso: cambia solo come
/// si arriva ai byte. [locate] è ciò che il lettore e le copertine ricevono,
/// e per una sorgente locale è un percorso vero e proprio: in quel caso la
/// strada da fare per arrivare alla tavola è esattamente quella di sempre.
abstract interface class LibraryShelf {
  LibraryOrigin get origin;

  Future<LibraryIndex> loadLibrary();

  Future<SeriesIndex?> loadSeries(SeriesEntry entry);

  Future<PagesIndex?> loadPages(SeriesEntry entry);

  Future<Map<String, Object?>?> loadSeriesManifest(SeriesEntry entry);

  /// L'indirizzo di un file della serie, relativo alla sua cartella.
  String locate(SeriesEntry entry, String relative);

  /// I capitoli (percorsi come in [ChapterEntry.path]) che l'indice di questa
  /// sorgente elenca ma che l'app vi ha tolto: fino a che il server non
  /// riscrive l'indice, sono lì solo sulla carta.
  Future<Set<String>> withdrawnChapters(SeriesEntry entry);
}

/// Un'immagine di copertina e il posto dove cercarla se il primo manca.
///
/// Il secondo indirizzo c'è perché una cartella locale sincronizzata a metà
/// può avere l'indice e non ancora la miniatura: con Drive a disposizione la
/// si prende da lì invece di mostrare un riquadro vuoto.
class SeriesImage {
  const SeriesImage(this.primary, [this.fallback]);

  final String primary;
  final String? fallback;
}

/// La libreria unita, com'era all'ultima lettura degli indici.
class LibraryCatalog {
  const LibraryCatalog({
    required this.index,
    required this.holders,
    required this.places,
    this.notices = const [],
  });

  static const LibraryCatalog empty = LibraryCatalog(
    index: LibraryIndex.empty,
    holders: {},
    places: {},
  );

  final LibraryIndex index;

  /// Per ogni serie, le sorgenti che la elencano, nell'ordine in cui vanno
  /// preferite: prima il telefono, poi Drive.
  final Map<String, List<LibraryShelf>> holders;

  final Map<String, SeriesPlace> places;

  /// Una sorgente che non ha risposto, quando le altre sì: la libreria si
  /// mostra lo stesso, e il problema si dice in una riga invece che al posto
  /// della libreria.
  final List<Object> notices;

  /// Il catalogo senza le serie tolte dall'utente ([removed], chiave →
  /// firma): una copia locale di `library.json` le elenca finché la
  /// sincronizzazione non porta quella nuova. Una serie riscaricata dopo ha
  /// un'altra firma, e torna.
  LibraryCatalog hiding(Map<String, String> removed) {
    if (removed.isEmpty) return this;
    final series = [
      for (final entry in index.series)
        if (removed[entry.key] != entry.signature) entry,
    ];
    if (series.length == index.series.length) return this;
    final kept = {for (final entry in series) entry.key};
    return LibraryCatalog(
      index: LibraryIndex(
        generatedAt: index.generatedAt,
        series: series,
        chapterCount: series.fold(0, (sum, row) => sum + row.chapterCount),
        pageCount: series.fold(0, (sum, row) => sum + row.pageCount),
        bytes: series.fold(0, (sum, row) => sum + row.bytes),
      ),
      holders: {for (final MapEntry(:key, :value) in holders.entries) if (kept.contains(key)) key: value},
      places: {for (final MapEntry(:key, :value) in places.entries) if (kept.contains(key)) key: value},
      notices: notices,
    );
  }

  LibraryCatalog withNotice(Object notice) => LibraryCatalog(
        index: index,
        holders: holders,
        places: places,
        notices: [...notices, notice],
      );
}

/// C'è una cartella di Drive scelta, ma nessun account con cui leggerla.
class DriveSignedOut implements Exception {
  const DriveSignedOut();

  @override
  String toString() => currentL10n().dataDriveSignedOut;
}

/// I capitoli di una serie, con chi li serve.
class SeriesChapters {
  const SeriesChapters({required this.index, required this.servedBy});

  /// L'unione dei capitoli di tutte le sorgenti, nell'ordine di lettura.
  final SeriesIndex index;

  /// Per ogni capitolo leggibile, la sorgente da cui lo si legge.
  final Map<String, LibraryShelf> servedBy;

  LibraryOrigin? originOf(String chapterId) => servedBy[chapterId]?.origin;
}

/// Il prefisso degli indirizzi che non sono ancora un file sul telefono.
///
/// Un indirizzo così passa da [RemoteFiles] prima di arrivare al
/// decodificatore: tutto il resto del lettore continua a ragionare per
/// stringhe, come ha sempre fatto.
const String remotePrefix = 'drive:';

bool isRemote(String address) => address.startsWith(remotePrefix);

/// Chi trasforma un indirizzo remoto in un file sul telefono.
///
/// È un punto solo per tutta l'app, come il decodificatore e il magazzino
/// delle fasce: la tavola la chiede chi la disegna, e chi la disegna non sa
/// niente di account e cartelle.
abstract class RemoteFiles {
  static RemoteFiles? instance;

  /// Il file, scaricandolo se serve. [urgent] passa davanti ai precarichi:
  /// è la tavola che l'utente sta guardando.
  Future<String> fetch(String address, {bool urgent = false});

  /// Il file, se è già sul telefono; altrimenti `null`, senza aspettare.
  String? peek(String address);

  /// Scarica in anticipo, nell'ordine dato e senza fretta.
  void warm(Iterable<String> addresses);

  /// Il lettore ha aperto un capitolo fatto di queste tavole, in ordine: è
  /// ciò che permette alla cache di buttarlo per intero quando è finito, e di
  /// tenerne il resto quando è a metà.
  void rememberChapter(String series, String chapter, List<String> addresses);
}

/// Un indirizzo pronto per il decodificatore o per `Image.file`.
///
/// Chi lo chiede di solito lo sta per mostrare: è urgente finché non si dice
/// il contrario.
Future<String> localFileOf(String address, {bool urgent = true}) {
  if (!isRemote(address)) return Future.value(address);
  final remote = RemoteFiles.instance;
  if (remote == null) {
    return Future.error(StateError('Drive non è collegato'));
  }
  return remote.fetch(address, urgent: urgent);
}

class Library {
  Library(this.shelves);

  /// In ordine di preferenza: prima le cartelle del telefono, poi Drive.
  final List<LibraryShelf> shelves;

  /// La cartella scelta dall'utente, se c'è: è quella di cui si guarda la
  /// data di `library.json` per sapere se rileggere.
  LibraryRepository? get folder => shelves
      .whereType<LibraryRepository>()
      .firstWhereOrNull((shelf) => !shelf.private);

  bool get hasDrive => shelves.any((shelf) => shelf.origin == LibraryOrigin.drive);

  Future<LibraryCatalog> load() async {
    final loaded = await Future.wait([
      for (final shelf in shelves)
        shelf.loadLibrary().then<Object>((index) => index, onError: (Object e) => e),
    ]);
    final indexes = <LibraryShelf, LibraryIndex>{};
    final problems = <Object>[];
    for (var position = 0; position < shelves.length; position++) {
      final result = loaded[position];
      if (result is LibraryIndex) {
        indexes[shelves[position]] = result;
      } else {
        problems.add(result);
      }
    }
    if (indexes.values.every((index) => index.series.isEmpty) &&
        problems.isNotEmpty) {
      throw problems.first;
    }
    return merge(indexes, problems);
  }

  /// L'unione vera e propria, separata dal disco perché la si possa provare.
  static LibraryCatalog merge(
    Map<LibraryShelf, LibraryIndex> indexes, [
    List<Object> notices = const [],
  ]) {
    final rows = <String, SeriesEntry>{};
    final holders = <String, List<LibraryShelf>>{};
    final localCount = <String, int>{};
    final driveCount = <String, int>{};
    for (final MapEntry(key: shelf, value: index) in indexes.entries) {
      final drive = shelf.origin == LibraryOrigin.drive;
      for (final entry in index.series) {
        holders.putIfAbsent(entry.key, () => []).add(shelf);
        // La riga di Drive vince: è quella che l'archivio ha scritto per
        // ultima, mentre una copia locale può essere indietro di giorni.
        if (drive || !rows.containsKey(entry.key)) rows[entry.key] = entry;
        final counts = drive ? driveCount : localCount;
        counts[entry.key] = [
          counts[entry.key] ?? 0,
          entry.archivedChapterCount,
        ].max;
      }
    }
    final places = <String, SeriesPlace>{
      for (final key in rows.keys)
        key: switch ((localCount[key], driveCount[key])) {
          (null, _) => SeriesPlace.drive,
          (_, null) => SeriesPlace.local,
          (final local?, final drive?) =>
            local >= drive ? SeriesPlace.local : SeriesPlace.mixed,
        },
    };
    final series = rows.values.toList(growable: false);
    return LibraryCatalog(
      index: LibraryIndex(
        generatedAt: indexes.values
            .map((index) => index.generatedAt)
            .nonNulls
            .maxOrNull,
        series: series,
        chapterCount: series.fold(0, (sum, row) => sum + row.chapterCount),
        pageCount: series.fold(0, (sum, row) => sum + row.pageCount),
        bytes: series.fold(0, (sum, row) => sum + row.bytes),
      ),
      holders: holders,
      places: places,
      notices: notices,
    );
  }

  Future<SeriesChapters?> loadSeries(
    SeriesEntry entry,
    List<LibraryShelf> holders,
  ) async {
    final indexes = await Future.wait([
      for (final shelf in holders) _safely(() => shelf.loadSeries(entry)),
    ]);
    // L'indice locale non si prende in parola: un capitolo che dice
    // leggibile e che non è sul telefono — non ancora sincronizzato, o
    // cancellato perché già letto — si legge da Drive se c'è, altrimenti si
    // mostra come non scaricato. Per saperlo basta elencare la cartella dei
    // capitoli, una lettura per serie.
    final present = <LibraryShelf, Set<String>>{
      for (final shelf in holders.whereType<LibraryRepository>())
        shelf: await shelf.presentChapters(entry),
    };
    final withdrawn = <LibraryShelf, Set<String>>{
      for (final shelf in holders)
        shelf: await _safely(() => shelf.withdrawnChapters(entry)) ?? const {},
    };
    return mergeChapters({
      for (var position = 0; position < holders.length; position++)
        if (indexes[position] != null) holders[position]: indexes[position]!,
    }, present, withdrawn);
  }

  /// L'unione dei capitoli: per ognuno, la prima sorgente che lo sa servire.
  static SeriesChapters? mergeChapters(
    Map<LibraryShelf, SeriesIndex> indexes, [
    Map<LibraryShelf, Set<String>> present = const {},
    Map<LibraryShelf, Set<String>> withdrawn = const {},
  ]) {
    if (indexes.isEmpty) return null;
    final chapters = <String, ChapterEntry>{};
    final servedBy = <String, LibraryShelf>{};
    for (final MapEntry(key: shelf, value: index) in indexes.entries) {
      final files = present[shelf];
      final gone = withdrawn[shelf] ?? const {};
      for (final chapter in index.chapters) {
        final path = chapter.isReadable ? p.posix.normalize(chapter.path!) : null;
        final serves = path != null &&
            (files == null || files.contains(path)) &&
            !gone.contains(path);
        if (serves && !servedBy.containsKey(chapter.id)) {
          servedBy[chapter.id] = shelf;
          chapters[chapter.id] = chapter;
        } else {
          chapters.putIfAbsent(chapter.id, () => chapter);
        }
      }
    }
    // Un capitolo che un indice dice leggibile e che nessuno sa servire —
    // l'indice locale è arrivato, le tavole no — si mostra come non
    // scaricato: è quello che l'interfaccia guarda per decidere se aprirlo.
    for (final MapEntry(:key, value: chapter) in chapters.entries.toList()) {
      if (chapter.isReadable && !servedBy.containsKey(key)) {
        chapters[key] = ChapterEntry(
          id: chapter.id,
          order: chapter.order,
          archived: chapter.archived,
          complete: false,
          pageCount: chapter.pageCount,
          bytes: chapter.bytes,
          number: chapter.number,
          title: chapter.title,
          sortKey: chapter.sortKey,
          path: chapter.path,
          publishedAt: chapter.publishedAt,
          archivedAt: chapter.archivedAt,
        );
      }
    }
    // L'indice di Drive dà titolo, stato e firma: è il più recente.
    final head = indexes.entries
            .firstWhereOrNull((row) => row.key.origin == LibraryOrigin.drive)
            ?.value ??
        indexes.values.first;
    return SeriesChapters(
      index: SeriesIndex(
        key: head.key,
        title: head.title,
        releaseStatus: head.releaseStatus,
        signature: head.signature,
        chapters: chapters.values.sortedBy<num>((chapter) => chapter.order),
      ),
      servedBy: servedBy,
    );
  }

  /// Le pagine dei capitoli, ognuno dalla sorgente che lo serve.
  Future<PagesIndex?> loadPages(
    SeriesEntry entry,
    SeriesChapters chapters,
    List<LibraryShelf> holders,
  ) async {
    final sources = {...chapters.servedBy.values, ...holders}.toList();
    final loaded = await Future.wait([
      for (final shelf in sources) _safely(() => shelf.loadPages(entry)),
    ]);
    final byShelf = <LibraryShelf, PagesIndex>{
      for (var position = 0; position < sources.length; position++)
        if (loaded[position] != null) sources[position]: loaded[position]!,
    };
    if (byShelf.isEmpty) return null;
    final pages = <String, List<PageEntry>>{};
    for (final chapter in chapters.index.chapters) {
      final own = byShelf[chapters.servedBy[chapter.id]]?.of(chapter.id);
      // Un `pages.json` locale più vecchio dei capitoli scaricati non li
      // conosce: i file sono gli stessi, quindi vale la descrizione di
      // un'altra sorgente.
      pages[chapter.id] = own != null && own.isNotEmpty
          ? own
          : byShelf.values
                  .map((index) => index.of(chapter.id))
                  .firstWhereOrNull((rows) => rows.isNotEmpty) ??
              const [];
    }
    final head = byShelf.values.first;
    return PagesIndex(key: head.key, signature: head.signature, pages: pages);
  }

  Future<Map<String, Object?>?> loadSeriesManifest(
    SeriesEntry entry,
    List<LibraryShelf> holders,
  ) async {
    for (final shelf in holders) {
      final manifest = await _safely(() => shelf.loadSeriesManifest(entry));
      if (manifest != null) return manifest;
    }
    return null;
  }

  /// Le tavole di un capitolo, nell'ordine di lettura, come indirizzi.
  List<String> pagePaths(
    SeriesEntry entry,
    ChapterEntry chapter,
    PagesIndex pages,
    SeriesChapters chapters,
  ) {
    final shelf = chapters.servedBy[chapter.id];
    final directory = chapter.path;
    if (shelf == null || directory == null) return const [];
    return pages
        .of(chapter.id)
        .map((page) => shelf.locate(entry, p.posix.join(directory, page.file)))
        .toList(growable: false);
  }

  /// Le tessere di ogni tavola del capitolo, come indirizzi, nello stesso
  /// ordine di [pagePaths]: una lista vuota dove la tavola non ne ha.
  List<List<String>> tilePaths(
    SeriesEntry entry,
    ChapterEntry chapter,
    PagesIndex pages,
    SeriesChapters chapters,
  ) {
    final shelf = chapters.servedBy[chapter.id];
    final directory = chapter.path;
    if (shelf == null || directory == null) return const [];
    return [
      for (final page in pages.of(chapter.id))
        [
          for (final tile in page.tiles)
            shelf.locate(entry, p.posix.join(directory, tile.file)),
        ],
    ];
  }

  /// La miniatura della griglia: dal telefono se la serie ci sta, altrimenti
  /// da Drive. È la miniatura e non la copertina per la stessa ragione di
  /// sempre — una decodifica piena per cella scalda il telefono per niente.
  SeriesImage? gridImage(SeriesEntry entry, List<LibraryShelf> holders) =>
      _image(entry, holders, entry.coverThumbnail ?? entry.cover);

  SeriesImage? coverImage(SeriesEntry entry, List<LibraryShelf> holders) =>
      _image(entry, holders, entry.cover ?? entry.coverThumbnail);

  SeriesImage? _image(
    SeriesEntry entry,
    List<LibraryShelf> holders,
    String? name,
  ) {
    if (name == null || holders.isEmpty) return null;
    final first = holders.first.locate(entry, name);
    final remote =
        holders.firstWhereOrNull((shelf) => shelf.origin == LibraryOrigin.drive);
    return SeriesImage(
      first,
      remote == null || identical(remote, holders.first)
          ? null
          : remote.locate(entry, name),
    );
  }

  /// Una sorgente che non risponde non deve togliere le altre: la serie si
  /// mostra con quello che c'è.
  static Future<T?> _safely<T>(Future<T?> Function() load) async {
    try {
      return await load();
    } on Exception {
      return null;
    }
  }
}
