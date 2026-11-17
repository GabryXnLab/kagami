/// Ciò che ogni sito deve dare all'archivio, e la forma comune dei metadati.
///
/// È il porting di `mangaarchive/model.py` di cobalt-extended: server e
/// telefono scrivono nella stessa libreria, quindi gli stessi campi devono
/// uscire uguali dai due lati. Chi cambia qualcosa qui lo cambia anche là.
library;

import 'dart:async';

/// Un sito che non risponde come dovrebbe, o un link che non è suo.
///
/// Non è un guasto dell'app: è ciò che l'utente legge, e il capitolo resta
/// da ritentare.
class ProviderError implements Exception {
  const ProviderError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// La pagina del sito non ha la forma che il provider si aspetta: il sito è
/// cambiato e il provider va aggiornato. Non dipende dalla serie, quindi
/// vale per tutto il sito ([SiteHealth]).
class ProviderChanged extends ProviderError {
  const ProviderChanged(super.message, {this.fault});

  /// Dove la definizione del sito è rimasta senza valore (`docs/siti.md`,
  /// «Diagnosi»). Facoltativo: non viaggia fra server e app, che si dicono
  /// solo il messaggio.
  final SiteFault? fault;
}

/// Le operazioni in cui un valore può mancare.
const List<String> sitePhases = ['search', 'series', 'chapters', 'pages', 'image'];

/// Il guasto di un [ProviderChanged]: in quale operazione, quale campo della
/// definizione (`series.title`, `chapter.pages.url`) e cosa è arrivato.
class SiteFault {
  SiteFault(this.phase, {this.field, String? detail, this.url})
      : assert(sitePhases.contains(phase)),
        detail = detail == null ? null : _clip(detail);

  final String phase;
  final String? field;

  /// Al più [maxDetail] caratteri, a capo ridotti a spazi: finisce in avvisi e log.
  final String? detail;
  final String? url;

  static const int maxDetail = 200;

  static String _clip(String text) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= maxDetail ? flat : '${flat.substring(0, maxDetail - 1)}…';
  }

  @override
  String toString() => [phase, ?field, ?detail].join(' · ');
}

/// Quanti capitoli (5% arrotondato per eccesso, quindi almeno 1 se ce ne sono)
/// può avere in meno di [declared] un elenco che resta valido:
/// i buchi di numerazione sono del sito, un taglio vero (paginazione, `limit`)
/// toglie molto più del 5%. Oltre questa soglia l'elenco è un guasto.
int chaptersTolerance(int declared) => (declared * 0.05).ceil();

/// La traccia di un'operazione su un sito dichiarativo (`docs/siti.md`,
/// «Traccia e sito degradato»): quali `first` e `try` hanno vinto con
/// un'alternativa che non è la prima. Non cambia l'esito; la leggono la sonda
/// e `tool/site.dart check`.
///
/// Viaggia in una zona invece che come parametro o campo del provider:
/// l'interfaccia [Provider] è comune ai siti Dart, all'archiviatore e al server,
/// e un campo con «l'ultima traccia» sarebbe condiviso fra operazioni
/// concorrenti sulla stessa istanza (il server ne fa girare più d'una). La
/// zona segue le continuazioni asincrone della sola operazione avviata da
/// [run], e chi non la chiede non paga niente: l'interprete la cerca solo
/// quando vince un'alternativa diversa dalla prima.
class SiteTrace {
  final Set<String> _degraded = {};

  static final Object _key = Object();

  /// L'id della serie letto dalla pagina con `series.id`, anche se poi
  /// l'operazione fallisce: il ripiego sull'incluso lo confronta con il suo
  /// (`fallback.dart`). `null` se la pagina non l'ha dato.
  String? seriesId;

  /// La traccia dell'operazione in corso, `null` se nessuno l'ha chiesta.
  static SiteTrace? get current => Zone.current[_key] as SiteTrace?;

  /// Esegue [operation] (`fetchSeries`, `fetchPages`, `search` di un provider)
  /// registrando qui le alternative vincenti.
  Future<T> run<T>(Future<T> Function() operation) => runZoned(operation, zoneValues: {_key: this});

  /// [field] ha dato il valore con l'alternativa [alternative], contata da 1.
  void note(String field, int alternative) {
    if (alternative > 1) _degraded.add('$field#$alternative');
  }

  /// [field] non ha dato un valore che il file si aspetta e senza cui un
  /// controllo si salta (`expect`): si segna senza numero d'alternativa.
  void missing(String field) => _degraded.add(field);

  /// Le voci di [other]: la traccia di un blocco di riserva (o del principale)
  /// che è riuscito. Quelle di un blocco fallito non si prendono, perché il
  /// suo esito non conta.
  void absorb(SiteTrace other) => _degraded.addAll(other._degraded);

