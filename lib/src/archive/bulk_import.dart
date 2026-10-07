/// L'import di tanti link in una volta, senza interfaccia: dal testo
/// incollato o condiviso alle righe da importare, e per ogni riga la strada
/// — già in libreria, una serie di un sito, una scheda manuale.
///
/// L'ingresso è testo libero (se ne prendono i link http/https) oppure un
/// JSON, una lista di oggetti `{"url", "title", "chapter", "status",
/// "rating", "notes"}`: è la forma pensata per chi passa all'app le schede
/// del browser in blocco (`docs/design.md`, «Importare tanti link»).
library;

import 'dart:convert';

import 'package:kagami_archive/manual.dart';
import 'package:kagami_archive/providers.dart';

import '../format/malf.dart';
import '../format/reading.dart';
import 'manual_card.dart';

/// Una riga da importare: il link e, se arriva da un JSON, ciò che lo
/// accompagna.
class ImportItem {
  const ImportItem(
    this.url, {
    this.title,
    this.chapter,
    this.status,
    this.rating,
    this.notes,
  });

  final String url;

  /// Il titolo, per una scheda manuale; una serie di un sito ha il suo.
  final String? title;

  /// Il numero dell'ultimo capitolo letto, come lo scrive l'autore.
  final String? chapter;
  final ShelfStatus? status;

  /// Da 1 a 10.
  final int? rating;
  final String? notes;

  /// Lo stato di una scheda manuale: quello dato o, con un capitolo
  /// raggiunto, «in lettura», come fa «arrivato a» per le serie dei siti.
  ShelfStatus get manualStatus => status ?? (chapter != null ? ShelfStatus.reading : ShelfStatus.none);
}

final RegExp _urlPattern = RegExp(r'''https?://[^\s<>"'`()\[\]{}]+''', caseSensitive: false);

/// La punteggiatura che chiude una frase non fa parte del link.
final RegExp _trailing = RegExp(r'[.,;:!?…»”’]+$');

/// Le righe di [text]: il JSON, se lo è, altrimenti i link che contiene,
/// senza doppioni (confrontati con `normalizeLink`) e nell'ordine in cui
/// compaiono.
List<ImportItem> parseImportText(String text) {
  final items = _parseJson(text.trim()) ??
      [
        for (final match in _urlPattern.allMatches(text))
          ImportItem(match[0]!.replaceFirst(_trailing, '')),
      ];
  final seen = <String>{};
  return [
    for (final item in items)
      if (_isWebLink(item.url) && seen.add(normalizeLink(item.url))) item,
  ];
}

bool _isWebLink(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}

/// `null` se [text] non è una lista JSON: allora è testo libero. Un
/// elemento può essere anche solo il link, come stringa.
List<ImportItem>? _parseJson(String text) {
  if (!text.startsWith('[')) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;
  String? string(Object? value) {
    final text = value is num ? '$value' : value is String ? value.trim() : null;
    return text == null || text.isEmpty ? null : text;
  }

  return [
    for (final row in decoded)
      if (row is String)
        ImportItem(row.trim())
      else if (row is Map && string(row['url']) != null)
        ImportItem(
          string(row['url'])!,
          title: string(row['title']),
          chapter: string(row['chapter']),
          status: switch (ShelfStatus.parse(row['status'])) {
            ShelfStatus.none => null,
            final status => status,
          },
          rating: switch (row['rating']) {
            final num value when value >= 1 && value <= 10 => value.round(),
            _ => null,
          },
          notes: string(row['notes']),
        ),
  ];
}

/// La strada di una riga, prima di leggere qualcosa dalla rete.
sealed class ImportRoute {
  const ImportRoute();
}

/// La serie c'è già, in libreria o fra quelle già in coda.
class ImportKnown extends ImportRoute {
  const ImportKnown(this.title);

  /// Il titolo della serie in libreria; `null` se è un lavoro in coda.
  final String? title;
}

/// Un sito che Kagami sa leggere: la serie si legge e se ne fa una scheda.
class ImportSite extends ImportRoute {
  const ImportSite(this.link);

  final SeriesLink link;
}

/// Un sito che nessun provider riconosce: una scheda manuale.
class ImportManual extends ImportRoute {
  const ImportManual();
}

/// Dove va [item]. [queued] sono i link (normalizzati) dei lavori già in
/// coda: una scheda in coda non è ancora in libreria, ma rimetterla la
/// farebbe due volte.
ImportRoute routeImport(ImportItem item, LibraryIndex index, {Set<String> queued = const {}}) {
  SeriesLink? link;
  try {
    link = resolveLink(item.url);
  } on UnsupportedLink {
    link = null;
  }
  for (final url in {item.url, ?link?.seriesUrl}) {
    final known = entryForLink(index, url);
    if (known != null) return ImportKnown(known.title);
    if (queued.contains(normalizeLink(url))) return const ImportKnown(null);
  }
  return link == null ? const ImportManual() : ImportSite(link);
}

/// La serie con la chiave [key], letta dal sito, è già in libreria: la
/// chiave dice di più del link, che lo stesso sito scrive in più modi.
SeriesEntry? entryForKey(LibraryIndex index, String key) =>
    index.series.where((entry) => entry.key == key).firstOrNull;

/// Il titolo di una scheda manuale quando né il JSON né la pagina ne danno
/// uno: host e percorso, senza `www.` e senza `/` finale.
String fallbackTitle(String url) {
  final uri = Uri.parse(url);
  final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  final path = [for (final segment in uri.pathSegments) if (segment.isNotEmpty) segment].join('/');
  return path.isEmpty ? host : '$host/$path';
}
