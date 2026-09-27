/// Dove l'archiviatore scrive: una cartella del telefono o la cartella di
/// Drive della libreria.
///
/// Il motore ([Archiver]) lavora sempre su una cartella del telefono, una
/// per capitolo, come fa il server nella sua; la destinazione decide cosa
/// vuol dire «capitolo finito». In locale è rinominare la cartella di
/// lavoro; su Drive è caricare i file, confrontare l'MD5 con quello che
/// Drive risponde e solo allora togliere le tavole dal telefono — la stessa
/// ricevuta del server, perché un errore di rete deve lasciare il capitolo
/// da ritentare e non perso.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'drive.dart';
import 'indexes.dart';
import 'model.dart';

const String seriesManifestFile = 'series.json';
const String chapterManifestFile = 'chapter.json';
const String libraryFile = 'library.json';
const String seriesIndexName = 'index.json';
const String pagesIndexName = 'pages.json';
const String readingFolder = 'reading';
const String downloadsName = 'downloads.json';
const String nomediaFile = '.nomedia';

/// Il suffisso della cartella di un capitolo ancora da finire: sul telefono
/// un capitolo compare solo intero, come quelli scaricati da Drive.
const String workSuffix = '.part';

var _temporaries = 0;

Future<void> writeAtomically(File file, List<int> bytes) async {
  await file.parent.create(recursive: true);
  // Un nome per scrittura: due scritture dello stesso file che si
  // sovrappongono non devono rinominare l'una il temporaneo dell'altra.
  final temporary = File('${file.path}.${_temporaries++}.tmp');
  await temporary.writeAsBytes(bytes, flush: true);
  await temporary.rename(file.path);
}

Future<Map<String, Object?>?> readJsonFile(File file) async {
  try {
    final data = jsonDecode(await file.readAsString());
    return data is Map<String, Object?> ? data : null;
  } on IOException {
    return null;
  } on FormatException {
    return null;
  }
}

/// Un file già nella destinazione, come la destinazione lo conosce.
typedef StoredFile = ({int? size, String? md5});

abstract class ArchiveStore {
  /// Il nome della cartella di una serie già presente con questa chiave: una
  /// serie del server si allunga nella sua cartella, anche se il titolo sul
  /// sito nel frattempo è cambiato.
  Future<String?> existingFolder(Series series);

  Future<Map<String, Object?>?> readJson(String relative);

  /// I file già nella cartella [relative] della destinazione.
  Future<Map<String, StoredFile>> filesIn(String relative);

  /// La cartella del telefono dove si prepara un capitolo. Su disco è la
  /// cartella vera se c'è già — un capitolo del server da completare — o
  /// `<capitolo>.part`; per Drive una cartella di lavoro fuori dalla libreria.
  Future<Directory> workspace(String chapterPath);

  /// Il capitolo preparato in [work] diventa parte della libreria. [files]
  /// sono i file da consegnare, `chapter.json` per ultimo.
  Future<void> commitChapter(String chapterPath, Directory work, List<String> files);

  /// Scrive i file della serie (manifest, indici, copertine).
  Future<void> writeSeriesFiles(String folder, Map<String, Uint8List> files);

  /// I capitoli che hanno una cartella nella serie, per id.
  Future<Map<String, ArchivedChapter>> archivedChapters(
    String folder,
    Map<String, Object?> manifest,
  );

  /// La riga della serie nella libreria.
  Future<void> writeLibraryRow(Map<String, Object?> row);
}

/// L'id del capitolo nel nome della sua cartella: `… [id]`.
String? _chapterIdOf(String name) {
  final match = RegExp(r'\[([^\[\]]+)\]$').firstMatch(name);
  return match?[1];
}

/// L'archivio in una cartella del telefono: quella scelta dall'utente o lo
/// spazio privato dell'app.
///
/// `library.json` non si tocca: se la cartella è una copia di quella del
/// server, una versione scritta qui la sovrascriverebbe o verrebbe
/// sovrascritta. Le serie archiviate dall'app si annotano in
/// `reading/downloads.json`, che la sorgente locale già unisce a
/// `library.json` — è lo spazio del client per contratto MALF.
class LocalStore extends ArchiveStore {
  LocalStore(this.root, {this.hideFromGallery = true});

  final String root;

  /// Una cartella scelta dall'utente sta dove la galleria guarda; lo spazio
  /// privato dell'app no.
  final bool hideFromGallery;

