import 'package:kagami_archive/model.dart';
import 'package:test/test.dart';

void main() {
  test('uno slug diventa un nome leggibile', () {
    expect(canonicalLabel('overpowered-male-lead'), 'Overpowered Male Lead');
    expect(canonicalLabel('slice-of-life'), 'Slice of Life');
    expect(canonicalLabel('  Strong   Female Lead '), 'Strong Female Lead');
    expect(canonicalLabel('Overpowered Male Lead'), 'Overpowered Male Lead');
  });

  test('i sinonimi si unificano', () {
    for (final v in ['Sci fi', 'Sci-fi', 'sci-fi', 'Science Fiction']) {
      expect(canonicalLabel(v), 'Sci-Fi');
    }
    expect(canonicalLabel('Shonen'), 'Shounen');
    expect(canonicalLabel('Full colour'), 'Full Color');
    expect(canonicalLabel('full-color'), 'Full Color');
  });

  test('il tipo: famiglia, minuscolo, dedotto dai generi', () {
    expect(canonicalType('Manhwa'), 'manhwa');
    expect(canonicalType('Webtoon'), 'manhwa');
    expect(canonicalType('Novel'), 'novel');
    expect(canonicalType(null, ['Action', 'Manhua']), 'manhua');
    expect(canonicalType('', ['Action']), isNull);
  });

  test('normalizeMetadata: tag in slug, doppioni, famiglia fra i generi', () {
    final m = normalizeMetadata({
      'type': 'manhwa',
      'genres': ['Action', 'sci fi'],
      'tags': ['overpowered-male-lead', 'action', 'Sci-Fi'],
    });
    expect(m['genres'], ['Action', 'Sci-Fi', 'Manhwa']);
    expect(m['tags'], ['Overpowered Male Lead']);
    expect(m['type'], 'manhwa');
  });

  test('senza type lo deduce dai generi; MangaK resta com\'è', () {
    final deduced = normalizeMetadata({'genres': ['Manhwa', 'Fantasy']});
    expect(deduced['type'], 'manhwa');
    expect(deduced['genres'], ['Manhwa', 'Fantasy']);
    final mangak = normalizeMetadata({
      'type': {'name': 'manhwa'},
      'genres': ['Action', 'Manhwa', 'Shounen'],
      'tags': ['Strong Female Lead'],
    });
    expect(mangak['genres'], ['Action', 'Manhwa', 'Shounen']);
    expect(mangak['tags'], ['Strong Female Lead']);
    expect(mangak['type'], 'manhwa');
  });
}