  /// `percorso#n` dei punti vinti da un'alternativa non prima, ordinati e
  /// senza doppioni: vuoto se il sito ha risposto nella forma principale.
  List<String> get degraded => _degraded.toList()..sort();

  bool get isDegraded => _degraded.isNotEmpty;
}

const int metadataSchemaVersion = 2;

const List<String> releaseStatuses = [
  'ongoing',
  'completed',
  'hiatus',
  'cancelled',
  'unknown',
];

const List<String> _listFields = [
  'artists',
  'authors',
  'tags',
  'genres',
  'alternativeTitles',
];

/// I campi che `metadata` ha sempre, nell'ordine in cui il server li scrive.
const List<String> metadataFields = [
  'description',
  'artists',
  'authors',
  'tags',
  'genres',
  'status',
  'alternativeTitles',
  'type',
  'language',
  'publishedAt',
  'updatedAt',
  'releaseStatus',
];

const List<(String, List<String>)> _releaseMarkers = [
  ('completed', ['completed', 'completo', 'completa', 'finished', 'ended', 'end', 'concluso', 'concluded', 'fine']),
  ('cancelled', ['cancelled', 'canceled', 'cancellato', 'dropped', 'abandoned']),
  ('hiatus', ['hiatus', 'pausa', 'paused', 'on hold', 'onhold', 'sospeso']),
  ('ongoing', ['ongoing', 'on going', 'in corso', 'incorso', 'publishing', 'releasing', 'serializing', 'in arrivo', 'continua', 'active']),
];

const Map<String, List<String>> _aliases = {
  'description': ['description', 'summary', 'synopsis'],
  'artists': ['artist', 'artists', 'illustrator', 'illustrators'],
  'authors': ['author', 'authors', 'writer', 'writers'],
  'tags': ['tag', 'tags', 'category', 'categories', 'keyword', 'keywords'],
  'genres': ['genre', 'genres'],
  'status': ['status'],
  'alternativeTitles': ['alternative', 'alternatives', 'alternativetitle', 'alternativetitles', 'othertitle', 'othertitles', 'othername', 'othernames', 'altname', 'altnames'],
  'type': ['type'],
  'language': ['language', 'lang'],
  'publishedAt': ['published', 'publishedat', 'released', 'release', 'releasedate', 'date', 'createdat'],
  'updatedAt': ['updated', 'updatedat', 'modified', 'modifiedat'],
};

String _key(String value) => value.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '');

List<String> metadataStrings(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? const [] : [trimmed];
  }
  if (value is Map) {
    for (final name in const ['name', 'title', 'label', 'value']) {
      if (value.containsKey(name)) return metadataStrings(value[name]);
    }
    return const [];
  }
  if (value is List) return [for (final item in value) ...metadataStrings(item)];
  if (value is num) return ['$value'];
  return const [];
}

/// Sinonimi espliciti delle etichette, per chiave (minuscole, solo lettere e
/// cifre): ciò che i siti scrivono in grafie diverse e che è lo stesso genere.
const Map<String, String> _labelSynonyms = {
  'scifi': 'Sci-Fi',
  'sciencefiction': 'Sci-Fi',
  'shonen': 'Shounen',
  'shounen': 'Shounen',
  'shojo': 'Shoujo',
  'shoujo': 'Shoujo',
  'fullcolor': 'Full Color',
  'fullcolour': 'Full Color',
};

const Set<String> _smallWords = {'of', 'the', 'a', 'an', 'and', 'in', 'to', 'no', 'on'};

/// L'etichetta di un genere o tag in forma leggibile e uguale per tutti i
/// siti: spazi compressi, uno slug («overpowered-male-lead») o un testo tutto
/// minuscolo diventa «Overpowered Male Lead», i sinonimi noti si unificano.
String canonicalLabel(String label) {
  var text = label.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return text;
  final synonym = _labelSynonyms[_key(text)];
  if (synonym != null) return synonym;
  if (RegExp(r'^[a-z0-9]+([-_][a-z0-9]+)+$').hasMatch(text)) {
    text = text.replaceAll(RegExp('[-_]'), ' ');
  }
  if (text == text.toLowerCase()) {
    final words = text.split(' ');
    text = [
      for (var i = 0; i < words.length; i++)
        if (words[i].isEmpty || (i > 0 && _smallWords.contains(words[i])))
          words[i]
        else
          words[i][0].toUpperCase() + words[i].substring(1),
    ].join(' ');
  }
  return _labelSynonyms[_key(text)] ?? text;
}

/// Le etichette in forma canonica, senza doppioni fra maiuscole e minuscole.
List<String> canonicalLabels(Iterable<String> labels) =>
    _unique([for (final l in labels) canonicalLabel(l)].where((l) => l.isNotEmpty));

