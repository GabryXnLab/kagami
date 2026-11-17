import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/library_repository.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/format/malf.dart';

import 'library_merge_test.dart' show FakeDrive, chapter, chapters, entry, index;

/// Una sorgente remota che non è il Drive dell'account, senza rete.
class FakeRemote implements LibraryShelf {
  FakeRemote(this.sourceId, {this.library = LibraryIndex.empty, this.failure});

  @override
  final String sourceId;

  final LibraryIndex library;

  /// Se c'è, è ciò che [loadLibrary] lancia al posto dell'indice.
  final Object? failure;

  @override
  LibraryOrigin get origin => LibraryOrigin.remote;

  @override
  Future<LibraryIndex> loadLibrary() async {
    if (failure != null) throw failure!;
    return library;
  }

  @override
  Future<SeriesIndex?> loadSeries(SeriesEntry entry) async => null;

  @override
  Future<PagesIndex?> loadPages(SeriesEntry entry) async => null;

  @override
  Future<Map<String, Object?>?> loadSeriesManifest(SeriesEntry entry) async =>
      null;

  @override
  String locate(SeriesEntry entry, String relative) =>
      sourceAddress(sourceId, '${entry.path}/$relative');

  @override
  Future<Set<String>> withdrawnChapters(SeriesEntry entry) async => const {};
}

SeriesEntry titled(String key, String title, {int archived = 1}) =>
    SeriesEntry.fromJson({
      ...entry(key, archived: archived).toJson(),
      'title': title,
    });

void main() {
  test('due remote con la stessa serie: vince la prima, la seconda aggiunge',
      () {
    final first = FakeRemote('s-aaaaaaaa');
    final second = FakeRemote('s-bbbbbbbb');
    final catalog = Library.merge({
      first: index([titled('mangak:S1', 'Prima', archived: 1)]),
      second: index([
        titled('mangak:S1', 'Seconda', archived: 2),
        entry('solo:seconda'),
      ]),
    });
    final row =
        catalog.index.series.firstWhere((row) => row.key == 'mangak:S1');
    expect(row.title, 'Prima');
    expect(catalog.holders['mangak:S1'], [first, second]);
    expect(catalog.holders['solo:seconda'], [second]);
    expect(catalog.places, {
      'mangak:S1': SeriesPlace.drive,
      'solo:seconda': SeriesPlace.drive,
    });

    final merged = Library.mergeChapters({
      first: chapters([chapter('C1', 0)]),
      second: chapters([chapter('C1', 0), chapter('C2', 1)]),
    })!;
    expect(merged.index.chapters.map((c) => c.id), ['C1', 'C2']);
    expect(merged.sourceOf('C1'), 's-aaaaaaaa');
    expect(merged.sourceOf('C2'), 's-bbbbbbbb');
    expect(merged.originOf('C2'), LibraryOrigin.remote);
    final pages = PagesIndex(key: 'k', signature: 's', pages: {
      'C1': const [PageEntry(file: '0001.webp')],
      'C2': const [PageEntry(file: '0001.webp')],
    });
    final library = Library([first, second]);
    final series = entry('mangak:S1');
    expect(
      library.pagePaths(series, merged.index.chapters[0], pages, merged).single,
      'remote:s-aaaaaaaa/Prova [mangak-S1]/chapters/1 [C1]/0001.webp',
    );
    expect(
      library.pagePaths(series, merged.index.chapters[1], pages, merged).single,
      'remote:s-bbbbbbbb/Prova [mangak-S1]/chapters/2 [C2]/0001.webp',
    );
  });

  test('il Drive dell\'account sta davanti alle altre remote', () {
    final drive = FakeDrive();
    final other = FakeRemote('s-aaaaaaaa');
    final catalog = Library.merge({
      drive: index([titled('mangak:S1', 'Drive')]),
      other: index([titled('mangak:S1', 'Altra', archived: 3)]),
    });
    expect(catalog.index.series.single.title, 'Drive');
    final merged = Library.mergeChapters({
      drive: chapters([chapter('C1', 0)]),
      other: SeriesIndex(
        key: 'mangak:S1',
        title: 'Altra',
        releaseStatus: ReleaseStatus.completed,
        signature: 'altra',
        chapters: [chapter('C1', 0), chapter('C2', 1)],
      ),
    })!;
    expect(merged.index.title, 'Prova');
    expect(merged.sourceOf('C1'), SourceConfig.driveId);
    expect(merged.sourceOf('C2'), 's-aaaaaaaa');
  });

  test('una remota scaduta lascia l\'avviso e le serie dell\'altra', () async {
    final live = FakeRemote('s-aaaaaaaa',
        library: index([entry('mangak:S1')]));
    final expired = FakeRemote('s-bbbbbbbb',
        failure: const SourceUnavailable('s-bbbbbbbb', SourceState.expired));
    final catalog = await Library([live, expired]).load();
    expect(catalog.index.series.map((row) => row.key), ['mangak:S1']);
    final notice = catalog.notices.single as SourceUnavailable;
    expect(notice.sourceId, 's-bbbbbbbb');
    expect(notice.state, SourceState.expired);
  });

  test('senza nessuna serie altrove, una remota irraggiungibile è un errore',
      () async {
    final offline = FakeRemote('s-aaaaaaaa',
        failure: const SourceUnavailable('s-aaaaaaaa', SourceState.offline));
    final empty = FakeRemote('s-bbbbbbbb');
    await expectLater(
      Library([empty, offline]).load(),
      throwsA(isA<SourceUnavailable>()
          .having((e) => e.state, 'state', SourceState.offline)),
    );
  });

  test('una remota vince su una locale, in qualunque ordine arrivino', () {
    final local = LibraryRepository('/nessuna');
    final remote = FakeRemote('s-aaaaaaaa');
    final catalog = Library.merge({
      remote: index([titled('mangak:S1', 'Remota', archived: 3)]),
      local: index([titled('mangak:S1', 'Telefono', archived: 1)]),
    });
    expect(catalog.index.series.single.title, 'Remota');
    expect(catalog.places['mangak:S1'], SeriesPlace.mixed);
  });

  test('con la cartella e il Drive di sempre il catalogo è quello di prima',
      () {
    final local = LibraryRepository('/nessuna');
    final drive = FakeDrive();
    final fromDrive = titled('mangak:S1', 'Drive', archived: 3);
    final notice = Exception('cartella privata');
    final catalog = Library.merge({
      local: index([titled('mangak:S1', 'Telefono'), entry('solo:telefono')]),
      drive: index([fromDrive, entry('solo:drive')]),
    }, [notice]);
    expect(local.sourceId, SourceConfig.folderId);
    expect(LibraryRepository('/x', private: true).sourceId,
        SourceConfig.privateId);
    expect(drive.sourceId, SourceConfig.driveId);
    expect(
      identical(
        catalog.index.series.firstWhere((row) => row.key == 'mangak:S1'),
        fromDrive,
      ),
      isTrue,
    );
    expect(catalog.index.series.map((row) => row.key),
        ['mangak:S1', 'solo:telefono', 'solo:drive']);
    expect(catalog.places, {
      'mangak:S1': SeriesPlace.mixed,
      'solo:telefono': SeriesPlace.local,
      'solo:drive': SeriesPlace.drive,
    });
    expect(catalog.holders['mangak:S1'], [local, drive]);
    expect(catalog.notices, [notice]);
  });
}
