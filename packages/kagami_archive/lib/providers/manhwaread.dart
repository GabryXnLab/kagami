/// ManhwaRead: capitoli nella pagina della serie, tavole in `chapterData`.
///
/// La pagina della serie spesso è dietro la verifica di Cloudflare: il
/// provider lo dice con [CloudflareChallenge] e chi lo usa la fa superare in
/// una WebView, poi gli ripassa la pagina ([SnapshotHttp]). Le tavole invece
/// stanno su `manread.xyz`, che non chiede niente: quando anche la pagina di
/// un capitolo è bloccata, gli id della serie bastano a trovarle provando i
/// nomi in ordine ([_probeCdn]).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../http.dart';
import '../model.dart';
import '../providers.dart';

final RegExp _seriesPath = RegExp(r'^/manhwa/([a-z0-9]+(?:-[a-z0-9]+)*)/?$');
final RegExp _chapterData = RegExp(r'\bchapterData\s*=\s*');
final RegExp _postId = RegExp(r'\bpostid-(\d+)\b');

const Map<String, String> _labels = {
  'artist': 'artists', 'artists': 'artists', 'illustrator': 'artists',
  'illustrators': 'artists', 'author': 'authors', 'authors': 'authors',
  'writer': 'authors', 'writers': 'authors', 'tag': 'tags', 'tags': 'tags',
  'category': 'tags', 'categories': 'tags', 'genre': 'genres', 'genres': 'genres',
  'status': 'status', 'alternative': 'alternativeTitles',
  'alternative title': 'alternativeTitles', 'alternative titles': 'alternativeTitles',
  'other name': 'alternativeTitles', 'other names': 'alternativeTitles',
  'type': 'type', 'language': 'language', 'released': 'publishedAt',
  'release date': 'publishedAt', 'published': 'publishedAt', 'updated': 'updatedAt',
};

const Set<String> _listKeys = {'artists', 'authors', 'tags', 'genres', 'alternativeTitles'};

/// Gli elementi in ordine di documento, [root] compreso.
Iterable<dom.Element> _walk(dom.Element root) sync* {
  yield root;
  for (final child in root.children) {
    yield* _walk(child);
  }
}

/// Il testo come lo legge il server: le parti unite da uno spazio, poi gli
/// spazi compressi. `element.text` di `package:html` incolla i nodi senza
/// separarli, e `<a>Action</a><a>Fantasy</a>` diventerebbe una parola sola.
String _text(dom.Node node) => _raw(node).split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');

String _raw(dom.Node node) => node.nodes.map((child) {
      if (child is dom.Element) return _raw(child);
      if (child is dom.Text) return child.data;
      return '';
    }).join(' ');

Set<String> _classes(dom.Element element) =>
    (element.attributes['class'] ?? '').split(RegExp(r'\s+')).where((c) => c.isNotEmpty).toSet();

String? _label(String value) {
  final cleaned = value.replaceAll(RegExp(r'\([^)]*\)'), '').toLowerCase();
  final normalized = cleaned.replaceAll(RegExp('[^a-z0-9]+'), ' ').trim().split(RegExp(r'\s+')).join(' ');
  return _labels[normalized];
}

List<String> _split(String value) => value.split(RegExp(r'\s*,\s*'));

void _add(Map<String, Object?> metadata, String key, Iterable<String> raw) {
  final values = [for (final value in raw) if (value.trim().isNotEmpty) value.trim()];
  if (values.isEmpty) return;
  if (_listKeys.contains(key)) {
    final previous = metadata.putIfAbsent(key, () => <String>[]) as List<String>;
    for (final value in values) {
      if (!previous.contains(value)) previous.add(value);
    }
  } else {
    metadata.putIfAbsent(key, () => values.first);
  }
}

List<String> _names(Object? value) {
  if (value is String) return _split(value);
  if (value is Map) {
    final name = value['name'] ?? value['title'];
    return _names(name is String && name.isNotEmpty ? name : '');
  }
  if (value is List) return [for (final item in value) ..._names(item)];
  return const [];
}

