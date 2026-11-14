// Ingressi non fidati nel pacchetto (FASE-8, F8.4): percorsi degli indici di
// una libreria altrui, interprete dei siti degli utenti.
import 'dart:io';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/transport.dart';
import 'package:kagami_archive/webdav.dart';
import 'package:test/test.dart';

void main() {
  group('isIndexPath (T8)', () {
    test('ammette i percorsi relativi scritti dagli archiviatori', () {
      for (final path in [
        'Dungeon Odyssey [mangak-KY55w5Y9]',
        'cover.thumb.webp',
        'chapters/0001 - Chapter 1 [WYXxOj6Y]',
        'chapters/0001 - Chapter 1 [WYXxOj6Y]/0001.webp',
        '..hidden',
      ]) {
        expect(isIndexPath(path), isTrue, reason: path);
      }
    });

    test('rifiuta ciò che esce dalla cartella o nomina altro', () {
      for (final path in [
        '',
        '..',
        '.',
        '../evil',
        'a/../../b',
        'a/./b',
        'a//b',
        'a/',
        '/etc/passwd',
        r'..\..\evil',
        r'a\b',
        'C:/Windows',
        'C:evil',
        ':x',
        'content://x',
        'file:/data',
        'a\u0000b',
      ]) {
        expect(isIndexPath(path), isFalse, reason: path);
      }
    });
  });

  group('indici enormi (T9)', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await request.drain<void>();
        // Più del tetto, senza fine dichiarata: si ferma chi legge.
        for (var i = 0; i < 64; i++) {
          request.response.add(List.filled(1024, 0x41));
        }
        await request.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    test('WebDAV: text() oltre il tetto è un errore, non un file in memoria', () async {
      final webdav = WebDavTransport(Uri.parse('http://127.0.0.1:${server.port}/dav'), textLimit: 4096);
      addTearDown(webdav.close);
      await expectLater(webdav.text('library.json'), throwsA(isA<TransportException>()));
    });

    test('WebDAV: download() oltre il tetto si interrompe in corsa e non lascia il file', () async {
      final webdav = WebDavTransport(Uri.parse('http://127.0.0.1:${server.port}/dav'), downloadLimit: 4096);
      addTearDown(webdav.close);
      final dir = await Directory.systemTemp.createTemp('kagami_tetto');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/page.bin');
      await expectLater(webdav.download('page.bin', target), throwsA(isA<TransportException>()));
      expect(await target.exists(), isFalse);
    });

    test('Drive: text() oltre il tetto è un errore, non un file in memoria', () async {
      final drive = DriveClient(
        ({refresh = false}) async => 't',
        network: _Online(),
        endpoint: (path, query) => Uri.http('127.0.0.1:${server.port}', path, query),
        textLimit: 4096,
      );
      addTearDown(drive.close);
      await expectLater(drive.text('id'), throwsA(isA<DriveException>()));
    });
  });

  group('normalizeServerUrl (T16)', () {
    test('senza schema è https, tranne verso indirizzi privati', () {
      expect(normalizeServerUrl('kagami.esempio.it'), Uri.parse('https://kagami.esempio.it'));
      expect(normalizeServerUrl('203.0.113.5:8080'), Uri.parse('https://203.0.113.5:8080'));
      for (final host in ['192.168.1.20:8080', '10.0.0.2', '172.16.0.9', '127.0.0.1:8080', 'localhost:8080', 'nas.local', 'nas:8080']) {
        expect(normalizeServerUrl(host)?.scheme, 'http', reason: host);
      }
      expect(normalizeServerUrl('172.32.0.1')?.scheme, 'https');
    });

    test('uno schema scritto resta com\'è (l\'app avvisa se http è pubblico)', () {
      expect(normalizeServerUrl('http://esempio.it')?.scheme, 'http');
      expect(normalizeServerUrl('https://192.168.1.2')?.scheme, 'https');
    });
  });

  group('tetti del sito dichiarato (T11)', () {
    final site = DeclarativeProvider.fromJson({
      'format': 1,
      'id': 'examplescans',
      'name': 'Example Scans',
      'version': 1,
      'home': 'https://examplescans.com',
      'hosts': ['examplescans.com'],
      'mediaHosts': ['*.examplecdn.net'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'url': 'https://examplescans.com/manga/{id}',
        'title': 'h1',
        'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'img', 'url': {'attr': 'src'}},
      },
    });
    const url = 'https://examplescans.com/manga/x/';

    test('una risposta oltre il tetto è un errore dichiarato', () async {
      final http = _FakeHttp((_) async => (body: Uint8List(maxSiteResponseBytes + 1), contentType: 'text/html'));
      await expectLater(site.fetchSeries(url, http), throwsA(isA<ProviderError>()));
    });

    test('il client riceve il tetto come limite', () async {
      int? seen;
      final http = _FakeHttp((limit) async {
        seen = limit;
        return (body: Uint8List.fromList(utf8.encode('<h1>T</h1><li><a href="/manga/x/chapter-1/">C1</a></li>')), contentType: 'text/html');
      });
      await site.fetchSeries(url, http);
      expect(seen, maxSiteResponseBytes);
      expect(http.calls, 1);
    });

    test('un sito che non risponde più si interrompe allo scadere del tempo', () {
      fakeAsync((async) {
        final http = _FakeHttp((_) => Completer<HttpResult>().future);
        Object? error;
        site.fetchSeries(url, http).then<void>((_) {}, onError: (Object e) => error = e);
        async.elapse(maxSiteOperationTime + const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(error, isA<ProviderError>());
      });
    });
  });
}

class _Online implements NetworkState {
  @override
  bool get isOnline => true;

  @override
  void failed() {}

  @override
  void succeeded() {}

  @override
  Future<bool> check() async => true;
}

class _FakeHttp implements ProviderHttp {
  _FakeHttp(this.answer);

  final Future<HttpResult> Function(int limit) answer;
  int calls = 0;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) {
    calls++;
    return answer(limit);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => decodeJsonObject((await get(url)).body);
}
