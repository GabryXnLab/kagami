/// Lo strumento di chi pubblica il catalogo dei siti (`docs/catalogo.md`).
///
/// ```text
///   dart run tool/catalog.dart build <cartella-siti> <uscita> --serial N
///       [--previous <index.json>] [--status <status.json>] [--themes <cartella>] [--check '<comando>']
///   dart run tool/catalog.dart sign <uscita> --kid K --key <chiave.pem>
///   dart run tool/catalog.dart verify <uscita> --keys '<CATALOG_KEYS>' [--engine N]
///   dart run tool/catalog.dart pubkey <chiave.pem> --kid K     (stampa `kid.n.e`)
/// ```
///
/// Chiave privata: PEM di openssl, PKCS#1 o PKCS#8 (le due forme che dà
/// `openssl genrsa`), da almeno 3072 bit:
///   openssl genrsa -out catalogo.pem 3072
/// La chiave resta fuori da git; `pubkey` ne ricava la voce di `CATALOG_KEYS`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/signature.dart';
import 'package:kagami_archive/site_engine.dart';
import 'package:path/path.dart' as p;

import 'src/lint.dart';
import 'src/theme.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCatalogTool(args, out: stdout, err: stderr);
}

class ToolError implements Exception {
  const ToolError(this.message);

  final String message;
}

const String _usage = 'Uso: catalog.dart build|sign|verify|pubkey ... (intestazione di tool/catalog.dart)';

/// Esegue un comando; l'exit code è 0 solo se tutto è tornato.
Future<int> runCatalogTool(List<String> args, {required StringSink out, required StringSink err}) async {
  try {
    if (args.isEmpty) throw const ToolError(_usage);
    final parsed = _Args(args.skip(1).toList());
    switch (args.first) {
      case 'build':
        await _build(parsed, out);
      case 'sign':
        _sign(parsed, out);
      case 'verify':
        _verify(parsed, out);
      case 'pubkey':
        _pubkey(parsed, out);
      default:
        throw const ToolError(_usage);
    }
    return 0;
  } on ToolError catch (error) {
    err.writeln(error.message);
    return 1;
  }
}

class _Args {
  _Args(List<String> raw) {
    for (var i = 0; i < raw.length; i++) {
      if (raw[i].startsWith('--')) {
        if (i + 1 >= raw.length) throw ToolError('Manca il valore di ${raw[i]}.');
        options[raw[i].substring(2)] = raw[++i];
      } else {
        positional.add(raw[i]);
      }
    }
  }

  final List<String> positional = [];
  final Map<String, String> options = {};

  String pos(int index, String name) {
    if (index >= positional.length) throw ToolError('Manca $name.');
    return positional[index];
  }

  String option(String name) => options[name] ?? (throw ToolError('Manca --$name.'));

  int intOption(String name, {int? fallback}) {
    final raw = options[name];
    if (raw == null && fallback != null) return fallback;
    return int.tryParse(raw ?? '') ?? (throw ToolError('--$name deve essere un intero.'));
  }
}

