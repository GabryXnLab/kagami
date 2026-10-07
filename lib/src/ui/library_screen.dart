/// La libreria: griglia, ricerca, filtri, ordinamenti e raccolte automatiche.
///
/// La ricerca sta sopra la griglia e non è una destinazione a sé: cercare è un
/// modo di guardare la libreria, non un posto dove andare.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library_view.dart';
import '../format/reading.dart';
import '../l10n.dart';
import '../providers.dart';
import 'app_shell.dart';
import 'series_screen.dart';
import 'setup_screen.dart';
import 'theme.dart';
import 'widgets/collection_sheet.dart';
import 'drive_ui.dart';
import 'widgets/kit.dart';
import 'widgets/remove_sheet.dart';
import 'widgets/origin.dart';
import 'widgets/series_cover.dart';

/// Apre la scheda di una serie. Sta qui perché ci arrivano tutte le
/// destinazioni, non solo la griglia.
void openSeries(BuildContext context, String seriesKey) =>
    Navigator.of(context).push(seriesRoute(seriesKey));

/// La scheda sale e compare sopra la libreria, che resta dov'è.
///
/// La transizione di sistema fa scorrere e sfumare anche la pagina sotto:
/// sotto c'è una griglia di copertine, e ridisegnarla sfumata a ogni
/// fotogramma, insieme alla scheda e al volo della copertina, era lo scatto
/// all'apertura e alla chiusura. Qui si muove solo la scheda.
Route<void> seriesRoute(String seriesKey) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => SeriesScreen(seriesKey: seriesKey),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            // La scheda si registra una volta e si ricompone: durante la
            // transizione cambia solo l'opacità, non il contenuto.
            child: RepaintBoundary(child: child),
          ),
        );
      },
    );

/// Griglia di copertine: è il widget che ogni destinazione riusa.
///
/// Con [selectable] il tocco lungo apre la selezione multipla e il tocco
/// singolo la estende: è il gesto con cui si mette a posto mezza libreria
/// senza aprire mezza libreria.
class SeriesGrid extends ConsumerWidget {
  const SeriesGrid({
    required this.series,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 24),
    this.display = LibraryDisplay.comfortable,
    this.selectable = false,
    this.controller,
    super.key,
  });

  final List<SeriesSignals> series;
  final EdgeInsets padding;
  final LibraryDisplay display;
  final bool selectable;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection =
        selectable ? ref.watch(selectionProvider) : const <String>{};

    void handleTap(String key) {
      if (selection.isEmpty) {
        openSeries(context, key);
      } else {
        ref.read(selectionProvider.notifier).toggle(key);
      }
    }

    void handleLongPress(String key) {
      if (selectable) {
        ref.read(selectionProvider.notifier).toggle(key);
      } else {
        showCollectionSheet(context, [key]);
      }
    }

    if (display.isGrid) {
      return GridView.builder(
        controller: controller,
        padding: padding,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: display == LibraryDisplay.compact ? 116 : 170,
          childAspectRatio: display == LibraryDisplay.compact ? 0.56 : 0.52,
          crossAxisSpacing: 12,
          mainAxisSpacing: 18,
        ),
        itemCount: series.length,
        itemBuilder: (context, position) => SeriesCover(
          signals: series[position],
          selected: selection.contains(series[position].entry.key),
          onTap: () => handleTap(series[position].entry.key),
          onLongPress: () => handleLongPress(series[position].entry.key),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: series.length,
      itemBuilder: (context, position) => _SeriesRow(
        signals: series[position],
        detailed: display == LibraryDisplay.detailed,
        selected: selection.contains(series[position].entry.key),
        onTap: () => handleTap(series[position].entry.key),
        onLongPress: () => handleLongPress(series[position].entry.key),
      ),
    );
  }
}

