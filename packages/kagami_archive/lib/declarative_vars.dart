// Variabili, modelli e indirizzi composti del formato 2 (`docs/siti.md`,
// «Variabili e modelli» e «Ripieghi»): ciò che non è un estrattore.
part of 'declarative.dart';

final RegExp _placeholder = RegExp(r'\{([a-z][A-Za-z0-9]*)\}');
final RegExp _varName = RegExp(r'^[a-z][A-Za-z0-9]{0,31}$');

/// Tetti del formato 2 (`docs/siti.md`, «Tetti del formato 2»).
const int _maxOperationVars = 64;
const int _maxTemplateText = 64 * 1024;
const int _maxAddress = 4 * 1024;
const int _maxValue = 2000000;
const int _maxAllValues = 8000000;
const int _maxFirst = 8;
const int _maxTry = 4;
const int _maxFallback = 2;

/// I nomi che un'operazione conosce in un punto del file, per rifiutare
/// all'installazione un modello che nomina una variabile che lì non c'è.
class _Scope {
  _Scope(this.names, {required this.v2});

  final Set<String> names;
  final bool v2;

  _Scope child() => _Scope({...names}, v2: v2);

  void declare(String name, String where) {
    if (!_varName.hasMatch(name)) throw SiteDefinitionError('$where: «$name» non è un nome di variabile valido.');
    if (names.contains(name)) throw SiteDefinitionError('$where: la variabile «$name» è già scritta.');
    names.add(name);
    if (names.length > _maxOperationVars) {
      throw SiteDefinitionError('$where: più di $_maxOperationVars variabili in un\'operazione.');
    }
  }
}

/// I valori delle variabili di un'operazione, con i tetti di peso.
class _Vars {
  _Vars(Map<String, Object?> initial)
      : _values = {},
        _bytes = 0 {
    initial.forEach(set);
  }

  _Vars._child(_Vars parent)
      : _values = {...parent._values},
        _bytes = parent._bytes;

  final Map<String, Object?> _values;
  int _bytes;

  /// Le variabili di un elemento: vedono quelle dell'operazione, non le
  /// lasciano all'elemento dopo.
  _Vars child() => _Vars._child(this);

  void set(String name, Object? value) {
    if (value == null) return;
    final size = _size(value);
    if (size > _maxValue) throw const ProviderError('Una variabile del sito supera i 2 MB.');
    _bytes += size;
    if (_bytes > _maxAllValues) throw const ProviderError('Le variabili del sito superano gli 8 MB.');
    _values[name] = value;
  }

  Object? operator [](String name) => _values[name];

  /// Il testo di una variabile in un modello: una lista o un oggetto JSON non
  /// hanno un testo, e contano come vuoti.
  String text(String name) => switch (_values[name]) {
        final String text => text,
        final num number => '$number',
        final bool flag => '$flag',
        final dom.Element element => element.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
        _ => '',
      };

  static int _size(Object? value) => switch (value) {
        String() => value.length,
        Uint8List() => value.length,
        List() => value.fold(0, (total, item) => total + _size(item)),
        Map() => jsonEncode(value).length,
        dom.Element() => value.outerHtml.length,
        dom.Node() => value.text?.length ?? 0,
        _ => 8,
      };
}

/// Un testo con `{nome}`.
class _Template {
  _Template(this.source) : names = {for (final found in _placeholder.allMatches(source)) found[1]!};

  static _Template read(Object? raw, String where, _Scope scope) {
    if (raw is! String || raw.trim().isEmpty) throw SiteDefinitionError('$where: serve un testo.');
    final template = _Template(raw);
    for (final name in template.names) {
      if (!scope.names.contains(name)) throw SiteDefinitionError('$where: variabile sconosciuta «{$name}».');
    }
    return template;
  }

  final String source;
  final Set<String> names;

  /// Il testo con le variabili sostituite, ognuna passata da [encode];
  /// `null` se una è vuota.
  String? render(_Vars vars, [String Function(String name, String text)? encode]) {
    var missing = false;
    final text = source.replaceAllMapped(_placeholder, (found) {
      final value = vars.text(found[1]!);
      if (value.isEmpty) missing = true;
      return encode == null ? value : encode(found[1]!, value);
    });
    if (missing) return null;
    if (text.length > _maxTemplateText) throw const ProviderError('Un modello del sito supera i 64 KB.');
    return text;
  }
}

/// Un indirizzo da chiedere: un modello e i suoi parametri.
class _Link {
  _Link(this.path, this.query);

  final _Template path;
  final Map<String, _Template> query;

  Set<String> get names => {...path.names, for (final value in query.values) ...value.names};

