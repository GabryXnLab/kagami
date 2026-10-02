/// L'aggiornatore contro un demone di Docker finto, sul suo socket unix.
library;

import 'dart:convert';
import 'dart:io';

import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String reference = 'ghcr.io/esempio/kagami-server:latest';

/// Quanto basta di Docker: contenitori, immagini, exec.
class FakeDocker {
  FakeDocker(this.server);

  final HttpServer server;
  final Map<String, Map<String, Object?>> containers = {};
  final Map<String, Map<String, Object?>> images = {};
  final List<String> calls = [];
  String latest = 'sha256:nuova';
  bool busy = false;
  int _next = 0;

  static Future<FakeDocker> start(String socket) async {
    final server = await HttpServer.bind(InternetAddress(socket, type: InternetAddressType.unix), 0);
    final docker = FakeDocker(server);
    server.listen(docker._handle);
    return docker;
  }

  Map<String, Object?>? find(String key) {
    for (final info in containers.values) {
      final id = info['Id'] as String;
      if (id == key || id.substring(0, 12) == key || info['Name'] == '/$key') return info;
    }
    return null;
  }

  String add(String name, String image, Map<String, Object?> config, Map<String, Object?> host) {
    final id = '${'${_next++}'.padLeft(12, 'c')}${'f' * 52}';
    containers[id] = {
      'Id': id,
      'Name': '/$name',
      'Image': image,
      'Config': config,
      'HostConfig': host,
      'Mounts': <Object?>[],
      'NetworkSettings': {'Networks': <String, Object?>{}},
      'State': {'Running': false},
    };
    return id;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final body = await utf8.decodeStream(request);
    calls.add('${request.method} $path');
    final response = request.response;
    Object? answer;
    final segments = request.uri.pathSegments;
    if (path == '/images/create') {
      images[reference] = {'Id': latest, 'Config': _imageConfig};
      answer = null;
      response.write('{"status":"Pulling"}\n{"status":"Downloaded"}\n');
    } else if (segments.first == 'images' && request.method == 'GET') {
      final name = segments.sublist(1, segments.length - 1).join('/');
      answer = images[name] ?? images.values.where((image) => image['Id'] == name).firstOrNull;
      if (answer == null) response.statusCode = 404;
    } else if (segments.first == 'images' && request.method == 'DELETE') {
      response.statusCode = 409;
    } else if (path == '/containers/create') {
      final config = jsonDecode(body) as Map<String, Object?>;
      final host = config.remove('HostConfig') as Map<String, Object?>;
      final image = images[config['Image']]!['Id'] as String;
      answer = {'Id': add(request.uri.queryParameters['name']!, image, config, host)};
    } else if (segments.first == 'containers') {
      final info = find(segments[1]);
      if (info == null) {
        response.statusCode = 404;
      } else if (request.method == 'DELETE') {
        containers.remove(info['Id']);
      } else {
        switch (segments.last) {
          case 'json':
            answer = info;
          case 'rename':
            info['Name'] = '/${request.uri.queryParameters['name']}';
          case 'start':
            (info['State'] as Map)['Running'] = true;
          case 'stop':
            (info['State'] as Map)['Running'] = false;
          case 'exec':
            answer = {'Id': 'e1'};
        }
      }
    } else if (path == '/exec/e1/start') {
      answer = null;
    } else if (path == '/exec/e1/json') {
      answer = {'Running': false, 'ExitCode': busy ? 1 : 0};
    }
    if (answer != null) response.write(jsonEncode(answer));
    await response.close();
  }

  static const Map<String, Object?> _imageConfig = {
    'Env': ['PATH=/usr/bin', 'KAGAMI_DATA=/data'],
    'Cmd': ['serve'],
    'Entrypoint': ['kagami-server'],
    'User': 'kagami',
    'Labels': {'org.opencontainers.image.revision': 'abc'},
  };
}

