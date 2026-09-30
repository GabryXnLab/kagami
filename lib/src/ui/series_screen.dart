/// Scheda della serie: cosa c'è, a che punto si è, e da dove si riparte.
///
/// L'ordine delle sezioni è quello delle domande: che serie è, a che punto
/// sono, di cosa parla, com'è fatta, che capitoli ci sono. Il pulsante che
/// riprende la lettura resta raggiungibile per tutta la scheda, perché è il
/// motivo per cui la scheda si apre.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cleanup.dart';
import '../data/downloads.dart';
import '../data/library.dart';
import '../data/library_view.dart';
import '../format/malf.dart';
import '../format/reading.dart';
import '../l10n.dart';
import '../providers.dart';
import 'drive_ui.dart';
import 'library_screen.dart' show seriesRoute;
import 'reader_screen.dart';
import 'theme.dart';
import 'widgets/cleanup_sheet.dart';
import 'widgets/collection_sheet.dart';
import 'widgets/kit.dart';
import 'widgets/origin.dart';
import 'widgets/series_cover.dart';

/// Un getter e non una costante: il testo dipende dalla lingua scelta.
Map<ShelfStatus, String> get shelfLabels {
  final l10n = currentL10n();
  return {
    ShelfStatus.none: l10n.seriesShelfNone,
    ShelfStatus.planned: l10n.seriesShelfPlanned,
    ShelfStatus.reading: l10n.seriesShelfReading,
    ShelfStatus.paused: l10n.seriesShelfPaused,
    ShelfStatus.completed: l10n.seriesShelfCompleted,
    ShelfStatus.dropped: l10n.seriesShelfDropped,
  };
}

const Map<ShelfStatus, IconData> shelfIcons = {
  ShelfStatus.none: LucideIcons.circleDashed,
  ShelfStatus.planned: LucideIcons.clock,
  ShelfStatus.reading: LucideIcons.bookOpen,
  ShelfStatus.paused: LucideIcons.pause,
  ShelfStatus.completed: LucideIcons.circleCheck,
  ShelfStatus.dropped: LucideIcons.circleX,
};

Map<ReleaseStatus, String> get releaseLabels {
  final l10n = currentL10n();
  return {
    ReleaseStatus.ongoing: l10n.seriesReleaseOngoing,
    ReleaseStatus.completed: l10n.seriesReleaseCompleted,
    ReleaseStatus.hiatus: l10n.seriesReleaseHiatus,
    ReleaseStatus.cancelled: l10n.seriesReleaseCancelled,
    ReleaseStatus.unknown: l10n.seriesReleaseUnknown,
  };
}