/// Una riga d'elenco: la stessa serie della griglia, ma con i numeri scritti
/// invece che accennati.
class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    required this.signals,
    required this.detailed,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final SeriesSignals signals;
  final bool detailed;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final entry = signals.entry;
    final l10n = context.l10n;
    final people = signals.people.take(2).join(', ');
    final width = detailed ? 54.0 : 40.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KPress(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.18)
                : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: width,
                  height: width * 1.42,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverImage(entry: entry, width: width),
                      if (signals.isNew)
                        Positioned(
                          top: 3,
                          left: 3,
                          child: NewChaptersDot(
                            count: signals.newChapters,
                            size: 16,
                          ),
                        ),
                      Positioned(
                        left: 3,
                        bottom: 3,
                        child: OriginBadge(seriesKey: entry.key, size: 9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KagamiType.title(14.5, weight: 600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        l10n.libraryRowChapters(entry.archivedChapterCount),
                        if (signals.hasUnread)
                          l10n.libraryRowUnread(signals.unreadCount),
                        if (detailed && people.isNotEmpty) people,
                        if (detailed) releaseLabels[entry.releaseStatus]!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KagamiType.label(size: 11.5, color: muted),
                    ),
                    if (detailed && signals.fraction > 0) ...[
                      const SizedBox(height: 8),
                      KProgress(value: signals.fraction, height: 4),
                    ],
                  ],
                ),
              ),
              if (signals.state.rating != null) ...[
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.star,
                        size: 13, color: context.tokens.warning),
                    const SizedBox(width: 4),
                    Text(
                      '${signals.state.rating}',
                      style: KagamiType.figure(13, color: scheme.onSurface),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final index = ref.watch(libraryIndexProvider);
    final filter = ref.watch(libraryFilterProvider);
    final visible = ref.watch(visibleLibraryProvider);
    final display =
        ref.watch(libraryDisplayProvider).value ?? LibraryDisplay.comfortable;
    final selection = ref.watch(selectionProvider);
    final l10n = context.l10n;

    if (library == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        // Rileggendo — tirando giù la griglia, o quando torna la rete — la
        // libreria di prima resta al suo posto finché arriva la nuova.
        child: switch (index) {
          AsyncValue(:final error?, hasValue: false) =>
            LibraryProblemView(error: error),
          AsyncValue(hasValue: false) =>
            const Center(child: CircularProgressIndicator()),
          _ => Column(
              children: [
                if (selection.isEmpty) ...[
                  _Title(shown: visible.length),
                  const LibraryNotices(),
                  const _SearchField(),
                  const _ShelfStrip(),
                ] else
                  _SelectionBar(count: selection.length, total: visible.length),
                Expanded(
                  child: visible.isEmpty
                      ? KEmpty(
                          icon: LucideIcons.searchX,
                          title: filter.isFiltering || filter.auto != null
                              ? l10n.libraryNoMatchTitle
                              : l10n.libraryEmptyTitle,
                          message: filter.isFiltering || filter.auto != null
                              ? l10n.libraryNoMatchMessage
                              : l10n.libraryEmptyMessage,
                          action: filter.isFiltering || filter.auto != null
                              ? KGhostButton(
                                  label: l10n.libraryClearFilters,
                                  icon: LucideIcons.eraser,
                                  onPressed: ref
                                      .read(libraryFilterProvider.notifier)
                                      .clear,
                                )
                              : null,
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            reloadLibrary(ref);
                            ref.invalidate(readingProvider);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: SeriesGrid(
                                  series: visible,
                                  display: display,
                                  selectable: true,
                                  controller: _scroll,
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    4,
                                    12,
                                    navBarInset,
                                  ),
                                ),
                              ),
                              // L'alfabeto serve solo quando l'ordine è quello
                              // alfabetico: altrove porterebbe a caso.
                              if (filter.sort == LibrarySort.title &&
                                  visible.length > 30)
                                _Alphabet(
                                  series: visible,
                                  display: display,
                                  controller: _scroll,
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
        },
      ),
      bottomNavigationBar:
          selection.isEmpty ? null : _SelectionActions(keys: selection),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.shown});

  final int shown;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(context.l10n.libraryTitle, style: KagamiType.display(30)),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '$shown',
                style:
                    KagamiType.figure(15, color: context.tokens.muted),
              ),
            ),
          ],
        ),
      );
}

/// Barra che sostituisce la ricerca mentre si seleziona: dice quante ne hai
/// prese e lascia uscire.
class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: context.l10n.libraryCancelSelection,
              onPressed: ref.read(selectionProvider.notifier).clear,
              icon: const Icon(LucideIcons.x),
            ),
            Expanded(
              child: Text(
                context.l10n.librarySelectedCount(count),
                style: KagamiType.title(15, weight: 700),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(selectionProvider.notifier).replace(
                    ref
                        .read(visibleLibraryProvider)
                        .map((signals) => signals.entry.key),
                  ),
              child: Text(
                count == total
                    ? context.l10n.libraryAllWithCount(total)
                    : context.l10n.libraryAll,
              ),
            ),
          ],
        ),
      );
}

/// Le azioni di gruppo. Sono le stesse della scheda, applicate a più serie:
/// mettere a posto venti serie una per una è il lavoro che un elenco dovrebbe
/// risparmiare.
class _SelectionActions extends ConsumerWidget {
  const _SelectionActions({required this.keys});

