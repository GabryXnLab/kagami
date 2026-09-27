/// Dove il server tiene i suoi file, e le impostazioni che vi legge.
///
/// Tutto sta in una cartella sola (`--data`, `KAGAMI_DATA`): con Docker è il
/// volume, e copiarla è spostare il server. Coda, stato e serie in corso sono
/// gli stessi file del telefono (`ArchiveFiles` del pacchetto), così il giro
/// è lo stesso codice e l'API li legge senza tradurli.
library;

import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/stores.dart';
import 'package:path/path.dart' as p;

const String serverVersion = '0.1.0';

/// La versione dell'API, quella del prefisso `/v1`.
const int apiVersion = 1;

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
  File get keys => File(p.join(root.path, 'keys.json'));
  File get driveToken => File(p.join(root.path, 'drive-token.json'));
  Directory get scratch => Directory(p.join(root.path, 'scratch'));
  ArchiveFiles get files => ArchiveFiles(root.path);
}

class ServerConfig {
  const ServerConfig({
    this.host = '0.0.0.0',
    this.port = 8080,
    this.name = 'Kagami Server',
    this.clientId,
    this.clientSecret,
    this.folderId,
    this.folderName,
    this.checkMinutes = 4 * 60,
  });

  factory ServerConfig.fromJson(Map<String, Object?> json) {
    final google = json['google'] as Map? ?? const {};
    final drive = json['drive'] as Map? ?? const {};
    final check = json['check'] as Map? ?? const {};
    return ServerConfig(
      host: json['host'] as String? ?? '0.0.0.0',
      port: (json['port'] as num?)?.toInt() ?? 8080,
      name: json['name'] as String? ?? 'Kagami Server',
      clientId: google['clientId'] as String?,
      clientSecret: google['clientSecret'] as String?,
      folderId: drive['folderId'] as String?,
      folderName: drive['folderName'] as String?,
      checkMinutes: check.containsKey('minutes') ? (check['minutes'] as num?)?.toInt() : 4 * 60,
    );
  }

  final String host;
  final int port;

  /// Il nome che l'app mostra per questo server.
  final String name;

  /// Il client OAuth «Desktop» di chi fa girare il server: Kagami non ne
  /// distribuisce uno, perché lo scope completo di Drive per chiunque
  /// richiederebbe la verifica di Google (vedi `google.dart`).
  final String? clientId;
  final String? clientSecret;

  /// La cartella di Drive della libreria, dove finisce tutto.
  final String? folderId;
  final String? folderName;

  /// L'ora del controllo delle serie in corso, in minuti dalla mezzanotte
  /// del server; `null` lo spegne.
  final int? checkMinutes;

  /// Le variabili d'ambiente vincono sul file: con Docker il client OAuth
  /// si passa così, fuori dal volume.
  ServerConfig withEnvironment(Map<String, String> env) => ServerConfig(
        host: environment(env, 'KAGAMI_HOST') ?? host,
        port: int.tryParse(environment(env, 'KAGAMI_PORT') ?? '') ?? port,
        name: environment(env, 'KAGAMI_NAME') ?? name,
        clientId: environment(env, 'KAGAMI_GOOGLE_CLIENT_ID') ?? clientId,
        clientSecret: environment(env, 'KAGAMI_GOOGLE_CLIENT_SECRET') ?? clientSecret,
        folderId: folderId,
        folderName: folderName,
        checkMinutes: checkMinutes,
      );

  ServerConfig copyWith({
    String? clientId,
    String? clientSecret,
    String? folderId,
    String? folderName,
  }) =>
      ServerConfig(
        host: host,
        port: port,
        name: name,
        clientId: clientId ?? this.clientId,
        clientSecret: clientSecret ?? this.clientSecret,
        folderId: folderId ?? this.folderId,
        folderName: folderName ?? this.folderName,
        checkMinutes: checkMinutes,
      );

  Map<String, Object?> toJson() => {
        'host': host,
        'port': port,
        'name': name,
        if (clientId != null) 'google': {'clientId': clientId, 'clientSecret': ?clientSecret},
        if (folderId != null) 'drive': {'folderId': folderId, 'folderName': ?folderName},
        'check': {'minutes': checkMinutes},
      };

  static Future<ServerConfig> load(ServerPaths paths) async =>
      ServerConfig.fromJson(await readJsonFile(paths.config) ?? const {});

  /// Il file porta il segreto del client OAuth: si scrive come gli altri
  /// segreti.
  Future<void> save(ServerPaths paths) =>
      writeSecret(paths.config, const JsonEncoder.withIndent('  ').convert(toJson()));
}

/// Una variabile d'ambiente, se ha un valore: il `docker-compose.yml` le
/// dichiara vuote, e una vuota non deve cancellare ciò che `drive login` ha
/// salvato.
String? environment(Map<String, String> env, String name) {
  final value = env[name]?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// Scrive un file che solo l'utente del server può leggere: chiavi, token di
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
