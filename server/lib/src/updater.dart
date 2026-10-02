/// L'aggiornamento automatico del server con Docker.
///
/// Lo fa un secondo contenitore della stessa immagine, `kagami-updater`
/// (`kagami-server update`), che ha il socket di Docker e gira come root: il
/// server resta senza, perché chi ha il socket comanda la macchina, e il
/// server parla con internet. Ogni tanto l'aggiornatore scarica l'immagine
/// del server; se è cambiata, aspetta che il server non stia scaricando e
/// ricrea il contenitore con la stessa configurazione e l'immagine nuova —
/// volume, porte e `KAGAMI_SETUP` restano. Poi fa lo stesso con sé stesso,
/// da un contenitore di passaggio, perché un contenitore non può
/// sostituirsi mentre gira.
///
/// Niente Watchtower: è un progetto di altri, si è fermato, e con Docker 29
/// ha smesso di parlare con il demone. L'API di Docker che serve qui sono
/// sette chiamate.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Il socket di Docker, montato nel contenitore dell'aggiornatore.
const String dockerSocket = '/var/run/docker.sock';

class DockerError implements Exception {
  const DockerError(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'Docker ha risposto $status: $message';
}

/// L'API del demone di Docker sul suo socket. Senza prefisso di versione:
/// vale quella del demone, e Docker 29 rifiuta le versioni vecchie.
class DockerApi {
  DockerApi({String socket = dockerSocket})
      : _http = HttpClient()
          ..connectionFactory = ((uri, proxyHost, proxyPort) =>
              Socket.startConnect(InternetAddress(socket, type: InternetAddressType.unix), 0));

  final HttpClient _http;

  void close() => _http.close(force: true);

