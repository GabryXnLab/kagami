// La ricetta del formato 2 (`docs/siti.md`, «Ricetta»): passi che danno una
// variabile ciascuno, eseguiti una volta dopo `vars` e prima dei campi. Ogni
// passo ha un tipo d'uscita fisso, così un passo che riceve il tipo sbagliato
// si rifiuta all'installazione e non a metà di un capitolo.
part of 'declarative.dart';

/// Tetti della ricetta (`docs/siti.md`, «Tetti del formato 2»).
const int _maxRecipe = 32;
const int _maxRecipeRun = 2048;
const int _maxIntExpr = 200;
const int _maxRange = 256;

/// Il tipo di un valore della ricetta. [any] è una variabile letta dalla
/// pagina (`vars`, `get`): testo o JSON, si sa solo leggendola.
enum _Kind {
  text('testo'),
  bytes('byte'),
  integer('intero'),
  json('JSON'),
  any('testo o JSON');

  const _Kind(this.label);

  final String label;
}

/// Un passo che non ha dato il suo valore: diventa un `ProviderChanged` col
/// percorso del passo.
class _RecipeFailure implements Exception {
  const _RecipeFailure(this.detail);

  final String detail;
}

final RegExp _exactVar = RegExp(r'^\{([a-z][A-Za-z0-9]*)\}$');

/// Un ingresso: `{nome}` esatto passa il valore com'è, un altro testo è un modello.
class _Input {
  _Input(this.kind, this._value);

  static _Input read(Object? raw, String where, _Scope scope, Map<String, _Kind> kinds) {
    final found = raw is String ? _exactVar.firstMatch(raw.trim()) : null;
    if (found != null) {
      final name = found[1]!;
      if (!scope.names.contains(name)) throw SiteDefinitionError('$where: variabile sconosciuta «{$name}».');
      return _Input(kinds[name] ?? _Kind.any, (vars) => vars[name]);
    }
    final template = _textTemplate(raw, where, scope, kinds);
    return _Input(_Kind.text, template.render);
  }

  final _Kind kind;
  final Object? Function(_Vars vars) _value;

  Object? value(_Vars vars) => _value(vars);
}

/// Un modello della ricetta: i byte non hanno un testo da metterci dentro.
_Template _textTemplate(Object? raw, String where, _Scope scope, Map<String, _Kind> kinds) {
  final template = _Template.read(raw, where, scope);
  for (final name in template.names) {
    if (kinds[name] == _Kind.bytes) throw SiteDefinitionError('$where: «{$name}» sono byte, non testo.');
  }
  return template;
}

void _accept(_Kind kind, Set<_Kind> allowed, String where) {
  if (kind == _Kind.any || allowed.contains(kind)) return;
  throw SiteDefinitionError('$where: atteso ${allowed.map((kind) => kind.label).join(' o ')}, arriva ${kind.label}.');
}

/// Il testo di un valore letto dalla pagina; `null` se non ne ha uno.
String? _plainText(Object? value) => switch (value) {
      final String text => text,
      final num number => '$number',
      final dom.Element element => element.text,
      _ => null,
    };

String _describe(Object? value) => switch (value) {
      Uint8List() => 'byte',
      Map() => 'un oggetto',
      List() => 'una lista',
      _ => 'un valore',
    };

/// [value] come testo, o un guasto se non lo è; `null` se la variabile è vuota.
String? _textOf(Object? value) {
  if (value == null) return null;
  return _plainText(value) ?? (throw _RecipeFailure('atteso un testo, arrivato ${_describe(value)}'));
}

/// Il testo del risultato per `check`.
String _resultText(Object? value) => switch (value) {
      null => '',
      Map() || List() => jsonEncode(value),
      _ => _plainText(value) ?? '',
    };

/// `fetch`: chiede [address] con le variabili di [vars]; la risposta come
/// JSON con [json], altrimenti come testo.
typedef _Fetch = Future<Object?> Function(_Address address, _Vars vars, String field, {required bool json});

