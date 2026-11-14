// La riparazione delle serie archiviate: adozione dell'identità nuova di
// Coffee Manga (serie `7743` → slug, capitoli numerici → slug) su disco e su
// Drive, senza riscaricare le tavole; titolo, copertina e capitoli nuovi;
// nessuna scrittura alla seconda passata; una serie rotta non ferma le altre.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/health.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/indexes.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/repair.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'archive_fakes.dart';

const String oldFolder = 'The House Without Time [coffeemanga-7743]';
const String newFolder = 'The House Without Time [coffeemanga-the-house-without-time]';
const String oldKey = 'coffeemanga:7743';
const String newKey = 'coffeemanga:the-house-without-time';
const String host = FakeCoffeeManga.host;

/// Una serie come la archiviava il provider del sito vecchio: id numerici,
/// un prologo che il sito nuovo non elenca, il capitolo 1.5 a metà e con un
/// link che il sito nuovo non ha più. Percorso → byte.
Map<String, List<int>> oldArchive() {
  final files = <String, List<int>>{};
  final page = webp(80, 120, 'old-page');
  final cover = webp(80, 120, 'old-cover');
  Map<String, Object?> chapter(String id, String number, String title, String source, {bool complete = true}) => {
        'schemaVersion': 3,
        'id': id,
        'number': number,
        'title': title,
        'source': source,
        'metadata': const {},
        'complete': complete,
        'pages': [
          {'file': '0001.webp', 'source': '$host/old/$id/1.webp', 'size': page.length,
            'sha256': sha256.convert(page).toString(), 'width': 80, 'height': 120},
        ],
      };
  final chapters = [
    ('217600', '0', 'Prologue', '$host/manga/the-house-without-time/prologue/', true),
    ('217607', '1', 'Chapter 1', '$host/manga/the-house-without-time/chapter-1/', true),
    ('217608', '1.5', 'Chapter 1.5', '$host/?p=217608', false),
  ];
  final archived = <String, ArchivedChapter>{};
  for (final (id, number, title, source, complete) in chapters) {
    final name = '${number == '0' ? '0000' : number == '1' ? '0001' : '0001.5'} - $title [$id]';
    final manifest = chapter(id, number, title, source, complete: complete);
    files['$oldFolder/chapters/$name/0001.webp'] = page;
    files['$oldFolder/chapters/$name/chapter.json'] = utf8.encode(prettyJson(manifest));
    archived[id] = ArchivedChapter.fromManifest('chapters/$name', manifest);
  }
  final series = <String, Object?>{
    'schemaVersion': 3,
    'metadataSchemaVersion': 2,
    'provider': 'coffeemanga',
    'id': '7743',
    'title': 'The House Without Time (old)',
    'source': FakeCoffeeManga.url,
    'fetchedAt': '2026-01-01T00:00:00Z',
    'metadata': {'releaseStatus': 'ongoing'},
    'cover': {'file': 'cover.webp', 'source': '$host/wp-content/old.jpg', 'size': cover.length, 'thumbnail': 'cover.thumb.webp'},
    'chapters': [
      for (final (id, number, title, source, _) in chapters)
        {'id': id, 'number': number, 'title': title, 'source': source, 'metadata': const {}},
    ],
  };
  files['$oldFolder/series.json'] = utf8.encode(prettyJson(series));
  files['$oldFolder/cover.webp'] = cover;
  files['$oldFolder/cover.thumb.webp'] = utf8.encode('old-thumb');
  final built = buildSeriesIndex(series, archived)!;
  files['$oldFolder/index.json'] = utf8.encode(prettyJson(built.index));
  files['$oldFolder/pages.json'] = utf8.encode(prettyJson(built.pages));
  files['library.json'] = utf8.encode(prettyJson(libraryWith(null, summarize(oldFolder, series, built.index))));
  return files;
}

/// Un disco che conta le scritture: la seconda riparazione non ne deve fare.
class CountingStore extends LocalStore {
  CountingStore(super.root);
  int writes = 0;

  @override
  Future<void> writeSeriesFiles(String folder, Map<String, Uint8List> files) {
    writes++;
    return super.writeSeriesFiles(folder, files);
  }

  @override
  Future<void> writeLibraryRow(Map<String, Object?> row) {
    writes++;
    return super.writeLibraryRow(row);
  }

  @override
  Future<void> renameFolder(String relative, String name) {
    writes++;
    return super.renameFolder(relative, name);
  }

  @override
  Future<void> writeChapterManifest(String chapterPath, Map<String, Object?> manifest) {
    writes++;
    return super.writeChapterManifest(chapterPath, manifest);
  }
}

Map<String, Object?> decode(List<int> bytes) => jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;

