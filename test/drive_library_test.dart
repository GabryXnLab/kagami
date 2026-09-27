import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/downloads.dart';
import 'package:kagami/src/data/drive_library.dart';
import 'package:kagami/src/data/library_repository.dart';
import 'package:kagami/src/data/network.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:path/path.dart' as p;

import 'network_helpers.dart';

/// Drive in memoria: un albero di cartelle, e il conto delle richieste.
class FakeClient extends DriveClient {
  FakeClient({NetworkMonitor? network})
      : super(({refresh = false}) async => 'token', network: network ?? NetworkMonitor.instance);

  final Map<String, (DriveItem, String?)> items = {};
  final List<String> calls = [];
  bool offline = false;

  void add(String id, String name, String parent, {String? content}) {
    items[id] = (
      DriveItem(
        id: id,
        name: name,
        folder: content == null,
        md5: content == null ? null : 'md5-$id-${content.hashCode}',
        parents: [parent],
      ),
      content,
    );
  }

  void _call(String what) {
    if (offline) throw const DriveException('Nessuna connessione');
    calls.add(what);
  }

  @override
  Future<List<DriveItem>> children(String folderId) async {
    _call('children:$folderId');
    return [
      for (final (item, _) in items.values)
        if (item.parents.contains(folderId)) item,
    ];
  }

  @override
  Future<List<DriveItem>> query(String q, {String orderBy = 'name'}) async {
    _call('query');
    return [
      for (final (item, _) in items.values)
        if (!item.folder && q.contains("'${item.name}'")) item,
    ];
  }

  @override
  Future<String> text(String id) async {
    _call('text:$id');
    return items[id]!.$2!;
  }

  @override
  Future<void> download(String id, File target) async {
    _call('download:$id');
    await target.writeAsString(items[id]!.$2!);
  }

  @override
  Future<void> trash(String id) async {
    _call('trash:$id');
    items.remove(id);
  }
}

