/// Da dove arriva una serie: telefono, Drive, o un po' e un po'.
///
/// L'icona compare solo quando Drive c'è. Senza, tutto è sul telefono e
/// dirlo su ogni copertina sarebbe rumore: la griglia resta quella di sempre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/library.dart';
import '../../providers.dart';

const Map<SeriesPlace, String> placeLabels = {
  SeriesPlace.local: 'Sul telefono',
  SeriesPlace.drive: 'Su Drive',
  SeriesPlace.mixed: 'Sul telefono, e altri capitoli su Drive',
};

List<IconData> placeIcons(SeriesPlace place) => switch (place) {
      SeriesPlace.local => const [LucideIcons.smartphone],
      SeriesPlace.drive => const [LucideIcons.cloud],
      SeriesPlace.mixed => const [LucideIcons.smartphone, LucideIcons.cloud],
    };

/// L'icona sopra la copertina.
class OriginBadge extends ConsumerWidget {
  const OriginBadge({required this.seriesKey, this.size = 12, super.key});

  final String seriesKey;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(seriesPlaceProvider(seriesKey));
    final drive = ref.watch(libraryProvider.select((l) => l?.hasDrive ?? false));
    if (!drive || place == null) return const SizedBox.shrink();
    return Semantics(
      label: placeLabels[place],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.45, vertical: size * 0.35),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(size),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (position, icon) in placeIcons(place).indexed) ...[
              if (position > 0) SizedBox(width: size * 0.3),
              Icon(icon, size: size, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}
