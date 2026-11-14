import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/sources/path_shelf.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami_archive/transport.dart';

/// Un trasporto in memoria: file per percorso, con etag; [failure] fa
/// fallire ogni richiesta, [cutAfter] tronca il prossimo download lì.
class FakeTransport implements StorageTransport {
  final Map<String, (String, String?)> files = {};
  final Set<String> folders = {''};
  TransportException? failure;
  int? cutAfter;
  final List<String> texts = [];
  final List<(String, int)> downloads = [];

  void put(String path, String content, {String? etag}) {
    files[path] = (content, etag);
    final parts = path.split('/');
    for (var i = 1; i < parts.length; i++) {
      folders.add(parts.take(i).join('/'));
    }
  }

  void _check() {
    if (failure != null) throw failure!;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async => throw UnimplementedError();

  @override
  Future<RemoteEntry?> stat(String path) async {
    _check();
    if (folders.contains(path)) {
      return RemoteEntry(path: path, name: path.split('/').last, folder: true);
    }
    final file = files[path];
    if (file == null) return null;
    return RemoteEntry(
      path: path,
      name: path.split('/').last,
      folder: false,
      size: file.$1.length,
      etag: file.$2,
    );
  }

  @override
  Future<String> text(String path) async {
    _check();
    texts.add(path);
    final file = files[path];
    if (file == null) throw const TransportNotFound();
    return file.$1;
  }

  @override
  Future<void> download(String path, File target, {int resumeFrom = 0}) async {
    _check();
    downloads.add((path, resumeFrom));
    final file = files[path];
    if (file == null) throw const TransportNotFound();
    final bytes = utf8.encode(file.$1);
    final cut = cutAfter;
    cutAfter = null;
    final end = cut ?? bytes.length;
    await target.writeAsBytes(bytes.sublist(resumeFrom, end),
        mode: resumeFrom > 0 ? FileMode.append : FileMode.write);
    if (cut != null) throw const TransportOffline();
  }

  @override
  void close() {}
}

String library(List<String> titles) => jsonEncode({
      'format': 'malf',
      'series': [
        for (final title in titles)
          {'key': 'site:$title', 'path': '$title [site-$title]', 'title': title},
      ],
    });

void main() {
  late Directory temp;
  late FakeTransport transport;
  late DateTime now;

  PathShelf shelf({String root = 'manga'}) => PathShelf(
        transport: transport,
        sourceId: 's-0a0b0c0d',
        stateDirectory: '${temp.path}/sources/s-0a0b0c0d',
        root: root,
        now: () => now,
      );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kagami-path-shelf');
    transport = FakeTransport()
      ..put('manga/library.json', library(['Prova']), etag: '"v1"')
      ..put('manga/Prova [site-Prova]/index.json', jsonEncode({
        'key': 'site:Prova',
        'chapters': [
          {'id': 'C1', 'order': 0, 'complete': true, 'archived': true,
           'pageCount': 1, 'path': 'chapters/0001 - Primo [C1]'},
        ],
      }))
      ..put('manga/Prova [site-Prova]/pages.json', jsonEncode({
        'pages': {
          'C1': [{'file': '0001.webp'}],
        },
      }))
      ..put('manga/Prova [site-Prova]/series.json', jsonEncode({
        'metadata': {'title': 'Prova'},
      }))
      ..put('manga/Prova [site-Prova]/chapters/0001 - Primo [C1]/0001.webp',
          'tavola-di-prova');
    now = DateTime.utc(2026, 11, 14, 12);
  });

  tearDown(() => temp.delete(recursive: true));

  test('legge library.json e lo tiene per etag', () async {
    final first = shelf();
    expect((await first.loadLibrary()).series.single.title, 'Prova');
    expect(transport.texts, ['manga/library.json']);

    // Stesso etag: dopo la scadenza si chiede solo lo stato, non il testo.
    now = now.add(const Duration(minutes: 11));
    await first.loadLibrary();
    expect(transport.texts, ['manga/library.json']);

    // Etag nuovo: il testo si rilegge.
    transport.put('manga/library.json', library(['Prova', 'Altra']), etag: '"v2"');
    now = now.add(const Duration(minutes: 11));
    expect((await first.loadLibrary()).series, hasLength(2));
    expect(transport.texts, ['manga/library.json', 'manga/library.json']);

    // La versione vecchia del testo non resta su disco.
    await first.pruned;
    final texts = Directory('${temp.path}/sources/s-0a0b0c0d/text').listSync();
    expect(texts, hasLength(1));
  });

  test('senza rete si apre l\'istantanea dell\'ultima volta', () async {
    await shelf().loadLibrary();
    transport.failure = const TransportOffline();
    final again = shelf();
    expect((await again.loadLibrary()).series.single.title, 'Prova');
    expect(again.fromSnapshot, isTrue);
  });

  test('senza rete né istantanea: offline, mai vuota', () async {
    transport.failure = const TransportOffline();
    await expectLater(
      shelf().loadLibrary(),
      throwsA(isA<SourceUnavailable>()
          .having((e) => e.state, 'state', SourceState.offline)
          .having((e) => e.sourceId, 'sourceId', 's-0a0b0c0d')),
    );
  });

  test('credenziali rifiutate: needsAuth anche con un\'istantanea', () async {
    await shelf().loadLibrary();
    transport.failure = const TransportAuthRequired(status: 401);
    await expectLater(
      shelf().loadLibrary(),
      throwsA(isA<SourceUnavailable>()
          .having((e) => e.state, 'state', SourceState.needsAuth)),
    );
  });

  test('cartella senza library.json è vuota, cartella sparita no', () async {
    transport.files.remove('manga/library.json');
    expect((await shelf().loadLibrary()).series, isEmpty);
    await expectLater(
      shelf(root: 'altrove').loadLibrary(),
      throwsA(isA<SourceUnavailable>()
          .having((e) => e.state, 'state', SourceState.missing)),
    );
  });

  test('indici della serie: chiesti all\'apertura, copia se la rete manca', () async {
    final books = shelf();
    final entry = (await books.loadLibrary()).series.single;
    expect((await books.loadSeries(entry))!.chapters.single.id, 'C1');
    expect((await books.loadPages(entry))!.pages['C1']!.single.file, '0001.webp');
    expect(await books.loadSeriesManifest(entry), {'title': 'Prova'});

    transport.failure = const TransportOffline();
    expect((await books.loadSeries(entry))!.chapters.single.id, 'C1');
    transport.failure = null;

    transport.files.remove('manga/Prova [site-Prova]/index.json');
    expect(await books.loadSeries(entry), isNull);
    // Tolta dalla sorgente, la copia non risponde più per lei.
    transport.failure = const TransportOffline();
    await expectLater(books.loadSeries(entry), throwsA(isA<TransportOffline>()));
  });

  test('indirizzi remote:<id>/ e niente capitoli tolti', () async {
    final books = shelf();
    final entry = (await books.loadLibrary()).series.single;
    expect(books.locate(entry, 'cover.webp'),
        'remote:s-0a0b0c0d/Prova [site-Prova]/cover.webp');
    expect(await books.withdrawnChapters(entry), isEmpty);
  });

  group('PathFiles', () {
    late PathShelf books;
    late DriveFileCache cache;
    late PathFiles files;
    const page = 'remote:s-0a0b0c0d/Prova [site-Prova]/chapters/0001 - Primo [C1]/0001.webp';

    setUp(() async {
      books = shelf();
      cache = DriveFileCache(Directory('${temp.path}/cache'), limitBytes: 1 << 20);
      files = PathFiles(books, cache, atOnce: 1);
    });

    test('scarica nella cache con una chiave della sorgente', () async {
      expect(files.peek(page), isNull);
      final path = await files.fetch(page, urgent: true);
      expect(await File(path).readAsString(), 'tavola-di-prova');
      expect(files.peek(page), path);
      expect(files.keyOf(page), startsWith('s-0a0b0c0d-'));
      // Già in cache: nessun download in più.
      await files.fetch(page);
      expect(transport.downloads, hasLength(1));
    });

    test('un download interrotto riprende da dove era arrivato', () async {
      transport.cutAfter = 6;
      await expectLater(files.fetch(page), throwsA(isA<TransportOffline>()));
      final path = await files.fetch(page);
      expect(await File(path).readAsString(), 'tavola-di-prova');
      expect(transport.downloads.map((d) => d.$2), [0, 6]);
    });

    test('le urgenti passano davanti ai precarichi', () async {
      const other = 'remote:s-0a0b0c0d/Prova [site-Prova]/cover.webp';
      const third = 'remote:s-0a0b0c0d/Prova [site-Prova]/cover.thumb.webp';
      transport
        ..put('manga/Prova [site-Prova]/cover.webp', 'copertina')
        ..put('manga/Prova [site-Prova]/cover.thumb.webp', 'miniatura');
      files.warm([page, other]);
      final urgent = files.fetch(third, urgent: true);
      await urgent;
      // Il primo precarico era già partito; la urgente arriva prima del
      // secondo.
      expect(transport.downloads.map((d) => d.$1.split('/').last).take(2),
          ['0001.webp', 'cover.thumb.webp']);
    });

    test('un indirizzo di un\'altra sorgente è un errore di chi chiama', () {
      expect(() => files.peek('remote:s-ffffffff/x.webp'), throwsArgumentError);
    });
  });
}
