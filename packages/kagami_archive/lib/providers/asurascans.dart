/// Asura Scans: tutto dall'API pubblica che usa il sito, `api.asurascans.com`.
///
/// Le pagine sono Astro e portano gli stessi dati nelle proprietà delle
/// isole, ma l'API li dà interi e in JSON: la serie, l'elenco completo dei
/// capitoli e, per ognuno, le tavole con le loro misure. Niente Cloudflare.
///
/// Gli indirizzi del sito finiscono con un suffisso che cambia
/// (`/comics/nano-machine-bd5bdaf8`) e che il sito ridirige da qualsiasi
/// altro valore, anche nessuno: l'identità della serie è lo slug dell'API, e
/// il link che resta in libreria è senza suffisso.
library;

import '../http.dart';
import '../model.dart';
import '../providers.dart';
import 'kit.dart';

const Set<String> _siteHosts = {'asurascans.com', 'www.asurascans.com'};
const String _api = 'https://api.asurascans.com/api';

final RegExp _seriesPath = RegExp(r'^/comics/([a-z0-9]+(?:-[a-z0-9]+)*)/?$');

/// Il suffisso che il sito appende allo slug nei suoi link.
final RegExp _chapterPath =
    RegExp(r'^/comics/([a-z0-9]+(?:-[a-z0-9]+)*)/chapter/([0-9]+(?:\.[0-9]+)?)/?$');

final RegExp _suffix = RegExp(r'-[0-9a-f]{8}$');

final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

class AsuraScans extends Provider {
  @override
  String get id => 'asurascans';

  @override
  String get name => 'Asura Scans';

  @override
  String get home => 'https://asurascans.com';

  @override
  bool accepts(String url) => siteLink(url, hosts: _siteHosts, path: _seriesPath, plain: true);

  @override
  bool allowedHost(Uri uri) =>
      _siteHosts.contains(uri.host) ||
      const {'api.asurascans.com', 'cdn.asurascans.com'}.contains(uri.host);

  @override
  String? seriesOfChapter(String url) {
    final found = siteMatch(url, hosts: _siteHosts, path: _chapterPath);
    return found == null ? null : '$home/comics/${found[1]!.replaceFirst(_suffix, '')}';
  }

  /// Il capitolo sta sotto lo slug senza suffisso, come lo elenca l'API.
  @override
  String chapterKeyOf(String url) {
    final key = chapterKey(url);
    final found = _chapterPath.firstMatch(Uri.parse(key).path);
    return found == null ? key : chapterKey('$home/comics/${found[1]!.replaceFirst(_suffix, '')}/chapter/${found[2]}');
  }

  String _segment(String url) => _seriesPath.firstMatch(Uri.parse(url).path)![1]!;

