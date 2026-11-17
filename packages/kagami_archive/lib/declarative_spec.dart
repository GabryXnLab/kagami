// Lettura e validazione di un file di sito (`docs/siti.md`): `_Spec.read` e le
// chiavi ammesse di ogni sua parte. Un errore qui non arriva mai a metà di un
// download.
part of 'declarative.dart';

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
    final format = json['format'];
    if (format != 1 && format != 2) {
      throw SiteDefinitionError('Formato del sito $format non supportato: questa versione legge l\'1 e il 2.');
    }
    final (:engine, :key) = siteMinEngine(json);
    if (format == 1 && engine > 1) throw SiteDefinitionError('«$key» vale solo con "format": 2.');
    if (engine > catalogEngine) throw SiteEngineError(engine, key!);
    final v2 = format == 2;
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
    final series = _SeriesSpec.read(_object(json['series'], 'series'), hosts, v2);
    return _Spec(
      id: id,
      name: _string(json['name'], 'name'),
      version: version,
      update: update,
      home: home,
      hosts: hosts,
      mediaHosts: mediaHosts,
      icon: icon,
      series: series,
      chapter: _ChapterSpec.read(_object(json['chapter'], 'chapter'), hosts, v2, series.chapters.keep),
      search: json['search'] == null ? null : _SearchSpec.read(_object(json['search'], 'search'), hosts, v2),
      browser: json['browser'] == null ? null : _BrowserSpec.read(_object(json['browser'], 'browser'), hosts),
    ).._checkRendered();
  }

  /// `browser.pages` vale solo per pagine HTML: una risposta JSON non ha DOM.
  void _checkRendered() {
    final rendered = browser?.pages ?? const <String>{};
    if (rendered.contains('series') && series.json) {
      throw const SiteDefinitionError('browser.pages: «series» non vale con series.json.');
    }
    if (rendered.contains('chapter')) {
      for (final block in [chapter, ...chapter.fallback]) {
        if (block.json || block.api != null) {
          throw SiteDefinitionError('browser.pages: «chapter» non vale con ${block.where}.json o ${block.where}.api.');
        }
      }
    }
    final search = this.search;
    if (rendered.contains('search') && search != null && [search, ...search.fallback].any((block) => block.json)) {
      throw const SiteDefinitionError('browser.pages: «search» non vale con search.json.');
    }
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
  _BrowserSpec(this.hosts, this.seriesReady, this.searchReady, this.chapterReady, this.pages);

  static _BrowserSpec read(Map<String, Object?> raw, List<String> siteHosts) {
    final hosts = _hosts(raw['hosts'], 'browser.hosts', wildcard: false);
    if (hosts.isEmpty) throw const SiteDefinitionError('browser.hosts: almeno un host.');
    for (final host in hosts) {
      if (!siteHosts.contains(host)) throw SiteDefinitionError('browser.hosts: «$host» non è fra gli hosts del sito.');
    }
    final pages = <String>{};
    if (raw['pages'] != null) {
      final list = raw['pages'];
      if (list is! List || list.isEmpty || list.length > 3) {
        throw const SiteDefinitionError('browser.pages: da uno a tre fra series, chapter e search.');
      }
      for (final page in list) {
        if (page is! String || !const {'series', 'chapter', 'search'}.contains(page) || !pages.add(page)) {
          throw const SiteDefinitionError('browser.pages: da uno a tre fra series, chapter e search, senza ripetizioni.');
        }
      }
    }
    final chapterReady = raw['chapterReady'] == null
        ? null
        : _Extractor._selector(_string(raw['chapterReady'], 'browser.chapterReady'), 'browser.chapterReady');
    if (pages.contains('chapter') && chapterReady == null) {
      throw const SiteDefinitionError('browser.chapterReady: obbligatorio con «chapter» in browser.pages.');
    }
    return _BrowserSpec(
      hosts,
      _Extractor._selector(_string(raw['seriesReady'], 'browser.seriesReady'), 'browser.seriesReady'),
      _Extractor._selector(_string(raw['searchReady'], 'browser.searchReady'), 'browser.searchReady'),
      chapterReady,
      pages,
    );
  }

  final List<String> hosts;
  final String seriesReady;
  final String searchReady;
  final String? chapterReady;

  /// Le pagine da leggere dal DOM reso (`series`, `chapter`, `search`).
  final Set<String> pages;
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
  _SeriesSpec(this.path, this.url, this.link, this.json, this.linkVars, this.vars, this.require, this.recipe, this.id, this.title,
      this.cover, this.metadata, this.chapters);

  static _SeriesSpec read(Map<String, Object?> raw, List<String> hosts, bool v2) {
    final scope = _Scope({'id', 'url'}, v2: v2);
    final linkVars = _readVars(raw['linkVars'], 'series.linkVars', scope);
    final url = raw['url'] == null ? null : _Address.read(raw['url'], 'series.url', hosts, scope, needs: 'id');
    final path = _pattern(raw['path'], 'series.path');
    final link = raw['link'] == null ? null : _readSeriesLink(raw['link'], path, hosts, linkVars, v2);
    final vars = _readVars(raw['vars'], 'series.vars', scope);
    final require = _Condition.readList(raw['require'], 'series.require', scope);
    final recipe = _Recipe.read(raw['recipe'], 'series.recipe', scope, hosts);
    final metadata = {
      for (final key in _metadataKeys)
        if (raw[key] != null) key: _Extractor.read(raw[key], 'series.$key', scope),
    };
    return _SeriesSpec(
      path,
      url,
      link,
      _flag(raw['json'], 'series.json'),
      linkVars,
      vars,
      require,
      recipe,
      raw['id'] == null ? null : _Extractor.read(raw['id'], 'series.id', scope),
      _Extractor.read(raw['title'], 'series.title', scope),
      raw['cover'] == null ? null : _Extractor.read(raw['cover'], 'series.cover', scope, link: true),
      metadata,
      _ChaptersSpec.read(_object(raw['chapters'], 'series.chapters'), hosts, scope),
    );
  }

  final RegExp path;
  final _Address? url;

  /// Il modello del link canonico (`docs/siti.md`, «Link canonico»); `null`: coincide con [url].
  final _Link? link;
  final bool json;
  final List<(String, _Extractor)> linkVars;
  final List<(String, _Extractor)> vars;
  final List<_Condition> require;

  /// `recipe` (`docs/siti.md`, «Ricetta»): dopo `vars` e `require`, prima dei campi.
  final _Recipe? recipe;
  final _Extractor? id;
  final _Extractor title;
  final _Extractor? cover;
  final Map<String, _Extractor> metadata;
  final _ChaptersSpec chapters;
}

