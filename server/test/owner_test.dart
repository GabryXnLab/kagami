// Kagami cancella solo dove l'utente possiede (docs/server-api.md, «Proprietà
// della cartella»): il server legge `ownedByMe` quando cambia la cartella, lo
// tiene con lei e senza un `true` non sposta niente nel cestino di Drive. E
// non legge né scrive `reading/`, che è dell'app.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart' show SuppliedPages;
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Drive in memoria che ricorda per percorso ciò che si legge e si scrive.
class _Remote implements SyncRemote {
  static const String root = 'LIB';

  final Map<String, DriveItem> items = {};
  final Map<String, Uint8List> contents = {};
  final List<String> listed = [];
  final List<String> downloaded = [];
  final List<String> written = [];
  final List<String> trashed = [];
  var _next = 0;

  String pathOf(String id) {
    if (id == root) return '';
    final item = items[id]!;
    final parent = pathOf(item.parents.single);
    return parent.isEmpty ? item.name : '$parent/${item.name}';
  }

  String folder(String path) {
    var parent = root;
    for (final name in path.split('/').where((part) => part.isNotEmpty)) {
      final found = items.values.where((i) => i.folder && i.name == name && i.parents.contains(parent));
      parent = found.isNotEmpty ? found.first.id : _put(DriveItem(id: 'd${_next++}', name: name, folder: true, parents: [parent])).id;
    }
    return parent;
  }

  void place(String path, String text) {
    final bytes = utf8.encode(text);
    final dir = p.posix.dirname(path);
    final item = _put(DriveItem(
        id: 'f${_next++}', name: p.posix.basename(path), size: bytes.length,
        md5: md5.convert(bytes).toString(), parents: [folder(dir == '.' ? '' : dir)]));
    contents[item.id] = Uint8List.fromList(bytes);
  }

  DriveItem _put(DriveItem item) => items[item.id] = item;

  @override
  Future<List<DriveItem>> childrenOf(List<String> folderIds) async {
    listed.addAll(folderIds.map(pathOf));
    return [for (final item in items.values) if (item.parents.any(folderIds.contains)) item];
  }

  @override
  Future<DriveItem> createFolder(String name, String parentId) async {
    final item = _put(DriveItem(id: 'd${_next++}', name: name, folder: true, parents: [parentId]));
    written.add(pathOf(item.id));
    return item;
  }

  @override
  Future<void> download(String id, File target) async {
    downloaded.add(pathOf(id));
    await target.writeAsBytes(contents[id]!);
  }

  @override
  Future<DriveItem> upload(File file, {String? id, String? name, String? parentId, DateTime? modified}) async {
    final bytes = await file.readAsBytes();
    final old = id == null ? null : items[id];
    final item = _put(DriveItem(
        id: id ?? 'f${_next++}', name: name ?? old!.name, size: bytes.length,
        md5: md5.convert(bytes).toString(), parents: [parentId ?? old!.parents.single]));
    contents[item.id] = bytes;
    written.add(pathOf(item.id));
    return item;
  }

  @override
  Future<void> trash(String id) async {
    trashed.add(pathOf(id));
    items.remove(id);
  }

  @override
  Future<DriveItem> rename(String id, String name) async {
    final old = items[id]!;
    final item = _put(DriveItem(id: id, name: name, folder: old.folder, size: old.size, md5: old.md5, parents: old.parents));
    written.add(pathOf(id));
    return item;
  }
}

class _Page implements ProviderHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async =>
      (body: Uint8List.fromList(utf8.encode(_manhwaPage)), contentType: 'text/html');

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => throw const ProviderOffline();
}

const _manhwa = 'https://manhwaread.com/manhwa/disfarming/';
const _manhwaPage = '''<html><head><meta property="og:image" content="https://mancover.xyz/cover/d.webp"></head>
<body class="postid-508"><h1 class="text-3xl text-primary">Disfarming</h1><div id="chaptersList">
<a class="chapter-item" data-id="1" href="${_manhwa}chapter-01/"><span class="chapter-item__name">Chapter 01</span></a>
</div></body></html>''';
const _folder = 'Disfarming [manhwaread-disfarming]';

