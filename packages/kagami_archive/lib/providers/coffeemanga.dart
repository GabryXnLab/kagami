/// Coffee Manga: un'app Inertia (Laravel), senza Cloudflare.
///
/// Ogni pagina porta il suo stato in `<script data-page="app">`: la serie
/// con la prima pagina dell'elenco capitoli (le altre sono file JSON), il
/// capitolo con la sola prima tavola. Le altre tavole arrivano da un
/// manifest cifrato: la pagina dà il cifrato e quale richiesta fare, la
/// chiave sta nel bundle JavaScript del sito (`TE()`), e la risposta ha
/// tre forme e tre codifiche scelte da `v`. Il procedimento è quello del
/// lettore del sito, rifatto qui senza motore JS.
///
/// L'identità è lo slug, della serie e del capitolo: gli id numerici
/// esistono solo dentro la pagina del capitolo.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html;

import '../http.dart';
import '../model.dart';
import '../providers.dart';
import 'kit.dart';

const Set<String> _siteHosts = {'coffeemanga.net', 'www.coffeemanga.net'};

/// Le copertine di alcune serie stanno su un host di immagini a parte.
const Set<String> _imageHosts = {..._siteHosts, 'i.coffeemanga.net'};

const String _slugPattern = r'[a-z0-9]+(?:-[a-z0-9]+)*';
final RegExp _seriesPath = RegExp('^/manga/($_slugPattern)/?\$');
final RegExp _chapterPath = RegExp('^/manga/($_slugPattern)/($_slugPattern)/?\$');
final RegExp _slug = RegExp('^$_slugPattern\$');
final RegExp _number = RegExp(r'^\d+(?:\.\d+)?$');
final RegExp _token = RegExp(r'^[A-Za-z0-9_-]+$');
final RegExp _hex = RegExp(r'^(?:[0-9a-fA-F]{2})+$');
final RegExp _bundleSource = RegExp(r'/build/assets/[^"?#]*app-[^"?#/]*\.js$');

const ProviderError _changed = ProviderChanged('Formato della pagina Coffee Manga cambiato.');

/// Lo stato Inertia di una pagina: `component` e `props`.
({String component, Map<String, Object?> props}) _inertia(Uint8List body) {
  final script = html.parse(utf8.decode(body, allowMalformed: true)).querySelector('script[data-page="app"]');
  final Object? page;
  try {
    page = jsonDecode(script?.text ?? '');
  } on FormatException {
    throw _changed;
  }
  if (page is! Map<String, Object?> || page['component'] is! String || page['props'] is! Map<String, Object?>) {
    throw _changed;
  }
  return (component: page['component'] as String, props: page['props'] as Map<String, Object?>);
}

Map<String, Object?> _map(Object? value) => value is Map<String, Object?> ? value : throw _changed;

List<Object?> _list(Object? value) => value is List<Object?> ? value : throw _changed;

String _string(Object? value) => value is String && value.isNotEmpty ? value : throw _changed;

int _int(Object? value) => value is int ? value : throw _changed;

/// Un nome da una voce che il sito dà come `{slug,name,url}` o come testo.
String? _name(Object? value) => switch (value) {
      final String text when text.trim().isNotEmpty => text.trim(),
      final Map<String, Object?> entry when isText(entry['name']) => (entry['name'] as String).trim(),
      _ => null,
    };

List<String> _names(Object? value) => [
      if (value is List<Object?>)
        for (final entry in value) ?_name(entry),
    ];

