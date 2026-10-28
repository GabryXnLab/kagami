/// Cambiare il provider di una serie già scaricata.
///
/// Prima si cerca la stessa serie sul provider nuovo ([sameSeries]); poi la
/// serie nuova ha un'altra chiave e altri id dei capitoli: i dati
/// personali la seguono con `UserRepository.moveSeries`, a cui serve sapere
/// quale capitolo del sito nuovo è quale di quello vecchio. Gli id non
/// dicono niente da un sito all'altro; il numero del capitolo sì.
library;

import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart' show SearchResult;
import 'package:kagami_archive/repair.dart' as archive show matchChapters;

import '../format/malf.dart';

/// Gli id di [old] tradotti in quelli di [fresh], con le regole di
/// `matchChapters` del pacchetto, che le usa anche la riparazione.
Map<String, String> matchChapters(Iterable<ChapterEntry> old, Iterable<Chapter> fresh) => archive.matchChapters(
      [for (final chapter in old) (id: chapter.id, number: chapter.number, title: chapter.title)],
      fresh,
    );

/// Un titolo nella forma in cui due siti lo scrivono uguale: senza
/// maiuscole, spazi e punteggiatura («The House Without Time» e
/// «The House: Without Time!» sono la stessa serie).
String titleKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

/// Il primo dei [results] che porta uno dei [titles] della serie (il titolo
/// e quelli alternativi), o `null`: la serie sul provider nuovo, se la sua
/// ricerca la trova con lo stesso nome.
SearchResult? sameSeries(Iterable<SearchResult> results, Iterable<String> titles) {
  final wanted = {for (final title in titles) titleKey(title)}..remove('');
  return results.where((result) => wanted.contains(titleKey(result.title))).firstOrNull;
}
