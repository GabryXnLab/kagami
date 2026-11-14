/// «Archivia nel mio Drive» sulla scheda di una serie che si legge solo da una
/// libreria condivisa (FASE-5b §3, F5.15): accoda nel flusso «Scarica un
/// manga» il link che l'indice della serie porta, perciò la chiave dei dati
/// personali resta la stessa per costruzione. I siti di una libreria altrui
/// non si installano da soli: senza il sito il pulsante è spento e dice perché.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/drive_library.dart';
import '../data/library.dart';
import '../l10n.dart';
import 'widgets/kit.dart';

enum ArchiveOwnOffer { none, ready, siteMissing }

/// Solo da condivisione: ogni scaffale è un Drive altrui. Senza scaffali o con
/// anche solo uno del telefono, del mio Drive o di un NAS non si offre.
bool onlyFromSharedDrives(Iterable<LibraryShelf> holders) =>
    holders.isNotEmpty && holders.every((shelf) => shelf is DriveRepository && shelf.origin == LibraryOrigin.remote);

ArchiveOwnOffer archiveOwnOffer(
  Iterable<LibraryShelf> holders,
  String? source,
  bool Function(String link) knownSite,
) {
  if (source == null || !onlyFromSharedDrives(holders)) return ArchiveOwnOffer.none;
  return knownSite(source) ? ArchiveOwnOffer.ready : ArchiveOwnOffer.siteMissing;
}

class ArchiveOwnChip extends StatelessWidget {
  const ArchiveOwnChip({required this.offer, required this.busy, required this.onArchive, super.key});

  final ArchiveOwnOffer offer;
  final bool busy;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    if (offer == ArchiveOwnOffer.none) return const SizedBox.shrink();
    final ready = offer == ArchiveOwnOffer.ready;
    final chip = KChip(
      label: context.l10n.seriesArchiveOwn,
      icon: LucideIcons.hardDriveUpload,
      onTap: ready && !busy ? onArchive : null,
    );
    if (ready) return chip;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chip,
        const SizedBox(height: 4),
        Text(context.l10n.seriesArchiveOwnSiteMissing, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
