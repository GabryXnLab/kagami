/// I nomi delle cartelle dell'archivio e la scelta del capitolo di partenza.
///
/// I nomi devono venire identici a quelli che scrive il server
/// (`archive.py`): server e telefono aggiungono capitoli alla stessa serie su
/// Drive, e un nome diverso per lo stesso capitolo sarebbe una seconda
/// cartella accanto alla prima.
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'model.dart';

final RegExp _forbidden = RegExp(r'[\\/<>:"|?*\x00-\x1f\x7f]+');
final RegExp _spaces = RegExp(r'\s+');

String _strip(String value) {
  var start = 0;
  var end = value.length;
  bool edge(int unit) => unit == 0x20 || unit == 0x2E;
  while (start < end && edge(value.codeUnitAt(start))) {
    start++;
  }
  while (end > start && edge(value.codeUnitAt(end - 1))) {
    end--;
  }
  return value.substring(start, end);
}

String _stripRight(String value) {
  var end = value.length;
  while (end > 0 && (value.codeUnitAt(end - 1) == 0x20 || value.codeUnitAt(end - 1) == 0x2E)) {
    end--;
  }
  return value.substring(0, end);
}

String safeName(String value, {int limit = 100}) {
  var name = unorm.nfkc(value).replaceAll(_forbidden, ' ');
  name = _strip(name.replaceAll(_spaces, ' '));
  // Python taglia per caratteri, non per unità UTF-16.
  final runes = name.runes;
  if (runes.length > limit) name = String.fromCharCodes(runes.take(limit));
  name = _stripRight(name);
  return name.isEmpty ? 'Senza titolo' : name;
}

String chapterPrefix(String number) {
  final match = RegExp(r'^(\d+)(\.\d+)?$').firstMatch(number);
  if (match != null) return match[1]!.padLeft(4, '0') + (match[2] ?? '');
  return safeName(number.isEmpty ? 'extra' : number, limit: 20);
}

String seriesFolderName(Series series) =>
    '${safeName(series.title, limit: 70)} '
    '[${safeName(series.provider, limit: 20)}-${safeName(series.id, limit: 30)}]';

String chapterFolderName(Chapter chapter) =>
    '${chapterPrefix(chapter.number)} - ${safeName(chapter.title, limit: 75)} '
    '[${safeName(chapter.id, limit: 30)}]';

/// Il numero con cui un capitolo si ordina, se ne ha uno.
double? sortKey(String? number) {
  final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(number ?? '');
  return match == null ? null : double.parse(match[0]!);
}

/// La posizione del capitolo da cui partire: per id, per numero o per valore.
///
/// Chi sceglie scrive il numero che legge sul sito («16», «16.5»), che non è
/// sempre la stringa archiviata: il confronto numerico recupera «Capitolo 16».
int startIndex(List<Chapter> chapters, String start) {
  final text = start.trim();
  if (text.isEmpty) throw const ProviderError('Indica il capitolo da cui iniziare.');
  for (var i = 0; i < chapters.length; i++) {
    if (chapters[i].id == text || chapters[i].number == text) return i;
  }
  final wanted = sortKey(text);
  if (wanted != null) {
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final number = chapter.number.isEmpty ? chapter.title : chapter.number;
      if (sortKey(number) == wanted) return i;
    }
  }
  throw ProviderError('Il capitolo «$text» non è nell’elenco della serie.');
}