/// Quanti capitoli in un salto dell'elenco. Sotto questa soglia l'elenco si
/// scorre e basta; sopra, cercare il capitolo 40 fra trecento è un gesto
/// lungo quanto la serie.
const int _jumpSize = 50;

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({required this.seriesKey, super.key});

  final String seriesKey;

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  /// I capitoli più recenti in cima: su una serie in corso è lì che si guarda.
  bool _newestFirst = true;
  bool _onlyUnread = false;
  bool _onlyDownloaded = false;
  String _chapterQuery = '';

  /// Il blocco di capitoli mostrato, quando la serie è troppo lunga per
  /// scorrerla tutta. `null` significa tutti.
  int? _jump;

  /// I capitoli selezionati. Vuoto significa che non si sta selezionando.
  final Set<String> _selected = {};

  bool _touched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_touched) return;
    _touched = true;
    // Aprire la scheda è la risposta a "hai visto cosa è arrivato?": da qui in
    // poi i capitoli già presenti non sono più una novità. Lo si scrive a
    // transizione finita, e anche a schede interne entrate: pubblicarlo rifà
    // i segnali di tutta la libreria, e durante l'ingresso della scheda era un
    // fotogramma perso.
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _touch());
      return;
    }
    void arrived(AnimationStatus status) {
      if (!status.isCompleted) return;
      animation.removeStatusListener(arrived);
      Future<void>.delayed(const Duration(milliseconds: 300), _touch);
    }

    animation.addStatusListener(arrived);
  }

  void _touch() {
    if (!mounted) return;
    ref.read(readingProvider.notifier).touch(widget.seriesKey);
    ref.read(arrivalsProvider.notifier).acknowledge(widget.seriesKey);
    _offerCleanup();
  }

  /// Aprendo la scheda, se dei capitoli già letti occupano ancora spazio sul
  /// telefono, propone di toglierli — finché l'utente non dice di smettere.
  Future<void> _offerCleanup() async {
    final quiet = await ref.read(cleanupQuietProvider.future);
    if (quiet.contains(widget.seriesKey) || !mounted) return;
    final leftovers =
        await ref.read(readLeftoversProvider(widget.seriesKey).future);
    if (leftovers.isEmpty || !mounted) return;
    // Chi è già entrato nel lettore nel frattempo non va interrotto.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    await offerCleanup(context, ref, widget.seriesKey, leftovers, asked: true);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final signals = ref.watch(seriesSignalsProvider(widget.seriesKey));
    if (library == null || signals == null) {
      return Scaffold(
        body: Center(child: Text(context.l10n.seriesNotFound)),
      );
    }
    final index = ref.watch(seriesChaptersProvider(widget.seriesKey));
    final sources = index.value;
    final chapters = sources?.index.chapters ?? const <ChapterEntry>[];
    final downloads = ref.watch(downloadsProvider);
    final leftovers = ref.watch(readLeftoversProvider(widget.seriesKey)).value;
    final onDrive = [
      for (final chapter in chapters)
        if (sources?.originOf(chapter.id) == LibraryOrigin.drive) chapter.id,
    ];
    final ordered = [...chapters]..sort(
        (a, b) => _newestFirst
            ? b.order.compareTo(a.order)
            : a.order.compareTo(b.order),
      );
    final visible = _visible(ordered, signals.state, onDrive.toSet());
    final next = _resumeTarget(chapters, signals.state);
    final blocks = _blocks(chapters.length);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _Cover(signals: signals),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Entrance(child: _Identity(signals: signals)),
                  const SizedBox(height: 18),
                  Entrance(
                    index: 1,
                    child: _Resume(
                      signals: signals,
                      next: next,
                      onOpen: _open,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Entrance(index: 2, child: _Numbers(signals: signals)),
                  const SizedBox(height: 22),
                  Entrance(
                    index: 3,
                    child: _Shelf(signals: signals),
                  ),
                  const SizedBox(height: 22),
                  Entrance(
                    index: 4,
                    child: _Details(
                      seriesKey: widget.seriesKey,
                      signals: signals,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ChapterHeader(
              total: chapters.length,
              archived: chapters.where((c) => c.isReadable).length,
              shown: visible.length,
              newestFirst: _newestFirst,
              onlyUnread: _onlyUnread,
              onlyDownloaded: _onlyDownloaded,
              blocks: blocks,
              jump: _jump,
              onJump: (value) => setState(() => _jump = value),
              onQuery: (value) => setState(() => _chapterQuery = value),
              onToggleOrder: () => setState(() => _newestFirst = !_newestFirst),
              onToggleUnread: () => setState(() => _onlyUnread = !_onlyUnread),
              onToggleDownloaded: () =>
                  setState(() => _onlyDownloaded = !_onlyDownloaded),
              onMarkAll: chapters.isEmpty
                  ? null
                  : () => _markAll(chapters, signals.state),
              onDownloadAll: onDrive.isEmpty
                  ? null
                  : () => _download(onDrive, confirm: true),
              cleanup: leftovers == null || !leftovers.offersAnything
                  ? null
                  : _cleanupLabel(context.l10n, leftovers),
              onCleanup: () {
                if (leftovers != null) {
                  offerCleanup(context, ref, widget.seriesKey, leftovers);
                }
              },
            ),
          ),
          if (!index.hasValue)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (chapters.isEmpty && !ref.watch(networkOnlineProvider))
            SliverToBoxAdapter(
              child: KEmpty(
                icon: LucideIcons.cloudOff,
                title: context.l10n.seriesOfflineTitle,
                message: context.l10n.seriesOfflineMessage,
              ),
            )
          else if (chapters.isEmpty)
            SliverToBoxAdapter(
              child: KEmpty(
                icon: LucideIcons.fileQuestion,
                title: context.l10n.seriesNoIndexTitle,
                message: context.l10n.seriesNoIndexMessage,
              ),
            )
          else if (visible.isEmpty)
            SliverToBoxAdapter(
              child: KEmpty(
                icon: LucideIcons.listFilter,
                compact: true,
                title: context.l10n.seriesNoChaptersTitle,
                message: context.l10n.seriesNoChaptersMessage,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, position) {
                  final chapter = visible[position];
                  final origin = sources?.originOf(chapter.id);
                  final download = downloads[
                      downloadKey(widget.seriesKey, chapter.id)];
                  return _ChapterTile(
                    chapter: chapter,
                    fromDrive: origin == LibraryOrigin.drive,
                    download: download,
                    onDownload: origin == LibraryOrigin.drive
                        ? () => _download([chapter.id])
                        : null,
                    onCancelDownload: download == null
                        ? null
                        : () => ref
                            .read(downloadsProvider.notifier)
                            .cancel(widget.seriesKey, chapter.id),
                    read: signals.state.readChapters.contains(chapter.id),
                    selected: _selected.contains(chapter.id),
                    selecting: _selected.isNotEmpty,
                    progress: signals.state.positions[chapter.id],
                    onTap: () {
                      if (_selected.isNotEmpty) {
                        _toggleSelected(chapter.id);
                      } else if (chapter.isReadable) {
                        _open(chapter.id);
                      }
                    },
                    onToggleRead: () =>
                        ref.read(readingProvider.notifier).setChapterRead(
                              widget.seriesKey,
                              chapter.id,
                              !signals.state.readChapters.contains(chapter.id),
                            ),
                    onLongPress: () => _toggleSelected(chapter.id),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(child: _Similar(seriesKey: widget.seriesKey)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : _ChapterSelectionBar(
              count: _selected.length,
              onRead: () => _markSelected(true),
              onUnread: () => _markSelected(false),
              onReadThrough: () => _readThrough(ordered),
              onDownload: _selected.any(onDrive.contains)
                  ? () {
                      _download(_selected.where(onDrive.contains));
                      setState(_selected.clear);
                    }
                  : null,
              onClear: () => setState(_selected.clear),
            ),
    );
  }

  /// Da dove si riparte: il capitolo lasciato a metà, altrimenti il primo non
  /// letto, altrimenti niente — la serie è in pari.
  ChapterEntry? _resumeTarget(List<ChapterEntry> chapters, SeriesState state) {
    final readable = chapters.where((c) => c.isReadable).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (readable.isEmpty) return null;
    final progress = state.progress;
    if (progress != null && !state.readChapters.contains(progress.chapterId)) {
      for (final chapter in readable) {
        if (chapter.id == progress.chapterId) return chapter;
      }
    }
    for (final chapter in readable) {
      if (!state.readChapters.contains(chapter.id)) return chapter;
    }
    return null;
  }

  /// I blocchi in cui si può saltare l'elenco, dal più recente: `170–121`,
  /// `120–71`, e così via. Sotto la soglia non ce ne sono.
  List<(int, int)> _blocks(int total) {
    if (total <= _jumpSize) return const [];
    return [
      for (var high = total; high > 0; high -= _jumpSize)
        (high, (high - _jumpSize + 1).clamp(1, total)),
    ];
  }

  /// I capitoli che passano ricerca, filtri e salto. Su una serie da trecento
  /// capitoli "solo non letti" è la differenza fra un elenco e un muro.
  List<ChapterEntry> _visible(
    List<ChapterEntry> ordered,
    SeriesState state,
    Set<String> onDrive,
  ) {
    final needle = _chapterQuery.trim().toLowerCase();
    final blocks = _blocks(ordered.length);
    final block = _jump != null && _jump! < blocks.length ? blocks[_jump!] : null;
    // L'ordine dichiarato dall'indice parte da zero; i blocchi si contano come
    // li conta chi legge, dal primo capitolo.
    return ordered.where((chapter) {
      if (_onlyUnread && state.readChapters.contains(chapter.id)) return false;
      // Con Drive «scaricato» vuol dire sul telefono: un capitolo che si
      // legge in streaming si legge, ma senza rete no.
      if (_onlyDownloaded &&
          (!chapter.isReadable || onDrive.contains(chapter.id))) {
        return false;
      }
      if (block != null) {
        final number = chapter.order + 1;
        if (number > block.$1 || number < block.$2) return false;
      }
      if (needle.isEmpty) return true;
      return chapter.label().toLowerCase().contains(needle);
    }).toList(growable: false);
  }

  void _toggleSelected(String chapterId) => setState(() {
        if (!_selected.remove(chapterId)) _selected.add(chapterId);
      });

  void _markSelected(bool read) {
    ref
        .read(readingProvider.notifier)
        .setAllRead(widget.seriesKey, _selected.toList(), read);
    setState(_selected.clear);
  }

  /// Porta dei capitoli da Drive al telefono. Tutti insieme si chiede
  /// prima: su una serie lunga sono gigabyte.
  Future<void> _download(Iterable<String> chapterIds, {bool confirm = false}) async {
    final ids = chapterIds.toList(growable: false);
    if (confirm) {
      final sure = await showKagamiSheet<bool>(
        context,
        title: context.l10n.seriesDownloadAllTitle(ids.length),
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.seriesDownloadAllMessage,
                style: KagamiType.body(13.5,
                    height: 1.5, color: context.tokens.muted),
              ),
              const SizedBox(height: 20),
              KButton(
                label: context.l10n.seriesDownload,
                icon: LucideIcons.download,
                expand: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      );
      if (sure != true || !mounted) return;
    }
    await downloadChapters(context, ref, widget.seriesKey, ids);
  }

  void _open(String chapterId) => openReader(
        context,
        seriesKey: widget.seriesKey,
        chapterId: chapterId,
      );

  /// Segna letto tutto fino al più recente fra i selezionati: è il gesto con
  /// cui si recupera una serie letta altrove senza toccarne cento a uno a uno.
  /// Anche i capitoli non scaricati: una serie archiviata dal 126 i primi
  /// 125 li ha letti altrove, ed è proprio lì che il gesto serve.
  void _readThrough(List<ChapterEntry> ordered) {
    final last = ordered
        .where((chapter) => _selected.contains(chapter.id))
        .map((chapter) => chapter.order)
        .fold<int>(-1, (highest, order) => order > highest ? order : highest);
    if (last < 0) return;
    final ids = ordered
        .where((chapter) => chapter.order <= last)
        .map((chapter) => chapter.id);
    ref.read(readingProvider.notifier).setReadThrough(widget.seriesKey, ids);
    setState(_selected.clear);
  }

  static String _cleanupLabel(AppLocalizations l10n, ReadLeftovers leftovers) {
    final count = leftovers.chapterCount;
    if (count == 0) return l10n.seriesCleanupRemote(leftovers.remote.length);
    final size = formatBytes(leftovers.folderBytes + leftovers.cacheBytes);
    return l10n.seriesCleanupLocal(count, size);
  }

  void _markAll(List<ChapterEntry> chapters, SeriesState state) {
    final ids = chapters
        .where((c) => c.isReadable)
        .map((c) => c.id)
        .toList(growable: false);
    final allRead = ids.every(state.readChapters.contains);
    ref
        .read(readingProvider.notifier)
        .setAllRead(widget.seriesKey, ids, !allRead);
  }
}

/// Un capitolo che sta scendendo da Drive: l'anello si riempie tavola dopo
/// tavola, un tocco lo ferma. Se è andato male lo si riprova da lì.
class _DownloadState extends StatelessWidget {
  const _DownloadState({required this.progress, this.onCancel, this.onRetry});

  final DownloadProgress progress;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (progress.error != null) {
      final label = context.l10n.seriesDownloadFailed('${progress.error}');
      return Tooltip(
        message: label,
        child: _TileAction(
          label: label,
          onTap: onRetry,
          child: Icon(LucideIcons.rotateCw,
              size: 18, color: context.tokens.danger),
        ),
      );
    }
    if (progress.waiting) {
      return _TileAction(
        label: context.l10n.seriesDownloadWaiting,
        onTap: onCancel,
        child: Icon(LucideIcons.cloudOff, size: 18, color: context.tokens.muted),
      );
    }
    return _TileAction(
      label: progress.queued
          ? context.l10n.seriesDownloadQueued
          : context.l10n.seriesDownloadCancel,
      onTap: onCancel,
      child: SizedBox.square(
        dimension: 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress.queued || progress.total == 0
                  ? null
                  : progress.fraction,
              strokeWidth: 2.5,
            ),
            const Icon(LucideIcons.x, size: 10),
          ],
        ),
      ),
    );
  }
}

/// Un'azione in fondo alla riga di un capitolo.
///
/// Non è un `IconButton`: con tooltip, inchiostro e fuoco una riga che ne
/// ha due costa da costruire circa quattro volte tanto, e scorrendo un
/// elenco di capitoli le righe si costruiscono a ogni fotogramma. Il
/// riscontro del tocco c'è lo stesso: l'icona cambia.
class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.square(dimension: 48, child: Center(child: child)),
        ),
      );
}