  File _file(String relative) => File(p.joinAll([root, ...p.posix.split(relative)]));

  Directory _directory(String relative) =>
      Directory(p.joinAll([root, ...p.posix.split(relative)]));

  File get _downloads => File(p.join(root, readingFolder, downloadsName));

  @override
  Future<String?> existingFolder(Series series) async {
    for (final file in [File(p.join(root, libraryFile)), _downloads]) {
      final rows = (await readJsonFile(file))?['series'];
      if (rows is! List) continue;
      for (final row in rows.whereType<Map>()) {
        if (row['key'] == series.key && row['path'] is String) return row['path'] as String;
      }
    }
    return null;
  }

  @override
  Future<Map<String, Object?>?> readJson(String relative) => readJsonFile(_file(relative));

  @override
  Future<Map<String, StoredFile>> filesIn(String relative) async {
    final directory = _directory(relative);
    if (!await directory.exists()) return const {};
    return {
      await for (final entity in directory.list())
        if (entity is File) p.basename(entity.path): (size: await entity.length(), md5: null),
    };
  }

  @override
  Future<Directory> workspace(String chapterPath) async {
    final done = _directory(chapterPath);
    if (await done.exists()) return done;
    final work = Directory('${done.path}$workSuffix');
    await work.create(recursive: true);
    return work;
  }

  @override
  Future<void> commitChapter(String chapterPath, Directory work, List<String> files) async {
    final done = _directory(chapterPath);
    if (work.path != done.path) await work.rename(done.path);
  }

  @override
  Future<void> writeSeriesFiles(String folder, Map<String, Uint8List> files) async {
    for (final MapEntry(key: name, value: bytes) in files.entries) {
      await writeAtomically(_file(p.posix.join(folder, name)), bytes);
    }
  }

  @override
  Future<Map<String, ArchivedChapter>> archivedChapters(
    String folder,
    Map<String, Object?> manifest,
  ) async {
    final chapters = _directory(p.posix.join(folder, 'chapters'));
    if (!await chapters.exists()) return const {};
    final names = [
      await for (final entity in chapters.list())
        if (entity is Directory && !entity.path.endsWith(workSuffix)) p.basename(entity.path),
    ]..sort();
    final result = <String, ArchivedChapter>{};
    for (final name in names) {
      final id = _chapterIdOf(name);
      if (id == null || result.containsKey(id)) continue;
      final path = 'chapters/$name';
      final stored = await readJson(p.posix.join(folder, path, chapterManifestFile));
      result[id] = ArchivedChapter.fromManifest(path, stored ?? const {});
    }
    return result;
  }

  @override
  Future<void> writeLibraryRow(Map<String, Object?> row) async {
    final previous = await readJsonFile(_downloads);
    final rows = [
      for (final entry in (previous?['series'] as List? ?? const []).whereType<Map<String, Object?>>())
        if (entry['key'] != row['key']) entry,
      row,
    ];
    await writeAtomically(
      _downloads,
      utf8.encode(jsonEncode({'format': malfFormatName, 'formatVersion': malfVersion, 'series': rows})),
    );
    if (hideFromGallery) {
      final nomedia = File(p.join(root, nomediaFile));
      if (!await nomedia.exists()) await nomedia.create(recursive: true);
    }
  }
}

/// L'archivio direttamente nella cartella di Drive della libreria.
///
/// Drive non ha percorsi ma cartelle con un id: gli elenchi si tengono qui
/// per la durata di un giro, e una cartella si crea solo dopo aver visto che
/// manca — Drive accetta due cartelle con lo stesso nome, e una seconda
/// `chapters/` o un secondo `library.json` spezzerebbero la libreria per il
/// server e per il lettore.
class DriveStore extends ArchiveStore {
  DriveStore({
    required this.remote,
    required this.folderId,
    required this.staging,
    this.mirror,
  });

  final SyncRemote remote;
  final String folderId;

  /// Dove si preparano i capitoli prima di caricarli: nello spazio dell'app,
  /// così un giro interrotto riprende dalle tavole già scaricate.
  final String staging;

  /// Se c'è, i capitoli caricati restano anche sul telefono, in questa
  /// libreria: «Drive e telefono».
  final LocalStore? mirror;

