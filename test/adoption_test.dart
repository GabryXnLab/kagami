/// Le copie scaricate sul telefono seguono la serie adottata da Drive.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/adoption.dart';
import 'package:kagami/src/data/library_repository.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami_archive/indexes.dart';
import 'package:kagami_archive/stores.dart';
import 'package:path/path.dart' as p;

const oldFolder = 'Casa [coffeemanga-7743]';
const newFolder = 'Casa [coffeemanga-casa]';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('kagami-adoption'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, Object data) => File(p.join(root.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(data is String ? data : jsonEncode(data));

  Map<String, Object?> freshManifest() => {
        'schemaVersion': 3,
        'provider': 'coffeemanga',
        'id': 'casa',
        'formerKeys': ['coffeemanga:7743'],
        'title': 'Casa',
        'source': 'https://x/casa',
        'metadata': <String, Object?>{},
        'chapters': [
          {'id': 'chapter-1', 'number': '1', 'title': 'Chapter 1', 'source': 'https://x/c1', 'metadata': <String, Object?>{}, 'formerIds': ['217607']},
        ],
      };

  test('i capitoli scaricati risultano scaricati sotto la chiave nuova', () async {
    final chapter = {'schemaVersion': 3, 'id': '217607', 'number': '1', 'title': 'Chapter 1', 'source': 'https://x/old', 'complete': true,
      'pages': [{'file': '0001.webp', 'size': 1}]};
    write('$oldFolder/chapters/0001 - Chapter 1 [217607]/chapter.json', chapter);
    write('$oldFolder/chapters/0001 - Chapter 1 [217607]/0001.webp', 'x');
    final old = {
      'provider': 'coffeemanga', 'id': '7743', 'title': 'Casa', 'source': 'https://x/old', 'metadata': <String, Object?>{},
      'chapters': [{'id': '217607', 'number': '1', 'title': 'Chapter 1', 'source': 'https://x/old'}],
    };
    write('$oldFolder/series.json', old);
    final built = buildSeriesIndex(old, {'217607': ArchivedChapter.fromManifest('chapters/0001 - Chapter 1 [217607]', chapter)})!;
    write('$oldFolder/index.json', built.index);
    write('$oldFolder/pages.json', built.pages);
    write('reading/downloads.json', {'format': 'malf', 'formatVersion': 1, 'series': [summarize(oldFolder, old, built.index)]});

    final phone = LibraryRepository(root.path);
    final fresh = SeriesEntry.fromJson({'key': 'coffeemanga:casa', 'formerKeys': ['coffeemanga:7743']});
    Future<int> run() => adoptDownloadedCopies(
          series: [fresh],
          phone: phone,
          storeOf: () => LocalStore(root.path),
          fresh: (_) async => freshManifest(),
        );
    expect(await run(), 1);

    final rows = (await phone.downloadedSeries());
    expect([for (final row in rows) (row.key, row.path)], [('coffeemanga:casa', newFolder)]);
    final entry = rows.single;
    final index = (await phone.loadSeries(entry))!;
    expect([for (final c in index.chapters) (c.id, c.isReadable)], [('chapter-1', true)]);
    expect(await phone.presentChapters(entry), {index.chapters.single.path});

    // Il secondo giro non trova più copie con la chiave vecchia.
    expect(await run(), 0);
    // Senza il series.json di Drive la copia non si tocca.
    expect(
      await adoptDownloadedCopies(series: [fresh], phone: phone, storeOf: () => LocalStore(root.path), fresh: (_) async => null),
      0,
    );
  });

  test('senza il series.json di Drive la copia resta com\'è', () async {
    write('reading/downloads.json', {'format': 'malf', 'formatVersion': 1, 'series': [{'key': 'coffeemanga:7743', 'path': oldFolder}]});
    final fresh = SeriesEntry.fromJson({'key': 'coffeemanga:casa', 'formerKeys': ['coffeemanga:7743']});
    final phone = LibraryRepository(root.path);
    final count = await adoptDownloadedCopies(
        series: [fresh], phone: phone, storeOf: () => LocalStore(root.path), fresh: (_) async => null);
    expect(count, 0);
    expect((await phone.downloadedSeries()).single.key, 'coffeemanga:7743');
  });
}
