/// Lo strumento di chi scrive o ripara le definizioni dei siti.
///
/// ```text
///   dart run tool/site.dart har <cartella-o-file.har> --hosts h1,h2
///       [--definition <def.json>] --out <cartella cassetta> [--json]
/// ```
///
/// `har` legge un HAR (Playwright in modo attach, con i corpi accanto, o DevTools
/// con i corpi nel file), scrive la cassetta dei soli GET sugli host del sito e
/// stampa l'inventario degli endpoint (testo, o JSON con `--json`).
///
/// ```text
///   dart run tool/site.dart lint <def.json> [--canaries catalog/canaries.json] [--json]
/// ```
///
/// ```text
///   dart run tool/site.dart check <def.json> (--replay <cassetta> | --live [--record <cartella>])
///       [--query q | --url u] [--json]
/// ```
///
/// `check` fa il giro della sonda (ricerca, serie, tavole del primo capitolo) con la definizione:
/// su una cassetta, confrontando l'esito con il suo `expect.json`, o dal vivo; `--record` salva la
/// cassetta e scrive un `expect.json` dall'esito, da rileggere a mano. Esce con 1 su guasto o differenza.
///
/// ```text
///   dart run tool/site.dart flatten <sito.json> [--themes dir]
///   dart run tool/site.dart bump --theme <nome> [--sites dir]
/// ```
///
/// `flatten` stampa la definizione piatta di un sorgente con `extends` (`docs/catalogo.md`, «Temi»);
/// `bump --theme` alza di 1 la `version` di ogni sorgente che estende quel tema. `check` e `lint`
/// accettano anche un sorgente con `extends`.
///
/// `lint` applica le regole di robustezza (`src/lint.dart`); esce con 1 se c'è un errore.
///
/// ```text
///   dart run tool/site.dart coffeemanga-key <bundle.js | --live>
/// ```
///
/// `coffeemanga-key` stampa in esadecimale la chiave del manifest di Coffee Manga, ricavata dal
/// bundle con il codice del provider Dart (`docs/manutenzione-siti.md`).
library;

import 'dart:convert';
import 'dart:io';

import 'src/check.dart';
import 'src/coffeemanga_key.dart';
import 'src/har.dart';
import 'src/lint.dart';
import 'src/theme.dart';

Future<void> main(List<String> args) async {
  exitCode = await runSiteTool(args, out: stdout, err: stderr);
}

const String _usage = 'Uso: site.dart <comando> ...\n'
    '  har <cartella-o-file.har> --hosts h1,h2 [--definition def.json] --out <cassetta> [--json]\n'
    '  check <def.json> (--replay <cassetta> | --live [--record <dir>]) [--query q | --url u] [--themes dir] [--json]\n'
    '  lint <def.json> [--canaries catalog/canaries.json] [--themes dir] [--json]\n'
    '  flatten <sito.json> [--themes dir]\n'
    '  bump --theme <nome> [--sites dir]\n'
    '  coffeemanga-key <bundle.js | --live>';

Future<int> runSiteTool(List<String> args, {required StringSink out, required StringSink err}) async {
  try {
    if (args.isEmpty || !const {'har', 'lint', 'check', 'flatten', 'bump', 'coffeemanga-key'}.contains(args.first)) {
      throw const HarError(_usage);
    }
    if (args.first == 'coffeemanga-key') return await runCoffeeMangaKey(args.skip(1).toList(), out);
    if (args.first == 'flatten') return _flatten(args.skip(1).toList(), out);
    if (args.first == 'bump') return _bump(args.skip(1).toList(), out);
    if (args.first == 'check') return await runCheck(parseCheck(args.skip(1).toList()), out);
    if (args.first == 'lint') return _lint(args.skip(1).toList(), out);
    final positional = <String>[];
    final options = <String, String>{};
    var asJson = false;
    final rest = args.skip(1).toList();
    for (var i = 0; i < rest.length; i++) {
      if (rest[i] == '--json') {
        asJson = true;
      } else if (rest[i].startsWith('--')) {
        if (i + 1 >= rest.length) throw HarError('Manca il valore di ${rest[i]}.');
        options[rest[i].substring(2)] = rest[++i];
      } else {
        positional.add(rest[i]);
      }
    }
    if (positional.isEmpty) throw const HarError('Manca la cartella o il file HAR.');
    final outDir = options['out'] ?? (throw const HarError('Manca --out.'));

    final hosts = <String>{...?options['hosts']?.split(',').map((h) => h.trim()).where((h) => h.isNotEmpty)};
    final definition = options['definition'];
    if (definition != null) {
      final Object? json;
      try {
        json = jsonDecode(File(definition).readAsStringSync());
      } on FormatException {
        throw HarError('$definition non è JSON.');
      } on FileSystemException {
        throw HarError('$definition non si legge.');
      }
      if (json is Map && json['hosts'] is List) hosts.addAll((json['hosts'] as List).whereType<String>());
    }
    if (hosts.isEmpty) throw const HarError('Servono --hosts o una --definition con «hosts».');

    final result = readHar(findHar(positional.first), hosts: hosts);
    result.cassette.save(Directory(outDir));
    out.write(asJson ? '${const JsonEncoder.withIndent('  ').convert(result.inventory)}\n' : renderInventory(result.inventory));
    return 0;
  } on HarError catch (error) {
    err.writeln(error.message);
    return 1;
  } on ThemeError catch (error) {
    err.writeln(error.message);
    return 1;
  }
}

