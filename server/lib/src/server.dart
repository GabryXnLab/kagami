/// Il server messo insieme: configurazione, utenti, giri e API.
library;

import 'dart:async';
import 'dart:io';

import 'package:kagami_archive/drive.dart' show DriveSyncRemote;
import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart' show PageBrowser;
import 'package:kagami_archive/renderer.dart' show installPageRenderer;
import 'package:kagami_archive/remote.dart' show ServerSetup;
import 'package:path/path.dart' as p;

import 'api.dart';
import 'browser.dart';
import 'browser_container.dart';
import 'catalog.dart';
import 'config.dart';
import 'google.dart';
import 'identity.dart';
import 'ticket.dart';
import 'images.dart';
import 'shares.dart';
import 'users.dart';
import 'worker.dart';

/// Lo spazio di un utente sul server: cartella, Drive e giro.
class ServerSpace implements UserSpace {
  ServerSpace._(this.directory, this.files, this.userDrive, this.worker)
      : shares = ShareKeeper(File(p.join(directory.path, 'shares.json')));

  static Future<ServerSpace> open(
    Directory directory,
    GoogleClient client, {
    required ImageTools images,
    PageBrowser? browser,
    int? checkMinutes,
    ServerCatalog? catalog,
  }) async {
    final files = ArchiveFiles(directory.path);
    final drive = UserDrive(File(p.join(directory.path, 'drive.json')), client);
    await drive.load();
    final worker = ServerWorker(
      files,
      serverEnvironment(files, DriveSyncRemote(drive.drive), Directory(p.join(directory.path, 'scratch')), images,
          owned: drive.ownedOf),
      blocked: drive.blocked,
      checkMinutes: checkMinutes,
      catalog: catalog,
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
  final ShareKeeper shares;

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
    backend: SetupBackend.fromBlob(blob),
    name: setup.name,
    hash: hash,
  );
  await applied.save(paths);
  final drive = UserDrive(File(p.join(paths.user(setup.owner).path, 'drive.json')), setup.client);
  await drive.put(setup.refreshToken, setup.folderId, setup.folderName);
  say?.call('Configurazione applicata: proprietario ${setup.owner}.');
  return applied;
}

/// Di chi accettare i token: il backend di `KAGAMI_BACKEND_URL` e
/// `KAGAMI_BACKEND_ANON_KEY`, altrimenti quello della configurazione;
/// Firebase con `KAGAMI_FIREBASE_PROJECT`, o col `project` di una
/// configurazione senza backend, perché un server installato prima del
/// backend non smetta di funzionare aggiornandosi. `null` se nessuno dei due:
/// le richieste rispondono `not_configured`.
IdentityVerifier? identityFor(AppliedSetup applied, Map<String, String> env, {void Function(String)? say}) {
  final url = environment(env, 'KAGAMI_BACKEND_URL');
  final key = environment(env, 'KAGAMI_BACKEND_ANON_KEY');
  final backend = backendFor(applied, env);
  if ((url != null || key != null) && backend == null) {
    say?.call('KAGAMI_BACKEND_URL e KAGAMI_BACKEND_ANON_KEY vanno date tutte e due, con un indirizzo completo: '
        'il backend resta spento.');
  }
  final project = environment(env, 'KAGAMI_FIREBASE_PROJECT') ?? (applied.backend == null ? applied.project : null);
  if (backend == null && project == null) {
    say?.call('Né backend né progetto Firebase: nessun token è accettato. '
        'Ricrea il server col comando dell\'app, o imposta KAGAMI_BACKEND_URL e KAGAMI_BACKEND_ANON_KEY.');
    return null;
  }
  say?.call('Token accettati: ${[
    if (backend != null) 'backend ${backend.url}',
    if (project != null) 'Firebase, progetto $project',
  ].join('; ')}.');
  return TokenVerifier(
    backend: backend == null ? null : BackendVerifier(backend.url, backend.anonKey),
    firebase: project == null ? null : FirebaseVerifier(project),
  );
}

/// Il backend di cui accettare token e biglietti: le variabili del server,
/// altrimenti quello della configurazione.
SetupBackend? backendFor(AppliedSetup applied, Map<String, String> env) {
  final url = environment(env, 'KAGAMI_BACKEND_URL');
  final key = environment(env, 'KAGAMI_BACKEND_ANON_KEY');
  return url == null && key == null
      ? applied.backend
      : SetupBackend.fromJson({'url': url ?? '${applied.backend?.url ?? ''}', 'anonKey': key ?? applied.backend?.anonKey});
}

/// Il comando `browser`: Chromium nel contenitore `kagami-browser`, col
/// profilo nella cartella dei dati di quel contenitore (non quella del
/// server) e il proxy del server, `KAGAMI_BROWSER_PROXY`, come unica uscita.
Future<int> browserCommand(ServerPaths paths) async {
  final chromium = await HeadlessBrowser.find();
  if (chromium == null) {
    stderr.writeln('Manca Chromium: il comando browser gira nell\'immagine del server.');
    return 1;
  }
  final proxy = environment(Platform.environment, 'KAGAMI_BROWSER_PROXY') ?? 'kagami-server:$browserProxyPort';
  stdout.writeln('Chromium $chromium, DevTools sulla porta $browserDebugPort per il server, proxy $proxy.');
  return runBrowser(chromium, paths.browser, proxy);
}

