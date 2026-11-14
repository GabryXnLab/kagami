/// Raccolte vincolanti e famiglie di tipo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/format/kind.dart';
import 'package:kagami/src/format/reading.dart';

import 'collection_auto_test.dart' show collection, signals;

void main() {
  group('modello', () {
    test('binding: JSON andata e ritorno, solo se ci sono criteri', () {
      const rules = CollectionRules(types: {'manhwa'}, binding: true);
      expect(rules.toJson()['binding'], true);
      final back = CollectionRules.fromJson(rules.toJson());
      expect(back, rules);
      expect(back.isBinding, isTrue);
      expect(back.hashCode, rules.hashCode);

      const empty = CollectionRules(binding: true);
      expect(empty.isEmpty, isTrue);
      expect(empty.isBinding, isFalse);
      expect(empty.toJson().containsKey('binding'), isFalse);

      // Un backup vecchio, senza il campo, si legge non vincolante.
      expect(CollectionRules.fromJson({'types': ['manga']}).binding, isFalse);
      expect(rules.copyWith(binding: false).isBinding, isFalse);
      expect(rules == rules.copyWith(binding: false), isFalse);
    });

    test('kindOf', () {
      const cases = {
        'Manga': SeriesKind.manga,
        'Japanese Manga': SeriesKind.manga,
        'doujinshi': SeriesKind.manga,
        'Manhwa': SeriesKind.manhwa,
        'Webtoon': SeriesKind.manhwa,
        'KOREAN': SeriesKind.manhwa,
        ' man hwa ': SeriesKind.manhwa,
        'Manhua': SeriesKind.manhua,
        'chinese': SeriesKind.manhua,
        'Novel': SeriesKind.other,
        '': SeriesKind.other,
      };
      cases.forEach((type, kind) => expect(kindOf(type), kind, reason: type));
      expect(kindOf(null), SeriesKind.other);
    });

    test('i tipi delle regole combaciano per famiglia, gli altri per testo', () {
      const manhwa = CollectionRules(types: {'manhwa'});
      expect(collectionRulesMatch(manhwa, signals('a', type: 'Webtoon')), isTrue);
      expect(collectionRulesMatch(manhwa, signals('a', type: 'Manga')), isFalse);
      const other = CollectionRules(types: {'other'});
      expect(collectionRulesMatch(other, signals('a')), isTrue);
      expect(collectionRulesMatch(other, signals('a', type: 'Novel')), isTrue);
      expect(collectionRulesMatch(other, signals('a', type: 'manga')), isFalse);
      const novel = CollectionRules(types: {'novel'});
      expect(collectionRulesMatch(novel, signals('a', type: 'Novel')), isTrue);
      expect(collectionRulesMatch(novel, signals('a')), isFalse);
    });

    test('la vincolante toglie una manuale presente che non combacia, '
        'lascia un\'assente', () {
      final c = collection(
        rules: const CollectionRules(types: {'manhwa'}, binding: true),
        keys: ['manga-manuale', 'assente', 'manhwa-manuale'],
      );
      final out = syncAutoMembers(c, [
        signals('manga-manuale', type: 'Manga'),
        signals('manhwa-manuale', type: 'Manhwa'),
      ]);
      expect(out.seriesKeys, ['assente', 'manhwa-manuale']);
      expect(out.autoKeys, isEmpty);
      // Senza cambiamenti, la stessa istanza.
      expect(syncAutoMembers(out, [signals('manhwa-manuale', type: 'Manhwa')]),
          same(out));
    });

    test('non vincolante: le manuali restano', () {
      final c = collection(keys: ['manga-manuale']);
      final out = syncAutoMembers(c, [signals('manga-manuale', type: 'Manga')]);
      expect(out, same(c));
    });

    test('canJoin nei tre esiti', () {
      final free = collection();
      final bound = collection(
          rules: const CollectionRules(types: {'manhwa'}, binding: true));
      final manga = signals('a', type: 'Manga');
      expect(canJoin(free, manga), CollectionJoin.joined);
      expect(canJoin(bound, manga), CollectionJoin.refused);
      expect(canJoin(bound, signals('b', type: 'Manhwa')), CollectionJoin.joined);
      expect(canJoin(bound, null), CollectionJoin.pending);
    });
  });
}
