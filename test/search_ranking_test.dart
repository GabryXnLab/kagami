import 'package:flutter_test/flutter_test.dart';
import 'package:kagami_archive/providers.dart' show SearchResult;
import 'package:kagami/src/archive/search_ranking.dart';

SearchResult r(String provider, String title) =>
    SearchResult(provider: provider, title: title, url: 'https://$provider/$title');

List<String> order(List<SearchResult> list) => [for (final x in list) '${x.provider}:${x.title}'];

void main() {
  test('lo stesso titolo su tre siti va in cima, raggruppato', () {
    final out = rankSearchResults('solo', [
      [r('a', 'Solo Leveling: Ragnarok'), r('a', 'Solo Leveling')],
      [r('b', 'Solo Leveling')],
      [r('c', 'Solo Leveling'), r('c', 'Solo Max-Level Newbie')],
    ]);
    expect(order(out).take(3), ['a:Solo Leveling', 'b:Solo Leveling', 'c:Solo Leveling']);
  });

  test('il titolo esatto batte uno che lo contiene', () {
    final out = rankSearchResults('solo leveling', [
      [r('a', 'Solo Leveling: Ragnarok')],
      [r('b', 'Solo Leveling')],
    ]);
    expect(order(out), ['b:Solo Leveling', 'a:Solo Leveling: Ragnarok']);
  });

  test('un risultato poco pertinente del primo sito scende sotto uno pertinente dell ultimo', () {
    final out = rankSearchResults('tower of god', [
      [r('a', 'Gods of Tower'), r('a', 'Another Story')],
      [],
      [r('c', 'Tower of God')],
    ]);
    expect(order(out), ['c:Tower of God', 'a:Gods of Tower', 'a:Another Story']);
  });
}