/// Tutti i dettagli strutturati che la pagina espone: meta, JSON-LD e le
/// coppie etichetta-valore del corpo.
Map<String, Object?> _metadata(dom.Document document) {
  final metadata = <String, Object?>{};
  final root = document.documentElement;
  if (root == null) return metadata;
  final nodes = _walk(root).toList();
  for (final node in nodes) {
    final content = node.attributes['content'];
    if (node.localName != 'meta' || content == null || content.isEmpty) continue;
    final name = (node.attributes['name'] ?? node.attributes['property'] ?? '').toLowerCase();
    final value = content.trim();
    if (const {'description', 'og:description', 'twitter:description'}.contains(name)) {
      _add(metadata, 'description', [value]);
    } else if (const {'keywords', 'news_keywords', 'article:tag'}.contains(name)) {
      _add(metadata, 'tags', _split(value));
    } else if (const {'article:published_time', 'datepublished'}.contains(name)) {
      _add(metadata, 'publishedAt', [value]);
    } else if (const {'article:modified_time', 'datemodified'}.contains(name)) {
      _add(metadata, 'updatedAt', [value]);
    } else if (_label(name) case final target?) {
      _add(metadata, target, _split(value));
    }
  }
  for (final node in nodes) {
    if (node.localName != 'script' ||
        (node.attributes['type'] ?? '').toLowerCase() != 'application/ld+json') {
      continue;
    }
    final Object? value;
    try {
      value = jsonDecode(node.nodes.whereType<dom.Text>().map((t) => t.data).join());
    } on FormatException {
      continue;
    }
    for (final item in value is List ? value : [value]) {
      if (item is! Map) continue;
      _add(metadata, 'description', ['${item['description'] ?? ''}']);
      _add(metadata, 'authors', _names(item['author']));
      _add(metadata, 'artists', _names(item['artist']));
      _add(metadata, 'genres', _names(item['genre']));
      _add(metadata, 'tags', _names(item['keywords']));
      _add(metadata, 'publishedAt', _names(item['datePublished']));
      _add(metadata, 'updatedAt', _names(item['dateModified']));
    }
  }
  for (final node in nodes) {
    if (node.children.isNotEmpty) continue;
    final target = _label(_text(node));
    final parent = node.parent;
    if (target == null || parent == null || parent.children.first != node) continue;
    var container = parent;
    while (container.children.length == 1 && container.parent != null) {
      container = container.parent!;
    }
    final siblings = container.children.skip(1).toList();
    final values = <String>[];
    if (siblings.isEmpty) {
      final label = _text(node);
      var rest = _text(container);
      if (rest.startsWith(label)) rest = rest.substring(label.length);
      rest = rest.replaceFirst(RegExp(r'^[: ]+'), '').trim();
      if (rest.isNotEmpty) values.add(rest);
    } else {
      for (final sibling in siblings) {
        final links = [
          for (final child in _walk(sibling))
            if (child.localName == 'a' && _text(child).isNotEmpty) _text(child),
        ];
        values.addAll(links.isNotEmpty ? links : _split(_text(sibling)));
      }
    }
    _add(metadata, target, values);
  }
  return metadata;
}