  /// Per ogni percorso di cartella, i suoi figli per nome. Si tiene la
  /// richiesta e non il risultato: i file di un capitolo salgono in
  /// parallelo, e due elenchi della stessa cartella chiesti insieme ne
  /// farebbero due mappe, con una sola aggiornata dai caricamenti.
  final Map<String, Future<Map<String, DriveItem>>> _listings = {};
  final Map<String, Future<String>> _creating = {};
  final Map<String, String> _folders = {};

  String _parentPath(String relative) {
    final parent = p.posix.dirname(relative);
    return parent == '.' ? '' : parent;
  }

  Future<String?> _folderId(String relative) async {
    if (relative.isEmpty) return folderId;
    final known = _folders[relative];
    if (known != null) return known;
    final item = (await _list(_parentPath(relative)))[p.posix.basename(relative)];
    if (item == null || !item.folder) return null;
    return _folders[relative] = item.id;
  }

  Future<Map<String, DriveItem>> _list(String relative) =>
      _listings[relative] ??= _fetchList(relative).catchError((Object error) {
        _listings.remove(relative);
        throw error;
      });

  Future<Map<String, DriveItem>> _fetchList(String relative) async {
    final id = await _folderId(relative);
    if (id == null) return {};
    final items = await remote.childrenOf([id]);
    final listing = <String, DriveItem>{};
    for (final item in items) {
      // Se Drive ha già due voci con lo stesso nome, vale la prima: è quella
      // che trova anche il lettore.
      listing.putIfAbsent(item.name, () => item);
    }
    return listing;
  }

  Future<String> _ensureFolder(String relative) async {
    final existing = await _folderId(relative);
    if (existing != null) return existing;
    return _creating[relative] ??= () async {
      final parent = await _ensureFolder(_parentPath(relative));
      final created = await remote.createFolder(p.posix.basename(relative), parent);
      (await _list(_parentPath(relative)))[created.name] = created;
      _listings[relative] = Future.value({});
      return _folders[relative] = created.id;
    }();
  }

  Future<DriveItem?> _item(String relative) async =>
      (await _list(_parentPath(relative)))[p.posix.basename(relative)];

  /// Carica [file] come [relative], al posto di quello che c'è già se c'è, e
  /// controlla che Drive abbia ricevuto esattamente quei byte.
  Future<void> _put(String relative, File file) async {
    final existing = await _item(relative);
    final digest = (await md5.bind(file.openRead()).first).toString();
    if (existing != null && existing.md5 == digest) return;
    final parent = await _ensureFolder(_parentPath(relative));
    final item = await remote.upload(
      file,
      id: existing?.id,
      name: existing == null ? p.posix.basename(relative) : null,
      parentId: existing == null ? parent : null,
    );
    if (item.md5 != null && item.md5 != digest) {
      throw DriveException('Drive ha ricevuto un file diverso: $relative');
    }
    (await _list(_parentPath(relative)))[p.posix.basename(relative)] = item;
  }