String _hex(List<int> bytes) => sha256.convert(bytes).toString();

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Future<void> _build(_Args args, StringSink out) async {
  final sitesDir = Directory(args.pos(0, 'la cartella dei siti'));
  final outDir = Directory(args.pos(1, 'la cartella di uscita'));
  final serial = args.intOption('serial');
  if (!sitesDir.existsSync()) throw ToolError('La cartella ${sitesDir.path} non esiste.');

  final previous = args.options['previous'];
  final previousIndex = previous == null ? null : _readIndex(File(previous));
  if (previousIndex != null && serial <= previousIndex.serial) {
    throw ToolError('--serial $serial deve superare quello precedente (${previousIndex.serial}).');
  }

  final status = _readStatus(args, sitesDir);
  final canariesFile = File(p.join(p.dirname(p.normalize(sitesDir.path)), 'canaries.json'));
  Map? canaries;
  if (canariesFile.existsSync()) {
    try {
      canaries = jsonDecode(canariesFile.readAsStringSync()) as Map;
    } on Object {
      throw ToolError('${canariesFile.path}: non è un JSON oggetto.');
    }
  }
  final errors = <String>[];

  // Per id e versione: il file da copiare e la sua voce.
  final variants = <String, Map<int, ({File file, Map<String, Object?> entry, List<int>? bytes})>>{};
  final themesDir = args.options['themes'] ?? defaultThemesDir(sitesDir.path);
  final files = sitesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) throw ToolError('Nessun file .json in ${sitesDir.path}.');
  for (final file in files) {
    var bytes = file.readAsBytesSync();
    String text;
    Object? json;
    try {
      text = utf8.decode(bytes);
      json = jsonDecode(text);
    } on FormatException {
      throw ToolError('${file.path}: non è un JSON UTF-8.');
    }
    if (json is! Map<String, Object?>) throw ToolError('${file.path}: non è un oggetto JSON.');
    // `extends` si risolve prima di tutto: lint, sha e minEngine vedono solo la definizione piatta.
    final flattened = json.containsKey('extends');
    if (flattened) {
      try {
        json = flattenSite(json, themesDir);
      } on ThemeError catch (error) {
        throw ToolError('${file.path}: ${error.message}');
      }
      text = encodeDefinition(json);
      bytes = utf8.encode(text);
    }
    final id = json['id'];
    final version = json['version'];
    if (id is! String || version is! int) throw ToolError('${file.path}: «id» o «version» mancano.');
    // La voce provvisoria serve solo ad applicare i tetti di un sito del catalogo.
    final probe = CatalogSite(
      id: id,
      state: CatalogSiteState.ok,
      variants: [CatalogVariant(version: version, minEngine: 1, sha256: '0' * 64, path: 'sites/$id-$version.json')],
    );
    final DeclarativeProvider provider;
    try {
      provider = DeclarativeProvider.parse(text, catalog: probe);
    } on SiteDefinitionError catch (error) {
      throw ToolError('${file.path}: ${error.message}');
    }
    if (provider.id != id || provider.version != version) throw ToolError('${file.path}: id o versione incoerenti.');
    if (variants[id]?.containsKey(version) ?? false) throw ToolError('${file.path}: $id v$version è già in un altro file.');
    final sha = _hex(bytes);
    final published = previousIndex?.sites[id]?.variants.where((v) => v.version == version && v.sha256 != sha);
    if (published != null && published.isNotEmpty) {
      throw ToolError('${file.path}: $id v$version è già pubblicata con altri byte: un file pubblicato non si riscrive, alza «version» a ${version + 1}.');
    }
    for (final issue in lintSite(json, canaries: canaries)) {
      if (issue.isError) errors.add('${file.path}: $issue');
      out.writeln('lint $id: $issue');
    }
    final before = previousIndex == null ? null : _publishedHosts(id, previousIndex, previous!);
    if (before != null) {
      final fresh = (_definitionHosts(json)..removeAll(before)).toList()..sort();
      if (fresh.isNotEmpty) out.writeln('Host nuovo in $id v$version: ${fresh.join(', ')} (da rivedere prima di firmare)');
    }
    variants.putIfAbsent(id, () => {})[version] = (
      file: file,
      bytes: flattened ? bytes : null,
      entry: {
        'version': version,
        'minEngine': siteMinEngine(json).engine,
        'sha256': _hex(bytes),
        'path': 'sites/$id-$version.json',
      },
    );
  }

  if (errors.isNotEmpty) throw ToolError('Lint: ${errors.length} errori, niente uscita.\n${errors.join('\n')}');
  for (final id in status.keys) {
    if (!variants.containsKey(id)) throw ToolError('status.json: «$id» non ha una definizione in ${sitesDir.path}.');
  }

  // Le varianti di prima ancora presenti accanto al vecchio indice restano, per le app che ne hanno bisogno.
  if (previousIndex != null) {
    final base = p.dirname(previous!);
    for (final site in previousIndex.sites.values) {
      for (final variant in site.variants) {
        final file = File(p.join(base, variant.path));
        if (!file.existsSync() || variants[site.id]?.containsKey(variant.version) == true) continue;
        if (_hex(file.readAsBytesSync()) != variant.sha256) continue;
        variants.putIfAbsent(site.id, () => {})[variant.version] = (
          file: file,
          bytes: null,
          entry: {'version': variant.version, 'minEngine': variant.minEngine, 'sha256': variant.sha256, 'path': variant.path},
        );
      }
    }
  }

  final sites = <String, Object?>{};
  for (final id in variants.keys.toList()..sort()) {
    final versions = variants[id]!.keys.toList()..sort((a, b) => b.compareTo(a));
    if (versions.length > maxCatalogVariants) versions.removeRange(maxCatalogVariants, versions.length);
    variants[id]!.removeWhere((version, _) => !versions.contains(version));
    final st = status[id];
    sites[id] = {
      'state': st?['state'] ?? 'ok',
      if (st?['message'] != null) 'message': st!['message'],
      if (st?['builtin'] == 'off') 'builtin': 'off',
      'variants': [for (final v in versions) variants[id]![v]!.entry],
    };
  }
  final issuedAt = DateTime.now().toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
  final indexBytes = utf8.encode('${const JsonEncoder.withIndent('  ').convert({
        'catalog': catalogFormat,
        'serial': serial,
        'issuedAt': issuedAt,
        'sites': sites,
      })}\n');
  try {
    CatalogIndex.parse(indexBytes);
  } on CatalogFormatError catch (error) {
    throw ToolError('L\'indice che ne verrebbe non è valido: ${error.message}');
  }

  final check = args.options['check'];
  if (check != null) {
    out.writeln('Controllo: $check');
    final result = await Process.run('sh', ['-c', check]);
    if (result.exitCode != 0) {
      throw ToolError('Il controllo è fallito (exit ${result.exitCode}), niente uscita.\n${result.stdout}${result.stderr}');
    }
  }

  // Solo ora si scrive: prima `sites/`, poi l'indice. Una firma vecchia non vale per il nuovo.
  Directory(p.join(outDir.path, 'sites')).createSync(recursive: true);
  for (final byVersion in variants.values) {
    for (final (:file, :entry, :bytes) in byVersion.values) {
      final target = File(p.join(outDir.path, entry['path']! as String));
      if (bytes != null) {
        target.writeAsBytesSync(bytes);
      } else if (!p.equals(file.path, target.path)) {
        file.copySync(target.path);
      }
    }
  }
  final sigFile = File(p.join(outDir.path, 'index.sig'));
  if (sigFile.existsSync()) sigFile.deleteSync();
  File(p.join(outDir.path, 'index.json')).writeAsBytesSync(indexBytes);
  out.writeln('Indice serial $serial: ${sites.length} siti, ${variants.values.fold(0, (n, v) => n + v.length)} varianti. Ora: sign.');
}

