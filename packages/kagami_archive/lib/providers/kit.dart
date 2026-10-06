/// Gli attrezzi che ogni provider usa, in un posto solo.
///
/// Un sito nuovo deve scrivere solo ciò che è suo — dove stanno serie,
/// capitoli e tavole — e prendere da qui i controlli che devono valere
/// uguali per tutti: un link accettato con regole diverse da un sito
/// all'altro è un buco, e un capitolo ordinato male una serie da rifare.
library;

import 'package:html/parser.dart' as html;

import '../model.dart';
import '../providers.dart';

/// Se [url] è il link di una pagina del sito: https, uno degli [hosts], senza
/// porta né credenziali, e un percorso che [path] riconosce. Con [plain] non
/// passano nemmeno query e frammento, per i siti dove cambierebbero pagina.
bool siteLink(
  String url, {
  required Set<String> hosts,
  required RegExp path,
  bool plain = false,
}) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      hosts.contains(uri.host) &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      (!plain || (!uri.hasQuery && !uri.hasFragment)) &&
      path.hasMatch(uri.path);
}

/// Un testo che c'è davvero: i JSON dei siti mettono `""` e `null` dove
/// manca un valore.
bool isText(Object? value) => value is String && value.isNotEmpty;

String trimSlashes(String value) {
  var result = value;
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

/// I metadati del sito senza i campi che non descrivono la serie (commenti,
/// segnalibri dell'utente, l'elenco dei capitoli già letto a parte): finiscono
/// nel manifest, e lì devono restare quelli che valgono anche domani.
Map<String, Object?> withoutKeys(Map<String, Object?> raw, Set<String> hidden) => {
      for (final MapEntry(:key, :value) in raw.entries)
        if (!hidden.contains(key)) key: value,
    };

/// Il numero del sito come lo scriverebbe l'autore: `70` e non `70.0`.
String numberLabel(num value) =>
    value == value.truncate() ? '${value.truncate()}' : '$value';

/// Una descrizione in HTML come testo, un paragrafo per riga vuota: la
/// libreria la mostra così com'è, e i tag sarebbero rumore.
String htmlText(String source) {
  final document = html.parseFragment(source.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'));
  final blocks = [
    for (final node in document.nodes)
      (node.text ?? '').split('\n').map((line) => line.trim()).join('\n').trim(),
  ];
  return blocks.where((block) => block.isNotEmpty).join('\n\n');
}

/// I capitoli dal primo all'ultimo, come li vuole la libreria. Un sito che
/// li elenca dal più recente si riconosce dal numero nei nomi; senza numeri
/// l'ordine resta quello del sito.
List<Chapter> oldestFirst(List<Chapter> chapters) {
  final ordered = [
    for (final chapter in chapters)
      if (chapterNumberPattern.firstMatch(chapter.title) case final match?)
        (int.parse(match[1]!), int.parse(match[2] ?? '0')),
  ];
  final reversed = ordered.length >= 2 &&
      (ordered.first.$1 > ordered.last.$1 ||
          (ordered.first.$1 == ordered.last.$1 && ordered.first.$2 > ordered.last.$2));
  return reversed ? chapters.reversed.toList() : chapters;
}

/// Un elenco di capitoli in cui lo stesso id compare due volte è un sito che
/// ha cambiato forma: meglio fermarsi che archiviare due cartelle uguali.
void requireUniqueIds(List<Chapter> chapters, String site) {
  final seen = <String>{};
  for (final chapter in chapters) {
    if (!seen.add(chapter.id)) throw ProviderError('Elenco capitoli $site incoerente.');
  }
}
