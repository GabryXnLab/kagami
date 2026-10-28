/// Cambi d'identità di una serie (`docs/malf.md`, «Cambi d'identità e
/// riparazione»): chi archivia ha adottato una chiave nuova e ricorda le
/// vecchie in `formerKeys`; i dati personali le seguono, una volta sola.
library;

import 'package:kagami_archive/repair.dart' show adoptCopy;
import 'package:kagami_archive/stores.dart' show ArchiveStore;

import '../format/malf.dart';
import 'library_repository.dart';

/// L'id nuovo di ogni id vecchio dei capitoli di [index].
Map<String, String> formerChapterIds(SeriesIndex index) {
  final result = <String, String>{};
  for (final chapter in index.chapters) {
    for (final old in chapter.formerIds) {
      if (old != chapter.id) result.putIfAbsent(old, () => chapter.id);
    }
  }
  return result;
}

/// Sposta i dati di ogni chiave vecchia di [series] sulla nuova.
///
/// Una chiave senza dati non si tocca e non fa leggere l'indice (che può
/// stare su Drive): è ciò che rende il secondo giro un niente. Se l'indice
/// non si può leggere ora, la serie resta com'è e si riprova al giro dopo:
/// «non ho potuto chiedere» non è «non ci sono capitoli da tradurre».
/// Restituisce quante serie ha spostato.
Future<int> adoptFormerKeys({
  required Iterable<SeriesEntry> series,
  required Future<Set<String>> Function() keysWithData,
  required Future<SeriesIndex?> Function(SeriesEntry entry) loadIndex,
  required Future<void> Function(String from, String to, Map<String, String> chapters) move,
}) async {
  final adopting = [for (final entry in series) if (entry.formerKeys.isNotEmpty) entry];
  if (adopting.isEmpty) return 0;
  final present = await keysWithData();
  var moved = 0;
  for (final entry in adopting) {
    final pending = [for (final key in entry.formerKeys) if (key != entry.key && present.contains(key)) key];
    if (pending.isEmpty) continue;
    final SeriesIndex? index;
    try {
      index = await loadIndex(entry);
    } on Exception {
      continue;
    }
    if (index == null) continue;
    final chapters = formerChapterIds(index);
    for (final key in pending) {
      await move(key, entry.key, chapters);
    }
    moved++;
  }
  return moved;
}

/// Porta le copie scaricate sul telefono alla serie adottata: per ogni serie
/// di [series] con `formerKeys`, la copia in [phone] che ha una di quelle
/// chiavi prende cartelle, id e riga nuovi (`adoptCopy`), così i capitoli
/// già scaricati restano scaricati. [fresh] dà il `series.json` riparato di
/// Drive; se non si può leggere ora, la copia resta com'è e si riprova.
/// Restituisce quante copie ha adottato.
Future<int> adoptDownloadedCopies({
  required Iterable<SeriesEntry> series,
  required LibraryRepository phone,
  required ArchiveStore Function() storeOf,
  required Future<Map<String, Object?>?> Function(SeriesEntry entry) fresh,
}) async {
  final adopting = [for (final entry in series) if (entry.formerKeys.isNotEmpty) entry];
  if (adopting.isEmpty) return 0;
  final copies = await phone.downloadedSeries();
  var adopted = 0;
  for (final entry in adopting) {
    for (final copy in copies) {
      if (copy.key == entry.key || !entry.formerKeys.contains(copy.key)) continue;
      final manifest = await fresh(entry);
      if (manifest == null) continue;
      try {
        await adoptCopy(store: storeOf(), path: copy.path, fresh: manifest);
        adopted++;
      } on Exception {
        continue;
      }
    }
  }
  return adopted;
}