/// `catalog/status.json` (o `--status`): `{"sites": {id: {state, message, builtin}}}`. Assente = tutti ok/on.
Map<String, Map<String, Object?>> _readStatus(_Args args, Directory sitesDir) {
  final explicit = args.options['status'];
  final file = File(explicit ?? p.join(p.dirname(p.normalize(sitesDir.path)), 'status.json'));
  if (!file.existsSync()) {
    if (explicit != null) throw ToolError('${file.path} non esiste.');
    return {};
  }
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(file.readAsBytesSync()));
  } on FormatException {
    throw ToolError('${file.path}: non è un JSON UTF-8.');
  }
  final raw = json is Map ? json['sites'] : null;
  if (raw is! Map) throw ToolError('${file.path}: manca l\'oggetto «sites».');
  final result = <String, Map<String, Object?>>{};
  for (final MapEntry(:key, :value) in raw.entries) {
    if (value is! Map) throw ToolError('${file.path}: «$key» non è un oggetto.');
    final state = value['state'] ?? 'ok';
    final builtin = value['builtin'] ?? 'on';
    final message = value['message'];
    if (state != 'ok' && state != 'broken') throw ToolError('${file.path}: «$key» state deve essere ok o broken.');
    if (builtin != 'on' && builtin != 'off') throw ToolError('${file.path}: «$key» builtin deve essere on o off.');
    if (message != null && message is! String) throw ToolError('${file.path}: «$key» message deve essere un testo.');
    result['$key'] = {'state': state, 'builtin': builtin, 'message': message};
  }
  return result;
}

