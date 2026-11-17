// I pezzi finti che l'API vuole: chi chiama, il giro e il Drive di ognuno.
import 'dart:io';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/health.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart' show Provider, withUserProviders;
import 'package:kagami_archive/tracking.dart';
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
  Future<ServerCheck> configureCheck(
          {bool? enabled, int? minutes, bool? library, Set<String>? unfollowed, bool? elsewhere}) async =>
      check = check.copyWith(
          enabled: enabled, minutes: minutes, library: library, unfollowed: unfollowed, elsewhere: elsewhere);

  final List<Set<String>> looks = [];
  final List<Set<String>?> elsewhereReads = [];

  @override
  void lookElsewhere(Set<String> keys) => looks.add(keys);

  @override
  Future<Map<String, Object?>> elsewhere({Set<String>? keys}) async {
    elsewhereReads.add(keys);
    return {
      'series': {
        'coffeemanga:a': {'checkedAt': '2026-10-27T10:00:00.000Z', 'sites': <String, Object?>{}},
      },
      'pass': {'running': false, 'checked': 3, 'pending': 2},
    };
  }

  List<Provider> userList = const [];
  List<Map<String, String>> errors = const [];
  int refreshes = 0;

  @override
  List<Provider> get userSites => userList;

  @override
  List<Map<String, String>> get sitesErrors => errors;

  @override
  Future<void> refreshSites() async => refreshes++;

  @override
  R withSites<R>(R Function() body) => withUserProviders(userList, body);

  final List<({String? site, Set<String>? keys})> repairs = [];

  @override
  void repair({String? site, Set<String>? keys}) => repairs.add((site: site, keys: keys));

  List<GatedSeries> blocked = const [];
  final List<Map<String, String>> pages = [];

  @override
  Future<List<GatedSeries>> gated() async => blocked;

  @override
  Future<Map<String, SiteHealth>> sites() => files.health.load();

  final List<Map<String, String>> repairedPages = [];
  bool busy = false;

  @override
  Future<PagesRepair> repairPages(Map<String, String> pages) async {
    if (busy) throw const WorkerBusy();
    repairedPages.add(pages);
    return PagesRepair()..repaired = pages.length;
  }

  @override
  Future<CheckReport> checkPages(Map<String, String> pages) async {
    this.pages.add(pages);
    return CheckReport()
      ..checked = pages.length
      ..queued.addAll(pages.keys);
  }
}

class FakeDrive implements DriveSetup {
  bool ready = false;
  String? refresh;
  @override
  String? folderId;
  @override
  String? folderName;

  /// Una cartella `altrui…` è di un altro account.
  @override
  bool? folderOwned;

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
    folderOwned = !id.startsWith('altrui');
    return DriveItem(id: id, name: 'Scelta', folder: true);
  }

  @override
  Future<void> forget() async {
    ready = false;
    refresh = folderId = folderName = null;
    folderOwned = null;
  }

  /// Le chiamate a [unshare], `folderId/permissionId`; [unshareError] la fa fallire.
  final List<String> unshared = [];
  Object? unshareError;

  @override
  Future<void> unshare(String folderId, String permissionId) async {
    unshared.add('$folderId/$permissionId');
    if (!ready) throw const DriveNotAuthorized();
    if (unshareError case final error?) throw error;
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
  @override
  late final ShareKeeper shares = ShareKeeper(File(p.join(directory.path, 'shares.json')));
  bool destroyed = false;
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<void> destroy() async {
    destroyed = true;
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Un server intero sul loopback, con gli utenti veri e il resto finto.
class TestServer {
  TestServer._(this.dir, this.accounts, this.server, this.spaces);

  static Future<TestServer> start({
    String owner = 'owner@example.com',
    String name = 'Prova',
    DateTime Function()? now,
    String? id,
    IdentityVerifier? tickets,
    ServerCatalog? catalog,
  }) async {
    final dir = await Directory.systemTemp.createTemp('kagami-api-');
    final spaces = <String, FakeSpace>{};
    final accounts = Accounts(
      File(p.join(dir.path, 'users.json')),
      owner: owner,
      open: (email) async => spaces[email] = FakeSpace(Directory(p.join(dir.path, 'users', email))),
      now: now,
    );
    final api = ServerApi(
      name: name,
      identity: FakeIdentity(),
      accounts: accounts,
      images: true,
      log: (_) {},
      id: id,
      tickets: tickets,
      catalog: catalog,
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
