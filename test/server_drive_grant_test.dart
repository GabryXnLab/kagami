/// Il permesso su tutto il Drive a un server: mai in chiaro su un indirizzo
/// pubblico, e a un server non proprio solo dopo la conferma.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/ui/archive_server.dart';
import 'package:kagami_archive/remote.dart';

void main() {
  late int sent;
  late int asked;
  Future<bool> send() async {
    sent++;
    return true;
  }

  Future<bool> guard(String url, {required bool own, bool answer = true}) => guardDriveGrant(
        url: Uri.parse(url),
        own: own,
        confirm: () async {
          asked++;
          return answer;
        },
        send: send,
      );

  setUp(() {
    sent = 0;
    asked = 0;
  });

  test('server non proprio: senza conferma non parte nulla', () async {
    expect(await guard('https://kagami.example.com', own: false, answer: false), isFalse);
    expect(asked, 1);
    expect(sent, 0);
  });

  test('server non proprio: con la conferma il permesso parte', () async {
    expect(await guard('https://kagami.example.com', own: false), isTrue);
    expect([asked, sent], [1, 1]);
  });

  test('server proprio: nessuna conferma, parte come prima', () async {
    expect(await guard('https://kagami.example.com', own: true), isTrue);
    expect([asked, sent], [0, 1]);
  });

  test('http su un indirizzo pubblico: rifiutato, anche se proprio e senza chiedere', () async {
    for (final own in [true, false]) {
      await expectLater(guard('http://8.8.8.8:8080', own: own), throwsA(isA<ServerException>()));
    }
    expect([asked, sent], [0, 0]);
  });

  test('http su un indirizzo privato: come prima', () async {
    expect(await guard('http://192.168.1.20:8080', own: true), isTrue);
    expect(await guard('http://127.0.0.1:8080', own: false), isTrue);
    expect([asked, sent], [1, 2]);
  });
}
