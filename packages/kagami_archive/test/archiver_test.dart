// Il motore dell'archivio su una cartella vera e su un Drive in memoria:
// ripresa, riparazione, indici, partenza da un capitolo, e la convivenza
// con ciò che il server ha già scritto nella stessa libreria.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:kagami_archive/archiver.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/indexes.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers/asurascans.dart';
import 'package:kagami_archive/providers/mangak.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_archive/drive.dart';
import 'package:path/path.dart' as p;

import 'archive_fakes.dart';

/// Come il Kotlin: una miniatura e tessere che dipendono dalla tavola.
class FakeImageTools implements ImageTools {
  int tilesMade = 0;

  @override
  Future<Uint8List?> thumbnail(File cover) async =>
      Uint8List.fromList(utf8.encode('thumb:${cover.lengthSync()}'));

  @override
  Future<List<Uint8List>?> tiles(File page, List<int> heights) async {
    tilesMade++;
    final digest = sha256.convert(page.readAsBytesSync()).toString();
    return [for (var i = 0; i < heights.length; i++) Uint8List.fromList(utf8.encode('$digest-$i'))];
  }
}

/// Drive in memoria, con i byte e l'MD5 che il vero restituisce.
class FakeDrive implements SyncRemote {
  static const String root = 'ROOT';

  final Map<String, DriveItem> items = {};
  final Map<String, Uint8List> contents = {};
  var _next = 0;
  int uploads = 0;

  /// I nomi caricati, nell'ordine in cui sono arrivati, e quanti insieme al
  /// massimo.
  final List<String> uploaded = [];
  int _active = 0;
  int mostAtOnce = 0;
  void Function(String name)? onUpload;

  /// Il caricamento che fallisce, per nome.
  String? failUpload;

  DriveItem _put(DriveItem item) => items[item.id] = item;

  String folder(String path) {
    var parent = root;
    for (final name in path.split('/').where((part) => part.isNotEmpty)) {
      final found = items.values.where((i) => i.folder && i.name == name && i.parents.contains(parent));
      parent = found.isNotEmpty
          ? found.first.id
          : _put(DriveItem(id: 'f${_next++}', name: name, folder: true, parents: [parent])).id;
    }
    return parent;
  }

  /// Un file messo da un altro, il server.
  void place(String path, List<int> bytes) {
    final parent = folder(p.posix.dirname(path) == '.' ? '' : p.posix.dirname(path));
    // Un file che c'è già si riscrive al suo posto, come farebbe Drive.
    final id = find(path)?.id ?? 'x${_next++}';
    _put(DriveItem(id: id, name: p.posix.basename(path), size: bytes.length, md5: md5.convert(bytes).toString(), parents: [parent]));
    contents[id] = Uint8List.fromList(bytes);
  }

  DriveItem? find(String path) {
    var parent = root;
    final parts = path.split('/');
    for (var i = 0; i < parts.length; i++) {
      final found = items.values.where((item) => item.name == parts[i] && item.parents.contains(parent)).toList();
      if (found.isEmpty) return null;
      if (i == parts.length - 1) return found.first;
      parent = found.first.id;
    }
    return null;
  }

  Uint8List? read(String path) => contents[find(path)?.id];

  List<String> namesIn(String path) => [
        for (final item in items.values)
          if (item.parents.contains(path.isEmpty ? root : find(path)!.id)) item.name,
      ]..sort();

  @override
  Future<List<DriveItem>> childrenOf(List<String> folderIds) async =>
      [for (final item in items.values) if (item.parents.any(folderIds.contains)) item];

  @override
  Future<DriveItem> createFolder(String name, String parentId) async =>
      _put(DriveItem(id: 'f${_next++}', name: name, folder: true, parents: [parentId]));

  @override
  Future<void> download(String id, File target) async {
    await target.writeAsBytes(contents[id]!);
  }

  @override
  Future<void> trash(String id) async => items.remove(id);

