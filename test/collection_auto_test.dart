/// L'autoinserimento delle raccolte: funzione pura, senza libreria vera.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';

SeriesSignals signals(
  String key, {
  String? title,
  String? type,
  List<String> genres = const [],
  List<String> tags = const [],
  String provider = 'mangak',
  ReleaseStatus release = ReleaseStatus.ongoing,
  SeriesState state = const SeriesState(),
}) =>
    SeriesSignals.of(
      SeriesEntry(
        key: key,
        path: key,
        title: title ?? key,
        provider: provider,
        releaseStatus: release,
        chapterCount: 1,
        archivedChapterCount: 1,
        pageCount: 0,
        bytes: 0,
        signature: 'x',
        genres: genres,
        tags: tags,
        type: type,
      ),
      state,
    );

Collection collection({
  CollectionRules rules = const CollectionRules(types: {'manhwa'}),
  List<String> keys = const [],
  Set<String> auto = const {},
  Set<String> skipped = const {},
}) =>
    Collection(
      id: 'c',
      name: 'C',
      seriesKeys: keys,
      rules: rules,
      autoKeys: auto,
      skipped: skipped,
    );

void main() {
  test('aggiunge in coda per titolo e segna le automatiche', () {
    final c = collection(keys: ['manuale']);
    final out = syncAutoMembers(c, [
      signals('b', title: 'Beta', type: 'Manhwa'),
      signals('a', title: 'alfa', type: 'manhwa'),
      signals('x', type: 'manga'),
    ]);
    expect(out.seriesKeys, ['manuale', 'a', 'b']);
    expect(out.autoKeys, {'a', 'b'});
  });

  test('toglie solo le automatiche che non combaciano più', () {
    final c = collection(keys: ['m', 'a'], auto: {'a'});
    final out = syncAutoMembers(c, [
      signals('m', type: 'manga'),
      signals('a', type: 'manga'),
    ]);
    expect(out.seriesKeys, ['m']);
    expect(out.autoKeys, isEmpty);
  });

  test('una serie assente dalla libreria non viene tolta', () {
    final c = collection(keys: ['a'], auto: {'a'});
    final out = syncAutoMembers(c, [signals('altra', type: 'manga')]);
    expect(out, same(c));
  });

  test('le saltate non rientrano', () {
    final c = collection(skipped: {'a'});
    final out = syncAutoMembers(c, [signals('a', type: 'manhwa')]);
    expect(out, same(c));
  });

  test('una chiave già manuale non diventa automatica', () {
    final c = collection(keys: ['a']);
    expect(syncAutoMembers(c, [signals('a', type: 'manhwa')]), same(c));
  });

  test('senza cambiamenti restituisce la stessa istanza', () {
    final c = collection(keys: ['a'], auto: {'a'});
    expect(syncAutoMembers(c, [signals('a', type: 'manhwa')]), same(c));
  });

  test('regole vuote tolgono solo le automatiche', () {
    final c = collection(
      rules: const CollectionRules(),
      keys: ['m', 'a'],
      auto: {'a'},
    );
    final out = syncAutoMembers(c, [signals('m'), signals('a')]);
    expect(out.seriesKeys, ['m']);
    expect(out.autoKeys, isEmpty);
  });

  group('criteri', () {
    bool match(CollectionRules r, SeriesSignals s) => collectionRulesMatch(r, s);

    test('i tag vanno avuti tutti, in generi o tag, senza maiuscole', () {
      const r = CollectionRules(tags: {'azione', 'MAGIA'});
      expect(match(r, signals('a', genres: ['Azione'], tags: ['Magia'])), isTrue);
      expect(match(r, signals('a', genres: ['Azione'])), isFalse);
    });

    test('criteri diversi in AND, valori in OR', () {
      const r = CollectionRules(
        types: {'manga', 'manhwa'},
        release: {ReleaseStatus.completed},
        favorite: true,
        minRating: 7,
      );
      const fan = SeriesState(favorite: true, rating: 8);
      expect(
        match(r, signals('a', type: 'manhwa', release: ReleaseStatus.completed, state: fan)),
        isTrue,
      );
      expect(match(r, signals('a', type: 'manhwa', state: fan)), isFalse);
      expect(
        match(
          r,
          signals('a',
              type: 'manga',
              release: ReleaseStatus.completed,
              state: const SeriesState(favorite: true, rating: 5)),
        ),
        isFalse,
      );
    });

    test('stato sul ripiano e sito', () {
      const r = CollectionRules(
        shelf: {ShelfStatus.reading},
        providers: {'MangaK'},
      );
      expect(
        match(r, signals('a', state: const SeriesState(status: ShelfStatus.reading))),
        isTrue,
      );
      expect(match(r, signals('a')), isFalse);
    });
  });
}
