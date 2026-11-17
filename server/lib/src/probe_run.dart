/// Il giro della sentinella su un elenco di siti, con la cassetta del guasto
/// (`probe --capture`). Il comando in `bin/` ci aggiunge solo gli argomenti.
library;

import 'dart:io';

import 'package:kagami_archive/cassette.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/probe.dart';
import 'package:kagami_archive/providers.dart';
import 'package:path/path.dart' as p;

/// Prova ogni sito di [sites]. Con [capture], per ogni sito non `ok` salva
/// in `<capture>/<id>/<data>-guasto/` ciò che il sito ha risposto in quel giro.
Future<List<SiteProbe>> probeSites(
  List<Provider> sites,
  Map<String, List<Canary>> canaries,
  ProviderHttp Function(Provider) httpFor, {
  Directory? capture,
  DateTime? now,
  ImageFetch? fetchImage,
  void Function(SiteProbe)? onResult,
}) async {
  final results = <SiteProbe>[];
  for (final provider in sites) {
    RecordingHttp? recorder;
    final result = await probeSite(provider, canaries[provider.id], (provider) {
      final inner = httpFor(provider);
      return capture == null ? inner : recorder = RecordingHttp(inner);
    }, fetchImage: fetchImage);
    if (capture != null && result.failed && recorder != null) {
      final day = (now ?? DateTime.now()).toUtc().toIso8601String().substring(0, 10);
      recorder!.save(Directory(p.join(capture.path, provider.id, '$day-guasto')));
    }
    results.add(result);
    onResult?.call(result);
  }
  return results;
}

/// `probe --layers all`: al posto di ogni sito del registro i suoi strati
/// ([siteLayers]: catalogo e incluso), da provare uno per uno; un sito con un
/// solo strato resta com'è.
List<Provider> probeLayers(List<Provider> sites) => [
      for (final site in sites)
        ...switch (siteLayers(site.id)) {
          final layers when layers.isNotEmpty => layers,
          _ => [site],
        },
    ];
