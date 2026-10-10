/// Le serie in corso scaricate dall'app, e il controllo dei capitoli nuovi.
///
/// Porting di `mangaarchive/tracking.py`. Al download, se il sito non dice
/// che la serie è finita, i capitoli già a posto — archiviati o saltati per
/// scelta — si annotano qui; il controllo rilegge la serie e mette in coda
/// solo quelli comparsi dopo. Una serie che il sito dà per conclusa o
/// cancellata esce da sola, dopo aver messo in coda gli ultimi capitoli. Il
/// sito si ricava dal link, quindi vale per ogni provider.
///
/// Diversamente da `mangaarchive`, una serie in pausa o con uno stato che il
/// sito non scrive in modo riconoscibile resta seguita: lasciarla cadere
/// perché la pagina ha cambiato una parola faceva sparire le serie dal
/// controllo senza che nessuno se ne accorgesse.
///
/// Le serie scaricate «man mano» ([TrackedSeries.ahead]) restano seguite
/// anche concluse, finché l'utente non smette: il controllo mette in coda
/// solo i capitoli nuovi che l'app ha chiesto ([TrackedSeries.wanted]),
/// perché gli altri li chiede lei a mano a mano che si legge.
///
/// Le schede ([TrackedSeries.card], serie salvate senza scaricare capitoli)
/// si seguono senza scaricare: il controllo mette in coda un lavoro scheda
/// ([ArchiveJob.cardOnly]), che riscrive indici e riga di libreria con i
/// capitoli nuovi elencati e nessuna tavola. Al primo download vero della
/// serie la scheda diventa una serie seguita come le altre.
///
/// Qui stanno le serie scaricate da chi controlla, telefono o server; le
/// altre serie in corso della libreria le guarda [checkLibrary]. Le guarda
/// uno solo dei due, mai entrambi: vorrebbe dire scaricare due volte gli
/// stessi capitoli. È stato del controllo, non un indice MALF, e resta
/// nello spazio di chi controlla.
///
/// I siti dietro la verifica del browser si leggono con un [PageBrowser],
/// se chi controlla ne ha uno, e il lavoro porta con sé la pagina letta.
///
/// Il server può guardare anche tutta la libreria su Drive
/// ([checkLibrary]): ogni serie di `library.json`, chiunque l'abbia
/// scaricata — telefono, server, `mangaarchive`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'http.dart';
import 'jobs.dart';
import 'manual.dart';
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
    this.ahead,
    this.wanted = 0,
    this.card = false,
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
        ahead: (json['ahead'] as num?)?.toInt(),
        wanted: (json['wanted'] as num?)?.toInt() ?? 0,
        card: json['card'] == true,
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

  /// Scaricata «man mano»: quanti capitoli da leggere tenere pronti.
  final int? ahead;

  /// Quanti capitoli nuovi del sito l'app vorrebbe adesso, perché quelli
  /// che conosceva sono già tutti scaricati.
  final int wanted;

  /// Una scheda: i capitoli nuovi si elencano nell'indice, non si scaricano.
  /// [chapters] sono allora quelli già elencati.
  final bool card;

  String get key => '$provider:$id';

  TrackedSeries copyWith({DateTime? checkedAt, String? problem, bool clearProblem = false, int? wanted}) =>
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
        ahead: ahead,
        wanted: wanted ?? this.wanted,
        card: card,
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
        'ahead': ?ahead,
        if (wanted > 0) 'wanted': wanted,
        if (card) 'card': true,
      };
}

/// Una serie che il sito dà per finita: dopo, capitoli nuovi non ne arrivano.
bool _finished(Object? releaseStatus) => releaseStatus == 'completed' || releaseStatus == 'cancelled';

class CheckReport {
  int checked = 0;

  /// Le serie in cui si sono rimessi in coda capitoli che su Drive c'erano
  /// già ma che l'indice dava incompleti: il giro li salta e riscrive
  /// l'indice.
  final List<String> repaired = [];
  final List<String> queued = [];
  final List<String> removed = [];

  /// Fra le [queued], le schede: in coda c'è solo l'aggiornamento del loro
  /// indice, nessun capitolo da scaricare.
  final List<String> cards = [];
  final List<({String title, String error})> failed = [];

  /// Fra le [failed], quelle ferme alla verifica del sito: la può passare
  /// solo una persona, dall'app.
  final List<GatedSeries> gated = [];

  /// Aggiunge a questo il resoconto di [other], un altro pezzo dello stesso
  /// controllo.
  void absorb(CheckReport other) {
    checked += other.checked;
    repaired.addAll(other.repaired);
    queued.addAll(other.queued);
    removed.addAll(other.removed);
    cards.addAll(other.cards);
    failed.addAll(other.failed);
    gated.addAll(other.gated);
  }
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