/// La chiave a 32 byte di `TE()` nel bundle [source].
///
/// `TE` riempie un `Uint8Array(32)` con espressioni sui numeri di un array
/// `ue` e sui caratteri di `document.documentElement.tagName` (`HTML`). Le
/// espressioni usano solo interi, `ue[i]`, `r.charCodeAt(k)`, parentesi e
/// gli operatori `+ - & ^ |`: un piccolo valutatore con la precedenza di JS
/// basta, e se il sito ne usa uno diverso si ferma con un errore invece di
/// dare una chiave sbagliata.
Uint8List coffeeMangaKey(String source) {
  final head = RegExp(
    r'function \w+\(\)\{const (\w+)=new Uint8Array\(32\),(\w+)=document\.documentElement\.tagName;return ',
  ).firstMatch(source);
  if (head == null) throw _changed;
  final out = head[1]!;
  final tag = head[2]!;
  final end = source.indexOf(',$out}', head.end);
  if (end < 0) throw _changed;
  final evaluator = _Expressions(
    RegExp(r'\d+|[A-Za-z_$][\w$]*|[\[\]().+\-^&|=,]').allMatches(source.substring(head.end, end)).map((m) => m[0]!).toList(),
    source,
    tag,
  );
  final key = Uint8List(32);
  final set = <int>{};
  while (!evaluator.done) {
    evaluator.expect(out);
    evaluator.expect('[');
    final index = evaluator.integer();
    evaluator.expect(']');
    evaluator.expect('=');
    if (index > 31 || !set.add(index)) throw _changed;
    key[index] = evaluator.expression() & 255;
    if (!evaluator.done) evaluator.expect(',');
  }
  if (set.length != 32) throw _changed;
  return key;
}

class _Expressions {
  _Expressions(this._tokens, this._source, this._tag);

  final List<String> _tokens;
  final String _source;
  final String _tag;
  final Map<String, List<int>> _arrays = {};
  int _at = 0;

  bool get done => _at >= _tokens.length;

  String _peek() => _at < _tokens.length ? _tokens[_at] : '';

  void expect(String token) {
    if (_peek() != token) throw _changed;
    _at++;
  }

  int integer() {
    final value = int.tryParse(_peek());
    if (value == null) throw _changed;
    _at++;
    return value;
  }

  int _i32(int value) => value.toSigned(32);

  // Precedenza di JS, dalla più debole: `|`, `^`, `&`, poi `+ -`.
  int expression() {
    var value = _xor();
    while (_peek() == '|') {
      _at++;
      value = _i32(value) | _i32(_xor());
    }
    return value;
  }

  int _xor() {
    var value = _and();
    while (_peek() == '^') {
      _at++;
      value = _i32(value) ^ _i32(_and());
    }
    return value;
  }

  int _and() {
    var value = _sum();
    while (_peek() == '&') {
      _at++;
      value = _i32(value) & _i32(_sum());
    }
    return value;
  }

  int _sum() {
    var value = _atom();
    while (_peek() == '+' || _peek() == '-') {
      final plus = _tokens[_at++] == '+';
      final next = _atom();
      value = plus ? value + next : value - next;
    }
    return value;
  }

  int _atom() {
    final token = _peek();
    if (token == '(') {
      _at++;
      final value = expression();
      expect(')');
      return value;
    }
    final literal = int.tryParse(token);
    if (literal != null) {
      _at++;
      return literal;
    }
    if (token == _tag) {
      _at++;
      expect('.');
      expect('charCodeAt');
      expect('(');
      final index = integer();
      expect(')');
      if (index >= 4) throw _changed;
      return 'HTML'.codeUnitAt(index);
    }
    if (RegExp(r'^[A-Za-z_$]').hasMatch(token)) {
      _at++;
      expect('[');
      final index = integer();
      expect(']');
      final values = _arrays[token] ??= _array(token);
      if (index >= values.length) throw _changed;
      return values[index];
    }
    throw _changed;
  }

  List<int> _array(String name) {
    final found = RegExp('[\\s;,{}]${RegExp.escape(name)}=\\[([\\d,]+)\\]').firstMatch(_source);
    if (found == null) throw _changed;
    return [for (final value in found[1]!.split(',')) int.parse(value)];
  }
}

class CoffeeManga extends Provider {
  /// Le chiavi già lette, per URL del bundle: cambia a ogni build del sito.
  final Map<String, Uint8List> _keys = {};

  @override
  String get id => 'coffeemanga';

  @override
  String get name => 'Coffee Manga';

  @override
  String get home => 'https://coffeemanga.net';

  @override
  bool accepts(String url) => siteLink(url, hosts: _siteHosts, path: _seriesPath, plain: true);

  @override
  String? seriesOfChapter(String url) {
    final found = siteMatch(url, hosts: _siteHosts, path: _chapterPath);
    return found == null ? null : '$home/manga/${found[1]}/';
  }

  @override
  bool allowedHost(Uri uri) => _imageHosts.contains(uri.host);

  @override
  String canonical(String url) => '$home/manga/${_seriesPath.firstMatch(Uri.parse(url).path)![1]}/';

