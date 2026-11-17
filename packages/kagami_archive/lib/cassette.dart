/// Cassette: ciò che un sito ha risposto al motore durante un giro, salvato per
/// riprodurlo senza rete (formato in `docs/manutenzione-siti.md` § «Cassette»).
///
/// Contiene solo ciò che `ProviderHttp` restituisce (stato, tipo, corpo): header e
/// cookie non ci sono perché l'interfaccia non li dà.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'http.dart';
import 'model.dart';

/// La definizione ha chiesto un indirizzo che la cassetta non contiene. Non è un
/// `ProviderError`: vuol dire che la definizione è cambiata, non il sito.
class CassetteMiss implements Exception {
  const CassetteMiss(this.url);

  final String url;

  @override
  String toString() => 'richiesta non prevista: $url';
}

/// Una cassetta con un file ostile o un JSON che non è quello atteso.
class CassetteFormatError implements Exception {
  const CassetteFormatError(this.message);

  final String message;

  @override
  String toString() => 'cassetta non valida: $message';
}

class CassetteEntry {
  const CassetteEntry({required this.status, required this.contentType, required this.body});

  final int status;
  final String contentType;

  /// Vuoto se la risposta non aveva corpo (`imageExists`, errori).
  final Uint8List body;
}

class Cassette {
  Cassette({Map<String, CassetteEntry>? entries, DateTime? recordedAt})
      : entries = entries ?? {},
        recordedAt = (recordedAt ?? DateTime.now()).toUtc();

  final Map<String, CassetteEntry> entries;
  final DateTime recordedAt;

  static final RegExp _safeName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  static Cassette load(Directory dir) {
    final Object? raw;
    try {
      raw = jsonDecode(File('${dir.path}/cassette.json').readAsStringSync());
    } on FormatException {
      throw const CassetteFormatError('cassette.json non è JSON');
    }
    if (raw is! Map || raw['entries'] is! Map) throw const CassetteFormatError('manca entries');
    final entries = <String, CassetteEntry>{};
    for (final MapEntry(:key, :value) in (raw['entries'] as Map).entries) {
      if (key is! String || value is! Map || value['status'] is! int) {
        throw CassetteFormatError('voce non valida: $key');
      }
      final file = value['file'];
      var body = Uint8List(0);
      if (file != null) {
        // Il nome arriva da un file che non controlliamo: niente percorsi.
        if (file is! String || !_safeName.hasMatch(file) || file.contains('..')) {
          throw CassetteFormatError('nome di file non ammesso: $file');
        }
        body = File('${dir.path}/$file').readAsBytesSync();
      }
      entries[key] = CassetteEntry(
        status: value['status'] as int,
        contentType: (value['contentType'] as String?) ?? '',
        body: body,
      );
    }
    final at = raw['recordedAt'] is String ? DateTime.tryParse(raw['recordedAt'] as String) : null;
    return Cassette(entries: entries, recordedAt: at);
  }

  /// Scrive `cassette.json` e i corpi; il nome di un corpo è lo sha1 dell'indirizzo.
  void save(Directory dir) {
    dir.createSync(recursive: true);
    final json = <String, Object?>{};
    for (final MapEntry(:key, :value) in entries.entries) {
      String? file;
      if (value.body.isNotEmpty) {
        file = '${sha1.convert(utf8.encode(key)).toString().substring(0, 12)}.${_extension(value.contentType)}';
        File('${dir.path}/$file').writeAsBytesSync(value.body);
      }
      json[key] = {'status': value.status, 'contentType': value.contentType, 'file': ?file};
    }
    File('${dir.path}/cassette.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'recordedAt': recordedAt.toIso8601String(), 'entries': json})}\n',
    );
  }

  static String _extension(String contentType) {
    final mime = contentType.split(';').first.trim().toLowerCase();
    return switch (mime) {
      'text/html' => 'html',
      'application/json' => 'json',
      'image/webp' => 'webp',
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/avif' => 'avif',
      _ => 'bin',
    };
  }
}

/// L'esito atteso di una cassetta (`expect.json`).
class CassetteExpect {
  const CassetteExpect({this.query, this.url, this.seriesId, this.title, this.minChapters, this.firstPage});

