/// Capitoli nuovi: quanti ne sono arrivati per serie e di quali dare notizia.
///
/// MangaArchive controlla ogni giorno le serie in corso e scarica i capitoli
/// usciti; la catena li porta su Drive e sul telefono quando vuole. L'app se
/// ne accorge rileggendo gli indici — all'avvio, tornando in primo piano,
/// tirando giù la griglia — e qui decide cosa farne. È logica pura, come
/// `library_view.dart`: il disco e le notifiche stanno fuori.
library;

import 'dart:math' as math;

import 'package:kagami_archive/providers.dart' show providerById;

import '../format/malf.dart';
import '../format/reading.dart';
import 'library_view.dart';

/// Cosa sa questo telefono dei capitoli di una serie (`SeriesArrivals`).
class ArrivalMark {
  const ArrivalMark({
    required this.seen,
    required this.notified,
    this.onSite = false,
  });

  /// Capitoli ([SeriesSignals.arrivalCount]) all'ultima apertura della scheda.
  final int seen;

  /// Capitoli all'ultima volta che se n'è data notizia.
  final int notified;

  /// I conteggi sono dei capitoli del sito, presi quando la serie era una
  /// scheda; altrimenti degli archiviati. Una scheda che diventa una serie
  /// scaricata passa da tutti i capitoli del sito ai pochi scaricati: con
  /// questo si sa che il riferimento va ripreso da capo, invece di restare
  /// «sopra» finché gli archiviati non raggiungono il sito.
  final bool onSite;

  /// La scheda è stata aperta con [count] capitoli: non sono più nuovi, e
  /// non c'è più niente da annunciare.
  ///
  /// I conteggi non scendono mai: una libreria letta a metà — Drive
  /// scollegato, una cartella sincronizzata in parte — mostra meno capitoli
  /// di quanti ce ne siano, e quando tornano non sono arrivi.
  ArrivalMark acknowledged(int count) => ArrivalMark(
        seen: math.max(seen, count),
        notified: math.max(notified, count),
        onSite: onSite,
      );

  /// Il riferimento di [entry] com'è adesso: quello che c'è non è nuovo.
  factory ArrivalMark.of(SeriesEntry entry) {
    final count = SeriesSignals.arrivalCount(entry);
    return ArrivalMark(
      seen: count,
      notified: count,
      onSite: SeriesSignals.isCardEntry(entry),
    );
  }

  /// Il riferimento vale per [entry] solo se è stato preso sulla stessa base.
  bool fits(SeriesEntry entry) => onSite == SeriesSignals.isCardEntry(entry);

  /// [seen] per [SeriesSignals.seenChapters], se vale ancora.
  int? seenFor(SeriesEntry entry) => fits(entry) ? seen : null;

  @override
  bool operator ==(Object other) =>
      other is ArrivalMark &&
      other.seen == seen &&
      other.notified == notified &&
      other.onSite == onSite;

  @override
  int get hashCode => Object.hash(seen, notified, onSite);

  @override
  String toString() => 'ArrivalMark($seen, $notified, onSite: $onSite)';
}

/// Il nome del sito di una serie, per dire dove sono usciti i capitoli.
String siteName(SeriesEntry entry) =>
    providerById(entry.provider)?.name ?? entry.provider;

/// La chiave di [seriesKey] in `arrivals/record.json`. I conteggi del sito
/// stanno sotto una chiave loro: un numero annunciato quando la serie era
/// una scheda, riletto dopo il primo download come se fosse di archiviati,
/// fermerebbe le notizie finché gli archiviati non lo raggiungono.
String recordKey(String seriesKey, {required bool onSite}) =>
    onSite ? '$seriesKey@site' : seriesKey;

/// Una notifica da mostrare: la serie e quanti capitoli nuovi ha.
class ArrivalAlert {
  const ArrivalAlert({
    required this.entry,
    required this.count,
    this.onSite = false,
  });

  final SeriesEntry entry;
  final int count;

  /// Capitoli usciti sul sito di una scheda: non sono da leggere in Kagami.
  final bool onSite;
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
///
/// Lo stesso vale quando cambia la base ([ArrivalMark.onSite]): una scheda
/// che riceve il primo capitolo, o una serie che li perde tutti, riparte da
/// ciò che ha, senza annunciare niente.
ArrivalPlan planArrivals(
  Iterable<SeriesEntry> series,
  Map<String, SeriesState> states,
  Map<String, ArrivalMark> marks,
) {
  final changed = <String, ArrivalMark>{};
  final alerts = <ArrivalAlert>[];
  for (final entry in series) {
    final mark = marks[entry.key];
    if (mark == null || !mark.fits(entry)) {
      changed[entry.key] = ArrivalMark.of(entry);
      continue;
    }
    final count = SeriesSignals.arrivalCount(entry);
    if (count <= mark.notified) continue;
    changed[entry.key] = ArrivalMark(
      seen: mark.seen,
      notified: count,
      onSite: mark.onSite,
    );
    final state = states[entry.key] ?? const SeriesState();
    if (state.muted) continue;
    final fresh = SeriesSignals.of(entry, state, seenChapters: mark.seen)
        .newChapters;
    if (fresh > 0) {
      alerts.add(ArrivalAlert(entry: entry, count: fresh, onSite: mark.onSite));
    }
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
      for (final MapEntry(:key, value: mark) in marks.entries)
        if (record[recordKey(key, onSite: mark.onSite)] case final count?
            when count > mark.notified)
          key: ArrivalMark(
            seen: mark.seen,
            notified: count,
            onSite: mark.onSite,
          ),
    };

/// Le serie che il controllo ad app chiusa deve guardare, con quanto gli
/// serve per fare gli stessi conti di [planArrivals] senza lo stato utente:
/// solo quelle seguite e non silenziate, con un riferimento sulla base che
/// hanno adesso. Le schede portano il nome del sito (`site`): il worker
/// conta allora i capitoli del sito, e salta la serie se nel frattempo è
/// cambiata la base, che riprende l'app.
Map<String, Object?> watchList(
  String root,
  Iterable<SeriesSignals> series,
  Map<String, ArrivalMark> marks,
) => {
      'root': root,
      'series': {
        for (final signals in series)
          if (signals.isFollowed && !signals.state.muted)
            if (marks[signals.entry.key] case final mark?
                when mark.fits(signals.entry))
              signals.entry.key: {
                'title': signals.entry.title,
                'seen': mark.seen,
                'notified': mark.notified,
                // Il worker conta i nuovi come capitoli meno letti, quindi
                // qui vanno i letti fra quelli che conta: per una scheda i
                // capitoli del sito, per le altre gli archiviati.
                'read': signals.isCard
                    ? math.min(signals.readCount, signals.entry.chapterCount)
                    : signals.entry.archivedChapterCount - signals.unreadCount,
                'opened': ?signals.state.lastOpenedAt?.millisecondsSinceEpoch,
                if (signals.isCard) 'site': siteName(signals.entry),
              },
      },
    };
