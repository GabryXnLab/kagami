/// I siti degli utenti: un file JSON che dice dove stanno serie, capitoli e
/// tavole, interpretato qui. Il formato è in `docs/siti.md`.
///
/// Niente codice del file viene eseguito: selettori CSS, percorsi JSON ed
/// espressioni regolari, e ogni indirizzo passa da [Provider.allowedHost] come
/// per i siti inclusi. Il file arriva da chiunque e il server gira nella rete
/// di casa di qualcuno, per questo gli host si controllano già all'installazione.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

import 'http.dart';
import 'indexes.dart' show prettyJson;
import 'model.dart';
import 'providers.dart';
import 'providers/kit.dart';
import 'stores.dart';

/// Il formato che questo motore sa leggere.
const int siteFormat = 1;

/// Tetti di un'operazione (serie, tavole di un capitolo, ricerca) di un sito
/// degli utenti: il file arriva da chiunque e gira sul telefono o nel server di
/// qualcuno, quindi un sito sbagliato o ostile non deve poterlo occupare senza
/// fine. Ordini di grandezza dai siti inclusi: una pagina HTML o JSON pesa
/// 100-500 KB (2 MB è il tetto di `ProviderHttp.get`, qui ripetuto perché non
/// dipenda dal client); il motore chiede 1 pagina e al più 1 API per
/// operazione, i siti inclusi 1-2 (Coffee Manga una per pagina di capitoli,
/// qualche decina al massimo); 30 s per richiesta e fino a 5 tentativi con
/// attesa che raddoppia in `SiteHttp`, quindi 120 s coprono un sito lento ma
/// non uno che trascina.
const int maxSiteRequests = 8;
const int maxSiteResponseBytes = 2000000;
const Duration maxSiteOperationTime = Duration(seconds: 120);

/// Il conto di una sola operazione.
class _Budget {
  int requests = 0;
}

/// La cartella dei siti nella libreria, accanto a `library.json`.
const String sitesFolder = 'providers';

const int _maxFileBytes = 64 * 1024;
const int _maxPattern = 300;

/// Il testo a cui si applica una regex: il `RegExp` di Dart va in
/// backtracking, quindi una pagina enorme non deve poterlo tenere occupato.
const int _maxMatchText = 64 * 1024;

String _clip(String text) => text.length > _maxMatchText ? text.substring(0, _maxMatchText) : text;
final RegExp _idPattern = RegExp(r'^[a-z0-9]{1,32}$');
final RegExp _hostPattern = RegExp(r'^(\*\.)?([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]$');
const List<String> _privateSuffixes = ['.local', '.lan', '.internal', '.home', '.arpa', '.localhost', '.test', '.invalid'];

/// Un file di sito che non si può installare: il messaggio dice quale campo.
class SiteDefinitionError implements Exception {
  const SiteDefinitionError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Un sito descritto da un file: si comporta come uno incluso.
class DeclarativeProvider extends Provider {
  DeclarativeProvider._(this.definition, this._spec);

