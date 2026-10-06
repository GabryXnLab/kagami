// Scaricare man mano: quali capitoli mancano davanti al lettore.
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/read_ahead.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/format/reading.dart';

/// Venti capitoli, `c0`…`c19`; quelli in [have] sono scaricati.
List<ChapterEntry> chapters(Set<int> have) => [
      for (var i = 0; i < 20; i++)
        ChapterEntry(
          id: 'c$i',
          order: i,
          archived: have.contains(i),
          complete: have.contains(i),
          pageCount: have.contains(i) ? 10 : 0,
          bytes: 0,
          path: have.contains(i) ? 'chapters/c$i' : null,
        ),
    ];

SeriesState state({Set<int> read = const {}, int? reading}) => SeriesState(
      readChapters: {for (final i in read) 'c$i'},
      positions: reading == null
          ? const {}
          : {
              'c$reading': ReadingProgress(
                chapterId: 'c$reading',
                page: 3,
                pageCount: 10,
                updatedAt: DateTime.utc(2026),
              ),
            },
    );

void main() {
  test('con cinque capitoli pronti non serve niente', () {
    final plan = planAhead(chapters: chapters({10, 11, 12, 13, 14}), state: state(), pending: const {});
    expect(plan.enqueue, isEmpty);
    expect(plan.wanted, 0);
  });

  test('i capitoli prima del primo scaricato non arrivano da soli', () {
    final plan = planAhead(chapters: chapters({10, 11}), state: state(), pending: const {});
    expect(plan.enqueue, ['c12', 'c13', 'c14']);
  });

  test('letto un capitolo, arriva il seguente', () {
    final plan = planAhead(
      chapters: chapters({10, 11, 12, 13, 14}),
      state: state(read: {10}),
      pending: const {},
    );
    expect(plan.enqueue, ['c15']);
  });

  test('il capitolo aperto conta come quello a cui si è arrivati', () {
    final plan = planAhead(
      chapters: chapters({10, 11, 12, 13, 14}),
      state: state(read: {10}, reading: 11),
      pending: const {},
    );
    expect(plan.enqueue, ['c15', 'c16']);
  });

  test('quelli già in coda non si chiedono due volte', () {
    final plan = planAhead(
      chapters: chapters({10, 11, 12, 13, 14}),
      state: state(read: {10, 11}),
      pending: const {'c15'},
    );
    expect(plan.enqueue, ['c16']);
  });

  test('in fondo all\'indice, il resto lo chiede al sito', () {
    final plan = planAhead(
      chapters: chapters({16, 17, 18, 19}),
      state: state(read: {16, 17}),
      pending: const {},
    );
    expect(plan.enqueue, isEmpty);
    expect(plan.wanted, 3);
  });

  test('un capitolo nuovo già in coda conta fra quelli pronti', () {
    final plan = planAhead(
      chapters: chapters({16, 17, 18, 19}),
      state: state(read: {16, 17}),
      pending: const {'c20'},
    );
    expect(plan.wanted, 2);
  });

  test('una serie non ancora scesa non chiede niente', () {
    final plan = planAhead(chapters: chapters(const {}), state: state(), pending: const {});
    expect(plan.enqueue, isEmpty);
    expect(plan.wanted, 0);
  });
}
