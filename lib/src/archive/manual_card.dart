/// Salvare una scheda manuale — un manga che nessun sito di Kagami sa
/// leggere — nella libreria e nei dati personali, senza interfaccia: lo usano
/// il modulo di «Scarica un manga» e l'import di tanti link.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/manual.dart';
import 'package:kagami_archive/stores.dart';

import '../format/malf.dart';
import '../format/reading.dart';
import '../providers.dart' show Reading;

/// Ciò che si sa di una scheda manuale.
class ManualCard {
  const ManualCard({
    required this.title,
    this.link,
    this.coverUrl,
    this.cover,
    this.id,
    this.reached,
    this.status = ShelfStatus.none,
    this.rating,
    this.notes = '',
    this.favorite = false,
  });

  final String title;

  /// Il link generale alla pagina della serie; senza, la scheda ha un id a
  /// caso (o [id]).
  final String? link;

  /// La copertina da scaricare, o già scaricata in [cover].
  final String? coverUrl;
  final Uint8List? cover;

  /// L'id di una scheda senza link già scritta, per riscriverla.
  final String? id;

  /// Il numero dell'ultimo capitolo letto, come lo scrive l'autore.
  final String? reached;
  final ShelfStatus status;
  final int? rating;
  final String notes;
  final bool favorite;
}

/// Scrive [card] in [store] e poi lo stato dell'utente in [reading]. Con lo
/// stesso link riscrive la stessa scheda. Lancia gli errori dello store
/// (`DriveException`, `ProviderError`): chi chiama li dice.
///
/// Lo stato si scrive dopo la libreria: se questa fallisce, la serie non
/// resta nei dati personali senza una scheda.
Future<ManualSeries> saveManualCard(
  ArchiveStore store,
  Reading reading,
  ManualCard card, {
  required Directory scratch,
  ImageTools images = const NoImageTools(),
}) async {
  final written = await writeManualSeries(
    store,
    title: card.title.trim(),
    scratch: scratch,
    link: card.link,
    id: card.id,
    cover: card.cover,
    coverUrl: card.coverUrl,
    images: images,
  );
  await reading.saveCard(
    written.key,
    status: card.status == ShelfStatus.none ? null : card.status,
    notes: card.notes.trim(),
    favorite: card.favorite,
    reachedChapter: card.reached,
  );
  await reading.setRating(written.key, card.rating);
  return written;
}

/// La serie della libreria che ha già [link] come link generale — una scheda
/// manuale o una serie di un sito —, se c'è.
SeriesEntry? entryForLink(LibraryIndex index, String link) {
  final wanted = normalizeLink(link);
  final manual = manualSeriesKey(link);
  for (final entry in index.series) {
    if (entry.key == manual) return entry;
    final source = entry.source;
    if (source != null && normalizeLink(source) == wanted) return entry;
  }
  return null;
}
