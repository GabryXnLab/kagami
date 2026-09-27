// Il client dell'app contro l'API vera del server: il contratto di
// docs/server-api.md provato da tutt'e due i lati.
import 'dart:io';

import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  late ArchiveFiles files;
  late FakeJobs jobs;
  late FakeDrive drive;
  late ServerClient client;
  late Uri address;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kagami-client-');
    files = ArchiveFiles(dir.path);
    jobs = FakeJobs()..files = files;
    drive = FakeDrive();
    final keys = ApiKeys(File(p.join(dir.path, 'keys.json')));
    final (_, secret) = await keys.create('telefono');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(ServerApi(
      name: 'Casa',
      keys: keys,
      files: files,
      jobs: jobs,
      drive: drive,
      images: true,
      checkMinutes: 240,
      log: (_) {},
    ).handle);
    address = Uri.parse('http://127.0.0.1:${server.port}');
    client = ServerClient(ServerLink(address, secret));
  });
  tearDown(() async {
    client.close();
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  test('il server si presenta e riceve un lavoro, che poi si vede e si toglie', () async {
    final info = await client.info();
    expect(info.name, 'Casa');
    expect(info.ready, isTrue);
    expect(info.folderName, 'MangaArchive');
    expect(info.providers, containsAll(['mangak', 'manhwaread']));

    final job = await client.enqueue(url: 'https://mangak.io/x', title: 'X', ids: {'a', 'b'}, delayMs: 500);
    final queue = await client.queue();
    expect([for (final row in queue.jobs) row.id], [job.id]);
    expect(queue.status.state, ArchiveState.idle);
    expect((await files.jobs()).single.ids, {'a', 'b'});

    await client.cancel(job.id);
    expect((await client.queue()).jobs, isEmpty);
    await expectLater(client.cancel(job.id), throwsA(isA<ServerException>().having((e) => e.status, 'status', 404)));
  });

  test('gli errori dell\'API arrivano col loro codice e il loro messaggio', () async {
    await expectLater(
      client.enqueue(url: 'https://example.com/x'),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 'unsupported_url')),
    );
    drive.ready = false;
    await expectLater(
      client.enqueue(url: 'https://mangak.io/x'),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 'drive_not_ready')),
    );
  });

  test('chiave sbagliata, server spento, indirizzo di qualcos\'altro', () async {
    final wrong = ServerClient(ServerLink(address, 'kagami_falsa'));
    await expectLater(wrong.info(), throwsA(isA<ServerUnauthorized>()));
    wrong.close();

    final off = ServerClient(ServerLink(Uri.parse('http://127.0.0.1:1'), 'k'));
    await expectLater(off.info(), throwsA(isA<ServerOffline>()));
    off.close();

    final other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    other.listen((request) async {
      request.response.write('<html>un altro sito</html>');
      await request.response.close();
    });
    final elsewhere = ServerClient(ServerLink(Uri.parse('http://127.0.0.1:${other.port}'), 'k'));
    await expectLater(
      elsewhere.info(),
      throwsA(isA<ServerException>().having((e) => e.message, 'message', contains('Kagami Server'))),
    );
    elsewhere.close();
    await other.close(force: true);
  });

  test('serie in corso, controllo, cartella scelta dall\'app, storico', () async {
    await Tracking(files.ongoing).record(
      const Series(
        provider: 'mangak',
        id: 'S1',
        title: 'In corso',
        url: 'https://mangak.io/s1',
        coverUrl: null,
        metadata: {},
        chapters: [],
      ),
      const ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'f'),
      settled: const ['c1', 'c2'],
      metadata: const {'releaseStatus': 'ongoing'},
    );
    final series = (await client.ongoing()).single;
    expect((series.key, series.title, series.chapters), ('mangak:S1', 'In corso', 2));
    await client.forget(series.key);
    expect(await client.ongoing(), isEmpty);

    await client.check();
    expect(jobs.checks, 1);

    final folder = await client.chooseFolder('nuova');
    expect(folder, (id: 'nuova', name: 'Scelta'));

    await files.remember(ArchiveOutcome(title: 'Fatta', ok: true, message: 'ok', finishedAt: DateTime.now()));
    expect((await client.queue()).history.single.title, 'Fatta');
    await client.clearHistory();
    expect((await client.queue()).history, isEmpty);
  });
}