  /// Legge [text], il contenuto di un file di sito, e lo valida per intero:
  /// un errore qui non arriva mai a metà di un download.
  factory DeclarativeProvider.parse(String text) {
    if (utf8.encode(text).length > _maxFileBytes) {
      throw const SiteDefinitionError('Il file del sito supera i 64 KB.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const SiteDefinitionError('Il file del sito non è un JSON valido.');
    }
    if (decoded is! Map<String, Object?>) throw const SiteDefinitionError('Il file del sito non è un oggetto JSON.');
    return DeclarativeProvider.fromJson(decoded);
  }

  factory DeclarativeProvider.fromJson(Map<String, Object?> json) {
    if (utf8.encode(jsonEncode(json)).length > _maxFileBytes) {
      throw const SiteDefinitionError('Il file del sito supera i 64 KB.');
    }
    return DeclarativeProvider._(Map.unmodifiable(json), _Spec.read(json));
  }

  /// Il file com'è stato letto, per riscriverlo nella libreria.
  final Map<String, Object?> definition;
  final _Spec _spec;

  @override
  String get id => _spec.id;

  @override
  String get name => _spec.name;

  @override
  String get home => _spec.home;

  @override
  String? get iconUrl => _spec.icon;

  @override
  bool get builtIn => false;

  /// Le espressioni le scrive il motore: il file dà solo selettori, che
  /// restano stringhe JSON e non possono diventare codice.
  @override
  BrowserGate? get browser {
    final gate = _spec.browser;
    if (gate == null) return null;
    String ready(String selector) => '!!document.querySelector(${jsonEncode(selector)})';
    return BrowserGate(
      hosts: gate.hosts,
      seriesReady: ready(gate.seriesReady),
      searchReady: ready(gate.searchReady),
    );
  }

  int get version => _spec.version;

  /// Da dove rileggere il file per aggiornarlo.
  String? get updateUrl => _spec.update;

  bool get searchable => _spec.search != null;

  /// Gli host a cui il sito chiederà qualcosa: chi installa li vede prima.
  List<String> get hosts => [..._spec.hosts, ..._spec.mediaHosts];

  /// Il file come lo si scrive in `providers/<id>.json`.
  Uint8List encode() => Uint8List.fromList(utf8.encode(prettyJson(definition)));

  @override
  bool accepts(String url) => _seriesMatch(url) != null;

  RegExpMatch? _seriesMatch(String url) =>
      siteMatch(url, hosts: _spec.hosts.toSet(), path: _spec.series.path, maxPath: _maxMatchText);

  @override
  String? seriesOfChapter(String url) {
    final template = _spec.series.url;
    final found = siteMatch(url, hosts: _spec.hosts.toSet(), path: _spec.chapter.path, maxPath: _maxMatchText);
    if (found == null || template == null || found.groupCount < 1 || found[1] == null) return null;
    return _fill(template, '{id}', Uri.encodeComponent(found[1]!));
  }

  @override
  bool allowedHost(Uri uri) =>
      _spec.hosts.contains(uri.host) || _spec.mediaHosts.any((host) => _hostMatches(host, uri.host));

  @override
  String canonical(String url) {
    final found = _seriesMatch(url);
    final template = _spec.series.url;
    if (found == null) return url;
    if (template != null && found.groupCount >= 1 && found[1] != null) {
      return _fill(template, '{id}', Uri.encodeComponent(found[1]!));
    }
    return Uri.parse(url).replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '');
  }

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) => _bounded((budget) => _fetchSeries(url, http, budget));

  Future<Series> _fetchSeries(String url, ProviderHttp http, _Budget budget) async {
    final found = _seriesMatch(url);
    if (found == null) throw ProviderError('Inserisci il link di una serie $name.');
    final spec = _spec.series;
    final address = canonical(url);
    final page = await _read(http, budget, address, json: spec.json);
    final context = _Context(address);
    var seriesId = found.groupCount >= 1 ? found[1] : null;
    if (spec.id case final extractor?) seriesId = extractor.first(page, context);
    final title = spec.title.first(page, context);
    if (seriesId == null || seriesId.isEmpty || title == null) {
      throw ProviderChanged('Serie $name non riconosciuta nella pagina.');
    }
    final metadata = <String, Object?>{};
    for (final MapEntry(key: field, value: extractor) in spec.metadata.entries) {
      final values = extractor.strings(page, context);
      if (values.isEmpty) continue;
      metadata[field] = extractor.all || extractor.split != null ? values : values.first;
    }
    var cover = spec.cover?.first(page, context);
    if (cover != null && !allows(cover)) cover = null;
    final chapters = await _chapters(http, budget, page, context, seriesId);
    return Series(
      provider: id,
      id: seriesId,
      title: title,
      url: address,
      coverUrl: cover,
      metadata: metadata,
      chapters: chapters,
    );
  }

  Future<List<Chapter>> _chapters(ProviderHttp http, _Budget budget, Object? page, _Context context, String seriesId) async {
    final spec = _spec.series.chapters;
    var source = page;
    // I link relativi di un'API si risolvono rispetto alla serie: l'API sta
    // spesso su un altro host, i capitoli no.
    final base = context;
    if (spec.api case final api?) {
      source = await _read(http, budget, _fill(api, '{id}', Uri.encodeComponent(seriesId)), json: true);
    }
    final chapters = <Chapter>[];
    for (final item in spec.items.nodes(source, base)) {
      final link = spec.url.first(item, base);
      final title = spec.title.first(item, base);
      if (link == null || title == null) throw ProviderChanged('Capitolo $name incompleto.');
      if (!allows(link)) throw ProviderChanged('Capitolo $name fuori dai domini del sito.');
      final itemContext = _Context(base.page, url: link);
      final chapterId = spec.id?.first(item, itemContext) ?? _lastSegment(link);
      if (chapterId == null || chapterId.isEmpty) throw ProviderChanged('Capitolo $name senza id.');
      final number = spec.number?.first(item, itemContext) ?? chapterNumber(title) ?? title;
      final date = spec.date?.first(item, itemContext);
      chapters.add(Chapter(chapterId, title, number, link, {'date': ?date}));
    }
    if (chapters.isEmpty) throw ProviderChanged('Elenco capitoli $name vuoto.');
    final ordered = switch (spec.order) {
      'newest-first' => chapters.reversed.toList(),
      'oldest-first' => chapters,
      _ => oldestFirst(chapters),
    };
    requireUniqueIds(ordered, name);
    return ordered;
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) =>
      _bounded((budget) => _fetchPages(chapter, http, budget));