/// Gli host nominati da una definizione: `hosts`, `mediaHosts` e quelli degli indirizzi scritti per esteso.
Set<String> _definitionHosts(Map json) {
  final hosts = <String>{};
  for (final key in ['hosts', 'mediaHosts']) {
    final list = json[key];
    if (list is List) hosts.addAll(list.whereType<String>());
  }
  void walk(Object? node) {
    if (node is String) {
      for (final m in RegExp(r'https?://([^/{}\s?#:"]+)').allMatches(node)) {
        hosts.add(m.group(1)!);
      }
    } else if (node is Map) {
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }
  walk(json);
  return hosts;
}

/// Gli host di tutte le varianti già pubblicate di [id] che si trovano accanto a [previousPath]; `null` se non c'è niente da confrontare.
Set<String>? _publishedHosts(String id, CatalogIndex previous, String previousPath) {
  final site = previous.sites[id];
  if (site == null) return null;
  final hosts = <String>{};
  var any = false;
  for (final variant in site.variants) {
    final file = File(p.join(p.dirname(previousPath), variant.path));
    if (!file.existsSync()) continue;
    try {
      hosts.addAll(_definitionHosts(jsonDecode(utf8.decode(file.readAsBytesSync())) as Map));
      any = true;
    } on Object {
      continue;
    }
  }
  return any ? hosts : null;
}

CatalogIndex _readIndex(File file) {
  if (!file.existsSync()) throw ToolError('${file.path} non esiste.');
  try {
    return CatalogIndex.parse(file.readAsBytesSync());
  } on CatalogFormatError catch (error) {
    throw ToolError('${file.path}: ${error.message}');
  }
}

void _sign(_Args args, StringSink out) {
  final dir = args.pos(0, 'la cartella del catalogo');
  final kid = args.option('kid');
  if (!RegExp(r'^[a-z0-9-]{1,32}$').hasMatch(kid)) throw const ToolError('--kid: lettere minuscole, cifre e -, al più 32.');
  final key = _readPrivateKey(args.option('key'));
  final indexBytes = _readFile(p.join(dir, 'index.json'));
  final length = (key.n.bitLength + 7) ~/ 8;
  final digestInfo = [..._sha256Info, ...sha256.convert(indexBytes).bytes];
  final em = [0x00, 0x01, for (var i = 0; i < length - digestInfo.length - 3; i++) 0xff, 0x00, ...digestInfo];
  final signature = bigToBytes(bytesToBig(em).modPow(key.d, key.n), length);
  if (!rsaVerify((n: key.n, e: key.e), indexBytes, signature)) throw const ToolError('La firma non si verifica con la chiave pubblica: chiave guasta.');

  final sigFile = File(p.join(dir, 'index.sig'));
  final lines = sigFile.existsSync()
      ? const LineSplitter().convert(utf8.decode(sigFile.readAsBytesSync())).where((l) => l.trim().isNotEmpty && !l.startsWith('$kid ')).toList()
      : <String>[];
  lines.add('$kid ${_b64(signature)}');
  sigFile.writeAsStringSync('${lines.join('\n')}\n');
  out.writeln('Firmato index.json con «$kid» (${lines.length} righe in index.sig).');
}

void _verify(_Args args, StringSink out) {
  final dir = args.pos(0, 'la cartella del catalogo');
  final engine = args.intOption('engine', fallback: catalogEngine);
  final problems = <String>[];
  final keys = parseCatalogKeys(args.option('keys'), onError: problems.add);
  if (keys.isEmpty) throw ToolError('Nessuna chiave valida in --keys.\n${problems.join('\n')}');
  final indexBytes = _readFile(p.join(dir, 'index.json'));
  if (!verifyCatalogSignature(indexBytes, _readFile(p.join(dir, 'index.sig')), keys)) {
    throw const ToolError('Firma assente o falsa.');
  }
  final CatalogIndex index;
  try {
    index = CatalogIndex.parse(indexBytes);
  } on CatalogFormatError catch (error) {
    throw ToolError('Indice non valido: ${error.message}');
  }
  for (final site in index.sites.values) {
    for (final variant in site.variants) {
      final label = '${site.id} v${variant.version}';
      final file = File(p.join(dir, variant.path));
      if (!file.existsSync()) {
        problems.add('$label: manca ${variant.path}.');
        continue;
      }
      final bytes = file.readAsBytesSync();
      if (bytes.length > maxCatalogSiteBytes) {
        problems.add('$label: oltre 256 KB.');
      } else if (_hex(bytes) != variant.sha256) {
        problems.add('$label: sha256 diverso da quello dell\'indice.');
      } else {
        try {
          final text = utf8.decode(bytes);
          final provider = DeclarativeProvider.parse(text, catalog: site);
          if (provider.id != site.id || provider.version != variant.version) problems.add('$label: il file dice ${provider.id} v${provider.version}.');
          final needed = siteMinEngine(jsonDecode(text) as Map<String, Object?>).engine;
          if (needed != variant.minEngine) problems.add('$label: minEngine ${variant.minEngine}, la definizione chiede $needed.');
        } on FormatException {
          problems.add('$label: non è UTF-8.');
        } on SiteDefinitionError catch (error) {
          problems.add('$label: ${error.message}');
        }
      }
    }
  }
  if (problems.isNotEmpty) throw ToolError(problems.join('\n'));
  out.writeln('Catalogo serial ${index.serial} (${index.issuedAt.toIso8601String()}): firma e ${index.sites.length} siti a posto.');
  for (final site in index.sites.values) {
    final chosen = site.choose(engine: engine);
    out.writeln('  ${site.id} [${site.state.name}]: ${chosen == null ? 'nessuna variante per engine $engine' : 'v${chosen.version} (minEngine ${chosen.minEngine})'}');
  }
}

void _pubkey(_Args args, StringSink out) {
  final key = _readPrivateKey(args.pos(0, 'la chiave privata'));
  out.writeln('${args.option('kid')}.${_b64(_bigBytes(key.n))}.${_b64(_bigBytes(key.e))}');
}

List<int> _bigBytes(BigInt value) => bigToBytes(value, (value.bitLength + 7) ~/ 8);

List<int> _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) throw ToolError('$path non esiste.');
  return file.readAsBytesSync();
}

