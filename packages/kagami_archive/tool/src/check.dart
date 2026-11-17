/// `site.dart check`: ricerca, serie e tavole del primo capitolo di una definizione,
/// da una cassetta (`--replay`) o dal sito vero (`--live`, con `--record`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/cassette.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';

import 'har.dart' show HarError;
import 'theme.dart';

class CheckOptions {
  CheckOptions({required this.definition, this.replay, this.live = false, this.record, this.query, this.url, this.themes, this.asJson = false});

  final String definition;
  final String? replay;
  final bool live;
  final String? record;
  final String? query;
  final String? url;
  final String? themes;
  final bool asJson;
}

const String checkUsage =
    'Uso: site.dart check <def.json> (--replay <cassetta> | --live [--record <cartella>]) [--query q | --url u] [--themes dir] [--json]';

CheckOptions parseCheck(List<String> args) {
  String? definition, replay, record, query, url, themes;
  var live = false, asJson = false;
  String value(int i) => i + 1 < args.length ? args[i + 1] : throw HarError('Manca il valore di ${args[i]}.');
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--json':
        asJson = true;
      case '--live':
        live = true;
      case '--replay':
        replay = value(i++);
      case '--record':
        record = value(i++);
      case '--query':
        query = value(i++);
      case '--url':
        url = value(i++);
      case '--themes':
        themes = value(i++);
      default:
        if (args[i].startsWith('--')) throw HarError('Opzione sconosciuta: ${args[i]}.');
        definition = args[i];
    }
  }
  if (definition == null) throw const HarError(checkUsage);
  if (live == (replay != null)) throw const HarError('Serve una sola fra --replay e --live.');
  if (record != null && !live) throw const HarError('--record vale solo con --live.');
  if (query != null && url != null) throw const HarError('--query e --url sono alternative.');
  return CheckOptions(definition: definition, replay: replay, live: live, record: record, query: query, url: url, themes: themes, asJson: asJson);
}

Map<String, Object?> _faultJson(SiteFault f) => {'phase': f.phase, 'field': f.field, 'detail': f.detail};