/// Dove sta la serie, fra le pastiglie della scheda. Come sulla copertina,
/// compare solo quando Drive c'è.
class _PlacePill extends ConsumerWidget {
  const _PlacePill({required this.seriesKey});

  final String seriesKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(seriesPlaceProvider(seriesKey));
    final drive = ref.watch(libraryProvider.select((l) => l?.hasDrive ?? false));
    if (!drive || place == null) return const SizedBox.shrink();
    return KChip(
      label: switch (place) {
        SeriesPlace.local => context.l10n.seriesPlaceLocal,
        SeriesPlace.drive => context.l10n.seriesPlaceDrive,
        SeriesPlace.mixed => context.l10n.seriesPlaceMixed,
      },
      icon: placeIcons(place).last,
    );
  }
}

/// La copertina a tutta larghezza, che sfuma nel fondo. Il titolo non ci sta
/// sopra: sta sotto, dove lo si legge senza combattere con la tavola.
class _Cover extends StatelessWidget {
  const _Cover({required this.signals});

  final SeriesSignals signals;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final entry = signals.entry;
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      stretch: true,
      leading: const _GlassBack(),
      actions: [_GlassMute(signals: signals)],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'cover:${entry.key}',
              flightShuttleBuilder: coverFlight,
              child: CoverImage(
                entry: entry,
                full: true,
                width: MediaQuery.sizeOf(context).width,
              ),
            ),
            // La copertina continua sotto il titolo: la sfumatura serve a
            // renderlo leggibile su qualunque tavola.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surface.withValues(alpha: 0.35),
                    scheme.surface.withValues(alpha: 0.2),
                    scheme.surface.withValues(alpha: 0.85),
                    scheme.surface,
                  ],
                  stops: const [0, 0.35, 0.82, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il ritorno indietro sopra la copertina: un tondo scuro, perché una freccia
/// nuda su una tavola chiara sparisce.
class _GlassBack extends StatelessWidget {
  const _GlassBack();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: KPress(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.arrowLeft,
                size: 19, color: Colors.white),
          ),
        ),
      );
}

