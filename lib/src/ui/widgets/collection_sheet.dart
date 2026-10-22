/// In quali raccolte sta una serie. Una serie può starne in più di una.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n.dart';
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
          ? context.l10n.collectionSheetTitle
          : context.l10n.collectionSheetTitleMany(seriesKeys.length),
      scrollable: true,
      action: Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => askForCollection(context, ref),
          child: Text(context.l10n.collectionSheetNew),
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
      return KEmpty(
        icon: LucideIcons.listPlus,
        compact: true,
        title: context.l10n.collectionSheetEmptyTitle,
        message: context.l10n.collectionSheetEmptyMessage,
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
                subtitle: context.l10n.collectionSheetSeriesCount(collection.seriesKeys.length),
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

/// Fa scegliere una raccolta fra quelle che ci sono, «Nessuna raccolta» o
/// una nuova creata lì per lì, che vale come scelta. [current] è quella
/// segnata. Restituisce la scelta in un record, perché `null` è anche
/// «nessuna»; `null` se l'utente chiude senza scegliere.
Future<(String?,)?> pickCollection(BuildContext context, {required String? current}) {
  final l10n = context.l10n;
  return showKagamiSheet<(String?,)>(
    context,
    title: l10n.archiveImportCollection,
    scrollable: true,
    action: Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () async {
          final before = {for (final row in ref.read(collectionsProvider)) row.id};
          await askForCollection(context, ref);
          final created = ref.read(collectionsProvider).where((row) => !before.contains(row.id)).firstOrNull;
          if (created != null && context.mounted) Navigator.of(context).pop((created.id,));
        },
        child: Text(l10n.collectionSheetNew),
      ),
    ),
    builder: (context) => Consumer(
      builder: (context, ref, _) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          KTile(
            icon: LucideIcons.circleSlash,
            title: l10n.archiveImportCollectionNone,
            trailing: current == null ? const Icon(LucideIcons.check, size: 18) : null,
            onTap: () => Navigator.of(context).pop((null,)),
          ),
          for (final collection in ref.watch(collectionsProvider))
            KTile(
              icon: LucideIcons.bookmark,
              tint: collection.color == null ? null : Color(collection.color!),
              title: collection.name,
              trailing: current == collection.id ? const Icon(LucideIcons.check, size: 18) : null,
              onTap: () => Navigator.of(context).pop((collection.id,)),
            ),
        ],
      ),
    ),
  );
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
    title: id == null
        ? context.l10n.collectionSheetCreateTitle
        : context.l10n.collectionSheetEditTitle,
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
              decoration: InputDecoration(hintText: context.l10n.collectionSheetNameHint),
            ),
            const SizedBox(height: 22),
            KSection(context.l10n.collectionSheetColor),
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
              label: id == null
                  ? context.l10n.collectionSheetCreate
                  : context.l10n.collectionSheetSave,
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
