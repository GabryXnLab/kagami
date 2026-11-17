import 'package:kagami_archive/elsewhere.dart' show titleKey;
import 'package:kagami_archive/providers.dart' show SearchResult;

/// Mescola i risultati di tutti i siti in una lista sola, dal più pertinente.
///
/// [perSite] ha una lista per sito, nell'ordine di `providers`. Pertinenza,
/// dalla più forte: titolo uguale al testo cercato (a meno di maiuscole e
/// punteggiatura), titolo che inizia con il testo, tutte le parole cercate
/// presenti come parole intere, alcune presenti, resto. A parità vince il
/// titolo trovato su più siti, poi la posizione che il sito gli dava, poi
/// l'ordine dei siti. Le copie dello stesso titolo stanno una dopo l'altra,
/// nella posizione della migliore.
List<SearchResult> rankSearchResults(String query, List<List<SearchResult>> perSite) {
  final queryKey = titleKey(query);
  final queryWords = _words(query);
  final groups = <String, List<_Entry>>{};
  var unique = 0;
  for (var site = 0; site < perSite.length; site++) {
    for (var index = 0; index < perSite[site].length; index++) {
      final result = perSite[site][index];
      final key = titleKey(result.title);
      // Un titolo senza lettere né cifre non si fonde con altri.
      groups.putIfAbsent(key.isEmpty ? '#${unique++}' : key, () => []).add(_Entry(result, site, index));
    }
  }
  final ranked = [
    for (final entry in groups.entries)
      _Group(
        [...entry.value]..sort(_bySite),
        _relevance(queryKey, queryWords, entry.value.map((e) => e.result.title)),
        {for (final e in entry.value) e.site}.length,
      ),
  ]..sort((a, b) {
      final byRelevance = b.relevance.compareTo(a.relevance);
      if (byRelevance != 0) return byRelevance;
      final bySites = b.sites.compareTo(a.sites);
      if (bySites != 0) return bySites;
      return _bySite(a.best, b.best) == 0 ? 0 : (a.best.index != b.best.index ? a.best.index.compareTo(b.best.index) : a.best.site.compareTo(b.best.site));
    });
  return [for (final group in ranked) for (final entry in group.entries) entry.result];
}

int _bySite(_Entry a, _Entry b) => a.site != b.site ? a.site.compareTo(b.site) : a.index.compareTo(b.index);

class _Entry {
  const _Entry(this.result, this.site, this.index);
  final SearchResult result;
  final int site;
  final int index;
}

class _Group {
  _Group(this.entries, this.relevance, this.sites)
      : best = ([...entries]..sort((a, b) => a.index != b.index ? a.index.compareTo(b.index) : a.site.compareTo(b.site))).first;
  final List<_Entry> entries;
  final int relevance;
  final int sites;
  final _Entry best;
}

List<String> _words(String text) =>
    text.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((word) => word.isNotEmpty).toList();

int _relevance(String queryKey, List<String> queryWords, Iterable<String> titles) {
  var best = 0;
  for (final title in titles) {
    final key = titleKey(title);
    final int score;
    if (queryKey.isEmpty) {
      score = 0;
    } else if (key == queryKey) {
      score = 4;
    } else if (key.startsWith(queryKey)) {
      score = 3;
    } else {
      final words = _words(title).toSet();
      final found = queryWords.where(words.contains).length;
      score = found == 0 ? 0 : found == queryWords.length ? 2 : 1;
    }
    if (score > best) best = score;
  }
  return best;
}