  Map<String, Object?> _json(HttpResult result) => decodeJsonObject(result.body);

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) async {
    if (!accepts(url)) throw const ProviderError('Inserisci il link di una serie Coffee Manga.');
    final canonicalUrl = canonical(url);
    final HttpResult result;
    try {
      result = await http.get(canonicalUrl);
    } on HttpStatusError catch (error) {
      if (error.status == 404) throw const ProviderError('Serie Coffee Manga non trovata.');
      rethrow;
    }
    final page = _inertia(result.body);
    if (page.component != 'Catalog/Series') throw const ProviderChanged('Serie Coffee Manga non trovata.');
    final props = page.props;
    final series = _map(props['series']);
    final slug = _string(series['slug']);
    final title = series['title'];
    if (!_slug.hasMatch(slug)) throw _changed;
    if (!isText(title) || (title as String).trim().isEmpty) {
      throw const ProviderChanged('Titolo Coffee Manga assente dalla pagina.');
    }

    final pagination = _map(props['chapters_pagination']);
    final total = _int(pagination['total']);
    final last = _int(pagination['last']);
    final template = _string(pagination['json']);
    if (last < 1 || last > 5000 || !template.contains('__PAGE__')) throw _changed;
    final raw = <Object?>[..._list(props['chapters'])];
    for (var number = 2; number <= last; number++) {
      final address = '$home${template.replaceAll('__PAGE__', '$number')}';
      raw.addAll(_list(_json(await http.get(address))['items']));
    }
    // Il totale conta anche i capitoli riservati: sono nell'elenco con
    // `locked`, e qui si escludono dopo il controllo.
    if (raw.length != total) throw ProviderError('Elenco incompleto: ${raw.length} capitoli su $total.');

    final chapters = <Chapter>[];
    for (final entry in raw) {
      final item = _map(entry);
      final chapterSlug = item['slug'];
      final label = item['label'];
      final path = item['url'];
      if (chapterSlug is! String || !_slug.hasMatch(chapterSlug) || !isText(label) || path is! String) {
        throw const ProviderChanged('Capitolo Coffee Manga incompleto.');
      }
      final target = siteMatch('$home$path', hosts: _siteHosts, path: _chapterPath);
      if (target == null || target[1] != slug || target[2] != chapterSlug) {
        throw const ProviderChanged('Elenco capitoli Coffee Manga incoerente.');
      }
      // Un capitolo VIP non ha tavole per chi non paga: resta fuori finché
      // non si libera, e allora arriva come capitolo nuovo.
      if (item['locked'] == true) continue;
      final number = item['number'];
      final name = label as String;
      chapters.add(Chapter(
        chapterSlug,
        name,
        number is String && _number.hasMatch(number) ? numberLabel(num.parse(number)) : chapterNumber(name) ?? name,
        '$home$path',
        {'publishedAt': ?(isText(item['published_at']) ? item['published_at'] : null)},
      ));
    }
    if (chapters.isEmpty) throw const ProviderError('Nessun capitolo Coffee Manga disponibile.');
    requireUniqueIds(chapters, 'Coffee Manga');

    final cover = [series['cover_canonical'], series['cover_lg'], series['cover']].firstWhere(isText, orElse: () => null);
    if (cover != null) validateUrl(cover as String);
    return Series(
      provider: id,
      id: slug,
      title: title.trim(),
      url: canonicalUrl,
      coverUrl: cover as String?,
      metadata: _metadata(series, props['rating']),
      // Il sito elenca dal più recente; `oldestFirst` lo riconosce dai
      // numeri, e regge anche se un giorno li desse nell'altro verso.
      chapters: oldestFirst(chapters.reversed.toList()),
    );
  }

  Map<String, Object?> _metadata(Map<String, Object?> series, Object? rating) {
    final metadata = <String, Object?>{
      'genres': _names(series['genres']),
      'tags': _names(series['tags']),
      'alternativeTitles': [
        // «Shard of Time / 시간이 머문 집»: i titoli li separa la barra con
        // gli spazi, che «1/24 Romance» non ha.
        for (final title in _names(series['alt_titles'])) ...title.split(' / '),
      ],
      'authors': _names(series['authors']),
      'artists': _names(series['artists']),
    };
    if (isText(series['synopsis'])) metadata['description'] = (series['synopsis'] as String).trim();
    if (isText(series['status'])) metadata['status'] = series['status'];
    if (isText(series['type'])) metadata['type'] = series['type'];
    final year = series['release_year'];
    if (year is int) metadata['publishedAt'] = '$year';
    final average = rating is Map<String, Object?> ? rating['avg'] : null;
    if (average is num) metadata['rating'] = '$average';
    return metadata;
  }

  /// La pagina dei risultati del sito, che è la stessa app: lo stato sta
  /// nel suo `data-page`.
  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) async {
    final page = _inertia((await http.get(Uri.https('coffeemanga.net', '/search', {'q': query.trim()}).toString())).body);
    if (page.component != 'Catalog/Search') throw _changed;
    final results = <SearchResult>[];
    for (final entry in _list(page.props['series'])) {
      final item = _map(entry);
      final path = item['url'];
      final title = item['title'];
      if (path is! String || !accepts('$home$path') || !isText(title)) continue;
      final cover = item['cover'];
      results.add(SearchResult(
        provider: id,
        title: (title as String).trim(),
        url: canonical('$home$path'),
        coverUrl: isText(cover) && allows(cover as String) ? cover : null,
        latestChapter: latestChapterNumber([
          for (final chapter in item['chapters'] is List<Object?> ? item['chapters'] as List<Object?> : const <Object?>[])
            if (chapter is Map<String, Object?> && chapter['label'] is String) chapter['label'] as String,
        ]),
        releaseStatus: releaseStatus(item['status']),
      ));
      if (results.length == searchLimit) break;
    }
    return results;
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) async {
    final body = (await http.get(chapter.url)).body;
    final page = _inertia(body);
    final props = page.props;
    if (page.component != 'Reader/Chapter') throw ProviderError('Capitolo non corrispondente: ${chapter.title}.');
    final info = _map(props['chapter']);
    final seriesSlug = _string(_map(props['series'])['slug']);
    if (info['slug'] != chapter.id) throw ProviderError('Capitolo non corrispondente: ${chapter.title}.');
    if (info['locked'] == true) throw ProviderError('Capitolo riservato ai VIP di Coffee Manga: ${chapter.title}.');
    final chapterId = _int(info['id']);
    final total = _int(props['total']);
    final encrypted = _string(_map(props['reader'])['x']);

    final bundle = _bundleUrl(utf8.decode(body, allowMalformed: true));
    final cached = _keys[bundle];
    List<Object?> items;
    try {
      items = await _manifest(cached ?? await _readKey(bundle, http), encrypted, chapterId, seriesSlug, http);
    } on _WrongKey {
      // La chiave in cache è di un bundle che il sito ha già cambiato sotto
      // lo stesso nome: si rilegge il bundle una volta sola.
      if (cached == null) throw _changed;
      _keys.remove(bundle);
      try {
        items = await _manifest(await _readKey(bundle, http), encrypted, chapterId, seriesSlug, http);
      } on _WrongKey {
        throw _changed;
      }
    }
    if (items.length != total || total < 1) throw ProviderError('Elenco immagini incompleto: ${chapter.title}.');

    final pages = <Page>[];
    for (final (index, entry) in items.indexed) {
      final item = _map(entry);
      if (item['n'] != index + 1) throw ProviderError('Pagina non coerente: ${chapter.title}.');
      final address = _imageOf(item);
      validateUrl(address);
      final width = item['width'];
      final height = item['height'];
      pages.add(Page(address, width is int ? width : null, height is int ? height : null));
    }
    return ChapterContent(pages, const {});
  }

  /// La tavola alla risoluzione originale (`raw:1` nel suo imgproxy), o il
  /// `src`, o la voce più larga di `srcset`: l'ultima striscia di un
  /// capitolo, di pochi pixel, non ha la variante `raw`. Gli indirizzi sono
  /// firmati: non si costruiscono.
  String _imageOf(Map<String, Object?> item) {
    String? widest;
    var width = -1;
    final srcset = item['srcset'];
    if (srcset is String) {
      for (final candidate in srcset.split(',')) {
        final parts = candidate.trim().split(RegExp(r'\s+'));
        if (parts.first.contains('/raw:1/')) return parts.first;
        final size = parts.length > 1 ? int.tryParse(parts[1].replaceAll('w', '')) : null;
        if (size != null && size > width) {
          width = size;
          widest = parts.first;
        }
      }
    }
    final src = item['src'];
    if (isText(src)) return src as String;
    return widest ?? (throw _changed);
  }

  String _bundleUrl(String page) {
    for (final script in html.parse(page).querySelectorAll('script[type="module"][src]')) {
      final source = script.attributes['src']!;
      final uri = Uri.parse(source).hasScheme ? Uri.parse(source) : Uri.parse(home).resolve(source);
      if (_bundleSource.hasMatch(uri.path) && allows(uri.toString())) return uri.toString();
    }
    throw _changed;
  }

  Future<Uint8List> _readKey(String bundle, ProviderHttp http) async {
    final result = await http.get(bundle, limit: 8000000);
    return _keys[bundle] = coffeeMangaKey(utf8.decode(result.body, allowMalformed: true));
  }

  Uint8List _hmac(List<int> key, String message) =>
      Uint8List.fromList(Hmac(sha256, key).convert(utf8.encode(message)).bytes);

  /// Decifra il manifest della pagina, fa la richiesta che dice e dà
  /// l'elenco delle tavole.
  Future<List<Object?>> _manifest(
    Uint8List key,
    String encrypted,
    int chapterId,
    String seriesSlug,
    ProviderHttp http,
  ) async {
    final secret = _hmac(key, 'rk|${Uri.parse(home).host}|$chapterId');
    final Map<String, Object?> manifest;
    try {
      final bytes = base64Url.decode(base64Url.normalize(encrypted));
      for (var block = 0, offset = 0; offset < bytes.length; block++, offset += 32) {
        final mask = _hmac(secret, 'ks|$block');
        for (var i = 0; i < 32 && offset + i < bytes.length; i++) {
          bytes[offset + i] ^= mask[i];
        }
      }
      manifest = _map(jsonDecode(utf8.decode(bytes)));
    } on Object {
      throw _WrongKey();
    }
    final parameters = manifest['p'];
    final version = manifest['v'];
    final endpoint = manifest['e'];
    final query = manifest['q'];
    if (endpoint is! String ||
        !_token.hasMatch(endpoint) ||
        query is! String ||
        !_token.hasMatch(query) ||
        version is! int ||
        version < 0 ||
        version > 8 ||
        parameters is! List<Object?> ||
        parameters.length != 3 ||
        parameters.any((name) => name is! String || !_token.hasMatch(name))) {
      throw _changed;
    }

    final address = '$home/$endpoint/$chapterId?${parameters[0]}=${Uri.encodeQueryComponent(seriesSlug)}'
        '&${parameters[2]}=${Uri.encodeQueryComponent(query)}';
    final HttpResult result;
    try {
      result = await http.get(address);
    } on HttpStatusError catch (error) {
      if (error.status == 428) {
        throw const ProviderError('Coffee Manga chiede la verifica Turnstile per questo capitolo.');
      }
      rethrow;
    }
    try {
      final Object? body = jsonDecode(utf8.decode(result.body));
      final mode = version ~/ 3;
      final sub = version % 3;
      final Map<String, Object?> envelope = switch (mode) {
        0 => _map(body),
        1 => {for (final (i, name) in const ['c', 'e', 'd', 's'].indexed) name: _list(body)[i]},
        _ => _map(_map(body)['r']),
      };
      if (envelope['c'] != chapterId) throw _changed;
      final data = _string(envelope['d']);
      final String text = switch (sub) {
        0 => data,
        1 => utf8.decode(base64.decode(base64.normalize(data))),
        _ => utf8.decode(_unmask(base64.decode(base64.normalize(data)), manifest['k'])),
      };
      return _list(jsonDecode(text));
    } on FormatException {
      throw _changed;
    }
  }

  List<int> _unmask(List<int> data, Object? hexKey) {
    if (hexKey is! String || !_hex.hasMatch(hexKey)) throw _changed;
    final mask = [for (var i = 0; i < hexKey.length; i += 2) int.parse(hexKey.substring(i, i + 2), radix: 16)];
    return [for (final (i, byte) in data.indexed) byte ^ mask[i % mask.length]];
  }
}

/// La chiave non apre il manifest: il bundle è cambiato.
class _WrongKey implements Exception {}