/// Silenzia le notifiche dei capitoli nuovi di questa serie. Sta sulla
/// copertina, di fronte al ritorno, perché è una scelta sulla serie intera e
/// non un gesto di lettura; il pallino sulle copertine resta comunque.
class _GlassMute extends ConsumerWidget {
  const _GlassMute({required this.signals});

  final SeriesSignals signals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = signals.state.muted;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Tooltip(
        message: muted
            ? context.l10n.seriesMuteTooltipOn
            : context.l10n.seriesMuteTooltipOff,
        child: KPress(
          onTap: () {
            ref.read(readingProvider.notifier).toggleMuted(signals.entry.key);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    muted
                        ? context.l10n.seriesMuteUnmuted
                        : context.l10n.seriesMuteMuted,
                  ),
                ),
              );
          },
          child: Container(
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              muted ? LucideIcons.bellOff : LucideIcons.bell,
              size: 19,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chi è questa serie: stato, tipo, lingua, titolo, chi l'ha fatta.
class _Identity extends StatelessWidget {
  const _Identity({required this.signals});

  final SeriesSignals signals;

  @override
  Widget build(BuildContext context) {
    final entry = signals.entry;
    final muted = context.tokens.muted;
    final people = {...entry.authors, ...entry.artists}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ReleasePill(status: entry.releaseStatus),
            _PlacePill(seriesKey: entry.key),
            if (entry.type != null) KTag(label: entry.type!),
            if (entry.language != null)
              KTag(label: entry.language!.toUpperCase()),
            if (entry.latestChapterArchivedAt != null)
              KChip(label: '${entry.latestChapterArchivedAt!.toLocal().year}'),
          ],
        ),
        const SizedBox(height: 16),
        Text(entry.title, style: KagamiType.display(27)),
        if (people.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            people.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KagamiType.body(13.5, color: muted),
          ),
        ],
      ],
    );
  }
}

/// Lo stato di pubblicazione, con il pallino acceso quando la serie è viva.
class _ReleasePill extends StatelessWidget {
  const _ReleasePill({required this.status});

  final ReleaseStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tint = switch (status) {
      ReleaseStatus.ongoing => tokens.success,
      ReleaseStatus.completed => tokens.info,
      ReleaseStatus.hiatus => tokens.warning,
      ReleaseStatus.cancelled => tokens.danger,
      ReleaseStatus.unknown => tokens.muted,
    };
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            releaseLabels[status]!.toUpperCase(),
            style: KagamiType.overline(size: 11, color: tint),
          ),
        ],
      ),
    );
  }
}

/// Da dove si riparte, con il gesto accanto: continuare dove si era rimasti o
/// saltare al capitolo dopo. È la scheda che si guarda per prima.
class _Resume extends ConsumerWidget {
  const _Resume({
    required this.signals,
    required this.next,
    required this.onOpen,
  });

