import 'dart:io';

import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kagami-keys-');
    file = File(p.join(dir.path, 'keys.json'));
  });
  tearDown(() => dir.delete(recursive: true));

  test('una chiave creata apre, una qualsiasi no, e sul disco c\'è solo l\'impronta', () async {
    final keys = ApiKeys(file);
    final (key, secret) = await keys.create('telefono');
    expect(secret, startsWith(keyPrefix));
    expect(secret.length, greaterThan(40));
    expect((await keys.verify(secret))?.id, key.id);
    expect(await keys.verify('${secret}x'), isNull);
    expect(await keys.verify(''), isNull);
    final stored = await file.readAsString();
    expect(stored, isNot(contains(secret)));
    expect(stored, contains(key.hash));
  });

  test('il file delle chiavi lo legge solo l\'utente del server', () async {
    await ApiKeys(file).create('telefono');
    final mode = (await file.stat()).mode & 0x1ff;
    expect(mode, 0x180, reason: 'permessi 0600, trovati ${mode.toRadixString(8)}');
  }, testOn: 'posix');

  test('revocata per nome o per id, e subito anche per un server già acceso', () async {
    final server = ApiKeys(file);
    final (a, secretA) = await server.create('telefono');
    final (_, secretB) = await server.create('tablet');
    expect(await server.verify(secretA), isNotNull);

    // Il comando `key revoke` è un altro processo: un altro oggetto sullo
    // stesso file.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await ApiKeys(file).revoke(a.id), isTrue);
    expect(await server.verify(secretA), isNull);
    expect(await server.verify(secretB), isNotNull);
    expect(await ApiKeys(file).revoke('tablet'), isTrue);
    expect(await server.verify(secretB), isNull);
    expect(await ApiKeys(file).revoke('nessuno'), isFalse);
  });

  test('l\'uso si annota', () async {
    final keys = ApiKeys(file);
    final (_, secret) = await keys.create('telefono');
    await keys.verify(secret);
    expect((await ApiKeys(file).list()).single.usedAt, isNotNull);
  });

  test('il link per l\'app porta indirizzo e chiave', () {
    final link = pairingLink(Uri.parse('https://casa.tail1234.ts.net'), 'kagami_abc');
    expect(link.scheme, 'kagami');
    expect(link.queryParameters, {'url': 'https://casa.tail1234.ts.net', 'key': 'kagami_abc'});
  });
}
