/// Il catalogo dei siti: definizioni firmate da chi compila, pubblicate a un
/// indirizzo che l'app e il server ricontrollano. Il formato è in
/// `docs/catalogo.md`, che è l'originale.
///
/// Qui c'è solo la parte pura: configurazione, firma, indice, scelta della
/// variante e adozione. Rete e disco li mette chi chiama (app e server), così
/// le regole sono le stesse per tutti e due.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'declarative.dart';
import 'signature.dart';

/// Quante primitive del formato dei siti sa interpretare questo motore
/// (`docs/catalogo.md`, «engine e varianti»; la tabella è in `docs/siti.md`,
/// «Compatibilità ed engine»): il formato 1, variabili e modelli, ripieghi, link canonico,
/// conteggio dichiarato, blocchi di riserva e la ricetta (passi, codifiche,
/// aritmetica e scelta, ripetizione, crittografia, richieste) e la pagina resa.
const int catalogEngine = 16;

/// La versione del formato dell'indice che questo cliente conosce.
const int catalogFormat = 1;

const int maxCatalogIndexBytes = 1024 * 1024;
const int maxCatalogSiteBytes = 256 * 1024;
const int maxCatalogSites = 200;
const int maxCatalogVariants = 8;
const int maxCatalogMessage = 300;

/// `index.sig` ha poche righe da ~520 caratteri: un file enorme di righe
/// false costerebbe una `modPow` ciascuna, quindi si rifiuta prima.
const int maxCatalogSignatureBytes = 64 * 1024;

/// Sotto questa misura una chiave si scarta (`docs/catalogo.md`, «Facoltativo»).
const int minCatalogKeyBits = 3072;

final RegExp _kidPattern = RegExp(r'^[a-z0-9-]{1,32}$');
final RegExp _base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');
final RegExp _siteIdPattern = RegExp(r'^[a-z0-9]{1,32}$');
final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

List<int>? _base64Url(String text) {
  if (!_base64UrlPattern.hasMatch(text)) return null;
  try {
    return base64Url.decode(base64Url.normalize(text));
  } on FormatException {
    return null;
  }
}

/// Le chiavi pubbliche di `CATALOG_KEYS`, per `kid`. Una chiave mal scritta,
/// troppo corta o con un `kid` ripetuto si salta e si dice a [onError]: una
/// variabile sbagliata spegne al più il catalogo, mai l'app.
Map<String, RsaKey> parseCatalogKeys(String raw, {void Function(String problem)? onError}) {
  final keys = <String, RsaKey>{};
  for (final entry in raw.split(',')) {
    final text = entry.trim();
    if (text.isEmpty) continue;
    final parts = text.split('.');
    if (parts.length != 3 || !_kidPattern.hasMatch(parts[0])) {
      onError?.call('Chiave del catalogo mal scritta: «${parts.first}».');
      continue;
    }
    final kid = parts[0];
    final n = _base64Url(parts[1]);
    final e = _base64Url(parts[2]);
    if (n == null || e == null) {
      onError?.call('Chiave del catalogo «$kid»: modulo o esponente non in base64url.');
      continue;
    }
    final modulus = bytesToBig(n);
    final exponent = bytesToBig(e);
    if (modulus.bitLength < minCatalogKeyBits) {
      onError?.call('Chiave del catalogo «$kid»: ${modulus.bitLength} bit, ne servono almeno $minCatalogKeyBits.');
      continue;
    }
    if (exponent < BigInt.from(3) || exponent.isEven || exponent >= modulus) {
      onError?.call('Chiave del catalogo «$kid»: esponente non valido.');
      continue;
    }
    if (keys.containsKey(kid)) {
      onError?.call('Chiave del catalogo «$kid» ripetuta: vale la prima.');
      continue;
    }
    keys[kid] = (n: modulus, e: exponent);
  }
  return keys;
}

/// Gli indirizzi di `CATALOG_URLS`, nell'ordine: il primo è la fonte, gli altri
/// specchi. Solo `https`; gli altri si saltano e si dicono a [onError].
List<Uri> parseCatalogUrls(String raw, {void Function(String problem)? onError}) {
  final urls = <Uri>[];
  for (final entry in raw.split(',')) {
    final text = entry.trim();
    if (text.isEmpty) continue;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      onError?.call('Indirizzo del catalogo non valido (serve https): «$text».');
      continue;
    }
    urls.add(uri);
  }
  return urls;
}