  Future<void> _putBytes(String relative, Uint8List bytes) async {
    final file = File(p.join(staging, '.upload', relative.replaceAll('/', '_')));
    await writeAtomically(file, bytes);
    try {
      await _put(relative, file);
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  @override
  Future<String?> existingFolder(Series series) async {
    final library = await readJson(libraryFile);
    for (final row in (library?['series'] as List? ?? const []).whereType<Map>()) {
      if (row['key'] == series.key && row['path'] is String) return row['path'] as String;
    }
    // Una serie del server la cui riga si è persa si riconosce dal nome: la
    // cartella finisce sempre con `[provider-id]`.
    final suffix = RegExp(r'\[([^\[\]]+)\]$');
    for (final item in (await _list('')).values) {
      final match = suffix.firstMatch(item.name);
      if (item.folder && match != null && match[1] == '${series.provider}-${series.id}') {
        return item.name;
      }
    }
    return null;
  }

  @override
  Future<Map<String, Object?>?> readJson(String relative) async {
    final item = await _item(relative);
    if (item == null || item.folder) return null;
    final file = File(p.join(staging, '.read', relative.replaceAll('/', '_')));
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.delete();
    try {
      await remote.download(item.id, file);
      return await readJsonFile(file);
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  @override
  Future<Map<String, StoredFile>> filesIn(String relative) async => {
        for (final item in (await _list(relative)).values)
          if (!item.folder) item.name: (size: item.size, md5: item.md5),
      };

  @override
  Future<Directory> workspace(String chapterPath) async {
    final work = Directory(p.joinAll([staging, ...p.posix.split(chapterPath)]));
    await work.create(recursive: true);
    return work;
  }

  /// Quanti file di un capitolo salgono insieme. Uno alla volta, un
  /// capitolo di un manhwa — decine di tavole, ognuna con le sue tessere —
  /// erano minuti di richieste in fila; più di così Drive comincia a
  /// rallentare chi chiede.
  static const int _uploads = 4;

  @override
  Future<void> commitChapter(String chapterPath, Directory work, List<String> files) async {
    // `chapter.json` è la ricevuta del capitolo: sale per ultimo, quando le
    // tavole che elenca sono già tutte su Drive.
    final pending = [for (final name in files) if (name != chapterManifestFile) name];
    var next = 0;
    Future<void> lane() async {
      while (next < pending.length) {
        final name = pending[next++];
        await _put(p.posix.join(chapterPath, name), File(p.join(work.path, name)));
      }
    }

    await Future.wait([for (var i = 0; i < _uploads; i++) lane()]);
    if (files.contains(chapterManifestFile)) {
      await _put(p.posix.join(chapterPath, chapterManifestFile), File(p.join(work.path, chapterManifestFile)));
    }
    final mirror = this.mirror;
    if (mirror != null) {
      final local = await mirror.workspace(chapterPath);
      for (final name in files) {
        final target = File(p.join(local.path, name));
        if (!await target.exists()) await File(p.join(work.path, name)).rename(target.path);
      }
      await mirror.commitChapter(chapterPath, local, files);
    }
    // Solo adesso: fino alla ricevuta le tavole restano qui, e il capitolo
    // si riprende da dove era.
    await work.delete(recursive: true);
  }

  @override
  Future<void> writeSeriesFiles(String folder, Map<String, Uint8List> files) async {
    for (final MapEntry(key: name, value: bytes) in files.entries) {
      await _putBytes(p.posix.join(folder, name), bytes);
    }
    await mirror?.writeSeriesFiles(folder, files);
  }

  @override
  Future<Map<String, ArchivedChapter>> archivedChapters(
    String folder,
    Map<String, Object?> manifest,
  ) async {
    final result = <String, ArchivedChapter>{};
    final folders = {
      for (final item in (await _list(p.posix.join(folder, 'chapters'))).values)
        if (item.folder) item.name: item,
    };
    // Gli indici di prima dicono già tutto dei capitoli che conoscono; si
    // apre il `chapter.json` solo delle cartelle che non vi compaiono —
    // quelle scritte da un altro, server o telefono, dopo l'ultimo indice.
    final index = await readJson(p.posix.join(folder, seriesIndexName));
    final pages = (await readJson(p.posix.join(folder, pagesIndexName)))?['pages'] as Map? ?? const {};
    for (final entry in (index?['chapters'] as List? ?? const []).whereType<Map<String, Object?>>()) {
      final id = entry['id'];
      final path = entry['path'];
      if (id is! String || path is! String || !folders.containsKey(p.posix.basename(path))) continue;
      final stored = ArchivedChapter.fromIndex(entry, pages[id] as List?);
      if (stored != null) result[id] = stored;
    }
    for (final name in folders.keys.toList()..sort()) {
      final id = _chapterIdOf(name);
      if (id == null || result.containsKey(id)) continue;
      final path = 'chapters/$name';
      final stored = await readJson(p.posix.join(folder, path, chapterManifestFile));
      result[id] = ArchivedChapter.fromManifest(path, stored ?? const {});
    }
    return result;
  }

  @override
  Future<void> writeLibraryRow(Map<String, Object?> row) async {
    final previous = await readJson(libraryFile);
    await _putBytes(libraryFile, Uint8List.fromList(utf8.encode(prettyJson(libraryWith(previous, row)))));
    // Chi archivia scrive anche `.nomedia`, se la libreria nasce qui: senza,
    // la galleria di un telefono che la sincronizza si riempie di album.
    if (await _item(nomediaFile) == null) await _putBytes(nomediaFile, Uint8List(0));
    await mirror?.writeLibraryRow(row);
  }

  /// Dimentica gli elenchi: al giro seguente si rileggono da Drive.
  void forget() {
    _listings.clear();
    _folders.clear();
    _creating.clear();
  }
}
