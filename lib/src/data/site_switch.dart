/// Cambiare il provider di una serie già scaricata.
///
/// Prima si cerca la stessa serie sul provider nuovo ([sameSeries]); poi la
/// serie nuova ha un'altra chiave e altri id dei capitoli: i dati
/// personali la seguono con `UserRepository.moveSeries`, a cui serve sapere
/// quale capitolo del sito nuovo è quale di quello vecchio. Gli id non
/// dicono niente da un sito all'altro; il numero del capitolo sì.
library;

import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart' show SearchResult, chapterNumber;

import '../format/malf.dart';

/// Gli id di [old] tradotti in quelli di [fresh], abbinati per numero di
/// capitolo («1.50» è l'1.5) e, per i capitoli senza numero («Prologue»),
/// per nome. Un capitolo che il sito nuovo non ha resta fuori; se il sito
/// nuovo ripete un numero, vale il primo.
Map<String, String> matchChapters(Iterable<ChapterEntry> old, Iterable<Chapter> fresh) {
  final byKey = <String, String>{};
  for (final chapter in fresh) {
    final key = _key(chapter.number, chapter.title);
    if (key.isNotEmpty) byKey.putIfAbsent(key, () => chapter.id);
  }
  return {
    for (final chapter in old) chapter.id: ?byKey[_key(chapter.number, chapter.title)],
  };
}

String _key(String? number, String? title) {
  for (final candidate in [number, chapterNumber(title ?? '')]) {
    final value = double.tryParse(candidate?.trim().replaceAll(',', '.') ?? '');
    if (value != null) return '#$value';
  }
  return (title ?? number ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

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