/// Vero se almeno una riga di [signatureFile] (`<kid> <firma>`) ha un `kid` di
/// [keys] e una firma valida dei byte esatti di [indexBytes].
bool verifyCatalogSignature(List<int> indexBytes, List<int> signatureFile, Map<String, RsaKey> keys) {
  if (signatureFile.length > maxCatalogSignatureBytes) return false;
  final String text;
  try {
    text = utf8.decode(signatureFile);
  } on FormatException {
    return false;
  }
  for (final line in const LineSplitter().convert(text)) {
    final parts = line.trim().split(' ');
    if (parts.length != 2) continue;
    final key = keys[parts[0]];
    if (key == null) continue;
    final signature = _base64Url(parts[1]);
    if (signature != null && rsaVerify(key, indexBytes, signature)) return true;
  }
  return false;
}

/// Un indice che non si può adottare: il messaggio dice perché.
class CatalogFormatError implements Exception {
  const CatalogFormatError(this.message);

  final String message;

  @override
  String toString() => message;
}

enum CatalogSiteState { ok, broken }

class CatalogVariant {
  const CatalogVariant({required this.version, required this.minEngine, required this.sha256, required this.path});

  final int version;
  final int minEngine;
  final String sha256;
  final String path;
}

class CatalogSite {
  const CatalogSite({required this.id, required this.state, required this.variants, this.message, this.builtin = true});

  final String id;
  final CatalogSiteState state;
  final String? message;

  /// `false` con `builtin: "off"`: il registro non ripiega sull'incluso
  /// (`docs/catalogo.md` § «Il registro: chi vince»).
  final bool builtin;
  final List<CatalogVariant> variants;

  /// Fra le varianti con `minEngine ≤ engine` quella con la `version` più
  /// alta; `null` se nessuna (serve un motore più nuovo).
  CatalogVariant? choose({int engine = catalogEngine}) {
    CatalogVariant? best;
    for (final variant in variants) {
      if (variant.minEngine > engine) continue;
      if (best == null || variant.version > best.version) best = variant;
    }
    return best;
  }
}

class CatalogIndex {
  const CatalogIndex({required this.serial, required this.issuedAt, required this.sites});

  final int serial;
  final DateTime issuedAt;
  final Map<String, CatalogSite> sites;