/// Esegue il giro e scrive l'esito; 0 se la definizione regge (e, con `--replay`,
/// l'esito è quello di `expect.json`), 1 altrimenti.
Future<int> runCheck(CheckOptions o, StringSink out) async {
  final DeclarativeProvider provider;
  try {
    provider = DeclarativeProvider.parse(resolveDefinitionText(File(o.definition).readAsStringSync(), o.themes ?? defaultThemesDirForFile(o.definition)));
  } on FileSystemException {
    throw HarError('${o.definition} non si legge.');
  } on SiteDefinitionError catch (error) {
    throw HarError('${o.definition}: ${error.message}');
  } on ThemeError catch (error) {
    throw HarError('${o.definition}: ${error.message}');
  }

  CassetteExpect? expect;
  ProviderHttp http;
  SiteHttp? live;
  RecordingHttp? recorder;
  if (o.replay != null) {
    final dir = Directory(o.replay!);
    try {
      http = ReplayHttp.load(dir);
      if (File('${dir.path}/expect.json').existsSync()) expect = CassetteExpect.load(dir);
    } on CassetteFormatError catch (error) {
      throw HarError(error.toString());
    } on FileSystemException {
      throw HarError('${o.replay} non è una cassetta (manca cassette.json).');
    }
  } else {
    http = live = SiteHttp(provider.allowedHost, attempts: 2, publicOnly: true);
    if (o.record != null) http = recorder = RecordingHttp(http);
  }

  final query = o.query ?? (o.url == null ? expect?.query : null);
  final url = o.url ?? (o.query == null ? expect?.url : null);
  if (query == null && url == null) throw const HarError('Manca --query o --url (e la cassetta non ha expect.json che li dica).');

  final trace = SiteTrace();
  final result = <String, Object?>{'site': provider.id, 'series': null, 'pages': null, 'fault': null, 'degraded': <String>[]};
  var failed = false;
  String? seriesUrl = url;
  Series? series;
  String? firstPage;
  var phase = 'search';
  try {
    if (query != null) {
      final found = await trace.run(() => provider.search(query, http));
      if (found.isEmpty) throw const ProviderChanged('La ricerca non dà risultati.');
      seriesUrl ??= found.first.url;
    }
    phase = 'series';
    final read = await trace.run(() => provider.fetchSeries(seriesUrl!, http));
    series = read;
    result['series'] = {'id': read.id, 'title': read.title, 'chapters': read.chapters.length};
    if (read.chapters.isEmpty) throw const ProviderChanged('La serie non ha capitoli.');
    phase = 'pages';
    final content = await trace.run(() => provider.fetchPages(read.chapters.first, http));
    firstPage = content.pages.isEmpty ? null : content.pages.first.url;
    result['pages'] = {'count': content.pages.length, 'first': firstPage};
    if (content.pages.isEmpty) throw const ProviderChanged('Il capitolo non ha tavole.');
  } on CassetteMiss catch (miss) {
    live?.close();
    throw HarError('La definizione ha chiesto un indirizzo fuori dalla cassetta: ${miss.url}');
  } on ProviderError catch (error) {
    failed = true;
    final fault = error is ProviderChanged ? error.fault : null;
    result['fault'] = fault != null
        ? _faultJson(fault)
        : {'phase': phase, 'field': null, 'detail': error.message};
  } finally {
    live?.close();
  }
  result['degraded'] = trace.degraded;

  final diffs = <String>[];
  if (expect != null && !failed) {
    if (expect.title != null && expect.title != series?.title) diffs.add('title: atteso "${expect.title}", trovato "${series?.title}"');
    if (expect.seriesId != null && expect.seriesId != series?.id) diffs.add('seriesId: atteso "${expect.seriesId}", trovato "${series?.id}"');
    final n = series?.chapters.length ?? 0;
    if (expect.minChapters != null && n < expect.minChapters!) diffs.add('minChapters: attesi almeno ${expect.minChapters}, trovati $n');
    if (expect.firstPage != null && expect.firstPage != firstPage) diffs.add('firstPage: atteso "${expect.firstPage}", trovato "$firstPage"');
  }
  result['expect'] = diffs;

  if (o.record != null && !failed && recorder != null) {
    final dir = Directory(o.record!);
    recorder.save(dir);
    CassetteExpect(
      query: query,
      url: query == null ? url : null,
      seriesId: series?.id,
      title: series?.title,
      minChapters: series?.chapters.length,
      firstPage: firstPage,
    ).save(dir);
    result['recorded'] = dir.path;
  }

  if (o.asJson) {
    out.writeln(const JsonEncoder.withIndent('  ').convert(result));
  } else {
    final s = result['series'] as Map?;
    final p = result['pages'] as Map?;
    out.writeln('${provider.id}: ${s == null ? 'serie non letta' : '"${s['title']}" (${s['id']}), ${s['chapters']} capitoli'}'
        '${p == null ? '' : ', ${p['count']} tavole'}');
    final fault = result['fault'] as Map?;
    if (fault != null) out.writeln('GUASTO ${fault['phase']}${fault['field'] == null ? '' : ' · ${fault['field']}'}: ${fault['detail']}');
    if (trace.degraded.isNotEmpty) out.writeln('Degradato: ${trace.degraded.join(', ')}');
    for (final d in diffs) {
      out.writeln('DIFFERENZA $d');
    }
    if (result['recorded'] != null) {
      out.writeln('Cassetta salvata in ${result['recorded']}. expect.json è scritto dall\'esito di adesso: '
          'rileggilo a mano (titolo, minChapters, firstPage) prima di fidartene.');
    }
  }
  return failed || diffs.isNotEmpty ? 1 : 0;
}
