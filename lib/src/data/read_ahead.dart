/// Scaricare «man mano»: tenere pronti pochi capitoli da leggere, e portare
/// il seguente quando se ne legge uno.
///
/// La serie la segue il motore ([TrackedSeries.ahead]); qui si decide, dallo
/// stato di lettura e dall'indice unito della libreria, quali capitoli
/// mancano davanti al lettore. Quelli che l'indice conosce si mettono in coda
/// per id; quelli che il sito non aveva ancora li chiede il controllo delle
/// serie seguite ([TrackedSeries.wanted]). È logica pura, come
/// `arrivals.dart`: coda, disco e rete stanno fuori.
library;

import '../format/malf.dart';
import '../format/reading.dart';

/// I capitoli da tenere pronti, se la serie non dice altro.
const int readAheadWindow = 5;

class AheadPlan {
  const AheadPlan({this.enqueue = const [], this.wanted = 0});

  /// I capitoli dell'indice da mettere in coda, in ordine di lettura.
  final List<String> enqueue;

  /// Quanti ne mancano ancora, che l'indice non conosce: arriveranno dal
  /// sito, quando ci saranno.
  final int wanted;
}

/// Cosa manca davanti al lettore per averne [window] da leggere.
///
/// Il lettore sta all'ultimo capitolo letto o aperto. I capitoli prima del
/// primo che si ha — scaricato o in coda — non contano: chi ha cominciato
/// dal 40 non vuole che arrivino i primi trentanove. [pending] sono i
/// capitoli già in coda, anche quelli che l'indice non elenca ancora.
AheadPlan planAhead({
  required List<ChapterEntry> chapters,
  required SeriesState state,
  required Set<String> pending,
  int window = readAheadWindow,
}) {
  final ordered = [...chapters]..sort((a, b) => a.order.compareTo(b.order));
  final reading = state.progress?.chapterId;
  var position = -1;
  var first = -1;
  for (var i = 0; i < ordered.length; i++) {
    final id = ordered[i].id;
    if (state.readChapters.contains(id) || id == reading) position = i;
    if (first < 0 && (ordered[i].isReadable || pending.contains(id))) first = i;
  }
  if (first < 0 && pending.isEmpty) return const AheadPlan();
  if (first > position + 1) position = first - 1;
  final known = {for (final chapter in ordered) chapter.id};
  var ahead = pending.where((id) => !known.contains(id)).length;
  final missing = <String>[];
  for (final chapter in ordered.skip(position + 1)) {
    if (state.readChapters.contains(chapter.id)) continue;
    if (chapter.isReadable || pending.contains(chapter.id)) {
      ahead++;
    } else {
      missing.add(chapter.id);
    }
  }
  final need = window - ahead;
  if (need <= 0) return const AheadPlan();
  final enqueue = missing.take(need).toList(growable: false);
  return AheadPlan(enqueue: enqueue, wanted: need - enqueue.length);
}
