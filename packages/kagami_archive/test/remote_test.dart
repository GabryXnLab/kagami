import 'package:kagami_archive/remote.dart';
import 'package:test/test.dart';

void main() {
  test('il link di abbinamento dà indirizzo e chiave, e nient\'altro lo è', () {
    final link = ServerLink.parsePairing(
      'kagami://server?url=https%3A%2F%2Fcasa.tail1234.ts.net%2F&key=kagami_abc',
    );
    expect(link?.url, Uri.parse('https://casa.tail1234.ts.net'));
    expect(link?.key, 'kagami_abc');
    expect(ServerLink.parsePairing('https://casa.tail1234.ts.net'), isNull);
    expect(ServerLink.parsePairing('kagami://server?url=https%3A%2F%2Fx'), isNull);
    expect(ServerLink.parsePairing('kagami://altro?url=x&key=y'), isNull);
  });

  test('l\'indirizzo scritto a mano si ripulisce', () {
    expect(normalizeServerUrl('192.168.1.20:8080'), Uri.parse('http://192.168.1.20:8080'));
    expect(normalizeServerUrl(' https://kagami.esempio.it/ '), Uri.parse('https://kagami.esempio.it'));
    expect(normalizeServerUrl('https://esempio.it/kagami/'), Uri.parse('https://esempio.it/kagami'));
    expect(normalizeServerUrl(''), isNull);
    expect(normalizeServerUrl('ftp://esempio.it'), isNull);
  });

  test('in chiaro va bene solo fra le proprie mura', () {
    bool private(String url) => isPrivateAddress(Uri.parse(url));
    for (final url in [
      'http://192.168.1.20:8080',
      'http://10.0.0.5',
      'http://172.20.1.1',
      'http://100.101.102.103:8080',
      'http://127.0.0.1:8080',
      'http://[fd7a:115c:a1e0::1]:8080',
      'http://nas:8080',
      'http://nas.local',
      'http://casa.tail1234.ts.net',
    ]) {
      expect(private(url), isTrue, reason: url);
    }
    for (final url in ['http://203.0.113.10:8080', 'http://kagami.esempio.it', 'http://172.32.0.1', 'http://100.128.0.1']) {
      expect(private(url), isFalse, reason: url);
    }
  });
}