/// Ciò che una ricetta in corso dà ai suoi passi: la pagina, il conto dei
/// passi eseguiti e la rete.
class _Run {
  _Run(this.page, this.budget, this.fetch, this.site);

  final Object? page;
  final _Budget budget;
  final _Fetch fetch;
  final String site;

  /// Un passo eseguito in più, contro `_maxRecipeRun`: le ripetizioni di
  /// `range` contano una per una.
  void count() {
    if (++budget.steps > _maxRecipeRun) {
      throw ProviderError('La ricetta del sito $site supera i $_maxRecipeRun passi in un\'operazione.');
    }
  }
}

typedef _Operation = FutureOr<Object?> Function(_Context context, _Run run);

class _Step {
  _Step(this.name, this.kind, this.operation, this.when, this.check);

  final String name;
  final _Kind kind;
  final _Operation operation;
  final _IntExpr? when;
  final RegExp? check;
}

const Set<String> _stepOperations = {
  'get',
  'template',
  'json',
  'base64',
  'hex',
  'utf8',
  'hmacSha256',
  'xor',
  'intExpr',
  'switch',
  'range',
  'fetch',
};

/// Le chiavi che accompagnano [operation] nel passo.
Set<String> _modifiers(String operation) => switch (operation) {
      'base64' => const {'url', 'encode'},
      'hex' => const {'encode'},
      'switch' => const {'cases', 'default'},
      'range' => const {'do'},
      'fetch' => const {'json'},
      _ => const <String>{},
    };

/// L'operazione di [step]; accanto a `fetch`, `json` è il suo modificatore.
String _operationOf(Map<String, Object?> step, String at) {
  final operations = _stepOperations.where(step.containsKey).toList();
  if (operations.contains('fetch')) operations.remove('json');
  if (operations.length != 1) throw SiteDefinitionError('$at: un passo fra ${_stepOperations.join(', ')}.');
  return operations.single;
}

class _Recipe {
  _Recipe(this.where, this.steps);

  /// [where]: il percorso della ricetta nel file (`chapter.recipe`). Ogni
  /// passo dichiara la sua variabile in [scope], dove la vedono i campi.
  /// [hosts]: i domini del sito, gli unici che `fetch` può chiedere.
  static _Recipe? read(Object? raw, String where, _Scope scope, List<String> hosts) {
    if (raw == null) return null;
    if (raw is! List || raw.isEmpty || raw.length > _maxRecipe) {
      throw SiteDefinitionError('$where: una lista da 1 a $_maxRecipe passi.');
    }
    final kinds = <String, _Kind>{};
    final steps = <_Step>[];
    for (final (index, item) in raw.indexed) {
      final at = '$where[$index]';
      final step = _object(item, at);
      final operation = _operationOf(step, at);
      _onlyKeys(step, {'let', 'check', 'when', operation, ..._modifiers(operation)}, at);
      final name = step['let'];
      if (name is! String) throw SiteDefinitionError('$at.let: il nome della variabile.');
      final when = step['when'] == null ? null : _IntExpr.read(step['when'], '$at.when', scope, kinds);
      final (kind, run) = _operation(operation, step, '$at.$operation', scope, kinds, hosts);
      if (step['check'] != null && kind == _Kind.bytes) throw SiteDefinitionError('$at.check: i byte non hanno un testo.');
      final check = step['check'] == null ? null : _pattern(step['check'], '$at.check');
      scope.declare(name, '$at.let');
      kinds[name] = kind;
      steps.add(_Step(name, kind, run, when, check));
    }
    return _Recipe(where, steps);
  }

