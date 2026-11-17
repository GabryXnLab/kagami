/// Temi a tempo di build (`docs/catalogo.md`, «Temi»): `extends` vive solo nel sorgente
/// `catalog/sites/`; qui lo si risolve in una definizione piatta, che è ciò che si pubblica.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ThemeError implements Exception {
  const ThemeError(this.message);

  final String message;
}

/// Chiavi d'identità: un tema non le può avere, sono del sito.
const Set<String> themeForbiddenKeys = {'id', 'name', 'version', 'home', 'hosts', 'extends'};

/// La cartella dei temi accanto a quella dei siti (`catalog/sites` -> `catalog/themes`).
String defaultThemesDir(String sitesDir) => p.join(p.dirname(p.normalize(sitesDir)), 'themes');

/// Il file sta in `catalog/sites/`: i temi in `catalog/themes/`.
String defaultThemesDirForFile(String file) => defaultThemesDir(p.dirname(p.absolute(file)));

/// Merge profondo: gli oggetti si fondono, il sito vince, le liste e i valori si sostituiscono,
/// `null` nel sito toglie la chiave.
Map<String, Object?> mergeTheme(Map<String, Object?> theme, Map<String, Object?> site) {
  final result = Map<String, Object?>.of(theme);
  for (final entry in site.entries) {
    final value = entry.value;
    if (value == null) {
      result.remove(entry.key);
    } else if (value is Map<String, Object?> && result[entry.key] is Map<String, Object?>) {
      result[entry.key] = mergeTheme(result[entry.key]! as Map<String, Object?>, value);
    } else {
      result[entry.key] = value is Map<String, Object?> ? mergeTheme(const {}, value) : value;
    }
  }
  return result;
}

Map<String, Object?> loadTheme(String name, String themesDir) {
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(name)) throw ThemeError('Nome di tema non valido: «$name».');
  final file = File(p.join(themesDir, '$name.json'));
  if (!file.existsSync()) throw ThemeError('Tema «$name» non trovato in $themesDir.');
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(file.readAsBytesSync()));
  } on FormatException {
    throw ThemeError('${file.path}: non è un JSON UTF-8.');
  }
  if (json is! Map<String, Object?>) throw ThemeError('${file.path}: non è un oggetto JSON.');
  if (json.containsKey('extends')) throw ThemeError('${file.path}: un tema non può avere «extends» (niente catene).');
  final bad = themeForbiddenKeys.where(json.containsKey).toList();
  if (bad.isNotEmpty) throw ThemeError('${file.path}: un tema non ha ${bad.map((k) => '«$k»').join(', ')}.');
  return json;
}

/// La definizione piatta: [site] senza `extends`, fusa col tema. Senza `extends` torna [site] com'è.
Map<String, Object?> flattenSite(Map<String, Object?> site, String themesDir) {
  if (!site.containsKey('extends')) return site;
  final name = site['extends'];
  if (name is! String) throw const ThemeError('«extends» deve essere il nome di un tema (una stringa, niente catene).');
  final merged = mergeTheme(loadTheme(name, themesDir), site)..remove('extends');
  return merged;
}

String encodeDefinition(Map<String, Object?> def) => '${const JsonEncoder.withIndent('  ').convert(def)}\n';

/// Il testo di una definizione pronta all'uso: invariato se non estende nulla, piatto altrimenti.
String resolveDefinitionText(String text, String themesDir, {String? what}) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return text; // lo segnala chi la parsa
  }
  if (json is! Map<String, Object?> || !json.containsKey('extends')) return text;
  try {
    return encodeDefinition(flattenSite(json, themesDir));
  } on ThemeError catch (error) {
    throw ThemeError(what == null ? error.message : '$what: ${error.message}');
  }
}

/// Alza di 1 la `version` di ogni sorgente in [sitesDir] che estende [theme]; riscrive solo quel numero.
/// Torna i file toccati con la nuova versione.
Map<String, int> bumpTheme(String theme, String sitesDir) {
  final dir = Directory(sitesDir);
  if (!dir.existsSync()) throw ThemeError('La cartella $sitesDir non esiste.');
  final bumped = <String, int>{};
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final text = utf8.decode(file.readAsBytesSync());
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      continue;
    }
    if (json is! Map || json['extends'] != theme) continue;
    final version = json['version'];
    if (version is! int) throw ThemeError('${file.path}: «version» manca.');
    final span = _topLevelNumber(text, 'version') ?? (throw ThemeError('${file.path}: «version» non trovata.'));
    file.writeAsStringSync('${text.substring(0, span.$1)}${version + 1}${text.substring(span.$2)}');
    bumped[file.path] = version + 1;
  }
  return bumped;
}

/// Inizio e fine del numero di [key] al primo livello dell'oggetto, senza toccare altro.
(int, int)? _topLevelNumber(String text, String key) {
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      final start = i++;
      while (text[i] != '"') {
        if (text[i] == '\\') i++;
        i++;
      }
      if (depth == 1 && text.substring(start + 1, i) == key) {
        var j = i + 1;
        while (RegExp(r'\s').hasMatch(text[j])) {
          j++;
        }
        if (text[j] != ':') continue;
        j++;
        while (RegExp(r'\s').hasMatch(text[j])) {
          j++;
        }
        final m = RegExp(r'\d+').matchAsPrefix(text, j);
        return m == null ? null : (j, m.end);
      }
    } else if (c == '{' || c == '[') {
      depth++;
    } else if (c == '}' || c == ']') {
      depth--;
    }
  }
  return null;
}
