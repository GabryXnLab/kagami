// Il trasporto WebDAV contro un server finto su loopback: i dialetti del
// multistatus, i percorsi che fanno andata e ritorno, gli esiti tradotti nei
// tre stati, la ripresa con Range e le credenziali che non escono dall'host.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/transport.dart';
import 'package:kagami_archive/webdav.dart';
import 'package:test/test.dart';

typedef _Call = ({String method, String path, Map<String, String> headers, String body});

void main() {
  late HttpServer server;
  late Directory temp;
  final calls = <_Call>[];
  late FutureOr<void> Function(HttpRequest request, _Call call) answer;

  setUp(() async {
    calls.clear();
    temp = await Directory.systemTemp.createTemp('webdav_test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      final headers = <String, String>{};
      request.headers.forEach((name, values) => headers[name] = values.join(','));
      final call = (method: request.method, path: request.uri.path, headers: headers, body: body);
      calls.add(call);
      await answer(request, call);
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await temp.delete(recursive: true);
  });

  String origin() => 'http://127.0.0.1:${server.port}';

  WebDavTransport transport({String root = '/dav/Manga', Duration answerTime = const Duration(seconds: 5)}) {
    final webdav = WebDavTransport(
      Uri.parse('${origin()}$root'),
      user: 'reader',
      password: 'segreto',
      answer: answerTime,
      stall: answerTime,
      retryDelay: const Duration(milliseconds: 1),
    );
    addTearDown(webdav.close);
    return webdav;
  }

  Future<void> reply(HttpRequest request, int status, [String body = '', Map<String, String> headers = const {}]) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
    headers.forEach(request.response.headers.set);
    request.response.write(body);
    await request.response.close();
  }

  const date = 'Wed, 04 Nov 2026 10:20:30 GMT';

  // Tre dialetti dello stesso elenco: la cartella stessa, una sottocartella
  // con spazi e #, un file con lettere giapponesi.
  String dialectD(String folder) => '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response><d:href>/dav/Manga/$folder/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>
  <d:response><d:href>/dav/Manga/$folder/One%20Piece%20%231/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:getlastmodified>$date</d:getlastmodified></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
    <d:propstat><d:prop><d:getcontentlength/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat>
  </d:response>
  <d:response><d:href>/dav/Manga/$folder/%E9%80%B2%E6%92%83.json</d:href>
    <d:propstat><d:prop><d:resourcetype/><d:getcontentlength>42</d:getcontentlength><d:getetag>"abc"</d:getetag></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>
</d:multistatus>''';

  String dialectApache(String folder) => '''<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:" xmlns:ns0="DAV:">
<D:response xmlns:lp1="DAV:">
<D:href>${origin()}/dav/Manga/$folder/</D:href>
<D:propstat><D:prop><lp1:resourcetype><D:collection/></lp1:resourcetype></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
</D:response>
<D:response xmlns:lp1="DAV:">
<D:href>${origin()}/dav/Manga/$folder/One%20Piece%20%231</D:href>
<D:propstat><D:prop><lp1:resourcetype><D:collection/></lp1:resourcetype><lp1:getlastmodified>$date</lp1:getlastmodified></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
</D:response>
<D:response xmlns:lp1="DAV:">
<D:href>${origin()}/dav/Manga/$folder/%e9%80%b2%e6%92%83.json</D:href>
<D:propstat><D:prop><lp1:resourcetype/><lp1:getcontentlength>42</lp1:getcontentlength><lp1:getetag>"abc"</lp1:getetag></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
</D:response>
</D:multistatus>''';

  // Namespace di default e href non codificati.
  String dialectDefault(String folder) => '''<?xml version="1.0"?>
<multistatus xmlns="DAV:">
  <response><href>/dav/Manga/$folder</href>
    <propstat><prop><resourcetype><collection/></resourcetype></prop><status>HTTP/1.1 200 OK</status></propstat></response>
  <response><href>/dav/Manga/$folder/One Piece #1/</href>
    <propstat><prop><resourcetype><collection/></resourcetype><getlastmodified>$date</getlastmodified></prop><status>HTTP/1.1 200 OK</status></propstat></response>
  <response><href>/dav/Manga/$folder/進撃.json</href>
    <propstat><prop><resourcetype/><getcontentlength>42</getcontentlength><getetag>"abc"</getetag></prop><status>HTTP/1.1 200 OK</status></propstat></response>
</multistatus>''';

  for (final (name, dialect) in [('d:', dialectD), ('D: e lp1:', dialectApache), ('namespace di default', dialectDefault)]) {
    test('list legge il multistatus con $name', () async {
      answer = (request, call) => reply(request, 207, dialect('Serie A'));
      final entries = await transport().list('Serie A');
      expect(calls.single.method, 'PROPFIND');
      expect(calls.single.path, '/dav/Manga/Serie%20A/');
      expect(calls.single.headers['depth'], '1');
      expect(calls.single.body, allOf(contains('resourcetype'), contains('getcontentlength'), contains('getlastmodified'), contains('getetag')));
      expect(calls.single.headers['authorization'], 'Basic ${base64.encode(utf8.encode('reader:segreto'))}');

      expect(entries.map((entry) => entry.path), ['Serie A/One Piece #1', 'Serie A/進撃.json']);
      final folder = entries.first;
      expect((folder.name, folder.folder, folder.size), ('One Piece #1', true, null));
      expect(folder.modified, DateTime.utc(2026, 11, 4, 10, 20, 30));
      final file = entries.last;
      expect((file.name, file.folder, file.size, file.etag), ('進撃.json', false, 42, '"abc"'));
    });
  }

  test('i percorsi elencati fanno andata e ritorno', () async {
    answer = (request, call) => call.method == 'PROPFIND'
        ? reply(request, 207, dialectD('Serie A'))
        : reply(request, 200, '{}');
    final webdav = transport();
    final entries = await webdav.list('Serie A');
    await webdav.text(entries.last.path);
    await webdav.list(entries.first.path);
    expect(calls[1].path, '/dav/Manga/Serie%20A/%E9%80%B2%E6%92%83.json');
    expect(calls[2].path, '/dav/Manga/Serie%20A/One%20Piece%20%231/');
    expect(Uri.decodeComponent(calls[2].path.split('/')[4]), 'One Piece #1');
  });

  test('il percento in un nome si codifica', () async {
    answer = (request, call) => reply(request, 200, 'ok');
    expect(await transport().text('100% Manga/a.json'), 'ok');
    expect(calls.single.path, '/dav/Manga/100%25%20Manga/a.json');
  });

  test('stat: voce, null su 404, eccezione su 500', () async {
    answer = (request, call) => reply(request, 207, '''<d:multistatus xmlns:d="DAV:"><d:response>
<d:href>/dav/Manga/library.json</d:href><d:propstat><d:prop><d:resourcetype/><d:getcontentlength>7</d:getcontentlength><d:getetag>W/"x"</d:getetag></d:prop>
<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>''');
    final webdav = transport();
    final entry = await webdav.stat('library.json');
    expect((entry!.path, entry.size, entry.etag, entry.folder), ('library.json', 7, 'W/"x"', false));
    expect(calls.single.headers['depth'], '0');

    answer = (request, call) => reply(request, 404);
    expect(await webdav.stat('library.json'), isNull);

    calls.clear();
    answer = (request, call) => reply(request, 500);
    await expectLater(webdav.stat('library.json'),
        throwsA(isA<TransportException>().having((e) => e.status, 'status', 500)));
    expect(calls.length, greaterThan(1), reason: 'un 5xx si riprova');
  });

  test('list di una cartella che non c’è', () async {
    answer = (request, call) => reply(request, 404);
    await expectLater(transport().list('Nessuna'), throwsA(isA<TransportNotFound>()));
  });

  test('401 e 403 chiedono le credenziali', () async {
    answer = (request, call) => reply(request, 401);
    await expectLater(transport().list(''), throwsA(isA<TransportAuthRequired>()));
    answer = (request, call) => reply(request, 403);
    await expectLater(transport().text('a.json'), throwsA(isA<TransportAuthRequired>()));
  });

  group('download', () {
    const content = '0123456789';

    test('riprende con Range e 206', () async {
      answer = (request, call) {
        final from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(call.headers['range']!)![1]!);
        return reply(request, 206, content.substring(from), {'content-range': 'bytes $from-9/10'});
      };
      final target = File('${temp.path}/a.part')..writeAsStringSync('0123xx');
      await transport().download('Serie A/001.webp', target, resumeFrom: 4);
      expect(calls.single.headers['range'], 'bytes=4-');
      expect(target.readAsStringSync(), content);
    });

    test('200 al posto di 206 riscrive da capo', () async {
      answer = (request, call) => reply(request, 200, content);
      final target = File('${temp.path}/a.part')..writeAsStringSync('0123');
      await transport().download('a.webp', target, resumeFrom: 4);
      expect(target.readAsStringSync(), content);
    });

    test('416 cancella il pezzo e riparte da zero', () async {
      answer = (request, call) =>
          call.headers.containsKey('range') ? reply(request, 416) : reply(request, 200, content);
      final target = File('${temp.path}/a.part')..writeAsStringSync('vecchio contenuto');
      await transport().download('a.webp', target, resumeFrom: 5);
      expect(calls.map((call) => call.headers['range']), ['bytes=5-', null]);
      expect(target.readAsStringSync(), content);
    });

    test('un errore lascia target com’era', () async {
      answer = (request, call) => reply(request, 404);
      final target = File('${temp.path}/a.part')..writeAsStringSync('0123');
      await expectLater(transport().download('a.webp', target, resumeFrom: 4), throwsA(isA<TransportNotFound>()));
      expect(target.readAsStringSync(), '0123');
    });
  });

  test('un reindirizzamento verso lo stesso host si segue', () async {
    answer = (request, call) => call.path == '/dav/Manga/old.json'
        ? reply(request, 301, '', {'location': '/dav/Manga/new.json'})
        : reply(request, 200, 'nuovo');
    expect(await transport().text('old.json'), 'nuovo');
    expect(calls.map((call) => call.path), ['/dav/Manga/old.json', '/dav/Manga/new.json']);
    expect(calls.last.headers['authorization'], startsWith('Basic '));
  });

  test('un reindirizzamento verso un altro host si rifiuta senza credenziali', () async {
    final other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final stolen = <String?>[];
    other.listen((request) async {
      stolen.add(request.headers.value('authorization'));
      await request.response.close();
    });
    addTearDown(() => other.close(force: true));
    answer = (request, call) => reply(request, 302, '', {'location': 'http://localhost:${other.port}/dav/Manga/a.json'});
    await expectLater(transport().text('a.json'), throwsA(isA<TransportException>().having((e) => e.status, 'status', 302)));
    expect(stolen, isEmpty);
  });

  test('un server che non risponde è TransportOffline entro il tempo massimo', () async {
    final hanging = <HttpRequest>[];
    answer = (request, call) => hanging.add(request);
    final watch = Stopwatch()..start();
    await expectLater(transport(answerTime: const Duration(milliseconds: 300)).list(''), throwsA(isA<TransportOffline>()));
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('un host spento è TransportOffline', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final webdav = WebDavTransport(Uri.parse('http://127.0.0.1:$port/'), answer: const Duration(seconds: 2));
    addTearDown(webdav.close);
    await expectLater(webdav.stat('a'), throwsA(isA<TransportOffline>()));
  });

  test('percorsi non validi si fermano prima della rete', () async {
    answer = (request, call) => reply(request, 200);
    final webdav = transport();
    for (final path in ['../etc', 'a/../b', '/a', 'a//b', 'a/']) {
      await expectLater(webdav.text(path), throwsArgumentError, reason: path);
    }
    expect(calls, isEmpty);
  });

  test('indirizzi: https sempre, http solo verso la rete di casa', () {
    expect(webDavAddress('https://nas.example.com/dav/').toString(), 'https://nas.example.com/dav');
    for (final text in ['http://192.168.1.5:5005/dav', 'http://nas.local/dav', 'http://nas/dav', 'http://[fd00::1]/']) {
      expect(webDavAddress(text).scheme, 'http', reason: text);
    }
    for (final text in [
      'http://nas.example.com/dav', 'http://8.8.8.8/', 'ftp://nas.example.com/', 'https://user:pw@nas.example.com/',
      'https://nas.example.com/?a=1', 'nas.example.com',
    ]) {
      expect(() => webDavAddress(text), throwsFormatException, reason: text);
    }
    expect(() => WebDavTransport(Uri.parse('http://nas.example.com/')), throwsFormatException);
  });
}