const List<int> _sha256Info = [
  0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
];

({BigInt n, BigInt e, BigInt d}) _readPrivateKey(String path) {
  final text = utf8.decode(_readFile(path));
  final body = text.split('\n').where((l) => !l.startsWith('-----')).join().replaceAll(RegExp(r'\s'), '');
  try {
    final der = base64.decode(body);
    var items = _der(der, 0, der.length); // SEQUENCE
    var inner = _der(der, items.first.start, items.first.end);
    if (inner.length >= 3 && inner[1].tag == 0x30) {
      // PKCS#8: version, algoritmo, OCTET STRING con il PKCS#1.
      final octets = inner[2];
      items = _der(der, octets.start, octets.end);
      inner = _der(der, items.first.start, items.first.end);
    }
    if (inner.length < 4 || inner.take(4).any((item) => item.tag != 0x02)) throw const FormatException();
    BigInt number(int i) => bytesToBig(der.sublist(inner[i].start, inner[i].end));
    final key = (n: number(1), e: number(2), d: number(3));
    if (key.n.bitLength < minCatalogKeyBits) throw ToolError('La chiave ha ${key.n.bitLength} bit, ne servono almeno $minCatalogKeyBits.');
    return key;
  } on FormatException {
    throw ToolError('$path non è una chiave RSA PEM (PKCS#1 o PKCS#8).');
  } on RangeError {
    throw ToolError('$path non è una chiave RSA PEM (PKCS#1 o PKCS#8).');
  }
}

/// Gli elementi DER fra [start] e [end]: tag e contenuto.
List<({int tag, int start, int end})> _der(List<int> bytes, int start, int end) {
  final items = <({int tag, int start, int end})>[];
  var pos = start;
  while (pos < end) {
    final tag = bytes[pos++];
    var length = bytes[pos++];
    if (length & 0x80 != 0) {
      final count = length & 0x7f;
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | bytes[pos++];
      }
    }
    if (pos + length > end) throw const FormatException();
    items.add((tag: tag, start: pos, end: pos + length));
    pos += length;
  }
  return items;
}
