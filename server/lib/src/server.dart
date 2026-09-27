/// Il server messo insieme: configurazione, Drive, giro e API.
library;

import 'dart:async';
import 'dart:io';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/image_tools.dart';

import 'api.dart';
import 'config.dart';
import 'google.dart';
import 'images.dart';
import 'keys.dart';
import 'worker.dart';

/// Drive del server: il permesso in `drive-token.json`, la cartella in
/// `config.json`.
class ServerDrive implements DriveSetup {
  ServerDrive(this.paths, this._config)
      : tokens = DriveTokens(paths.driveToken, _client(_config));

  final ServerPaths paths;
  ServerConfig _config;
  final DriveTokens tokens;

  late final DriveClient client = DriveClient(tokens.token, network: const ServerNetwork());

  ServerConfig get config => _config;

  static GoogleClient? _client(ServerConfig config) {
    final id = config.clientId;
    final secret = config.clientSecret;
    return id == null || secret == null ? null : GoogleClient(id, secret);
  }

  @override
  Future<bool> get authorized async => _client(_config) != null && await tokens.authorized;

  @override
  String? get folderId => _config.folderId;

  @override
  String? get folderName => _config.folderName;

  @override
  Future<DriveItem> choose(String folderId) async {
    final item = await client.file(folderId);
    if (!item.folder) throw const DriveException('Non è una cartella.');
    // Un elenco dice anche che il server ci può entrare: `file` risponde
    // pure per una cartella vista solo di sfuggita da un link condiviso.
    await client.children(folderId);
    final chosen = (await ServerConfig.load(paths)).copyWith(folderId: item.id, folderName: item.name);
    await chosen.save(paths);
    _config = _config.copyWith(folderId: item.id, folderName: item.name);
    return item;
  }

  /// Perché un giro non può partire, o `null`.
  Future<String?> blocked() async {
    if (_client(_config) == null) {
      return 'Manca il client OAuth di Google: esegui «kagami-server drive login».';
    }
    if (_config.folderId == null) return 'Manca la cartella della libreria: «kagami-server drive folder».';
    try {
      await tokens.token();
      return null;
    } on DriveNotAuthorized catch (error) {
      return '$error';
    } on DriveOffline {
      return 'Google non risponde: si riprova fra poco.';
    }
  }
}

/// Accende il server e resta acceso finché non riceve SIGINT o SIGTERM.
Future<void> serve(ServerPaths paths, {String? host, int? port, void Function(String)? say}) async {
  final out = say ?? stdout.writeln;
  await paths.root.create(recursive: true);
  final config = (await ServerConfig.load(paths)).withEnvironment(Platform.environment);
  final drive = ServerDrive(paths, config);
  final files = paths.files;
  final keys = ApiKeys(paths.keys);

  final vips = await VipsImageTools.available();
  final ImageTools images = vips ? VipsImageTools(paths.scratch) : const NoImageTools();
  final worker = ServerWorker(
    files,
    serverEnvironment(files, drive.client, paths.scratch, images),
    blocked: drive.blocked,
    checkMinutes: config.checkMinutes,
  );
  final api = ServerApi(
    name: config.name,
    keys: keys,
    files: files,
    jobs: worker,
    drive: drive,
    images: vips,
    checkMinutes: config.checkMinutes,
  );

  // Il primo avvio senza chiavi ne crea una e la stampa: con Docker la si
  // legge da `docker logs`, senza entrare nel contenitore.
  if ((await keys.list()).isEmpty) {
    final (_, secret) = await keys.create('primo dispositivo');
    out('Nessuna chiave API: ne ho creata una. Copiala adesso, non verrà più mostrata:\n\n  $secret\n');
  }

  final server = await HttpServer.bind(host ?? config.host, port ?? config.port);
  server.idleTimeout = const Duration(seconds: 30);
  out('Kagami Server $serverVersion in ascolto su ${server.address.address}:${server.port}');
  out('Dati in ${paths.root.path}');
  out(vips ? 'Miniature e tessere: libvips.' : 'Miniature e tessere: spente (manca «vips»).');
  final reason = await drive.blocked();
  out(reason == null ? 'Drive: pronto, cartella ${config.folderName ?? config.folderId}.' : 'Drive: $reason');

  worker.start();
  final serving = server.listen((request) => unawaited(api.handle(request)));

  final stop = Completer<void>();
  final signals = [
    ProcessSignal.sigint.watch().listen((_) => stop.isCompleted ? null : stop.complete()),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen((_) => stop.isCompleted ? null : stop.complete()),
  ];
  await stop.future;
  out('Chiusura: il lavoro in corso si ferma e resta in coda.');
  for (final signal in signals) {
    await signal.cancel();
  }
  await serving.cancel();
  await server.close();
  await worker.close();
  drive.client.close();
}
