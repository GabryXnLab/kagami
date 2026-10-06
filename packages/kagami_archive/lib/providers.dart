/// I siti da cui l'app sa archiviare, e il confine fra loro e il motore.
///
/// Ogni sito vive in un file suo sotto `providers/` e si registra in
/// [providers]: il motore non conosce l'HTML di nessuno. È lo stesso registro
/// di `mangaarchive/providers/__init__.py`, e i due vanno tenuti allineati:
/// una serie archiviata da una parte si aggiorna dall'altra.
///
/// Aggiungere un sito:
/// 1. `providers/<id>.dart`, una sottoclasse di [Provider] che usa gli
///    attrezzi di `providers/kit.dart` per link, testi e ordine dei capitoli;
/// 2. registrarlo in [providers];
/// 3. l'icona in `assets/providers/<id>.png` (96×96);
/// 4. le risposte finte in `test/archive_fakes.dart` e i suoi casi in
///    `test/archive_providers_test.dart`; `test/provider_contract_test.dart`
///    controlla da solo ciò che ogni sito deve avere.
///
/// Il resto — app, server, coda, serie in corso — non nomina nessun sito: se
/// uno sta dietro una verifica del browser lo dice [Provider.browser], e la
/// WebView, la pagina mandata al server e il salto nel controllo ad app chiusa
/// seguono da lì.
library;

import 'http.dart';
import 'model.dart';
import 'providers/asurascans.dart';
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

  /// Se [url] si può chiedere per conto del sito: [validateUrl] senza
  /// eccezione, per le copertine che si mostrano solo se sono sue.
  bool allows(String url) {
    try {
      validateUrl(url);
      return true;
    } on ProviderError {
      return false;
    }
  }

  /// L'indirizzo della serie nella forma che il sito usa per sé: è quello che
  /// la WebView apre e che la pagina mandata al server sostituisce.
  String canonical(String url) => url;

  /// Come far passare la verifica del sito in una WebView; `null` per i siti
  /// che rispondono al client HTTP dell'app.
  BrowserGate? get browser => null;

  /// Se la serie passa da una verifica che solo una WebView supera.
  bool get needsBrowser => browser != null;
}

/// Ciò che serve all'app per aprire un sito protetto in una WebView: di chi
/// portarsi dietro i cookie e come riconoscere, in JavaScript, che la pagina
/// vera è arrivata al posto della verifica.
class BrowserGate {
  const BrowserGate({
    required this.hosts,
    required this.seriesReady,
    required this.searchReady,
  });

  final List<String> hosts;

  /// Sulla pagina di una serie: c'è l'elenco dei capitoli.
  final String seriesReady;

  /// Sulla pagina principale o dei risultati: c'è la ricerca del sito.
  final String searchReady;
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

final List<Provider> providers = [MangaK(), ManhwaRead(), AsuraScans()];

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