  @override
  Future<DriveItem> upload(File file, {String? id, String? name, String? parentId, DateTime? modified}) async {
    final bytes = await file.readAsBytes();
    final previous = id == null ? null : items[id];
    if ((name ?? previous?.name) == failUpload) throw const DriveOffline();
    _active++;
    mostAtOnce = _active > mostAtOnce ? _active : mostAtOnce;
    // Un caricamento vero dura: gli altri devono potersi sovrapporre.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _active--;
    uploads++;
    uploaded.add(name ?? previous!.name);
    onUpload?.call(name ?? previous!.name);
    final item = _put(DriveItem(
      id: id ?? 'u${_next++}',
      name: name ?? previous!.name,
      size: bytes.length,
      md5: md5.convert(bytes).toString(),
      parents: previous?.parents ?? [parentId!],
    ));
    contents[item.id] = bytes;
    return item;
  }
}

Map<String, Object?> readJson(File file) => jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

Map<String, Object?> driveJson(FakeDrive drive, String path) =>
    jsonDecode(utf8.decode(drive.read(path)!)) as Map<String, Object?>;

void main() {
  late Directory temporary;
  late FakeMangaK http;
  late Series series;
  late FakeImageTools images;
  final provider = MangaK();

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('kagami-archive');
    http = FakeMangaK();
    series = await provider.fetchSeries('https://mangak.io/test-series', http);
    images = FakeImageTools();
  });

  tearDown(() => temporary.delete(recursive: true));

  String libraryPath() => p.join(temporary.path, 'library');

  Archiver local({ArchiveStore? store}) => Archiver(
        provider: provider,
        http: http,
        store: store ?? LocalStore(libraryPath()),
        scratch: Directory(p.join(temporary.path, 'scratch')),
        images: images,
        delay: Duration.zero,
      );

  group('in una cartella del telefono', () {
    test('le tavole di un capitolo scendono insieme, nell\'ordine giusto', () async {
      http.imageDelay = const Duration(milliseconds: 20);
      final result = await local().download(series, ids: {'1'});
      expect(result.failed, isEmpty);
      expect(http.mostAtOnce, 2);
      final chapter = readJson(File(p.join(libraryPath(), result.folder, 'chapters', '0001 - Chapter 1 [C1]', 'chapter.json')));
      expect((chapter['pages'] as List).map((page) => (page as Map)['source']), http.urls[1]);
    });

    test('scarica, riprende e ripara', () async {
      final archiver = local();
      final first = await archiver.download(series);
      expect((first.completed, first.pagesDownloaded), (2, 3));
      expect(first.failed, isEmpty);
      final folder = Directory(p.join(libraryPath(), first.folder));
      expect(p.basename(folder.path), 'Test Series [mangak-S1]');
      final manifest = readJson(File(p.join(folder.path, 'series.json')));
      expect(manifest['schemaVersion'], 3);
      expect(manifest['metadataSchemaVersion'], 2);
      final metadata = manifest['metadata'] as Map;
      expect(metadata['description'], 'A story');
      expect(metadata['artists'], ['Artist']);
      expect((metadata['source'] as Map)['summary'], 'A story');
      final cover = manifest['cover'] as Map;
      expect((cover['file'], cover['thumbnail'], cover['width'], cover['height']),
          ('cover.webp', 'cover.thumb.webp', 80, 120));
      expect(File(p.join(folder.path, 'cover.thumb.webp')).existsSync(), isTrue);
      final chapters = Directory(p.join(folder.path, 'chapters')).listSync().map((e) => p.basename(e.path)).toList()..sort();
      expect(chapters, ['0001 - Chapter 1 [C1]', '0002 - Chapter 2 [C2]']);
      final chapter = readJson(File(p.join(folder.path, 'chapters', chapters.first, 'chapter.json')));
      expect(chapter['complete'], isTrue);
      expect((chapter['pages'] as List).map((page) => (page as Map)['file']), ['0001.webp', '0002.webp']);
      expect((chapter['metadata'] as Map)['updatedAt'], 'yesterday');
      expect(((chapter['metadata'] as Map)['source'] as Map).containsKey('latest_comments'), isFalse);

      final second = await archiver.download(series);
      expect((second.pagesDownloaded, second.pagesSkipped), (0, 3));
      expect(http.imageRequests, hasLength(4));

      final damaged = File(p.join(folder.path, 'chapters', chapters.first, '0002.webp'));
      damaged.writeAsStringSync('broken');
      final third = await archiver.download(series);
      expect((third.pagesDownloaded, third.pagesSkipped), (1, 2));
      expect(damaged.readAsBytesSync(), http.images[http.urls[1]![1]]);
    });

    test('gli indici descrivono serie e pagine, e la libreria resta del server', () async {
      final library = libraryPath();
      Directory(library).createSync(recursive: true);
      // La riga del server: l'app non la tocca, e non tocca library.json.
      final serverLibrary = File(p.join(library, 'library.json'))
        ..writeAsStringSync(jsonEncode({'format': 'malf', 'formatVersion': 1, 'series': []}));
      final before = serverLibrary.readAsStringSync();
      final result = await local().download(series);
      expect(serverLibrary.readAsStringSync(), before);
      expect(File(p.join(library, '.nomedia')).existsSync(), isTrue);
      final rows = readJson(File(p.join(library, 'reading', 'downloads.json')))['series'] as List;
      final row = rows.single as Map;
      expect(row['key'], 'mangak:S1');
      expect(row['path'], result.folder);
      expect((row['chapterCount'], row['archivedChapterCount'], row['pageCount']), (2, 2, 3));
      expect(row['coverThumbnail'], 'cover.thumb.webp');
      expect(row['latestChapterNumber'], '2');
      expect(row['authors'], ['Writer']);
      final folder = p.join(library, result.folder);
      final index = readJson(File(p.join(folder, 'index.json')));
      final entries = (index['chapters'] as List).cast<Map>();
      expect(entries.map((c) => c['number']), ['1', '2']);
      expect(entries.map((c) => c['order']), [0, 1]);
      expect(entries.first['sortKey'], 1.0);
      expect(entries.first['complete'], isTrue);
      expect(index['signature'], row['signature']);
      final pages = (readJson(File(p.join(folder, 'pages.json')))['pages'] as Map)['C1'] as List;
      expect(pages.map((page) => (page as Map)['file']), ['0001.webp', '0002.webp']);
      expect(((pages.first as Map)['width'], (pages.first as Map)['height']), (80, 120));
    });

    test('la firma è quella che calcola il server', () {
      // `json.dumps(sort_keys=True, ensure_ascii=False)` con i separatori
      // di Python, e i numeri con la virgola scritti come li scrive lui.
      expect(pythonDumps([{'b': 1.0, 'a': null, 'c': 'è'}]), '[{"a": null, "b": 1.0, "c": "è"}]');
      expect(pythonDumps({'x': 16.5, 'y': [true, 2]}), '{"x": 16.5, "y": [true, 2]}');
    });

    test('una tavola che manca lascia il capitolo da riprendere', () async {
      http.failOnce = http.urls[1]![1];
      final first = await local().download(series, ids: {'1'});
      expect((first.completed, first.failed.length), (0, 1));
      // Mai un capitolo a metà fra quelli leggibili.
      final chapters = Directory(p.join(libraryPath(), first.folder, 'chapters')).listSync().map((e) => p.basename(e.path));
      expect(chapters, ['0001 - Chapter 1 [C1].part']);
      final second = await local().download(series, ids: {'1'});
      expect((second.completed, second.pagesDownloaded, second.pagesSkipped), (1, 1, 1));
      final after = Directory(p.join(libraryPath(), first.folder, 'chapters')).listSync().map((e) => p.basename(e.path));
      expect(after, ['0001 - Chapter 1 [C1]']);
    });

    test('un WebP troncato non diventa una tavola', () async {
      http.images[http.urls[1]!.first] = Uint8List.sublistView(webp(80, 120, 'page'), 0, 40);
      final result = await local().download(series, ids: {'1'});
      expect(result.completed, 0);
      expect(result.failed.single.error, contains('incompleta'));
    });

    test('dal capitolo scelto in poi: i precedenti restano in elenco', () async {
      final archiver = local();
      final result = await archiver.download(series, start: '2');
      expect((result.chapters, result.completed), (1, 1));
      expect(result.settled, ['C1', 'C2']);
      final folder = p.join(libraryPath(), result.folder);
      expect(Directory(p.join(folder, 'chapters')).listSync().map((e) => p.basename(e.path)), ['0002 - Chapter 2 [C2]']);
      expect((readJson(File(p.join(folder, 'series.json')))['chapters'] as List).map((c) => (c as Map)['number']), ['1', '2']);
      final index = readJson(File(p.join(folder, 'index.json')));
      final [missing, archived] = (index['chapters'] as List).cast<Map>();
      expect((missing['archived'], missing['complete'], missing['pageCount'], missing['path']), (false, false, 0, null));
      expect(archived['complete'], isTrue);
      expect((index['chapterCount'], index['archivedChapterCount']), (2, 1));
      final completing = await archiver.download(series, start: '1');
      expect((completing.chapters, completing.pagesSkipped), (2, 1));
    });

    test('le tavole alte hanno le tessere, e una ripresa non le rifà', () async {
      http = FakeMangaK(tallPages: true);
      series = await provider.fetchSeries('https://mangak.io/test-series', http);
      final archiver = local();
      final result = await archiver.download(series, ids: {'1'});
      final chapter = p.join(libraryPath(), result.folder, 'chapters', '0001 - Chapter 1 [C1]');
      final record = (readJson(File(p.join(chapter, 'chapter.json')))['pages'] as List).first as Map;
      expect((record['tiles'] as List).map((t) => (t as Map)['file']), ['0001-01.webp', '0001-02.webp', '0001-03.webp']);
      expect((record['tiles'] as List).map((t) => (t as Map)['height']), [1000, 1000, 1000]);
      expect(File(p.join(chapter, '0001.webp')).readAsBytesSync(), http.images[http.urls[1]!.first]);
      final pages = (readJson(File(p.join(p.dirname(p.dirname(chapter)), 'pages.json')))['pages'] as Map)['C1'] as List;
      expect(((pages.first as Map)['tiles'] as List).first,
          {'file': '0001-01.webp', 'height': 1000, 'bytes': ((record['tiles'] as List).first as Map)['size']});
      final made = images.tilesMade;
      await archiver.download(series, ids: {'1'});
      expect(images.tilesMade, made);
      File(p.join(chapter, '0001-03.webp')).writeAsStringSync('rotta');
      await archiver.download(series, ids: {'1'});
      expect(images.tilesMade, made + 1);
    });
  });

  test('Asura Scans fa la stessa strada degli altri siti', () async {
    final asura = FakeAsuraScans();
    final provider = AsuraScans();
    final series = await provider.fetchSeries('https://asurascans.com/comics/war-of-extinction-bd5bdaf8', asura);
    final result = await Archiver(
      provider: provider,
      http: asura,
      store: LocalStore(libraryPath()),
      scratch: Directory(p.join(temporary.path, 'scratch')),
      images: images,
      delay: Duration.zero,
    ).download(series);
    expect((result.completed, result.pagesDownloaded), (2, 3));
    expect(result.failed, isEmpty);
    final folder = p.join(libraryPath(), result.folder);
    expect(p.basename(folder), 'War of Extinction [asurascans-war-of-extinction]');
    final manifest = readJson(File(p.join(folder, 'series.json')));
    expect((manifest['metadata'] as Map)['genres'], ['Action', 'Fantasy']);
    final chapters = Directory(p.join(folder, 'chapters')).listSync().map((e) => p.basename(e.path)).toList()..sort();
    expect(chapters, ['0001 - Chapter 1 [101]', '0002 - Chapter 2 - The Arena [102]']);
    final index = readJson(File(p.join(folder, 'index.json')));
    expect((index['chapters'] as List).map((c) => ((c as Map)['id'], c['complete'])), [('101', true), ('102', true)]);
  });

  group('direttamente su Drive', () {
    late FakeDrive drive;
    DriveStore store({LocalStore? mirror}) => DriveStore(
          remote: drive,
          folderId: FakeDrive.root,
          staging: p.join(temporary.path, 'staging'),
          mirror: mirror,
        );

    setUp(() => drive = FakeDrive());

    test('le tavole salgono e lasciano il telefono', () async {
      final result = await local(store: store()).download(series);
      expect(result.failed, isEmpty);
      final chapter = '${result.folder}/chapters/0001 - Chapter 1 [C1]';
      expect(drive.namesIn(chapter), ['0001.webp', '0002.webp', 'chapter.json']);
      expect(drive.read('$chapter/0002.webp'), http.images[http.urls[1]![1]]);
      expect(drive.namesIn(result.folder),
          ['chapters', 'cover.thumb.webp', 'cover.webp', 'index.json', 'pages.json', 'series.json']);
      expect(drive.namesIn(''), ['.nomedia', result.folder, 'library.json']);
      final library = driveJson(drive, 'library.json');
      expect((library['series'] as List).map((row) => (row as Map)['key']), ['mangak:S1']);
      expect(Directory(p.join(temporary.path, 'staging')).listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test('le tavole salgono insieme, e la ricevuta del capitolo per ultima', () async {
      final result = await local(store: store()).download(series, ids: {'1'});
      expect(result.failed, isEmpty);
      expect(drive.mostAtOnce, greaterThan(1));
      final chapter = drive.uploaded.indexOf('chapter.json');
      expect(drive.uploaded.indexOf('0001.webp'), lessThan(chapter));
      expect(drive.uploaded.indexOf('0002.webp'), lessThan(chapter));
    });

    test('il capitolo seguente scende mentre il precedente sale', () async {
      http.imageDelay = const Duration(milliseconds: 20);
      final timeline = <String>[];
      drive.onUpload = (name) => timeline.add('su $name');
      http.onImage = (url) => timeline.add('giù $url');
      final result = await local(store: store()).download(series);
      expect(result.failed, isEmpty);
      // c.webp è del capitolo 2: parte prima che il capitolo 1 abbia
      // consegnato la sua ricevuta.
      expect(timeline.indexOf('giù ${http.urls[2]!.single}'), lessThan(timeline.indexOf('su chapter.json')));
    });

    test('un capitolo già su Drive non si riscarica, e non si ricarica', () async {
      await local(store: store()).download(series);
      final requests = http.imageRequests.length;
      final uploads = drive.uploads;
      final again = await local(store: store()).download(series);
      expect((again.pagesDownloaded, again.pagesSkipped), (0, 3));
      expect(http.imageRequests.length, requests);
      // Solo series.json, gli indici e library.json: le tavole no.
      expect(drive.uploads - uploads, lessThanOrEqualTo(4));
    });

    test('un caricamento fallito lascia le tavole sul telefono, da riprendere', () async {
      drive.failUpload = '0002.webp';
      await expectLater(local(store: store()).download(series, ids: {'1'}), throwsA(isA<DriveOffline>()));
      final staged = Directory(p.join(temporary.path, 'staging')).listSync(recursive: true).whereType<File>()
          .map((f) => p.basename(f.path)).toSet();
      expect(staged, containsAll(['0001.webp', '0002.webp', 'chapter.json']));
      drive.failUpload = null;
      final requests = http.imageRequests.length;
      final result = await local(store: store()).download(series, ids: {'1'});
      expect(result.completed, 1);
      expect(http.imageRequests.length, requests);
    });

    test('le serie del server restano, i suoi capitoli entrano negli indici', () async {
      // Il server ha già la serie: un'altra riga in libreria, la cartella con
      // il suo nome e il capitolo 1 caricato da lui dopo l'ultimo indice.
      final other = {'key': 'mangak:ALTRO', 'path': 'Altro [mangak-ALTRO]', 'title': 'Altro',
          'archivedChapterCount': 5, 'pageCount': 50, 'bytes': 1000};
      final mine = {'key': 'mangak:S1', 'path': 'Serie del server [mangak-S1]', 'title': 'Serie del server'};
      drive.place('library.json', utf8.encode(jsonEncode({'format': 'malf', 'formatVersion': 1, 'series': [other, mine]})));
      const folder = 'Serie del server [mangak-S1]';
      final page1 = http.images[http.urls[1]![0]]!;
      final page2 = http.images[http.urls[1]![1]]!;
      drive.place('$folder/chapters/0001 - Chapter 1 [C1]/0001.webp', page1);
      drive.place('$folder/chapters/0001 - Chapter 1 [C1]/0002.webp', page2);
      drive.place('$folder/chapters/0001 - Chapter 1 [C1]/chapter.json', utf8.encode(jsonEncode({
        'id': 'C1', 'complete': true, 'completedAt': '2026-09-01T04:00:00+00:00',
        'pages': [
          for (final (i, url) in http.urls[1]!.indexed)
            {'file': '000${i + 1}.webp', 'source': url, 'size': [page1, page2][i].length,
             'sha256': sha256.convert([page1, page2][i]).toString(), 'width': 80, 'height': 120},
        ],
      })));
      final result = await local(store: store()).download(series, start: '2');
      expect(result.folder, folder);
      expect(drive.namesIn('$folder/chapters'), ['0001 - Chapter 1 [C1]', '0002 - Chapter 2 [C2]']);
      final index = driveJson(drive, '$folder/index.json');
      expect((index['chapters'] as List).map((c) => (c as Map)['complete']), [true, true]);
      final library = driveJson(drive, 'library.json');
      expect((library['series'] as List).map((row) => (row as Map)['key']), ['mangak:ALTRO', 'mangak:S1']);
      expect(((library['series'] as List).first as Map)['pageCount'], 50);
      expect(library['seriesCount'], 2);
      // Nessun doppione: ogni cartella e ogni file una volta sola.
      final names = drive.items.values.map((item) => '${item.parents.first}/${item.name}').toList();
      expect(names.toSet().length, names.length);
    });

    test('un indice rimasto a metà si ripara: vale il chapter.json, non la voce vecchia', () async {
      final first = await local(store: store()).download(series);
      final folder = first.folder;
      // Com'era Disfarming: il capitolo 1 indicizzato mentre saliva, il 2
      // senza tavole in pages.json. Su Drive tutt'e due sono completi.
      final index = driveJson(drive, '$folder/index.json');
      final chapters = (index['chapters'] as List).cast<Map<String, Object?>>();
      chapters[0]
        ..['complete'] = false
        ..['pageCount'] = 0
        ..['bytes'] = 0;
      chapters[1]['pageCount'] = 0;
      drive.place('$folder/index.json', utf8.encode(jsonEncode(index)));
      final pages = driveJson(drive, '$folder/pages.json');
      (pages['pages'] as Map).clear();
      drive.place('$folder/pages.json', utf8.encode(jsonEncode(pages)));

      final again = await local(store: store()).download(series);
      expect(again.pagesDownloaded, 0);
      expect(again.failed, isEmpty);
      final fixed = driveJson(drive, '$folder/index.json');
      expect((fixed['chapters'] as List).map((c) => ((c as Map)['complete'], c['pageCount'])), [(true, 2), (true, 1)]);
      expect(((driveJson(drive, '$folder/pages.json')['pages'] as Map)['C1'] as List), hasLength(2));
    });

    test('Drive e telefono: il capitolo resta anche in una cartella locale', () async {
      final mirror = LocalStore(libraryPath());
      final result = await local(store: store(mirror: mirror)).download(series, ids: {'1'});
      final chapter = p.join(libraryPath(), result.folder, 'chapters', '0001 - Chapter 1 [C1]');
      expect(Directory(chapter).listSync().map((e) => p.basename(e.path)).toSet(),
          {'0001.webp', '0002.webp', 'chapter.json'});
      expect(drive.namesIn('${result.folder}/chapters/0001 - Chapter 1 [C1]'), ['0001.webp', '0002.webp', 'chapter.json']);
      expect(File(p.join(libraryPath(), result.folder, 'index.json')).existsSync(), isTrue);
      expect(File(p.join(libraryPath(), 'reading', 'downloads.json')).existsSync(), isTrue);
    });

    test('togliere una serie la manda nel cestino e lascia le righe degli altri', () async {
      final other = {'key': 'mangak:ALTRO', 'path': 'Altro [mangak-ALTRO]', 'title': 'Altro'};
      drive.place('library.json', utf8.encode(jsonEncode({'format': 'malf', 'formatVersion': 1, 'series': [other]})));
      final mirror = LocalStore(libraryPath());
      final result = await local(store: store(mirror: mirror)).download(series, ids: {'1'});
      await store(mirror: mirror).removeSeries(result.folder, 'mangak:S1');
      expect(drive.namesIn(''), ['.nomedia', 'library.json']);
      final library = driveJson(drive, 'library.json');
      expect((library['series'] as List).map((row) => (row as Map)['key']), ['mangak:ALTRO']);
      expect(library['seriesCount'], 1);
      expect(Directory(p.join(libraryPath(), result.folder)).existsSync(), isFalse);
      final downloads = readJson(File(p.join(libraryPath(), 'reading', 'downloads.json')));
      expect(downloads['series'], isEmpty);
      // Una seconda volta non c'è più niente da togliere, e non è un errore.
      await store().removeSeries(result.folder, 'mangak:S1');
    });
  });
}