void main() {
  late Directory temporary;
  late FakeCoffeeManga coffee;
  late Tracking tracking;
  late HealthLog health;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('kagami-repair');
    coffee = FakeCoffeeManga();
    tracking = Tracking(File(p.join(temporary.path, 'ongoing.json')));
    health = HealthLog(File(p.join(temporary.path, 'health.json')));
    await health.markBroken('coffeemanga', 'Serie Coffee Manga non trovata.');
    await File(tracking.file.path).writeAsString(jsonEncode({
      'schemaVersion': 1,
      'series': [
        {
          'provider': 'coffeemanga',
          'id': '7743',
          'title': 'The House Without Time',
          'url': FakeCoffeeManga.url,
          'target': {'destination': 'drive', 'folderId': 'ROOT'},
          'chapters': ['217600', '217607', '217608'],
          'addedAt': '2026-01-01T00:00:00Z',
          'problem': 'Serie Coffee Manga non trovata.',
        },
      ],
    }));
  });

  tearDown(() => temporary.delete(recursive: true));

  Future<List<RepairOutcome>> repair(ArchiveStore store,
          {ProviderHttp? http,
          void Function(int done, int total, String title)? progress,
          Future<void> Function(RepairOutcome outcome)? onOutcome}) =>
      repairLibrary(
        store: store,
        httpFor: (_) => http ?? coffee,
        scratch: Directory(p.join(temporary.path, 'scratch')),
        images: FakeImageTools(),
        health: health,
        tracking: tracking,
        progress: progress,
        onOutcome: onOutcome,
        delay: Duration.zero,
        pause: Duration.zero,
      );

  void expectAdopted(RepairOutcome outcome, Map<String, Object?> series, Map<String, Object?> index,
      Map<String, Object?> library) {
    expect(outcome.error, isNull);
    expect(outcome.adoptedFrom, oldKey);
    expect(outcome.key, newKey);
    expect(outcome.renamed, {'217607': 'chapter-1', '217608': 'chapter-1-5'});
    expect(outcome.unlisted, ['217600']);
    expect(outcome.incomplete, ['chapter-1-5']);
    expect((outcome.titleChanged, outcome.coverChanged), (true, true));
    expect([series['id'], series['formerKeys'], series['title']],
        ['the-house-without-time', [oldKey], 'The House Without Time']);
    expect([
      for (final entry in (series['chapters'] as List).cast<Map>()) [entry['id'], entry['formerIds'], entry['listed']]
    ], [
      ['217600', null, false],
      ['chapter-1', ['217607'], null],
      ['chapter-1-5', ['217608'], null],
    ]);
    expect((series['cover'] as Map)['source'], FakeCoffeeManga.cover);
    expect([index['key'], index['formerKeys']], [newKey, [oldKey]]);
    expect([
      for (final entry in (index['chapters'] as List).cast<Map>()) (entry['id'], entry['archived'], entry['complete'])
    ], [
      ('217600', true, true),
      ('chapter-1', true, true),
      ('chapter-1-5', true, false),
    ]);
    expect([for (final row in (library['series'] as List).cast<Map>()) [row['key'], row['path'], row['formerKeys']]],
        [[newKey, newFolder, [oldKey]]]);
    // Le tavole non si riscaricano: al sito si chiedono la serie e la copertina.
    expect(coffee.requests.where((url) => url.contains('/img/SIG')), isEmpty);
  }

  Future<void> expectTracked() async {
    final [entry] = await tracking.load();
    expect([entry.key, entry.problem, entry.chapters], [newKey, null, ['217600', 'chapter-1', 'chapter-1-5']]);
    expect(await health.isBroken('coffeemanga'), isFalse);
  }

  test('su disco: la serie adotta lo slug, cartelle rinominate, tavole al loro posto', () async {
    final root = p.join(temporary.path, 'library');
    for (final MapEntry(:key, :value) in oldArchive().entries) {
      File(p.join(root, key))
        ..createSync(recursive: true)
        ..writeAsBytesSync(value);
    }
    final store = CountingStore(root);
    final [outcome] = await repair(store);
    Map<String, Object?> json(String path) => decode(File(p.join(root, path)).readAsBytesSync());
    expect(Directory(p.join(root, oldFolder)).existsSync(), isFalse);
    expect(
      (Directory(p.join(root, newFolder, 'chapters')).listSync().map((e) => p.basename(e.path)).toList()..sort()),
      ['0000 - Prologue [217600]', '0001 - Chapter 1 [chapter-1]', '0001.5 - Chapter 1.5 [chapter-1-5]'],
    );
    final chapter = json('$newFolder/chapters/0001 - Chapter 1 [chapter-1]/chapter.json');
    expect((chapter['id'], chapter['source'], chapter['complete']),
        ('chapter-1', '$host/manga/the-house-without-time/chapter-1/', true));
    expect(File(p.join(root, newFolder, 'chapters', '0001 - Chapter 1 [chapter-1]', '0001.webp')).readAsBytesSync(),
        webp(80, 120, 'old-page'));
    // Sul telefono la riga va in `reading/downloads.json`; library.json resta di chi l'ha scritto.
    expectAdopted(outcome, json('$newFolder/series.json'), json('$newFolder/index.json'),
        json('reading/downloads.json'));
    await expectTracked();

    store.writes = 0;
    final [again] = await repair(store);
    expect((again.error, again.adoptedFrom, again.written, store.writes), (null, null, false, 0));
  });

  test('su Drive: la stessa adozione, con le rinomine e senza caricare tavole', () async {
    final drive = FakeDrive();
    for (final MapEntry(:key, :value) in oldArchive().entries) {
      drive.place(key, value);
    }
    final store = DriveStore(remote: drive, folderId: FakeDrive.root, staging: p.join(temporary.path, 'staging'));
    final files = ArchiveFiles(p.join(temporary.path, 'support'));
    final outcomes = await repairLibrary(
      store: store,
      httpFor: (_) => coffee,
      scratch: Directory(p.join(temporary.path, 'scratch')),
      images: FakeImageTools(),
      health: health,
      tracking: tracking,
      files: files,
      target: const ArchiveTarget(destination: ArchiveDestination.drive, folderId: FakeDrive.root),
      delay: Duration.zero,
      pause: Duration.zero,
    );
    final [outcome] = outcomes;
    Map<String, Object?> json(String path) => decode(drive.read(path)!);
    expect(drive.find(oldFolder), isNull);
    expect(drive.namesIn('$newFolder/chapters'),
        ['0000 - Prologue [217600]', '0001 - Chapter 1 [chapter-1]', '0001.5 - Chapter 1.5 [chapter-1-5]']);
    expect(json('$newFolder/chapters/0001 - Chapter 1 [chapter-1]/chapter.json')['id'], 'chapter-1');
    expect(drive.uploaded.where((name) => name.endsWith('.webp') && name != 'cover.webp' && name != 'cover.thumb.webp'),
        isEmpty);
    expectAdopted(outcome, json('$newFolder/series.json'), json('$newFolder/index.json'), json('library.json'));
    await expectTracked();
    final [job] = await files.jobs();
    expect([job.url, job.ids], [FakeCoffeeManga.url, {'chapter-1-5'}]);

    // Una seconda passata, con gli elenchi riletti da Drive, non scrive niente.
    final uploads = drive.uploads;
    final renames = drive.renames;
    final again = await repairLibrary(
      store: DriveStore(remote: drive, folderId: FakeDrive.root, staging: p.join(temporary.path, 'staging')),
      httpFor: (_) => coffee,
      scratch: Directory(p.join(temporary.path, 'scratch')),
      images: FakeImageTools(),
      delay: Duration.zero,
      pause: Duration.zero,
    );
    expect((again.single.error, again.single.written, drive.uploads, drive.renames), (null, false, uploads, renames));
  });

  test('senza cambio d\'identità ripara titolo, copertina e capitoli nuovi', () async {
    final drive = FakeDrive();
    for (final MapEntry(:key, :value) in oldArchive().entries) {
      drive.place(key, value);
    }
    final store = DriveStore(remote: drive, folderId: FakeDrive.root, staging: p.join(temporary.path, 'staging'));
    await repair(store);
    coffee.chapters.insert(0, ('chapter-2', '2', 183005, false));
    final before = drive.renames;
    final [outcome] = await repair(DriveStore(remote: drive, folderId: FakeDrive.root, staging: p.join(temporary.path, 'staging')));
    expect([outcome.adoptedFrom, outcome.added, outcome.seriesChanged, drive.renames], [null, ['chapter-2'], true, before]);
    final index = decode(drive.read('$newFolder/index.json')!);
    expect([for (final entry in (index['chapters'] as List).cast<Map>()) entry['id']],
        ['217600', 'chapter-1', 'chapter-1-5', 'chapter-2']);
    expect(index['chapterCount'], 4);
  });

  test('una serie che fallisce non ferma le altre', () async {
    final drive = FakeDrive();
    for (final MapEntry(:key, :value) in oldArchive().entries) {
      drive.place(key, value);
    }
    // Una seconda serie dello stesso sito, che il sito non trova più.
    final library = decode(drive.read('library.json')!);
    final rows = [...(library['series'] as List).cast<Map<String, Object?>>()];
    rows.insert(0, {
      'key': 'coffeemanga:gone',
      'path': 'Gone [coffeemanga-gone]',
      'provider': 'coffeemanga',
      'title': 'Gone',
      'source': '$host/manga/gone/',
    });
    drive.place('library.json', utf8.encode(prettyJson({...library, 'series': rows})));
    final store = DriveStore(remote: drive, folderId: FakeDrive.root, staging: p.join(temporary.path, 'staging'));
    final steps = <(int, int, String)>[];
    final recorded = <RepairOutcome>[];
    final outcomes = await repair(store,
        progress: (done, total, title) => steps.add((done, total, title)), onOutcome: (outcome) async => recorded.add(outcome));
    expect(recorded, outcomes);
    expect(outcomes.map((outcome) => (outcome.key, outcome.error == null)), [('coffeemanga:gone', false), (newKey, true)]);
    expect(steps.map((step) => (step.$1, step.$2)), [(0, 2), (1, 2)]);
    final records = [
      for (final outcome in outcomes) ArchiveOutcome.fromJson(jsonDecode(jsonEncode(outcome.toArchiveOutcome().toJson())) as Map<String, Object?>)
    ];
    expect(records.map((record) => (record.ok, record.seriesKey, record.repair?['adoptedFrom'])),
        [(false, 'coffeemanga:gone', null), (true, newKey, oldKey)]);
    expect(drive.find(newFolder), isNotNull);
    await expectTracked();
  });

  test('adoptCopy: la copia del telefono prende nomi e id di Drive, senza rete, una volta sola', () async {
    final root = p.join(temporary.path, 'phone');
    for (final MapEntry(:key, :value) in oldArchive().entries) {
      File(p.join(root, key))
        ..createSync(recursive: true)
        ..writeAsBytesSync(value);
    }
    // Come sul telefono: la riga sta in downloads.json, non in library.json.
    File(p.join(root, 'library.json')).renameSync(p.join(root, 'downloads.json'));
    Directory(p.join(root, 'reading')).createSync();
    File(p.join(root, 'downloads.json')).renameSync(p.join(root, 'reading', 'downloads.json'));
    final fresh = <String, Object?>{
      'schemaVersion': 3,
      'metadataSchemaVersion': 2,
      'provider': 'coffeemanga',
      'id': 'the-house-without-time',
      'formerKeys': [oldKey],
      'title': 'The House Without Time',
      'source': FakeCoffeeManga.url,
      'fetchedAt': '2026-02-01T00:00:00Z',
      'metadata': {'releaseStatus': 'ongoing'},
      'cover': {'file': 'cover.webp', 'source': FakeCoffeeManga.cover},
      'chapters': [
        {'id': '217600', 'number': '0', 'title': 'Prologue', 'source': '$host/manga/the-house-without-time/prologue/',
          'metadata': const {}, 'listed': false},
        {'id': 'chapter-1', 'number': '1', 'title': 'Chapter 1', 'source': '$host/manga/the-house-without-time/chapter-1/',
          'metadata': const {}, 'formerIds': ['217607']},
        {'id': 'chapter-1-5', 'number': '1.5', 'title': 'Chapter 1.5', 'source': '$host/manga/the-house-without-time/chapter-1-5/',
          'metadata': const {}, 'formerIds': ['217608']},
      ],
    };
    final store = CountingStore(root);
    final outcome = await adoptCopy(store: store, path: oldFolder, fresh: fresh);
    Map<String, Object?> json(String path) => decode(File(p.join(root, path)).readAsBytesSync());
    expect(outcome.renamed, {'217607': 'chapter-1', '217608': 'chapter-1-5'});
    expect(Directory(p.join(root, oldFolder)).existsSync(), isFalse);
    expect(
      Directory(p.join(root, newFolder, 'chapters')).listSync().map((e) => p.basename(e.path)).toList()..sort(),
      ['0000 - Prologue [217600]', '0001 - Chapter 1 [chapter-1]', '0001.5 - Chapter 1.5 [chapter-1-5]'],
    );
    expect(json('$newFolder/chapters/0001 - Chapter 1 [chapter-1]/chapter.json')['id'], 'chapter-1');
    expect(File(p.join(root, newFolder, 'cover.webp')).existsSync(), isTrue);
    expect(json('$newFolder/series.json')['id'], 'the-house-without-time');
    final index = json('$newFolder/index.json');
    expect([for (final c in (index['chapters'] as List).cast<Map>()) (c['id'], c['archived'], c['complete'])],
        [('217600', true, true), ('chapter-1', true, true), ('chapter-1-5', true, false)]);
    expect([for (final row in (json('reading/downloads.json')['series'] as List).cast<Map>()) [row['key'], row['path'], row['formerKeys']]],
        [[newKey, newFolder, [oldKey]]]);

    store.writes = 0;
    final again = await adoptCopy(store: store, path: newFolder, fresh: fresh);
    expect((again.written, store.writes), (false, 0));
    // Ripresa dopo una cartella già rinominata: la riga ha ancora il percorso di prima.
    final resumed = await adoptCopy(store: store, path: oldFolder, fresh: fresh);
    expect((resumed.written, store.writes), (false, 0));
  });
}
