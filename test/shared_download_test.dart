/// Scaricare da una libreria condivisa (FASE-5b §4): solo se la riga lo
/// permette, sempre nello scaffale privato della sorgente e mai nella cartella
/// dell'utente, e le copie seguono il permesso.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/download_origin.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/data/share_directory.dart';
import 'package:kagami/src/data/shared_copies.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_shares.dart';
import 'package:kagami/src/providers_sources.dart';
import 'package:path/path.dart' as p;

import 'drive_library_test.dart' show FakeClient;

const _me = 'me@example.com';
const _id = 's-0000abcd';
const _seriesPath = 'Prova [mangak-S1]';
const _chapterPath = 'chapters/0001 - Primo [C1]';

DriveShare _row({bool download = true, DateTime? expiresAt}) => DriveShare(
      id: DriveShare.shareId('amica@example.com', _me, 'R'),
      to: _me,
      from: 'amica@example.com',
      folderId: 'R',
      folderName: 'Manga di Amica',
      permissionId: 'perm',
      at: DateTime.utc(2026, 11, 1),
      expiresAt: expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 7)),
      download: download,
    );

SourceConfig _config({bool download = true, DateTime? expiresAt, String account = _me}) => SourceConfig(
      id: _id,
      kind: SourceKind.driveShared,
      label: 'Manga di Amica',
      params: {
        'folderId': 'R',
        'folderName': 'Manga di Amica',
        'owner': 'amica@example.com',
        'account': account,
        'download': download,
      },
      expiresAt: expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 7)),
    );

_Drive _drive() => _Drive()
  ..add('LIB', libraryIndexFile, 'R', content: '{"format":"malf","series":[{"key":"mangak:S1",'
      '"path":"$_seriesPath","title":"Prova","archivedChapterCount":1}]}')
  ..add('S', _seriesPath, 'R')
  ..add('IDX', seriesIndexFile, 'S', content: '{"key":"mangak:S1","chapters":[{"id":"C1","order":0,'
      '"complete":true,"archived":true,"pageCount":1,"path":"$_chapterPath"}]}')
  ..add('PG', pagesIndexFile, 'S', content: '{"pages":{"C1":[{"file":"0001.webp"}]}}')
  ..add('CH', 'chapters', 'S')
  ..add('C1', '0001 - Primo [C1]', 'CH')
  ..add('P1', '0001.webp', 'C1', content: 'tavola');

/// Drive che, a comando, risponde 403 come a un permesso ritirato.
class _Drive extends FakeClient {
  bool denied = false;

