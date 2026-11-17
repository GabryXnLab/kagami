// Filtri e condizioni del formato 2 (`docs/siti.md`, «Filtri e condizioni»):
// trasformare un valore letto, scartare un elemento, fermare un'operazione.
part of 'declarative.dart';

/// Una trasformazione di un testo; `null` o vuoto: il valore sparisce.
typedef _Filter = String? Function(String text);

final RegExp _decimal = RegExp(r'^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$');
final RegExp _groupRef = RegExp(r'\$(\d)');

List<_Filter>? _readFilters(Object? raw, String where) {
  if (raw == null) return null;
  if (raw is! List || raw.isEmpty) throw SiteDefinitionError('$where: una lista di filtri.');
  return [for (final (index, item) in raw.indexed) _readFilter(item, '$where[$index]')];
}

_Filter _readFilter(Object? raw, String where) {
  switch (raw) {
    case 'lower':
      return (text) => text.toLowerCase();
    case 'trim':
      return (text) => text.trim();
    case 'number':
      return _shortNumber;
    case {'replace': final List<Object?> args} when raw.length == 1 && args.length == 2 && args[1] is String:
      final pattern = _pattern(args[0], '$where.replace');
      final replacement = args[1] as String;
      return (text) => _replace(_clip(text), pattern, replacement);
    case {'prefix': final String prefix} when raw.length == 1:
      return (text) => _sized('$prefix$text');
    case {'suffix': final String suffix} when raw.length == 1:
      return (text) => _sized('$text$suffix');
  }
  throw SiteDefinitionError(
      '$where: "lower", "trim", "number", {"replace": [espressione, sostituto]}, {"prefix": testo} o {"suffix": testo}.');
}

String _sized(String text) {
  if (text.length > _maxValue) throw const ProviderError('Un valore del sito supera i 2 MB.');
  return text;
}

/// Tutte le corrispondenze, con `$1`…`$9` per i gruppi; un gruppo che non
/// c'è vale vuoto. Il risultato non cresce oltre il tetto di un valore.
String _replace(String text, RegExp pattern, String replacement) {
  var size = text.length;
  return text.replaceAllMapped(pattern, (found) {
    final value = replacement.replaceAllMapped(_groupRef, (ref) {
      final group = int.parse(ref[1]!);
      return group <= found.groupCount ? (found[group] ?? '') : '';
    });
    size += value.length - found[0]!.length;
    if (size > _maxValue) throw const ProviderError('Un valore del sito supera i 2 MB.');
    return value;
  });
}

/// Un numero nella forma corta (`12.0` → `12`, `12.5` resta); un testo che
/// non è un numero decimale non dà un valore.
String? _shortNumber(String text) {
  final trimmed = text.trim();
  if (!_decimal.hasMatch(trimmed)) return null;
  final number = num.parse(trimmed);
  if (!number.isFinite) return null;
  if (number is int) return '$number';
  return number == number.truncateToDouble() && number.abs() < 1e15 ? '${number.toInt()}' : '$number';
}

/// Lo stesso testo, o lo stesso numero scritto in due modi (`12` e `12.0`).
bool _sameText(String a, String b) {
  if (a == b) return true;
  final x = _shortNumber(a);
  return x != null && x == _shortNumber(b);
}

/// Un estrattore più una prova: `equals`, `matches` o `exists`, e `not`.
class _Condition {
  _Condition(this.extractor, {this.equals, this.fixed, this.matches, this.exists, this.not = false});

  static const Set<String> _tests = {'equals', 'matches', 'exists'};

  static _Condition read(Object? raw, String where, _Scope scope) {
    final map = _object(raw, where);
    final tests = _tests.where(map.containsKey).toList();
    if (tests.length != 1) throw SiteDefinitionError('$where: una sola fra equals, matches ed exists.');
    final extractor = _Extractor.read(
        {for (final entry in map.entries) if (!_tests.contains(entry.key) && entry.key != 'not') entry.key: entry.value},
        where,
        scope);
    final not = _flag(map['not'], '$where.not');
    switch (tests.single) {
      case 'equals':
        return switch (map['equals']) {
          final String text => _Condition(extractor, equals: _Template.read(text, '$where.equals', scope), not: not),
          final num number => _Condition(extractor, fixed: '$number', not: not),
          final bool flag => _Condition(extractor, fixed: '$flag', not: not),
          _ => throw SiteDefinitionError('$where.equals: un testo, un numero o un booleano.'),
        };
      case 'matches':
        return _Condition(extractor, matches: _pattern(map['matches'], '$where.matches'), not: not);
      default:
        final exists = map['exists'];
        if (exists is! bool) throw SiteDefinitionError('$where.exists: true o false.');
        return _Condition(extractor, exists: exists, not: not);
    }
  }

  /// `skip` e `require`: una lista di condizioni.
  static List<_Condition> readList(Object? raw, String where, _Scope scope) {
    if (raw == null) return const [];
    if (raw is! List || raw.isEmpty) throw SiteDefinitionError('$where: una lista di condizioni.');
    return [for (final (index, item) in raw.indexed) read(item, '$where[$index]', scope)];
  }

  final _Extractor extractor;
  final _Template? equals;
  final String? fixed;
  final RegExp? matches;
  final bool? exists;
  final bool not;

  /// Con più valori (`all`) basta che uno superi la prova; un modello che non
  /// si compone non è uguale a niente.
  bool holds(Object? node, _Context context) {
    final bool result;
    if (exists case final wanted?) {
      result = (extractor.capture(node, context) != null) == wanted;
    } else if (matches case final pattern?) {
      result = extractor.strings(node, context).any((text) => pattern.hasMatch(_clip(text)));
    } else {
      final expected = fixed ?? equals!.render(context.vars);
      result = expected != null && extractor.strings(node, context).any((text) => _sameText(text, expected));
    }
    return result != not;
  }
}

bool _anyHolds(List<_Condition> conditions, Object? node, _Context context) =>
    conditions.any((condition) => condition.holds(node, context));
