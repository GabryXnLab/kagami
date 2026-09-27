/// In quali raccolte sta una serie. Una serie può starne in più di una.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers.dart';
import '../theme.dart';
import 'kit.dart';

/// Tavolozza delle raccolte: pochi colori scelti, perché servono a
/// distinguere a colpo d'occhio e non a decorare.
const List<int> collectionColors = [
  0xFFEF4444,
  0xFFF59E0B,
  0xFF22C55E,
  0xFF38BDF8,
  0xFF8B5CF6,
  0xFF8A8F98,
];

/// Con più chiavi il foglio agisce su tutte insieme: la casella è piena solo
/// se ci stanno già tutte, e un tocco le aggiunge o le toglie in blocco.
Future<void> showCollectionSheet(
  BuildContext context,
  List<String> seriesKeys,
) =>
    showKagamiSheet<void>(
      context,
      title: seriesKeys.length == 1
          ? 'Raccolte'
          : 'Raccolte di ${seriesKeys.length} serie',
      scrollable: true,
      action: Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => askForCollection(context, ref),
          child: const Text('Nuova'),
        ),
      ),
      builder: (context) => _CollectionSheet(seriesKeys: seriesKeys),
    );

class _CollectionSheet extends ConsumerWidget {
  const _CollectionSheet({required this.seriesKeys});

  final List<String> seriesKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final reading = ref.read(readingProvider.notifier);
    if (collections.isEmpty) {
      return const KEmpty(
        icon: LucideIcons.listPlus,
        compact: true,
        title: 'Nessuna raccolta',
        message: 'Servono a dare struttura a una libreria che cresce da sola.',
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      children: [
        for (final collection in collections)
          Builder(
            builder: (context) {
              final inside = seriesKeys.every(collection.seriesKeys.contains);
              return KTile(
                icon: LucideIcons.bookmark,
                tint: collection.color == null
                    ? null
                    : Color(collection.color!),
                title: collection.name,
                subtitle: '${collection.seriesKeys.length} serie',
                onTap: () async {
                  for (final key in seriesKeys) {
                    await reading.setSeriesInCollection(
                      collection.id,
                      key,
                      !inside,
                    );
                  }
                },
                trailing: Icon(
                  inside ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 20,
                  color: inside ? context.colors.primary : context.tokens.muted,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Chiede nome e colore di una raccolta. Con [id] la modifica invece di
/// crearla.
Future<void> askForCollection(
  BuildContext context,
  WidgetRef ref, {
  String? id,
  String? name,
  int? color,
}) async {
  final controller = TextEditingController(text: name ?? '');
  var chosen = color ?? collectionColors.first;
  final confirmed = await showKagamiSheet<bool>(
    context,
    title: id == null ? 'Nuova raccolta' : 'Modifica raccolta',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Nome'),
            ),
            const SizedBox(height: 22),
            const KSection('Colore'),
            Row(
              children: [
                for (final value in collectionColors)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: KPress(
                      onTap: () => setState(() => chosen = value),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color(value),
                          shape: BoxShape.circle,
                          border: chosen == value
                              ? Border.all(
                                  color: context.colors.onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            KButton(
              label: id == null ? 'Crea' : 'Salva',
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
  final text = controller.text.trim();
  controller.dispose();
  if (confirmed != true || text.isEmpty) return;
  final reading = ref.read(readingProvider.notifier);
  if (id == null) {
    await reading.createCollection(text, color: chosen);
  } else {
    await reading.editCollection(id, name: text, color: chosen);
  }
}
