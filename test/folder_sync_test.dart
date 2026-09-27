/// La sincronizzazione della cartella: il piano senza disco né rete, poi un
/// giro vero fra una cartella temporanea e un Drive in memoria.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/cleanup.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/folder_sync.dart';
import 'package:path/path.dart' as p;

LocalFile here(int size, [int modified = 1000]) =>
    (size: size, modified: modified);
RemoteFile there(String key, int size, [int modified = 1000]) =>
    (key: key, size: size, modified: modified);

SyncPlan plan({
  Map<String, LocalFile> local = const {},
  Map<String, RemoteFile> remote = const {},
  Map<String, SyncRecord> state = const {},
  SyncDirection direction = SyncDirection.both,
  bool deletions = false,
}) =>
    planSync(
      local: local,
      remote: remote,
      state: state,
      direction: direction,
      deletions: deletions,
    );

Map<String, SyncActionKind> kinds(SyncPlan plan) =>
    {for (final action in plan.actions) action.path: action.kind};

void main() {
  group('il piano', () {
    test('al primo giro file della stessa misura si prendono per uguali', () {
      final result = plan(
        local: {'a/1.webp': here(10)},
        remote: {'a/1.webp': there('k', 10)},
      );
      expect(result.actions, isEmpty);
      expect(result.records['a/1.webp'], const SyncRecord(size: 10, modified: 1000, remote: 'k'));
    });

    test('ciò che c\'è da una parte sola si copia secondo la direzione', () {
      final local = {'solo-qui': here(1)};
      final remote = {'solo-li': there('k', 1)};
      expect(kinds(plan(local: local, remote: remote)), {
        'solo-qui': SyncActionKind.upload,
        'solo-li': SyncActionKind.download,
      });
      expect(
        kinds(plan(local: local, remote: remote, direction: SyncDirection.download)),
        {'solo-li': SyncActionKind.download},
      );
      expect(
        kinds(plan(local: local, remote: remote, direction: SyncDirection.upload)),
        {'solo-qui': SyncActionKind.upload},
      );
    });

    test('cambiato da una parte sola va dall\'altra', () {
      const record = SyncRecord(size: 5, modified: 1000, remote: 'v1');
      expect(
        kinds(plan(
          local: {'f': here(6, 2000)},
          remote: {'f': there('v1', 5)},
          state: {'f': record},
        )),
        {'f': SyncActionKind.upload},
      );
      expect(
        kinds(plan(
          local: {'f': here(5)},
          remote: {'f': there('v2', 7)},
          state: {'f': record},
        )),
        {'f': SyncActionKind.download},
      );
    });

    test('cambiato da tutt\'e due vince il più recente', () {
      const record = SyncRecord(size: 5, modified: 1000, remote: 'v1');
      expect(
        kinds(plan(
          local: {'f': here(6, 5000)},
          remote: {'f': there('v2', 7, 3000)},
          state: {'f': record},
        )),
        {'f': SyncActionKind.upload},
      );
      expect(
        kinds(plan(
          local: {'f': here(6, 2000)},
          remote: {'f': there('v2', 7, 3000)},
          state: {'f': record},
        )),
        {'f': SyncActionKind.download},
      );
    });

    test('gli indici del server non salgono mai', () {
      final result = plan(
        local: {'library.json': here(3), 'S/index.json': here(4)},
        direction: SyncDirection.both,
      );
      expect(result.actions, isEmpty);
      const record = SyncRecord(size: 5, modified: 1000, remote: 'v1');
      expect(
        kinds(plan(
          local: {'library.json': here(9, 9000)},
          remote: {'library.json': there('v2', 7, 3000)},
          state: {'library.json': record},
        )),
        {'library.json': SyncActionKind.download},
      );
    });

    test('senza cancellazioni un file tolto resta tolto, e non torna', () {
      const record = SyncRecord(size: 5, modified: 1000, remote: 'v1');
      final first = plan(remote: {'c/1.webp': there('v1', 5)}, state: {'c/1.webp': record});
      expect(first.actions, isEmpty);
      final tombstone = first.records['c/1.webp']!;
      expect(tombstone.hasLocal, isFalse);
      // Al giro dopo, lo stesso file su Drive non si riscarica…
      expect(
        plan(remote: {'c/1.webp': there('v1', 5)}, state: {'c/1.webp': tombstone}).actions,
        isEmpty,
      );
      // …a meno che non ne arrivi una versione nuova.
      expect(
        kinds(plan(remote: {'c/1.webp': there('v2', 6)}, state: {'c/1.webp': tombstone})),
        {'c/1.webp': SyncActionKind.download},
      );
    });

    test('con le cancellazioni si propagano, nella direzione giusta', () {
      const record = SyncRecord(size: 5, modified: 1000, remote: 'v1');
      expect(
        kinds(plan(
          remote: {'x': there('v1', 5)},
          state: {'x': record},
          deletions: true,
        )),
        {'x': SyncActionKind.trashRemote},
      );
      expect(
        kinds(plan(
          local: {'x': here(5)},
          state: {'x': record},
          deletions: true,
        )),
        {'x': SyncActionKind.deleteLocal},
      );
      // In sola discesa il telefono non cancella niente su Drive.
      expect(
        plan(
          remote: {'x': there('v1', 5)},
          state: {'x': record},
          deletions: true,
          direction: SyncDirection.download,
        ).actions,
        isEmpty,
      );
    });

    test('tolto dal telefono con «Libera spazio» non torna, neanche al primo giro', () {
      final remote = {'S/chapters/0001/0001.webp': there('k', 5)};
      final released = releaseRecords(
        local: const {},
        remote: remote,
        state: const {},
        releases: const [(path: 'S/chapters/0001', side: SyncSide.local)],
      );
      final result = plan(
        remote: remote,
        state: {for (final e in released.entries) e.key: e.value!},
      );
      expect(result.actions, isEmpty);
    });

    test('«Libera spazio» non si propaga anche con le cancellazioni accese', () {
      const record = SyncRecord(size: 5, modified: 1000, remote: 'k');
      final remote = {'S/chapters/0001/0001.webp': there('k', 5)};
      final released = releaseRecords(
        local: const {},
        remote: remote,
        state: const {'S/chapters/0001/0001.webp': record},
        releases: const [(path: 'S/chapters/0001', side: SyncSide.local)],
      );
      expect(
        plan(
          remote: remote,
          state: {for (final e in released.entries) e.key: e.value!},
          deletions: true,
        ).actions,
        isEmpty,
      );
    });

    test('tolto da Drive con «Libera spazio» resta sul telefono', () {
      const record = SyncRecord(size: 5, modified: 1000, remote: 'k');
      final local = {'S/chapters/0001/0001.webp': here(5)};
      final released = releaseRecords(
        local: local,
        remote: const {},
        state: const {'S/chapters/0001/0001.webp': record},
        releases: const [(path: 'S/chapters/0001', side: SyncSide.remote)],
      );
      final result = plan(
        local: local,
        state: {for (final e in released.entries) e.key: e.value!},
        deletions: true,
      );
      expect(result.actions, isEmpty);
    });

    test('tolto da tutt\'e due le parti, il ricordo se ne va', () {
      const record = SyncRecord(size: 5, modified: 1000, remote: 'k');
      final released = releaseRecords(
        local: const {},
        remote: const {},
        state: const {'S/chapters/0001/0001.webp': record},
        releases: const [
          (path: 'S/chapters/0001', side: SyncSide.local),
          (path: 'S/chapters/0001', side: SyncSide.remote),
        ],
      );
      expect(released, {'S/chapters/0001/0001.webp': null});
    });

    test('pezzi a metà e file nascosti restano fuori', () {
      expect(isSyncable('S/chapters/0001.part/0001.webp'), isFalse);
      expect(isSyncable('reading/downloads.json.tmp'), isFalse);
      expect(isSyncable('.foldersync/x'), isFalse);
      expect(isSyncable('S/chapters/0001/0001.webp'), isTrue);
    });
  });

  group('un giro', () {
    late Directory temp;
    late String root;
    late FakeRemote drive;
    late SyncFiles files;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('kagami-sync');
      root = p.join(temp.path, 'libreria');
      await Directory(root).create();
      files = SyncFiles(p.join(temp.path, 'app'));
      drive = FakeRemote();
    });
    tearDown(() => temp.delete(recursive: true));

    FolderSync sync(SyncDirection direction, {bool deletions = false}) => FolderSync(
          remote: drive,
          root: root,
          folderId: FakeRemote.rootId,
          direction: direction,
          deletions: deletions,
          files: files,
        );

    File local(String path) => File(p.joinAll([root, ...path.split('/')]));

    test('scarica, carica, ricorda e al secondo giro non fa niente', () async {
      drive.put('library.json', 'indice');
      drive.put('S/chapters/0001/0001.webp', 'tavola');
      await local('reading/backup/copia.gz').create(recursive: true);
      await local('reading/backup/copia.gz').writeAsString('backup');

      final first = await sync(SyncDirection.both).run();
      expect(first.error, isNull);
      expect(first.downloaded, 2);
      expect(first.uploaded, 1);
      expect(await local('S/chapters/0001/0001.webp').readAsString(), 'tavola');
      expect(drive.content('reading/backup/copia.gz'), 'backup');

      final second = await sync(SyncDirection.both).run();
      expect(second.changed, isFalse);
      expect((await files.readReport())!.at, second.at);
    });

    test('un capitolo tolto dal telefono non torna e non sparisce da Drive', () async {
      drive.put('S/chapters/0001/0001.webp', 'tavola');
      await sync(SyncDirection.download).run();
      await local('S/chapters/0001').delete(recursive: true);

      final again = await sync(SyncDirection.download).run();
      expect(again.changed, isFalse);
      expect(await local('S/chapters/0001/0001.webp').exists(), isFalse);
      expect(drive.content('S/chapters/0001/0001.webp'), 'tavola');
    });

    test('con le cancellazioni finisce nel cestino di Drive', () async {
      drive.put('S/chapters/0001/0001.webp', 'tavola');
      await sync(SyncDirection.both).run();
      await local('S/chapters/0001/0001.webp').delete();

      final again = await sync(SyncDirection.both, deletions: true).run();
      expect(again.trashed, 1);
      expect(drive.content('S/chapters/0001/0001.webp'), isNull);
    });

    test('cancellando dal telefono si tolgono anche le cartelle vuote', () async {
      drive.put('S/chapters/0001/0001.webp', 'tavola');
      await sync(SyncDirection.download).run();
      drive.remove('S/chapters/0001/0001.webp');

      final again = await sync(SyncDirection.download, deletions: true).run();
      expect(again.deletedLocal, 1);
      expect(await Directory(p.join(root, 'S', 'chapters', '0001')).exists(), isFalse);
    });

    test('le annotazioni di «Libera spazio» valgono una volta e poi si tolgono',
        () async {
      drive.put('S/chapters/0001/0001.webp', 'tavola');
      drive.put('S/chapters/0002/0001.webp', 'altra');
      await files.release(['S/chapters/0001'], SyncSide.local);

      final first = await sync(SyncDirection.both, deletions: true).run();
      expect(first.downloaded, 1);
      expect(await local('S/chapters/0001/0001.webp').exists(), isFalse);
      expect(drive.content('S/chapters/0001/0001.webp'), 'tavola');
      expect(await files.readReleases(), isEmpty);

      final second = await sync(SyncDirection.both, deletions: true).run();
      expect(second.changed, isFalse);
      expect(drive.content('S/chapters/0001/0001.webp'), 'tavola');
    });

    test('«Libera spazio» sulla cartella e la sincronizzazione vanno d\'accordo',
        () async {
      drive.put('S/chapters/0001/0001.webp', 'letto');
      drive.put('S/chapters/0002/0001.webp', 'da leggere');
      await sync(SyncDirection.both).run();

      final folder = p.join(root, 'S', 'chapters', '0001');
      await clearReadLeftovers(
        ReadLeftovers(
          folders: {'C1': [folder]},
          syncedPaths: const {'S/chapters/0001'},
          synced: true,
        ),
        series: 'S',
        folders: true,
        cache: false,
        sync: files,
      );
      expect(await Directory(folder).exists(), isFalse);

      // Anche con le cancellazioni propagate: il foglio ha scelto il
      // telefono, e Drive resta com'è.
      final after = await sync(SyncDirection.both, deletions: true).run();
      expect(after.changed, isFalse);
      expect(await Directory(folder).exists(), isFalse);
      expect(drive.content('S/chapters/0001/0001.webp'), 'letto');
    });

    test('un giro alla volta', () async {
      await files.lock.parent.create(recursive: true);
      await files.lock.writeAsString('altro');
      await expectLater(sync(SyncDirection.both).run(), throwsA(isA<SyncBusy>()));
    });

    test('senza rete si ferma e lo dice', () async {
      drive.put('a', 'x');
      drive.offline = true;
      final report = await sync(SyncDirection.both).run();
      expect(report.error, isNotNull);
      expect(await files.busy(), isFalse);
    });
  });
}

