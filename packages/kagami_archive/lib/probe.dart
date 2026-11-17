/// La sentinella dei siti (`kagami-server probe`): per ogni sito prova ricerca,
/// serie, tavole di un capitolo e prima immagine con un canarino noto, e dice
/// se il sito è `ok`, `changed` (il provider va aggiornato), `offline` o
/// `gated` (verifica del browser). Non scrive niente e non conosce Drive.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'declarative.dart' show DeclarativeProvider;
import 'http.dart';
import 'model.dart';
import 'providers.dart';

/// Che cosa provare di un sito: una ricerca, l'indirizzo di una serie, o tutti
/// e due (con la ricerca si controlla anche che trovi qualcosa).
/// [minChapters]: meno capitoli di così è `changed`.
class Canary {
  const Canary({this.query, this.url, this.minChapters});

  final String? query;
  final String? url;
  final int? minChapters;

  static const int maxPerSite = 3;

  /// Per sito un oggetto (come prima) o una lista di al più [maxPerSite].
  static Map<String, List<Canary>> parse(String json) {
    final root = jsonDecode(json);
    final sites = root is Map ? root['sites'] : null;
    if (sites is! Map) throw const FormatException('canaries.json: manca "sites".');
    Canary one(Map value) => Canary(
          query: value['query'] as String?,
          url: value['url'] as String?,
          minChapters: (value['minChapters'] as num?)?.toInt(),
        );
    final result = <String, List<Canary>>{};
    for (final MapEntry(:key, :value) in sites.entries) {
      if (value is Map) {
        result['$key'] = [one(value)];
      } else if (value is List) {
        if (value.length > maxPerSite) throw FormatException('canaries.json: "$key" ha più di $maxPerSite canarini.');
        result['$key'] = [for (final item in value) if (item is Map) one(item)];
      }
    }
    return result;
  }
}

enum ProbeStatus { ok, changed, offline, gated, skipped }

/// L'esito di un canarino, `n` da 1.
class CanaryResult {
  const CanaryResult(this.n, this.status, this.fault, this.degraded, [this.message = '']);

  final int n;
  final ProbeStatus status;
  final SiteFault? fault;
  final List<String> degraded;
  final String message;

  Map<String, Object?> toJson() => {'n': n, 'status': status.name, 'fault': _faultJson(fault)};
}

Map<String, Object?>? _faultJson(SiteFault? fault) =>
    fault == null ? null : {'phase': fault.phase, 'field': fault.field, 'detail': fault.detail};

class SiteProbe {
  const SiteProbe({
    required this.site,
    required this.status,
    required this.duration,
    this.phase,
    this.message = '',
    this.version,
    this.origin = 'builtIn',
    this.fault,
    this.degraded = const [],
    this.canaries = const [],
  });

  final String site;
  final ProbeStatus status;

  /// `search`, `series`, `chapters`, `pages` o `image`: dov'è fallito; `null` se ok.
  final String? phase;
  final String message;
  final Duration duration;
  final int? version;
  final String origin;

  /// Il guasto, quando lo stato non è `ok`.
  final SiteFault? fault;

  /// Alternative vincenti non prime (`series.title#2`) e canarini falliti (`canary#2`).
  final List<String> degraded;
  final List<CanaryResult> canaries;

  bool get failed => status != ProbeStatus.ok && status != ProbeStatus.skipped;

  Map<String, Object?> toJson() => {
        'site': site,
        'status': status.name,
        'phase': phase,
        'message': message,
        'durationMs': duration.inMilliseconds,
        'version': version,
        'origin': origin,
        'fault': _faultJson(fault),
        'degraded': degraded,
        'canaries': [for (final c in canaries) c.toJson()],
      };
}

typedef ImageFetch = Future<Uint8List> Function(String url, String referer);