/// `series.link`: solo `id` e `linkVars`, perché il link si compone senza richieste.
/// Il link composto dev'essere accettato da `series.path` e ricomporlo dal suo
/// stesso risultato deve dare lo stesso link: all'installazione si prova con
/// valori di prova (tutte «a», poi tutte «1»).
_Link _readSeriesLink(Object? raw, RegExp path, List<String> hosts, List<(String, _Extractor)> linkVars, bool v2) {
  if (raw is! String) throw const SiteDefinitionError('series.link: un modello di testo, senza query né try.');
  final names = [for (final (name, _) in linkVars) name];
  final link = _Address._link(raw, 'series.link', hosts, _Scope({'id', ...names}, v2: v2), null);
  for (final sample in const ['a', '1']) {
    final vars = _Vars({'id': sample, for (final name in names) name: sample});
    final first = link.render(vars);
    final found = first == null ? null : siteMatch(first, hosts: hosts.toSet(), path: path, maxPath: _maxMatchText);
    if (found == null || found.groupCount < 1 || found[1] == null) continue;
    vars.set('id', found[1]);
    if (link.render(vars) == first) return link;
  }
  throw const SiteDefinitionError('series.link: il link composto non è accettato da series.path, o non si ricompone uguale.');
}

class _ChaptersSpec {
  _ChaptersSpec(this.where, this.items, this.vars, this.skip, this.keep, this.url, this.title, this.id, this.number,
      this.date, this.order, this.api, this.expect, this.fallback);

