/// Cambiare il provider di una serie già scaricata.
///
/// Prima si cerca la stessa serie sul provider nuovo ([sameSeries]); poi la
/// serie nuova ha un'altra chiave e altri id dei capitoli: i dati
/// personali la seguono con `UserRepository.moveSeries`, a cui serve sapere
/// quale capitolo del sito nuovo è quale di quello vecchio. Gli id non
/// dicono niente da un sito all'altro; il numero del capitolo sì.
library;

import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/repair.dart' as archive show matchChapters;

import '../format/malf.dart';

export 'package:kagami_archive/elsewhere.dart' show sameSeries, titleKey;

/// Gli id di [old] tradotti in quelli di [fresh], con le regole di
/// `matchChapters` del pacchetto, che le usa anche la riparazione.
Map<String, String> matchChapters(Iterable<ChapterEntry> old, Iterable<Chapter> fresh) => archive.matchChapters(
      [for (final chapter in old) (id: chapter.id, number: chapter.number, title: chapter.title)],
      fresh,
    );