/// La famiglia («manga», «manhwa», «manhua») che [type] nomina, o null. Le
/// parole di famiglia sono quelle di `kindOf` dell'app, che la usa.
String? typeFamily(String? type) {
  if (type == null) return null;
  final t = type.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  bool has(List<String> words) => words.any(t.contains);
  if (has(const ['manhwa', 'webtoon', 'korean'])) return 'manhwa';
  if (has(const ['manhua', 'chinese'])) return 'manhua';
  if (has(const ['manga', 'japanese', 'doujin'])) return 'manga';
  return null;
}

/// Il `type` canonico: la famiglia se il sito ne dà una («Webtoon» è
/// «manhwa»), altrimenti il testo minuscolo; se manca, la famiglia che
/// [hints] (generi e tag) nominano per intero.
String? canonicalType(String? type, [Iterable<String> hints = const []]) {
  final text = type?.trim() ?? '';
  if (text.isNotEmpty) return typeFamily(text) ?? text.toLowerCase();
  for (final family in const ['manhwa', 'manhua', 'manga']) {
    if (hints.any((h) => _key(h) == family || (family == 'manhwa' && _key(h) == 'webtoon'))) {
      return family;
    }
  }
  return null;
}

List<String> _unique(Iterable<String> values) {
  final seen = <String>{};
  return [for (final value in values) if (seen.add(value.toLowerCase())) value];
}

/// Lo stato canonico dal testo libero del sito: i siti scrivono lo stesso
/// stato in decine di modi, e la libreria deve distinguere una serie in corso
/// da una conclusa senza reinterpretarli.
String releaseStatus(Object? value) {
  final text = metadataStrings(value).join(' ').toLowerCase();
  if (text.isEmpty) return 'unknown';
  for (final (status, markers) in _releaseMarkers) {
    if (markers.any(text.contains)) return status;
  }
  return 'unknown';
}

/// `type`, generi e tag insieme, in forma canonica: è ciò che chi scrive
/// registra e ciò che chi legge applica a una voce già scritta.
({String? type, List<String> genres, List<String> tags}) canonicalClassification({
  String? type,
  Iterable<String> genres = const [],
  Iterable<String> tags = const [],
}) {
  final g = canonicalLabels(genres);
  final t = canonicalLabels(tags);
  final canonical = canonicalType(type, [...g, ...t]);
  final family = typeFamily(canonical);
  if (family != null && !g.any((x) => x.toLowerCase() == family)) {
    g.add(family[0].toUpperCase() + family.substring(1));
  }
  final inGenres = {for (final x in g) x.toLowerCase()};
  return (
    type: canonical,
    genres: g,
    tags: [for (final x in t) if (!inGenres.contains(x.toLowerCase())) x],
  );
}

/// I metadati nella forma neutra che ogni manifest conserva.
///
/// `source` resta accanto ai valori normalizzati: i siti danno spesso campi
/// utili che non si lasciano ricondurre a un vocabolario comune, e tenerli
/// evita di perdere dati archiviandoli.
Map<String, Object?> normalizeMetadata(Map<String, Object?>? raw) {
  final source = {...?raw};
  final byKey = <String, List<Object?>>{};
  for (final MapEntry(:key, :value) in source.entries) {
    byKey.putIfAbsent(_key(key), () => []).add(value);
  }
  final normalized = <String, Object?>{};
  for (final field in metadataFields) {
    final aliases = _aliases[field];
    if (aliases == null) continue;
    final values = [for (final alias in aliases) ...?byKey[_key(alias)]];
    final texts = [for (final value in values) ...metadataStrings(value)];
    normalized[field] = _listFields.contains(field)
        ? _unique(texts)
        : texts.firstOrNull;
  }
  final c = canonicalClassification(
    type: normalized['type'] as String?,
    genres: normalized['genres'] as List<String>,
    tags: normalized['tags'] as List<String>,
  );
  normalized['genres'] = c.genres;
  normalized['tags'] = c.tags;
  normalized['type'] = c.type;
  normalized['releaseStatus'] = releaseStatus(normalized['status']);
  normalized['source'] = source;
  return normalized;
}

class Chapter {
  const Chapter(this.id, this.title, this.number, this.url, [this.metadata = const {}]);

  final String id;
  final String title;
  final String number;
  final String url;
  final Map<String, Object?> metadata;
}

class Series {
  const Series({
    required this.provider,
    required this.id,
    required this.title,
    required this.url,
    required this.coverUrl,
    required this.metadata,
    required this.chapters,
  });

  final String provider;
  final String id;
  final String title;
  final String url;
  final String? coverUrl;
  final Map<String, Object?> metadata;
  final List<Chapter> chapters;

  /// La chiave MALF: è l'identità della serie in libreria.
  String get key => '$provider:$id';
}

class Page {
  const Page(this.url, [this.width, this.height]);

  final String url;
  final int? width;
  final int? height;
}

class ChapterContent {
  const ChapterContent(this.pages, this.metadata);

  final List<Page> pages;
  final Map<String, Object?> metadata;
}
