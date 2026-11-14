// La scadenza degli accessi vista dal client (`expiry`, docs/server-api.md):
// RemoteArchive contro l'API vera, con l'orologio finto.
import 'package:kagami_archive/remote.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  const owner = 'owner@example.com';
  const friend = 'amico@example.com';
  late TestServer server;
  late DateTime clock;
  late ServerClient boss;
  late ServerClient his;

  ServerClient as(String email) =>
      ServerClient(ServerLink(server.address), (_, _, {bool refresh = false}) async => 'Bearer tok:$email');

  setUp(() async {
    clock = DateTime.utc(2026, 11, 13, 12);
    server = await TestServer.start(owner: owner, now: () => clock);
    await server.ready(owner);
    boss = as(owner);
    his = as(friend);
  });
  tearDown(() async {
    boss.close();
    his.close();
    await server.close();
  });

  test('addUser con scadenza, info la dice; scaduto, il server lo toglie e il rinnovo non lo trova', () async {
    final until = clock.add(const Duration(days: 7));
    final added = await boss.addUser(friend, expiresAt: until);
    expect((added.expiresAt, added.expired), (until, false));
    await server.ready(friend);

    final info = await his.info();
    expect(info.features, contains('expiry'));
    expect((info.expiresAt, info.expired), (until, false));
    await his.queue();

    final next = clock.add(const Duration(days: 3));
    expect((await boss.renewUser(friend, next)).expiresAt, next);

    clock = next.add(const Duration(hours: 1));
    await expectLater(his.queue(), throwsA(isA<ServerForbidden>().having((e) => e.code, 'code', 'not_allowed')));
    expect((await boss.users()).any((u) => u.email == friend), isFalse);
    await expectLater(boss.renewUser(friend, null), throwsA(isA<ServerException>()));
  });

  test('senza expiresAt l\'utente non scade', () async {
    final added = await boss.addUser(friend);
    expect((added.expiresAt, added.expired), (null, false));
  });
}