  Future<ChapterContent> _fetchPages(Chapter chapter, ProviderHttp http, _Budget budget) async {
    final spec = _spec.chapter;
    var address = chapter.url;
    if (spec.api case final api?) {
      address = _fill(_fill(api, '{url}', Uri.encodeComponent(chapter.url)), '{id}', Uri.encodeComponent(chapter.id));
    }
    validateUrl(address);
    final page = await _read(http, budget, address, json: spec.json || spec.api != null);
    final context = _Context(address);
    final pages = <Page>[];
    for (final item in spec.pages.items.nodes(page, context)) {
      final link = spec.pages.url.first(item, context);
      if (link == null) continue;
      if (!allows(link)) throw ProviderChanged('Tavola fuori dai domini del sito: ${chapter.title}.');
      pages.add(Page(
        link,
        int.tryParse(spec.pages.width?.first(item, context) ?? ''),
        int.tryParse(spec.pages.height?.first(item, context) ?? ''),
      ));
    }
    if (pages.isEmpty) throw ProviderChanged('Nessuna tavola trovata: ${chapter.title}.');
    return ChapterContent(pages, const {});
  }

  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) => _bounded((budget) => _search(query, http, budget));

  Future<List<SearchResult>> _search(String query, ProviderHttp http, _Budget budget) async {
    final spec = _spec.search;
    if (spec == null) return const [];
    final address = _fill(spec.url, '{query}', Uri.encodeQueryComponent(query.trim()));
    validateUrl(address);
    final page = await _read(http, budget, address, json: spec.json);
    final context = _Context(address);
    final results = <SearchResult>[];
    for (final item in spec.items.nodes(page, context)) {
      final link = spec.link.first(item, context);
      final title = spec.title.first(item, context);
      if (link == null || title == null || !accepts(link)) continue;
      final cover = spec.cover?.first(item, context);
      final latest = spec.latest?.first(item, context);
      results.add(SearchResult(
        provider: id,
        title: title,
        url: canonical(link),
        coverUrl: cover != null && allows(cover) ? cover : null,
        latestChapter: latest == null ? null : chapterNumber(latest) ?? (num.tryParse(latest) != null ? latest : null),
        releaseStatus: releaseStatus(spec.status?.first(item, context)),
      ));
      if (results.length == searchLimit) break;
    }
    return results;
  }

  Future<T> _bounded<T>(Future<T> Function(_Budget budget) operation) async {
    try {
      return await operation(_Budget()).timeout(maxSiteOperationTime);
    } on TimeoutException {
      throw ProviderError('Il sito $name ha impiegato troppo: operazione interrotta.');
    }
  }

  Future<Object?> _read(ProviderHttp http, _Budget budget, String url, {required bool json}) async {
    validateUrl(url);
    if (++budget.requests > maxSiteRequests) {
      throw ProviderError('Il sito $name chiede troppe richieste per una sola operazione.');
    }
    final result = await http.get(url, limit: maxSiteResponseBytes);
    if (result.body.length > maxSiteResponseBytes) throw const ProviderError('Risposta troppo grande.');
    final body = utf8.decode(result.body, allowMalformed: true);
    if (!json) return parser.parse(body);
    try {
      return jsonDecode(body);
    } on FormatException {
      throw ProviderChanged('Risposta di $name non in JSON.');
    }
  }
}

/// Legge i siti in `providers/` di [store]. Un file rovinato non ferma gli
/// altri: lo dice [onError] e resta dov'è, perché togliere un sito è una scelta
/// dell'utente.
Future<List<DeclarativeProvider>> loadSites(
  ArchiveStore store, {
  void Function(String file, Object error)? onError,
}) async {
  final sites = <DeclarativeProvider>[];
  final files = await store.filesIn(sitesFolder);
  for (final name in files.keys.toList()..sort()) {
    if (!name.endsWith('.json')) continue;
    try {
      final json = await store.readJson('$sitesFolder/$name');
      if (json == null) throw const SiteDefinitionError('Il file non si legge o non è un JSON valido.');
      final site = DeclarativeProvider.fromJson(json);
      if ('${site.id}.json' != name) throw SiteDefinitionError('Il file $name contiene il sito ${site.id}.');
      sites.add(site);
    } on Object catch (error) {
      onError?.call(name, error);
    }
  }
  return sites;
}

