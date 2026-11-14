/// La stessa serie sugli altri siti: dov'è, quanti capitoli ha, fin dove è
/// arrivata, e chi è rotto.
///
/// È un dato ricavato, non MALF: si rifà in una passata, e scriverlo in
/// `series.json` ogni giorno farebbe risincronizzare ogni cartella. Lo tiene
/// chi lo calcola, il server in `elsewhere.json` accanto a `ongoing.json`
/// (`GET /v2/elsewhere`) o il telefono nella sua cache.
///
/// Ogni passata costa richieste ai siti: per serie, su ogni altro sito, fino a
/// quattro ricerche (titolo e alternativi) e una lettura della serie trovata.
/// Per questo una serie già trovata si rilegge senza cercarla, una non trovata
/// si ricerca solo dopo [missingAgain], un sito rotto o dietro la verifica non
/// si chiede affatto, e fra una richiesta e l'altra si aspetta.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'health.dart';
import 'http.dart';
import 'model.dart';
import 'providers.dart';
import 'repair.dart' show libraryRows;
import 'stores.dart';

/// Un titolo nella forma in cui due siti lo scrivono uguale: senza
/// maiuscole, spazi e punteggiatura («The House Without Time» e
/// «The House: Without Time!» sono la stessa serie).
String titleKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

/// Il primo dei [results] che porta uno dei [titles] della serie (il titolo
/// e quelli alternativi), o `null`: la serie sull'altro sito, se la sua
/// ricerca la trova con lo stesso nome.
SearchResult? sameSeries(Iterable<SearchResult> results, Iterable<String> titles) {
  final wanted = {for (final title in titles) titleKey(title)}..remove('');
  return results.where((result) => wanted.contains(titleKey(result.title))).firstOrNull;
}

/// Una serie si riguarda dopo questo tempo; meno di un giorno, perché la
/// passata quotidiana non la salti per pochi minuti.
const Duration elsewhereAgain = Duration(hours: 20);

/// Una serie conclusa (o cancellata) sul suo sito si riguarda una volta a
/// settimana: altrove può ancora mancare qualche capitolo, ma di rado.
const Duration concludedAgain = Duration(days: 7);

/// Un sito dove la serie non c'era si ricerca dopo questo tempo.
const Duration missingAgain = Duration(days: 7);

/// Quante serie al più per passata: una libreria grande si completa in più
/// giorni, cominciando dalle serie guardate meno di recente.
const int elsewherePerPass = 100;

/// Quanti titoli (il principale e gli alternativi) si cercano al più su un sito.
const int elsewhereTitles = 4;

enum ElsewhereState {
  /// La serie c'è e la sua pagina si è letta.
  found,

  /// La ricerca del sito non la trova con nessuno dei suoi titoli.
  missing,

  /// Il sito ha risposto con un errore: per questa volta non si sa.
  error,

  /// Il sito è rotto per intero ([SiteHealth]): non si è chiesto niente.
  broken,

  /// Il sito vuole la verifica del browser e qui non si passa.
  gated,
}

/// La serie su un sito. Con [state] diverso da `found` restano i dati
/// dell'ultima volta che c'era ([url], [chapters]…), se c'è stata.
class SiteCopy {
  const SiteCopy({
    required this.provider,
    required this.state,
    required this.checkedAt,
    this.key,
    this.url,
    this.title,
    this.chapters,
    this.latest,
    this.latestAt,
    this.releaseStatus = 'unknown',
    this.message,
  });

  factory SiteCopy.fromJson(String provider, Map<String, Object?> json) => SiteCopy(
        provider: provider,
        state: ElsewhereState.values.asNameMap()[json['state']] ?? ElsewhereState.error,
        checkedAt: DateTime.tryParse('${json['checkedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        key: json['key'] as String?,
        url: json['url'] as String?,
        title: json['title'] as String?,
        chapters: (json['chapters'] as num?)?.toInt(),
        latest: json['latest'] as String?,
        latestAt: json['latestAt'] as String?,
        releaseStatus: json['releaseStatus'] as String? ?? 'unknown',
        message: json['message'] as String?,
      );

  final String provider;
  final ElsewhereState state;
  final DateTime checkedAt;

  /// La chiave MALF della serie su quel sito.
  final String? key;
  final String? url;
  final String? title;

  /// Quanti capitoli elenca il sito.
  final int? chapters;

  /// Il numero dell'ultimo capitolo ([latestChapterNumber]), che si
  /// confronta con quello della serie in uso: i conteggi no, perché un sito
  /// conta anche prologhi e avvisi.
  final String? latest;

  /// Quando è uscito l'ultimo capitolo, come lo scrive il sito, se lo scrive.
  final String? latestAt;

  /// Uno di [releaseStatuses].
  final String releaseStatus;

  /// L'errore del sito, per `error`, `broken` e `gated`.
  final String? message;

  /// Lo stesso sito in un altro stato, con i dati dell'ultima volta che c'era.
  SiteCopy withState(ElsewhereState state, DateTime checkedAt, {String? message}) => SiteCopy(
        provider: provider,
        state: state,
        checkedAt: checkedAt,
        key: key,
        url: url,
        title: title,
        chapters: chapters,
        latest: latest,
        latestAt: latestAt,
        releaseStatus: releaseStatus,
        message: message,
      );

  Map<String, Object?> toJson() => {
        'state': state.name,
        'checkedAt': checkedAt.toUtc().toIso8601String(),
        'key': ?key,
        'url': ?url,
        'title': ?title,
        'chapters': ?chapters,
        'latest': ?latest,
        'latestAt': ?latestAt,
        if (key != null) 'releaseStatus': releaseStatus,
        'message': ?message,
      };
}

/// La serie [key] sugli altri siti, per id del provider. Il sito della serie
/// non c'è: quello lo dice il suo indice.
class Elsewhere {
  const Elsewhere({required this.key, required this.checkedAt, required this.sites});

