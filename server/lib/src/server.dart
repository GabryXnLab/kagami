/// Il server messo insieme: configurazione, utenti, giri e API.
library;

import 'dart:async';
import 'dart:io';

import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart' show PageBrowser;
import 'package:kagami_archive/remote.dart' show ServerSetup;
import 'package:path/path.dart' as p;

import 'api.dart';
import 'browser.dart';
import 'config.dart';
import 'google.dart';
import 'identity.dart';
import 'images.dart';
import 'users.dart';
import 'worker.dart';

/// Lo spazio di un utente sul server: cartella, Drive e giro.
class ServerSpace implements UserSpace {
  ServerSpace._(this.directory, this.files, this.userDrive, this.worker);

  static Future<ServerSpace> open(
    Directory directory,
    GoogleClient client, {
    required ImageTools images,
    PageBrowser? browser,
    int? checkMinutes,
  }) async {
    final files = ArchiveFiles(directory.path);
    final drive = UserDrive(File(p.join(directory.path, 'drive.json')), client);
    await drive.load();
    final worker = ServerWorker(
      files,
      serverEnvironment(files, drive.drive, Directory(p.join(directory.path, 'scratch')), images),
      blocked: drive.blocked,
      checkMinutes: checkMinutes,
      folder: () => drive.folderId,
      browser: browser,
    )..start();
    return ServerSpace._(directory, files, drive, worker);
  }

  final Directory directory;
  @override
  final ArchiveFiles files;
  final UserDrive userDrive;
  final ServerWorker worker;

  @override
  JobControl get jobs => worker;

  @override
  DriveSetup get drive => userDrive;

  @override
  Future<void> close() async {
    await worker.close();
    userDrive.close();
  }

  @override
  Future<void> destroy() async {
    await close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Applica `KAGAMI_SETUP` se è nuova: progetto e client in `setup.json`, il
/// permesso del proprietario nella sua cartella. Torna la configurazione in
/// vigore, o `null` se il server non ne ha mai avuta una.
Future<AppliedSetup?> applySetup(ServerPaths paths, String? blob, {void Function(String)? say}) async {
  final current = await AppliedSetup.load(paths);
  if (blob == null || blob.trim().isEmpty) return current;
  final hash = setupHash(blob);
  if (current?.hash == hash) return current;
  final setup = ServerSetup.decode(blob);
  final applied = AppliedSetup(
    project: setup.project,
    client: setup.client,
    owner: setup.owner,
    name: setup.name,
    hash: hash,
  );
  await applied.save(paths);
  final drive = UserDrive(File(p.join(paths.user(setup.owner).path, 'drive.json')), setup.client);
  await drive.put(setup.refreshToken, setup.folderId, setup.folderName);
  say?.call('Configurazione applicata: proprietario ${setup.owner}.');
  return applied;
}

/// Accende il server e resta acceso finché non riceve SIGINT o SIGTERM.
Future<void> serve(ServerPaths paths, {String? host, int? port, String? setup, void Function(String)? say}) async {
  final void Function(String) out = say ?? stdout.writeln;
  await paths.root.create(recursive: true);
  final config = (await ServerConfig.load(paths)).withEnvironment(Platform.environment);
  final applied = await applySetup(paths, setup ?? environment(Platform.environment, 'KAGAMI_SETUP'), say: out);

  final vips = await VipsImageTools.available();
  final ImageTools images = vips ? VipsImageTools(paths.scratch) : const NoImageTools();
  final chromium = await HeadlessBrowser.find();
  final browser = chromium == null ? null : HeadlessBrowser(chromium, paths.browser, log: out);
  final accounts = applied == null
      ? null
      : Accounts(
          paths.users,
          owner: applied.owner,
          open: (email) => ServerSpace.open(
            paths.user(email),
            applied.client,
            images: images,
            browser: browser,
            checkMinutes: config.checkMinutes,
          ),
        );
  final api = ServerApi(
    name: config.name ?? applied?.name ?? 'Kagami Server',
    identity: applied == null ? null : FirebaseVerifier(applied.project),
    accounts: accounts,
    images: vips,
    browser: browser != null,
  );

  final server = await HttpServer.bind(host ?? config.host, port ?? config.port);
  server.idleTimeout = const Duration(seconds: 30);
  out('Kagami Server $serverVersion in ascolto su ${server.address.address}:${server.port}');
  out('Dati in ${paths.root.path}');
  out(vips ? 'Miniature e tessere: libvips.' : 'Miniature e tessere: spente (manca «vips»).');
  out(chromium != null
      ? 'Siti dietro la verifica del browser: $chromium.'
      : 'Siti dietro la verifica del browser: saltati nei controlli (manca Chromium).');
  if (accounts == null) {
    out('Nessuna configurazione: avvia il server col comando che genera l\'app '
        '(Altro → Scarica un manga → Server → Crea il tuo server).');
  } else {
    await accounts.openAll();
    final users = await accounts.list();
    out('Proprietario: ${accounts.owner}; account ammessi: ${users.length}.');
  }

  final serving = server.listen((request) => unawaited(api.handle(request)));

  final stop = Completer<void>();
  final signals = [
    ProcessSignal.sigint.watch().listen((_) => stop.isCompleted ? null : stop.complete()),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen((_) => stop.isCompleted ? null : stop.complete()),
  ];
  await stop.future;
  out('Chiusura: i lavori in corso si fermano e restano in coda.');
  for (final signal in signals) {
    await signal.cancel();
  }
  await serving.cancel();
  await server.close();
  await accounts?.close();
  await browser?.close();
}
