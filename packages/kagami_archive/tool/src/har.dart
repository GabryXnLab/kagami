/// `site.dart har`: dall'HAR di una sessione di browser alla cassetta e all'inventario.
///
/// Dell'HAR si legge solo url, metodo, stato, tipo e corpo: header e cookie non
/// vengono mai né letti né scritti, perché la cassetta (`lib/cassette.dart`) non
/// ha dove metterli.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kagami_archive/cassette.dart';
import 'package:path/path.dart' as p;

class HarError implements Exception {
  const HarError(this.message);

  final String message;
}

/// Dell'immagine in cassetta restano i primi byte: bastano per la firma.
const int imageHeadBytes = 64;

/// Il nome di un corpo scritto da Playwright; ogni altro valore è ostile.
final RegExp _safeBodyName = RegExp(r'^[0-9a-f]{40}\.[a-z0-9]+$');

class _Hit {
  _Hit(this.method, this.uri, this.status, this.mime, this.body);

  final String method;
  final Uri uri;
  final int status;
  final String mime;
  final Uint8List? body;
}

class HarResult {
  HarResult({required this.cassette, required this.inventory});

  final Cassette cassette;
  final Map<String, Object?> inventory;
}

File findHar(String path) {
  if (File(path).existsSync()) return File(path);
  final dir = Directory(path);
  if (!dir.existsSync()) throw HarError('$path non esiste.');
  final hars = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.har')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (hars.isEmpty) throw HarError('Nessun file .har in $path.');
  return hars.first;
}

HarResult readHar(File har, {required Set<String> hosts}) {
  final Object? raw;
  try {
    raw = jsonDecode(utf8.decode(har.readAsBytesSync()));
  } on FormatException {
    throw HarError('${har.path}: non è un HAR in JSON.');
  }
  final entries = raw is Map && raw['log'] is Map ? (raw['log'] as Map)['entries'] : null;
  if (entries is! List) throw HarError('${har.path}: manca log.entries.');

  var hostedRejected = 0;
  var noBody = 0;
  final hits = <_Hit>[];
  for (final entry in entries) {
    if (entry is! Map || entry['request'] is! Map || entry['response'] is! Map) continue;
    final request = entry['request'] as Map;
    final response = entry['response'] as Map;
    final uri = Uri.tryParse('${request['url']}');
    if (uri == null || !uri.hasAuthority) continue;
    final content = response['content'] is Map ? response['content'] as Map : const {};
    final body = _body(content, har.parent, () => hostedRejected++);
    hits.add(_Hit(
      '${request['method']}'.toUpperCase(),
      uri,
      response['status'] is int ? response['status'] as int : 0,
      '${content['mimeType'] ?? ''}',
      body,
    ));
    if (body == null) noBody++;
  }

  final cassette = Cassette();
  final thirdParty = <String, int>{};
  final imageHosts = <String, int>{};
  final unsupported = <String, int>{};
  final endpoints = <String, _Endpoint>{};
  final volatile = <String>{};
  var sites = 0;
  for (final hit in hits) {
    final host = hit.uri.host;
    final own = hosts.contains(host);
    if (hit.method != 'GET') {
      if (own) unsupported['${hit.method} $host${_schema(hit.uri, volatile)}'] = (unsupported['${hit.method} $host${_schema(hit.uri, volatile)}'] ?? 0) + 1;
      continue;
    }
    final isImage = hit.mime.toLowerCase().startsWith('image/');
    if (!own) {
      thirdParty[host] = (thirdParty[host] ?? 0) + 1;
      if (isImage) imageHosts[host] = (imageHosts[host] ?? 0) + 1;
      continue;
    }
    sites++;
    final key = hit.uri.removeFragment().toString();
    var body = hit.body ?? Uint8List(0);
    if (isImage && body.length > imageHeadBytes) body = Uint8List.sublistView(body, 0, imageHeadBytes);
    cassette.entries.putIfAbsent(key, () => CassetteEntry(status: hit.status, contentType: hit.mime, body: body));
    final schema = _schema(hit.uri, volatile);
    final id = '$host $schema ${hit.status} ${hit.mime.split(';').first.trim()}';
    endpoints.putIfAbsent(id, () => _Endpoint(host, schema, hit.status, hit.mime.split(';').first.trim())).add(hit);
  }

  final inventory = <String, Object?>{
    'entries': hits.length,
    'cassetteEntries': cassette.entries.length,
    'ownGet': sites,
    'ignoredThirdParty': thirdParty.values.fold<int>(0, (a, b) => a + b),
    'ignoredThirdPartyHosts': thirdParty,
    'mediaHostCandidates': imageHosts,
    'notExpressible': unsupported,
    'rejectedBodyNames': hostedRejected,
    'withoutBody': noBody,
    'volatile': (volatile.toList()..sort()),
    'endpoints': [for (final e in endpoints.values) e.toJson()]..sort((a, b) => '${a['host']}${a['path']}'.compareTo('${b['host']}${b['path']}')),
  };
  return HarResult(cassette: cassette, inventory: inventory);
}

Uint8List? _body(Map content, Directory dir, void Function() onRejected) {
  final file = content['_file'];
  if (file != null) {
    if (file is String && _safeBodyName.hasMatch(file)) {
      final f = File(p.join(dir.path, file));
      if (f.existsSync()) return f.readAsBytesSync();
    } else {
      onRejected();
      return null;
    }
  }
  final text = content['text'];
  if (text is! String) return null;
  try {
    return content['encoding'] == 'base64' ? Uint8List.fromList(base64.decode(text)) : Uint8List.fromList(utf8.encode(text));
  } on FormatException {
    return null;
  }
}

