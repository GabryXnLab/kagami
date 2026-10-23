/// Il foglio delle proprietà di una raccolta: le scelte tornano come regole e
/// caratteristiche, e i tipi vengono dalla libreria.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami/src/ui/widgets/collection_properties_sheet.dart';

SeriesEntry entry(String key, {String? type, String provider = 'mangak', List<String> tags = const []}) =>
    SeriesEntry(
      key: key,
      path: key,
      title: key,
      provider: provider,
      releaseStatus: ReleaseStatus.ongoing,
      chapterCount: 1,
      archivedChapterCount: 1,
      pageCount: 0,
      bytes: 0,
      signature: 'x',
      type: type,
      genres: const ['Azione'],
      tags: tags,
    );

void main() {
  test('LibraryFacets.types: i type presenti, senza doppioni e senza vuoti', () {
    final facets = LibraryFacets.of([
      entry('a', type: 'Manhwa'),
      entry('b', type: 'manhwa', provider: 'altro'),
      entry('c', type: ' Manga '),
      entry('d'),
      entry('e', type: ''),
    ]);
    expect(facets.types, ['manga', 'manhwa']);
    expect(facets.providers, ['altro', 'mangak']);
  });

  testWidgets('le scelte tornano come regole e caratteristiche', (tester) async {
    CollectionProperties? result;
    final facets = LibraryFacets.of([
      entry('a', type: 'manhwa', tags: ['Magia']),
      entry('b', type: 'manga'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        theme: kagamiTheme(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<CollectionProperties>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CollectionPropertiesForm(
                    facets: facets,
                    rules: const CollectionRules(),
                    traits: const CollectionTraits(),
                  ),
                );
              },
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    Future<void> tap(String text) async {
      final finder = find.text(text).first;
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap('manhwa');
    await tap('Magia');
    await tap('In lettura');
    await tap('8');
    await tap('Solo preferiti');
    await tap('Silenzia le novità');
    await tap('Non chiedere il voto');
    await tap('Applica');

    final (rules, traits) = result!;
    expect(rules.types, {'manhwa'});
    expect(rules.tags, {'Magia'});
    expect(rules.shelf, {ShelfStatus.reading});
    expect(rules.minRating, 8);
    expect(rules.favorite, isTrue);
    expect(traits.muted, isTrue);
    expect(traits.noRatingInvite, isTrue);
    expect(traits.keepChapters, isFalse);
    expect(traits.noAutoPause, isFalse);
  });
}
