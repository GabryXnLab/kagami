/// Il client di Drive contro un server vero, sul telefono stesso: le
/// interruzioni si provano solo con una connessione che si interrompe.
///
/// Sta in un file a parte perché il binding dei test dei widget sostituisce
/// `HttpClient` con uno che risponde sempre 400.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/network.dart';
import 'package:path/path.dart' as p;

import 'network_helpers.dart';

void main() {
  group('il client', () {
    late HttpServer server;
    late Directory temp;
    final ranges = <String?>[];
    late Future<void> Function(HttpRequest request) handle;

    setUp(() async {
      ranges.clear();
      temp = await Directory.systemTemp.createTemp('kagami-rete');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) => handle(request));
    });
    tearDown(() async {
      await server.close(force: true);
      await temp.delete(recursive: true);
    });

    DriveClient client(NetworkMonitor network, {Duration? stall, int? multipartLimit}) => DriveClient(
          ({refresh = false}) async => 'token',
          network: network,
          endpoint: (path, query) => Uri.http(
            '${server.address.address}:${server.port}',
            path,
            query,
          ),
          stall: stall ?? const Duration(seconds: 20),
          multipartLimit: multipartLimit ?? 5 * 1024 * 1024,
        );

    test('un file per id: com\'è fatto, o che non c\'è', () async {
      handle = (request) async {
        final id = request.uri.pathSegments.last;
        final response = request.response;
        if (id == 'C1') {
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode({
            'id': 'C1',
            'name': 'MangaArchive',
            'mimeType': 'application/vnd.google-apps.folder',
          }));
        } else {
          response.statusCode = HttpStatus.notFound;
        }
        await response.close();
      };
      final drive = client(monitor());
      final folder = await drive.file('C1');
      expect((folder.name, folder.folder), ('MangaArchive', true));
      await expectLater(
        drive.file('altro'),
        throwsA(isA<DriveException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('una tavola interrotta riprende dal byte dove si era fermata',
        () async {
      final bytes = List.generate(1000, (i) => i % 256);
      var first = true;
      handle = (request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        final response = request.response;
        if (first) {
          first = false;
          response.contentLength = bytes.length;
          final socket = await response.detachSocket(writeHeaders: true);
          socket.add(bytes.sublist(0, 400));
          await socket.flush();
          // La rete cade a metà tavola.
          socket.destroy();
          return;
        }
        final from = int.parse(range!.substring('bytes='.length, range.length - 1));
        response
          ..statusCode = HttpStatus.partialContent
          ..contentLength = bytes.length - from
          ..add(bytes.sublist(from));
        await response.close();
      };
      final drive = client(monitor());
      final target = File(p.join(temp.path, 'tavola.part'));
      await expectLater(
        drive.download('P1', target),
        throwsA(isA<DriveOffline>()),
      );
      expect(await target.length(), 400);
      await drive.download('P1', target);
      expect(await target.readAsBytes(), bytes);
      expect(ranges, [null, 'bytes=400-']);
      drive.close();
    });

    test('una connessione che non porta più niente si chiude', () async {
      handle = (request) async {
        request.response.contentLength = 100;
        final socket =
            await request.response.detachSocket(writeHeaders: true);
        socket.add(List.filled(10, 1));
        await socket.flush();
        // Dieci byte, poi niente: la connessione resta aperta e muta.
        await Future<void>.delayed(const Duration(seconds: 2));
        socket.destroy();
      };
      final drive = client(monitor(), stall: const Duration(milliseconds: 200));
      final target = File(p.join(temp.path, 'ferma.part'));
      final started = DateTime.now();
      await expectLater(
        drive.download('P1', target),
        throwsA(isA<DriveOffline>()),
      );
      expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 2)));
      expect(await target.length(), 10);
      drive.close();
    });

    test('senza rete non si prova nemmeno', () async {
      var requests = 0;
      handle = (request) async {
        requests++;
        await request.response.close();
      };
      final network = monitor(reachable: false);
      await (network as Switchable).goOffline();
      final drive = client(network);
      await expectLater(drive.children('R'), throwsA(isA<DriveOffline>()));
      expect(requests, 0);
      drive.close();
    });

    test('un file piccolo sale in una richiesta sola, metadati e byte insieme',
        () async {
      final seen = <String>[];
      List<int>? body;
      String? type;
      handle = (request) async {
        seen.add('${request.method} ${request.uri.path} ${request.uri.queryParameters['uploadType']}');
        type = request.headers.contentType?.mimeType;
        body = [for (final chunk in await request.toList()) ...chunk];
        request.response
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'id': 'NUOVO', 'name': '0001.webp', 'md5Checksum': 'abc'}));
        await request.response.close();
      };
      final bytes = List.generate(300, (i) => i % 256);
      final source = File(p.join(temp.path, 'tavola'));
      await source.writeAsBytes(bytes);
      final drive = client(monitor());
      final item = await drive.upload(source, name: '0001.webp', parentId: 'CARTELLA');
      expect(seen, ['POST /upload/drive/v3/files multipart']);
      expect(type, 'multipart/related');
      final text = latin1.decode(body!);
      expect(text, contains('"parents":["CARTELLA"]'));
      expect(text, contains(latin1.decode(bytes)));
      expect(item.id, 'NUOVO');
      drive.close();
    });

    test('Drive che rallenta si aspetta, poi si riprova', () async {
      var calls = 0;
      handle = (request) async {
        await request.drain<void>();
        if (calls++ == 0) {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..write('{"error":{"errors":[{"reason":"userRateLimitExceeded"}]}}');
        } else {
          request.response.write(jsonEncode({'id': 'F1', 'name': 'x'}));
        }
        await request.response.close();
      };
      final drive = client(monitor());
      expect((await drive.file('F1')).id, 'F1');
      expect(calls, 2);
      drive.close();
    });

    test('un caricamento apre la sessione e poi manda i byte a flusso',
        () async {
      final seen = <String>[];
      final received = <int>[];
      handle = (request) async {
        seen.add('${request.method} ${request.uri.path}');
        final response = request.response;
        if (request.uri.path == '/upload/drive/v3/files') {
          final metadata = jsonDecode(await utf8.decodeStream(request));
          expect(metadata['name'], '0001.webp');
          expect(metadata['parents'], ['CARTELLA']);
          expect(request.headers.value('X-Upload-Content-Length'), '300');
          response.headers.set(
            HttpHeaders.locationHeader,
            'http://${server.address.address}:${server.port}/sessione?upload_id=1',
          );
        } else {
          expect(request.uri.queryParameters['upload_id'], '1');
          await request.forEach(received.addAll);
          response.statusCode = HttpStatus.created;
          response.write(jsonEncode({
            'id': 'NUOVO',
            'name': '0001.webp',
            'size': '${received.length}',
            'md5Checksum': 'abc',
          }));
        }
        await response.close();
      };
      final source = File(p.join(temp.path, 'tavola'));
      await source.writeAsBytes(List.generate(300, (i) => i % 256));
      final drive = client(monitor(), multipartLimit: 0);
      final item = await drive.upload(
        source,
        name: '0001.webp',
        parentId: 'CARTELLA',
        modified: DateTime.utc(2026, 9, 1),
      );
      expect(seen, ['POST /upload/drive/v3/files', 'PUT /sessione']);
      expect(received, await source.readAsBytes());
      expect(item.id, 'NUOVO');
      expect(item.md5, 'abc');
      drive.close();
    });

    test('il cestino è un PATCH con trashed', () async {
      Object? body;
      handle = (request) async {
        expect(request.method, 'PATCH');
        expect(request.uri.path, '/drive/v3/files/F1');
        body = jsonDecode(await utf8.decodeStream(request));
        request.response.write(jsonEncode({'id': 'F1'}));
        await request.response.close();
      };
      final drive = client(monitor());
      await drive.trash('F1');
      expect(body, {'trashed': true});
      drive.close();
    });
  });

}