/// Scrive [site] nella libreria di [store], al posto della versione di prima.
Future<void> saveSite(ArchiveStore store, DeclarativeProvider site) =>
    store.writeSeriesFiles(sitesFolder, {'${site.id}.json': site.encode()});

/// Toglie il file del sito [id] dalla libreria; le sue serie restano.
Future<void> removeSite(ArchiveStore store, String id) => store.removeFile('$sitesFolder/$id.json');

bool _hostMatches(String pattern, String host) =>
    pattern.startsWith('*.') ? host.endsWith(pattern.substring(1)) : pattern == host;

String _fill(String template, String name, String value) => template.replaceAll(name, value);

String? _lastSegment(String url) =>
    Uri.tryParse(url)?.pathSegments.where((segment) => segment.isNotEmpty).lastOrNull;

class _Context {
  const _Context(this.page, {this.url});

  final String page;

  /// Il link già letto dell'elemento, per `from: url`.
  final String? url;
}

/// Un campo da leggere da un nodo (documento, elemento HTML o valore JSON).
class _Extractor {
  _Extractor({
    this.css,
    this.json,
    this.attrs = const [],
    this.asHtml = false,
    this.regex,
    this.split,
    this.all = false,
    this.from,
    this.value,
    this.link = false,
  });

  static _Extractor read(Object? raw, String where, {bool link = false, bool all = false}) {
    if (raw is String) return _Extractor(css: _selector(raw, where), link: link, all: all);
    if (raw is! Map<String, Object?>) throw SiteDefinitionError('$where: serve un selettore o un oggetto.');
    const known = {'css', 'json', 'attr', 'html', 'regex', 'split', 'all', 'from', 'value'};
    for (final key in raw.keys) {
      if (!known.contains(key)) throw SiteDefinitionError('$where: chiave sconosciuta «$key».');
    }
    final attr = raw['attr'];
    final from = raw['from'];
    if (from != null && from != 'url' && from != 'page') throw SiteDefinitionError('$where: «from» è url o page.');
    return _Extractor(
      css: raw['css'] == null ? null : _selector(_string(raw['css'], '$where.css'), where),
      json: raw['json'] == null ? null : _string(raw['json'], '$where.json'),
      attrs: switch (attr) {
        null => const [],
        String() => [attr],
        List() when attr.every((name) => name is String && name.isNotEmpty) => attr.cast<String>(),
        _ => throw SiteDefinitionError('$where.attr: un nome o una lista di nomi.'),
      },
      asHtml: _flag(raw['html'], '$where.html'),
      regex: raw['regex'] == null ? null : _pattern(raw['regex'], '$where.regex'),
      split: raw['split'] == null ? null : _pattern(raw['split'], '$where.split'),
      all: all || _flag(raw['all'], '$where.all'),
      from: from as String?,
      value: raw['value'] == null ? null : _string(raw['value'], '$where.value'),
      link: link,
    );
  }

  static String _selector(String selector, String where) {
    try {
      parser.parseFragment('<p></p>').querySelectorAll(selector);
    } on Object {
      throw SiteDefinitionError('$where: selettore CSS non valido «$selector».');
    }
    return selector;
  }

  final String? css;
  final String? json;
  final List<String> attrs;
  final bool asHtml;
  final RegExp? regex;
  final RegExp? split;
  final bool all;
  final String? from;
  final String? value;

  /// Un link: si risolve rispetto alla pagina.
  final bool link;

  /// I nodi trovati, per gli elenchi (`items`).
  List<Object?> nodes(Object? node, _Context context) {
    var current = <Object?>[
      switch (from) {
        'url' => context.url,
        'page' => context.page,
        _ => node,
      },
    ];
    if (css case final selector?) {
      current = [
        for (final item in current)
          ..._select(item, selector, all: all),
      ];
    }
    if (json case final path?) {
      current = [for (final item in current) ..._walk(_asJson(item), path)];
      if (!all && current.length > 1) current = [current.first];
    }
    return current;
  }