  /// Legge `index.json`. I campi sconosciuti si ignorano; un campo noto
  /// mancante o di tipo sbagliato invalida l'indice intero
  /// ([CatalogFormatError]), come una versione del formato che non si conosce.
  static CatalogIndex parse(List<int> bytes) {
    if (bytes.length > maxCatalogIndexBytes) throw const CatalogFormatError('L\'indice del catalogo supera 1 MB.');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const CatalogFormatError('L\'indice del catalogo non è un JSON valido.');
    }
    if (json is! Map<String, Object?>) throw const CatalogFormatError('L\'indice del catalogo non è un oggetto.');
    final format = json['catalog'];
    if (format is! int) throw const CatalogFormatError('«catalog» manca o non è un intero.');
    if (format != catalogFormat) throw CatalogFormatError('Formato del catalogo $format sconosciuto.');
    final serial = json['serial'];
    if (serial is! int || serial < 0) throw const CatalogFormatError('«serial» manca o non è un intero positivo.');
    final issued = json['issuedAt'];
    final issuedAt = issued is String ? DateTime.tryParse(issued) : null;
    if (issuedAt == null) throw const CatalogFormatError('«issuedAt» manca o non è una data ISO 8601.');
    final sites = json['sites'];
    if (sites is! Map<String, Object?>) throw const CatalogFormatError('«sites» manca o non è un oggetto.');
    if (sites.length > maxCatalogSites) throw const CatalogFormatError('Il catalogo ha più di $maxCatalogSites siti.');
    return CatalogIndex(
      serial: serial,
      issuedAt: issuedAt.toUtc(),
      sites: Map.unmodifiable({for (final MapEntry(:key, :value) in sites.entries) key: _site(key, value)}),
    );
  }

  static CatalogSite _site(String id, Object? json) {
    if (!_siteIdPattern.hasMatch(id)) throw CatalogFormatError('Id di sito non valido: «$id».');
    if (json is! Map<String, Object?>) throw CatalogFormatError('Il sito «$id» non è un oggetto.');
    final state = switch (json['state']) {
      'ok' => CatalogSiteState.ok,
      'broken' => CatalogSiteState.broken,
      _ => throw CatalogFormatError('Il sito «$id» ha uno «state» diverso da ok e broken.'),
    };
    final message = json['message'];
    if (message != null && (message is! String || message.runes.length > maxCatalogMessage)) {
      throw CatalogFormatError('Il messaggio del sito «$id» non è un testo di al più $maxCatalogMessage caratteri.');
    }
    final builtin = switch (json['builtin']) {
      null || 'on' => true,
      'off' => false,
      _ => throw CatalogFormatError('Il sito «$id» ha un «builtin» diverso da on e off.'),
    };
    final variants = json['variants'];
    if (variants is! List<Object?> || variants.isEmpty || variants.length > maxCatalogVariants) {
      throw CatalogFormatError('Il sito «$id» deve avere da 1 a $maxCatalogVariants varianti.');
    }
    final read = [for (final variant in variants) _variant(id, variant)];
    if (read.map((variant) => variant.version).toSet().length != read.length) {
      throw CatalogFormatError('Il sito «$id» ha due varianti con la stessa versione.');
    }
    return CatalogSite(id: id, state: state, message: message as String?, builtin: builtin, variants: List.unmodifiable(read));
  }

  static CatalogVariant _variant(String id, Object? json) {
    if (json is! Map<String, Object?>) throw CatalogFormatError('Una variante del sito «$id» non è un oggetto.');
    final version = json['version'];
    final minEngine = json['minEngine'];
    final sha = json['sha256'];
    final path = json['path'];
    if (version is! int || version < 1) throw CatalogFormatError('Una variante del sito «$id» ha una «version» non valida.');
    if (minEngine is! int || minEngine < 1) throw CatalogFormatError('Una variante del sito «$id» ha un «minEngine» non valido.');
    if (sha is! String || !_sha256Pattern.hasMatch(sha)) {
      throw CatalogFormatError('Una variante del sito «$id» ha uno «sha256» non valido.');
    }
    if (path is! String || !_safePath(path)) throw CatalogFormatError('Una variante del sito «$id» ha un «path» non valido.');
    return CatalogVariant(version: version, minEngine: minEngine, sha256: sha, path: path);
  }

  /// Relativo alla cartella del catalogo: niente `/` iniziale, niente `..`,
  /// niente schemi, query o barre rovesciate che lo porterebbero altrove.
  static bool _safePath(String path) {
    if (path.isEmpty || path.startsWith('/') || path.contains('\\') || path.contains(':')) return false;
    if (path.contains('?') || path.contains('#') || path.contains('%')) return false;
    final segments = path.split('/');
    return segments.every((segment) => segment.isNotEmpty && segment != '.' && segment != '..');
  }
}

/// La definizione di un sito presa dal catalogo, com'è in cache.
class CatalogDefinition {
  const CatalogDefinition({required this.text, required this.sha256, required this.version});

  final String text;
  final String sha256;
  final int version;
}

/// Il catalogo adottato: ciò che chi chiama tiene in cache e passa al
/// controllo dopo.
class AdoptedCatalog {
  const AdoptedCatalog({required this.serial, required this.indexBytes, required this.definitions});

  final int serial;
  final List<int> indexBytes;

  /// Per id di sito, la definizione in uso. Un sito dell'indice che non ne ha
  /// nessuna buona qui manca: vale l'incluso, se c'è.
  final Map<String, CatalogDefinition> definitions;

  /// Le impronte da tenere in `sites/<sha256>.json`: le altre si cancellano.
  Set<String> get cachedShas => {for (final definition in definitions.values) definition.sha256};
}

