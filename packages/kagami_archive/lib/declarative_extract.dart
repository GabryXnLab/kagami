// Estrattori del formato 2 (`docs/siti.md`, «Estrattori»): leggere un valore da
// un nodo (documento, elemento HTML o JSON) e valutarlo.
part of 'declarative.dart';

class _Context {
  const _Context(this.page, this.vars, {this.url});

  final String page;
  final _Vars vars;

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
    this.variable,
    this.template,
    this.base,
    this.alternatives,
    this.filters,
    this.jsonAt,
    this.field,
  });

  /// [scope]: le variabili che `var` e i modelli possono nominare lì.
  static _Extractor read(Object? raw, String where, _Scope scope, {bool link = false, bool all = false}) {
    if (raw is String) return _Extractor(css: _selector(raw, where), link: link, all: all);
    if (raw is! Map<String, Object?>) throw SiteDefinitionError('$where: serve un selettore o un oggetto.');
    if (raw['first'] case final list?) {
      if (raw.length != 1) throw SiteDefinitionError('$where: «first» va da solo.');
      if (list is! List || list.isEmpty || list.length > _maxFirst) {
        throw SiteDefinitionError('$where.first: una lista da 1 a $_maxFirst estrattori.');
      }
      final alternatives = [
        for (final (index, item) in list.indexed) read(item, '$where.first[$index]', scope, link: link, all: all),
      ];
      return _Extractor(
          alternatives: alternatives, field: where, link: link, all: alternatives.any((item) => item.all));
    }
    _onlyKeys(raw, const {'css', 'json', 'attr', 'html', 'regex', 'split', 'all', 'from', 'value', 'var', 'template', 'base', 'filters', 'jsonAt'}, where);
    if ((raw.containsKey('var') || raw.containsKey('template')) &&
        ['from', 'value', 'var', 'template'].where(raw.containsKey).length > 1) {
      throw SiteDefinitionError('$where: uno solo fra from, value, var e template.');
    }
    final variable = raw['var'];
    if (variable != null && (variable is! String || !scope.names.contains(variable))) {
      throw SiteDefinitionError('$where.var: variabile sconosciuta «$variable».');
    }
    final attr = raw['attr'];
    final from = raw['from'];
    if (from != null && from != 'url' && from != 'page') throw SiteDefinitionError('$where: «from» è url o page.');
    return _Extractor(
      variable: variable as String?,
      template: raw['template'] == null ? null : _Template.read(raw['template'], '$where.template', scope),
      base: raw['base'] == null ? null : _Template.read(raw['base'], '$where.base', scope),
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
      filters: _readFilters(raw['filters'], '$where.filters'),
      jsonAt: raw['jsonAt'] == null ? null : _pattern(raw['jsonAt'], '$where.jsonAt'),
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

  /// `var`: si parte dal valore di questa variabile invece che dal nodo.
  final String? variable;

  /// `template`: si parte dal testo composto.
  final _Template? template;

  /// `base`: il link rispetto a cui risolvere, al posto della pagina.
  final _Template? base;

  /// `first`: vale la prima alternativa non vuota.
  final List<_Extractor>? alternatives;

  /// Il percorso del campo che contiene `first`, per [SiteTrace].
  final String? field;

  void _won(int index) {
    if (index > 0) SiteTrace.current?.note(field!, index + 1);
  }

  /// `filters`: trasformazioni di ogni valore, prima di risolverlo come link.
  final List<_Filter>? filters;

  /// `jsonAt`: dove comincia, dentro un testo, il JSON da leggere.
  final RegExp? jsonAt;

  String? _filtered(String text) {
    String? current = text;
    for (final filter in filters ?? const <_Filter>[]) {
      current = filter(current!);
      if (current == null || current.isEmpty) return null;
    }
    return current;
  }

  /// I nodi trovati, per gli elenchi (`items`).
  List<Object?> nodes(Object? node, _Context context) {
    if (alternatives case final list?) {
      for (final (index, alternative) in list.indexed) {
        final found = alternative.nodes(node, context);
        if (found.isEmpty) continue;
        _won(index);
        return found;
      }
      return const [];
    }
    var current = <Object?>[];
    if (variable case final name?) {
      current = switch (context.vars[name]) {
        null => [],
        final Uint8List bytes => [bytes],
        final List<Object?> list => [...list],
        final value => [value],
      };
    } else if (template case final template?) {
      current = [?template.render(context.vars)];
    } else {
      current = [
        switch (from) {
          'url' => context.url,
          'page' => context.page,
          _ => node,
        },
      ];
    }
    if (css case final selector?) {
      current = [
        for (final item in current)
          ..._select(item, selector, all: all),
      ];
    }
    if (jsonAt case final pattern?) current = [?_jsonAfter(current, pattern)];
    if (json case final path?) {
      current = [for (final item in current) ..._walk(_asJson(item), path)];
      if (!all && current.length > 1) current = [current.first];
    }
    return current;
  }

  /// I valori come testi, già ripuliti e filtrati da [regex] e [split].
  List<String> strings(Object? node, _Context context) {
    if (alternatives case final list?) {
      for (final (index, alternative) in list.indexed) {
        final found = alternative.strings(node, context);
        if (found.isEmpty) continue;
        _won(index);
        return found;
      }
      return const [];
    }
    if (value case final fixed?) return [?_filtered(fixed)];
    final String resolveFrom;
    if (base case final template?) {
      final rendered = template.render(context.vars);
      if (rendered == null) return const [];
      resolveFrom = rendered;
    } else {
      resolveFrom = context.page;
    }
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
        if (filters != null) {
          final filtered = _filtered(part);
          if (filtered == null) continue;
          part = filtered;
        }
        if (link || base != null) {
          final resolved = Uri.tryParse(resolveFrom)?.resolve(part).toString();
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

  /// Il valore di una variabile: il JSON o gli elementi HTML così come sono se
  /// l'estrattore si limita a selezionarli (così `var` può proseguire da lì),
  /// altrimenti i testi; `null` se è vuoto.
  Object? capture(Object? node, _Context context) {
    if (alternatives case final list?) {
      for (final (index, alternative) in list.indexed) {
        final found = alternative.capture(node, context);
        if (found == null) continue;
        _won(index);
        return found;
      }
      return null;
    }
    final selects = attrs.isEmpty && regex == null && split == null && !asHtml && value == null &&
        template == null && base == null && !link && filters == null;
    if (selects) {
      final found = nodes(node, context);
      if (found.isNotEmpty && found.every((item) => item is Map || item is List || item is dom.Node)) {
        // Con jsonAt e senza json, `all` sceglie fra quali elementi cercare:
        // il valore è uno solo.
        return all && (jsonAt == null || json != null) ? found : found.first;
      }
    }
    final texts = strings(node, context);
    if (texts.isEmpty) return null;
    return all || split != null ? texts : texts.first;
  }

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

  /// Il JSON che segue [pattern] nel primo elemento di [items] in cui
  /// l'espressione si trova; `null` se lì non c'è un JSON valido.
  static Object? _jsonAfter(List<Object?> items, RegExp pattern) {
    for (final item in items) {
      final text = switch (item) {
        dom.Element() => item.text,
        dom.Document() => item.documentElement?.text,
        String() => item,
        _ => null,
      };
      if (text == null) continue;
      final found = pattern.firstMatch(_clip(text));
      if (found == null) continue;
      return _balancedJson(text, found.end);
    }
    return null;
  }

  /// L'oggetto o la lista che comincia in [start] (dopo gli spazi), fino alla
  /// parentesi che lo chiude, contando quelle fuori dalle stringhe.
  static Object? _balancedJson(String text, int start) {
    var begin = start;
    while (begin < text.length && ' \t\n\r'.contains(text[begin])) {
      begin++;
    }
    if (begin >= text.length || (text[begin] != '{' && text[begin] != '[')) return null;
    var depth = 0;
    var quoted = false;
    for (var at = begin; at < text.length; at++) {
      if (at - begin >= _maxValue) throw const ProviderError('Un valore JSON del sito supera i 2 MB.');
      final char = text[at];
      if (quoted) {
        if (char == r'\') {
          at++;
        } else if (char == '"') {
          quoted = false;
        }
      } else if (char == '"') {
        quoted = true;
      } else if (char == '{' || char == '[') {
        depth++;
      } else if ((char == '}' || char == ']') && --depth == 0) {
        try {
          return jsonDecode(text.substring(begin, at + 1));
        } on FormatException {
          return null;
        }
      }
    }
    return null;
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
