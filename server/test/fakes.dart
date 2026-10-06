// I pezzi finti che l'API vuole: chi chiama, il giro e il Drive di ognuno.
import 'dart:io';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;

/// Il token è `tok:<indirizzo>`: la verifica vera sta in identity_test.
class FakeIdentity implements IdentityVerifier {
  @override
  Future<Identity> verify(String token) async {
    if (!token.startsWith('tok:')) throw const IdentityError('Firma del token non valida.');
    return Identity(token.substring(4).toLowerCase());
  }
}

class FakeJobs implements JobControl {
  FakeJobs(this.files);

  final ArchiveFiles files;
  int woken = 0;
  final List<String> cancelled = [];
  int checks = 0;

  @override
  void wake() => woken++;

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    await files.remove(id);
  }

  @override
  Future<void> checkNow() async => checks++;

  final List<String> seriesChecks = [];

  @override
  Future<void> checkSeries(String key) async => seriesChecks.add(key);

  ServerCheck check = const ServerCheck();

  @override
  Future<ServerCheck> checkSettings() async => check;

  @override
  Future<ServerCheck> configureCheck({bool? enabled, int? minutes, bool? library}) async =>
      check = check.copyWith(enabled: enabled, minutes: minutes, library: library);
}

class FakeDrive implements DriveSetup {
  bool ready = false;
  String? refresh;
  @override
  String? folderId;
  @override
  String? folderName;

  @override
  Future<bool> get authorized async => ready;

  @override
  Future<void> grant(String refreshToken, String id) async {
    if (refreshToken == 'revocato') throw const DriveNotAuthorized('Google ha rifiutato il permesso di Drive');
    await choose(id);
    ready = true;
    refresh = refreshToken;
  }

  @override
  Future<DriveItem> choose(String id) async {
    if (id == 'non-esiste') throw const DriveException('File non trovato su Drive', status: 404);
    folderId = id;
    folderName = 'Scelta';
    return DriveItem(id: id, name: 'Scelta', folder: true);
  }

  @override
  Future<void> forget() async {
    ready = false;
    refresh = folderId = folderName = null;
  }
}

class FakeSpace implements UserSpace {
  FakeSpace(this.directory) : files = ArchiveFiles(directory.path) {
    jobs = FakeJobs(files);
  }

  final Directory directory;
  @override
  final ArchiveFiles files;
  @override
  late final FakeJobs jobs;
  @override
  final FakeDrive drive = FakeDrive();
  bool destroyed = false;

  @override
  Future<void> close() async {}

  @override
  Future<void> destroy() async {
    destroyed = true;
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Un server intero sul loopback, con gli utenti veri e il resto finto.
class TestServer {
  TestServer._(this.dir, this.accounts, this.server, this.spaces);

  static Future<TestServer> start({String owner = 'owner@example.com', String name = 'Prova'}) async {
    final dir = await Directory.systemTemp.createTemp('kagami-api-');
    final spaces = <String, FakeSpace>{};
    final accounts = Accounts(
      File(p.join(dir.path, 'users.json')),
      owner: owner,
      open: (email) async => spaces[email] = FakeSpace(Directory(p.join(dir.path, 'users', email))),
    );
    final api = ServerApi(
      name: name,
      identity: FakeIdentity(),
      accounts: accounts,
      images: true,
      log: (_) {},
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(api.handle);
    return TestServer._(dir, accounts, server, spaces);
  }

  final Directory dir;
  final Accounts accounts;
  final HttpServer server;
  final Map<String, FakeSpace> spaces;

  Uri get address => Uri.parse('http://127.0.0.1:${server.port}');

  /// Lo spazio di un utente, già col Drive pronto.
  Future<FakeSpace> ready(String email) async {
    final space = await accounts.space(email) as FakeSpace;
    space.drive
      ..ready = true
      ..folderId = 'cartella-$email'
      ..folderName = 'Manga';
    return space;
  }

  Future<void> close() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  }
}