  static (_Kind, _Operation) _operation(String operation, Map<String, Object?> step, String at, _Scope scope,
      Map<String, _Kind> kinds, List<String> hosts) {
    final raw = step[operation];
    switch (operation) {
      case 'get':
        final extractor = _Extractor.read(raw, at, scope);
        return (_Kind.any, (context, run) => extractor.capture(run.page, context));
      case 'template':
        final template = _textTemplate(raw, at, scope, kinds);
        return (_Kind.text, (context, run) => template.render(context.vars));
      case 'json':
        final input = _Input.read(raw, at, scope, kinds);
        _accept(input.kind, const {_Kind.text, _Kind.bytes}, at);
        return (_Kind.json, (context, run) => _decodeJson(input.value(context.vars)));
      case 'base64' || 'hex':
        final input = _Input.read(raw, at, scope, kinds);
        final encode = _flag(step['encode'], '${at.substring(0, at.lastIndexOf('.'))}.encode');
        final url = _flag(step['url'], '${at.substring(0, at.lastIndexOf('.'))}.url');
        if (encode) {
          _accept(input.kind, const {_Kind.bytes, _Kind.text}, at);
          return (_Kind.text, (context, run) => _encode(operation, input.value(context.vars), url: url));
        }
        _accept(input.kind, const {_Kind.text}, at);
        return (
          _Kind.bytes,
          (context, run) => switch (_textOf(input.value(context.vars))) {
                null => null,
                final text => operation == 'hex' ? _fromHex(text) : _fromBase64(text, url: url),
              },
        );
      case 'utf8':
        final input = _Input.read(raw, at, scope, kinds);
        _accept(input.kind, const {_Kind.bytes}, at);
        return (_Kind.text, (context, run) => _decodeUtf8(input.value(context.vars)));
      case 'hmacSha256':
        final spec = _object(raw, at);
        _onlyKeys(spec, const {'key', 'message'}, at);
        final key = _Input.read(spec['key'], '$at.key', scope, kinds);
        _accept(key.kind, const {_Kind.text, _Kind.bytes}, '$at.key');
        final message = _textTemplate(spec['message'], '$at.message', scope, kinds);
        return (
          _Kind.bytes,
          (context, run) {
            final secret = _bytesOf(key.value(context.vars));
            final text = message.render(context.vars);
            if (secret == null || text == null) return null;
            return Uint8List.fromList(Hmac(sha256, secret).convert(utf8.encode(text)).bytes);
          },
        );
      case 'xor':
        final spec = _object(raw, at);
        _onlyKeys(spec, const {'data', 'key'}, at);
        final data = _Input.read(spec['data'], '$at.data', scope, kinds);
        final key = _Input.read(spec['key'], '$at.key', scope, kinds);
        _accept(data.kind, const {_Kind.bytes}, '$at.data');
        _accept(key.kind, const {_Kind.bytes}, '$at.key');
        return (_Kind.bytes, (context, run) => _xor(data.value(context.vars), key.value(context.vars)));
      case 'intExpr':
        final expression = _IntExpr.read(raw, at, scope, kinds);
        return (_Kind.integer, (context, run) => expression.evaluate(context.vars));
      case 'range':
        return _range(step, at, scope, kinds, hosts);
      case 'fetch':
        final address = _Address.read(raw, at, hosts, scope);
        for (final link in address.alternatives) {
          for (final name in link.names) {
            if (kinds[name] == _Kind.bytes) throw SiteDefinitionError('$at: «{$name}» sono byte, non testo.');
          }
        }
        final json = _flag(step['json'], '${at.substring(0, at.lastIndexOf('.'))}.json');
        return (
          json ? _Kind.json : _Kind.text,
          (context, run) {
            // Un ingresso vuoto dà un risultato vuoto, senza chiedere niente.
            if (address.alternatives.any((link) => link.render(context.vars) == null)) return null;
            return run.fetch(address, context.vars, at, json: json);
          },
        );
      default:
        return _switch(step, at, scope, kinds);
    }
  }

