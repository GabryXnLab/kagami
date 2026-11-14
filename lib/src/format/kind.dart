/// Famiglie di tipo di una serie, ricavate in lettura dal `type` di MALF, che
/// resta testo libero: ogni archiviatore scrive «Manhwa», «Webtoon» o
/// «Korean» a modo suo, e una raccolta deve poterli prendere tutti insieme.
enum SeriesKind { manga, manhwa, manhua, other }

/// La famiglia di [type]: minuscole e spazi tolti, poi per parola contenuta.
/// L'ordine conta: «manhwa» e «manhua» contengono «man» ma non «manga».
SeriesKind kindOf(String? type) {
  if (type == null) return SeriesKind.other;
  final t = type.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  bool has(List<String> words) => words.any(t.contains);
  if (has(const ['manhwa', 'webtoon', 'korean'])) return SeriesKind.manhwa;
  if (has(const ['manhua', 'chinese'])) return SeriesKind.manhua;
  if (has(const ['manga', 'japanese', 'doujin'])) return SeriesKind.manga;
  return SeriesKind.other;
}

/// La famiglia che porta il nome [value], se è il nome di una famiglia.
SeriesKind? kindNamed(String value) {
  final v = value.trim().toLowerCase();
  return SeriesKind.values.where((k) => k.name == v).firstOrNull;
}
