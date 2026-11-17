/// «Porta qui i miei dati» (FASE-5b §3, F5.16): la stessa opera da un altro
/// sito ha un'altra chiave, quindi un'altra serie. Il ponte è un gesto
/// esplicito dalla scheda di una serie, mai automatico: un titolo uguale non
/// è la stessa serie.
library;

import '../format/malf.dart';

/// Cosa succederebbe spostando i dati di [from] su [to].
class SeriesDataMove {
  const SeriesDataMove({
    required this.from,
    required this.to,
    required this.chapters,
    required this.matchedReads,
    required this.lostReads,
  });

  final String from;
  final String to;

  /// L'id di [to] di ogni capitolo di [from] che ha lo stesso numero.
  final Map<String, String> chapters;

  /// Capitoli letti di [from] che trovano il loro numero in [to].
  final int matchedReads;

  /// Capitoli letti di [from] senza corrispondente: non si portano, e il
  /// foglio lo dice prima di confermare. Con loro cadono posizioni,
  /// cronologia e segnalibri di quei capitoli.
  final int lostReads;
}

/// Il numero come chiave di confronto: «10», «10.0» e « 10 » sono lo stesso
/// capitolo. Un capitolo senza numero non ha corrispondente.
String? _numberKey(String? number) {
  final text = number?.trim();
  if (text == null || text.isEmpty) return null;
  final value = double.tryParse(text);
  return value == null ? text.toLowerCase() : value.toString();
}

/// Abbina i capitoli di [from] a quelli di [to] per numero. A parità di
/// numero in [to] vale il primo nell'ordine di lettura.
Map<String, String> matchChaptersByNumber(Iterable<ChapterEntry> from, Iterable<ChapterEntry> to) {
  final byNumber = <String, String>{};
  for (final chapter in [...to]..sort((a, b) => a.order.compareTo(b.order))) {
    final key = _numberKey(chapter.number);
    if (key != null) byNumber.putIfAbsent(key, () => chapter.id);
  }
  final result = <String, String>{};
  for (final chapter in from) {
    final key = _numberKey(chapter.number);
    final target = key == null ? null : byNumber[key];
    if (target != null) result[chapter.id] = target;
  }
  return result;
}

SeriesDataMove planSeriesDataMove({
  required String from,
  required String to,
  required Iterable<ChapterEntry> fromChapters,
  required Iterable<ChapterEntry> toChapters,
  required Set<String> readInFrom,
}) {
  final chapters = matchChaptersByNumber(fromChapters, toChapters);
  final matched = readInFrom.where(chapters.containsKey).length;
  return SeriesDataMove(
    from: from,
    to: to,
    chapters: chapters,
    matchedReads: matched,
    lostReads: readInFrom.length - matched,
  );
}

/// Sposta solo se [confirm] dice sì: la serie di partenza perde i suoi dati,
/// e senza un sì esplicito non si tocca niente. Restituisce se ha spostato.
Future<bool> runSeriesDataMove(
  SeriesDataMove plan, {
  required Future<bool> Function(SeriesDataMove plan) confirm,
  required Future<void> Function(SeriesDataMove plan) move,
}) async {
  if (!await confirm(plan)) return false;
  await move(plan);
  return true;
}