  final SeriesSignals signals;
  final ChapterEntry? next;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.tokens.muted;
    final state = signals.state;
    final index = ref.watch(seriesIndexProvider(signals.entry.key)).value;
    if (next == null) {
      return KCard(
        child: Row(
          children: [
            Icon(LucideIcons.circleCheck, size: 20, color: context.tokens.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                signals.entry.missingChapterCount > 0
                    ? context.l10n.seriesCaughtUpMissing(
                        signals.entry.missingChapterCount)
                    : context.l10n.seriesCaughtUpAll,
                style: KagamiType.body(13.5, color: muted),
              ),
            ),
          ],
        ),
      );
    }

    final chapter = next!;
    final progress = state.positions[chapter.id];
    final chapters = index?.readable.length ?? signals.entry.archivedChapterCount;
    final position = chapter.order + 1;

    return KCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.bookOpen, size: 15, color: muted),
              const SizedBox(width: 8),
              Text(
                progress == null
                    ? (signals.isStarted
                        ? context.l10n.seriesResumeToContinue
                        : context.l10n.seriesResumeToStart)
                    : context.l10n.seriesResumeHalfway,
                style: KagamiType.overline(size: 10.5, color: muted),
              ),
              const Spacer(),
              Text(
                '$position / $chapters',
                style: KagamiType.figure(12, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            chapter.label(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KagamiType.title(17, weight: 700),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            KProgress(value: progress.fraction),
            const SizedBox(height: 6),
            Text(
              context.l10n.seriesResumePage(
                progress.page + 1,
                progress.pageCount,
              ),
              style: KagamiType.label(size: 11.5, color: muted),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: KButton(
                  label: progress == null
                      ? (signals.isStarted
                          ? context.l10n.seriesContinue
                          : context.l10n.seriesStart)
                      : context.l10n.seriesResume,
                  icon: LucideIcons.play,
                  expand: true,
                  onPressed: () => onOpen(chapter.id),
                ),
              ),
              const SizedBox(width: 10),
              KIconAction(
                icon: LucideIcons.skipForward,
                tooltip: context.l10n.seriesNextChapter,
                onPressed: () {
                  final readable = index?.readable ?? const <ChapterEntry>[];
                  final after = readable
                      .where((row) => row.order > chapter.order)
                      .fold<ChapterEntry?>(
                        null,
                        (best, row) =>
                            best == null || row.order < best.order ? row : best,
                      );
                  if (after != null) onOpen(after.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// I numeri della serie: quanti capitoli, quanti letti, quanto manca, che
/// voto le è stato dato.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.signals});

  final SeriesSignals signals;

  @override
  Widget build(BuildContext context) {
    final entry = signals.entry;
    return KCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: KFigureRow(
        children: [
          // Tutti, non solo gli archiviati: fra i letti ci sono anche quelli
          // mai scaricati, e un «Letti» più grande di «Capitoli» non si legge.
          KFigure(
            value: '${math.max(entry.chapterCount, entry.archivedChapterCount)}',
            label: context.l10n.seriesFigureChapters,
          ),
          KFigure(
            value: '${signals.readCount}',
            label: context.l10n.seriesFigureRead,
          ),
          KFigure(
            value: '${(signals.fraction * 100).round()}%',
            label: context.l10n.seriesFigureProgress,
          ),
          KFigure(
            value: signals.state.rating == null
                ? '—'
                : '${signals.state.rating}',
            label: context.l10n.seriesFigureRating,
            tint: signals.state.rating == null
                ? context.tokens.muted
                : ratingTint(context, signals.state.rating!),
          ),
        ],
      ),
    );
  }
}

/// Lo scaffale: stato, preferito, voto, raccolte, note. Sono le cose che si
/// cambiano stando sulla scheda, non leggendo.
class _Shelf extends ConsumerWidget {
  const _Shelf({required this.signals});

  final SeriesSignals signals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = signals.state;
    final key = signals.entry.key;
    final reading = ref.read(readingProvider.notifier);
    final notes = state.notes ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KSection(context.l10n.seriesMyShelf),
        KChipBar(
          children: [
            for (final entry in shelfLabels.entries)
              KChip(
                label: entry.value,
                icon: shelfIcons[entry.key],
                active: entry.key == state.status,
                onTap: () => reading.setStatus(key, entry.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KGhostButton(
                label: state.favorite
                    ? context.l10n.seriesFavoriteOn
                    : context.l10n.seriesFavoriteOff,
                icon: state.favorite ? LucideIcons.heart : LucideIcons.heart,
                expand: true,
                height: 46,
                onPressed: () => reading.toggleFavorite(key),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KGhostButton(
                label: state.rating == null
                    ? context.l10n.seriesRatingButton
                    : context.l10n.seriesRatingOutOfTen(state.rating!),
                icon: LucideIcons.star,
                expand: true,
                height: 46,
                onPressed: () => _rate(context, ref, key, state.rating),
              ),
            ),
            const SizedBox(width: 10),
            KIconAction(
              icon: LucideIcons.listPlus,
              tooltip: context.l10n.seriesCollections,
              size: 46,
              onPressed: () => showCollectionSheet(context, [key]),
            ),
            const SizedBox(width: 10),
            KIconAction(
              icon: LucideIcons.notebookPen,
              tooltip: context.l10n.seriesNotes,
              size: 46,
              active: notes.isNotEmpty,
              onPressed: () => _editNotes(context, ref, key, state.notes),
            ),
          ],
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          KCard(
            color: context.colors.surfaceContainerHigh,
            padding: const EdgeInsets.all(14),
            onTap: () => _editNotes(context, ref, key, notes),
            child: Text(notes, style: KagamiType.body(13)),
          ),
        ],
      ],
    );
  }

  Future<void> _rate(
    BuildContext context,
    WidgetRef ref,
    String key,
    int? current,
  ) async {
    final chosen = await showKagamiSheet<int>(
      context,
      title: context.l10n.seriesRatingSheetTitle,
      builder: (context) => _RatingSheet(current: current),
    );
    if (chosen == null) return;
    await ref
        .read(readingProvider.notifier)
        .setRating(key, chosen < 0 ? null : chosen);
  }

  Future<void> _editNotes(
    BuildContext context,
    WidgetRef ref,
    String key,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    final saved = await showKagamiSheet<String>(
      context,
      title: context.l10n.seriesNotes,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 6,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.seriesNotesHint,
              ),
            ),
            const SizedBox(height: 16),
            KButton(
              label: context.l10n.seriesSave,
              expand: true,
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == null) return;
    await ref.read(readingProvider.notifier).setNotes(key, saved);
  }
}

/// Il voto da 1 a 10: una fila di dieci celle che si riempie fino al valore,
/// da toccare o da percorrere col dito. Il numero grande e la parola sopra
/// dicono cosa si sta per dare prima di confermarlo, perché un voto dato per
/// sbaglio con un tocco solo è un voto che nessuno corregge.
class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.current});

  final int? current;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  List<String> _words(AppLocalizations l10n) => [
        l10n.seriesRatingWord1,
        l10n.seriesRatingWord2,
        l10n.seriesRatingWord3,
        l10n.seriesRatingWord4,
        l10n.seriesRatingWord5,
        l10n.seriesRatingWord6,
        l10n.seriesRatingWord7,
        l10n.seriesRatingWord8,
        l10n.seriesRatingWord9,
        l10n.seriesRatingWord10,
      ];

  late int? _value = widget.current;

  void _pick(double dx, double width) {
    final value = (dx / width * 10).floor().clamp(0, 9) + 1;
    if (value == _value) return;
    HapticFeedback.selectionClick();
    setState(() => _value = value);
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final muted = context.tokens.muted;
    final tint = value == null ? muted : ratingTint(context, value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: KagamiType.figure(56, color: tint, height: 1),
                child: Text(value == null ? '—' : '$value'),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text('/10', style: KagamiType.figure(20, color: muted)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    value == null
                        ? context.l10n.seriesRatingNone
                        : _words(context.l10n)[value - 1],
                    key: ValueKey(value),
                    style: KagamiType.title(17, weight: 700, color: tint),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _pick(details.localPosition.dx, width),
                onHorizontalDragStart: (details) =>
                    _pick(details.localPosition.dx, width),
                onHorizontalDragUpdate: (details) =>
                    _pick(details.localPosition.dx, width),
                // Alta quanto la cella scelta: la fila non deve crescere
                // quando si dà il primo voto.
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      for (var cell = 1; cell <= 10; cell++) ...[
                        if (cell > 1) const SizedBox(width: 5),
                        Expanded(child: _RatingCell(cell: cell, value: value)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.seriesRatingHint,
                style: KagamiType.body(12, color: muted),
              ),
              if (widget.current != null)
                Text(
                  context.l10n.seriesRatingBefore(widget.current!),
                  style: KagamiType.body(12, color: muted),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.current != null) ...[
                Expanded(
                  child: KGhostButton(
                    label: context.l10n.seriesRatingRemove,
                    icon: LucideIcons.eraser,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(-1),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: KButton(
                  label: context.l10n.seriesRatingSave,
                  icon: LucideIcons.star,
                  expand: true,
                  tone: value == null ? null : tint,
                  onPressed: value == null || value == widget.current
                      ? null
                      : () => Navigator.of(context).pop(value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingCell extends StatelessWidget {
  const _RatingCell({required this.cell, required this.value});

  final int cell;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final rating = value;
    final tint =
        rating != null && cell <= rating ? ratingTint(context, rating) : null;
    return AnimatedContainer(
      // Le celle si accendono una dopo l'altra, da sinistra: si vede
      // riempirsi la fila invece di un blocco che cambia colore.
      duration: Duration(milliseconds: 120 + cell * 12),
      curve: Curves.easeOutCubic,
      height: cell == rating ? 56 : 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint ?? context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$cell',
        style: KagamiType.figure(
          15,
          color: tint == null
              ? context.tokens.muted
              : tint.computeLuminance() > 0.45
                  ? Colors.black
                  : Colors.white,
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.seriesKey, required this.signals});

  final String seriesKey;
  final SeriesSignals signals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = signals.entry;
    final metadata = ref.watch(seriesManifestProvider(seriesKey)).value;
    final description = metadata?['description'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description != null && description.isNotEmpty) ...[
          KSection(context.l10n.seriesSynopsis),
          _Description(text: description),
          const SizedBox(height: 20),
        ],
        _Pace(seriesKey: seriesKey, signals: signals),
        // Generi e tag portano alla libreria già filtrata: da qui "altre
        // così" è una domanda sola, non un giro dai filtri.
        if (entry.genres.isNotEmpty) ...[
          KSection(context.l10n.seriesGenres),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final genre in entry.genres)
                KTag(
                  label: genre,
                  onTap: () => _browse(context, ref, genre: genre),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (entry.tags.isNotEmpty) ...[
          KSection(
            context.l10n.seriesTags,
            trailing: Text(
              '${entry.tags.length}',
              style: KagamiType.label(size: 12, color: context.tokens.muted),
            ),
          ),
          _TagCloud(
            tags: entry.tags,
            onTap: (tag) => _browse(context, ref, tag: tag),
          ),
          const SizedBox(height: 20),
        ],
        if (entry.authors.isNotEmpty || entry.artists.isNotEmpty) ...[
          KSection(context.l10n.seriesCreators),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final person in {...entry.authors, ...entry.artists})
                KTag(
                  label: person,
                  icon: LucideIcons.penTool,
                  onTap: () => _browse(context, ref, author: person),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// I tag, che su certe serie sono quaranta: se ne mostrano i primi e il
/// resto a richiesta, perché la scheda non diventi un muro di etichette.
class _TagCloud extends StatefulWidget {
  const _TagCloud({required this.tags, required this.onTap});

  final List<String> tags;
  final ValueChanged<String> onTap;

  @override
  State<_TagCloud> createState() => _TagCloudState();
}

class _TagCloudState extends State<_TagCloud> {
  static const _shown = 18;

  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final hidden = _all ? 0 : math.max(0, widget.tags.length - _shown);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in widget.tags.take(widget.tags.length - hidden))
            KTag(label: tag, prefix: '#', onTap: () => widget.onTap(tag)),
          if (hidden > 0)
            KChip(
              label: context.l10n.seriesMoreTags(hidden),
              icon: LucideIcons.plus,
              onTap: () => setState(() => _all = true),
            ),
        ],
      ),
    );
  }
}

/// Apre la libreria filtrata su un valore, tornando alla griglia: il tag
/// chiede "altre così" e la risposta è la libreria, non un'altra schermata.
void _browse(
  BuildContext context,
  WidgetRef ref, {
  String? genre,
  String? tag,
  String? author,
}) {
  ref.read(libraryFilterProvider.notifier).only(
        genre: genre,
        tag: tag,
        author: author,
      );
  ref.read(shellTabProvider.notifier).show(ShellTab.library);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Quanto resta da leggere e ogni quanto arriva un capitolo.
///
/// La stima è dichiaratamente grossolana — tre tavole al minuto, che è il
/// passo con cui si legge un capitolo senza rileggerlo — e serve a decidere se
/// c'è tempo adesso, non a misurare niente.
class _Pace extends ConsumerWidget {
  const _Pace({required this.seriesKey, required this.signals});

  final String seriesKey;
  final SeriesSignals signals;

  static const double _pagesPerMinute = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(seriesIndexProvider(seriesKey)).value;
    if (index == null) return const SizedBox.shrink();
    final unread = index.readable
        .where((chapter) => !signals.state.readChapters.contains(chapter.id))
        .toList(growable: false);
    final pages =
        unread.fold<int>(0, (sum, chapter) => sum + chapter.pageCount);
    final next = _nextExpected(index.chapters);
    if (pages == 0 && next == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          if (pages > 0)
            Expanded(
              child: KStatCard(
                icon: LucideIcons.hourglass,
                label: context.l10n.seriesPaceToRead,
                value: _time(context.l10n, pages / _pagesPerMinute),
                caption: context.l10n.seriesPaceCaption(unread.length, pages),
              ),
            ),
          if (pages > 0 && next != null) const SizedBox(width: 10),
          if (next != null)
            Expanded(
              child: KStatCard(
                icon: LucideIcons.calendarClock,
                label: context.l10n.seriesPaceNext,
                value: _when(context.l10n, next),
                caption: context.l10n.seriesPaceNextCaption,
              ),
            ),
        ],
      ),
    );
  }

  static String _time(AppLocalizations l10n, double minutes) {
    if (minutes < 60) return l10n.seriesDurationMinutes(minutes.round());
    final hours = minutes / 60;
    if (hours < 24) return l10n.seriesDurationHours(hours.round());
    return l10n.seriesDurationDays((hours / 24).round());
  }

  /// Quando ci si aspetta il prossimo capitolo, dalla cadenza con cui sono
  /// arrivati gli ultimi: su una serie settimanale è l'informazione che dice
  /// se vale la pena riaprire l'app domani.
  static DateTime? _nextExpected(List<ChapterEntry> chapters) {
    final dates = chapters
        .map((chapter) => chapter.archivedAt ?? chapter.publishedAt)
        .nonNulls
        .toList()
      ..sort();
    if (dates.length < 4) return null;
    final recent = dates.sublist(dates.length > 10 ? dates.length - 10 : 0);
    final gaps = <int>[
      for (var i = 1; i < recent.length; i++)
        recent[i].difference(recent[i - 1]).inHours,
    ]..sort();
    if (gaps.isEmpty) return null;
    final median = gaps[gaps.length ~/ 2];
    // Una cadenza sotto il giorno o sopra i due mesi non è una cadenza: è un
    // archivio scaricato tutto insieme, o una serie ferma.
    if (median < 24 || median > 24 * 60) return null;
    return recent.last.add(Duration(hours: median));
  }

  static String _when(AppLocalizations l10n, DateTime expected) {
    final days = expected.difference(DateTime.now().toUtc()).inDays;
    if (days < -14) return l10n.seriesWhenLate;
    if (days < 0) return l10n.seriesWhenExpected;
    if (days == 0) return l10n.seriesWhenToday;
    if (days == 1) return l10n.seriesWhenTomorrow;
    if (days < 14) return l10n.seriesWhenInDays(days);
    return l10n.seriesWhenInWeeks((days / 7).round());
  }
}

/// La sinossi, tagliata a quattro righe con il suo "leggi tutto": una
/// descrizione lunga fra il titolo e i capitoli allontana i capitoli.
class _Description extends StatefulWidget {
  const _Description({required this.text});

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: KagamiType.body(14, height: 1.5),
            ),
          ),
          const SizedBox(height: 6),
          KPress(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded
                      ? context.l10n.seriesShowLess
                      : context.l10n.seriesShowMore,
                  style: KagamiType.label(
                    size: 13,
                    color: context.colors.primary,
                  ),
                ),
                Icon(
                  _expanded
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 16,
                  color: context.colors.primary,
                ),
              ],
            ),
          ),
        ],
      );
}

