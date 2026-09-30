/// Raccolte: l'equivalente delle playlist.
///
/// Quelle create a mano hanno nome, colore e un ordine scelto dall'utente;
/// accanto stanno quelle che l'app costruisce da sé e che non si modificano.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library_view.dart';
import '../format/reading.dart';
import '../l10n.dart';
import '../providers.dart';
import 'app_shell.dart';
import 'library_screen.dart';
import 'theme.dart';
import 'widgets/collection_sheet.dart';
import 'widgets/kit.dart';
import 'widgets/series_cover.dart';

IconData autoIcon(AutoCollection auto) => switch (auto) {
      AutoCollection.reading => LucideIcons.bookOpen,
      AutoCollection.fresh => LucideIcons.sparkles,
      AutoCollection.favorites => LucideIcons.heart,
      AutoCollection.planned => LucideIcons.clock,
      AutoCollection.finished => LucideIcons.checkCheck,
    };

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final all = ref.watch(librarySignalsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: navBarInset),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.collectionsTitle, style: KagamiType.display(30)),
                  ),
                  KButton(
                    label: context.l10n.collectionsNew,
                    icon: LucideIcons.plus,
                    height: 42,
                    onPressed: () => askForCollection(context, ref),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KSection(context.l10n.collectionsAutomatic),
                  KGroup(
                    children: [
                      for (final auto in AutoCollection.values)
                        _AutoTile(
                          auto: auto,
                          count: all.where(auto.matches).length,
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  KSection(context.l10n.collectionsYours),
                ],
              ),
            ),
            if (collections.isEmpty)
              KEmpty(
                icon: LucideIcons.listPlus,
                compact: true,
                title: context.l10n.collectionsNoneTitle,
                message: context.l10n.collectionsNoneMessage,
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                onReorderItem: (from, to) => ref
                    .read(readingProvider.notifier)
                    .reorderCollections(from, to),
                children: [
                  for (final collection in collections)
                    _CollectionTile(
                      key: ValueKey(collection.id),
                      collection: collection,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AutoTile extends ConsumerWidget {
  const _AutoTile({required this.auto, required this.count});

  final AutoCollection auto;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) => KTile(
        icon: autoIcon(auto),
        title: auto.label,
        trailing: Text(
          '$count',
          style: KagamiType.figure(14, color: context.tokens.muted),
        ),
        onTap: count == 0
            ? null
            : () {
                ref.read(libraryFilterProvider.notifier).showAuto(auto);
                ref.read(shellTabProvider.notifier).show(ShellTab.library);
              },
      );
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.collection, super.key});

  final Collection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: KCard(
          padding: EdgeInsets.zero,
          child: KTile(
            icon: LucideIcons.bookmark,
            tint: collection.color == null ? null : Color(collection.color!),
            title: collection.name,
            subtitle: context.l10n.collectionsSeriesCount(collection.seriesKeys.length),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CollectionScreen(collectionId: collection.id),
              ),
            ),
            trailing: IconButton(
              tooltip: context.l10n.collectionsEdit,
              onPressed: () => _menu(context, ref),
              icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
            ),
          ),
        ),
      );

  Future<void> _menu(BuildContext context, WidgetRef ref) =>
      showKagamiSheet<void>(
        context,
        title: collection.name,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KTile(
                icon: LucideIcons.pencil,
                title: context.l10n.collectionsRenameRecolor,
                onTap: () {
                  Navigator.of(context).pop();
                  askForCollection(
                    context,
                    ref,
                    id: collection.id,
                    name: collection.name,
                    color: collection.color,
                  );
                },
              ),
              KTile(
                icon: LucideIcons.trash2,
                title: context.l10n.collectionsDelete,
                tint: context.tokens.danger,
                onTap: () {
                  ref
                      .read(readingProvider.notifier)
                      .deleteCollection(collection.id);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
}

/// Una raccolta aperta: l'ordine è quello scelto, e si cambia trascinando.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({required this.collectionId, super.key});

  final String collectionId;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final collection = ref
        .watch(collectionsProvider)
        .firstWhereOrNull((row) => row.id == widget.collectionId);
    if (library == null || collection == null) {
      return Scaffold(
        body: Center(child: Text(context.l10n.collectionsNotFound)),
      );
    }
    final all = {
      for (final signals in ref.watch(librarySignalsProvider))
        signals.entry.key: signals,
    };
    // Una chiave senza serie è normale: la libreria può non aver ancora
    // sincronizzato ciò che un altro dispositivo ha messo in raccolta.
    final series = collection.seriesKeys
        .map((key) => all[key])
        .nonNulls
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            tooltip: _reordering
                ? context.l10n.collectionsDone
                : context.l10n.collectionsReorder,
            onPressed: series.isEmpty
                ? null
                : () => setState(() => _reordering = !_reordering),
            icon: Icon(
              _reordering ? LucideIcons.check : LucideIcons.arrowUpDown,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: series.isEmpty
          ? KEmpty(
              icon: LucideIcons.bookmark,
              title: context.l10n.collectionsEmptyTitle,
              message: context.l10n.collectionsEmptyMessage,
            )
          : _reordering
              ? _ReorderList(
                  collection: collection,
                  series: series,
                )
              : SeriesGrid(series: series),
    );
  }
}

class _ReorderList extends ConsumerWidget {
  const _ReorderList({
    required this.collection,
    required this.series,
  });

  final Collection collection;
  final List<SeriesSignals> series;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: series.length,
        onReorderItem: (from, to) =>
            ref.read(readingProvider.notifier).reorderCollection(
                  collection.id,
                  from,
                  to,
                ),
        itemBuilder: (context, position) {
          final signals = series[position];
          return Padding(
            key: ValueKey(signals.entry.key),
            padding: const EdgeInsets.only(bottom: 8),
            child: KCard(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 36,
                      height: 50,
                      child: CoverImage(
                        entry: signals.entry,
                        width: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      signals.entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KagamiType.title(14, weight: 600),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.collectionsRemoveFrom,
                    onPressed: () =>
                        ref.read(readingProvider.notifier).setSeriesInCollection(
                              collection.id,
                              signals.entry.key,
                              false,
                            ),
                    icon: const Icon(LucideIcons.circleMinus, size: 18),
                  ),
                  Icon(LucideIcons.gripVertical,
                      size: 18, color: context.tokens.muted),
                ],
              ),
            ),
          );
        },
      );
}