/// Accende il server e resta acceso finché non riceve SIGINT o SIGTERM.
Future<void> serve(ServerPaths paths, {String? host, int? port, String? setup, void Function(String)? say}) async {
  final void Function(String) out = say ?? stdout.writeln;
  await paths.root.create(recursive: true);
  final config = (await ServerConfig.load(paths)).withEnvironment(Platform.environment);
  final applied = await applySetup(paths, setup ?? environment(Platform.environment, 'KAGAMI_SETUP'), say: out);

  final vips = await VipsImageTools.available();
  final ImageTools images = vips ? VipsImageTools(paths.scratch) : const NoImageTools();
  final remote = environment(Platform.environment, 'KAGAMI_BROWSER');
  final chromium = remote == null ? await HeadlessBrowser.find() : null;
  final browser = remote != null
      ? HeadlessBrowser.remote(remote, log: out)
      : chromium == null
          ? null
          : HeadlessBrowser(chromium, paths.browser, log: out);
  // Le pagine che i siti vogliono rese (`browser.pages`) le apre lo stesso Chromium.
  installPageRenderer(browser);
  final catalog = ServerCatalog.fromEnvironment(Platform.environment, paths.catalog, log: out);
  if (catalog != null) {
    await catalog.load();
    out('Catalogo dei siti: serial ${catalog.serial} dalla cache, ${catalog.urls.length} indirizzi.');
    unawaited(catalog.refresh());
  }
  final spaces = <String, ServerSpace>{};
  final accounts = applied == null
      ? null
      : Accounts(
          paths.users,
          owner: applied.owner,
          open: (email) async => spaces[email] = await ServerSpace.open(
            paths.user(email),
            applied.client,
            images: images,
            browser: browser,
            checkMinutes: config.checkMinutes,
            catalog: catalog,
          ),
        );
  final id = await serverIdentity(paths);
  final backend = applied == null ? null : backendFor(applied, Platform.environment);
  final api = ServerApi(
    name: config.name ?? applied?.name ?? 'Kagami Server',
    id: id,
    tickets: backend == null ? null : TicketVerifier(backend.url, backend.anonKey, id, applied!.owner),
    identity: applied == null ? null : identityFor(applied, Platform.environment, say: out),
    accounts: accounts,
    images: vips,
    browser: browser != null,
    catalog: catalog,
  );

  final server = await HttpServer.bind(host ?? config.host, port ?? config.port);
  server.idleTimeout = const Duration(seconds: 30);
  out('Kagami Server $serverVersion in ascolto su ${server.address.address}:${server.port}');
  out('Dati in ${paths.root.path}');
  out(vips ? 'Miniature e tessere: libvips.' : 'Miniature e tessere: spente (manca «vips»).');
  if (remote != null) {
    out('Siti dietro la verifica del browser: Chromium nel contenitore «$remote», '
        'DevTools sulla porta $browserDebugPort, proxy sulla $browserProxyPort.');
  } else if (chromium != null) {
    out('Siti dietro la verifica del browser: $chromium, nello stesso contenitore dei dati.');
    if (await File('/.dockerenv').exists()) {
      out('Consiglio: rilancia il server col comando nuovo dell\'app, che mette Chromium nel contenitore '
          'separato kagami-browser (KAGAMI_BROWSER), lontano da drive.json (docs/server.md).');
    }
  } else {
    out('Siti dietro la verifica del browser: saltati nei controlli (manca Chromium).');
  }
  if (accounts == null) {
    out('Nessuna configurazione: avvia il server col comando che genera l\'app '
        '(Altro → Scarica un manga → Server → Crea il tuo server).');
  } else {
    await accounts.openAll();
    final users = await accounts.list();
    out('Proprietario: ${accounts.owner}; account ammessi: ${users.length}.');
  }

  final serving = server.listen((request) => unawaited(api.handle(request)));

  // L'ultima difesa contro un'attesa senza fine: il server è rimasto fermo
  // una settimana su un lavoro, senza errori, finché qualcuno non l'ha
  // guardato. Il processo esce e Docker lo riaccende (`--restart`); coda,
  // stato e tavole già scaricate sono sul disco, e il lavoro riprende da lì.
  final watchdog = Timer.periodic(const Duration(minutes: 5), (timer) async {
    for (final MapEntry(key: email, value: space) in spaces.entries) {
      final why = space.worker.stuck(run: const Duration(hours: 1), check: const Duration(hours: 4));
      if (why == null) continue;
      timer.cancel();
      out('Bloccato per $email: $why. Il server si riavvia.');
      // La riga deve arrivare al log di Docker prima che il processo esca.
      await Future.any([stdout.flush(), Future<void>.delayed(const Duration(seconds: 2))]);
      exit(75);
    }
  });

  // Gli accessi scaduti: spazio chiuso, e tolto dopo trenta giorni. Le
  // richieste lo controllano da sé; questa passata ferma i giri di chi non chiama.
  final expiry = Timer.periodic(const Duration(hours: 1), (_) async {
    try {
      // Prima le condivisioni: quelle di un accesso scaduto restano all'app.
      await accounts?.sweepShares(say: out);
      await accounts?.sweep();
    } on Object catch (error) {
      out('Controllo delle scadenze fallito: $error');
    }
  });

  final stop = Completer<void>();
  final signals = [
    ProcessSignal.sigint.watch().listen((_) => stop.isCompleted ? null : stop.complete()),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen((_) => stop.isCompleted ? null : stop.complete()),
  ];
  await stop.future;
  watchdog.cancel();
  expiry.cancel();
  out('Chiusura: i lavori in corso si fermano e restano in coda.');
  for (final signal in signals) {
    await signal.cancel();
  }
  await serving.cancel();
  await server.close();
  await accounts?.close();
  await browser?.close();
  catalog?.close();
}