  /// I valori come testi, già ripuliti e filtrati da [regex] e [split].
  List<String> strings(Object? node, _Context context) {
    if (value case final fixed?) return [fixed];
    final texts = <String>[];
    for (final item in nodes(node, context)) {
      var text = _text(item);
      if (text == null) continue;
      if (regex != null || split != null) text = _clip(text);
      if (regex case final pattern?) {
        final found = pattern.firstMatch(text);
        if (found == null) continue;
        text = found.groupCount >= 1 ? (found[1] ?? '') : found[0]!;
      }
      final parts = split == null ? [text] : text.split(split!);
      for (var part in parts) {
        part = asHtml ? part.trim() : part.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (part.isEmpty) continue;
        if (link) {
          final resolved = Uri.tryParse(context.page)?.resolve(part).toString();
          if (resolved == null) continue;
          part = resolved;
        }
        texts.add(part);
      }
      if (!all && split == null && texts.isNotEmpty) break;
    }
    return texts;
  }

  String? first(Object? node, _Context context) => strings(node, context).firstOrNull;

  String? _text(Object? item) {
    if (item is dom.Element) {
      for (final name in attrs) {
        final value = item.attributes[name]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      if (attrs.isNotEmpty) return null;
      return asHtml ? htmlText(item.innerHtml) : item.text;
    }
    if (item is dom.Document) return item.body?.text;
    if (item is String) return asHtml ? htmlText(item) : item;
    if (item is num || item is bool) return '$item';
    if (item is Map) {
      for (final name in attrs) {
        final value = item[name];
        if (value is String && value.trim().isNotEmpty) return value;
        if (value is num) return '$value';
      }
      return metadataStrings(item).firstOrNull;
    }
    return null;
  }

  static List<dom.Element> _select(Object? item, String selector, {required bool all}) {
    final List<dom.Element> found = switch (item) {
      dom.Document() => all ? item.querySelectorAll(selector) : [?item.querySelector(selector)],
      dom.Element() => all ? item.querySelectorAll(selector) : [?item.querySelector(selector)],
      String() => () {
          final fragment = parser.parseFragment(item);
          return all ? fragment.querySelectorAll(selector) : [?fragment.querySelector(selector)];
        }(),
      _ => const [],
    };
    return found;
  }

  static Object? _asJson(Object? item) {
    final text = switch (item) {
      dom.Element() => item.text,
      dom.Document() => item.body?.text,
      String() => item,
      _ => null,
    };
    if (text == null) return item;
    try {
      return jsonDecode(text.trim());
    } on FormatException {
      return null;
    }
  }

  /// I valori in [path] (`a.b[0].c`); attraverso una lista, di ogni elemento.
  static List<Object?> _walk(Object? root, String path) {
    var current = <Object?>[root];
    for (final segment in path.split('.').where((part) => part.isNotEmpty)) {
      final found = RegExp(r'^([^\[\]]*)((?:\[\d+\])*)$').firstMatch(segment);
      if (found == null) return const [];
      final indexes = [for (final index in RegExp(r'\[(\d+)\]').allMatches(found[2]!)) int.parse(index[1]!)];
      final next = <Object?>[];
      for (final item in current) {
        var values = <Object?>[item];
        if (found[1]!.isNotEmpty) {
          values = [
            for (final value in values)
              if (value is Map) value[found[1]]
              else if (value is List) for (final element in value) if (element is Map) element[found[1]],
          ];
        }
        for (final index in indexes) {
          values = [for (final value in values) if (value is List && index < value.length) value[index]];
        }
        for (final value in values) {
          if (value is List && indexes.isEmpty) {
            next.addAll(value);
          } else if (value != null) {
            next.add(value);
          }
        }
      }
      current = next;
    }
    return current;
  }
}

class _Spec {
  _Spec({
    required this.id,
    required this.name,
    required this.version,
    required this.update,
    required this.home,
    required this.hosts,
    required this.mediaHosts,
    required this.icon,
    required this.series,
    required this.chapter,
    required this.search,
    required this.browser,
  });