  @override
  Future<List<DriveItem>> children(String folderId) async {
    if (denied) throw const DriveException('Drive ha risposto 403', status: 403);
    return super.children(folderId);
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

/// Aspetta [done] (le cancellazioni sono asincrone e la suite gira in parallelo).
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await _settle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KagamiDatabase db;
  late Directory temp;
  late AppDirectories directories;
  late MemoryShareDirectory shares;
  late _Drive client;
  late ProviderContainer container;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('kagami-shared-download');
    directories = AppDirectories(support: '${temp.path}/support', cache: '${temp.path}/cache');
    shares = MemoryShareDirectory();
    client = _drive();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appDirectoriesProvider.overrideWithValue(directories),
      shareDirectoryProvider.overrideWithValue(shares),
      shareReceiverProvider.overrideWithValue(_me),
      sourceBuildersProvider.overrideWithValue({
        SourceKind.driveShared: (ref, config) => sharedDriveSource(ref, config, client),
      }),
    ]);
    container.read(libraryRootProvider.notifier).select('${temp.path}/manga');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<void> configure(SourceConfig config) async {
    await container
        .read(userRepositoryProvider)
        .writeSetting(LibrarySources.settingKey, SourceList([config]).encode());
    container.invalidate(librarySourcesProvider);
    await container.read(librarySourcesProvider.future);
  }

  String copies() => sharedCopiesDirectory(directories, _id);
  File page() => File(p.join(copies(), _seriesPath, _chapterPath, '0001.webp'));

  /// Una copia già scesa, con la sua istantanea e la cache delle tavole.
  void seed() {
    page()
      ..createSync(recursive: true)
      ..writeAsStringSync('tavola');
    File(p.join(copies(), readingDirectory, 'downloads.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"format":"malf","series":[{"key":"mangak:S1","path":"$_seriesPath",'
          '"title":"Prova","archivedChapterCount":1}]}');
    File(p.join(copies(), _seriesPath, seriesIndexFile)).writeAsStringSync(
        '{"key":"mangak:S1","chapters":[{"id":"C1","order":0,"complete":true,"archived":true,'
        '"pageCount":1,"path":"$_chapterPath"}]}');
    File(p.join(sharedStateDirectory(directories, _id), 'R', 'snapshot.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    File(p.join(sharedCacheDirectory(directories, _id), 'tavola'))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
  }

  bool copiesLeft() => Directory(copies()).existsSync();
  bool restLeft() =>
      Directory(sharedStateDirectory(directories, _id)).existsSync() ||
      Directory(sharedCacheDirectory(directories, _id)).existsSync();

  test('accettare porta il permesso nella sorgente, e la rilettura lo segue', () async {
    await shares.put(_row(download: false));
    container.listen(sharedLibraryWatcherProvider, (_, _) {});
    await container.read(librarySourcesProvider.future);
    await _settle();
    await container.read(librarySourcesProvider.notifier).accept(container.read(shareInvitesProvider).single);
    SourceConfig source() => container.read(librarySourcesProvider).value!.sources.single;
    expect(source().params['download'], isFalse);

    await shares.put(_row());
    shares.notifyChanged();
    await _settle();
    expect(source().params['download'], isTrue);
  });

  test('download falso: nessuna origine, nessuno «Scarica»', () async {
    await configure(_config(download: false));
    final shared = container.read(storageSourcesProvider).sources.singleWhere((s) => s.config.id == _id);
    expect(shared.capabilities.download, isFalse);
    expect(container.read(downloadOriginProvider(_id)), isNull);
  });

  test('download vero: i file finiscono nello scaffale privato, mai nella cartella dell\'utente', () async {
    await configure(_config());
    final shared = container.read(storageSourcesProvider).sources.singleWhere((s) => s.config.id == _id);
    expect(shared.capabilities.download, isTrue);
    final origin = container.read(downloadOriginProvider(_id));
    expect(origin, isA<DriveOrigin>());
    expect(origin!.destination, p.join(directories.support, 'drive-shared', _id, 'library'));

    container.listen(libraryCatalogProvider, (_, _) {});
    container.listen(seriesEntryProvider('mangak:S1'), (_, _) {});
    await container.read(libraryCatalogProvider.future);
    expect((await container.read(seriesChaptersProvider('mangak:S1').future))!.sourceOf('C1'), _id);
    // La cartella scelta è quella che l'interfaccia passa: il permesso la scavalca.
    container.read(downloadsProvider.notifier).enqueue('mangak:S1', ['C1'], '${temp.path}/manga');
    for (var i = 0; i < 40 && container.read(downloadsProvider).isNotEmpty; i++) {
      await _settle();
    }
    expect(container.read(downloadsProvider), isEmpty);
    final index = File(p.join(copies(), readingDirectory, 'downloads.json'));
    for (var i = 0; i < 40 && !index.existsSync(); i++) {
      await _settle();
    }
    await _settle();
    expect(index.existsSync(), isTrue);
    expect(page().readAsStringSync(), 'tavola');
    expect(Directory('${temp.path}/manga').existsSync(), isFalse);

    // Da qui il capitolo si legge dal telefono, anche quando Drive dice 403.
    await _settle();
    client.offline = true;
    container.invalidate(storageSourcesProvider);
    final chapters = await container.read(seriesChaptersProvider('mangak:S1').future);
    expect(chapters!.originOf('C1')!.isRemote, isFalse);
  });

  test('rilettura fallita e Drive che rifiuta: le copie restano e si leggono', () async {
    seed();
    await configure(_config());
    await shares.put(_row());
    container.listen(sharedLibraryWatcherProvider, (_, _) {});
    await _settle();
    shares.failure = StateError('rete');
    shares.notifyChanged();
    await _settle();
    client.denied = true;
    container.invalidate(storageSourcesProvider);
    container.listen(libraryCatalogProvider, (_, _) {});
    container.listen(seriesEntryProvider('mangak:S1'), (_, _) {});
    final catalog = await container.read(libraryCatalogProvider.future);
    expect(catalog.notices.whereType<SourceUnavailable>().map((notice) => notice.sourceId), [_id]);
    expect(catalog.index.series.map((entry) => entry.key), ['mangak:S1']);
    final chapters = await container.read(seriesChaptersProvider('mangak:S1').future);
    expect(chapters!.originOf('C1')!.isRemote, isFalse);
    await _settle();
    expect(page().existsSync(), isTrue);
    expect(restLeft(), isTrue);
  });

  group('le copie seguono il permesso', () {
    test('scadenza: via tutto, anche senza rete', () async {
      seed();
      await configure(_config(expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1))));
      container.read(storageSourcesProvider);
      await _until(() => !restLeft());
      expect(copiesLeft(), isFalse);
      expect(restLeft(), isFalse);
    });

    test('scadenza ad app aperta: la sorgente si spegne al termine da sola', () async {
      seed();
      await configure(_config(expiresAt: DateTime.now().toUtc().add(const Duration(milliseconds: 300))));
      container.listen(storageSourcesProvider, (_, _) {});
      expect(container.read(storageSourcesProvider).sources.any((s) => s.config.id == _id), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(container.read(storageSourcesProvider).sources.any((s) => s.config.id == _id), isFalse);
      await _until(() => !copiesLeft());
      expect(copiesLeft(), isFalse);
    });

    test('riga sparita a una rilettura riuscita: via tutto', () async {
      seed();
      await configure(_config());
      container.listen(sharedLibraryWatcherProvider, (_, _) {});
      container.listen(storageSourcesProvider, (_, _) {});
      shares.notifyChanged();
      await _until(() => !restLeft());
      expect(copiesLeft(), isFalse);
      expect(restLeft(), isFalse);
    });

    test('declassamento a solo streaming: via solo le copie', () async {
      seed();
      await configure(_config());
      await shares.put(_row(download: false));
      container.listen(sharedLibraryWatcherProvider, (_, _) {});
      container.listen(storageSourcesProvider, (_, _) {});
      shares.notifyChanged();
      await _until(() => !copiesLeft());
      expect(container.read(librarySourcesProvider).value!.sources.single.params['download'], isFalse);
      expect(copiesLeft(), isFalse);
      expect(restLeft(), isTrue);
      expect(container.read(downloadOriginProvider(_id)), isNull);
    });

    test('rimozione della sorgente: via tutto', () async {
      seed();
      await configure(_config());
      await container.read(librarySourcesProvider.notifier).remove(_id);
      expect(copiesLeft(), isFalse);
      expect(restLeft(), isFalse);
    });

    test('altro account: via tutto, la sorgente resta', () async {
      seed();
      await configure(_config(account: 'altro@example.com'));
      container.read(storageSourcesProvider);
      await _until(() => !restLeft());
      expect(copiesLeft(), isFalse);
      expect(restLeft(), isFalse);
      expect(container.read(librarySourcesProvider).value!.sources.single.id, _id);
    });
  });
}