  /// Annota la serie se non è finita, altrimenti la dimentica. [settled]
  /// sono i capitoli a posto: un capitolo tentato e fallito non ci entra,
  /// così il controllo lo ritenta. Con [ahead] la serie si scarica «man
  /// mano», e resta seguita comunque. Con [card] è un lavoro scheda.
  Future<void> record(
    Series series,
    ArchiveTarget target, {
    required List<String> settled,
    required Map<String, Object?> metadata,
    int? ahead,
    bool card = false,
  }) async {
    final entries = await load();
    final previous = entries.where((entry) => entry.key == series.key).firstOrNull;
    // Aggiornare la scheda di una serie che si scarica non la fa tornare
    // scheda, e non dà per scaricati i capitoli usciti nel frattempo.
    if (card && previous != null && !previous.card) return;
    final rest = [for (final entry in entries) if (entry.key != series.key) entry];
    final smart = card ? null : ahead ?? previous?.ahead;
    if (smart == null && _finished(metadata['releaseStatus'])) {
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
        // Il primo download dopo la scheda riparte da ciò che ha a posto
        // lui: i capitoli elencati dalla scheda non sono scaricati, e un
        // capitolo scelto e fallito va ritentato.
        chapters: {
          if (card || previous?.card != true) ...?previous?.chapters,
          ...settled,
        }.toList(),
        addedAt: previous?.addedAt ?? DateTime.now(),
        checkedAt: DateTime.now(),
        ahead: smart,
        wanted: previous?.wanted ?? 0,
        card: card,
      ),
    ]);
  }

  /// L'app chiede [count] capitoli nuovi per una serie scaricata «man
  /// mano»: il controllo li mette in coda appena il sito li ha.
  Future<void> want(String key, int count) async {
    final entries = await load();
    final entry = entries.where((entry) => entry.key == key).firstOrNull;
    if (entry == null || entry.ahead == null || entry.wanted == count) return;
    await _update(entry.copyWith(wanted: count));
  }

  /// Rilegge le serie e mette in coda i capitoli nuovi. Un errore su una
  /// serie non ferma le altre: resta annotata, e si riprova al controllo
  /// seguente. Con [only] si guardano solo quelle serie; quelle in [skip]
  /// (le serie che l'utente ha smesso di seguire) mai.
  Future<CheckReport> check(
    ArchiveFiles files,
    ProviderHttp Function(Provider provider) httpFor, {
    PageBrowser? browser,
    bool Function()? cancelled,
    Set<String>? only,
    Set<String> skip = const {},
  }) async {
    final report = CheckReport();
    if (await files.delegated()) return report;
    for (final entry in await load()) {
      if (cancelled?.call() ?? false) break;
      if (only != null && !only.contains(entry.key)) continue;
      if (skip.contains(entry.key)) continue;
      final Series series;
      final Uint8List? page;
      try {
        final provider = selectProvider(entry.url);
        (:series, :page) = await readSeries(provider, entry.url, httpFor(provider), browser: browser);
      } on ProviderOffline {
        rethrow;
      } on ProviderError catch (error) {
        final message = error is CloudflareChallenge
            ? 'Il sito chiede la verifica: apri la serie da «Scarica un manga».'
            : '$error';
        report.failed.add((title: entry.title, error: message));
        if (error is CloudflareChallenge) report.gated.add(GatedSeries(key: entry.key, title: entry.title, url: entry.url));
        await _update(entry.copyWith(checkedAt: DateTime.now(), problem: message));
        continue;
      }
      report.checked++;
      final metadata = normalizeMetadata(series.metadata);
      final known = entry.chapters.toSet();
      final fresh = [for (final chapter in series.chapters) if (!known.contains(chapter.id)) chapter.id];
      // L'ultimo capitolo esce spesso proprio quando il sito scrive
      // «concluso»: si mette in coda prima di smettere di seguire la serie.
      if (entry.card) {
        if (fresh.isNotEmpty) {
          final id = 'check-${entry.key}-${DateTime.now().millisecondsSinceEpoch}';
          await files.enqueue(ArchiveJob(
            id: id,
            url: entry.url,
            title: series.title,
            target: entry.target,
            ids: const {},
            automatic: true,
            snapshot: await files.saveSnapshot(id, page),
          ));
          report.queued.add(series.title);
          report.cards.add(series.title);
        }
        if (_finished(metadata['releaseStatus'])) {
          await forget(entry.key);
          report.removed.add(entry.title);
        } else {
          await _update(entry.copyWith(checkedAt: DateTime.now(), clearProblem: true));
        }
        continue;
      }
      final queued = entry.ahead == null ? fresh : fresh.take(entry.wanted).toList();
      if (queued.isNotEmpty) {
        final id = 'check-${entry.key}-${DateTime.now().millisecondsSinceEpoch}';
        await files.enqueue(ArchiveJob(
          id: id,
          url: entry.url,
          title: series.title,
          target: entry.target,
          ids: queued.toSet(),
          automatic: true,
          ahead: entry.ahead,
          snapshot: await files.saveSnapshot(id, page),
        ));
        report.queued.add(series.title);
      }
      if (entry.ahead == null && _finished(metadata['releaseStatus'])) {
        await forget(entry.key);
        report.removed.add(entry.title);
        continue;
      }
      await _update(entry.copyWith(
        checkedAt: DateTime.now(),
        clearProblem: true,
        wanted: entry.wanted - (entry.ahead == null ? 0 : queued.length),
      ));
    }
    return report;
  }

  Future<void> _update(TrackedSeries updated) async {
    final entries = await load();
    await _save([for (final entry in entries) entry.key == updated.key ? updated : entry]);
  }
}

