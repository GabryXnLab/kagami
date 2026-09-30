// Il client dell'app contro l'API vera del server: il contratto di
// docs/server-api.md provato da tutt'e due i lati. Il resto del server è
// finto (fakes.dart): qui conta la forma delle richieste e delle risposte.
import 'dart:io';

import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  const owner = 'owner@example.com';
  late TestServer server;
  late ArchiveFiles files;
  late FakeJobs jobs;
  late FakeDrive drive;
  late ServerClient client;
  late Uri address;

  ServerClient as(String email, {Uri? at}) =>
      ServerClient(ServerLink(at ?? address), ({bool refresh = false}) async => 'tok:$email');

  setUp(() async {
    server = await TestServer.start(owner: owner, name: 'Casa');
    final space = await server.ready(owner);
    files = space.files;
    jobs = space.jobs;
    drive = space.drive;
    address = server.address;
    client = as(owner);
  });
  tearDown(() async {
    client.close();
    await server.close();
  });

  test('il server si presenta e riceve un lavoro, che poi si vede e si toglie', () async {
    final info = await client.info();
    expect(info.name, 'Casa');
    expect(info.ready, isTrue);
    expect(info.isOwner, isTrue);
    expect(info.email, owner);
    expect(info.owner, owner);
    expect(info.folderName, 'Manga');
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

  test('token rifiutato, token scaduto, server spento, indirizzo di qualcos\'altro', () async {
    final wrong = ServerClient(ServerLink(address), ({bool refresh = false}) async => 'falso');
    await expectLater(wrong.info(), throwsA(isA<ServerUnauthorized>()));
    wrong.close();

    // Il primo token è scaduto: il client ne chiede uno nuovo e riprova.
    final asked = <bool>[];
    final stale = ServerClient(ServerLink(address), ({bool refresh = false}) async {
      asked.add(refresh);
      return refresh ? 'tok:$owner' : 'scaduto';
    });
    expect((await stale.info()).email, owner);
    expect(asked, [false, true]);
    stale.close();

    final off = as(owner, at: Uri.parse('http://127.0.0.1:1'));
    await expectLater(off.info(), throwsA(isA<ServerOffline>()));
    off.close();

    final other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    other.listen((request) async {
      request.response.write('<html>un altro sito</html>');
      await request.response.close();
    });
    final elsewhere = as(owner, at: Uri.parse('http://127.0.0.1:${other.port}'));
    await expectLater(
      elsewhere.info(),
      throwsA(isA<ServerException>().having((e) => e.message, 'message', contains('Kagami Server'))),
    );
    elsewhere.close();
    await other.close(force: true);
  });

  test('un server della v1 all\'indirizzo giusto va aggiornato, e lo si dice', () async {
    final old = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    old.listen((request) async {
      final root = request.uri.path == '/';
      request.response
        ..statusCode = root ? 200 : 404
        ..write(root ? '{"service":"kagami-server","api":1}' : '{"error":{"code":"not_found","message":"Indirizzo sconosciuto."}}');
      await request.response.close();
    });
    final client = as(owner, at: Uri.parse('http://127.0.0.1:${old.port}'));
    await expectLater(client.info(), throwsA(isA<ServerException>().having((e) => e.message, 'message', contains('API 1'))));
    client.close();
    await old.close(force: true);
  });

  test('un amico: fuori finché non è ammesso, poi dà il suo Drive e ha la sua coda', () async {
    const friend = 'amico@example.com';
    final his = as(friend);
    await expectLater(his.info(), throwsA(isA<ServerForbidden>().having((e) => e.code, 'code', 'not_allowed')));
    await expectLater(his.users(), throwsA(isA<ServerForbidden>()));

    final added = await client.addUser('Amico@Example.com');
    expect((added.email, added.owner, added.connected), (friend, false, false));
    final info = await his.info();
    expect((info.isOwner, info.ready), (false, false));
    await expectLater(his.users(), throwsA(isA<ServerForbidden>().having((e) => e.code, 'code', 'owner_only')));

    expect(await his.grantDrive('1//suo', 'sua-cartella'), (id: 'sua-cartella', name: 'Scelta'));
    expect((await his.info()).ready, isTrue);
    expect([for (final user in await client.users()) (user.email, user.owner, user.connected)], [
      (owner, true, true),
      (friend, false, true),
    ]);
    await his.enqueue(url: 'https://mangak.io/x');
    expect((await his.queue()).jobs, hasLength(1));
    expect((await client.queue()).jobs, isEmpty);

    await his.forgetDrive();
    expect((await his.info()).ready, isFalse);
    await client.removeUser(friend);
    await expectLater(his.info(), throwsA(isA<ServerForbidden>()));
    his.close();
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
    expect(drive.folderId, 'nuova');

    await files.remember(ArchiveOutcome(title: 'Fatta', ok: true, message: 'ok', finishedAt: DateTime.now()));
    expect((await client.queue()).history.single.title, 'Fatta');
    await client.clearHistory();
    expect((await client.queue()).history, isEmpty);
  });
}