final RegExp _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

bool _isId(String seg) =>
    RegExp(r'^\d+$').hasMatch(seg) ||
    _uuid.hasMatch(seg) ||
    RegExp(r'^[0-9a-fA-F]{8,}$').hasMatch(seg) ||
    (seg.length >= 16 && RegExp(r'\d').hasMatch(seg) && RegExp(r'[A-Za-z]').hasMatch(seg));

double _entropy(String s) {
  final counts = <int, int>{};
  for (final c in s.codeUnits) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  var h = 0.0;
  for (final n in counts.values) {
    final q = n / s.length;
    h -= q * math.log(q) / math.ln2;
  }
  return h;
}

/// Il percorso con gli id sostituiti da `{}`; i valori che cambiano a ogni giro
/// finiscono in [volatile].
String _schema(Uri uri, Set<String> volatile) {
  final segs = uri.pathSegments.toList();
  for (var i = 0; i < segs.length; i++) {
    if (i >= 2 && segs[i - 2] == '_next' && segs[i - 1] == 'data') {
      volatile.add('${uri.host} _next/data/<buildId>');
      segs[i] = '{buildId}';
    } else if (_isId(segs[i])) {
      segs[i] = '{}';
    }
  }
  var out = '/${segs.join('/')}';
  if (uri.queryParametersAll.isNotEmpty) {
    final names = <String>[];
    for (final MapEntry(:key, :value) in uri.queryParametersAll.entries) {
      names.add(key);
      if (value.any((v) => v.length >= 12 && _entropy(v) > 3.3)) volatile.add('${uri.host} ?$key (alta entropia)');
    }
    out += '?${(names..sort()).join('&')}';
  }
  return out;
}

class _Endpoint {
  _Endpoint(this.host, this.path, this.status, this.mime);

  final String host;
  final String path;
  final int status;
  final String mime;
  int count = 0;
  int bytes = 0;
  final Set<String> signals = {};

  void add(_Hit hit) {
    count++;
    final body = hit.body;
    if (body == null) return;
    bytes += body.length;
    if (body.length > 4000000) return;
    final text = utf8.decode(body, allowMalformed: true);
    final lower = hit.mime.toLowerCase();
    if (lower.contains('json')) {
      try {
        _jsonSignals(jsonDecode(text), signals, 0);
      } on FormatException {
        // JSON rotto: nessun segnale.
      }
    } else if (lower.contains('html')) {
      if (text.contains('__NEXT_DATA__')) signals.add('__NEXT_DATA__');
      if (text.contains('application/ld+json')) signals.add('application/ld+json');
      if (RegExp(r'''<meta[^>]+property=["']og:''', caseSensitive: false).hasMatch(text)) signals.add('og: meta');
    }
  }

  Map<String, Object?> toJson() => {
        'host': host,
        'path': path,
        'status': status,
        'type': mime,
        'count': count,
        'bytes': bytes,
        'signals': signals.toList()..sort(),
      };
}

final RegExp _imageUrl = RegExp(r'^https?://\S+\.(jpe?g|png|webp|avif|gif)(\?\S*)?$', caseSensitive: false);

void _jsonSignals(Object? node, Set<String> signals, int depth) {
  if (depth > 8) return;
  if (node is List) {
    if (node.length >= 10) {
      signals.add(node.first is Map ? 'array lungo di oggetti (candidato elenco capitoli)' : 'array lungo');
    }
    if (node.where((e) => e is String && _imageUrl.hasMatch(e)).length >= 3) signals.add('lista di URL d\'immagine');
    for (final e in node.take(50)) {
      _jsonSignals(e, signals, depth + 1);
    }
  } else if (node is Map) {
    if (node.values.any((v) => v is String && _imageUrl.hasMatch(v))) signals.add('URL d\'immagine');
    for (final v in node.values) {
      _jsonSignals(v, signals, depth + 1);
    }
  }
}

/// Il testo leggibile dell'inventario.
String renderInventory(Map<String, Object?> inv) {
  final b = StringBuffer()
    ..writeln('Voci nell\'HAR: ${inv['entries']}; GET sugli host del sito: ${inv['ownGet']}; in cassetta: ${inv['cassetteEntries']}')
    ..writeln('Terze parti ignorate: ${inv['ignoredThirdParty']}')
    ..writeln('Corpi scartati (_file non ammesso): ${inv['rejectedBodyNames']}; voci senza corpo: ${inv['withoutBody']}');
  final media = inv['mediaHostCandidates'] as Map;
  if (media.isNotEmpty) b.writeln('Candidati mediaHosts: ${media.entries.map((e) => '${e.key} (${e.value})').join(', ')}');
  final third = inv['ignoredThirdPartyHosts'] as Map;
  if (third.isNotEmpty) b.writeln('Host terzi: ${third.entries.map((e) => '${e.key} (${e.value})').join(', ')}');
  for (final v in inv['volatile'] as List) {
    b.writeln('Volatile: $v');
  }
  for (final MapEntry(:key, :value) in (inv['notExpressible'] as Map).entries) {
    b.writeln('Non esprimibile (il motore fa solo GET): $key x$value');
  }
  b.writeln('Endpoint:');
  for (final e in inv['endpoints'] as List) {
    final m = e as Map;
    final signals = (m['signals'] as List).isEmpty ? '' : '  [${(m['signals'] as List).join('; ')}]';
    b.writeln('  ${m['host']}${m['path']}  ${m['status']} ${m['type']}  x${m['count']} ${m['bytes']}B$signals');
  }
  return b.toString();
}