void main() {
  test('i nomi delle immagini', () {
    expect(splitReference('ghcr.io/a/b:latest'), ('ghcr.io/a/b', 'latest'));
    expect(splitReference('localhost:5000/b'), ('localhost:5000/b', 'latest'));
    expect(updatable('ghcr.io/a/b:latest'), isTrue);
    expect(updatable('kagami-server'), isFalse);
    expect(updatable('ghcr.io/a/b@sha256:1234'), isFalse);
  });

  test('il contenitore nuovo tiene ciò che ha scelto chi l\'ha avviato, non ciò che dava l\'immagine', () {
    final body = recreateBody(
      {
        'Id': 'abcdefabcdef0123',
        'Config': {
          'Hostname': 'abcdefabcdef',
          'Image': reference,
          'Env': ['PATH=/usr/bin', 'KAGAMI_DATA=/data', 'KAGAMI_SETUP=segreto', 'TZ=Europe/Rome'],
          'Cmd': ['serve'],
          'Entrypoint': ['kagami-server'],
          'User': 'kagami',
          'Labels': {'org.opencontainers.image.revision': 'abc', 'mia': 'sì'},
        },
        'HostConfig': {
          'Binds': ['kagami-data:/data'],
          'RestartPolicy': {'Name': 'unless-stopped'},
          'NetworkMode': 'casa',
        },
        'Mounts': [
          {'Type': 'volume', 'Name': 'kagami-data', 'Destination': '/data'},
          {'Type': 'volume', 'Name': 'anonimo', 'Destination': '/cache'},
        ],
        'NetworkSettings': {
          'Networks': {
            'casa': {'Aliases': ['abcdefabcdef', 'kagami']},
          },
        },
      },
      {'Config': FakeDocker._imageConfig},
      reference,
    );
    expect(body['Env'], ['KAGAMI_SETUP=segreto', 'TZ=Europe/Rome']);
    expect(body['Labels'], {'mia': 'sì'});
    expect(body.containsKey('Cmd'), isFalse);
    expect(body.containsKey('User'), isFalse);
    expect(body.containsKey('Hostname'), isFalse);
    expect((body['HostConfig'] as Map)['Binds'], ['kagami-data:/data', 'anonimo:/cache']);
    expect((body['HostConfig'] as Map)['RestartPolicy'], {'Name': 'unless-stopped'});
    expect(body['NetworkingConfig'], {
      'EndpointsConfig': {
        'casa': {'Aliases': ['kagami']},
      },
    });
  });

  group('il giro', () {
    late Directory temp;
    late FakeDocker fake;
    late DockerApi docker;
    late String updaterId;
    final said = <String>[];

    setUp(() async {
      said.clear();
      temp = await Directory.systemTemp.createTemp('kagami-docker');
      final socket = p.join(temp.path, 'docker.sock');
      fake = await FakeDocker.start(socket);
      docker = DockerApi(socket: socket);
      fake.images['sha256:vecchia'] = {'Id': 'sha256:vecchia', 'Config': FakeDocker._imageConfig};
      fake.add(
        'kagami-server',
        'sha256:vecchia',
        {
          'Image': reference,
          'Env': ['PATH=/usr/bin', 'KAGAMI_DATA=/data', 'KAGAMI_SETUP=segreto'],
          'Cmd': ['serve'],
        },
        {'Binds': ['kagami-data:/data'], 'PortBindings': {'8080/tcp': [{'HostPort': '8080'}]}},
      );
      updaterId = fake.add(
        'kagami-updater',
        'sha256:vecchia',
        {'Image': reference, 'Cmd': ['update'], 'User': '0'},
        {'Binds': ['$dockerSocket:$dockerSocket']},
      );
    });

    tearDown(() async {
      docker.close();
      await fake.server.close(force: true);
      await temp.delete(recursive: true);
    });

    Updater updater() => Updater(docker, self: updaterId.substring(0, 12), say: said.add);

    test('un\'immagine nuova ricrea il server con la sua configurazione, poi l\'aggiornatore', () async {
      await updater().check();
      final server = fake.find('kagami-server')!;
      expect(server['Image'], 'sha256:nuova');
      expect((server['Config'] as Map)['Env'], ['KAGAMI_SETUP=segreto']);
      expect((server['HostConfig'] as Map)['Binds'], ['kagami-data:/data']);
      expect((server['HostConfig'] as Map)['PortBindings'], {'8080/tcp': [{'HostPort': '8080'}]});
      expect((server['State'] as Map)['Running'], isTrue);
      expect(fake.find('kagami-server-old'), isNull);
      final helper = fake.containers.values.singleWhere((info) => (info['Name'] as String).startsWith('/kagami-updater-'));
      expect((helper['Config'] as Map)['Cmd'], ['update', '--apply', updaterId]);
      expect((helper['HostConfig'] as Map)['AutoRemove'], isTrue);

      // Il contenitore di passaggio rifà l'aggiornatore.
      await recreate(docker, updaterId);
      final again = fake.find('kagami-updater')!;
      expect(again['Image'], 'sha256:nuova');
      expect((again['Config'] as Map)['User'], '0');
    });

    test('mentre scarica si aspetta, oltre la pazienza no', () async {
      fake.busy = true;
      await updater().check();
      expect(fake.find('kagami-server')!['Image'], 'sha256:vecchia');
      expect(said.last, contains('aspetto'));
      await Updater(docker, self: updaterId.substring(0, 12), patience: Duration.zero, say: said.add).check();
      expect(fake.find('kagami-server')!['Image'], 'sha256:nuova');
    });

    test('con l\'immagine di sempre non si tocca niente', () async {
      fake.latest = 'sha256:vecchia';
      await updater().check();
      expect(fake.calls.where((call) => call.startsWith('POST /containers/create')), isEmpty);
    });
  });
}