  /// [where]: il percorso del blocco nel file, `series.chapters` o una sua riserva.
  static _ChaptersSpec read(Map<String, Object?> raw, List<String> hosts, _Scope scope,
      {String where = 'series.chapters'}) {
    final order = raw['order'] ?? 'auto';
    if (order != 'auto' && order != 'newest-first' && order != 'oldest-first') {
      throw SiteDefinitionError('$where.order: auto, newest-first o oldest-first.');
    }
    final api = raw['api'] == null ? null : _Address.read(raw['api'], '$where.api', hosts, scope, needs: 'id');
    final items = _Extractor.read(raw['items'], '$where.items', scope, all: true);
    final item = scope.child();
    final vars = _readVars(raw['vars'], '$where.vars', item);
    final keep = <String>[];
    if (raw['keep'] case final names?) {
      if (names is! List) throw SiteDefinitionError('$where.keep: una lista di variabili.');
      for (final name in names) {
        // `date` è già un dato del capitolo, e le variabili ne prenderebbero il posto.
        if (name is! String || name == 'date' || !vars.any((declared) => declared.$1 == name) || keep.contains(name)) {
          throw SiteDefinitionError('$where.keep: «$name» non è una variabile di $where.vars.');
        }
        keep.add(name);
      }
    }
    // Le riserve vedono le variabili della serie, non quelle del principale:
    // [scope] non ne ha ricevute, perché quelle dell'elemento stanno in [item].
    final fallback = [
      for (final (index, block) in _reserves(raw, where).indexed)
        _ChaptersSpec.read(block, hosts, scope, where: '$where.fallback[$index]'),
    ];
    for (final reserve in fallback) {
      // Le tavole leggono le variabili tenute qualunque strategia abbia dato l'elenco.
      if (reserve.keep.toSet().length != keep.length || !reserve.keep.every(keep.contains)) {
        throw SiteDefinitionError('${reserve.where}.keep: gli stessi nomi di $where.keep.');
      }
    }
    return _ChaptersSpec(
      where,
      items,
      vars,
      _Condition.readList(raw['skip'], '$where.skip', item),
      keep,
      _Extractor.read(raw['url'], '$where.url', item, link: true),
      _Extractor.read(raw['title'], '$where.title', item),
      raw['id'] == null ? null : _Extractor.read(raw['id'], '$where.id', item),
      raw['number'] == null ? null : _Extractor.read(raw['number'], '$where.number', item),
      raw['date'] == null ? null : _Extractor.read(raw['date'], '$where.date', item),
      order as String,
      api,
      raw['expect'] == null ? null : _Extractor.read(raw['expect'], '$where.expect', scope),
      fallback,
    );
  }

  final String where;

  final _Extractor items;
  final List<(String, _Extractor)> vars;

  /// Un capitolo per cui una vale si scarta (accesso anticipato, annunci).
  final List<_Condition> skip;

  /// Le variabili dell'elemento che viaggiano col capitolo (`Chapter.metadata`).
  final List<String> keep;
  final _Extractor url;
  final _Extractor title;
  final _Extractor? id;
  final _Extractor? number;
  final _Extractor? date;
  final String order;
  final _Address? api;

  /// Quanti capitoli il sito dichiara, letto dalla pagina della serie
  /// (`docs/siti.md`, «Conteggio dichiarato»).
  final _Extractor? expect;

  /// I blocchi di riserva, già validati: senza `fallback` né `path`.
  final List<_ChaptersSpec> fallback;
}

/// I blocchi di `fallback` di [raw] (`docs/siti.md`, «Blocchi di riserva»):
/// al più [_maxFallback], della forma del blocco che li contiene, senza
/// `path` (che riconosce i link ed è uno solo) e senza riserve proprie.
List<Map<String, Object?>> _reserves(Map<String, Object?> raw, String where) {
  final list = raw['fallback'];
  if (list == null) return const [];
  if (list is! List || list.isEmpty || list.length > _maxFallback) {
    throw SiteDefinitionError('$where.fallback: una lista da 1 a $_maxFallback blocchi.');
  }
  return [
    for (final (index, raw) in list.indexed)
      switch (_object(raw, '$where.fallback[$index]')) {
        final block when block.containsKey('fallback') =>
          throw SiteDefinitionError('$where.fallback[$index]: niente riserve annidate.'),
        final block when block.containsKey('path') =>
          throw SiteDefinitionError('$where.fallback[$index]: «path» sta solo nel blocco principale.'),
        final block => block,
      },
  ];
}

class _PagesSpec {
  _PagesSpec(this.items, this.vars, this.skip, this.url, this.width, this.height);

  static _PagesSpec read(Map<String, Object?> raw, _Scope scope, String where) {
    final items = _Extractor.read(raw['items'], '$where.items', scope, all: true);
    final item = scope.child();
    final vars = _readVars(raw['vars'], '$where.vars', item);
    return _PagesSpec(
      items,
      vars,
      _Condition.readList(raw['skip'], '$where.skip', item),
      _Extractor.read(raw['url'] ?? const <String, Object?>{}, '$where.url', item, link: true),
      raw['width'] == null ? null : _Extractor.read(raw['width'], '$where.width', item),
      raw['height'] == null ? null : _Extractor.read(raw['height'], '$where.height', item),
    );
  }