/// Il controllo di tutte le serie della libreria su Drive, anche di quelle
/// che il server non ha scaricato.
///
/// Per ogni riga di `library.json` si legge l'`index.json` della serie: i
/// capitoli nuovi sono quelli del sito che l'indice non elenca. Non quelli
/// non archiviati: chi ha scaricato dal capitolo 16 in poi ha i precedenti
/// nell'indice, non scaricati per scelta, e non deve ritrovarseli in coda.
/// Una serie conclusa non si chiede nemmeno al sito. Un capitolo che l'indice
/// dà a metà va in coda lo stesso, qualunque sia lo stato della serie: se su
/// Drive è intero il giro lo salta e riscrive l'indice, se no lo completa.
///
/// Una scheda (nessun capitolo archiviato) non scarica i capitoli nuovi: va
/// in coda il suo aggiornamento ([ArchiveJob.cardOnly]), che li elenca
/// nell'indice. Le schede manuali ([manualProvider]) non hanno un sito da
/// rileggere e si saltano.
///
/// Si saltano le serie in [skip] (quelle che segue già [Tracking] e quelle
/// che l'utente ha smesso di seguire), quelle già in coda — un lavoro nuovo
/// sullo stesso link prenderebbe il posto di quello dell'utente — e, senza
/// un [browser], quelle dei siti dietro la verifica del browser. Con [only]
/// si guardano solo quelle serie.
Future<CheckReport> checkLibrary({
  required ArchiveFiles files,
  required ArchiveStore store,
  required ArchiveTarget target,
  required ProviderHttp Function(Provider provider) httpFor,
  PageBrowser? browser,
  Set<String> skip = const {},
  Set<String>? only,
  bool Function()? cancelled,
  Duration pause = const Duration(seconds: 1),
}) async {
  final report = CheckReport();
  final library = await store.readJson(libraryFile);
  final queued = {for (final job in await files.jobs()) job.url};
  var first = true;
  for (final row in (library?['series'] as List? ?? const []).whereType<Map<String, Object?>>()) {
    if (cancelled?.call() ?? false) break;
    final key = row['key'];
    final path = row['path'];
    final url = row['source'];
    if (key is! String || path is! String || url is! String) continue;
    if (row['provider'] == manualProvider) continue;
    if (skip.contains(key) || queued.contains(url)) continue;
    if (only != null && !only.contains(key)) continue;
    final Provider provider;
    try {
      provider = selectProvider(url);
    } on ProviderError {
      continue;
    }
    if (provider.needsBrowser && browser == null) continue;
    final title = row['title'] as String? ?? key;
    final index = await store.readJson(p.posix.join(path, seriesIndexName));
    final entries = (index?['chapters'] as List? ?? const []).whereType<Map<String, Object?>>().toList();
    if (entries.isEmpty) continue;
    final known = {for (final entry in entries) entry['id']};
    final card = !entries.any((entry) => entry['archived'] == true);
    final halfway = {
      for (final entry in entries)
        if (entry['archived'] == true && (entry['complete'] != true || entry['pageCount'] == 0))
          entry['id'] as String,
    };
    final status = index?['releaseStatus'] ?? row['releaseStatus'];
    var fresh = <String>[];
    Uint8List? page;
    if (status != 'completed' && status != 'cancelled') {
      if (!first && pause > Duration.zero) await Future<void>.delayed(pause);
      first = false;
      try {
        final Series series;
        (:series, :page) = await readSeries(provider, url, httpFor(provider), browser: browser);
        fresh = [for (final chapter in series.chapters) if (!known.contains(chapter.id)) chapter.id];
        report.checked++;
      } on ProviderOffline {
        rethrow;
      } on ProviderError catch (error) {
        report.failed.add((title: title, error: '$error'));
        if (error is CloudflareChallenge) report.gated.add(GatedSeries(key: key, title: title, url: url));
        continue;
      }
    }
    if (fresh.isEmpty && halfway.isEmpty) continue;
    final id = 'library-$key-${DateTime.now().millisecondsSinceEpoch}';
    await files.enqueue(ArchiveJob(
      id: id,
      url: url,
      title: title,
      target: target,
      ids: card ? const {} : {...fresh, ...halfway},
      automatic: true,
      snapshot: await files.saveSnapshot(id, page),
    ));
    if (fresh.isNotEmpty) report.queued.add(title);
    if (card) report.cards.add(title);
    if (halfway.isNotEmpty) report.repaired.add(title);
  }
  return report;
}
