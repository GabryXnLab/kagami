import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;

const String usage = '''Kagami Server: scarica le serie al posto del telefono e le carica sul Drive di chi le chiede.

Uso: kagami-server [--data <cartella>] <comando>

  serve [--host H] [--port P] [--setup S]
                                  accende il server (default 0.0.0.0:8080); la configurazione
                                  è --setup o KAGAMI_SETUP, generata dall'app
  users                           gli account ammessi e chi ha già collegato il suo Drive
  status                          per ogni account: lavoro in corso, coda, ultimi esiti
  ping [--port P]                 esce con 0 se il server risponde (controllo di salute di Docker)
  idle                            esce con 0 se nessun account sta scaricando
  update [--every M] [--container C]
                                  l'aggiornatore: ogni M minuti (default 60) scarica l'immagine del
                                  contenitore C (default kagami-server) e, se è cambiata, lo ricrea;
                                  vuole il socket di Docker in /var/run/docker.sock

La cartella dei dati è --data, poi KAGAMI_DATA, poi ~/.local/share/kagami-server.
Gli account si aggiungono e si tolgono dall'app, nella sezione Server.''';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('data')
    ..addFlag('help', abbr: 'h', negatable: false);
  parser.addCommand('serve', ArgParser()..addOption('host')..addOption('port')..addOption('setup'));
  parser.addCommand('users');
  parser.addCommand('status');
  parser.addCommand('ping', ArgParser()..addOption('port'));
  parser.addCommand('idle');
  parser.addCommand(
    'update',
    ArgParser()
      ..addOption('every', defaultsTo: '60')
      ..addOption('container', defaultsTo: 'kagami-server')
      ..addOption('apply'),
  );

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
        await serve(
          paths,
          host: command.option('host'),
          port: port == null ? null : int.parse(port),
          setup: command.option('setup'),
        );
      case 'users':
        await usersCommand(paths);
      case 'status':
        await statusCommand(paths);
      case 'ping':
        await ping(paths, command.option('port'));
      case 'idle':
        await idleCommand(paths);
      case 'update':
        await updateCommand(command);
    }
  } on FormatException catch (error) {
    fail(error.message);
  }
}

Never fail(String message) {
  stderr.writeln(message);
  exit(1);
}

/// L'elenco letto dai file, senza accendere niente: vale anche col server
/// acceso in un altro processo.
Future<(AppliedSetup, List<Member>)> _members(ServerPaths paths) async {
  final setup = await AppliedSetup.load(paths);
  if (setup == null) fail('Il server non ha ancora una configurazione: avvialo col comando generato dall\'app.');
  final accounts = Accounts(paths.users, owner: setup.owner, open: (_) => throw UnsupportedError('solo lettura'));
  return (setup, await accounts.list());
}

Future<void> usersCommand(ServerPaths paths) async {
  final (_, members) = await _members(paths);
  for (final member in members) {
    final drive = await readJsonFile(File(p.join(paths.user(member.email).path, 'drive.json')));
    stdout.writeln('${member.email}${member.owner ? ' (proprietario)' : ''}'
        ' · ${drive?['refreshToken'] == null ? 'Drive non collegato' : 'Drive: ${drive?['folderName'] ?? drive?['folderId']}'}');
  }
}

Future<void> statusCommand(ServerPaths paths) async {
  final (_, members) = await _members(paths);
  for (final member in members) {
    stdout.writeln('== ${member.email}');
    await _status(ArchiveFiles(paths.user(member.email).path));
  }
}

Future<void> _status(ArchiveFiles files) async {
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

/// Per l'aggiornatore, che non ricrea il server a metà di un download.
Future<void> idleCommand(ServerPaths paths) async {
  final setup = await AppliedSetup.load(paths);
  if (setup == null) return;
  final accounts = Accounts(paths.users, owner: setup.owner, open: (_) => throw UnsupportedError('solo lettura'));
  for (final member in await accounts.list()) {
    final status = await ArchiveFiles(paths.user(member.email).path).status();
    if (status.state == ArchiveState.running) fail('${member.email} sta scaricando: ${status.title}');
  }
}

Future<void> updateCommand(ArgResults command) async {
  final docker = DockerApi();
  try {
    final apply = command.option('apply');
    if (apply != null) {
      await recreate(docker, apply, say: stdout.writeln);
      return;
    }
    final every = int.tryParse(command.option('every')!);
    if (every == null || every < 5) fail('--every vuole i minuti, almeno 5.');
    await Updater(docker, server: command.option('container')!, self: Platform.localHostname)
        .run(Duration(minutes: every));
  } finally {
    docker.close();
  }
}

/// `GET /` sul server di questa macchina: l'unica risposta senza token.
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