/// I siti da passare a `installCatalogProviders` per [catalog], ognuno con la
/// sua voce dell'indice ([DeclarativeProvider.catalog]). Una definizione o una
/// voce della cache che non si legge più si salta, e [onError] lo dice: per
/// quel sito vale l'incluso, se c'è. Un indice illeggibile lancia
/// [CatalogFormatError], perché è la cache intera a essere guasta.
List<DeclarativeProvider> catalogProviders(AdoptedCatalog catalog, {void Function(String id, String problem)? onError}) {
  final index = CatalogIndex.parse(catalog.indexBytes);
  final sites = <DeclarativeProvider>[];
  for (final MapEntry(key: id, value: definition) in catalog.definitions.entries) {
    final site = index.sites[id];
    if (site == null) {
      onError?.call(id, 'Il sito non è nell\'indice adottato.');
      continue;
    }
    try {
      final provider = DeclarativeProvider.parse(definition.text, catalog: site);
      if (provider.id != id) {
        onError?.call(id, 'La definizione in cache è del sito ${provider.id}.');
        continue;
      }
      sites.add(provider);
    } on SiteDefinitionError catch (error) {
      onError?.call(id, error.message);
    }
  }
  return sites;
}

enum CatalogOutcome {
  /// Indice nuovo, adottato (anche se qualche sito ha tenuto la variante di prima).
  adopted,

  /// Stesso `serial`, stessi byte: niente di nuovo.
  unchanged,

  /// Firma assente o falsa: l'indirizzo vale come irraggiungibile.
  badSignature,

  /// Indice illeggibile, di un formato sconosciuto o oltre i tetti.
  invalid,

  /// `serial` minore di quello adottato, o uguale con byte diversi.
  rollback,
}

enum CatalogSiteProblem {
  /// Nessuna variante con `minEngine ≤ engine`: «serve Kagami più nuovo».
  needsNewerEngine,

  /// Il file non si è potuto chiedere (`fetchSite` ha dato `null`).
  unreachable,
  tooLarge,
  hashMismatch,

  /// Il file non è una definizione valida per l'interprete.
  invalid,

  /// `id` o `version` del file diversi da quelli dell'indice.
  mismatch,
}

class CatalogSiteResult {
  const CatalogSiteResult({required this.state, this.message, this.definition, this.problem, this.detail});

  final CatalogSiteState state;
  final String? message;

  /// La definizione in uso: la nuova, o quella di prima se la nuova non è
  /// passata, o `null` se non ce n'è nessuna buona.
  final CatalogDefinition? definition;

  /// Perché la variante scelta non è stata adottata; `null` se lo è.
  final CatalogSiteProblem? problem;
  final String? detail;
}

class CatalogAdoption {
  const CatalogAdoption({required this.outcome, required this.catalog, this.index, this.sites = const {}, this.detail});

  final CatalogOutcome outcome;

  /// Il catalogo da usare dopo: il nuovo se [outcome] è
  /// [CatalogOutcome.adopted], altrimenti quello di prima (anche `null`).
  final AdoptedCatalog? catalog;

  /// L'indice adottato, solo con [CatalogOutcome.adopted].
  final CatalogIndex? index;

  /// Per id di sito dell'indice nuovo, solo con [CatalogOutcome.adopted].
  final Map<String, CatalogSiteResult> sites;
  final String? detail;

  int get serial => catalog?.serial ?? 0;
}

