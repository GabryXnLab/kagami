/// «Scarica» da una sorgente per percorsi: stesso albero MALF, stessi `.part`,
/// stesso `reading/downloads.json` del Drive.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/download_origin.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/data/downloads.dart';
import 'package:kagami/src/data/library_repository.dart';
import 'package:kagami/src/data/sources/path_shelf.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_sources.dart';
import 'package:kagami_archive/transport.dart';
import 'package:path/path.dart' as p;

import 'path_shelf_test.dart' show FakeTransport, library;
import 'sources_test.dart' show webdav;

void main() {
  late Directory temp;
  late FakeTransport transport;
  late PathShelf shelf;
  late SeriesEntry entry;
  late ChapterEntry chapter;
  late String destination;

  const seriesPath = 'Prova [site-Prova]';
  const chapterPath = 'chapters/0001 - Primo [C1]';

  PathOrigin origin() => PathOrigin(
        shelf,
        PathFiles(
          shelf,
          DriveFileCache(Directory('${temp.path}/cache'), limitBytes: 1 << 20),
        ),
        online: () async => false,
      );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kagami-source-download');
    destination = p.join(temp.path, 'manga');
    transport = FakeTransport()
      ..put('manga/library.json', library(['Prova']), etag: '"v1"')
      ..put('manga/$seriesPath/index.json', jsonEncode({
        'key': 'site:Prova',
        'chapters': [
          {'id': 'C1', 'order': 0, 'complete': true, 'archived': true,
           'pageCount': 1, 'path': chapterPath},
        ],
      }))
      ..put('manga/$seriesPath/pages.json', jsonEncode({
        'pages': {'C1': [{'file': '0001.webp'}]},
      }))
      ..put('manga/$seriesPath/series.json', jsonEncode({'metadata': {'title': 'Prova'}}))
      ..put('manga/$seriesPath/$chapterPath/0001.webp', 'tavola-di-prova');
    shelf = PathShelf(
      transport: transport,
      sourceId: 's-0a0b0c0d',
      stateDirectory: '${temp.path}/state',
      root: 'manga',
    );
    entry = (await shelf.loadLibrary()).series.single;
    chapter = (await shelf.loadSeries(entry))!.chapters.single;
  });

  tearDown(() => temp.delete(recursive: true));

  Future<void> download(ChapterDownloader downloader) => downloader.download(
        destination: destination,
        entry: entry,
        chapter: chapter,
        pages: const [PageEntry(file: '0001.webp')],
        onPage: (_, _) {},
        cancelled: () => false,
      );

  test('un capitolo di una sorgente diventa un capitolo della cartella', () async {
    final downloader = ChapterDownloader(origin());
    await download(downloader);
    await downloader.finishSeries(destination: destination, entry: entry);

    final page = File(p.join(destination, entry.path, chapterPath, '0001.webp'));
    expect(await page.readAsString(), 'tavola-di-prova');
    expect(
      Directory(p.join(destination, entry.path, 'chapters'))
          .listSync()
          .map((e) => p.basename(e.path)),
      ['0001 - Primo [C1]'],
    );
    final local = LibraryRepository(destination, requireIndex: false);
    expect((await local.loadSeries(entry))!.readable.single.id, 'C1');
    final remembered = jsonDecode(
      await File(p.join(destination, readingDirectory, downloadsFile)).readAsString(),
    ) as Map<String, Object?>;
    final row = (remembered['series']! as List).single as Map<String, Object?>;
    expect(row['key'], 'site:Prova');
    expect(row['archivedChapterCount'], 1);
  });

  test('senza rete si ferma con TransportOffline e riprende dal byte dove era', () async {
    transport.cutAfter = 5;
    await expectLater(
      download(ChapterDownloader(origin())),
      throwsA(isA<TransportOffline>()),
    );
    // Il capitolo non c'è ancora: c'è solo il suo `.part`, con la tavola a metà.
    expect(Directory(p.join(destination, entry.path, chapterPath)).existsSync(), isFalse);
    final partial = File(
      p.join(destination, entry.path, '$chapterPath$partialSuffix', '0001.webp.tmp'),
    );
    expect(await partial.length(), 5);

    await download(ChapterDownloader(origin()));
    expect(transport.downloads.last.$2, 5);
    expect(
      await File(p.join(destination, entry.path, chapterPath, '0001.webp')).readAsString(),
      'tavola-di-prova',
    );
  });

  test('una tavola che la sorgente non ha è un errore, non un capitolo bucato', () async {
    transport.files.remove('manga/$seriesPath/$chapterPath/0001.webp');
    await expectLater(
      download(ChapterDownloader(origin())),
      throwsA(isA<TransportNotFound>()),
    );
    expect(Directory(p.join(destination, entry.path, chapterPath)).existsSync(), isFalse);
  });

  test('da dove si scarica lo dice la sorgente: WebDAV sì, ciò che non c\'è no', () async {
    final db = KagamiDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appDirectoriesProvider.overrideWithValue(
        AppDirectories(support: '${temp.path}/support', cache: '${temp.path}/cache2'),
      ),
      sourceBuildersProvider.overrideWithValue(const {SourceKind.webdav: buildWebDav}),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await container
        .read(userRepositoryProvider)
        .writeSetting(LibrarySources.settingKey, SourceList([webdav('s-00000001')]).encode());
    await container.read(librarySourcesProvider.future);

    expect(container.read(downloadOriginProvider('s-00000001')), isA<PathOrigin>());
    expect(container.read(downloadOriginProvider('s-ffffffff')), isNull);
  });
}