Map<String, String> _simpleArgs(List<String> args, Set<String> allowed, List<String> positional) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      if (!allowed.contains(args[i].substring(2))) throw HarError('Opzione sconosciuta: ${args[i]}.');
      if (i + 1 >= args.length) throw HarError('Manca il valore di ${args[i]}.');
      options[args[i].substring(2)] = args[++i];
    } else {
      positional.add(args[i]);
    }
  }
  return options;
}

int _flatten(List<String> args, StringSink out) {
  final positional = <String>[];
  final options = _simpleArgs(args, {'themes'}, positional);
  if (positional.length != 1) throw const HarError('Uso: site.dart flatten <sito.json> [--themes dir]');
  final file = positional.single;
  final text = File(file).existsSync() ? File(file).readAsStringSync() : throw HarError('$file non si legge.');
  out.write(resolveDefinitionText(text, options['themes'] ?? defaultThemesDirForFile(file), what: file));
  return 0;
}

int _bump(List<String> args, StringSink out) {
  final positional = <String>[];
  final options = _simpleArgs(args, {'theme', 'sites'}, positional);
  final theme = options['theme'] ?? (throw const HarError('Uso: site.dart bump --theme <nome> [--sites dir]'));
  final bumped = bumpTheme(theme, options['sites'] ?? 'catalog/sites');
  for (final e in bumped.entries) {
    out.writeln('${e.key}: version ${e.value}');
  }
  if (bumped.isEmpty) out.writeln('Nessun sito estende «$theme».');
  return 0;
}

Object? _readJson(String path) {
  try {
    return jsonDecode(File(path).readAsStringSync());
  } on FormatException {
    throw HarError('$path non è JSON.');
  } on FileSystemException {
    throw HarError('$path non si legge.');
  }
}

int _lint(List<String> args, StringSink out) {
  String? file, canariesFile, themesDir;
  var asJson = false;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--json') {
      asJson = true;
    } else if (args[i] == '--themes') {
      if (i + 1 >= args.length) throw const HarError('Manca il valore di --themes.');
      themesDir = args[++i];
    } else if (args[i] == '--canaries') {
      if (i + 1 >= args.length) throw const HarError('Manca il valore di --canaries.');
      canariesFile = args[++i];
    } else {
      file = args[i];
    }
  }
  if (file == null) throw const HarError('Uso: site.dart lint <def.json> [--canaries catalog/canaries.json] [--json]');
  var def = _readJson(file);
  if (def is! Map) throw HarError('$file non è una definizione (atteso un oggetto).');
  if (def.containsKey('extends')) def = flattenSite(def.cast<String, Object?>(), themesDir ?? defaultThemesDirForFile(file));
  final canaries = canariesFile == null ? null : _readJson(canariesFile);
  if (canariesFile != null && canaries is! Map) throw HarError('$canariesFile non è un oggetto.');
  final issues = lintSite(def, canaries: canaries as Map?);
  out.write(asJson ? lintJson(issues) : renderLint(issues));
  return issues.any((i) => i.isError) ? 1 : 0;
}