  @override
  String canonical(String url) => '$home/comics/${_segment(url).replaceFirst(_suffix, '')}';

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) async {
    if (!accepts(url)) throw const ProviderError('Inserisci il link di una serie Asura Scans.');
    final segment = _segment(url);
    final stripped = segment.replaceFirst(_suffix, '');
    // Uno slug che finisce davvero con otto cifre esadecimali non ha
    // suffisso: se senza non lo trova, si riprova com'era nel link.
    Map<String, Object?>? response;
    for (final slug in {stripped, segment}) {
      try {
        response = await http.json('$_api/series/$slug');
        break;
      } on HttpStatusError catch (error) {
        if (error.status != 404) rethrow;
      }
    }
    final series = response?['series'];
    if (series is! Map<String, Object?> || !isText(series['slug']) || !isText(series['title'])) {
      throw const ProviderError('Serie Asura Scans non trovata.');
    }
    final slug = series['slug'] as String;
    if (!_slugPattern.hasMatch(slug)) throw const ProviderError('Serie Asura Scans non valida.');
    final listing = await http.json('$_api/series/$slug/chapters');
    final raw = listing['data'];
    if (raw is! List) throw const ProviderError('Elenco dei capitoli Asura Scans non disponibile.');
    final chapters = <Chapter>[];
    for (final item in raw.reversed) {
      if (item is! Map<String, Object?> ||
          item['id'] is! int ||
          item['number'] is! num ||
          !isText(item['slug']) ||
          !_slugPattern.hasMatch(item['slug'] as String)) {
        throw const ProviderError('Capitolo Asura Scans incompleto.');
      }
      // Un capitolo in accesso anticipato non ha tavole per chi non paga:
      // resta fuori finché non si libera, e allora arriva come capitolo nuovo.
      if (item['is_premium'] == true) continue;
      final number = numberLabel(item['number'] as num);
      final title = item['title'];
      chapters.add(Chapter(
        '${item['id']}',
        isText(title) ? 'Chapter $number - $title' : 'Chapter $number',
        number,
        '$home/comics/$slug/chapter/$number',
        item,
      ));
    }
    if (chapters.isEmpty) throw const ProviderError('Nessun capitolo Asura Scans disponibile.');
    requireUniqueIds(chapters, 'Asura Scans');
    final cover = series['cover'];
    if (isText(cover)) validateUrl(cover as String);
    final description = series['description'];
    return Series(
      provider: id,
      id: slug,
      title: series['title'] as String,
      url: '$home/comics/$slug',
      coverUrl: isText(cover) ? cover as String : null,
      metadata: {
        // `created_at` è sempre l'anno 1: passerebbe per la data d'uscita.
        ...withoutKeys(series, const {
          'alt_titles', 'alternative_titles', 'description', 'created_at', 'public_url', 'source_url',
        }),
        if (isText(description)) 'description': htmlText(description as String),
        'alternativeTitles': series['alt_titles'] ?? series['alternative_titles'],
      },
      chapters: chapters,
    );
  }

  /// La stessa API della barra di ricerca del sito.
  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) async {
    final response = await http.json(Uri.https('api.asurascans.com', '/api/search', {
      'q': query.trim(),
    }).toString());
    final items = response['data'];
    if (items is! List) throw const ProviderError('Risposta della ricerca Asura Scans cambiata.');
    final results = <SearchResult>[];
    for (final item in items) {
      if (item is! Map<String, Object?> || !isText(item['title']) || !isText(item['slug'])) continue;
      // La ricerca del sito dà anche i romanzi, che qui non si leggono.
      if (item['type'] == 'novel') continue;
      final url = '$home/comics/${item['slug']}';
      if (!accepts(url)) continue;
      final cover = item['cover'] ?? item['cover_url'];
      final count = item['chapter_count'];
      results.add(SearchResult(
        provider: id,
        title: item['title'] as String,
        url: url,
        coverUrl: isText(cover) && allows(cover as String) ? cover : null,
        chapters: count is int ? count : null,
        releaseStatus: releaseStatus(item['status']),
      ));
      if (results.length == searchLimit) break;
    }
    return results;
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) async {
    final series = chapter.metadata['series_slug'];
    final slug = chapter.metadata['slug'];
    if (!isText(series) || !isText(slug)) {
      throw ProviderError('Capitolo Asura Scans senza indirizzo: ${chapter.title}.');
    }
    final response = await http.json('$_api/series/$series/chapters/$slug');
    final data = response['data'];
    final raw = data is Map<String, Object?> ? data['chapter'] : null;
    if (raw is! Map<String, Object?> || '${raw['id']}' != chapter.id) {
      throw ProviderError('Capitolo non corrispondente: ${chapter.title}.');
    }
    if (data is Map && data['is_locked'] == true) {
      throw ProviderError('Capitolo riservato agli abbonati di Asura Scans: ${chapter.title}.');
    }
    final images = raw['pages'];
    if (images is! List || images.isEmpty) {
      throw ProviderError('Elenco immagini incompleto: ${chapter.title}.');
    }
    final pages = <Page>[];
    for (final image in images) {
      final url = image is Map ? image['url'] : null;
      if (url is! String) throw ProviderError('Pagina non coerente: ${chapter.title}.');
      validateUrl(url);
      pages.add(Page(
        url,
        image['width'] is int ? image['width'] as int : null,
        image['height'] is int ? image['height'] as int : null,
      ));
    }
    return ChapterContent(pages, withoutKeys(raw, const {'pages'}));
  }
}
