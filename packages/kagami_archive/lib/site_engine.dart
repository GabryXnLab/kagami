/// L'`engine` che serve a una definizione di sito (`docs/siti.md`,
/// «Compatibilità ed engine»): il massimo `engine` delle chiavi che usa.
///
/// È una funzione sola perché la stessa risposta serve a chi costruisce il
/// catalogo (`minEngine` di una variante), all'app che decide se un sito può
/// andare al server e al motore che rifiuta un file più nuovo di lui: tre conti
/// diversi direbbero tre cose diverse dello stesso file.
library;

/// Le chiavi del formato 2 col numero della primitiva che le porta.
const Map<String, int> _keyEngines = {
  'linkVars': 2,
  'vars': 2,
  'keep': 2,
  'var': 2,
  'template': 2,
  'query': 2,
  'base': 2,
  'first': 3,
  'try': 3,
  'on': 3,
  'filters': 4,
  'skip': 4,
  'require': 4,
  'locked': 4,
  'jsonAt': 6,
  'expect': 8,
  'fallback': 9,
  'recipe': 10,
  'let': 10,
  'get': 10,
  'utf8': 10,
  'check': 10,
  'base64': 11,
  'hex': 11,
  'intExpr': 12,
  'switch': 12,
  'when': 12,
  'range': 13,
  'hmacSha256': 14,
  'xor': 14,
  'fetch': 15,
  'chapterReady': 16,
};

/// Oggetti le cui chiavi sono nomi scelti da chi scrive il file (variabili,
/// parametri, casi): una variabile chiamata `first` non è un ripiego.
const Set<String> _namedMaps = {'vars', 'linkVars', 'query', 'cases'};

/// Valori JSON letterali, che non si leggono come struttura del file.
const Set<String> _literals = {'equals', 'value'};

/// I campi indirizzo che nel formato 1 sono un testo con `{id}`, `{url}` o `{query}`.
const List<List<String>> _addresses = [
  ['series', 'url'],
  ['series', 'chapters', 'api'],
  ['chapter', 'api'],
  ['search', 'url'],
];

final RegExp _placeholder = RegExp(r'\{([a-z][A-Za-z0-9]*)\}');

/// L'`engine` minimo per [definition] e la chiave che lo chiede (`null` per un
/// file del solo formato 1). Non valida il file: un file che usa una chiave
/// nel posto sbagliato lo rifiuta poi il motore.
({int engine, String? key}) siteMinEngine(Map<String, Object?> definition) {
  var engine = 1;
  String? key;
  void need(int level, String name) {
    if (level > engine) {
      engine = level;
      key = name;
    }
  }

  if (definition['format'] == 2) need(2, 'format');
  void walk(Object? node) {
    if (node is List) {
      node.forEach(walk);
    } else if (node is Map) {
      for (final MapEntry(key: name, value: value) in node.entries) {
        if (name is! String) continue;
        need(_keyEngines[name] ?? 1, name);
        if (_literals.contains(name)) continue;
        if (_namedMaps.contains(name) && value is Map) {
          value.values.forEach(walk);
        } else {
          walk(value);
        }
      }
    }
  }

  walk(definition);
  // `pages` è anche il campo delle tavole in `chapter`: conta solo in `browser`.
  if (definition['browser'] case {'pages': _}) need(16, 'pages');
  if (definition['series'] case {'link': String _}) need(7, 'link');
  for (final path in _addresses) {
    Object? value = definition;
    for (final step in path) {
      value = value is Map ? value[step] : null;
    }
    if (value is! String) continue;
    for (final found in _placeholder.allMatches(value)) {
      if (!const {'id', 'url', 'query'}.contains(found[1])) need(2, found[0]!);
    }
  }
  final media = definition['mediaHosts'];
  if (media is List && media.any((host) => host is String && host.contains('?'))) need(5, 'mediaHosts');
  return (engine: engine, key: key);
}