void main() {
  late Directory dir;
  late ArchiveFiles files;
  late _Remote remote;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kagami-owner-');
    files = ArchiveFiles(dir.path);
    remote = _Remote()
      ..place('$_folder/series.json', jsonEncode({
        'schemaVersion': 3, 'provider': 'manhwaread', 'id': 'disfarming', 'title': 'Vecchio titolo',
        'source': _manhwa, 'metadata': const {}, 'chapters': const <Object?>[],
      }))
      ..place('library.json', jsonEncode({
        'series': [{'key': 'manhwaread:disfarming', 'path': _folder, 'source': _manhwa, 'title': 'Vecchio titolo'}],
      }))
      ..place('reading/manhwaread-disfarming.json', '{"chapter": "1"}');
  });
  tearDown(() => dir.delete(recursive: true));

  ArchiveEnvironment environment(Map<String, bool?> owned) => serverEnvironment(
      files, remote, Directory(p.join(dir.path, 'scratch')), const NoImageTools(), owned: (id) => owned[id]);

  DriveStore store(Map<String, bool?> owned) => environment(owned)
      .storeFor(const ArchiveTarget(destination: ArchiveDestination.drive, folderId: _Remote.root)) as DriveStore;

  group('nel cestino solo nella cartella propria', () {
    test('non propria: removeSeries e removeFile rifiutati con not_owner, Drive intatto', () async {
      final s = store({_Remote.root: false});
      await expectLater(s.removeSeries(_folder, 'manhwaread:disfarming'),
          throwsA(isA<FolderNotOwned>().having((e) => e.unknown, 'unknown', isFalse)));
      await expectLater(s.removeFile('library.json'), throwsA(isA<FolderNotOwned>()));
      expect(FolderNotOwned.code, 'not_owner');
      expect(remote.trashed, isEmpty);
      expect(remote.written, isEmpty);
    });

    test('proprietà non letta: rifiutato allo stesso modo, e lo dice', () async {
      await expectLater(store({}).removeSeries(_folder, 'manhwaread:disfarming'),
          throwsA(isA<FolderNotOwned>().having((e) => e.unknown, 'unknown', isTrue)));
      expect(remote.trashed, isEmpty);
    });

    test('propria: la serie va nel cestino come prima', () async {
      await store({_Remote.root: true}).removeSeries(_folder, 'manhwaread:disfarming');
      expect(remote.trashed, [_folder]);
    });
  });

  test('una riparazione sulla libreria di Drive non tocca reading/', () async {
    final env = environment({_Remote.root: true});
    final worker = ServerWorker(
      files,
      ArchiveEnvironment(
        scratch: env.scratch,
        storeFor: env.storeFor,
        httpFor: (provider, {userAgent, cookies = const {}}) => _Page(),
      ),
      blocked: () async => null,
      folder: () => _Remote.root,
      browser: SuppliedPages(const {}),
      log: (_) {},
    );
    worker.repair(keys: {'manhwaread:disfarming'});
    worker.start();
    for (var i = 0; i < 200 && (await files.history()).isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await worker.close();
    expect((await files.history()).single.repair?['titleChanged'], isTrue);
    expect(remote.written, contains('$_folder/series.json'));
    bool reading(String path) => path == 'reading' || path.startsWith('reading/');
    expect(remote.written.where(reading), isEmpty);
    expect(remote.downloaded.where(reading), isEmpty);
    expect(remote.listed.where(reading), isEmpty);
    expect(remote.trashed, isEmpty);
  });

  group('UserDrive legge e tiene la proprietà', () {
    late HttpServer google;
    late HttpServer drive;
    final owners = <String, bool>{};
    var ownerFails = false;
    const client = GoogleClient('id.apps.googleusercontent.com', 'segreto');

    setUp(() async {
      owners.clear();
      ownerFails = false;
      google = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      google.listen((request) async {
        await request.drain<void>();
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'access_token': 'a', 'expires_in': 3600}));
        await request.response.close();
      });
      drive = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      drive.listen((request) async {
        final segments = request.uri.pathSegments;
        final id = segments.length > 3 ? segments[3] : null;
        Object reply;
        if (id == null) {
          reply = {'files': const <Object?>[]};
        } else if (request.uri.queryParameters['fields'] == 'id,ownedByMe') {
          if (ownerFails) {
            request.response.statusCode = 400;
            reply = {'error': {'code': 400, 'message': 'no'}};
          } else {
            reply = {'id': id, if (owners[id] != null) 'ownedByMe': owners[id]};
          }
        } else {
          reply = {'id': id, 'name': 'Manga', 'mimeType': folderMimeType};
        }
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(reply));
        await request.response.close();
      });
    });
    tearDown(() async {
      await google.close(force: true);
      await drive.close(force: true);
    });

    final opened = <UserDrive>[];
    tearDown(() {
      for (final d in opened) {
        d.close();
      }
      opened.clear();
    });

    Future<UserDrive> open() async {
      final d = UserDrive(File(p.join(dir.path, 'drive.json')), client,
          endpoint: Uri.parse('http://127.0.0.1:${google.port}/token'),
          driveFor: (token) => DriveClient(token,
              network: const ServerNetwork(),
              endpoint: (path, query) => Uri.parse('http://127.0.0.1:${drive.port}$path').replace(queryParameters: query)));
      opened.add(d);
      await d.load();
      return d;
    }

    test('alla scelta della cartella: propria vero, d\'altri falso, e resta dopo un riavvio', () async {
      owners['mia'] = true;
      final d = await open();
      await d.grant('refresh', 'mia');
      expect((d.folderOwned, d.ownedOf('mia'), d.ownedOf('altra')), (true, true, null));
      expect((await open()).folderOwned, isTrue);

      await d.choose('altrui');
      expect(d.folderOwned, isFalse);
      expect((await open()).folderOwned, isFalse);
    });

    test('Drive non risponde: non letta, nessun cestino, e si rilegge prima del giro', () async {
      owners['mia'] = true;
      ownerFails = true;
      final d = await open();
      await d.grant('refresh', 'mia');
      expect(d.folderOwned, isNull);
      expect(d.ownedOf('mia'), isNull);

      ownerFails = false;
      expect(await d.blocked(), isNull);
      expect(d.folderOwned, isTrue);
      expect((await open()).folderOwned, isTrue);
    });

    test('la cartella di KAGAMI_SETUP arriva non letta, poi la legge il giro', () async {
      owners['setup'] = false;
      final d = await open();
      await d.put('refresh', 'setup', 'Manga');
      expect(d.folderOwned, isNull);
      await d.blocked();
      expect(d.folderOwned, isFalse);
    });
  });
}
