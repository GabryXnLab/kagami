/// MangaK: pagine Next.js, API pubblica dei capitoli e immagini WebP.
///
/// L'HTML visibile mostra solo una parte delle pagine e dei capitoli: la
/// verità sta in `__NEXT_DATA__` della serie e di ogni capitolo, più l'elenco
/// completo che dà `api.mangak.io`.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../http.dart';
import '../model.dart';
import '../providers.dart';
import 'kit.dart';

final RegExp _nextData = RegExp(
  r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>',
  dotAll: true,
);
final RegExp _slug = RegExp(r'^/([a-z0-9]+(?:-[a-z0-9]+)*)/?$');
final RegExp _chapterSlug = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final RegExp _mediaHost = RegExp(r'^rx\.qvzr[a-z]\.org$');

Map<String, Object?> _payload(Uint8List body) {
  final found = _nextData.firstMatch(utf8.decode(body, allowMalformed: true));
  if (found == null) throw const ProviderError('Dati MangaK assenti dalla pagina.');
  try {
    final data = jsonDecode(found[1]!) as Map<String, Object?>;
    return (data['props'] as Map<String, Object?>)['pageProps'] as Map<String, Object?>;
  } on Object {
    throw const ProviderError('Formato della pagina MangaK cambiato.');
  }
}

class MangaK extends Provider {
  @override
  String get id => 'mangak';

  @override
  String get name => 'MangaK';

  @override
  String get home => 'https://mangak.io';

  @override
  bool accepts(String url) => siteLink(url, hosts: const {'mangak.io'}, path: _slug);

  @override
  bool allowedHost(Uri uri) =>
      const {'mangak.io', 'api.mangak.io', 'rx.resmk.org'}.contains(uri.host) ||
      _mediaHost.hasMatch(uri.host);

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) async {
    if (!accepts(url)) {
      throw const ProviderError('Inserisci il link della serie MangaK, non di un capitolo.');
    }
    final canonical = 'https://mangak.io${trimSlashes(Uri.parse(url).path)}';
    final data = _payload((await http.get(canonical)).body);
    final manga = data['initialManga'];
    if (manga is! Map<String, Object?> || !_present(manga['id']) || !_present(manga['name'])) {
      throw const ProviderError('Serie MangaK non trovata.');
    }
    var api = 'https://api.mangak.io/titles/${Uri.encodeComponent('${manga['id']}')}/chapters';
    if (manga['cv'] != null) api += '?cv=${Uri.encodeComponent('${manga['cv']}')}';
    final response = await http.json(api);
    final values = response['data'];
    final raw = response['success'] == true && values is Map ? values['chapters'] : null;
    if (raw is! List || raw.isEmpty) {
      throw const ProviderError('Elenco completo dei capitoli MangaK non disponibile.');
    }
    final seriesUrl = manga['url'];
    // Non tutti i capitoli sono `chapter-…`: Kidnapped Dragons ha un
    // `/notice` fra gli altri. Basta che stia subito sotto la serie.
    final prefix = '${seriesUrl is String ? trimSlashes(seriesUrl) : ''}/';
    final chapters = <Chapter>[];
    final seen = <String>{};
    for (final item in raw.reversed) {
      if (item is! Map<String, Object?> ||
          !isText(item['id']) ||
          !isText(item['name']) ||
          !isText(item['url'])) {
        throw const ProviderError('Capitolo MangaK incompleto.');
      }
      final chapterUrl = 'https://mangak.io${item['url']}';
      final itemUrl = item['url'] as String;
      if (!itemUrl.startsWith(prefix) ||
          !_chapterSlug.hasMatch(itemUrl.substring(prefix.length)) ||
          Uri.tryParse(chapterUrl)?.host != 'mangak.io' ||
          !seen.add(item['id'] as String)) {
        throw const ProviderError('Elenco capitoli MangaK incoerente.');
      }
      // `number` di MangaK è il posto nell'elenco, non il numero del
      // capitolo: resta nei metadati e basta. Un nome senza numero («Prologue»)
      // fa da numero, come su ManhwaRead.
      final name = item['name'] as String;
      chapters.add(Chapter(
        item['id'] as String,
        name,
        chapterNumber(name) ?? name,
        chapterUrl,
        item,
      ));
    }
    final stats = manga['stats'];
    final expected = stats is Map ? stats['chaptersCount'] : null;
    if (expected is int && expected != chapters.length) {
      throw ProviderError('Elenco incompleto: ${chapters.length} capitoli su $expected.');
    }
    final cover = manga['cover'];
    if (isText(cover)) validateUrl(cover as String);
    return Series(
      provider: id,
      id: '${manga['id']}',
      title: '${manga['name']}',
      url: canonical,
      coverUrl: isText(cover) ? cover as String : null,
      metadata: withoutKeys(manga, const {'chapters', 'latestComments', 'userBookmark', 'userHistory', 'userReview'}),
      chapters: chapters,
    );
  }

  /// La stessa API che interroga la barra di ricerca di mangak.io.
  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) async {
    final response = await http.json(Uri.https('api.mangak.io', '/titles/search', {
      'q': query.trim(),
      'limit': '$searchLimit',
    }).toString());
    final data = response['data'];
    final items = response['success'] == true && data is Map ? data['items'] : null;
    if (items is! List) throw const ProviderError('Risposta della ricerca MangaK cambiata.');
    final results = <SearchResult>[];
    for (final item in items) {
      if (item is! Map<String, Object?> || !isText(item['name']) || !isText(item['url'])) continue;
      final url = 'https://mangak.io${item['url']}';
      if (!accepts(url)) continue;
      final cover = item['cover'];
      final stats = item['stats'];
      // L'API risponde in snake_case; è il sito a passare al camelCase.
      final count = stats is Map ? stats['chapters_count'] ?? stats['chaptersCount'] : null;
      results.add(SearchResult(
        provider: id,
        title: item['name'] as String,
        url: url,
        coverUrl: isText(cover) && allows(cover as String) ? cover : null,
        chapters: count is int ? count : null,
        releaseStatus: releaseStatus(item['status']),
      ));
    }
    return results;
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) async {
    final data = _payload((await http.get(chapter.url)).body);
    final raw = data['initialChapter'];
    if (raw is! Map<String, Object?> || raw['id'] != chapter.id) {
      throw ProviderError('Capitolo non corrispondente: ${chapter.title}.');
    }
    final images = raw['images'];
    final details = raw['pages'];
    if (images is! List || images.isEmpty || details is! List || images.length != details.length) {
      throw ProviderError('Elenco immagini incompleto: ${chapter.title}.');
    }
    final pages = <Page>[];
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final detail = details[i];
      if (detail is! Map || image is! String || image != detail['url']) {
        throw ProviderError('Pagina non coerente: ${chapter.title}.');
      }
      validateUrl(image);
      pages.add(Page(
        image,
        detail['width'] is int ? detail['width'] as int : null,
        detail['height'] is int ? detail['height'] as int : null,
      ));
    }
    return ChapterContent(pages, withoutKeys(raw, const {'images', 'pages', 'latest_comments'}));
  }
}

bool _present(Object? value) =>
    value != null && value != false && value != '' && value != 0;