  factory Elsewhere.fromJson(String key, Map<String, Object?> json) => Elsewhere(
        key: key,
        checkedAt: DateTime.tryParse('${json['checkedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        sites: {
          if (json['sites'] case final Map sites)
            for (final MapEntry(:key, :value) in sites.entries)
              if (key is String && value is Map<String, Object?>) key: SiteCopy.fromJson(key, value),
        },
      );

  final String key;
  final DateTime checkedAt;
  final Map<String, SiteCopy> sites;

  Map<String, Object?> toJson() => {
        'checkedAt': checkedAt.toUtc().toIso8601String(),
        'sites': {for (final MapEntry(:key, :value) in sites.entries) key: value.toJson()},
      };
}

/// Se la serie va riguardata: mai vista, o vista da più di [elsewhereAgain]
/// ([concludedAgain] se sul suo sito è conclusa).
bool elsewhereDue(Elsewhere? previous, DateTime now, {bool concluded = false}) =>
    previous == null || now.difference(previous.checkedAt) >= (concluded ? concludedAgain : elsewhereAgain);

/// `elsewhere.json`: le serie per chiave. Si riscrive dopo ogni serie, così
/// una passata interrotta non perde ciò che ha già letto.
class ElsewhereLog {
  ElsewhereLog(this.file);

  final File file;

  Future<Map<String, Elsewhere>> load() async {
    final series = (await readJsonFile(file))?['series'];
    return {
      if (series is Map)
        for (final MapEntry(:key, :value) in series.entries)
          if (key is String && value is Map<String, Object?>) key: Elsewhere.fromJson(key, value),
    };
  }