/// I primi byte di [url]: bastano a dire se è un'immagine.
Future<Uint8List> fetchImagePrefix(String url, String referer, {String userAgent = defaultUserAgent}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 30));
    request.headers
      ..set('User-Agent', userAgent)
      ..set('Referer', referer)
      ..set('Accept', 'image/*');
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw HttpStatusError(response.statusCode, cdn: true);
    }
    final head = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      head.add(chunk);
      if (head.length >= 16) break;
    }
    return head.takeBytes();
  } on SocketException {
    throw const ProviderOffline();
  } on TimeoutException {
    throw const ProviderOffline();
  } on HttpException {
    throw const ProviderOffline();
  } on TlsException {
    throw const ProviderOffline();
  } finally {
    client.close(force: true);
  }
}

bool looksLikeImage(List<int> b) {
  bool at(int i, List<int> magic) {
    if (b.length < i + magic.length) return false;
    for (var k = 0; k < magic.length; k++) {
      if (b[i + k] != magic[k]) return false;
    }
    return true;
  }

  return at(0, [0xFF, 0xD8, 0xFF]) ||
      at(0, [0x89, 0x50, 0x4E, 0x47]) ||
      at(0, [0x47, 0x49, 0x46, 0x38]) ||
      (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) ||
      at(4, [0x66, 0x74, 0x79, 0x70]);
}

class _Failure implements Exception {
  _Failure(this.phase, this.status, this.message, {this.field, this.detail});
  final String phase;
  final ProbeStatus status;
  final String message;
  final String? field;
  final String? detail;

  SiteFault get fault => SiteFault(phase, field: field, detail: detail ?? message);
}

_Failure _classify(String phase, Object error) {
  if (error is CloudflareChallenge) return _Failure(phase, ProbeStatus.gated, error.message);
  if (error is ProviderOffline) return _Failure(phase, ProbeStatus.offline, error.message);
  if (error is HttpStatusError) {
    final s = error.status;
    final status = s == 403 ? ProbeStatus.gated : (s == 429 || s >= 500) ? ProbeStatus.offline : ProbeStatus.changed;
    return _Failure(phase, status, error.message, detail: 'HTTP $s');
  }
  if (error is ProviderChanged && error.fault != null) {
    final f = error.fault!;
    return _Failure(sitePhases.contains(f.phase) ? f.phase : phase, ProbeStatus.changed, error.message,
        field: f.field, detail: f.detail ?? error.message);
  }
  if (error is ProviderError) return _Failure(phase, ProbeStatus.changed, error.message);
  if (error is TimeoutException || error is SocketException || error is HttpException || error is TlsException) {
    return _Failure(phase, ProbeStatus.offline, '$error');
  }
  return _Failure(phase, ProbeStatus.changed, 'Struttura inattesa: $error');
}

Future<T> _step<T>(String phase, SiteTrace trace, Future<T> Function() body) async {
  try {
    return await trace.run(body);
  } on _Failure {
    rethrow;
  } on Object catch (error) {
    throw _classify(phase, error);
  }
}

/// Più basso è, migliore è: un canarino che va vale più di uno offline.
int _rank(ProbeStatus s) => switch (s) {
      ProbeStatus.ok => 0,
      ProbeStatus.offline => 1,
      ProbeStatus.gated => 2,
      _ => 3,
    };

