/// Capitoli nuovi: quanti ne sono arrivati per serie e di quali dare notizia.
///
/// MangaArchive controlla ogni giorno le serie in corso e scarica i capitoli
/// usciti; la catena li porta su Drive e sul telefono quando vuole. L'app se
/// ne accorge rileggendo gli indici — all'avvio, tornando in primo piano,
/// tirando giù la griglia — e qui decide cosa farne. È logica pura, come
/// `library_view.dart`: il disco e le notifiche stanno fuori.
library;

import 'dart:math' as math;

import '../format/malf.dart';
import '../format/reading.dart';
import 'library_view.dart';

/// Cosa sa questo telefono dei capitoli di una serie (`SeriesArrivals`).
class ArrivalMark {
  const ArrivalMark({required this.seen, required this.notified});

  /// Capitoli archiviati all'ultima apertura della scheda.
  final int seen;

  /// Capitoli archiviati all'ultima volta che se n'è data notizia.
  final int notified;

  /// La scheda è stata aperta con [count] capitoli: non sono più nuovi, e
  /// non c'è più niente da annunciare.
  ///
  /// I conteggi non scendono mai: una libreria letta a metà — Drive
  /// scollegato, una cartella sincronizzata in parte — mostra meno capitoli
  /// di quanti ce ne siano, e quando tornano non sono arrivi.
  ArrivalMark acknowledged(int count) => ArrivalMark(
        seen: math.max(seen, count),
        notified: math.max(notified, count),
      );

  @override
  bool operator ==(Object other) =>
      other is ArrivalMark && other.seen == seen && other.notified == notified;

  @override
  int get hashCode => Object.hash(seen, notified);
}

/// Una notifica da mostrare: la serie e quanti capitoli nuovi ha.
class ArrivalAlert {
  const ArrivalAlert({required this.entry, required this.count});

  final SeriesEntry entry;
  final int count;
}

class ArrivalPlan {
  const ArrivalPlan({required this.marks, required this.alerts});

  /// Solo le righe cambiate, da scrivere.
  final Map<String, ArrivalMark> marks;
  final List<ArrivalAlert> alerts;
}

/// Confronta la libreria appena letta con ciò che il telefono sapeva.
///
/// Una serie vista per la prima volta prende come riferimento quello che ha:
/// installare l'app, o aggiornarla a questa versione, non deve annunciare
/// tutta la libreria. Ogni arrivo si annuncia una volta sola, e solo per le
/// serie seguite e non silenziate; per le altre il riferimento avanza lo
/// stesso, così cominciare a seguirne una non fa suonare gli arrivi vecchi.
ArrivalPlan planArrivals(
  Iterable<SeriesEntry> series,
  Map<String, SeriesState> states,
  Map<String, ArrivalMark> marks,
) {
  final changed = <String, ArrivalMark>{};
  final alerts = <ArrivalAlert>[];
  for (final entry in series) {
    final count = entry.archivedChapterCount;
    final mark = marks[entry.key];
    if (mark == null) {
      changed[entry.key] = ArrivalMark(seen: count, notified: count);
      continue;
    }
    if (count <= mark.notified) continue;
    changed[entry.key] = ArrivalMark(seen: mark.seen, notified: count);
    final state = states[entry.key] ?? const SeriesState();
    if (state.muted) continue;
    final fresh = SeriesSignals.of(entry, state, seenChapters: mark.seen)
        .newChapters;
    if (fresh > 0) alerts.add(ArrivalAlert(entry: entry, count: fresh));
  }
  return ArrivalPlan(marks: changed, alerts: alerts);
}

/// Ciò che il controllo ad app chiusa (`LibraryWatchWorker.kt`) ha già
/// annunciato: un arrivo notificato lì non deve suonare di nuovo qui.
///
/// Restituisce solo le righe che cambiano.
Map<String, ArrivalMark> recordedArrivals(
  Map<String, ArrivalMark> marks,
  Map<String, int> record,
) => {
      for (final MapEntry(:key, value: count) in record.entries)
        if (marks[key] case final mark? when count > mark.notified)
          key: ArrivalMark(seen: mark.seen, notified: count),
    };

/// Le serie che il controllo ad app chiusa deve guardare, con quanto gli
/// serve per fare gli stessi conti di [planArrivals] senza lo stato utente:
/// solo quelle seguite e non silenziate.
Map<String, Object?> watchList(
  String root,
  Iterable<SeriesSignals> series,
  Map<String, ArrivalMark> marks,
) => {
      'root': root,
      'series': {
        for (final signals in series)
          if (signals.isFollowed && !signals.state.muted)
            if (marks[signals.entry.key] case final mark?)
              signals.entry.key: {
                'title': signals.entry.title,
                'seen': mark.seen,
                'notified': mark.notified,
                // Il worker conta i nuovi come archiviati meno letti, quindi
                // qui vanno i letti fra gli archiviati, non tutti.
                'read': signals.entry.archivedChapterCount -
                    signals.unreadCount,
                'opened': ?signals.state.lastOpenedAt?.millisecondsSinceEpoch,
              },
      },
    };