  /// `range`: il passo di `do` ripetuto con `as` da 0 a count−1. Non si
  /// annida e non chiede niente alla rete, così il lavoro massimo di un file
  /// si conosce leggendolo.
  static (_Kind, _Operation) _range(
      Map<String, Object?> step, String at, _Scope scope, Map<String, _Kind> kinds, List<String> hosts) {
    final where = at.substring(0, at.lastIndexOf('.'));
    final spec = _object(step['range'], at);
    _onlyKeys(spec, const {'count', 'max', 'as'}, at);
    final max = spec['max'];
    if (max is! int || max < 1 || max > _maxRange) throw SiteDefinitionError('$at.max: un intero da 1 a $_maxRange.');
    final count = _IntExpr.read(spec['count'], '$at.count', scope, kinds);
    if (count.constant) {
      final int times;
      try {
        times = count.evaluate(_Vars(const {}));
      } on _RecipeFailure catch (failure) {
        throw SiteDefinitionError('$at.count: ${failure.detail}.');
      }
      if (times < 0 || times > max) throw SiteDefinitionError('$at.count: $times ripetizioni, fuori da 0…$max.');
    }
    final name = _string(spec['as'], '$at.as');
    final inner = scope.child()..declare(name, '$at.as');
    final innerKinds = {...kinds, name: _Kind.integer};
    final body = _object(step['do'], '$where.do');
    final operation = _operationOf(body, '$where.do');
    if (operation == 'range' || operation == 'fetch') {
      throw SiteDefinitionError('$where.do: un passo solo, né range né fetch.');
    }
    _onlyKeys(body, {operation, ..._modifiers(operation)}, '$where.do');
    final (kind, repeated) = _operation(operation, body, '$where.do.$operation', inner, innerKinds, hosts);
    final bytes = kind == _Kind.bytes;
    return (
      bytes ? _Kind.bytes : _Kind.json,
      (context, run) async {
        final times = count.evaluate(context.vars);
        if (times < 0 || times > max) throw _RecipeFailure('range: $times ripetizioni, fuori da 0…$max');
        final parts = <Object?>[];
        var size = 0;
        for (var index = 0; index < times; index++) {
          run.count();
          final vars = context.vars.child()..set(name, index);
          final value = await repeated(_Context(context.page, vars, url: context.url), run);
          size += _Vars._size(value);
          if (size > _maxValue) throw const ProviderError('Una variabile del sito supera i 2 MB.');
          if (bytes) {
            if (value != null) parts.add(value);
          } else {
            parts.add(value);
          }
        }
        if (!bytes) return parts;
        final joined = BytesBuilder(copy: false);
        for (final part in parts) {
          joined.add(part! as Uint8List);
        }
        return joined.takeBytes();
      },
    );
  }

  static (_Kind, _Operation) _switch(Map<String, Object?> step, String at, _Scope scope, Map<String, _Kind> kinds) {
    final where = at.substring(0, at.lastIndexOf('.'));
    final selector = _textTemplate(step['switch'], at, scope, kinds);
    final cases = {
      for (final MapEntry(key: label, value: value) in _object(step['cases'], '$where.cases').entries)
        label: _Input.read(value, '$where.cases.$label', scope, kinds),
    };
    if (cases.isEmpty) throw SiteDefinitionError('$where.cases: almeno un caso.');
    final fallback = step['default'] == null ? null : _Input.read(step['default'], '$where.default', scope, kinds);
    // Un tipo solo per tutti i casi: il passo dopo deve saperlo già adesso.
    var kind = cases.values.first.kind;
    for (final input in [...cases.values, ?fallback]) {
      if (input.kind == kind) continue;
      if ({input.kind, kind}.difference(const {_Kind.text, _Kind.any}).isEmpty) {
        kind = _Kind.any;
        continue;
      }
      throw SiteDefinitionError('$where.cases: i casi danno tipi diversi (${kind.label}, ${input.kind.label}).');
    }
    return (
      kind,
      (context, run) {
        final key = selector.render(context.vars) ?? '';
        final chosen = cases[key] ?? fallback;
        if (chosen == null) throw _RecipeFailure('nessun caso per «$key»');
        return chosen.value(context.vars);
      },
    );
  }

