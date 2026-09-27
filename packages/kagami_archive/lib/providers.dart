/// I siti da cui l'app sa archiviare, e il confine fra loro e il motore.
///
/// Ogni sito vive in un file suo sotto `providers/` e si registra in
/// [providers]: il motore non conosce l'HTML di nessuno. È lo stesso registro
/// di `mangaarchive/providers/__init__.py`, e i due vanno tenuti allineati:
/// una serie archiviata da una parte si aggiorna dall'altra.
library;

import 'http.dart';
import 'model.dart';
import 'providers/mangak.dart';
import 'providers/manhwaread.dart';

abstract class Provider {
  String get id;
  String get name;

  /// La pagina principale del sito, da mostrare a chi sceglie cosa scaricare.
  String get home;

  /// L'icona del sito, fra gli asset dell'app.
  String get icon => 'assets/providers/$id.png';

  /// Se [url] è il link di una serie di questo sito.
  bool accepts(String url);

  /// Se l'app può chiedere qualcosa a questo host per conto del sito.
  bool allowedHost(Uri uri);

  Future<Series> fetchSeries(String url, ProviderHttp http);

  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http);

  /// Le serie che la ricerca del sito dà per [query], nello stesso ordine:
  /// è la barra di ricerca del sito, chiamata come la chiama lui. Serve solo
  /// all'app per scegliere cosa scaricare, e il server non ce l'ha.
  Future<List<SearchResult>> search(String query, ProviderHttp http);

  void validateUrl(String url) => checkUrl(url, allowedHost);

  /// Se la serie passa da una verifica che solo una WebView supera.
  bool get needsBrowser => false;
}

/// Una serie trovata cercando: quanto basta a riconoscerla e il link da
/// scaricare, che passa poi dalla stessa verifica di un link incollato.
class SearchResult {
  const SearchResult({
    required this.provider,
    required this.title,
    required this.url,
    this.coverUrl,
    this.chapters,
    this.releaseStatus = 'unknown',
  });

  final String provider;
  final String title;
  final String url;
  final String? coverUrl;
  final int? chapters;

  /// Uno di [releaseStatuses].
  final String releaseStatus;
}

/// Quante serie chiedere a ogni sito mentre si scrive: quelle di un menù a
/// tendina, non di una pagina di risultati.
const int searchLimit = 10;

final List<Provider> providers = [MangaK(), ManhwaRead()];

final RegExp chapterNumberPattern =
    RegExp(r'\bchapter\s*0*(\d+)(?:[.,](\d+))?\b', caseSensitive: false);

/// Il numero che l'autore dà al capitolo, letto dal suo nome: «Chapter
/// 70.5» è il 70.5. È lo stesso `chapter_number` di `providers/base.py`.
///
/// I siti hanno spesso anche un numero loro, ma può essere solo il posto
/// nell'elenco: su MangaK un capitolo 70.5 fa salire di uno tutti i numeri
/// dopo di lui, e la serie avrebbe due numerazioni.
String? chapterNumber(String title) {
  final found = chapterNumberPattern.firstMatch(title);
  if (found == null) return null;
  return '${int.parse(found[1]!)}${found[2] != null ? '.${found[2]}' : ''}';
}

Provider selectProvider(String url) {
  final matches = providers.where((provider) => provider.accepts(url)).toList();
  if (matches.length != 1) {
    throw ProviderError(
      'Link non supportato. Siti disponibili: '
      '${providers.map((provider) => provider.name).join(', ')}.',
    );
  }
  return matches.single;
}

Provider? providerById(String id) =>
    providers.where((provider) => provider.id == id).firstOrNull;
