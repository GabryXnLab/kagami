import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_server/kagami_server.dart';

const String usage = '''Kagami Server: scarica le serie al posto del telefono e le carica su Drive.

Uso: kagami-server [--data <cartella>] <comando>

  serve [--host H] [--port P]     accende il server (default 0.0.0.0:8080)
  key create <nome> [--url U]     crea una chiave API; con --url stampa anche il link da incollare nell'app
  key list                        le chiavi, senza il segreto
  key revoke <id|nome>            toglie una chiave
  drive login [--client-id I --client-secret S]
                                  dà al server il permesso di scrivere su Drive
  drive folder <id|link>          sceglie la cartella di Drive della libreria
  drive status                    permesso e cartella
  status                          lavoro in corso, coda, ultimi esiti
  ping [--port P]                 esce con 0 se il server risponde (controllo di salute di Docker)

La cartella dei dati è --data, poi KAGAMI_DATA, poi ~/.local/share/kagami-server.''';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('data')
    ..addFlag('help', abbr: 'h', negatable: false);
  parser.addCommand('serve', ArgParser()..addOption('host')..addOption('port'));
  parser.addCommand(
    'key',
    ArgParser()
      ..addCommand('create', ArgParser()..addOption('url'))
      ..addCommand('list')
      ..addCommand('revoke'),
  );
  parser.addCommand(
    'drive',
    ArgParser()
      ..addCommand('login', ArgParser()..addOption('client-id')..addOption('client-secret'))
      ..addCommand('folder')
      ..addCommand('status'),
  );
  parser.addCommand('status');
  parser.addCommand('ping', ArgParser()..addOption('port'));

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (error) {
    fail('${error.message}\n\n$usage');
  }
  final command = args.command;
  if (args.flag('help') || command == null) {
    stdout.writeln(usage);
    return;
  }
  final paths = ServerPaths.resolve(args.option('data'));
  try {
    switch (command.name) {
      case 'serve':
        final port = command.option('port');
        await serve(paths, host: command.option('host'), port: port == null ? null : int.parse(port));
      case 'key':
        await keyCommand(paths, command.command);
      case 'drive':
        await driveCommand(paths, command.command);
      case 'status':
        await statusCommand(paths);
      case 'ping':
        await ping(paths, command.option('port'));
    }
  } on DriveNotAuthorized catch (error) {
    fail('$error');
  } on DriveException catch (error) {
    fail('Drive: $error');
  }
}

Never fail(String message) {
  stderr.writeln(message);
  exit(1);
}

String rest(ArgResults? command, String what) {
  final rest = command?.rest ?? const [];
  if (rest.length != 1) fail('Manca $what.\n\n$usage');
  return rest.single;
}

Future<void> keyCommand(ServerPaths paths, ArgResults? command) async {
  final keys = ApiKeys(paths.keys);
  switch (command?.name) {
    case 'create':
      final (key, secret) = await keys.create(rest(command, 'il nome della chiave'));
      stdout.writeln('Chiave «${key.name}» (${key.id}). Copiala adesso, non verrà più mostrata:\n\n  $secret\n');
      final url = command!.option('url');
      if (url != null) {
        stdout.writeln('Da incollare in Kagami → Scarica un manga → Server:\n\n  ${pairingLink(Uri.parse(url), secret)}\n');
      }
    case 'list':
      final all = await keys.list();
      if (all.isEmpty) stdout.writeln('Nessuna chiave.');
      for (final key in all) {
        stdout.writeln('${key.id}  ${key.name}  creata ${_day(key.createdAt)}'
            '${key.usedAt == null ? ', mai usata' : ', usata ${_day(key.usedAt!)}'}');
      }
    case 'revoke':
      final which = rest(command, 'l\'id o il nome della chiave');
      if (!await keys.revoke(which)) fail('Nessuna chiave «$which».');
      stdout.writeln('Chiave «$which» revocata: vale da subito, anche col server acceso.');
    default:
      fail(usage);
  }
}

String _day(DateTime at) => at.toLocal().toString().substring(0, 16);

Future<void> driveCommand(ServerPaths paths, ArgResults? command) async {
  var config = await ServerConfig.load(paths);
  switch (command?.name) {
    case 'login':
      final env = Platform.environment;
      final id = command!.option('client-id') ?? environment(env, 'KAGAMI_GOOGLE_CLIENT_ID') ?? config.clientId;
      final secret =
          command.option('client-secret') ?? environment(env, 'KAGAMI_GOOGLE_CLIENT_SECRET') ?? config.clientSecret;
      if (id == null || secret == null) {
        fail('Serve il client OAuth «Desktop» di Google: --client-id e --client-secret '
            '(o KAGAMI_GOOGLE_CLIENT_ID e KAGAMI_GOOGLE_CLIENT_SECRET). Come crearlo: docs/server.md.');
      }
      final client = GoogleClient(id, secret);
      final refresh = await loginFromTerminal(
        client,
        lines: stdin.transform(utf8.decoder).transform(const LineSplitter()),
        say: stdout.writeln,
      );
      config = config.copyWith(clientId: id, clientSecret: secret);
      await config.save(paths);
      await DriveTokens(paths.driveToken, client).save(refresh);
      stdout.writeln('Fatto: il server può scrivere su Drive.'
          '${config.folderId == null ? ' Ora scegli la cartella: kagami-server drive folder <link>.' : ''}');
    case 'folder':
      final drive = ServerDrive(paths, config);
      try {
        final item = await drive.choose(folderIdFrom(rest(command, 'la cartella (id o link)')));
        stdout.writeln('Cartella della libreria: «${item.name}» (${item.id}).');
      } finally {
        drive.client.close();
      }
    case 'status':
      final drive = ServerDrive(paths, config);
      final reason = await drive.blocked();
      stdout.writeln(reason ?? 'Pronto: cartella «${config.folderName}» (${config.folderId}).');
      drive.client.close();
    default:
      fail(usage);
  }
}

Future<void> statusCommand(ServerPaths paths) async {
  final files = paths.files;
  final status = await files.status();
  stdout.writeln('Stato: ${status.state.name}${status.title.isEmpty ? '' : ' · ${status.title}'}'
      '${status.total == 0 ? '' : ' · ${status.done}/${status.total} capitoli'}'
      '${status.message.isEmpty ? '' : '\n  ${status.message}'}');
  final queue = await files.jobs();
  stdout.writeln('In coda: ${queue.length}');
  for (final job in queue) {
    stdout.writeln('  ${job.id}  ${job.title.isEmpty ? job.url : job.title}');
  }
  for (final outcome in (await files.history()).take(5)) {
    stdout.writeln('${outcome.ok ? 'ok ' : 'err'} ${outcome.title}: ${outcome.message}');
  }
}

/// `GET /` sul server di questa macchina: l'unica risposta senza chiave.
Future<void> ping(ServerPaths paths, String? port) async {
  final config = (await ServerConfig.load(paths)).withEnvironment(Platform.environment);
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await http.getUrl(Uri.http('127.0.0.1:${port ?? config.port}', '/'));
    final response = await request.close().timeout(const Duration(seconds: 5));
    final body = await utf8.decodeStream(response);
    if (response.statusCode != 200 || !body.contains('kagami-server')) fail('Risposta inattesa.');
  } on Exception catch (error) {
    fail('Il server non risponde: $error');
  } finally {
    http.close(force: true);
  }
}
