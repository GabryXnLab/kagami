/// «Su altri siti»: la serie sugli altri siti, dalla cache o da chi la cerca.
///
/// Il dato è ricavato e si rifà in un giorno (`packages/kagami_archive/lib/elsewhere.dart`),
/// quindi sta in un file di cache dell'app, non nel database né in MALF. La
/// scheda lo disegna subito dalla copia e poi, se è vecchio, lo rinfresca: dal
/// server collegato che sa farlo, altrimenti dal telefono per quella serie sola.
/// Un errore di rete lascia la copia: «non ho potuto chiedere» non è «non c'è».
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/elsewhere.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart' show ProviderError;
import 'package:kagami_archive/health.dart' show SiteWatch;
import 'package:kagami_archive/remote.dart';

import '../archive/page_browser.dart' show platformPageBrowser;
import '../format/malf.dart';
import '../providers.dart';

/// Quanti capitoli un sito è avanti (positivo) o indietro (negativo) rispetto
/// alla serie in uso: per numero dell'ultimo capitolo, non per conteggio,
/// perché un sito conta anche prologhi e avvisi. I numeri non numerici si
/// ignorano; `null` se manca uno dei due.
double? chaptersAhead(String? latest, Iterable<ChapterEntry> chapters) {
  final theirs = latest == null ? null : double.tryParse(latest.trim());
  if (theirs == null) return null;
  double? mine;
  for (final chapter in chapters) {
    final number = chapter.number == null ? null : double.tryParse(chapter.number!.trim());
    if (number != null && (mine == null || number > mine)) mine = number;
  }
  return mine == null ? null : theirs - mine;
}

/// Cosa si cerca: la serie [key], coi titoli con cui cercarla. Due richieste
/// sono la stessa se hanno la stessa chiave.
class ElsewhereTarget {
  const ElsewhereTarget(this.key, this.titles, {this.concluded = false});

  final String key;
  final List<String> titles;
  final bool concluded;

  @override
  bool operator ==(Object other) => other is ElsewhereTarget && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Chi rifà il dato di una serie, dato quello di prima.
typedef ElsewhereLookup = Future<Elsewhere?> Function(Elsewhere? previous);

/// Rinfresca [cached] se è da riguardare ([elsewhereDue]); un errore (rete,
/// sito, server) lascia la copia com'è.
Future<Elsewhere?> resolveElsewhere({
  required Elsewhere? cached,
  required ElsewhereLog log,
  required ElsewhereLookup lookup,
  bool concluded = false,
  DateTime Function() clock = DateTime.now,
}) async {
  if (!elsewhereDue(cached, clock(), concluded: concluded)) return cached;
  try {
    final fresh = await lookup(cached);
    if (fresh == null) return cached;
    await log.put(fresh);
    return fresh;
  } on ProviderError {
    return cached;
  } on ServerException {
    return cached;
  } on IOException {
    return cached;
  }
}

/// Il server cerca da sé: lo si avvisa e si rilegge a intervalli, finché il
/// risultato è più recente di [previous]. Scaduti i tentativi, `null`: il
/// risultato arriverà alla prossima apertura.
Future<Elsewhere?> lookViaServer({
  required String key,
  required Elsewhere? previous,
  required Future<void> Function() look,
  required Future<Elsewhere?> Function() read,
  int attempts = 6,
  Duration wait = const Duration(seconds: 5),
}) async {
  await look();
  for (var i = 0; i < attempts; i++) {
    await Future<void>.delayed(wait);
    final found = await read();
    if (found != null && (previous == null || found.checkedAt.isAfter(previous.checkedAt))) return found;
  }
  return null;
}

final elsewhereLogProvider = Provider<ElsewhereLog>(
  (ref) => ElsewhereLog(File('${ref.watch(appDirectoriesProvider).support}/elsewhere.json')),
);

/// Il dato di una serie e se lo si sta rifacendo.
class ElsewhereView {
  const ElsewhereView({this.data, this.busy = false});