/// Il valore JSON che comincia in [source] a [start], come `raw_decode`.
Object? _jsonPrefix(String source, int start) {
  var depth = 0;
  var inString = false;
  for (var i = start; i < source.length; i++) {
    final char = source[i];
    if (inString) {
      if (char == r'\') {
        i++;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{' || char == '[') {
      depth++;
    } else if (char == '}' || char == ']') {
      depth--;
      if (depth == 0) return jsonDecode(source.substring(start, i + 1));
    } else if (depth == 0 && char.trim().isNotEmpty) {
      break;
    }
  }
  throw const FormatException('JSON non chiuso');
}

class ManhwaRead extends Provider {
  @override
  String get id => 'manhwaread';

  @override
  String get name => 'ManhwaRead';

  @override
  String get home => 'https://manhwaread.com';

  @override
  bool get needsBrowser => true;

  @override
  bool accepts(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        const {'manhwaread.com', 'www.manhwaread.com'}.contains(uri.host) &&
        !uri.hasPort &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        _seriesPath.hasMatch(uri.path);
  }

  @override
  bool allowedHost(Uri uri) =>
      const {'manhwaread.com', 'www.manhwaread.com', 'manread.xyz', 'mancover.xyz'}
          .contains(uri.host);

  /// L'indirizzo della serie nella forma che il sito usa per sé.
  String canonical(String url) =>
      'https://manhwaread.com/manhwa/${_seriesPath.firstMatch(Uri.parse(url).path)![1]}/';

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) async {
    if (!accepts(url)) throw const ProviderError('Inserisci il link di una serie ManhwaRead.');
    final slug = _seriesPath.firstMatch(Uri.parse(url).path)![1]!;
    final canonicalUrl = canonical(url);
    final Uint8List body;
    try {
      body = (await http.get(canonicalUrl)).body;
    } on HttpStatusError catch (error) {
      if (error.status == 403) throw const CloudflareChallenge();
      rethrow;
    }
    final text = utf8.decode(body, allowMalformed: true);
    final document = html.parse(text);
    final root = document.documentElement!;
    final nodes = _walk(root).toList();
    final base = Uri.parse(canonicalUrl);
    final canonicalLinks = [
      for (final node in nodes)
        if (node.localName == 'link' && node.attributes['rel'] == 'canonical')
          base.resolve(node.attributes['href'] ?? '').toString(),
    ];
    String trim(String value) => value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    if (canonicalLinks.isNotEmpty &&
        !canonicalLinks.map(trim).contains(trim(canonicalUrl))) {
      throw const ProviderError('La pagina appartiene a un’altra serie ManhwaRead.');
    }
    final mangaId = _postId.firstMatch(text)?[1];
    final headings = nodes.where((node) => node.localName == 'h1').toList();
    final preferred = headings.where((node) =>
        _classes(node).intersection(const {'text-primary', 'clipboard-copy', 'entry-title'}).isNotEmpty);
    final title = [...preferred, ...headings].map(_text).firstWhere((t) => t.isNotEmpty, orElse: () => '');
    if (title.isEmpty) throw const ProviderError('Titolo ManhwaRead assente dalla pagina.');
    String? cover = nodes
        .where((node) =>
            node.localName == 'meta' &&
            node.attributes['property'] == 'og:image' &&
            (node.attributes['content'] ?? '').isNotEmpty)
        .map((node) => node.attributes['content']!)
        .firstOrNull;
    if (cover != null) {
      cover = base.resolve(cover).toString();
      validateUrl(cover);
    }
    final metadata = _metadata(document);
    final containers = nodes.where((node) =>
        const {'chaptersList', 'groupChapterList'}.contains(node.attributes['id']) ||
        _classes(node).contains('chapters-list'));
    var links = [
      for (final container in containers)
        for (final a in _walk(container))
          if (a.localName == 'a' && (a.attributes['href'] ?? '').isNotEmpty) a,
    ];
    if (links.isEmpty) {
      links = [
        for (final node in nodes)
          if (node.localName == 'li' && _classes(node).contains('wp-manga-chapter'))
            for (final a in _walk(node))
              if (a.localName == 'a' && (a.attributes['href'] ?? '').isNotEmpty) a,
      ];
    }
    final chapters = <Chapter>[];
    final seen = <String>{};
    final prefix = '/manhwa/$slug/';
    for (final link in links) {
      final chapterUrl = base.resolve(link.attributes['href']!).toString();
      validateUrl(chapterUrl);
      final target = Uri.parse(chapterUrl);
      var rest = target.path.startsWith(prefix) ? target.path.substring(prefix.length) : '';
      rest = rest.replaceAll(RegExp(r'^/+|/+$'), '');
      if (rest.isEmpty || rest.contains('/') || target.hasQuery || target.hasFragment || seen.contains(chapterUrl)) {
        continue;
      }
      var label = _walk(link)
          .where((node) => _classes(node).contains('chapter-item__name'))
          .map(_text)
          .firstWhere((t) => t.isNotEmpty, orElse: () => '');
      if (label.isEmpty) {
        label = link.children
            .where((node) => node.localName == 'span' && !_classes(node).contains('chapter-item__date'))
            .map(_text)
            .firstWhere((t) => t.isNotEmpty, orElse: () => _text(link));
      }
      if (label.isEmpty) throw const ProviderError('Nome di un capitolo ManhwaRead assente.');
      seen.add(chapterUrl);
      final date = _walk(link)
          .where((node) => _classes(node).contains('chapter-item__date'))
          .map(_text)
          .firstOrNull;
      final chapterId = link.attributes['data-id'];
      final chapterMetadata = <String, Object?>{'date': ?date};
      final decimal = RegExp(r'^\d+$');
      if (mangaId != null && chapterId != null && decimal.hasMatch(mangaId) && decimal.hasMatch(chapterId)) {
        chapterMetadata['manga_id'] = mangaId;
        chapterMetadata['chapter_id'] = chapterId;
      }
      chapters.add(Chapter(rest, label, chapterNumber(label) ?? label, chapterUrl, chapterMetadata));
    }
    if (chapters.isEmpty) {
      throw const ProviderError('Elenco capitoli ManhwaRead assente o incompleto.');
    }
    final ordered = [
      for (final chapter in chapters)
        if (chapterNumberPattern.firstMatch(chapter.title) case final match?)
          (int.parse(match[1]!), int.parse(match[2] ?? '0')),
    ];
    final reversed = ordered.length >= 2 &&
        (ordered.first.$1 > ordered.last.$1 ||
            (ordered.first.$1 == ordered.last.$1 && ordered.first.$2 > ordered.last.$2));
    return Series(
      provider: id,
      id: slug,
      title: title,
      url: canonicalUrl,
      coverUrl: cover,
      metadata: metadata,
      chapters: reversed ? chapters.reversed.toList() : chapters,
    );
  }

  /// La pagina dei risultati che apre la barra di ricerca del sito
  /// (`/?s=…`), letta scheda per scheda: la ricerca rapida che compare
  /// mentre si scrive passa da `admin-ajax.php`, che Cloudflare blocca anche
  /// dopo la verifica.
  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) async {
    final Uint8List body;
    try {
      body = (await http.get(Uri.https('manhwaread.com', '/', {'s': query.trim()}).toString())).body;
    } on HttpStatusError catch (error) {
      if (error.status == 403) throw const CloudflareChallenge();
      rethrow;
    }
    final root = html.parse(utf8.decode(body, allowMalformed: true)).documentElement;
    if (root == null) return const [];
    final base = Uri.parse(home);
    final results = <SearchResult>[];
    final seen = <String>{};
    for (final card in _walk(root).where((node) => _classes(node).contains('manga-item'))) {
      final nodes = _walk(card).toList();
      final links = nodes.where((node) =>
          node.localName == 'a' &&
          accepts(base.resolve(node.attributes['href'] ?? '').toString()));
      final link = links.where((node) => _classes(node).contains('manga-item__link')).firstOrNull ??
          links.firstOrNull;
      if (link == null) continue;
      final url = canonical(base.resolve(link.attributes['href']!).toString());
      final image = nodes.where((node) => node.localName == 'img').firstOrNull;
      final title = [_text(link), image?.attributes['alt'] ?? '']
          .map((value) => value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (title.isEmpty || !seen.add(url)) continue;
      String? cover;
      for (final name in const ['data-src', 'data-lazy-src', 'src']) {
        final value = image?.attributes[name];
        if (value == null || value.isEmpty || value.startsWith('data:')) continue;
        try {
          validateUrl(base.resolve(value).toString());
          cover = base.resolve(value).toString();
          break;
        } on ProviderError {
          // Una copertina fuori dai domini del sito non si mostra.
        }
      }
      final status = nodes
          .map((node) => node.attributes['data-status'])
          .firstWhere((value) => value != null, orElse: () => null);
      results.add(SearchResult(
        provider: id,
        title: title,
        url: url,
        coverUrl: cover,
        releaseStatus: releaseStatus(status),
      ));
      if (results.length == searchLimit) break;
    }
    return results;
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) async {
    final Uint8List body;
    try {
      body = (await http.get(chapter.url)).body;
    } on CloudflareChallenge {
      return _probeCdn(chapter, http);
    } on HttpStatusError catch (error) {
      if (error.status == 403) return _probeCdn(chapter, http);
      rethrow;
    }
    final document = html.parse(utf8.decode(body, allowMalformed: true));
    Object? data;
    for (final script in document.getElementsByTagName('script')) {
      final source = script.nodes.whereType<dom.Text>().map((t) => t.data).join();
      final found = _chapterData.firstMatch(source);
      if (found == null) continue;
      var start = found.end;
      while (start < source.length && source[start].trim().isEmpty) {
        start++;
      }
      try {
        data = _jsonPrefix(source, start);
      } on FormatException {
        throw const ProviderError('Dati immagini ManhwaRead non validi.');
      }
      break;
    }
    if (data is! Map) throw const ProviderError('Elenco immagini ManhwaRead assente dal capitolo.');
    final encoded = data['data'];
    var base = data['base'];
    if (encoded is! String || encoded.isEmpty || encoded.length > 2000000 || base is! String) {
      throw const ProviderError('Dati immagini ManhwaRead incompleti.');
    }
    if (base.startsWith('//')) base = 'https:$base';
    validateUrl(base);
    if (Uri.parse(base).host != 'manread.xyz') {
      throw const ProviderError('CDN immagini ManhwaRead non riconosciuto.');
    }
    final Object? images;
    try {
      final padded = encoded + '=' * ((4 - encoded.length % 4) % 4);
      images = jsonDecode(utf8.decode(base64.decode(padded)));
    } on FormatException {
      throw const ProviderError('Elenco immagini ManhwaRead non valido.');
    }
    if (images is! List || images.isEmpty) {
      throw const ProviderError('Elenco immagini ManhwaRead vuoto.');
    }
    var root = base;
    while (root.endsWith('/')) {
      root = root.substring(0, root.length - 1);
    }
    final pages = <Page>[];
    for (final item in images) {
      var src = item is Map ? item['src'] : null;
      if (src is String) src = src.replaceAll(r'\/', '/');
      if (src is! String ||
          src.isEmpty ||
          src.startsWith('/') ||
          src.startsWith('http:') ||
          src.startsWith('https:') ||
          src.split('/').contains('..') ||
          src.contains('\x00')) {
        throw const ProviderError('Pagina ManhwaRead non valida.');
      }
      final imageUrl = '$root/$src';
      validateUrl(imageUrl);
      final map = item as Map;
      pages.add(Page(
        imageUrl,
        map['w'] is int ? map['w'] as int : null,
        map['h'] is int ? map['h'] as int : null,
      ));
    }
    return ChapterContent(pages, {..._metadata(document), 'imageSource': 'chapterData'});
  }

  Future<ChapterContent> _probeCdn(Chapter chapter, ProviderHttp http) async {
    final mangaId = chapter.metadata['manga_id'];
    final chapterId = chapter.metadata['chapter_id'];
    final decimal = RegExp(r'^\d+$');
    if (mangaId is! String || !decimal.hasMatch(mangaId) || chapterId is! String || !decimal.hasMatch(chapterId)) {
      throw const ProviderError(
        'Il capitolo richiede la pagina del sito o gli id del CDN nella pagina della serie.',
      );
    }
    String address(int number) =>
        'https://manread.xyz/$mangaId/$chapterId/mr_${'$number'.padLeft(3, '0')}.jpg';
    final pages = <Page>[];
    for (var number = 1; number <= 1000; number++) {
      if (!await http.imageExists(address(number), referer: chapter.url)) {
        if (number == 1) {
          throw ProviderError('Nessuna immagine CDN disponibile: ${chapter.title}.');
        }
        // Una tavola che manca in mezzo non deve accorciare il capitolo in
        // silenzio.
        for (final later in [number + 1, number + 2]) {
          if (await http.imageExists(address(later), referer: chapter.url)) {
            throw ProviderError('Immagini CDN non consecutive: ${chapter.title}.');
          }
        }
        return ChapterContent(pages, const {'imageSource': 'cdn-probe'});
      }
      pages.add(Page(address(number)));
    }
    throw ProviderError('Troppe immagini nel capitolo ${chapter.title}; verifica il CDN.');
  }
}

/// Una pagina della serie già in mano, letta nella WebView: la serie si
/// legge da lì, capitoli e tavole passano da [inner] come sempre.
class SnapshotHttp implements ProviderHttp {
  SnapshotHttp(this.inner, this.url, this.body);

  final ProviderHttp inner;
  final String url;
  final Uint8List body;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    if (url == this.url) return (body: body, contentType: 'text/html');
    return inner.get(url, limit: limit, referer: referer);
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) =>
      inner.imageExists(url, referer: referer);

  @override
  Future<Map<String, Object?>> json(String url) => inner.json(url);
}
