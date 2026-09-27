/// Le serie in corso scaricate dall'app, e il controllo dei capitoli nuovi.
///
/// Porting di `mangaarchive/tracking.py`. Al download, se il sito dice che
/// la serie è `ongoing`, i capitoli già a posto — archiviati o saltati per
/// scelta — si annotano qui; il controllo rilegge la serie e mette in coda
/// solo quelli comparsi dopo. Una serie che il sito dà per conclusa esce da
/// sola. Il sito si ricava dal link, quindi vale per ogni provider.
///
/// Si seguono solo le serie scaricate dall'app: quelle del server le segue
/// il suo timer, e seguirle da tutt'e due vorrebbe dire scaricare due volte
/// gli stessi capitoli. È stato del controllo, non un indice MALF, e resta
/// nello spazio dell'app.
library;

import 'dart:convert';
import 'dart:io';

import 'http.dart';
import 'jobs.dart';
import 'model.dart';
import 'providers.dart';
import 'stores.dart';

class TrackedSeries {
  const TrackedSeries({
    required this.provider,
    required this.id,
    required this.title,
    required this.url,
    required this.target,
    required this.chapters,
    required this.addedAt,
    this.checkedAt,
    this.problem,
  });

  factory TrackedSeries.fromJson(Map<String, Object?> json) => TrackedSeries(
        provider: json['provider'] as String,
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        url: json['url'] as String,
        target: ArchiveTarget.fromJson(json['target'] as Map<String, Object?>),
        chapters: (json['chapters'] as List? ?? const []).whereType<String>().toList(),
        addedAt: DateTime.tryParse('${json['addedAt']}') ?? DateTime.now(),
        checkedAt: DateTime.tryParse('${json['checkedAt']}'),
        problem: json['problem'] as String?,
      );

  final String provider;
  final String id;
  final String title;
  final String url;
  final ArchiveTarget target;

  /// I capitoli da non riscaricare da soli.
  final List<String> chapters;
  final DateTime addedAt;
  final DateTime? checkedAt;

  /// Perché l'ultimo controllo non è riuscito, se non è riuscito.
  final String? problem;

  String get key => '$provider:$id';

  TrackedSeries copyWith({DateTime? checkedAt, String? problem, bool clearProblem = false}) =>
      TrackedSeries(
        provider: provider,
        id: id,
        title: title,
        url: url,
        target: target,
        chapters: chapters,
        addedAt: addedAt,
        checkedAt: checkedAt ?? this.checkedAt,
        problem: clearProblem ? null : problem ?? this.problem,
      );

  Map<String, Object?> toJson() => {
        'provider': provider,
        'id': id,
        'title': title,
        'url': url,
        'target': target.toJson(),
        'chapters': chapters,
        'addedAt': addedAt.toIso8601String(),
        'checkedAt': ?checkedAt?.toIso8601String(),
        'problem': ?problem,
      };
}

class CheckReport {
  int checked = 0;
  final List<String> queued = [];
  final List<String> removed = [];
  final List<({String title, String error})> failed = [];
}

class Tracking {
  Tracking(this.file);

  final File file;

  Future<List<TrackedSeries>> load() async => [
        for (final row in ((await readJsonFile(file))?['series'] as List? ?? const [])
            .whereType<Map<String, Object?>>())
          if (row['url'] is String && row['provider'] is String && row['target'] is Map)
            TrackedSeries.fromJson(row),
      ];

  Future<void> _save(List<TrackedSeries> entries) => writeAtomically(
        file,
        utf8.encode(jsonEncode({'schemaVersion': 1, 'series': [for (final entry in entries) entry.toJson()]})),
      );

  Future<void> forget(String key) async {
    final entries = await load();
    await _save([for (final entry in entries) if (entry.key != key) entry]);
  }

  /// Annota la serie se è in corso, altrimenti la dimentica. [settled] sono
  /// i capitoli a posto: un capitolo tentato e fallito non ci entra, così il
  /// controllo lo ritenta.
  Future<void> record(
    Series series,
    ArchiveTarget target, {
    required List<String> settled,
    required Map<String, Object?> metadata,
  }) async {
    final entries = await load();
    final previous = entries.where((entry) => entry.key == series.key).firstOrNull;
    final rest = [for (final entry in entries) if (entry.key != series.key) entry];
    if (metadata['releaseStatus'] != 'ongoing') {
      if (previous != null) await _save(rest);
      return;
    }
    await _save([
      ...rest,
      TrackedSeries(
        provider: series.provider,
        id: series.id,
        title: series.title,
        url: series.url,
        target: target,
        chapters: {...?previous?.chapters, ...settled}.toList(),
        addedAt: previous?.addedAt ?? DateTime.now(),
        checkedAt: DateTime.now(),
      ),
    ]);
  }

  /// Rilegge le serie e mette in coda i capitoli nuovi. Un errore su una
  /// serie non ferma le altre: resta annotata, e si riprova al controllo
  /// seguente.
  Future<CheckReport> check(
    ArchiveFiles files,
    ProviderHttp Function(Provider provider) httpFor, {
    bool Function()? cancelled,
  }) async {
    final report = CheckReport();
    for (final entry in await load()) {
      if (cancelled?.call() ?? false) break;
      final Series series;
      try {
        final provider = selectProvider(entry.url);
        series = await provider.fetchSeries(entry.url, httpFor(provider));
      } on ProviderOffline {
        rethrow;
      } on ProviderError catch (error) {
        final message = error is CloudflareChallenge
            ? 'Il sito chiede la verifica: apri la serie da «Scarica un manga».'
            : '$error';
        report.failed.add((title: entry.title, error: message));
        await _update(entry.copyWith(checkedAt: DateTime.now(), problem: message));
        continue;
      }
      report.checked++;
      final metadata = normalizeMetadata(series.metadata);
      if (metadata['releaseStatus'] != 'ongoing') {
        await forget(entry.key);
        report.removed.add(entry.title);
        continue;
      }
      final known = entry.chapters.toSet();
      final fresh = [for (final chapter in series.chapters) if (!known.contains(chapter.id)) chapter.id];
      if (fresh.isEmpty) {
        await _update(entry.copyWith(checkedAt: DateTime.now(), clearProblem: true));
        continue;
      }
      await files.enqueue(ArchiveJob(
        id: 'check-${entry.key}-${DateTime.now().millisecondsSinceEpoch}',
        url: entry.url,
        title: series.title,
        target: entry.target,
        ids: fresh.toSet(),
        automatic: true,
      ));
      await _update(entry.copyWith(checkedAt: DateTime.now(), clearProblem: true));
      report.queued.add(series.title);
    }
    return report;
  }

  Future<void> _update(TrackedSeries updated) async {
    final entries = await load();
    await _save([for (final entry in entries) entry.key == updated.key ? updated : entry]);
  }
}
