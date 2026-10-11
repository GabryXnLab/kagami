// Cambiare provider: riconoscere la serie fra i risultati del provider nuovo,
// e abbinare i capitoli, che decidono quali letti, posizioni e capitoli da
// riscaricare la seguono.
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/site_switch.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart' show SearchResult;

ChapterEntry _entry(String id, {String? number, String? title}) => ChapterEntry(
      id: id,
      order: 0,
      archived: true,
      complete: true,
      pageCount: 1,
      bytes: 1,
      number: number,
      title: title,
    );

void main() {
  test('per numero, anche scritto in un altro modo', () {
    final matched = matchChapters([
      _entry('a1', number: '1'),
      _entry('a15', number: '1.50'),
      _entry('a2', title: 'Chapter 2 - The Arena'),
      _entry('a9', number: '9'),
    ], const [
      Chapter('1', 'Chapter 1', '1', 'u'),
      Chapter('15', 'Chapter 1.5', '1.5', 'u'),
      Chapter('2', 'Chapter 2', '2', 'u'),
    ]);
    expect(matched, {'a1': '1', 'a15': '15', 'a2': '2'});
  });

  test('senza numero per nome, e un numero ripetuto prende il primo', () {
    final matched = matchChapters([
      _entry('p', number: 'Prologue', title: 'Prologue'),
      _entry('e', title: 'Epilogue'),
      _entry('x'),
      _entry('a3', number: '3'),
    ], const [
      Chapter('pro', ' prologue ', 'Prologue', 'u'),
      Chapter('3a', 'Chapter 3', '3', 'u'),
      Chapter('3b', 'Chapter 3 (redraw)', '3', 'u'),
      Chapter('empty', '', '', 'u'),
    ]);
    expect(matched, {'p': 'pro', 'a3': '3a'});
  });

  group('la stessa serie fra i risultati', () {
    SearchResult result(String title) =>
        SearchResult(provider: 'coffeemanga', title: title, url: 'https://coffeemanga.net/manga/$title/');

    test('per titolo, a meno di maiuscole e punteggiatura', () {
      final results = [result('The House Without'), result('the house: WITHOUT time!')];
      expect(sameSeries(results, ['The House Without Time'])?.title, 'the house: WITHOUT time!');
    });

    test('anche per un titolo alternativo', () {
      expect(sameSeries([result('Shard of Time')], ['The House Without Time', 'Shard of Time'])?.title,
          'Shard of Time');
    });

    test('un titolo simile non basta, e uno vuoto non trova niente', () {
      expect(sameSeries([result('The House Without Time 2')], ['The House Without Time']), isNull);
      expect(sameSeries([result('!!!')], ['???']), isNull);
    });
  });
}
