/// Dove il server tiene i suoi file, e le impostazioni che vi legge.
///
/// Tutto sta in una cartella sola (`--data`, `KAGAMI_DATA`): con Docker è il
/// volume, e copiarla è spostare il server. Ogni utente ha la sua
/// sottocartella in `users/`, con coda, stato e serie in corso negli stessi
/// file del telefono (`ArchiveFiles` del pacchetto), così il giro è lo stesso
/// codice e l'API li legge senza tradurli.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/stores.dart';
import 'package:path/path.dart' as p;

const String serverVersion = '0.2.0';

/// La versione dell'API, quella del prefisso `/v2`.
const int apiVersion = 2;

class ServerPaths {
  ServerPaths(this.root);

  /// `--data`, poi `KAGAMI_DATA`, poi la cartella dei dati dell'utente.
  factory ServerPaths.resolve(String? data) {
    final env = Platform.environment;
    final chosen = data ?? env['KAGAMI_DATA'];
    if (chosen != null && chosen.isNotEmpty) return ServerPaths(Directory(chosen));
    final base = env['XDG_DATA_HOME'] ?? p.join(env['HOME'] ?? '.', '.local', 'share');
    return ServerPaths(Directory(p.join(base, 'kagami-server')));
  }

  final Directory root;

  File get config => File(p.join(root.path, 'config.json'));
  File get setup => File(p.join(root.path, 'setup.json'));
  File get users => File(p.join(root.path, 'users.json'));
  Directory get scratch => Directory(p.join(root.path, 'scratch'));

  /// Il profilo di Chromium: i cookie di una verifica passata valgono anche
  /// al controllo seguente.
  Directory get browser => Directory(p.join(root.path, 'browser'));

  /// La cartella di un utente: un'impronta dell'indirizzo, perché un
  /// indirizzo non è un nome di cartella valido ovunque.
  Directory user(String email) =>
      Directory(p.join(root.path, 'users', sha256.convert(utf8.encode(email)).toString().substring(0, 16)));
}

class ServerConfig {
  const ServerConfig({
    this.host = '0.0.0.0',
    this.port = 8080,
    this.name,
    this.checkMinutes = 4 * 60,
  });

  factory ServerConfig.fromJson(Map<String, Object?> json) {
    final check = json['check'] as Map? ?? const {};
    return ServerConfig(
      host: json['host'] as String? ?? '0.0.0.0',
      port: (json['port'] as num?)?.toInt() ?? 8080,
      name: json['name'] as String?,
      checkMinutes: check.containsKey('minutes') ? (check['minutes'] as num?)?.toInt() : 4 * 60,
    );
  }

  final String host;
  final int port;

  /// Il nome che l'app mostra per questo server, se chi lo installa ne
  /// vuole uno diverso da quello del comando di avvio.
  final String? name;

  /// L'ora del controllo delle serie in corso, in minuti dalla mezzanotte
  /// del server; `null` lo spegne.
  final int? checkMinutes;

  /// Le variabili d'ambiente vincono sul file: con Docker si passano così,
  /// fuori dal volume.
  ServerConfig withEnvironment(Map<String, String> env) => ServerConfig(
        host: environment(env, 'KAGAMI_HOST') ?? host,
        port: int.tryParse(environment(env, 'KAGAMI_PORT') ?? '') ?? port,
        name: environment(env, 'KAGAMI_NAME') ?? name,
        checkMinutes: checkMinutes,
      );

  static Future<ServerConfig> load(ServerPaths paths) async =>
      ServerConfig.fromJson(await readJsonFile(paths.config) ?? const {});
}

/// La configurazione applicata di `KAGAMI_SETUP`: di chi accettare i token e
/// con quale client rinnovare i permessi di Drive. Il permesso del
/// proprietario va nella sua cartella, come quello di tutti.
class AppliedSetup {
  const AppliedSetup({required this.project, required this.client, required this.owner, this.name, this.hash});

  factory AppliedSetup.fromJson(Map<String, Object?> json) {
    final client = json['client'] as Map;
    return AppliedSetup(
      project: json['project'] as String,
      client: GoogleClient(client['id'] as String, client['secret'] as String),
      owner: json['owner'] as String,
      name: json['name'] as String?,
      hash: json['hash'] as String?,
    );
  }

  final String project;
  final GoogleClient client;
  final String owner;
  final String? name;

  /// L'impronta del blob da cui viene: lo stesso comando rilanciato non
  /// riapplica un permesso vecchio sopra uno rinnovato.
  final String? hash;

  Map<String, Object?> toJson() => {
        'project': project,
        'client': {'id': client.id, 'secret': client.secret},
        'owner': owner,
        'name': ?name,
        'hash': ?hash,
      };

  static Future<AppliedSetup?> load(ServerPaths paths) async {
    final json = await readJsonFile(paths.setup);
    return json == null ? null : AppliedSetup.fromJson(json);
  }

  Future<void> save(ServerPaths paths) =>
      writeSecret(paths.setup, const JsonEncoder.withIndent('  ').convert(toJson()));
}

/// L'impronta di un blob di configurazione.
String setupHash(String blob) => sha256.convert(utf8.encode(blob.trim())).toString();

/// Una variabile d'ambiente, se ha un valore: il `docker-compose.yml` le
/// dichiara vuote, e una vuota vale come assente.
String? environment(Map<String, String> env, String name) {
  final value = env[name]?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// Scrive un file che solo l'utente del server può leggere: permessi di
/// Drive, client OAuth. Il permesso si dà prima di rinominarlo, così il file
/// non esiste mai leggibile da altri nemmeno per un istante.
Future<void> writeSecret(File file, String contents) async {
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.tmp');
  await temp.writeAsString('', flush: true);
  if (!Platform.isWindows) await Process.run('chmod', ['600', temp.path]);
  await temp.writeAsString(contents, flush: true);
  await temp.rename(file.path);
}
