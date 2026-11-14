// Il controllo degli indirizzi privati di SiteHttp: i siti degli utenti non
// devono raggiungere la rete di chi li esegue, nemmeno con un nome pubblico.
import 'dart:io';

import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:test/test.dart';

void main() {
  InternetAddress ip(String text) => InternetAddress(text);

  group('isPrivateAddress', () {
    test('IPv4 privati e riservati', () {
      for (final text in [
        '127.0.0.1', '10.0.0.1', '172.16.0.1', '172.31.255.255', '192.168.1.1', '169.254.169.254',
        '100.64.0.1', '100.127.255.255', '0.0.0.0', '224.0.0.1', '240.0.0.1', '255.255.255.255',
      ]) {
        expect(isPrivateAddress(ip(text)), isTrue, reason: text);
      }
    });

    test('IPv4 pubblici', () {
      for (final text in ['8.8.8.8', '172.15.0.1', '172.32.0.1', '100.63.0.1', '100.128.0.1', '1.1.1.1']) {
        expect(isPrivateAddress(ip(text)), isFalse, reason: text);
      }
    });

    test('IPv6', () {
      for (final text in ['::1', '::', 'fc00::1', 'fd12:3456::1', 'fe80::1', 'ff02::1', '::ffff:10.0.0.1', '::ffff:127.0.0.1']) {
        expect(isPrivateAddress(ip(text)), isTrue, reason: text);
      }
      for (final text in ['2606:4700::1111', '::ffff:8.8.8.8']) {
        expect(isPrivateAddress(ip(text)), isFalse, reason: text);
      }
    });
  });

  group('SiteHttp con publicOnly', () {
    SiteHttp client(Map<String, List<String>> dns, {bool publicOnly = true, List<String>? asked}) => SiteHttp(
          (uri) => true,
          attempts: 1,
          publicOnly: publicOnly,
          lookup: (host) async {
            asked?.add(host);
            return [for (final text in dns[host] ?? const <String>[]) InternetAddress(text)];
          },
        );

    for (final entry in {'IPv4': '10.0.0.1', 'loopback IPv6': '::1', 'IPv4-mapped': '::ffff:192.168.0.5'}.entries) {
      test('rifiuta un host pubblico che risolve su ${entry.key}', () async {
        final http = client({'example.com': [entry.value]});
        await expectLater(
          http.get('https://example.com/'),
          throwsA(isA<ProviderError>().having((e) => e.message, 'message', contains('privato'))),
        );
        http.close();
      });
    }

    test('basta un indirizzo privato fra quelli risolti', () async {
      final http = client({'example.com': ['8.8.8.8', '10.0.0.1']});
      await expectLater(http.get('https://example.com/'), throwsA(isA<ProviderError>()));
      http.close();
    });

    test('il controllo sta nel giro dei salti, quindi vale per ogni host raggiunto', () async {
      // Un redirect vero non si prova senza un server https: qui si fissa che
      // ogni host chiesto da _open passa dalla risoluzione.
      final asked = <String>[];
      final http = client({'two.example.com': ['10.0.0.1']}, asked: asked);
      await expectLater(
        http.imageExists('https://two.example.com/a.png', referer: 'https://two.example.com/'),
        throwsA(isA<ProviderError>()),
      );
      expect(asked, ['two.example.com']);
      http.close();
    });

    test('un sito incluso (publicOnly spento) non risolve nulla', () async {
      final asked = <String>[];
      final http = client({'example.com': ['10.0.0.1']}, publicOnly: false, asked: asked);
      await http.get('https://example.com/').then<void>((_) {}, onError: (_) {});
      expect(asked, isEmpty);
      http.close();
    });
  });
}