  /// L'indirizzo, o `null` se manca una variabile del percorso. Un parametro
  /// vuoto non si scrive.
  String? render(_Vars vars) {
    final base = path.render(
        vars, (name, text) => name == 'query' ? Uri.encodeQueryComponent(text) : Uri.encodeComponent(text));
    if (base == null) return null;
    final params = [
      for (final MapEntry(key: name, value: value) in query.entries)
        if (value.render(vars) case final text?) '${Uri.encodeQueryComponent(name)}=${Uri.encodeQueryComponent(text)}',
    ];
    final url = params.isEmpty ? base : '$base${base.contains('?') ? '&' : '?'}${params.join('&')}';
    if (url.length > _maxAddress) throw const ProviderError('Un indirizzo del sito supera i 4 KB.');
    return url;
  }
}

/// Un campo indirizzo: un [_Link] o, con `try`, fino a [_maxTry] da provare
/// in ordine finché uno non risponde con uno stato fuori da [on].
class _Address {
  _Address(this.alternatives, this.on);

  /// [needs]: la variabile che l'indirizzo deve usare (`id` per serie e
  /// capitoli, `query` per la ricerca). Nel formato 2 al posto di `id` basta
  /// una variabile qualsiasi: l'id dell'API può venire dalla pagina.
  static _Address read(Object? raw, String where, List<String> hosts, _Scope scope, {String? needs}) {
    var on = const {404};
    final List<Object?> sources;
    if (raw is Map<String, Object?> && raw.containsKey('try')) {
      _onlyKeys(raw, const {'try', 'on'}, where);
      final list = raw['try'];
      if (list is! List || list.isEmpty || list.length > _maxTry) {
        throw SiteDefinitionError('$where.try: una lista da 1 a $_maxTry indirizzi.');
      }
      sources = list;
      if (raw['on'] != null) {
        final codes = raw['on'];
        if (codes is! List || codes.isEmpty || codes.any((code) => code is! int || code < 400 || code > 599)) {
          throw SiteDefinitionError('$where.on: una lista di stati HTTP da 400 a 599.');
        }
        on = codes.cast<int>().toSet();
      }
    } else {
      sources = [raw];
    }
    final alternatives = [
      for (final (index, source) in sources.indexed)
        _link(source, sources.length == 1 ? where : '$where.try[$index]', hosts, scope, needs),
    ];
    return _Address(alternatives, on);
  }

  static _Link _link(Object? raw, String where, List<String> hosts, _Scope scope, String? needs) {
    final _Link link;
    if (raw is Map<String, Object?>) {
      _onlyKeys(raw, const {'template', 'query'}, where);
      final query = raw['query'] == null ? const <String, Object?>{} : _object(raw['query'], '$where.query');
      link = _Link(_Template.read(_string(raw['template'], '$where.template'), '$where.template', scope), {
        for (final MapEntry(key: name, value: value) in query.entries)
          name: _Template.read(value, '$where.query.$name', scope),
      });
    } else {
      link = _Link(_Template.read(_string(raw, where), where, scope), const {});
    }
    if (needs != null) {
      final ok = scope.v2 && needs == 'id' ? link.names.isNotEmpty : link.names.contains(needs);
      if (!ok) throw SiteDefinitionError(needs == 'id' && scope.v2 ? '$where: manca una variabile.' : '$where: manca {$needs}.');
    }
    final value = link.path.source;
    final sample = value.replaceAll(_placeholder, 'x');
    try {
      checkUrl(sample, (uri) => hosts.contains(uri.host));
    } on ProviderError {
      throw SiteDefinitionError('$where: un link https su uno degli host del sito.');
    }
    // Una variabile non può stare nell'host: deciderebbe lei a chi chiedere.
    if (Uri.parse(sample).host != Uri.parse(value.replaceAll(_placeholder, 'y')).host) {
      throw SiteDefinitionError('$where: il segnaposto non può stare nell\'host.');
    }
    return link;
  }

  final List<_Link> alternatives;
  final Set<int> on;
}

void _onlyKeys(Map<String, Object?> raw, Set<String> known, String where) {
  for (final key in raw.keys) {
    if (!known.contains(key)) throw SiteDefinitionError('$where: chiave sconosciuta «$key».');
  }
}

/// `vars` o `linkVars`: estrattori in ordine, ognuno vede i precedenti.
List<(String, _Extractor)> _readVars(Object? raw, String where, _Scope scope) {
  if (raw == null) return const [];
  final vars = <(String, _Extractor)>[];
  for (final MapEntry(key: name, value: value) in _object(raw, where).entries) {
    final extractor = _Extractor.read(value, '$where.$name', scope);
    scope.declare(name, where);
    vars.add((name, extractor));
  }
  return vars;
}

void _evaluate(List<(String, _Extractor)> declared, Object? node, _Context context) {
  for (final (name, extractor) in declared) {
    context.vars.set(name, extractor.capture(node, context));
  }
}