Future<CanaryResult> _probeCanary(
  int n,
  Provider provider,
  Canary canary,
  ProviderHttp http,
  ImageFetch? fetchImage,
  Duration timeout,
) async {
  final trace = SiteTrace();
  try {
    await Future(() async {
      String? seriesUrl = canary.url;
      final query = canary.query;
      if (query != null) {
        final results = await _step('search', trace, () => provider.search(query, http));
        if (results.isEmpty) throw _Failure('search', ProbeStatus.changed, 'La ricerca "$query" non dà risultati.');
        seriesUrl ??= results.first.url;
      }
      final series = await _step('series', trace, () => provider.fetchSeries(seriesUrl!, http));
      if (series.chapters.isEmpty) throw _Failure('series', ProbeStatus.changed, 'La serie non ha capitoli.');
      final min = canary.minChapters;
      if (min != null && series.chapters.length < min) {
        throw _Failure('chapters', ProbeStatus.changed, 'La serie ha ${series.chapters.length} capitoli, attesi almeno $min.',
            field: 'series.chapters', detail: '${series.chapters.length} capitoli, attesi almeno $min');
      }
      final content = await _step('pages', trace, () => provider.fetchPages(series.chapters.first, http));
      if (content.pages.isEmpty) throw _Failure('pages', ProbeStatus.changed, 'Il capitolo non ha tavole.');
      final imageUrl = content.pages.first.url;
      await _step('image', trace, () async {
        provider.validateUrl(imageUrl);
        final head = await (fetchImage ?? fetchImagePrefix)(imageUrl, series.url);
        if (!looksLikeImage(head)) throw const ProviderChanged('La prima tavola non è un\'immagine.');
      });
    }).timeout(timeout);
    return CanaryResult(n, ProbeStatus.ok, null, trace.degraded);
  } on _Failure catch (failure) {
    return CanaryResult(n, failure.status, failure.fault, trace.degraded, failure.message);
  } on TimeoutException {
    return CanaryResult(n, ProbeStatus.offline,
        SiteFault('series', detail: 'Nessuna risposta entro ${timeout.inSeconds} s.'), trace.degraded,
        'Nessuna risposta entro ${timeout.inSeconds} s.');
  }
}

/// Prova un sito con i suoi [canaries] (al più [Canary.maxPerSite]); lo stato è
/// il migliore dei canarini. [httpFor] dà il client con cui parlargli.
Future<SiteProbe> probeSite(
  Provider provider,
  List<Canary>? canaries,
  ProviderHttp Function(Provider) httpFor, {
  ImageFetch? fetchImage,
  Duration timeout = const Duration(minutes: 2),
}) async {
  final watch = Stopwatch()..start();
  final version = switch (provider.unwrapped) {
    final DeclarativeProvider site => site.version,
    _ => null,
  };
  final usable = [for (final c in canaries ?? const <Canary>[]) if (c.query != null || c.url != null) c];
  SiteProbe done(ProbeStatus status,
          {String? phase, String message = '', SiteFault? fault, List<String> degraded = const [], List<CanaryResult> results = const []}) =>
      SiteProbe(
        site: provider.id,
        status: status,
        phase: phase,
        message: message,
        duration: watch.elapsed,
        version: version,
        origin: provider.origin.name,
        fault: fault,
        degraded: degraded,
        canaries: results,
      );
  if (usable.isEmpty) return done(ProbeStatus.skipped, message: 'Nessun canarino in canaries.json.');
  final http = httpFor(provider);
  final results = <CanaryResult>[];
  for (var i = 0; i < usable.length && i < Canary.maxPerSite; i++) {
    results.add(await _probeCanary(i + 1, provider, usable[i], http, fetchImage, timeout));
  }
  final best = results.reduce((a, b) => _rank(b.status) < _rank(a.status) ? b : a);
  final degraded = <String>{};
  if (best.status == ProbeStatus.ok) {
    for (final r in results) {
      if (r.status == ProbeStatus.ok) {
        degraded.addAll(r.degraded);
      } else {
        degraded.add('canary#${r.n}');
      }
    }
  } else {
    degraded.addAll(best.degraded);
  }
  final sorted = degraded.toList()..sort();
  final fault = best.fault;
  return done(best.status,
      phase: fault?.phase,
      message: best.message,
      fault: fault,
      degraded: sorted,
      results: results);
}

/// L'esito intero, nella forma di `--json`.
Map<String, Object?> probeReport(List<SiteProbe> sites, {required DateTime checkedAt, required int engine, required int serial}) => {
      'checkedAt': checkedAt.toUtc().toIso8601String(),
      'engine': engine,
      'serial': serial,
      'sites': [for (final site in sites) site.toJson()],
    };

String probeLine(SiteProbe s) =>
    '${s.status.name.padRight(7)} ${s.site} (${s.origin}${s.version == null ? '' : ' v${s.version}'}) ${s.duration.inMilliseconds} ms'
    '${s.phase == null ? '' : ' · ${s.phase}'}${s.message.isEmpty ? '' : ': ${s.message}'}';