class _ChapterHeader extends StatefulWidget {
  const _ChapterHeader({
    required this.total,
    required this.archived,
    required this.shown,
    required this.newestFirst,
    required this.onlyUnread,
    required this.onlyDownloaded,
    required this.blocks,
    required this.jump,
    required this.onJump,
    required this.onQuery,
    required this.onToggleOrder,
    required this.onToggleUnread,
    required this.onToggleDownloaded,
    required this.onMarkAll,
    required this.onDownloadAll,
    required this.cleanup,
    required this.onCleanup,
  });

  final int total;
  final int archived;
  final int shown;
  final bool newestFirst;
  final bool onlyUnread;
  final bool onlyDownloaded;
  final List<(int, int)> blocks;
  final int? jump;
  final ValueChanged<int?> onJump;
  final ValueChanged<String> onQuery;
  final VoidCallback onToggleOrder;
  final VoidCallback onToggleUnread;
  final VoidCallback onToggleDownloaded;
  final VoidCallback? onMarkAll;

  /// Scarica tutti i capitoli che si leggono da Drive; `null` se non ce ne
  /// sono.
  final VoidCallback? onDownloadAll;

  /// Quanto occupano sul telefono i capitoli già letti, detto in una riga;
  /// `null` se non occupano niente.
  final String? cleanup;
  final VoidCallback onCleanup;

