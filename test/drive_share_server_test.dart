/// Le scadenze delle condivisioni passate al Kagami Server: quando si manda
/// l'elenco, quando no, e cosa succede con un server vecchio o spento.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/share_directory.dart';
import 'package:kagami/src/data/share_server.dart';
import 'package:kagami_archive/remote.dart';

void main() {
  late HttpServer server;
  late List<String> calls;
  late List<Object?> held;
  late List<String> features;

  setUp(() async {
    calls = [];
    held = [];
    features = ['shares'];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final text = await utf8.decodeStream(request);
      // Il saluto anonimo di ServerClient (F8.6) non è una chiamata delle condivisioni.
      if (request.uri.path != '/') calls.add('${request.method} ${request.uri.path}');
      Object body;
      if (!request.uri.path.contains('shares')) {
        body = {'service': 'kagami-server', 'name': 'x', 'version': '1', 'api': 2, 'features': features};
      } else {
        if (request.method == 'PUT') held = (jsonDecode(text) as Map)['shares'] as List;
        body = {'shares': held};
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  ServerClient client([int? port]) =>
      ServerClient(ServerLink(Uri.http('127.0.0.1:${port ?? server.port}')), (_, _, {bool refresh = false}) async => 'Bearer t');

  DriveShare row(String permission, DateTime? expiry, {String folder = 'F'}) => DriveShare(
        id: 'id$permission',
        to: 'a@b.it',
        from: 'c@d.it',
        folderId: folder,
        folderName: 'Manga',
        permissionId: permission,
        at: DateTime.utc(2026),
        expiresAt: expiry,
      );

  final soon = DateTime.utc(2027, 1, 1);

  test('manda solo le righe con un termine, e solo se il server è indietro', () async {
    final rows = [row('p1', soon), row('p2', null), row('', soon)];
    expect(await alignServerShares(client(), rows), isTrue);
    expect(held, [
      {'folderId': 'F', 'permissionId': 'p1', 'expiresAt': soon.toIso8601String()},
    ]);
    calls.clear();
    expect(await alignServerShares(client(), rows), isFalse);
    expect(calls, ['GET /v2/server', 'GET /v2/me/shares']);
  });

  test('un termine cambiato o una riga tolta riscrive l\'elenco, anche a vuoto', () async {
    await alignServerShares(client(), [row('p1', soon)]);
    expect(await alignServerShares(client(), [row('p1', soon.add(const Duration(days: 1)))]), isTrue);
    expect(await alignServerShares(client(), [row('p1', null)]), isTrue);
    expect(held, isEmpty);
  });

  test('un server senza la funzione non riceve niente', () async {
    features = [];
    expect(await alignServerShares(client(), [row('p1', soon)]), isFalse);
    expect(calls, ['GET /v2/server']);
  });

  test('un server che non risponde lascia l\'errore, non un elenco vuoto', () async {
    final port = server.port;
    await server.close(force: true);
    await expectLater(alignServerShares(client(port), [row('p1', soon)]), throwsA(isA<Object>()));
  });

  test('tiene le 200 più vicine e una sola volta per coppia', () {
    final rows = [
      for (var i = 0; i < 250; i++) row('p$i', soon.add(Duration(days: 250 - i))),
      row('p0', soon),
    ];
    final shares = serverSharesOf(rows);
    expect(shares, hasLength(200));
    expect(shares.first.permissionId, 'p0');
    expect(shares.first.expiresAt, soon);
  });
}