void main() {
  late Directory temp;
  late FakeClient client;

  DriveRepository repository() => DriveRepository(
        client: client,
        folderId: 'R',
        stateDirectory: p.join(temp.path, 'state'),
        files: DriveFileCache(
          Directory(p.join(temp.path, 'cache')),
          limitBytes: 1 << 20,
        ),
      );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kagami-drive');
    client = FakeClient()
      ..add('LIB', libraryIndexFile, 'R', content: jsonEncode({
        'format': 'malf',
        'series': [
          {'key': 'mangak:S1', 'path': 'Prova [mangak-S1]', 'title': 'Prova',
           'coverThumbnail': 'cover.thumb.webp', 'archivedChapterCount': 1},
        ],
      }))
      ..add('S', 'Prova [mangak-S1]', 'R')
      ..add('IDX', seriesIndexFile, 'S', content: jsonEncode({
        'key': 'mangak:S1',
        'chapters': [
          {'id': 'C1', 'order': 0, 'complete': true, 'archived': true,
           'pageCount': 1, 'path': 'chapters/0001 - Primo [C1]'},
        ],
      }))
      ..add('THUMB', 'cover.thumb.webp', 'S', content: 'copertina')
      ..add('CH', 'chapters', 'S')
      ..add('C1', '0001 - Primo [C1]', 'CH')
      ..add('P1', '0001.webp', 'C1', content: 'tavola');
  });
  tearDown(() async => temp.delete(recursive: true));

  test('la libreria si apre con due richieste più il suo indice', () async {
    final drive = repository();
    final library = await drive.loadLibrary();
    expect(library.series.single.key, 'mangak:S1');
    expect(client.calls, ['children:R', 'query', 'text:LIB']);

    client.calls.clear();
    final series = await drive.loadSeries(library.series.single);
    expect(series!.readable.single.id, 'C1');
    expect(client.calls, ['text:IDX']);
  });

  test('una tavola si trova elencando le cartelle, e gli elenchi restano',
      () async {
    final drive = repository();
    await drive.loadLibrary();
    client.calls.clear();
    final page = await drive.resolve('Prova [mangak-S1]/chapters/0001 - Primo [C1]/0001.webp');
    expect(page!.id, 'P1');
    expect(client.calls, ['children:S', 'children:CH', 'children:C1']);

    client.calls.clear();
    final again = repository();
    await again.loadLibrary();
    client.calls.clear();
    await again.resolve('Prova [mangak-S1]/chapters/0001 - Primo [C1]/0001.webp');
    expect(client.calls, isEmpty, reason: 'gli elenchi stanno su disco');
  });

  test('un capitolo arrivato dopo si trova rielencando una volta', () async {
    final drive = repository();
    await drive.loadLibrary();
    await drive.resolve('Prova [mangak-S1]/chapters/0001 - Primo [C1]/0001.webp');
    client
      ..add('C2', '0002 - Secondo [C2]', 'CH')
      ..add('P2', '0001.webp', 'C2', content: 'altra');
    final fresh = repository();
    await fresh.loadLibrary();
    client.calls.clear();
    final page = await fresh.resolve('Prova [mangak-S1]/chapters/0002 - Secondo [C2]/0001.webp');
    expect(page!.id, 'P2');
    expect(client.calls, ['children:CH', 'children:C2']);
  });

  test('offline la libreria si apre subito, senza nessuna richiesta', () async {
    await repository().loadLibrary();
    final network = monitor() as Switchable;
    await network.goOffline();
    client = FakeClient(network: network)..items.addAll(client.items);
    final drive = repository();
    final library = await drive.loadLibrary();
    expect(library.series.single.title, 'Prova');
    expect(drive.fromSnapshot, isTrue);
    expect(client.calls, isEmpty);
    network.dispose();
  });

  test('all\'apertura la libreria è l\'istantanea, e Drive si rilegge dietro',
      () async {
    await repository().loadLibrary();
    client.calls.clear();
    final drive = repository();
    final library = await drive.loadLibrary();
    expect(library.series.single.title, 'Prova');
    expect(drive.fromSnapshot, isFalse, reason: 'la rete c\'è: nessun avviso');
    expect(client.calls, isEmpty);

    expect(await drive.revalidate(), isFalse, reason: 'niente è cambiato');
    expect(client.calls, ['children:R', 'query']);
    client.calls.clear();
    expect(await drive.revalidate(), isFalse);
    expect(client.calls, isEmpty, reason: 'appena riletta');
    await drive.pruned;
  });

  test('un library.json nuovo trovato dietro fa rifare la griglia', () async {
    await repository().loadLibrary();
    client.add('LIB', libraryIndexFile, 'R', content: jsonEncode({
      'format': 'malf',
      'series': [
        {'key': 'mangak:S1', 'path': 'Prova [mangak-S1]', 'title': 'Prova 2'},
      ],
    }));
    final drive = repository();
    expect((await drive.loadLibrary()).series.single.title, 'Prova');
    expect(await drive.revalidate(), isTrue);
    expect((await drive.loadLibrary()).series.single.title, 'Prova 2');
    await drive.pruned;
  });

  test('senza rete la libreria è quella dell\'ultima volta', () async {
    await repository().loadLibrary();
    client.offline = true;
    final library = await repository().loadLibrary();
    expect(library.series.single.title, 'Prova');
  });

  test('le tavole scendono in cache una volta sola', () async {
    final drive = repository();
    await drive.loadLibrary();
    final files = DriveFiles(drive);
    const address = 'drive:Prova [mangak-S1]/chapters/0001 - Primo [C1]/0001.webp';
    final both = await Future.wait([
      files.fetch(address),
      files.fetch(address, urgent: true),
    ]);
    expect(both.first, both.last);
    expect(await File(both.first).readAsString(), 'tavola');
    expect(client.calls.where((call) => call == 'download:P1'), hasLength(1));
    expect(files.peek(address), both.first);

    // La miniatura si riconosce dall'impronta trovata con la ricerca.
    final cover = await files.fetch('drive:Prova [mangak-S1]/cover.thumb.webp');
    expect(p.basename(cover), client.items['THUMB']!.$1.md5);
  });

  test('un capitolo scaricato diventa un capitolo della cartella', () async {
    final drive = repository();
    final entry = (await drive.loadLibrary()).series.single;
    final chapter = (await drive.loadSeries(entry))!.chapters.single;
    final destination = p.join(temp.path, 'manga');
    final downloader = ChapterDownloader(drive, DriveFiles(drive));
    final progress = <int>[];
    await downloader.download(
      destination: destination,
      entry: entry,
      chapter: chapter,
      pages: const [PageEntry(file: '0001.webp')],
      onPage: (done, _) => progress.add(done),
      cancelled: () => false,
    );
    await downloader.finishSeries(destination: destination, entry: entry);

    expect(progress, [0, 1]);
    final local = LibraryRepository(destination, requireIndex: false);
    final library = await local.loadLibrary();
    expect(library.series.single.key, 'mangak:S1');
    expect(library.series.single.archivedChapterCount, 1);
    expect(await local.presentChapters(entry), {'chapters/0001 - Primo [C1]'});
    expect((await local.loadSeries(entry))!.readable.single.id, 'C1');
    final page = File(p.join(destination, entry.path, chapter.path!, '0001.webp'));
    expect(await page.readAsString(), 'tavola');
    expect(
      File(p.join(destination, entry.path, 'cover.thumb.webp')).existsSync(),
      isTrue,
    );
  });

  test('un download annullato non lascia niente', () async {
    final drive = repository();
    final entry = (await drive.loadLibrary()).series.single;
    final chapter = (await drive.loadSeries(entry))!.chapters.single;
    final destination = p.join(temp.path, 'manga');
    await expectLater(
      ChapterDownloader(drive, DriveFiles(drive)).download(
        destination: destination,
        entry: entry,
        chapter: chapter,
        pages: const [PageEntry(file: '0001.webp')],
        onPage: (_, _) {},
        cancelled: () => true,
      ),
      throwsA(isA<DownloadCancelled>()),
    );
    expect(
      Directory(p.join(destination, entry.path, 'chapters'))
          .listSync(),
      isEmpty,
    );
  });

  test('senza rete le tavole in cache si vedono, le altre avvisano e poi '
      'arrivano da sole', () async {
    final network = monitor() as Switchable;
    client = FakeClient(network: network)
      ..items.addAll(client.items)
      ..add('P2', '0002.webp', 'C1', content: 'seconda');
    final drive = repository();
    await drive.loadLibrary();
    final files = DriveFiles(drive);
    const first = 'drive:Prova [mangak-S1]/chapters/0001 - Primo [C1]/0001.webp';
    const second = 'drive:Prova [mangak-S1]/chapters/0001 - Primo [C1]/0002.webp';
    final cached = await files.fetch(first);

    await network.goOffline();
    expect(await files.fetch(first), cached);
    await expectLater(files.fetch(second), throwsA(isA<DriveOffline>()));
    files.warm([first, second]);
    await pumpEventQueue();
    expect(client.calls.where((call) => call == 'download:P2'), isEmpty);

    await network.goOnline();
    for (var i = 0; i < 50 && files.peek(second) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(files.peek(second)!).readAsString(), 'seconda');
    files.dispose();
    network.dispose();
  });

  test('il precarico segue l\'ordine chiesto, e la tavola guardata passa avanti',
      () async {
    for (var i = 2; i <= 9; i++) {
      client.add('P$i', '000$i.webp', 'C1', content: 'tavola $i');
    }
    final drive = repository();
    await drive.loadLibrary();
    final files = DriveFiles(drive);
    String page(int i) =>
        'drive:Prova [mangak-S1]/chapters/0001 - Primo [C1]/000$i.webp';
    // Si riprende dalla sesta: prima quelle dopo, poi quelle prima.
    files.warm([for (final i in [6, 7, 8, 9, 5, 4, 3, 2, 1]) page(i)]);
    await files.fetch(page(3), urgent: true);
    for (var i = 0; i < 100 && files.peek(page(2)) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final order = [
      for (final call in client.calls)
        if (call.startsWith('download:')) call.substring('download:P'.length),
    ];
    // Senza una velocità misurata i precarichi corrono in due, quindi la
    // sesta e la settima partono insieme: quale delle due arrivi prima al
    // client dipende dal disco, non dall'ordine.
    expect(order.first, isIn(['6', '7', '3']));
    expect(order.indexOf('3'), lessThan(order.indexOf('5')));
    expect(order.indexOf('6'), lessThan(order.indexOf('9')));
    expect(order.indexOf('9'), lessThan(order.indexOf('1')));
    files.dispose();
  });

  test('i capitoli finiti scadono, di quelli a metà resta da dove si riprende',
      () {
    final now = DateTime.utc(2026, 9, 24);
    CachedChapter chapter(String id, int pages, int daysAgo) => CachedChapter(
          series: 'S',
          chapter: id,
          keys: [for (var i = 0; i < pages; i++) '$id$i'],
          openedAt: now.subtract(Duration(days: daysAgo)),
        );
    final plan = planCache(
      [
        chapter('a', 3, 4),
        chapter('b', 4, 4),
        chapter('c', 1, 4),
        chapter('d', 1, 20),
      ],
      (_, id) => (
        finished: id == 'a',
        resumePage: id == 'b' ? 2 : null,
      ),
      now,
    );

    expect(plan.ranks['a0'], CacheRank.spent);
    expect([for (var i = 0; i < 4; i++) plan.ranks['b$i']], [
      CacheRank.spent,
      CacheRank.spent,
      CacheRank.kept,
      CacheRank.kept,
    ]);
    expect(plan.ranks['c0'], CacheRank.ordinary);
    // Finiti e già passati dopo tre giorni, gli altri dopo due settimane; il
    // seguito del capitolo a metà mai.
    expect(plan.expired, {'a0', 'a1', 'a2', 'b0', 'b1', 'd0'});
  });

  test('quando manca spazio escono prima le tavole già lette', () async {
    for (var i = 2; i <= 5; i++) {
      client.add('P$i', '000$i.webp', 'C1', content: 'tavola $i');
    }
    final drive = repository();
    await drive.loadLibrary();
    final files = DriveFiles(drive);
    String page(int i) =>
        'drive:Prova [mangak-S1]/chapters/0001 - Primo [C1]/000$i.webp';
    final chapter = [for (var i = 1; i <= 4; i++) page(i)];
    for (final address in chapter) {
      await files.fetch(address);
    }
    await files.fetch('drive:Prova [mangak-S1]/cover.thumb.webp');
    files.rememberChapter('mangak:S1', 'C1', chapter);
    await files.sweep((_, _) => (finished: false, resumePage: 2));

    drive.files.limitBytes = 42;
    await files.fetch(page(5));

    expect(files.peek(page(1)), isNull);
    expect(files.peek(page(2)), isNull);
    for (final i in [3, 4, 5]) {
      expect(files.peek(page(i)), isNotNull, reason: 'tavola $i');
    }
    expect(files.peek('drive:Prova [mangak-S1]/cover.thumb.webp'), isNotNull);

    // Il capitolo si ricorda anche riaprendo l'app.
    await files.saved;
    files.dispose();
    final reopened = DriveFiles(drive);
    await reopened.sweep((_, _) => (finished: true, resumePage: null));
    final third = drive.cacheKeyOf(page(3).substring('drive:'.length));
    expect(drive.files.rank!(third), CacheRank.spent);
    reopened.dispose();
  });

  test('i capitoli letti escono dalla cache quando lo chiede l\'utente',
      () async {
    client
      ..add('C2', '0002 - Secondo [C2]', 'CH')
      ..add('Q1', '0001.webp', 'C2', content: 'seconda');
    final drive = repository();
    await drive.loadLibrary();
    final files = DriveFiles(drive);
    const first = 'drive:Prova [mangak-S1]/chapters/0001 - Primo [C1]/0001.webp';
    const second =
        'drive:Prova [mangak-S1]/chapters/0002 - Secondo [C2]/0001.webp';
    await files.fetch(first);
    await files.fetch(second);
    files
      ..rememberChapter('mangak:S1', 'C1', [first])
      ..rememberChapter('mangak:S1', 'C2', [second]);

    final cached = await files.cachedOf('mangak:S1', {'C1'});
    expect(cached.chapters, {'C1'});
    expect(cached.bytes, 'tavola'.length);
    expect((await files.cachedOf('altra', {'C1'})).chapters, isEmpty);

    await files.forgetChapters('mangak:S1', {'C1'});
    expect(files.peek(first), isNull);
    expect(files.peek(second), isNotNull);
    expect((await files.cachedOf('mangak:S1', {'C1', 'C2'})).chapters, {'C2'});
    await files.saved;
    files.dispose();
  });

  test('un capitolo tolto da Drive si segna, e torna se il server lo rimette',
      () async {
    final drive = repository();
    final library = await drive.loadLibrary();
    final entry = library.series.single;
    const path = 'chapters/0001 - Primo [C1]';
    await drive.resolve('Prova [mangak-S1]/$path/0001.webp');
    client.calls.clear();

    await drive.withdrawChapters(entry, [path], client);
    expect(client.calls, ['trash:C1']);
    expect(await drive.resolve('Prova [mangak-S1]/$path'), isNull);
    expect(await drive.withdrawnChapters(entry), {path});

    // Un'altra sessione: il segno sta su disco, la cartella non c'è.
    final again = repository();
    await again.loadLibrary();
    expect(await again.withdrawnChapters(entry), {path});

    // Il server la ricarica: al primo elenco nuovo il segno se ne va.
    client.add('C1', '0001 - Primo [C1]', 'CH');
    final later = repository();
    await later.loadLibrary();
    expect(await later.withdrawnChapters(entry), isEmpty);
  });
}