  final String where;
  final List<_Step> steps;

  /// Esegue i passi in ordine su [context]. [phase] e [site] servono al guasto.
  Future<void> run(Object? page, _Context context, _Budget budget, _Fetch fetch, String phase, String site) async {
    final run = _Run(page, budget, fetch, site);
    for (final (index, step) in steps.indexed) {
      run.count();
      try {
        if (step.when case final condition? when condition.evaluate(context.vars) == 0) continue;
        final value = await step.operation(context, run);
        if (step.check case final check? when !check.hasMatch(_clip(_resultText(value)))) {
          final text = _resultText(value);
          throw _RecipeFailure(text.isEmpty
              ? '«check» non soddisfatto: valore vuoto'
              : '«check» non soddisfatto: ${text.length > 60 ? '${text.substring(0, 60)}…' : text}');
        }
        context.vars.set(step.name, value);
      } on _RecipeFailure catch (failure) {
        throw ProviderChanged(
          'Il sito $site ha cambiato forma: ${failure.detail}.',
          fault: SiteFault(phase, field: '$where[$index]', detail: failure.detail, url: context.page),
        );
      }
    }
  }
}

Object? _decodeJson(Object? value) {
  final String text;
  switch (value) {
    case null:
      return null;
    case final Uint8List bytes:
      text = _decodeUtf8(bytes)!;
    default:
      text = _textOf(value)!;
  }
  try {
    return jsonDecode(text);
  } on FormatException {
    throw const _RecipeFailure('JSON non valido');
  }
}

String? _decodeUtf8(Object? value) {
  if (value == null) return null;
  if (value is! Uint8List) throw _RecipeFailure('attesi byte, arrivato ${_describe(value)}');
  try {
    return utf8.decode(value);
  } on FormatException {
    throw const _RecipeFailure('UTF-8 non valido');
  }
}

/// La chiave di `hmacSha256`: byte, o un testo in UTF-8.
Uint8List? _bytesOf(Object? value) => switch (value) {
      null => null,
      final Uint8List bytes => bytes,
      _ => utf8.encode(_textOf(value)!),
    };

/// [data] con [key] ripetuta quanto serve.
Uint8List? _xor(Object? data, Object? key) {
  if (data == null || key == null) return null;
  if (data is! Uint8List) throw _RecipeFailure('xor: attesi byte, arrivato ${_describe(data)}');
  if (key is! Uint8List) throw _RecipeFailure('xor: attesi byte, arrivato ${_describe(key)}');
  if (key.isEmpty) throw const _RecipeFailure('xor: chiave vuota');
  return Uint8List.fromList([for (var at = 0; at < data.length; at++) data[at] ^ key[at % key.length]]);
}

final RegExp _base64Alphabet = RegExp(r'^[A-Za-z0-9+/]*=*$');
final RegExp _base64UrlAlphabet = RegExp(r'^[A-Za-z0-9_-]*=*$');
final RegExp _hexText = RegExp(r'^(?:[0-9a-fA-F]{2})*$');

/// Il riempimento `=` mancante si aggiunge; l'alfabeto è uno solo dei due.
Uint8List _fromBase64(String text, {required bool url}) {
  final trimmed = text.trim();
  if (!(url ? _base64UrlAlphabet : _base64Alphabet).hasMatch(trimmed)) {
    throw _RecipeFailure(url ? 'base64url non valido' : 'base64 non valido');
  }
  try {
    final normalized = base64.normalize(trimmed);
    return base64.decode(url ? normalized.replaceAll('-', '+').replaceAll('_', '/') : normalized);
  } on FormatException {
    throw _RecipeFailure(url ? 'base64url non valido' : 'base64 non valido');
  }
}