  final String? query;
  final String? url;
  final String? seriesId;
  final String? title;
  final int? minChapters;
  final String? firstPage;

  static CassetteExpect load(Directory dir) {
    final Object? raw;
    try {
      raw = jsonDecode(File('${dir.path}/expect.json').readAsStringSync());
    } on FormatException {
      throw const CassetteFormatError('expect.json non è JSON');
    }
    if (raw is! Map) throw const CassetteFormatError('expect.json non è un oggetto');
    final map = raw;
    String? text(String key) => map[key] is String ? map[key] as String : null;
    return CassetteExpect(
      query: text('query'),
      url: text('url'),
      seriesId: text('seriesId'),
      title: text('title'),
      minChapters: map['minChapters'] is int ? map['minChapters'] as int : null,
      firstPage: text('firstPage'),
    );
  }

  void save(Directory dir) {
    dir.createSync(recursive: true);
    final json = {
      'query': ?query,
      'url': ?url,
      'seriesId': ?seriesId,
      'title': ?title,
      'minChapters': ?minChapters,
      'firstPage': ?firstPage,
    };
    File('${dir.path}/expect.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}\n');
  }
}

String _mime(String contentType) => contentType.split(';').first.trim().toLowerCase();

/// Risponde da una cassetta, con gli stessi errori del client vero.
class ReplayHttp implements ProviderHttp {
  ReplayHttp(this.cassette);

  factory ReplayHttp.load(Directory dir) => ReplayHttp(Cassette.load(dir));

  final Cassette cassette;

  CassetteEntry _entry(String url) => cassette.entries[url] ?? (throw CassetteMiss(url));

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    final entry = _entry(url);
    if (entry.status != 200) throw HttpStatusError(entry.status);
    if (entry.body.length > limit) throw const ProviderError('Risposta troppo grande.');
    return (body: entry.body, contentType: _mime(entry.contentType));
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async {
    final entry = _entry(url);
    if (entry.status == 404) return false;
    if (entry.status != 200) throw HttpStatusError(entry.status, cdn: true);
    if (!_mime(entry.contentType).startsWith('image/')) {
      throw const ProviderError('Il CDN non ha restituito un’immagine.');
    }
    return true;
  }

  @override
  Future<Map<String, Object?>> json(String url) async {
    final result = await get(url);
    if (result.contentType != 'application/json') throw const ProviderChanged('Risposta JSON non valida.');
    return decodeJsonObject(result.body);
  }
}

/// Avvolge un client vero e annota ogni risposta, errori di stato compresi.
class RecordingHttp implements ProviderHttp {
  RecordingHttp(this.inner);

  final ProviderHttp inner;
  final Cassette cassette = Cassette();

  void _note(String url, CassetteEntry entry) {
    final old = cassette.entries[url];
    // Un indirizzo ha una risposta sola; ma un corpo vale più di un «esiste».
    if (old == null || (old.body.isEmpty && entry.body.isNotEmpty)) cassette.entries[url] = entry;
  }

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async {
    try {
      final result = await inner.get(url, limit: limit, referer: referer);
      _note(url, CassetteEntry(status: 200, contentType: result.contentType, body: result.body));
      return result;
    } on HttpStatusError catch (error) {
      _note(url, CassetteEntry(status: error.status, contentType: '', body: Uint8List(0)));
      rethrow;
    }
  }

  @override
  Future<bool> imageExists(String url, {required String referer}) async {
    try {
      final exists = await inner.imageExists(url, referer: referer);
      _note(url, CassetteEntry(status: exists ? 200 : 404, contentType: exists ? 'image/*' : '', body: Uint8List(0)));
      return exists;
    } on HttpStatusError catch (error) {
      _note(url, CassetteEntry(status: error.status, contentType: '', body: Uint8List(0)));
      rethrow;
    }
  }

  @override
  Future<Map<String, Object?>> json(String url) async {
    final result = await get(url);
    if (result.contentType != 'application/json') throw const ProviderChanged('Risposta JSON non valida.');
    return decodeJsonObject(result.body);
  }

  void save(Directory dir) => cassette.save(dir);
}
