// La pagina della serie letta dal sito: il punto a cui si è arrivati, che
// precompila «Arrivato fino al…» e il capitolo da cui partire.
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/ui/archive_series.dart';
import 'package:kagami_archive/model.dart';

/// I capitoli come li dà il sito, dal più vecchio: 50, 51, 53, 53.5, 54 e
/// uno speciale senza numero.
final List<Chapter> chapters = [
  for (final number in ['50', '51', '53', '53.5', '54', ''])
    Chapter('c$number', 'Chapter $number', number, 'https://example.com/c$number'),
];

void main() {
  test('senza niente non si sa', () {
    expect(reachedChapterIndex(chapters), -1);
  });

  test('il capitolo del link vince su letti e numero dichiarato', () {
    expect(
      reachedChapterIndex(chapters, linkedId: 'c51', read: {'c53'}, reachedNumber: '54'),
      1,
    );
  });

  test('un link di un capitolo che la serie non elenca non conta', () {
    expect(reachedChapterIndex(chapters, linkedId: 'altro', read: {'c50', 'c53'}), 2);
  });

  test("i letti contano dall'ultimo, non dal primo che manca", () {
    expect(reachedChapterIndex(chapters, read: {'c50', 'c53.5'}, reachedNumber: '51'), 3);
  });

  test('il numero dichiarato si confronta per valore', () {
    expect(reachedChapterIndex(chapters, reachedNumber: '53.5'), 3);
    expect(reachedChapterIndex(chapters, reachedNumber: '53,5'), 3);
    expect(reachedChapterIndex(chapters, reachedNumber: '053'), 2);
  });

  test("un numero che il sito salta porta all'ultimo prima", () {
    expect(reachedChapterIndex(chapters, reachedNumber: '52'), 1);
    expect(reachedChapterIndex(chapters, reachedNumber: '49'), -1);
    expect(reachedChapterIndex(chapters, reachedNumber: '120'), 4);
  });

  test('un numero che non è un numero si cerca così com\'è', () {
    final named = [
      ...chapters,
      const Chapter('extra', 'Extra', 'Extra', 'https://example.com/extra'),
    ];
    expect(reachedChapterIndex(named, reachedNumber: 'Extra'), 6);
    expect(reachedChapterIndex(named, reachedNumber: 'Prologo'), -1);
  });

  group('man mano', () {
    test('da un capitolo di inizio segna letti i precedenti', () {
      expect(chapterBeforeAhead(chapters, {'c53', 'c53.5'})?.id, 'c51');
    });

    test('dal primo capitolo non segna niente', () {
      expect(chapterBeforeAhead(chapters, {'c50', 'c51'}), isNull);
    });

    test('già più avanti: non fa arretrare l\'arrivato a', () {
      expect(chapterBeforeAhead(chapters, {'c53'}, read: {'c51'}), isNull);
      expect(chapterBeforeAhead(chapters, {'c54'}, reachedNumber: '53.5'), isNull);
      expect(chapterBeforeAhead(chapters, {'c54'}, read: {'c50'})?.id, 'c53.5');
    });

    test('l\'inizio predefinito è il primo da leggere, anche dal solo numero dichiarato', () {
      expect(aheadStartId(chapters, read: {'c50', 'c51'}), 'c53');
      expect(aheadStartId(chapters, reachedNumber: '53'), 'c53.5');
      expect(aheadStartId(chapters), 'c50');
      expect(aheadStartId(chapters, read: {for (final c in chapters) c.id}), 'c50');
    });
  });
}