  @override
  State<_ChapterHeader> createState() => _ChapterHeaderState();
}

class _ChapterHeaderState extends State<_ChapterHeader> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(context.l10n.seriesChaptersTitle, style: KagamiType.display(19)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${widget.archived}',
                  style:
                      KagamiType.figure(12, color: context.colors.primary),
                ),
              ),
              const Spacer(),
              if (widget.archived != widget.total)
                Text(
                  context.l10n.seriesChaptersOf(widget.total),
                  style: KagamiType.label(size: 12, color: muted),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onQuery,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: context.l10n.seriesSearchChapter,
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              KIconAction(
                icon: widget.newestFirst
                    ? LucideIcons.arrowDownWideNarrow
                    : LucideIcons.arrowUpWideNarrow,
                tooltip: widget.newestFirst
                    ? context.l10n.seriesSortNewest
                    : context.l10n.seriesSortOldest,
                onPressed: widget.onToggleOrder,
              ),
              const SizedBox(width: 8),
              KIconAction(
                icon: LucideIcons.checkCheck,
                tooltip: context.l10n.seriesMarkAll,
                onPressed: widget.onMarkAll,
              ),
              if (widget.onDownloadAll != null) ...[
                const SizedBox(width: 8),
                KIconAction(
                  icon: LucideIcons.cloudDownload,
                  tooltip: context.l10n.seriesDownloadFromDrive,
                  onPressed: widget.onDownloadAll,
                ),
              ],
            ],
          ),
          if (widget.cleanup case final cleanup?) ...[
            const SizedBox(height: 10),
            KPress(
              onTap: widget.onCleanup,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(LucideIcons.hardDrive, size: 15, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cleanup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KagamiType.label(size: 12, color: muted),
                      ),
                    ),
                    Text(
                      context.l10n.seriesFreeSpace,
                      style: KagamiType.label(
                        size: 12,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          KChipBar(
            children: [
              KChip(
                label: context.l10n.seriesFilterUnread,
                active: widget.onlyUnread,
                onTap: widget.onToggleUnread,
              ),
              KChip(
                label: context.l10n.seriesFilterDownloaded,
                active: widget.onlyDownloaded,
                onTap: widget.onToggleDownloaded,
              ),
              // Il salto esiste solo sulle serie lunghe: sotto il blocco
              // l'elenco si scorre e basta.
              if (widget.blocks.isNotEmpty) ...[
                KChip(
                  label: context.l10n.seriesFilterAll,
                  active: widget.jump == null,
                  onTap: () => widget.onJump(null),
                ),
                for (var i = 0; i < widget.blocks.length; i++)
                  KChip(
                    label: '${widget.blocks[i].$1}–${widget.blocks[i].$2}',
                    active: widget.jump == i,
                    onTap: () => widget.onJump(i),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Le azioni sui capitoli selezionati.
class _ChapterSelectionBar extends StatelessWidget {
  const _ChapterSelectionBar({
    required this.count,
    required this.onRead,
    required this.onUnread,
    required this.onReadThrough,
    required this.onDownload,
    required this.onClear,
  });

  final int count;
  final VoidCallback onRead;
  final VoidCallback onUnread;
  final VoidCallback onReadThrough;
  final VoidCallback? onDownload;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        color: context.colors.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(LucideIcons.x),
                ),
                Expanded(
                  child: Text(
                    context.l10n.seriesSelectedCount(count),
                    style: KagamiType.title(14.5),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.seriesMarkReadMany,
                  onPressed: onRead,
                  icon: const Icon(LucideIcons.check),
                ),
                IconButton(
                  tooltip: context.l10n.seriesMarkUnread,
                  onPressed: onUnread,
                  icon: const Icon(LucideIcons.undo2),
                ),
                IconButton(
                  tooltip: context.l10n.seriesMarkReadThrough,
                  onPressed: onReadThrough,
                  icon: const Icon(LucideIcons.listChecks),
                ),
                if (onDownload != null)
                  IconButton(
                    tooltip: context.l10n.seriesDownloadFromDrive,
                    onPressed: onDownload,
                    icon: const Icon(LucideIcons.cloudDownload),
                  ),
              ],
            ),
          ),
        ),
      );
}

/// Serie della libreria che condividono generi e tag con questa: il modo di
/// dire "altre così" senza chiedere niente a nessuno.
class _Similar extends ConsumerWidget {
  const _Similar({required this.seriesKey});

  final String seriesKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final me = ref.watch(seriesEntryProvider(seriesKey));
    if (library == null || me == null) return const SizedBox.shrink();
    final mine = {...me.genres, ...me.tags};
    if (mine.isEmpty) return const SizedBox.shrink();

    final scored = <(SeriesSignals, int)>[];
    for (final signals in ref.watch(librarySignalsProvider)) {
      if (signals.entry.key == seriesKey) continue;
      final shared = {...signals.entry.genres, ...signals.entry.tags}
          .where(mine.contains)
          .length;
      if (shared > 0) scored.add((signals, shared));
    }
    if (scored.isEmpty) return const SizedBox.shrink();
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final series = [for (final row in scored.take(12)) row.$1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: KSection(context.l10n.seriesSimilar),
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: series.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, position) => SizedBox(
              width: 108,
              child: SeriesCover(
                signals: series[position],
                onTap: () => Navigator.of(context).pushReplacement(
                  seriesRoute(series[position].entry.key),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.read,
    required this.selected,
    required this.selecting,
    required this.progress,
    required this.onTap,
    required this.onToggleRead,
    required this.onLongPress,
    this.fromDrive = false,
    this.download,
    this.onDownload,
    this.onCancelDownload,
  });

  final ChapterEntry chapter;

  /// Si legge da Drive: lo dice l'icona accanto al titolo, e il pulsante in
  /// fondo lo porta sul telefono.
  final bool fromDrive;
  final DownloadProgress? download;
  final VoidCallback? onDownload;
  final VoidCallback? onCancelDownload;
  final bool read;
  final bool selected;
  final bool selecting;
  final ReadingProgress? progress;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    // Un capitolo annunciato dal provider e non ancora scaricato resta in
    // elenco, spento: su una serie in corso è la normalità, non un difetto.
    final available = chapter.isReadable;
    final dim = read || !available;
    final l10n = context.l10n;
    final subtitle = <String>[
      if (!available) l10n.seriesChapterNotDownloaded,
      if (fromDrive) l10n.seriesPlaceDrive,
      if (chapter.archivedAt != null)
        _shortDate(l10n, chapter.archivedAt!),
      if (available && chapter.pageCount > 0)
        l10n.seriesChapterPages(chapter.pageCount),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: KPress(
        onTap: available || selecting ? onTap : null,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.18)
                : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 26,
                child: progress != null && !read
                    ? CircularProgressIndicator(
                        value: progress!.fraction,
                        strokeWidth: 3,
                      )
                    : Icon(
                        available
                            ? (read
                                ? LucideIcons.circleCheck
                                : LucideIcons.circle)
                            : LucideIcons.cloudDownload,
                        size: 20,
                        color: read ? scheme.primary : muted,
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (fromDrive) ...[
                          Icon(LucideIcons.cloud, size: 14, color: muted),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            chapter.label(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KagamiType.title(
                              14.5,
                              weight: read ? 500 : 600,
                              color: dim ? muted : scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: KagamiType.label(size: 11.5, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selecting && download != null)
                _DownloadState(
                  progress: download!,
                  onCancel: onCancelDownload,
                  onRetry: onDownload,
                )
              else if (!selecting && onDownload != null)
                _TileAction(
                  label: context.l10n.seriesDownloadToPhone,
                  onTap: onDownload,
                  child: Icon(LucideIcons.download, size: 18, color: muted),
                ),
              if (available && !selecting)
                _TileAction(
                  label: read
                      ? context.l10n.seriesMarkUnread
                      : context.l10n.seriesMarkRead,
                  onTap: onToggleRead,
                  child: Icon(
                    read ? LucideIcons.undo2 : LucideIcons.check,
                    size: 18,
                    color: muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(AppLocalizations l10n, DateTime value) =>
      DateFormat.yMd(l10n.localeName).format(value.toLocal());
}
