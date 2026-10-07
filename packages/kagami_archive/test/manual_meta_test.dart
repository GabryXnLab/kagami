import 'dart:convert';
import 'dart:typed_data';

import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/manual.dart';
import 'package:test/test.dart';

class _Page implements ProviderHttp {
  _Page(this.body, {this.type = 'text/html; charset=utf-8', this.fail = false});

  final String body;
  final String type;
  final bool fail;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (fail) throw const ProviderOffline();
    return (body: Uint8List.fromList(utf8.encode(body)), contentType: type);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async => false;

  @override
  Future<Map<String, Object?>> json(String url) async => const {};
}

void main() {
  test('og:title e og:image, con l\'immagine relativa risolta sul link', () {
    const page = '<html><head><title>Sito</title>'
        '<meta property="og:title" content="  Solo   Leveling "/>'
        '<meta property="og:image" content="/img/c.jpg"/></head></html>';
    final meta = parsePageMeta(page, 'https://example.org/serie/solo');
    expect(meta.title, 'Solo Leveling');
    expect(meta.image, 'https://example.org/img/c.jpg');
  });

  test('senza og:title ripiega su <title>, senza immagine resta null', () {
    final meta = parsePageMeta('<title>Una serie</title>', 'https://example.org/x');
    expect(meta.title, 'Una serie');
    expect(meta.image, isNull);
  });

  test('un guasto o una pagina non HTML danno una risposta vuota', () async {
    expect((await fetchPageMeta('https://example.org/x', http: _Page('', fail: true))).title, isNull);
    expect((await fetchPageMeta('https://example.org/x', http: _Page('{}', type: 'application/json'))).title, isNull);
    expect((await fetchPageMeta('non un link')).title, isNull);
  });

  test('legge titolo e copertina dalla pagina', () async {
    final meta = await fetchPageMeta(
      'https://example.org/x',
      http: _Page('<meta property="og:title" content="T"><meta property="og:image" content="https://cdn.org/i.png">'),
    );
    expect(meta, (title: 'T', image: 'https://cdn.org/i.png'));
  });
}