  final Set<String> keys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Container(
        color: context.colors.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  tooltip: l10n.libraryMarkAllRead,
                  onPressed: () => _markAll(context, ref, true),
                  icon: const Icon(LucideIcons.checkCheck),
                ),
                IconButton(
                  tooltip: l10n.libraryMarkAllUnread,
                  onPressed: () => _markAll(context, ref, false),
                  icon: const Icon(LucideIcons.undo2),
                ),
                IconButton(
                  tooltip: l10n.libraryStatus,
                  onPressed: () => _pickStatus(context, ref),
                  icon: const Icon(LucideIcons.bookmark),
                ),
                IconButton(
                  tooltip: l10n.libraryFavorites,
                  onPressed: () {
                    final reading = ref.read(readingProvider.notifier);
                    final data = ref.read(readingProvider).value;
                    for (final key in keys) {
                      if (data?.of(key).favorite != true) {
                        reading.toggleFavorite(key);
                      }
                    }
                    ref.read(selectionProvider.notifier).clear();
                  },
                  icon: const Icon(LucideIcons.heart),
                ),
                IconButton(
                  tooltip: l10n.libraryAddToCollection,
                  onPressed: () => showCollectionSheet(context, keys.toList()),
                  icon: const Icon(LucideIcons.listPlus),
                ),
                IconButton(
                  tooltip: l10n.removeSeriesAction,
                  onPressed: () => confirmRemoveSeries(context, ref, [
                    for (final key in keys) ?ref.read(seriesEntryProvider(key)),
                  ]),
                  icon: Icon(LucideIcons.trash2, color: context.tokens.danger),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Future<void> _pickStatus(BuildContext context, WidgetRef ref) async {
    final status = await showKagamiSheet<ShelfStatus>(
      context,
      title: context.l10n.libraryStatusOfSeries(keys.length),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in shelfLabels.entries)
              KTile(
                icon: shelfIcons[entry.key]!,
                title: entry.value,
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
          ],
        ),
      ),
    );
    if (status == null) return;
    await _setStatus(ref, status);
  }

  Future<void> _setStatus(WidgetRef ref, ShelfStatus status) async {
    final reading = ref.read(readingProvider.notifier);
    for (final key in keys) {
      await reading.setStatus(key, status);
    }
    ref.read(selectionProvider.notifier).clear();
  }

  /// Segnare letta una serie intera vuole i suoi capitoli, che stanno in
  /// `index.json`: è una lettura per serie, fatta solo quando l'utente la
  /// chiede esplicitamente.
  Future<void> _markAll(BuildContext context, WidgetRef ref, bool read) async {
    final reading = ref.read(readingProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    ref.read(selectionProvider.notifier).clear();
    var touched = 0;
    for (final key in keys) {
      final index = await ref.read(seriesIndexProvider(key).future);
      if (index == null) continue;
      await reading.setAllRead(
        key,
        index.readable.map((chapter) => chapter.id),
        read,
      );
      touched++;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          read
              ? currentL10n().libraryMarkedRead(touched)
              : currentL10n().libraryMarkedUnread(touched),
        ),
      ),
    );
  }
}

/// La striscia dell'alfabeto: su una libreria lunga ordinata per titolo è il
/// modo più corto per arrivare a una lettera senza scorrere.
class _Alphabet extends StatelessWidget {
  const _Alphabet({
    required this.series,
    required this.display,
    required this.controller,
  });

