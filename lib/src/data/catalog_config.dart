/// A quale catalogo di siti guarda questa build (`docs/catalogo.md`).
///
/// Il catalogo è di chi compila: il sorgente non ne nomina nessuno, e gli
/// indirizzi e le chiavi pubbliche arrivano con `--dart-define=CATALOG_URLS=…` e
/// `--dart-define=CATALOG_KEYS=…`. Senza, o con valori che non reggono, il
/// catalogo è spento e l'app non fa nessuna richiesta.
library;

import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/signature.dart';

class CatalogConfig {
  const CatalogConfig({this.urls = const [], this.keys = const {}});

  /// Una variabile mal scritta non ferma l'app: spegne il catalogo, e
  /// [onProblem] lo dice.
  factory CatalogConfig.parse(String urls, String keys, {void Function(String problem)? onProblem}) {
    final parsedUrls = parseCatalogUrls(urls, onError: onProblem);
    final parsedKeys = parseCatalogKeys(keys, onError: onProblem);
    if (parsedUrls.isEmpty || parsedKeys.isEmpty) return const CatalogConfig();
    return CatalogConfig(urls: parsedUrls, keys: parsedKeys);
  }

  /// Quella scelta da chi ha compilato.
  static final CatalogConfig environment = CatalogConfig.parse(
    const String.fromEnvironment('CATALOG_URLS'),
    const String.fromEnvironment('CATALOG_KEYS'),
  );

  final List<Uri> urls;
  final Map<String, RsaKey> keys;

  bool get isConfigured => urls.isNotEmpty && keys.isNotEmpty;
}