/// Applica i passi 2-5 di «Adozione» (`docs/catalogo.md`) a un indice già
/// scaricato: firma, anti-rollback, poi sito per sito. [fetchSite] riceve il
/// `path` dell'indice e dà i byte del file, o `null` se non ha potuto
/// chiederlo: il sito allora tiene la definizione di prima, perché una lettura
/// fallita non è un sito sparito. Non scrive niente: chi chiama mette in cache
/// [CatalogAdoption.catalog] solo alla fine.
Future<CatalogAdoption> adoptCatalog({
  required AdoptedCatalog? previous,
  required List<int> indexBytes,
  required List<int> signatureBytes,
  required Map<String, RsaKey> keys,
  required Future<List<int>?> Function(String path) fetchSite,
  int engine = catalogEngine,
}) async {
  if (indexBytes.length > maxCatalogIndexBytes) {
    return CatalogAdoption(outcome: CatalogOutcome.invalid, catalog: previous, detail: 'L\'indice del catalogo supera 1 MB.');
  }
  if (!verifyCatalogSignature(indexBytes, signatureBytes, keys)) {
    return CatalogAdoption(outcome: CatalogOutcome.badSignature, catalog: previous);
  }
  final CatalogIndex index;
  try {
    index = CatalogIndex.parse(indexBytes);
  } on CatalogFormatError catch (error) {
    return CatalogAdoption(outcome: CatalogOutcome.invalid, catalog: previous, detail: error.message);
  }
  if (previous != null) {
    if (index.serial < previous.serial) {
      return CatalogAdoption(outcome: CatalogOutcome.rollback, catalog: previous, detail: 'serial ${index.serial} < ${previous.serial}');
    }
    if (index.serial == previous.serial) {
      final same = _sameBytes(indexBytes, previous.indexBytes);
      return CatalogAdoption(
        outcome: same ? CatalogOutcome.unchanged : CatalogOutcome.rollback,
        catalog: previous,
        detail: same ? null : 'serial ${index.serial} uguale con byte diversi',
      );
    }
  }
  final known = {for (final definition in previous?.definitions.values ?? const <CatalogDefinition>[]) definition.sha256: definition};
  final results = <String, CatalogSiteResult>{};
  final definitions = <String, CatalogDefinition>{};
  for (final site in index.sites.values) {
    final before = previous?.definitions[site.id];
    CatalogSiteResult kept(CatalogSiteProblem problem, [String? detail]) =>
        CatalogSiteResult(state: site.state, message: site.message, definition: before, problem: problem, detail: detail);
    final variant = site.choose(engine: engine);
    final CatalogSiteResult result;
    if (variant == null) {
      result = kept(CatalogSiteProblem.needsNewerEngine);
    } else if (known[variant.sha256] case final cached?) {
      result = CatalogSiteResult(state: site.state, message: site.message, definition: cached);
    } else {
      result = await _fetch(site, variant, fetchSite) ?? kept(CatalogSiteProblem.unreachable);
    }
    // Un file che non passa tiene la definizione di prima: [_fetch] non la conosce.
    final problem = result.problem;
    final adopted = problem == null ? result : kept(problem, result.detail);
    results[site.id] = adopted;
    if (adopted.definition case final definition?) definitions[site.id] = definition;
  }
  return CatalogAdoption(
    outcome: CatalogOutcome.adopted,
    catalog: AdoptedCatalog(serial: index.serial, indexBytes: List.unmodifiable(indexBytes), definitions: Map.unmodifiable(definitions)),
    index: index,
    sites: Map.unmodifiable(results),
  );
}

/// Scarica e verifica la variante: `null` se irraggiungibile, un risultato
/// senza definizione se il file non passa.
Future<CatalogSiteResult?> _fetch(CatalogSite site, CatalogVariant variant, Future<List<int>?> Function(String) fetchSite) async {
  CatalogSiteResult failed(CatalogSiteProblem problem, [String? detail]) =>
      CatalogSiteResult(state: site.state, message: site.message, problem: problem, detail: detail);
  final bytes = await fetchSite(variant.path);
  if (bytes == null) return null;
  if (bytes.length > maxCatalogSiteBytes) return failed(CatalogSiteProblem.tooLarge);
  if (sha256.convert(bytes).toString() != variant.sha256) return failed(CatalogSiteProblem.hashMismatch);
  final String text;
  final DeclarativeProvider provider;
  try {
    text = utf8.decode(bytes);
    provider = DeclarativeProvider.parse(text);
  } on FormatException {
    return failed(CatalogSiteProblem.invalid, 'Il file non è UTF-8.');
  } on SiteDefinitionError catch (error) {
    return failed(CatalogSiteProblem.invalid, error.message);
  }
  if (provider.id != site.id || provider.version != variant.version) {
    return failed(CatalogSiteProblem.mismatch, 'Il file dice ${provider.id} v${provider.version}, l\'indice ${site.id} v${variant.version}.');
  }
  return CatalogSiteResult(
    state: site.state,
    message: site.message,
    definition: CatalogDefinition(text: text, sha256: variant.sha256, version: variant.version),
  );
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