  final List<SeriesSignals> series;
  final LibraryDisplay display;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final letters = <String, int>{};
    for (var position = 0; position < series.length; position++) {
      final initial = _initialOf(series[position].entry.title);
      letters.putIfAbsent(initial, () => position);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: navBarInset),
      child: SizedBox(
        width: 22,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final letter in letters.keys)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _jump(context, letters[letter]!),
                  child: Center(
                    child: Text(
                      letter,
                      style: KagamiType.label(
                        size: 10.5,
                        color: context.tokens.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _initialOf(String title) {
    final first = title.trim().toUpperCase();
    if (first.isEmpty) return '#';
    final letter = first[0];
    return RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
  }

  /// La posizione si stima dalla geometria della griglia: non serve precisione
  /// al pixel, serve arrivare nella zona giusta senza costruire tutto.
  void _jump(BuildContext context, int position) {
    final width = MediaQuery.sizeOf(context).width - 46;
    if (!display.isGrid) {
      controller.jumpTo(
        (position * (display == LibraryDisplay.detailed ? 90.0 : 70.0))
            .clamp(0, controller.position.maxScrollExtent),
      );
      return;
    }
    final extent = display == LibraryDisplay.compact ? 116.0 : 170.0;
    final columns = (width / extent).ceil().clamp(1, 12);
    final ratio = display == LibraryDisplay.compact ? 0.56 : 0.52;
    final rowHeight = extent / ratio + 18;
    controller.jumpTo(
      ((position ~/ columns) * rowHeight)
          .clamp(0, controller.position.maxScrollExtent),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(libraryFilterProvider);
    final notifier = ref.read(libraryFilterProvider.notifier);
    final display =
        ref.watch(libraryDisplayProvider).value ?? LibraryDisplay.comfortable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: notifier.setQuery,
              decoration: InputDecoration(
                isDense: true,
                hintText: context.l10n.librarySearchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          notifier.setQuery('');
                        },
                        icon: const Icon(LucideIcons.x, size: 16),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          KIconAction(
            icon: display.isGrid ? LucideIcons.layoutGrid : LucideIcons.list,
            tooltip: context.l10n.libraryLayout,
            onPressed: () => _showDisplay(context, display),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: filter.activeCount > 0,
            label: Text('${filter.activeCount}'),
            child: KIconAction(
              icon: LucideIcons.slidersHorizontal,
              tooltip: context.l10n.libraryFiltersAndSort,
              active: filter.activeCount > 0,
              onPressed: () => _showFilters(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisplay(BuildContext context, LibraryDisplay current) =>
      showKagamiSheet<void>(
        context,
        title: context.l10n.libraryLayout,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in LibraryDisplay.values)
                KTile(
                  icon: value.isGrid
                      ? LucideIcons.layoutGrid
                      : LucideIcons.list,
                  title: value.label,
                  trailing: value == current
                      ? Icon(LucideIcons.check,
                          size: 18, color: context.colors.primary)
                      : null,
                  onTap: () {
                    ref.read(libraryDisplayProvider.notifier).show(value);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      );

  void _showFilters(BuildContext context) => showKagamiSheet<void>(
        context,
        title: context.l10n.libraryFiltersAndSort,
        scrollable: true,
        action: Consumer(
          builder: (context, ref, _) =>
              ref.watch(libraryFilterProvider).activeCount == 0
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: ref.read(libraryFilterProvider.notifier).clear,
                      child: Text(context.l10n.libraryReset),
                    ),
        ),
        builder: (context) => const _FilterSheet(),
      );
}

/// Le raccolte automatiche in cima alla griglia: sono le domande che l'utente
/// si fa più spesso, e non vale la pena nasconderle dentro un filtro.
class _ShelfStrip extends ConsumerWidget {
  const _ShelfStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterProvider);
    final notifier = ref.read(libraryFilterProvider.notifier);
    final all = ref.watch(librarySignalsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KChipBar(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          KChip(
            label: context.l10n.libraryAllWithCount(all.length),
            active: filter.auto == null && filter.collectionId == null,
            onTap: () => notifier.showAuto(null),
          ),
          for (final auto in AutoCollection.values)
            Builder(
              builder: (context) {
                final count = all.where(auto.matches).length;
                return KChip(
                  label: count == 0 ? auto.label : '${auto.label} ($count)',
                  active: filter.auto == auto,
                  onTap: count == 0 && filter.auto != auto
                      ? null
                      : () =>
                          notifier.showAuto(filter.auto == auto ? null : auto),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterProvider);
    final notifier = ref.read(libraryFilterProvider.notifier);
    final facets = ref.watch(libraryFacetsProvider);
    final l10n = context.l10n;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          KSection(l10n.librarySortSection),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sort in LibrarySort.values)
                KChip(
                  label: sort.label,
                  icon: filter.sort != sort || sort == LibrarySort.shuffle
                      ? null
                      : (filter.descending
                          ? LucideIcons.arrowDown
                          : LucideIcons.arrowUp),
                  active: filter.sort == sort,
                  onTap: () => sort == LibrarySort.shuffle
                      ? notifier.shuffle()
                      : notifier.setSort(sort),
                ),
            ],
          ),
          const SizedBox(height: 22),
          KSection(l10n.libraryShowOnly),
          KGroup(
            children: [
              KTile(
                icon: LucideIcons.bookOpen,
                title: l10n.libraryOnlyUnread,
                onTap: () => notifier.setOnlyUnread(!filter.onlyUnread),
                trailing: Switch(
                  value: filter.onlyUnread,
                  onChanged: notifier.setOnlyUnread,
                ),
              ),
              KTile(
                icon: LucideIcons.play,
                title: l10n.libraryOnlyStarted,
                onTap: () => notifier.setOnlyStarted(!filter.onlyStarted),
                trailing: Switch(
                  value: filter.onlyStarted,
                  onChanged: notifier.setOnlyStarted,
                ),
              ),
              KTile(
                icon: LucideIcons.sparkles,
                title: l10n.libraryOnlyNew,
                onTap: () => notifier.setOnlyNew(!filter.onlyNew),
                trailing: Switch(
                  value: filter.onlyNew,
                  onChanged: notifier.setOnlyNew,
                ),
              ),
              KTile(
                icon: LucideIcons.stickyNote,
                title: l10n.libraryOnlyCards,
                onTap: () => notifier.setOnlyCards(!filter.onlyCards),
                trailing: Switch(
                  value: filter.onlyCards,
                  onChanged: notifier.setOnlyCards,
                ),
              ),
              KTile(
                icon: LucideIcons.heart,
                title: l10n.libraryOnlyFavorite,
                onTap: () => notifier.setOnlyFavorite(!filter.onlyFavorite),
                trailing: Switch(
                  value: filter.onlyFavorite,
                  onChanged: notifier.setOnlyFavorite,
                ),
              ),
            ],
          ),
          _FilterGroup(
            title: l10n.libraryMinRating,
            children: [
              for (final value in const [6, 7, 8, 9, 10])
                KChip(
                  label: '$value',
                  active: filter.minRating == value,
                  onTap: () => notifier
                      .setMinRating(filter.minRating == value ? null : value),
                ),
            ],
          ),
          _FilterGroup(
            title: l10n.libraryStatus,
            children: [
              for (final status in ShelfStatus.values)
                KChip(
                  label: shelfLabels[status]!,
                  active: filter.shelf.contains(status),
                  onTap: () => notifier.toggleShelf(status),
                ),
            ],
          ),
          _FilterGroup(
            title: l10n.libraryRelease,
            children: [
              for (final status in releaseLabels.keys)
                KChip(
                  label: releaseLabels[status]!,
                  active: filter.release.contains(status),
                  onTap: () => notifier.toggleRelease(status),
                ),
            ],
          ),
          if (facets.genres.isNotEmpty)
            _TriGroup(
              title: l10n.libraryGenres,
              hint: l10n.libraryTriHint,
              values: facets.genres,
              filter: filter.genres,
              onToggle: notifier.toggleGenre,
            ),
          if (facets.tags.isNotEmpty)
            _TriGroup(
              title: l10n.libraryTags,
              values: facets.tags,
              filter: filter.tags,
              onToggle: notifier.toggleTag,
            ),
          if (facets.authors.isNotEmpty)
            _TriGroup(
              title: l10n.libraryAuthors,
              values: facets.authors,
              filter: filter.authors,
              onToggle: notifier.toggleAuthor,
            ),
        ],
      ),
    );
  }
}

/// Un gruppo di valori a tre stati. Il segno davanti dice cosa sta facendo il
/// filtro: più richiede, meno esclude.
class _TriGroup extends StatelessWidget {
  const _TriGroup({
    required this.title,
    required this.values,
    required this.filter,
    required this.onToggle,
    this.hint,
  });

  final String title;
  final String? hint;
  final List<String> values;
  final TriFilter filter;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => _FilterGroup(
        title: title,
        hint: hint,
        children: [
          for (final value in values)
            Builder(
              builder: (context) {
                final state = filter.stateOf(value);
                return KChip(
                  label: value,
                  active: state != FacetState.off,
                  icon: switch (state) {
                    FacetState.off => null,
                    FacetState.include => LucideIcons.plus,
                    FacetState.exclude => LucideIcons.minus,
                  },
                  // Il pallino ha il colore che il valore ha nelle schede, così
                  // «Azione» qui è la stessa cosa che si è toccata là.
                  tint: state == FacetState.exclude
                      ? context.tokens.danger
                      : TagTint.of(context, value).foreground,
                  onTap: () => onToggle(value),
                );
              },
            ),
        ],
      );
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.title, required this.children, this.hint});

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KSection(title, padding: const EdgeInsets.fromLTRB(4, 0, 4, 4)),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  hint!,
                  style:
                      KagamiType.body(12, color: context.tokens.muted),
                ),
              )
            else
              const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ],
        ),
      );
}