  Future<Object?> _call(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final request = await _http.openUrl(method, Uri.http('docker', path, query));
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close().timeout(timeout);
    final text = await utf8.decodeStream(response).timeout(timeout);
    if (response.statusCode >= 300 && response.statusCode != HttpStatus.notModified) {
      String message = text;
      try {
        message = (jsonDecode(text) as Map)['message'] as String? ?? text;
      } on Object {
        // Il corpo non è JSON: si tiene il testo.
      }
      throw DockerError(response.statusCode, message.trim());
    }
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  Future<Map<String, Object?>> container(String id) async =>
      (await _call('GET', '/containers/${Uri.encodeComponent(id)}/json')) as Map<String, Object?>;

  Future<Map<String, Object?>> image(String reference) async =>
      (await _call('GET', '/images/$reference/json')) as Map<String, Object?>;

  /// Scarica [reference] dal suo registro. La risposta è un flusso di righe
  /// JSON che può dire «errore» anche con un 200.
  Future<void> pull(String reference) async {
    final (repository, tag) = splitReference(reference);
    final answer = await _call(
      'POST',
      '/images/create',
      query: {'fromImage': repository, 'tag': tag},
      timeout: const Duration(minutes: 30),
    );
    final text = answer is String ? answer : jsonEncode(answer);
    for (final line in const LineSplitter().convert(text)) {
      final Object? event;
      try {
        event = jsonDecode(line);
      } on FormatException {
        continue;
      }
      if (event is Map && event['error'] != null) throw DockerError(500, '${event['error']}');
    }
  }

  Future<String> create(String name, Map<String, Object?> body) async =>
      ((await _call('POST', '/containers/create', query: {'name': name}, body: body)) as Map)['Id'] as String;

  Future<void> start(String id) => _call('POST', '/containers/$id/start');

  Future<void> stop(String id, {int seconds = 60}) =>
      _call('POST', '/containers/$id/stop', query: {'t': '$seconds'}, timeout: Duration(seconds: seconds + 30));

  Future<void> rename(String id, String name) => _call('POST', '/containers/$id/rename', query: {'name': name});

  Future<void> remove(String id) => _call('DELETE', '/containers/$id', query: {'force': 'true'});

  Future<void> removeImage(String id) => _call('DELETE', '/images/$id');

  /// Esegue [command] dentro [container] e torna il codice d'uscita.
  Future<int> exec(String container, List<String> command) async {
    final created = await _call('POST', '/containers/$container/exec', body: {'Cmd': command}) as Map;
    final id = created['Id'] as String;
    await _call('POST', '/exec/$id/start', body: {'Detach': true});
    for (var i = 0; i < 60; i++) {
      final state = await _call('GET', '/exec/$id/json') as Map;
      if (state['Running'] != true) return (state['ExitCode'] as num?)?.toInt() ?? 1;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw const DockerError(504, 'il comando nel contenitore non finisce');
  }
}

/// `ghcr.io/a/b:tag` in repository e tag; senza tag è `latest`.
(String, String) splitReference(String reference) {
  final slash = reference.lastIndexOf('/');
  final colon = reference.lastIndexOf(':');
  if (colon > slash) return (reference.substring(0, colon), reference.substring(colon + 1));
  return (reference, 'latest');
}

/// Si aggiorna solo un'immagine che viene da un registro e non è fissata a
/// un'impronta: una costruita in casa (`kagami-server`) non ha dove
/// scaricarsi, una con `@sha256:` l'ha fissata chi l'ha avviata.
bool updatable(String reference) => reference.contains('/') && !reference.contains('@');

/// Il corpo di `POST /containers/create` per rifare il contenitore [info]
/// con l'immagine [reference], dal contenitore com'era e dalla
/// configurazione della sua immagine vecchia [oldImage].
///
/// Ciò che il contenitore ha solo perché l'aveva l'immagine vecchia
/// (variabili come `PATH`, comando, controllo di salute, etichette) non si
/// copia: deve valere quello dell'immagine nuova.
Map<String, Object?> recreateBody(
  Map<String, Object?> info,
  Map<String, Object?> oldImage,
  String reference,
) {
  final config = Map<String, Object?>.of(info['Config'] as Map<String, Object?>);
  final inherited = oldImage['Config'] as Map<String, Object?>? ?? const {};
  final id = info['Id'] as String;
  config['Image'] = reference;
  if (config['Hostname'] == id.substring(0, 12)) config.remove('Hostname');
  final env = inherited['Env'] as List? ?? const [];
  config['Env'] = [for (final value in config['Env'] as List? ?? const []) if (!env.contains(value)) value];
  final labels = inherited['Labels'] as Map? ?? const {};
  config['Labels'] = {
    for (final MapEntry(:key, :value) in (config['Labels'] as Map? ?? const {}).entries)
      if (labels[key] != value) key: value,
  };
  for (final key in const [
    'Cmd',
    'Entrypoint',
    'Healthcheck',
    'WorkingDir',
    'User',
    'ExposedPorts',
    'Volumes',
    'StopSignal',
  ]) {
    if (jsonEncode(config[key]) == jsonEncode(inherited[key])) config.remove(key);
  }
  final host = Map<String, Object?>.of(info['HostConfig'] as Map<String, Object?>);
  // Un volume senza nome (la `VOLUME /data` dell'immagine, se chi l'ha
  // avviato non ha dato `-v`) va riattaccato per nome, o il contenitore
  // nuovo ne avrebbe uno vuoto.
  final binds = [...?(host['Binds'] as List?)?.cast<String>()];
  final mounted = {
    for (final bind in binds) bind.split(':').elementAtOrNull(1),
    for (final mount in (host['Mounts'] as List? ?? const []).whereType<Map>()) mount['Target'],
  };
  for (final mount in (info['Mounts'] as List? ?? const []).whereType<Map>()) {
    if (mount['Type'] == 'volume' && !mounted.contains(mount['Destination'])) {
      binds.add('${mount['Name']}:${mount['Destination']}');
    }
  }
  host['Binds'] = binds;
  final body = <String, Object?>{...config, 'HostConfig': host};
  final mode = host['NetworkMode'] as String? ?? 'default';
  final networks = (info['NetworkSettings'] as Map?)?['Networks'] as Map? ?? const {};
  final network = networks[mode];
  if (network is Map && !const {'default', 'bridge', 'host', 'none'}.contains(mode)) {
    body['NetworkingConfig'] = {
      'EndpointsConfig': {
        mode: {
          'Aliases': [
            for (final alias in network['Aliases'] as List? ?? const [])
              if (alias != id.substring(0, 12)) alias,
          ],
        },
      },
    };
  }
  return body;
}

/// Rifà il contenitore [container] con l'immagine che porta il suo nome, la
/// stessa configurazione e lo stesso nome. Se il nuovo non parte, rimette in
/// piedi il vecchio.
Future<void> recreate(DockerApi docker, String container, {void Function(String)? say}) async {
  final info = await docker.container(container);
  final id = info['Id'] as String;
  final name = (info['Name'] as String).replaceFirst('/', '');
  final reference = (info['Config'] as Map)['Image'] as String;
  final oldImage = info['Image'] as String;
  final body = recreateBody(info, await docker.image(oldImage), reference);
  // Un avanzo di un tentativo finito male terrebbe occupato il nome.
  await docker.remove('$name-old').catchError((Object _) {});
  await docker.rename(id, '$name-old');
  String? fresh;
  try {
    await docker.stop(id);
    fresh = await docker.create(name, body);
    await docker.start(fresh);
  } on Object {
    if (fresh != null) await docker.remove(fresh).catchError((Object _) {});
    await docker.rename(id, name);
    await docker.start(id);
    rethrow;
  }
  await docker.remove(id);
  say?.call('$name aggiornato.');
  // L'immagine vecchia resta finché la usa qualcun altro (l'aggiornatore
  // stesso, fino al suo turno): il demone rifiuta, e va bene così.
  await docker.removeImage(oldImage).catchError((Object _) {});
}

/// Il giro dell'aggiornatore: ogni [every] guarda se c'è un'immagine nuova.
class Updater {
  Updater(
    this.docker, {
    this.server = 'kagami-server',
    required this.self,
    this.patience = const Duration(hours: 6),
    void Function(String)? say,
  }) : say = say ?? stdout.writeln;

  final DockerApi docker;

  /// Il nome del contenitore del server.
  final String server;

  /// Questo contenitore: il suo id corto è il nome della macchina.
  final String self;

  /// Quanto si aspetta che il server finisca di scaricare. Un lavoro
  /// interrotto riprende da dove era, quindi oltre non vale la pena.
  final Duration patience;
  final void Function(String) say;

  DateTime? _waitingSince;

  Future<void> run(Duration every) async {
    say('Aggiornamento automatico di $server: un controllo ogni ${every.inMinutes} minuti.');
    while (true) {
      try {
        await check();
      } on Object catch (error) {
        say('Controllo dell\'aggiornamento non riuscito: $error');
      }
      await Future<void>.delayed(every);
    }
  }

  Future<void> check() async {
    final info = await docker.container(server);
    final reference = (info['Config'] as Map)['Image'] as String;
    if (!updatable(reference)) {
      say('$server usa «$reference», che non viene da un registro: niente da aggiornare.');
      return;
    }
    await docker.pull(reference);
    final latest = (await docker.image(reference))['Id'] as String;
    if (info['Image'] != latest) {
      if (!await _idle()) return;
      say('Immagine nuova per $server: lo ricreo.');
      await recreate(docker, server, say: say);
    }
    final me = await docker.container(self);
    if (me['Image'] != latest && (me['Config'] as Map)['Image'] == reference) {
      // Il contenitore di passaggio rifà questo, e poi se ne va da solo.
      say('Immagine nuova anche per l\'aggiornatore: mi ricreo.');
      final helper = await docker.create('kagami-updater-${DateTime.now().millisecondsSinceEpoch}', {
        'Image': reference,
        'User': '0',
        'Cmd': ['update', '--apply', me['Id'] as String],
        'Healthcheck': {'Test': ['NONE']},
        'HostConfig': {
          'Binds': ['$dockerSocket:$dockerSocket'],
          'AutoRemove': true,
        },
      });
      await docker.start(helper);
    }
  }

  /// Se il server non sta scaricando, o se lo si è aspettato abbastanza.
  Future<bool> _idle() async {
    final busy = await docker.exec(server, ['kagami-server', 'idle']) != 0;
    if (!busy) {
      _waitingSince = null;
      return true;
    }
    final since = _waitingSince ??= DateTime.now();
    if (DateTime.now().difference(since) >= patience) {
      _waitingSince = null;
      say('$server scarica da ${patience.inHours} ore: lo aggiorno lo stesso, il lavoro riprenderà da dove era.');
      return true;
    }
    say('Immagine nuova per $server: aspetto che finisca di scaricare.');
    return false;
  }
}