  static _Spec read(Map<String, Object?> json) {
    if (json['format'] != siteFormat) {
      throw SiteDefinitionError('Formato del sito ${json['format']} non supportato: questa versione legge il $siteFormat.');
    }
    final id = _string(json['id'], 'id');
    if (!_idPattern.hasMatch(id)) throw const SiteDefinitionError('id: solo lettere minuscole e cifre, al più 32.');
    final version = json['version'];
    if (version is! int || version < 1) throw const SiteDefinitionError('version: un intero da 1 in su.');
    final hosts = _hosts(json['hosts'], 'hosts', wildcard: false);
    if (hosts.isEmpty) throw const SiteDefinitionError('hosts: almeno un host.');
    final mediaHosts = json['mediaHosts'] == null ? const <String>[] : _hosts(json['mediaHosts'], 'mediaHosts', wildcard: true);
    bool allowed(Uri uri) => hosts.contains(uri.host) || mediaHosts.any((host) => _hostMatches(host, uri.host));
    String link(Object? raw, String where, bool Function(Uri) ok) {
      final value = _string(raw, where);
      try {
        checkUrl(value, ok);
      } on ProviderError {
        throw SiteDefinitionError('$where: un link https su uno degli host dichiarati.');
      }
      return value;
    }

    final home = link(json['home'], 'home', (uri) => hosts.contains(uri.host));
    final update = json['update'] == null ? null : link(json['update'], 'update', (_) => true);
    if (update != null && !_publicHost(Uri.parse(update).host)) {
      throw const SiteDefinitionError('update: un host pubblico.');
    }
    final icon = json['icon'] == null ? null : link(json['icon'], 'icon', allowed);
    return _Spec(
      id: id,
      name: _string(json['name'], 'name'),
      version: version,
      update: update,
      home: home,
      hosts: hosts,
      mediaHosts: mediaHosts,
      icon: icon,
      series: _SeriesSpec.read(_object(json['series'], 'series'), hosts),
      chapter: _ChapterSpec.read(_object(json['chapter'], 'chapter'), hosts),
      search: json['search'] == null ? null : _SearchSpec.read(_object(json['search'], 'search'), hosts),
      browser: json['browser'] == null ? null : _BrowserSpec.read(_object(json['browser'], 'browser'), hosts),
    );
  }

  final String id;
  final String name;
  final int version;
  final String? update;
  final String home;
  final List<String> hosts;
  final List<String> mediaHosts;
  final String? icon;
  final _SeriesSpec series;
  final _ChapterSpec chapter;
  final _SearchSpec? search;
  final _BrowserSpec? browser;
}

class _BrowserSpec {
  _BrowserSpec(this.hosts, this.seriesReady, this.searchReady);

  static _BrowserSpec read(Map<String, Object?> raw, List<String> siteHosts) {
    final hosts = _hosts(raw['hosts'], 'browser.hosts', wildcard: false);
    if (hosts.isEmpty) throw const SiteDefinitionError('browser.hosts: almeno un host.');
    for (final host in hosts) {
      if (!siteHosts.contains(host)) throw SiteDefinitionError('browser.hosts: «$host» non è fra gli hosts del sito.');
    }
    return _BrowserSpec(
      hosts,
      _Extractor._selector(_string(raw['seriesReady'], 'browser.seriesReady'), 'browser.seriesReady'),
      _Extractor._selector(_string(raw['searchReady'], 'browser.searchReady'), 'browser.searchReady'),
    );
  }

  final List<String> hosts;
  final String seriesReady;
  final String searchReady;
}

const List<String> _metadataKeys = [
  'description',
  'status',
  'authors',
  'artists',
  'genres',
  'tags',
  'alternativeTitles',
  'type',
];

class _SeriesSpec {
  _SeriesSpec(this.path, this.url, this.json, this.id, this.title, this.cover, this.metadata, this.chapters);

  static _SeriesSpec read(Map<String, Object?> raw, List<String> hosts) {
    final url = raw['url'] == null ? null : _template(raw['url'], 'series.url', hosts, '{id}');
    final metadata = {
      for (final key in _metadataKeys)
        if (raw[key] != null) key: _Extractor.read(raw[key], 'series.$key'),
    };
    return _SeriesSpec(
      _pattern(raw['path'], 'series.path'),
      url,
      _flag(raw['json'], 'series.json'),
      raw['id'] == null ? null : _Extractor.read(raw['id'], 'series.id'),
      _Extractor.read(raw['title'], 'series.title'),
      raw['cover'] == null ? null : _Extractor.read(raw['cover'], 'series.cover', link: true),
      metadata,
      _ChaptersSpec.read(_object(raw['chapters'], 'series.chapters'), hosts),
    );
  }

  final RegExp path;
  final String? url;
  final bool json;
  final _Extractor? id;
  final _Extractor title;
  final _Extractor? cover;
  final Map<String, _Extractor> metadata;
  final _ChaptersSpec chapters;
}

class _ChaptersSpec {
  _ChaptersSpec(this.items, this.url, this.title, this.id, this.number, this.date, this.order, this.api);