  final _Extractor items;
  final List<(String, _Extractor)> vars;
  final List<_Condition> skip;
  final _Extractor url;
  final _Extractor? width;
  final _Extractor? height;
}

class _ChapterSpec {
  _ChapterSpec(this.where, this.path, this.json, this.linkVars, this.api, this.vars, this.require, this.locked, this.recipe,
      this.pages, this.fallback);

  /// Nelle tavole `id` resta l'id del capitolo, come in `chapter.api` del
  /// formato 1, e le variabili di [keep] arrivano col capitolo. Una riserva
  /// ([path] dato) ha un ambito suo: non vede le variabili del principale.
  static _ChapterSpec read(Map<String, Object?> raw, List<String> hosts, bool v2, List<String> keep,
      {String where = 'chapter', RegExp? path}) {
    final scope = _Scope({'id', 'url', 'chapterId', ...keep}, v2: v2);
    final linkVars = _readVars(raw['linkVars'], '$where.linkVars', scope);
    final api = raw['api'] == null ? null : _Address.read(raw['api'], '$where.api', hosts, scope);
    final vars = _readVars(raw['vars'], '$where.vars', scope);
    final pattern = path ?? _pattern(raw['path'], '$where.path');
    final require = _Condition.readList(raw['require'], '$where.require', scope);
    final locked = raw['locked'] == null ? null : _Condition.read(raw['locked'], '$where.locked', scope);
    return _ChapterSpec(
      where,
      pattern,
      _flag(raw['json'], '$where.json'),
      linkVars,
      api,
      vars,
      require,
      locked,
      _Recipe.read(raw['recipe'], '$where.recipe', scope, hosts),
      _PagesSpec.read(_object(raw['pages'], '$where.pages'), scope, '$where.pages'),
      [
        for (final (index, block) in _reserves(raw, where).indexed)
          _ChapterSpec.read(block, hosts, v2, keep, where: '$where.fallback[$index]', path: pattern),
      ],
    );
  }

  final String where;
  final RegExp path;
  final bool json;
  final List<(String, _Extractor)> linkVars;
  final _Address? api;
  final List<(String, _Extractor)> vars;
  final List<_Condition> require;

  /// Se vale, il capitolo è riservato agli abbonati del sito.
  final _Condition? locked;
  final _Recipe? recipe;
  final _PagesSpec pages;
  final List<_ChapterSpec> fallback;
}

class _SearchSpec {
  _SearchSpec(this.where, this.url, this.json, this.vars, this.require, this.recipe, this.skip, this.items, this.title,
      this.link, this.cover, this.latest, this.status, this.fallback);

  static _SearchSpec read(Map<String, Object?> raw, List<String> hosts, bool v2, {String where = 'search'}) {
    final scope = _Scope({'query'}, v2: v2);
    final url = _Address.read(raw['url'], '$where.url', hosts, scope, needs: 'query');
    final vars = _readVars(raw['vars'], '$where.vars', scope);
    final require = _Condition.readList(raw['require'], '$where.require', scope);
    final recipe = _Recipe.read(raw['recipe'], '$where.recipe', scope, hosts);
    return _SearchSpec(
      where,
      url,
      _flag(raw['json'], '$where.json'),
      vars,
      require,
      recipe,
      _Condition.readList(raw['skip'], '$where.skip', scope),
      _Extractor.read(raw['items'], '$where.items', scope, all: true),
      _Extractor.read(raw['title'], '$where.title', scope),
      _Extractor.read(raw['link'], '$where.link', scope, link: true),
      raw['cover'] == null ? null : _Extractor.read(raw['cover'], '$where.cover', scope, link: true),
      raw['latest'] == null ? null : _Extractor.read(raw['latest'], '$where.latest', scope),
      raw['status'] == null ? null : _Extractor.read(raw['status'], '$where.status', scope),
      [
        for (final (index, block) in _reserves(raw, where).indexed)
          _SearchSpec.read(block, hosts, v2, where: '$where.fallback[$index]'),
      ],
    );
  }

  final String where;

  final _Address url;
  final bool json;
  final List<(String, _Extractor)> vars;
  final List<_Condition> require;
  final _Recipe? recipe;
  final List<_Condition> skip;
  final _Extractor items;
  final _Extractor title;
  final _Extractor link;
  final _Extractor? cover;
  final _Extractor? latest;
  final _Extractor? status;
  final List<_SearchSpec> fallback;
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