/// Drive in memoria: cartelle, file con impronta, cestino.
class FakeRemote implements SyncRemote {
  static const String rootId = 'ROOT';

  /// Come il client vero, che ha un `HttpClient`: non si può mandare a un
  /// isolate, e il giro non deve provarci.
  final HttpClient _unsendable = HttpClient();

  final Map<String, DriveItem> _items = {};
  final Map<String, String> _contents = {};
  var _next = 0;
  bool offline = false;

  String _id() => 'id${_next++}';

  String _folderFor(String path) {
    var parent = rootId;
    if (path.isEmpty) return parent;
    for (final name in path.split('/')) {
      final existing = _items.values.where(
        (item) => item.folder && item.name == name && item.parents.contains(parent),
      );
      parent = existing.isNotEmpty
          ? existing.first.id
          : _add(DriveItem(id: _id(), name: name, folder: true, parents: [parent])).id;
    }
    return parent;
  }

  DriveItem _add(DriveItem item) => _items[item.id] = item;

  DriveItem? _find(String path) {
    final parts = path.split('/');
    final parent = _folderFor(parts.sublist(0, parts.length - 1).join('/'));
    return _items.values
        .where((item) => !item.folder && item.name == parts.last && item.parents.contains(parent))
        .firstOrNull;
  }