  static _ChaptersSpec read(Map<String, Object?> raw, List<String> hosts) {
    final order = raw['order'] ?? 'auto';
    if (order != 'auto' && order != 'newest-first' && order != 'oldest-first') {
      throw const SiteDefinitionError('series.chapters.order: auto, newest-first o oldest-first.');
    }
    return _ChaptersSpec(
      _Extractor.read(raw['items'], 'series.chapters.items', all: true),
      _Extractor.read(raw['url'], 'series.chapters.url', link: true),
      _Extractor.read(raw['title'], 'series.chapters.title'),
      raw['id'] == null ? null : _Extractor.read(raw['id'], 'series.chapters.id'),
      raw['number'] == null ? null : _Extractor.read(raw['number'], 'series.chapters.number'),
      raw['date'] == null ? null : _Extractor.read(raw['date'], 'series.chapters.date'),
      order as String,
      raw['api'] == null ? null : _template(raw['api'], 'series.chapters.api', hosts, '{id}'),
    );
  }

  final _Extractor items;
  final _Extractor url;
  final _Extractor title;
  final _Extractor? id;
  final _Extractor? number;
  final _Extractor? date;
  final String order;
  final String? api;
}

class _PagesSpec {
  _PagesSpec(this.items, this.url, this.width, this.height);

  static _PagesSpec read(Map<String, Object?> raw) => _PagesSpec(
        _Extractor.read(raw['items'], 'chapter.pages.items', all: true),
        _Extractor.read(raw['url'] ?? const <String, Object?>{}, 'chapter.pages.url', link: true),
        raw['width'] == null ? null : _Extractor.read(raw['width'], 'chapter.pages.width'),
        raw['height'] == null ? null : _Extractor.read(raw['height'], 'chapter.pages.height'),
      );

  final _Extractor items;
  final _Extractor url;
  final _Extractor? width;
  final _Extractor? height;
}

class _ChapterSpec {
  _ChapterSpec(this.path, this.json, this.api, this.pages);

  static _ChapterSpec read(Map<String, Object?> raw, List<String> hosts) => _ChapterSpec(
        _pattern(raw['path'], 'chapter.path'),
        _flag(raw['json'], 'chapter.json'),
        raw['api'] == null ? null : _template(raw['api'], 'chapter.api', hosts, null),
        _PagesSpec.read(_object(raw['pages'], 'chapter.pages')),
      );

  final RegExp path;
  final bool json;
  final String? api;
  final _PagesSpec pages;
}

class _SearchSpec {
  _SearchSpec(this.url, this.json, this.items, this.title, this.link, this.cover, this.latest, this.status);

  static _SearchSpec read(Map<String, Object?> raw, List<String> hosts) => _SearchSpec(
        _template(raw['url'], 'search.url', hosts, '{query}'),
        _flag(raw['json'], 'search.json'),
        _Extractor.read(raw['items'], 'search.items', all: true),
        _Extractor.read(raw['title'], 'search.title'),
        _Extractor.read(raw['link'], 'search.link', link: true),
        raw['cover'] == null ? null : _Extractor.read(raw['cover'], 'search.cover', link: true),
        raw['latest'] == null ? null : _Extractor.read(raw['latest'], 'search.latest'),
        raw['status'] == null ? null : _Extractor.read(raw['status'], 'search.status'),
      );

