/// Le sorgenti messe insieme da `libraryProvider`: le tre di sempre come
/// prima, le altre da `library.sources`, e ciò che non si sa accendere è un
/// avviso e mai una sorgente vuota.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/data/library_repository.dart';
import 'package:kagami/src/data/series_removal.dart';
import 'package:kagami/src/data/sources/shelf_source.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_sources.dart';

import 'library_merge_sources_test.dart' show FakeRemote;
import 'sources_test.dart' show webdav;

void main() {
  late KagamiDatabase db;
  late Directory temp;
  late ProviderContainer container;

  ProviderContainer build({Map<SourceKind, SourceBuilder> builders = const {}}) =>
      ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        appDirectoriesProvider.overrideWithValue(
          AppDirectories(support: '${temp.path}/support', cache: '${temp.path}/cache'),
        ),
        sourceBuildersProvider.overrideWithValue(builders),
      ]);

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('kagami-wiring');
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<void> save(String value) => container
      .read(userRepositoryProvider)
      .writeSetting(LibrarySources.settingKey, value);

  Future<Library?> loaded() async {
    await container.read(librarySourcesProvider.future);
    return container.read(libraryProvider);
  }

  List<String> ids(Library library) =>
      [for (final shelf in library.shelves) shelf.sourceId];

  test('con le tre di sempre gli scaffali sono quelli di prima, nello stesso ordine', () async {
    container = build();
    expect(container.read(libraryProvider), isNull);
    container.read(libraryRootProvider.notifier).select('${temp.path}/manga');
    final library = (await loaded())!;
    expect(ids(library), [SourceConfig.folderId, SourceConfig.privateId]);
    expect(library.shelves.every((shelf) => shelf is LibraryRepository), isTrue);
    expect((library.shelves[0] as LibraryRepository).private, isFalse);
    expect((library.shelves[1] as LibraryRepository).private, isTrue);
    expect(library.notices, isEmpty);
    // Senza sorgenti in più la libreria non si ricompone all'arrivo della lista.
    expect(identical(container.read(libraryProvider), library), isTrue);
  });

  test('una configurazione di un tipo senza costruttore dà un avviso e nessuno scaffale', () async {
    container = build();
    await save(SourceList([webdav('s-0000000a')]).encode());
    container.read(libraryRootProvider.notifier).select('${temp.path}/manga');
    final library = (await loaded())!;
    expect(ids(library), [SourceConfig.folderId, SourceConfig.privateId]);
    final notice = library.notices.single as SourceUnavailable;
    expect(notice.sourceId, 's-0000000a');
    expect(notice.state, SourceState.missing);
  });

  test('gli avvisi di configurazione arrivano al catalogo, serie comprese', () async {
    const notice = SourceUnavailable('s-0000000a', SourceState.missing);
    final catalog = await Library([FakeRemote('s-0000000b')], notices: [notice]).load();
    expect(catalog.notices, [notice]);
  });

  test('una configurazione scaduta è un avviso, anche se il tipo si sa costruire', () async {
    var built = 0;
    container = build(builders: {
      SourceKind.webdav: (ref, config) {
        built++;
        return ShelfSource(config: config, shelf: FakeRemote(config.id));
      },
    });
    await save(SourceList([
      webdav('s-0000000a', expiresAt: DateTime.utc(2020)),
    ]).encode());
    container.read(libraryRootProvider.notifier).select('${temp.path}/manga');
    final library = (await loaded())!;
    expect(built, 0);
    expect((library.notices.single as SourceUnavailable).state, SourceState.expired);
  });

  test('le sorgenti costruite seguono le tre di sempre, per order, e attaccano i loro file', () async {
    container = build(builders: {
      SourceKind.webdav: (ref, config) =>
          ShelfSource(config: config, shelf: FakeRemote(config.id)),
    });
    await save(SourceList([
      webdav('s-0000000b', order: 1),
      webdav('s-0000000a', order: 0),
    ]).encode());
    container.read(libraryRootProvider.notifier).select('${temp.path}/manga');
    final library = (await loaded())!;
    expect(ids(library), [
      SourceConfig.folderId,
      SourceConfig.privateId,
      's-0000000a',
      's-0000000b',
    ]);
    expect(library.notices, isEmpty);
  });

  test('una lista illeggibile non toglie le tre di sempre e non si riscrive', () async {
    container = build();
    await save('{rotto');
    container.read(libraryRootProvider.notifier).select('${temp.path}/manga');
    final library = (await loaded())!;
    expect(ids(library), [SourceConfig.folderId, SourceConfig.privateId]);
    final notice = library.notices.single as SourceUnavailable;
    expect(notice.sourceId, unreadableSourcesId);
    expect(
      await container.read(userRepositoryProvider).readSetting(LibrarySources.settingKey),
      '{rotto',
    );
  });

  test('una serie che ha solo una sorgente senza diritto di cancellare non si propone', () {
    final remote = FakeRemote('s-0000000a');
    final folder = LibraryRepository('${Directory.systemTemp.path}/x');
    expect(canRemoveSeries([remote], driveOwned: true), isFalse);
    expect(canRemoveSeries([remote, folder], driveOwned: true), isTrue);
    expect(canRemoveSeries(const [], driveOwned: true), isTrue);
  });
}
