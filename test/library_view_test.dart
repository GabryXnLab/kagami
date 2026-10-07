import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/library_view.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';

SeriesEntry entry({
  required String key,
  String provider = 'mangak',
  String title = 'Serie',
  int chapters = 10,
  int archived = 10,
  ReleaseStatus release = ReleaseStatus.ongoing,
  List<String> authors = const [],
  List<String> genres = const [],
  DateTime? latest,
  DateTime? added,
}) =>
    SeriesEntry(
      key: key,
      path: key,
      title: title,
      provider: provider,
      releaseStatus: release,
      chapterCount: chapters,
      archivedChapterCount: archived,
      pageCount: 0,
      bytes: 0,
      signature: 'x',
      authors: authors,
      genres: genres,
      latestChapterArchivedAt: latest,
      archivedAt: added,
    );

ChapterEntry chapter(String id, int order) => ChapterEntry(
      id: id,
      order: order,
      archived: true,
      complete: true,
      pageCount: 1,
      bytes: 0,
      path: 'chapters/$id',
    );

void main() {
  final gennaio = DateTime.utc(2026, 1, 1);
  final giugno = DateTime.utc(2026, 6, 1);

  group('le schede', () {
    final manual = entry(key: 'manual:a1', provider: 'manual', chapters: 0, archived: 0);
    final site = entry(key: 'mangak:b', chapters: 40, archived: 0);
    final full = entry(key: 'mangak:c');

    test('una serie senza capitoli archiviati, o manuale, è una scheda', () {
      expect(SeriesSignals.of(manual, const SeriesState()).isCard, isTrue);
      expect(SeriesSignals.of(site, const SeriesState()).isCard, isTrue);
      expect(SeriesSignals.of(full, const SeriesState()).isCard, isFalse);
    });

    test('il filtro «solo schede» le isola e conta come filtro attivo', () {
      final all = [
        for (final e in [manual, site, full]) SeriesSignals.of(e, const SeriesState()),
      ];
      const filter = LibraryFilter(onlyCards: true);
      expect(filter.activeCount, 1);
      expect(applyFilter(all, filter).map((s) => s.entry.key), ['manual:a1', 'mangak:b']);
    });

    test('una scheda coi letti stimati non ha niente da riprendere', () {
      final chapters = [
        for (var order = 0; order < 3; order++)
          ChapterEntry(
            id: 'C$order',
            order: order,
            archived: false,
            complete: false,
            pageCount: 0,
            bytes: 0,
          ),
      ];
      final signals = SeriesSignals.of(
        entry(key: 'mangak:b', chapters: 3, archived: 0),
        const SeriesState(readChapters: {'C0', 'C1'}, reachedChapter: '2'),
        chapters: chapters,
      );
      expect(signals.isStarted, isTrue);
      expect(signals.hasUnread, isFalse);
      expect(signals.unreadCount, 0);
    });

    test('il solo punto dichiarato di una scheda manuale la dà per iniziata', () {
      final signals = SeriesSignals.of(manual, const SeriesState(reachedChapter: '52'));
      expect(signals.isStarted, isTrue);
      expect(signals.hasUnread, isFalse);
      expect(const SeriesState(reachedChapter: '52').isEmpty, isFalse);
    });

    test('i capitoli nuovi di una scheda si contano sul sito', () {
      expect(SeriesSignals.arrivalCount(site), 40);
      expect(SeriesSignals.arrivalCount(full), 10);
      expect(SeriesSignals.arrivalCount(manual), 0);
      final signals = SeriesSignals.of(
        entry(key: 'mangak:b', chapters: 44, archived: 0, added: giugno),
        SeriesState(
          status: ShelfStatus.reading,
          readChapters: {for (var i = 1; i <= 40; i++) '$i'},
          updatedAt: gennaio,
          lastOpenedAt: gennaio,
        ),
        seenChapters: 40,
      );
      expect(signals.newChapters, 4);
      expect(AutoCollection.fresh.matches(signals), isTrue);
      expect(applyFilter([signals], const LibraryFilter(onlyNew: true)), [signals]);
      // In «Riprendi» no: in Kagami non c'è niente da leggere.
      expect(signals.hasUnread, isFalse);
    });

    test('una scheda non seguita non ha capitoli nuovi', () {
      final signals = SeriesSignals.of(
        entry(key: 'mangak:b', chapters: 44, archived: 0, added: giugno),
        const SeriesState(),
        seenChapters: 40,
      );
      expect(signals.newChapters, 0);
    });
  });

  test('i capitoli letti si contano sull\'archiviato, non sull\'annunciato', () {
    final signals = SeriesSignals.of(
      entry(key: 'a', chapters: 20, archived: 5),
      const SeriesState(readChapters: {'1', '2', '3', '4', '5'}),
    );
    expect(signals.unreadCount, 0);
    expect(signals.fraction, 1);
    expect(signals.entry.missingChapterCount, 15);
  });

  test('i precedenti non scaricati e segnati letti contano fra i letti', () {
    // Archiviata dal capitolo 4: i primi tre l'archivio li conosce e basta.
    final chapters = [
      for (var order = 0; order < 3; order++)
        ChapterEntry(
          id: 'C$order',
          order: order,
          archived: false,
          complete: false,
          pageCount: 0,
          bytes: 0,
        ),
      for (var order = 3; order < 6; order++) chapter('C$order', order),
    ];
    final series = entry(key: 'a', chapters: 6, archived: 3);
    const state = SeriesState(readChapters: {'C0', 'C1', 'C2', 'C3'});
    expect(SeriesSignals.needsChapters(series, state), isTrue);

    final signals = SeriesSignals.of(series, state, chapters: chapters);
    expect(signals.readCount, 4);
    expect(signals.unreadCount, 2);
    expect(signals.isFinished, isFalse);
    expect(signals.fraction, closeTo(4 / 6, 1e-9));

    // Senza indice i letti si suppongono archiviati: è il conto che
    // l'indice esiste per correggere.
    expect(SeriesSignals.of(series, state).unreadCount, 0);
  });

  test('una serie mai toccata non ha novità, ha tutto da iniziare', () {
    final signals = SeriesSignals.of(
      entry(key: 'a', latest: giugno),
      const SeriesState(),
    );
    expect(signals.isNew, isFalse);
    expect(signals.isStarted, isFalse);
    expect(AutoCollection.planned.matches(signals), isTrue);
    expect(AutoCollection.fresh.matches(signals), isFalse);
  });

  test('i capitoli arrivati dopo l\'ultima apertura sono una novità', () {
    final signals = SeriesSignals.of(
      entry(key: 'a', archived: 3, latest: giugno),
      SeriesState(
        status: ShelfStatus.reading,
        readChapters: const {'1'},
        updatedAt: gennaio,
        lastOpenedAt: gennaio,
      ),
      seenChapters: 1,
    );
    expect(signals.newChapters, 2);
    expect(signals.isNew, isTrue);
    expect(AutoCollection.fresh.matches(signals), isTrue);
  });

  test('senza capitoli da leggere non è una novità anche se la data è nuova',
      () {
    final signals = SeriesSignals.of(
      entry(key: 'a', archived: 1, latest: giugno),
      SeriesState(readChapters: const {'1'}, updatedAt: gennaio),
      seenChapters: 0,
    );
    expect(signals.isNew, isFalse);
  });

  test('la ricerca prende anche gli autori', () {
    final all = [
      SeriesSignals.of(
        entry(key: 'a', title: 'Dungeon Odyssey', authors: const ['Kim']),
        const SeriesState(),
      ),
      SeriesSignals.of(
        entry(key: 'b', title: 'Altro', authors: const ['Sato']),
        const SeriesState(),
      ),
    ];
    expect(
      applyFilter(all, const LibraryFilter(query: 'kim')).map((s) => s.entry.key),
      ['a'],
    );
    expect(
      applyFilter(all, const LibraryFilter(query: 'odys')).map((s) => s.entry.key),
      ['a'],
    );
  });

  test('i filtri si sommano e i generi si richiedono tutti', () {
    final all = [
      SeriesSignals.of(
        entry(key: 'a', genres: const ['Azione', 'Fantasy']),
        const SeriesState(status: ShelfStatus.reading),
      ),
      SeriesSignals.of(
        entry(key: 'b', genres: const ['Azione']),
        const SeriesState(status: ShelfStatus.reading),
      ),
      SeriesSignals.of(
        entry(key: 'c', genres: const ['Azione', 'Fantasy']),
        const SeriesState(status: ShelfStatus.dropped),
      ),
    ];
    final visible = applyFilter(
      all,
      const LibraryFilter(
        genres: TriFilter(include: {'Azione', 'Fantasy'}),
        shelf: {ShelfStatus.reading},
      ),
    );
    expect(visible.map((s) => s.entry.key), ['a']);
  });

  test('un genere escluso toglie la serie anche se il resto corrisponde', () {
    final all = [
      SeriesSignals.of(
        entry(key: 'a', genres: const ['Azione', 'Horror']),
        const SeriesState(),
      ),
      SeriesSignals.of(
        entry(key: 'b', genres: const ['Azione']),
        const SeriesState(),
      ),
    ];
    final visible = applyFilter(
      all,
      const LibraryFilter(
        genres: TriFilter(include: {'Azione'}, exclude: {'Horror'}),
      ),
    );
    expect(visible.map((s) => s.entry.key), ['b']);
  });

  test('la ricerca con prefissi cerca nel campo giusto', () {
    final all = [
      SeriesSignals.of(
        entry(key: 'a', title: 'Alfa', genres: const ['Azione']),
        const SeriesState(),
      ),
      SeriesSignals.of(
        entry(key: 'b', title: 'Beta', genres: const ['Commedia']),
        const SeriesState(),
      ),
    ];
    expect(
      applyFilter(all, const LibraryFilter(query: 'genere:azione'))
          .map((s) => s.entry.key),
      ['a'],
    );
    // Senza prefisso il testo resta una ricerca su titolo e autori: il nome
    // di un genere non deve far comparire tutta la sua categoria.
    expect(
      applyFilter(all, const LibraryFilter(query: 'azione')).map((s) => s.entry.key),
      isEmpty,
    );
  });

  test('l\'ordine di una raccolta vince sull\'ordinamento della libreria', () {
    final all = [
      SeriesSignals.of(entry(key: 'a', title: 'Alfa'), const SeriesState()),
      SeriesSignals.of(entry(key: 'b', title: 'Beta'), const SeriesState()),
      SeriesSignals.of(entry(key: 'c', title: 'Gamma'), const SeriesState()),
    ];
    final visible = applyFilter(
      all,
      const LibraryFilter(collectionId: 'r1', sort: LibrarySort.title),
      collectionOrder: const ['c', 'a'],
    );
    expect(visible.map((s) => s.entry.key), ['c', 'a']);
  });

  test('ordinare per aggiornamento mette davanti l\'ultimo arrivato', () {
    final all = [
      SeriesSignals.of(entry(key: 'a', latest: gennaio), const SeriesState()),
      SeriesSignals.of(entry(key: 'b', latest: giugno), const SeriesState()),
    ];
    expect(
      applyFilter(all, const LibraryFilter()).map((s) => s.entry.key),
      ['b', 'a'],
    );
    expect(
      applyFilter(all, const LibraryFilter(descending: false))
          .map((s) => s.entry.key),
      ['a', 'b'],
    );
  });

  test('i valori dei filtri escono dalla libreria vera', () {
    final facets = LibraryFacets.of([
      entry(key: 'a', genres: const ['Azione'], authors: const ['Kim']),
      entry(key: 'b', genres: const ['Fantasy'], authors: const ['Kim']),
    ]);
    expect(facets.genres, ['Azione', 'Fantasy']);
    expect(facets.authors, ['Kim']);
  });

  test('i precedenti da leggere sono quelli prima, non letti, in ordine', () {
    final chapters = [
      chapter('C4', 3),
      chapter('C1', 0),
      chapter('C3', 2),
      chapter('C2', 1),
      chapter('C5', 4),
    ];
    expect(unreadBefore(chapters, 'C4', {'C2', 'C4'}), ['C1', 'C3']);
    expect(unreadBefore(chapters, 'C1', const {}), isEmpty);
    expect(unreadBefore(chapters, 'altrove', const {}), isEmpty);
  });
}