  final String url;
  final bool json;
  final _Extractor items;
  final _Extractor title;
  final _Extractor link;
  final _Extractor? cover;
  final _Extractor? latest;
  final _Extractor? status;
}

String _string(Object? raw, String where) {
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  throw SiteDefinitionError('$where: serve un testo.');
}

Map<String, Object?> _object(Object? raw, String where) {
  if (raw is Map<String, Object?>) return raw;
  throw SiteDefinitionError('$where: serve un oggetto.');
}

bool _flag(Object? raw, String where) {
  if (raw == null) return false;
  if (raw is bool) return raw;
  throw SiteDefinitionError('$where: true o false.');
}

RegExp _pattern(Object? raw, String where) {
  final source = _string(raw, where);
  if (source.length > _maxPattern) throw SiteDefinitionError('$where: espressione oltre $_maxPattern caratteri.');
  final risky = _riskyPattern(source);
  if (risky != null) throw SiteDefinitionError('$where: $risky');
  try {
    return RegExp(source);
  } on FormatException {
    throw SiteDefinitionError('$where: espressione regolare non valida.');
  }
}

/// Controllo euristico sul sorgente (non una prova): rifiuta le
/// backreference e un gruppo quantificato con `+`, `*` o `{n,}` che contiene
/// a sua volta una ripetizione illimitata, come `(a+)+` o `(.*a){2,}`.
String? _riskyPattern(String source) {
  // Per ogni gruppo aperto: contiene una ripetizione illimitata?
  final open = <bool>[false];
  var i = 0;
  // Fine dell'eventuale quantificatore in [at]: (illimitato, prossimo indice).
  (bool, int) quantifier(int at) {
    if (at >= source.length) return (false, at);
    final c = source[at];
    var unbounded = c == '+' || c == '*';
    var end = at + 1;
    if (c == '{') {
      final found = RegExp(r'^\{(\d+)(,(\d*))?\}').firstMatch(source.substring(at));
      if (found == null) return (false, at);
      unbounded = found[2] != null && found[3]!.isEmpty;
      end = at + found[0]!.length;
    } else if (c != '?' && !unbounded) {
      return (false, at);
    }
    if (end < source.length && (source[end] == '?' || source[end] == '+')) end++;
    return (unbounded, end);
  }

  while (i < source.length) {
    final c = source[i];
    if (c == r'\') {
      final next = i + 1 < source.length ? source[i + 1] : '';
      if (RegExp(r'[1-9]').hasMatch(next) || next == 'k') return 'riferimenti a gruppi (backreference) non ammessi.';
      final (unbounded, after) = quantifier(i + 2);
      if (unbounded) open[open.length - 1] = true;
      i = after;
    } else if (c == '[') {
      i++;
      if (i < source.length && source[i] == '^') i++;
      if (i < source.length && source[i] == ']') i++;
      while (i < source.length && source[i] != ']') {
        i += source[i] == r'\' ? 2 : 1;
      }
      final (unbounded, after) = quantifier(i + 1);
      if (unbounded) open[open.length - 1] = true;
      i = after;
    } else if (c == '(') {
      open.add(false);
      i++;
    } else if (c == ')') {
      if (open.length == 1) return null;
      final inner = open.removeLast();
      final (unbounded, next) = quantifier(i + 1);
      if (unbounded && inner) return 'ripetizioni annidate (come (a+)+) non ammesse.';
      if (unbounded || inner) open[open.length - 1] = true;
      i = next;
    } else if (c == '^' || c == r'$' || c == '|') {
      i++;
    } else {
      final (unbounded, next) = quantifier(i + 1);
      if (unbounded) open[open.length - 1] = true;
      i = next;
    }
  }
  return null;
}

/// Un indirizzo con un segnaposto: con il segnaposto al posto di un valore
/// qualsiasi deve restare un link https su uno degli [hosts].
String _template(Object? raw, String where, List<String> hosts, String? placeholder) {
  final value = _string(raw, where);
  if (placeholder != null && !value.contains(placeholder)) throw SiteDefinitionError('$where: manca $placeholder.');
  final sample = value.replaceAll('{id}', 'x').replaceAll('{url}', 'x').replaceAll('{query}', 'x');
  try {
    checkUrl(sample, (uri) => hosts.contains(uri.host));
  } on ProviderError {
    throw SiteDefinitionError('$where: un link https su uno degli host del sito.');
  }
  // Il segnaposto non può stare nell'host: deciderebbe lui a chi chiedere.
  if (Uri.parse(sample).host != Uri.parse(value.replaceAll(RegExp(r'\{(id|url|query)\}'), 'y')).host) {
    throw SiteDefinitionError('$where: il segnaposto non può stare nell\'host.');
  }
  return value;
}

List<String> _hosts(Object? raw, String where, {required bool wildcard}) {
  if (raw is! List || raw.any((host) => host is! String)) throw SiteDefinitionError('$where: una lista di host.');
  final hosts = [for (final host in raw.cast<String>()) host.trim().toLowerCase()];
  for (final host in hosts) {
    if (!_hostPattern.hasMatch(host) || (!wildcard && host.startsWith('*.')) || !_publicHost(host.replaceFirst('*.', ''))) {
      throw SiteDefinitionError('$where: «$host» non è un nome di dominio pubblico.');
    }
    if (host.startsWith('*.') && host.split('.').length < 3) {
      throw SiteDefinitionError('$where: «$host» vale per un dominio intero.');
    }
  }
  return hosts;
}

/// Un nome di dominio, non un indirizzo IP né un nome della rete di casa.
bool _publicHost(String host) =>
    host.contains('.') &&
    !RegExp(r'^[\d.]+$').hasMatch(host) &&
    !host.contains(':') &&
    host != 'localhost' &&
    !_privateSuffixes.any(host.endsWith);