  final Elsewhere? data;
  final bool busy;
}

/// Il server collegato che sa cercare «Su altri siti», o `null`: allora lo fa
/// il telefono. Con il telefono come motore non si chiede nemmeno al server.
final elsewhereServerProvider = FutureProvider<ServerLink?>((ref) async {
  if (ref.watch(archiveEngineProvider) != ArchiveEngine.server) return null;
  final link = ref.watch(serverLinkProvider).value;
  if (link == null) return null;
  final client = serverClient(ref, link);
  try {
    return (await client.info()).elsewhere ? link : null;
  } on ServerException {
    return null;
  } on IOException {
    return null;
  } finally {
    client.close();
  }
});

/// Chi cerca la serie [target] dato il dato di prima: il server o il telefono.
typedef ElsewhereSearch = Future<Elsewhere?> Function(ElsewhereTarget target, Elsewhere? previous);

final serverElsewhereProvider = Provider<ElsewhereSearch>((ref) {
  return (target, previous) async {
    final link = ref.read(elsewhereServerProvider).value;
    if (link == null) return null;
    final client = serverClient(ref, link);
    try {
      return await lookViaServer(
        key: target.key,
        previous: previous,
        look: () => client.lookElsewhere({target.key}),
        read: () async => (await client.elsewhere(keys: {target.key})).series[target.key],
      );
    } finally {
      client.close();
    }
  };
});

/// Il browser invisibile dell'app serve solo a leggere la pagina trovata: la
/// ricerca dei siti dietro la verifica vuole una WebView nell'albero, che qui
/// non c'è, e finisce come «verifica».
final phoneElsewhereProvider = Provider<ElsewhereSearch>((ref) {
  return (target, previous) async {
    final files = ref.read(archiveFilesProvider);
    final clients = <SiteHttp>[];
    try {
      return await findElsewhere(
        key: target.key,
        titles: target.titles,
        httpFor: (provider) {
          final http = SiteHttp(provider.allowedHost, publicOnly: !provider.builtIn);
          clients.add(http);
          return http;
        },
        browser: platformPageBrowser(),
        health: await files.health.load(),
        watch: SiteWatch(files.health),
        previous: previous,
      );
    } finally {
      for (final http in clients) {
        http.close();
      }
    }
  };
});

class ElsewhereNotifier extends AsyncNotifier<ElsewhereView> {
  ElsewhereNotifier(this.target);

  final ElsewhereTarget target;

  @override
  Future<ElsewhereView> build() async {
    final log = ref.read(elsewhereLogProvider);
    final cached = (await log.load())[target.key];
    final due = elsewhereDue(cached, DateTime.now(), concluded: target.concluded);
    if (due) unawaited(Future(() => _refresh(log, cached)));
    return ElsewhereView(data: cached, busy: due);
  }

  Future<void> _refresh(ElsewhereLog log, Elsewhere? cached) async {
    final link = await ref.read(elsewhereServerProvider.future);
    if (!ref.mounted) return;
    final fresh = await resolveElsewhere(
      cached: cached,
      log: log,
      concluded: target.concluded,
      lookup: (previous) => link == null
          ? ref.read(phoneElsewhereProvider)(target, previous)
          : ref.read(serverElsewhereProvider)(target, previous),
    );
    if (ref.mounted) state = AsyncData(ElsewhereView(data: fresh));
  }
}

final elsewhereProvider = AsyncNotifierProvider.autoDispose.family<ElsewhereNotifier, ElsewhereView, ElsewhereTarget>(
  ElsewhereNotifier.new,
);

/// Le serie in libreria di [site] dalla copia e, col server che sa cercare, dalla sua
/// risposta più recente. Senza server solo la copia: dal telefono non si
/// lanciano ricerche in massa.
final siteElsewhereProvider =
    FutureProvider.autoDispose.family<Map<String, Elsewhere>, String>((ref, site) async {
  final keys = {
    for (final signals in ref.watch(shownSignalsProvider))
      if (signals.entry.provider == site) signals.entry.key,
  };
  final log = ref.read(elsewhereLogProvider);
  final found = {...await log.load()}..removeWhere((key, _) => !keys.contains(key));
  final link = await ref.watch(elsewhereServerProvider.future);
  if (link == null || keys.isEmpty) return found;
  final client = serverClient(ref, link);
  try {
    final list = keys.toList();
    for (var i = 0; i < list.length; i += 200) {
      final answer = await client.elsewhere(keys: list.sublist(i, i + 200 > list.length ? list.length : i + 200).toSet());
      for (final MapEntry(:key, :value) in answer.series.entries) {
        final mine = found[key];
        if (mine == null || value.checkedAt.isAfter(mine.checkedAt)) {
          found[key] = value;
          await log.put(value);
        }
      }
    }
  } on ServerException {
    // Si resta con la copia.
  } on IOException {
    // Lo stesso, senza rete.
  } finally {
    client.close();
  }
  return found;
});