Uint8List _fromHex(String text) {
  final trimmed = text.trim();
  if (!_hexText.hasMatch(trimmed)) throw const _RecipeFailure('esadecimale non valido');
  return Uint8List.fromList([
    for (var at = 0; at < trimmed.length; at += 2) int.parse(trimmed.substring(at, at + 2), radix: 16),
  ]);
}

String? _encode(String operation, Object? value, {required bool url}) {
  if (value == null) return null;
  final bytes = value is Uint8List ? value : utf8.encode(_textOf(value)!);
  if (operation == 'hex') return [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();
  return url ? base64Url.encode(bytes) : base64.encode(bytes);
}

/// `intExpr` e `when`: un'espressione su interi a 64 bit, letta una volta
/// all'installazione. Il motore non valuta mai espressioni lette dalle pagine.
class _IntExpr {
  _IntExpr(this._evaluate, {required this.constant});

  static _IntExpr read(Object? raw, String where, _Scope scope, Map<String, _Kind> kinds) {
    final source = _string(raw, where);
    if (source.length > _maxIntExpr) throw SiteDefinitionError('$where: espressione oltre $_maxIntExpr caratteri.');
    final tokens = <String>[];
    var rest = source;
    while (rest.isNotEmpty) {
      final found = _intToken.matchAsPrefix(rest);
      if (found == null) throw SiteDefinitionError('$where: simbolo non valido «${rest[0]}».');
      if (found[0]!.trim().isNotEmpty) tokens.add(found[0]!);
      rest = rest.substring(found.end);
    }
    final parser = _IntParser(tokens, where, scope, kinds);
    final evaluate = parser.expression(0);
    if (parser.at < tokens.length) throw SiteDefinitionError('$where: «${tokens[parser.at]}» in più.');
    return _IntExpr(evaluate, constant: !tokens.any((token) => RegExp(r'^[a-z]').hasMatch(token)));
  }

  final int Function(_Vars vars) _evaluate;

  /// Senza variabili: il valore si conosce già all'installazione.
  final bool constant;

  int evaluate(_Vars vars) => _evaluate(vars);
}

final RegExp _intToken = RegExp(r'\s+|\d+|[a-z][A-Za-z0-9]*|<<|>>|<=|>=|==|!=|&&|\|\||[-+*/%&|^~!<>()]');

/// Dal più debole al più forte, come in JavaScript.
const List<Set<String>> _intLevels = [
  {'||'},
  {'&&'},
  {'|'},
  {'^'},
  {'&'},
  {'==', '!='},
  {'<', '<=', '>', '>='},
  {'<<', '>>'},
  {'+', '-'},
  {'*', '/', '%'},
];

typedef _IntFn = int Function(_Vars vars);

/// Discesa ricorsiva sui token: ogni livello di [_intLevels] è un ciclo
/// associativo a sinistra sopra il livello dopo.
class _IntParser {
  _IntParser(this.tokens, this.where, this.scope, this.kinds);

  final List<String> tokens;
  final String where;
  final _Scope scope;
  final Map<String, _Kind> kinds;
  int at = 0;

  String? get _peek => at < tokens.length ? tokens[at] : null;

  String _next() {
    if (at >= tokens.length) throw SiteDefinitionError('$where: l\'espressione finisce a metà.');
    return tokens[at++];
  }

  void _expect(String token) {
    if (_next() != token) throw SiteDefinitionError('$where: atteso «$token».');
  }

  _IntFn expression(int level) {
    if (level == _intLevels.length) return _unary();
    var left = expression(level + 1);
    while (_intLevels[level].contains(_peek)) {
      final operator = _next();
      left = _binary(operator, left, expression(level + 1));
    }
    return left;
  }

  _IntFn _unary() {
    switch (_peek) {
      case '-':
        _next();
        final operand = _unary();
        return (vars) => -operand(vars);
      case '~':
        _next();
        final operand = _unary();
        return (vars) => (~operand(vars).toSigned(32)).toSigned(32);
      case '!':
        _next();
        final operand = _unary();
        return (vars) => operand(vars) == 0 ? 1 : 0;
    }
    return _primary();
  }

  _IntFn _primary() {
    final token = _next();
    if (token == '(') {
      final inner = expression(0);
      _expect(')');
      return inner;
    }
    if (RegExp(r'^\d').hasMatch(token)) {
      final value = int.tryParse(token);
      if (value == null) throw SiteDefinitionError('$where: «$token» non sta in 64 bit.');
      return (_) => value;
    }
    if (!RegExp(r'^[a-z]').hasMatch(token)) throw SiteDefinitionError('$where: atteso un valore, trovato «$token».');
    if (token == 'len' && _peek == '(') {
      _next();
      final name = _variable(_next());
      if (kinds[name] == _Kind.integer) throw SiteDefinitionError('$where: len di un intero.');
      _expect(')');
      return (vars) => _length(vars[name]);
    }
    final name = _variable(token);
    final kind = kinds[name] ?? _Kind.any;
    _accept(kind, const {_Kind.integer, _Kind.text}, where);
    return (vars) => _integer(name, vars[name]);
  }

  String _variable(String name) {
    if (!scope.names.contains(name)) throw SiteDefinitionError('$where: variabile sconosciuta «$name».');
    return name;
  }

  static _IntFn _binary(String operator, _IntFn left, _IntFn right) {
    int bool01(bool value) => value ? 1 : 0;
    int int32(int value) => value.toSigned(32);
    return switch (operator) {
      '||' => (vars) => bool01(left(vars) != 0 || right(vars) != 0),
      '&&' => (vars) => bool01(left(vars) != 0 && right(vars) != 0),
      '|' => (vars) => int32(int32(left(vars)) | int32(right(vars))),
      '^' => (vars) => int32(int32(left(vars)) ^ int32(right(vars))),
      '&' => (vars) => int32(int32(left(vars)) & int32(right(vars))),
      '==' => (vars) => bool01(left(vars) == right(vars)),
      '!=' => (vars) => bool01(left(vars) != right(vars)),
      '<' => (vars) => bool01(left(vars) < right(vars)),
      '<=' => (vars) => bool01(left(vars) <= right(vars)),
      '>' => (vars) => bool01(left(vars) > right(vars)),
      '>=' => (vars) => bool01(left(vars) >= right(vars)),
      '<<' => (vars) => int32(int32(left(vars)) << (right(vars) & 31)),
      '>>' => (vars) => int32(left(vars)) >> (right(vars) & 31),
      '+' => (vars) => left(vars) + right(vars),
      '-' => (vars) => left(vars) - right(vars),
      '*' => (vars) => left(vars) * right(vars),
      '/' => (vars) => _divide(left(vars), right(vars), (a, b) => a ~/ b),
      _ => (vars) => _divide(left(vars), right(vars), (a, b) => a.remainder(b)),
    };
  }

  static int _divide(int a, int b, int Function(int a, int b) operation) {
    if (b == 0) throw const _RecipeFailure('divisione per zero');
    return operation(a, b);
  }

  static int _integer(String name, Object? value) {
    if (value == null) throw _RecipeFailure('la variabile «$name» è vuota');
    return switch (value) {
      final int number => number,
      final num number when number == number.truncateToDouble() && number.isFinite => number.toInt(),
      _ => int.tryParse(_plainText(value)?.trim() ?? '') ??
          (throw _RecipeFailure('la variabile «$name» non è un intero')),
    };
  }

  /// Byte di un valore, voci di una lista; una variabile vuota è lunga 0.
  static int _length(Object? value) => switch (value) {
        null => 0,
        Uint8List() => value.length,
        List() => value.length,
        Map() => value.length,
        _ => utf8.encode(_plainText(value) ?? '').length,
      };
}
