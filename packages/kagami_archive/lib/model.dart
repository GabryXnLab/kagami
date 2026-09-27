/// Ciò che ogni sito deve dare all'archivio, e la forma comune dei metadati.
///
/// È il porting di `mangaarchive/model.py` di cobalt-extended: server e
/// telefono scrivono nella stessa libreria, quindi gli stessi campi devono
/// uscire uguali dai due lati. Chi cambia qualcosa qui lo cambia anche là.
library;

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
