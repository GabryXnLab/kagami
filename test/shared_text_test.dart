import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/share_intake.dart';

void main() {
  test('un link https condiviso è accettato', () {
    expect(sharedLinks('guarda https://example.com/manga/1').single.url, 'https://example.com/manga/1');
  });

  test('file:, content: e javascript: non diventano link', () {
    expect(sharedLinks('file:///etc/passwd content://x/y javascript:alert(1) intent://x#Intent;end'), isEmpty);
  });

  test('un testo troppo lungo non si legge', () {
    expect(sharedLinks('https://example.com/a ${'x' * sharedTextLimit}'), isEmpty);
  });

  test('un indirizzo troppo lungo è scartato, gli altri restano', () {
    final long = 'https://example.com/${'a' * sharedLinkLimit}';
    final items = sharedLinks('$long https://example.com/ok');
    expect(items.map((i) => i.url), ['https://example.com/ok']);
  });
}
