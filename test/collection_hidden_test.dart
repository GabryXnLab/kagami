/// Raccolte nascoste: modello, provider e silenzio.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/arrivals.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';

import 'collection_auto_test.dart' show signals;

Collection row(String id, List<String> keys, {bool hidden = false, bool muted = false}) => Collection(
      id: id,
      name: id,
      seriesKeys: keys,
      traits: CollectionTraits(hidden: hidden, muted: muted),
    );

void main() {
  test('hidden: JSON andata e ritorno, in OR, dentro isEmpty', () {
    const traits = CollectionTraits(hidden: true);
    expect(traits.toJson(), {'hidden': true});
    expect(CollectionTraits.fromJson(traits.toJson()), traits);
    expect(CollectionTraits.fromJson(traits.toJson()).hashCode, traits.hashCode);
    expect(traits.isEmpty, isFalse);
    expect((const CollectionTraits(muted: true) | traits).hidden, isTrue);
    expect(traits.copyWith(hidden: false).isEmpty, isTrue);
    expect(CollectionTraits.fromJson(const {}).hidden, isFalse);
  });

  group('provider', () {
    final library = [signals('a'), signals('b'), signals('c')];

    ProviderContainer container(List<Collection> collections) {
      final c = ProviderContainer(overrides: [
        collectionsProvider.overrideWithValue(collections),
        librarySignalsProvider.overrideWithValue(library),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    List<String> keys(List<SeriesSignals> list) => [for (final s in list) s.entry.key]..sort();

    test('hiddenSeriesKeysProvider e shownSignalsProvider', () {
      final c = container([
        row('privata', ['a'], hidden: true),
        row('altra', ['b']),
      ]);
      expect(c.read(hiddenSeriesKeysProvider), {'a'});
      expect(keys(c.read(shownSignalsProvider)), ['b', 'c']);
      expect(keys(c.read(librarySignalsProvider)), ['a', 'b', 'c']);
    });

    test('visibleLibraryProvider: nessuna raccolta, nascosta aperta, '
        'non nascosta con una serie nascosta altrove', () {
      final c = container([
        row('privata', ['a', 'b'], hidden: true),
        row('pubblica', ['a', 'c']),
      ]);
      expect(keys(c.read(visibleLibraryProvider)), ['c']);
      c.read(libraryFilterProvider.notifier).showCollection('privata');
      expect(keys(c.read(visibleLibraryProvider)), ['a', 'b']);
      c.read(libraryFilterProvider.notifier).showCollection('pubblica');
      expect(keys(c.read(visibleLibraryProvider)), ['c']);
    });
  });

  test('le nascoste sono silenziate come le silenziate', () {
    final silenced = silencedSeriesKeys([
      row('privata', ['a'], hidden: true),
      row('muta', ['b'], muted: true),
      row('normale', ['c']),
    ]);
    expect(silenced, {'a', 'b'});

    // Una serie con capitoli nuovi già vista: annunciata solo se non è silenziata.
    final entry = signals('a').entry;
    final marks = {'a': const ArrivalMark(seen: 0, notified: 0)};
    const states = {'a': SeriesState(status: ShelfStatus.reading)};
    expect(planArrivals([entry], states, marks).alerts, isNotEmpty);
    expect(planArrivals([entry], states, marks, mutedKeys: silenced).alerts, isEmpty);
    final followed = signals('a', state: states['a']!);
    Map series(Set<String> muted) =>
        watchList('/radice', [followed], marks, mutedKeys: muted)['series'] as Map;
    expect(series(const {}).containsKey('a'), isTrue);
    expect(series(silenced).containsKey('a'), isFalse);
  });
}