  void put(String path, String content) {
    final parts = path.split('/');
    final parent = _folderFor(parts.sublist(0, parts.length - 1).join('/'));
    final old = _find(path);
    final item = _add(DriveItem(
      id: old?.id ?? _id(),
      name: parts.last,
      size: content.length,
      md5: '${content.hashCode}',
      modified: DateTime.utc(2026, 1, 1),
      parents: [parent],
    ));
    _contents[item.id] = content;
  }

  void remove(String path) {
    final item = _find(path);
    if (item != null) _items.remove(item.id);
  }

  String? content(String path) {
    final item = _find(path);
    return item == null ? null : _contents[item.id];
  }

  void _check() {
    _unsendable.idleTimeout;
    if (offline) throw const DriveOffline();
  }

  @override
  Future<List<DriveItem>> childrenOf(List<String> folderIds) async {
    _check();
    return [
      for (final item in _items.values)
        if (item.parents.any(folderIds.contains)) item,
    ];
  }

  @override
  Future<void> download(String id, File target) async {
    _check();
    await target.writeAsString(_contents[id]!);
  }

  @override
  Future<DriveItem> upload(
    File file, {
    String? id,
    String? name,
    String? parentId,
    DateTime? modified,
  }) async {
    _check();
    final content = await file.readAsString();
    final old = id == null ? null : _items[id];
    final item = _add(DriveItem(
      id: id ?? _id(),
      name: name ?? old!.name,
      size: content.length,
      md5: '${content.hashCode}',
      modified: modified,
      parents: parentId == null ? old!.parents : [parentId],
    ));
    _contents[item.id] = content;
    return item;
  }

  @override
  Future<DriveItem> createFolder(String name, String parentId) async {
    _check();
    return _add(DriveItem(id: _id(), name: name, folder: true, parents: [parentId]));
  }

  @override
  Future<void> trash(String id) async {
    _check();
    _items.remove(id);
  }
}