  Future<void> put(Elsewhere found) async {
    final all = await load();
    all[found.key] = found;
    await writeAtomically(
      file,
      utf8.encode(jsonEncode({'series': {for (final MapEntry(:key, :value) in all.entries) key: value.toJson()}})),
    );
  }
}

/// Cerca la serie [key] (con i suoi [titles]) su ogni sito di [sites] che non
/// è il suo. [previous] è la volta prima: un sito dove c'era si rilegge dal
/// suo link senza cercare, uno dove mancava si lascia com'è per
/// [missingAgain]. I siti rotti in [health] non si chiedono; un
/// [ProviderChanged] li dichiara rotti in [watch]. Solo la rete che manca
/// ([ProviderOffline]) esce come eccezione: l'errore di un sito resta suo.
Future<Elsewhere> findElsewhere({
  required String key,
  required List<String> titles,
  required ProviderHttp Function(Provider provider) httpFor,
  List<Provider>? sites,
  PageBrowser? browser,
  Map<String, SiteHealth> health = const {},
  SiteWatch? watch,
  Elsewhere? previous,
  Duration delay = const Duration(seconds: 2),
  DateTime Function() clock = DateTime.now,
}) async {
  final source = key.split(':').first;
  final wanted = [for (final title in titles) if (title.trim().isNotEmpty) title.trim()].take(elsewhereTitles).toList();
  final found = <String, SiteCopy>{};
  var asked = false;
  Future<void> pause() async {
    if (asked) await Future<void>.delayed(delay);
    asked = true;
  }

  for (final provider in sites ?? providers) {
    if (provider.id == source) continue;
    final before = previous?.sites[provider.id];
    final blank = before ?? SiteCopy(provider: provider.id, state: ElsewhereState.missing, checkedAt: clock());
    final siteHealth = health[provider.id];
    if (siteHealth != null && siteHealth.broken) {
      found[provider.id] = blank.withState(ElsewhereState.broken, clock(), message: siteHealth.message);
      continue;
    }
    if (provider.needsBrowser && browser == null) {
      found[provider.id] = blank.withState(ElsewhereState.gated, clock());
      continue;
    }
    if (before != null && before.state == ElsewhereState.missing && clock().difference(before.checkedAt) < missingAgain) {
      found[provider.id] = before;
      continue;
    }
    final http = httpFor(provider);
    try {
      var url = before?.url;
      if (url == null) {
        for (final title in wanted) {
          await pause();
          url = sameSeries(await provider.search(title, http), wanted)?.url;
          if (url != null) break;
        }
      }
      if (url == null) {
        found[provider.id] = SiteCopy(provider: provider.id, state: ElsewhereState.missing, checkedAt: clock());
        await watch?.succeeded(provider.id);
        continue;
      }
      await pause();
      final series = (await readSeries(provider, url, http, browser: browser)).series;
      found[provider.id] = _copyOf(series, clock());
      await watch?.succeeded(provider.id);
    } on ProviderOffline {
      rethrow;
    } on CloudflareChallenge catch (error) {
      found[provider.id] = blank.withState(ElsewhereState.gated, clock(), message: error.message);
    } on ProviderChanged catch (error) {
      await watch?.failed(provider.id, error);
      found[provider.id] = blank.withState(ElsewhereState.broken, clock(), message: error.message);
    } on ProviderError catch (error) {
      found[provider.id] = blank.withState(ElsewhereState.error, clock(), message: error.message);
    }
  }
  return Elsewhere(key: key, checkedAt: clock(), sites: found);
}

SiteCopy _copyOf(Series series, DateTime now) {
  final latest = latestChapterNumber([for (final chapter in series.chapters) chapter.title]) ??
      latestChapterNumber([for (final chapter in series.chapters) 'Chapter ${chapter.number}']);
  final last = series.chapters
      .where((chapter) => latest != null && (chapterNumber(chapter.title) ?? chapter.number) == latest)
      .firstOrNull;
  final date = last?.metadata['publishedAt'] ?? last?.metadata['date'] ?? series.metadata['updatedAt'];
  return SiteCopy(
    provider: series.provider,
    state: ElsewhereState.found,
    checkedAt: now,
    key: series.key,
    url: series.url,
    title: series.title,
    chapters: series.chapters.length,
    latest: latest,
    latestAt: switch (date) { final String text => text, [final String text, ...] => text, _ => null },
    releaseStatus: releaseStatus(series.metadata['releaseStatus'] ?? series.metadata['status']),
  );
}

/// Una passata sulla libreria in [store]: le serie da riguardare
/// ([elsewhereDue]), da quella vista meno di recente, al più [limit]. Con
/// [only] quelle sole, anche se non sono da riguardare. Le serie di [skip]
/// (quelle che l'utente non segue più) e quelle senza link o di un sito che
/// non c'è non si cercano. Ogni serie si scrive in [log] appena letta;
/// [cancelled] ferma la passata fra una serie e l'altra. Torna quante serie
/// ha letto. La rete che manca ([ProviderOffline]) la ferma come eccezione.
Future<int> sweepElsewhere({
  required ArchiveStore store,
  required ElsewhereLog log,
  required ProviderHttp Function(Provider provider) httpFor,
  List<Provider>? sites,
  PageBrowser? browser,
  HealthLog? health,
  Set<String> skip = const {},
  Set<String>? only,
  int limit = elsewherePerPass,
  Duration delay = const Duration(seconds: 2),
  DateTime Function() clock = DateTime.now,
  bool Function()? cancelled,
  void Function(int done, int total, String title)? progress,
}) async {
  final known = {for (final provider in sites ?? providers) provider.id};
  final previous = await log.load();
  final now = clock();
  final due = [
    for (final row in await libraryRows(store))
      if (row['key'] case final String key
          when row['source'] is String &&
              row['path'] is String &&
              known.contains(key.split(':').first) &&
              !skip.contains(key) &&
              (only == null
                  ? elsewhereDue(previous[key], now,
                      concluded: const {'completed', 'cancelled'}.contains(row['releaseStatus']))
                  : only.contains(key)))
        row,
  ];
  DateTime seen(Map<String, Object?> row) =>
      previous[row['key']]?.checkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  due.sort((a, b) => seen(a).compareTo(seen(b)));
  final pass = due.take(limit).toList();
  final watch = health == null ? null : SiteWatch(health);
  var done = 0;
  for (final row in pass) {
    if (cancelled?.call() ?? false) break;
    final key = row['key'] as String;
    final title = row['title'] as String? ?? '';
    progress?.call(done, pass.length, title);
    final series = await store.readJson(p.posix.join(row['path'] as String, 'series.json'));
    final alternative = series?['metadata'] is Map ? (series!['metadata'] as Map)['alternativeTitles'] : null;
    final result = await findElsewhere(
      key: key,
      titles: [title, if (series?['title'] case final String own) own, ...?(alternative as List?)?.whereType<String>()],
      httpFor: httpFor,
      sites: sites,
      browser: browser,
      health: health == null ? const {} : await health.load(),
      watch: watch,
      previous: previous[key],
      delay: delay,
      clock: clock,
    );
    await log.put(result);
    done++;
  }
  return done;
}
