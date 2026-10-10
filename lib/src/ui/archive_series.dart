/// La serie appena letta dal sito: cosa scaricarne, dove e con che ritmo.
///
/// Una pagina intera e non un foglio: su una serie da trecento capitoli la
/// scelta dei capitoli è la parte lunga, e deve poter scorrere quanto la
/// serie. In fondo resta sempre il riepilogo con il pulsante, così si sa cosa
/// partirà senza tornare su.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:intl/intl.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/names.dart';
import 'package:kagami_archive/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/read_ahead.dart';
import '../format/reading.dart';
import '../l10n.dart';
import '../providers.dart';
import 'series_screen.dart' show shelfIcons, shelfLabels, showRatingSheet;
import 'theme.dart';
import 'widgets/kit.dart';

/// Dove va una serie: una delle destinazioni del telefono, o il server.
enum ArchiveWhere {
  server,
  drive,
  driveAndPhone,
  phone;

  /// La destinazione della coda del telefono; `null` per il server, che ha
  /// la sua.
  ArchiveDestination? get local => switch (this) {
        server => null,
        drive => ArchiveDestination.drive,
        driveAndPhone => ArchiveDestination.driveAndPhone,
        phone => ArchiveDestination.phone,
      };

  String label(AppLocalizations l10n) => switch (this) {
        server => l10n.archiveWhereServer,
        drive => l10n.archiveWhereDrive,
        driveAndPhone => l10n.archiveWhereDriveAndPhone,
        phone => l10n.archiveWherePhone,
      };

  IconData get icon => switch (this) {
        server => LucideIcons.server,
        drive => LucideIcons.cloud,
        driveAndPhone => LucideIcons.cloudDownload,
        phone => LucideIcons.smartphone,
      };
}

enum ArchiveMode {
  all,
  from,
  ahead,
  pick,

  /// Solo la scheda: la serie in libreria senza capitoli, con lo stato
  /// dell'utente.
  card,
}

/// La scheda dell'utente scelta con [ArchiveMode.card]: si scrive nei dati
/// personali appena il lavoro è in coda.
class ArchiveCard {
  const ArchiveCard({
    this.status = ShelfStatus.none,
    this.rating,
    this.notes = '',
    this.favorite = false,
    this.reachedId,
  });

  final ShelfStatus status;
  final int? rating;
  final String notes;
  final bool favorite;

  /// L'ultimo capitolo letto altrove; `null`, non ancora iniziata.
  final String? reachedId;
}

/// Cosa si è scelto: è un lavoro della coda senza ancora id e destinazione
/// risolta.
class ArchiveChoice {
  const ArchiveChoice({
    required this.where,
    required this.delayMs,
    this.start,
    this.ids,
    this.ahead,
    this.card,
  });

  /// Solo la scheda: [ids] vuoto, nessun capitolo, e lo stato da scrivere.
  const ArchiveChoice.card({required this.where, required ArchiveCard this.card, this.delayMs = 200})
      : start = null,
        ids = const {},
        ahead = null;

  final ArchiveWhere where;
  final int delayMs;

  /// Dal capitolo con questo id in poi.
  final String? start;

  /// Solo questi capitoli.
  final Set<String>? ids;

  /// Scaricando man mano: quanti capitoli tenere pronti.
  final int? ahead;

  final ArchiveCard? card;
}

String archiveStatusLabel(AppLocalizations l10n, Object? value) => switch (value) {
      'ongoing' => l10n.archiveStatusOngoing,
      'completed' => l10n.archiveStatusCompleted,
      'hiatus' => l10n.archiveStatusHiatus,
      'cancelled' => l10n.archiveStatusCancelled,
      _ => l10n.archiveStatusUnknown,
    };

/// L'indice in [chapters] (dal più vecchio) dell'ultimo capitolo letto, per
/// precompilare il punto a cui si è arrivati e il capitolo da cui partire;
/// -1 se non lo si sa.
///
/// Vale, nell'ordine: il capitolo del link incollato ([linkedId]), l'ultimo
/// dei capitoli segnati letti ([read]), il numero dichiarato
/// ([reachedNumber], `SeriesState.reachedChapter`). Il numero si confronta
/// per valore, e prende l'ultimo capitolo che non lo supera: dichiarato il
/// 52 su un sito che salta dal 51 al 53, si è arrivati al 51.
int reachedChapterIndex(
  List<Chapter> chapters, {
  String? linkedId,
  Set<String> read = const {},
  String? reachedNumber,
}) {
  if (linkedId != null) {
    final linked = chapters.indexWhere((chapter) => chapter.id == linkedId);
    if (linked >= 0) return linked;
  }
  final last = chapters.lastIndexWhere((chapter) => read.contains(chapter.id));
  if (last >= 0) return last;
  final number = reachedNumber?.trim();
  if (number == null || number.isEmpty) return -1;
  final value = double.tryParse(number.replaceAll(',', '.'));
  if (value == null) return chapters.lastIndexWhere((chapter) => chapter.number == number);
  return chapters.lastIndexWhere((chapter) {
    final own = double.tryParse(chapter.number);
    return own != null && own <= value;
  });
}

class ArchiveSeriesPage extends ConsumerStatefulWidget {
  const ArchiveSeriesPage({
    required this.series,
    required this.metadata,
    required this.destinations,
    required this.destination,
    required this.delayMs,
    required this.serverHint,
    this.serverAhead = false,
    this.mode = ArchiveMode.all,
    this.start,
    this.picked = const {},
    this.linkedChapterId,
    this.stateKey,
    super.key,
  });

  final Series series;
  final Map<String, Object?> metadata;
  final List<ArchiveWhere> destinations;
  final ArchiveWhere destination;
  final int delayMs;

  /// Cosa fa il server con la serie: lo sa chi conosce il server.
  final String serverHint;

  /// Il server collegato sa scaricare man mano: le serie le segue lui, i
  /// capitoli seguenti glieli chiede l'app.
  final bool serverAhead;

  /// La scelta con cui la pagina si apre: la modalità, il capitolo da cui
  /// partire (se manca, quello che la modalità propone) e i capitoli già
  /// spuntati per [ArchiveMode.pick].
  final ArchiveMode mode;
  final String? start;
  final Set<String> picked;

  /// Il capitolo del link incollato: per la pagina è l'ultimo letto.
  final String? linkedChapterId;

  /// La chiave da cui prendere stato, voto, nota e punto di lettura con cui
  /// la pagina si apre, se non è quella della serie: collegando una scheda
  /// manuale, sono i suoi.
  final String? stateKey;

  static Future<ArchiveChoice?> open(
    BuildContext context, {
    required Series series,
    required Map<String, Object?> metadata,
    required List<ArchiveWhere> destinations,
    required ArchiveWhere destination,
    required int delayMs,
    required String serverHint,
    bool serverAhead = false,
    ArchiveMode mode = ArchiveMode.all,
    String? start,
    Set<String> picked = const {},
    String? linkedChapterId,
    String? stateKey,
  }) =>
      Navigator.of(context).push<ArchiveChoice>(MaterialPageRoute(
        builder: (_) => ArchiveSeriesPage(
          series: series,
          metadata: metadata,
          destinations: destinations,
          destination: destination,
          delayMs: delayMs,
          serverHint: serverHint,
          serverAhead: serverAhead,
          mode: mode,
          start: start,
          picked: picked,
          linkedChapterId: linkedChapterId,
          stateKey: stateKey,
        ),
      ));

  @override
  ConsumerState<ArchiveSeriesPage> createState() => _ArchiveSeriesPageState();
}

class _ArchiveSeriesPageState extends ConsumerState<ArchiveSeriesPage> {
  static const List<int> _delays = [0, 200, 500, 1000, 2000];

  final TextEditingController _search = TextEditingController();

  late ArchiveMode _mode = widget.mode;
  late String? _start = widget.start;
  late final Set<String> _picked = {...widget.picked};

  /// L'ultimo capitolo toccato scegliendoli uno per uno: un tocco lungo
  /// prende tutti quelli fra lui e il capitolo premuto.
  String? _anchor;
  bool _newestFirst = false;
  bool _advanced = false;
  late ArchiveWhere _where = widget.destination;
  late int _delayMs = widget.delayMs;

  /// La scheda: l'ultimo capitolo letto e i campi del ripiano, partendo da
  /// ciò che i dati personali sanno già di questa serie.
  String? _reached;
  late final SeriesState _known = ref.read(seriesStateProvider(widget.stateKey ?? widget.series.key));
  late ShelfStatus _status = _known.status;
  late int? _rating = _known.rating;
  late bool _favorite = _known.favorite;
  late final TextEditingController _notes = TextEditingController(text: _known.notes ?? '');

  List<Chapter> get _chapters => widget.series.chapters;

  /// Scarica il server, se fra le destinazioni c'è lui: allora i capitoli
  /// vanno solo a lui.
  bool get _serverOnly => widget.destinations.contains(ArchiveWhere.server);

  bool get _needsBrowser => providerById(widget.series.provider)?.needsBrowser ?? false;

  /// Man mano ripete da solo le richieste al sito, ogni volta che si legge:
  /// non con un sito che vuole la verifica del browser. E non con un server
  /// di prima, che non lo sa fare: il telefono non segue le serie mentre
  /// scarica il server.
  bool get _aheadPossible => !_needsBrowser && (!_serverOnly || widget.serverAhead);

  /// Le schede le scrive sempre il telefono.
  bool get _serverExcluded => _mode == ArchiveMode.card;

  List<ArchiveWhere> get _destinations => _serverExcluded
      ? [for (final where in widget.destinations) if (where != ArchiveWhere.server) where]
      : _serverOnly
          ? const [ArchiveWhere.server]
          : widget.destinations;

  @override
  void initState() {
    super.initState();
    if (_mode == ArchiveMode.ahead && !_aheadPossible) _mode = ArchiveMode.all;
    final reached = _reachedIndex();
    if (reached >= 0) _reached = _chapters[reached].id;
    if ((_mode == ArchiveMode.from || _mode == ArchiveMode.ahead) && _start == null) {
      _start = _defaultStart(_mode, _have(watch: false));
    }
    if (!_destinations.contains(_where)) _where = _destinations.first;
  }

  @override
  void dispose() {
    _search.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _startIndex {
    final start = _start;
    if (start == null) return -1;
    return _chapters.indexWhere((chapter) => chapter.id == start);
  }

  /// I capitoli già nella libreria, leggibili da qualche parte.
  Set<String> _have({bool watch = true}) {
    final provider = seriesChaptersProvider(widget.series.key);
    final chapters = (watch ? ref.watch(provider) : ref.read(provider)).value;
    return {
      for (final chapter in chapters?.index.chapters ?? const [])
        if (chapter.isReadable) chapter.id,
    };
  }

  /// L'ultimo capitolo letto, come lo sa [reachedChapterIndex].
  int _reachedIndex() {
    final state = ref.read(seriesStateProvider(widget.stateKey ?? widget.series.key));
    return reachedChapterIndex(
      _chapters,
      linkedId: widget.linkedChapterId,
      read: state.readChapters,
      reachedNumber: state.reachedChapter,
    );
  }

  /// Da dove partire se non lo si è ancora detto: man mano, dal primo
  /// capitolo che resta da leggere; dal capitolo, dal primo dopo l'ultimo
  /// letto, o se non se ne sa niente dal primo che manca.
  String? _defaultStart(ArchiveMode mode, Set<String> have) {
    if (mode == ArchiveMode.ahead) {
      final read = ref.read(seriesStateProvider(widget.stateKey ?? widget.series.key)).readChapters;
      final last = _chapters.lastIndexWhere((chapter) => read.contains(chapter.id));
      if (last + 1 < _chapters.length) return _chapters[last + 1].id;
      return _chapters.first.id;
    }
    final reached = _reachedIndex();
    if (reached >= 0 && reached + 1 < _chapters.length) return _chapters[reached + 1].id;
    if (have.isEmpty) return null;
    return _chapters.where((chapter) => !have.contains(chapter.id)).firstOrNull?.id;
  }

  void _choose(ArchiveMode mode, Set<String> have) {
    if (mode == ArchiveMode.ahead && !_aheadPossible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_needsBrowser ? context.l10n.archiveModeAheadUnavailable : context.l10n.archiveModeAheadServer),
        ),
      );
      return;
    }
    setState(() {
      _mode = mode;
      if ((mode == ArchiveMode.from || mode == ArchiveMode.ahead) && _start == null) {
        _start = _defaultStart(mode, have);
      }
      if (!_destinations.contains(_where)) _where = _destinations.first;
    });
  }

  int get _count {
    final start = _startIndex;
    return switch (_mode) {
      ArchiveMode.all => _chapters.length,
      ArchiveMode.from => start < 0 ? 0 : _chapters.length - start,
      ArchiveMode.ahead => start < 0 ? 0 : math.min(readAheadWindow, _chapters.length - start),
      ArchiveMode.pick => _picked.length,
      ArchiveMode.card => 0,
    };
  }

  int get _reachedPosition {
    final reached = _reached;
    if (reached == null) return -1;
    return _chapters.indexWhere((chapter) => chapter.id == reached);
  }

  void _tap(Chapter chapter) => setState(() {
        if (_mode == ArchiveMode.pick) {
          if (!_picked.remove(chapter.id)) _picked.add(chapter.id);
          _anchor = chapter.id;
        } else if (_mode == ArchiveMode.card) {
          _reached = chapter.id;
        } else {
          _start = chapter.id;
        }
      });

  void _range(Chapter chapter) {
    if (_mode != ArchiveMode.pick) return _tap(chapter);
    final anchor = _anchor == null ? -1 : _chapters.indexWhere((c) => c.id == _anchor);
    final here = _chapters.indexOf(chapter);
    if (anchor < 0) return _tap(chapter);
    setState(() {
      for (var i = math.min(anchor, here); i <= math.max(anchor, here); i++) {
        _picked.add(_chapters[i].id);
      }
      _anchor = chapter.id;
    });
  }

  /// Un numero scritto per intero porta al capitolo: Invio lo sceglie.
  void _submitSearch(String text) {
    if (text.trim().isEmpty) return;
    final int index;
    try {
      index = startIndex(_chapters, text);
    } on ProviderError {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.archiveStartNoMatch)),
      );
      return;
    }
    _tap(_chapters[index]);
    _search.clear();
    setState(() {});
  }

  List<Chapter> _visible() {
    final needle = _search.text.trim().toLowerCase();
    final shown = [
      for (final chapter in _chapters)
        if (needle.isEmpty ||
            chapter.number.toLowerCase().contains(needle) ||
            chapter.title.toLowerCase().contains(needle))
          chapter,
    ];
    return _newestFirst ? shown.reversed.toList() : shown;
  }

  void _confirm() {
    final start = _start;
    final ArchiveChoice choice;
    switch (_mode) {
      case ArchiveMode.all:
        choice = ArchiveChoice(where: _where, delayMs: _delayMs);
      case ArchiveMode.from:
        choice = ArchiveChoice(where: _where, delayMs: _delayMs, start: start);
      case ArchiveMode.ahead:
        final index = _startIndex;
        choice = ArchiveChoice(
          where: _where,
          delayMs: _delayMs,
          ids: {for (final chapter in _chapters.skip(index).take(readAheadWindow)) chapter.id},
          ahead: readAheadWindow,
        );
      case ArchiveMode.pick:
        choice = ArchiveChoice(where: _where, delayMs: _delayMs, ids: {..._picked});
      case ArchiveMode.card:
        choice = ArchiveChoice.card(
          where: _where,
          delayMs: _delayMs,
          card: ArchiveCard(
            status: _status,
            rating: _rating,
            notes: _notes.text.trim(),
            favorite: _favorite,
            reachedId: _reached,
          ),
        );
    }
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final have = _have();
    final visible = _mode == ArchiveMode.all ? const <Chapter>[] : _visible();
    final count = _count;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archiveChooseTitle)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            sliver: SliverList.list(
              children: [
                _Header(series: widget.series, metadata: widget.metadata, have: have.length),
                const SizedBox(height: 26),
                KSection(l10n.archiveWhatSection),
                _Modes(
                  mode: _mode,
                  aheadPossible: _aheadPossible,
                  onChanged: (mode) => _choose(mode, have),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    switch (_mode) {
                      ArchiveMode.all => l10n.archiveModeAllHint,
                      ArchiveMode.from => l10n.archiveModeFromHint,
                      ArchiveMode.ahead => l10n.archiveModeAheadHint(readAheadWindow),
                      ArchiveMode.pick => l10n.archiveModePickHint,
                      ArchiveMode.card => l10n.archiveModeCardHint,
                    },
                    style: KagamiType.body(12.5, height: 1.45, color: context.tokens.muted),
                  ),
                ),
                if (_mode != ArchiveMode.all) ...[
                  const SizedBox(height: 26),
                  _chapterTools(have),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          if (_mode != ArchiveMode.all)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: visible.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          l10n.archiveStartNoMatch,
                          textAlign: TextAlign.center,
                          style: KagamiType.body(13, color: context.tokens.muted),
                        ),
                      ),
                    )
                  : SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, position) {
                        final chapter = visible[position];
                        return _ChapterRow(
                          chapter: chapter,
                          mark: _markOf(chapter),
                          mode: _mode,
                          inLibrary: have.contains(chapter.id),
                          onTap: () => _tap(chapter),
                          onLongPress: () => _range(chapter),
                        );
                      },
                    ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
            sliver: SliverList.list(
              children: [
                if (_mode == ArchiveMode.card) ...[
                  _shelf(),
                  const SizedBox(height: 26),
                ],
                KSection(l10n.archiveWhereSection),
                KGroup(
                  children: [
                    for (final where in _destinations)
                      _WhereTile(
                        where: where,
                        hint: switch (where) {
                          ArchiveWhere.server => widget.serverHint,
                          ArchiveWhere.drive => l10n.archiveWhereDriveHint,
                          ArchiveWhere.driveAndPhone => l10n.archiveWhereDriveAndPhoneHint,
                          ArchiveWhere.phone => l10n.archiveWherePhoneHint,
                        },
                        selected: where == _where,
                        onTap: () => setState(() => _where = where),
                      ),
                  ],
                ),
                if (_serverExcluded && _serverOnly) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l10n.archiveCardServer,
                      style: KagamiType.body(12.5, height: 1.45, color: context.tokens.muted),
                    ),
                  ),
                ],
                // Una scheda chiede al sito una pagina sola: la pausa fra le
                // richieste non ha niente da distanziare.
                if (_mode != ArchiveMode.card) ...[
                  const SizedBox(height: 22),
                  _advancedCard(),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _Summary(
        text: _summary(l10n, count),
        label: switch (_mode) {
          ArchiveMode.all => l10n.archiveDownloadAll,
          ArchiveMode.ahead => l10n.archiveDownloadAhead(count),
          ArchiveMode.card => l10n.archiveSaveCard,
          _ => l10n.archiveDownloadPicked(count),
        },
        icon: _mode == ArchiveMode.card ? LucideIcons.bookmarkPlus : LucideIcons.download,
        onPressed: count == 0 && _mode != ArchiveMode.card ? null : _confirm,
      ),
    );
  }

  String _summary(AppLocalizations l10n, int count) {
    final where = _where.label(l10n);
    final reached = _reachedPosition;
    return switch (_mode) {
      ArchiveMode.card when reached >= 0 =>
        l10n.archiveSummaryCardReached(_numberOf(reached), where),
      ArchiveMode.card => l10n.archiveSummaryCard(where),
      ArchiveMode.ahead => l10n.archiveSummaryAhead(count, where),
      ArchiveMode.from || ArchiveMode.pick when count == 0 =>
        _mode == ArchiveMode.pick ? l10n.archivePickNone : l10n.archiveChooseStart,
      _ => l10n.archiveSummaryChapters(count, where),
    };
  }

  /// Il numero di un capitolo come lo scrive l'autore; senza, il suo posto
  /// nell'elenco, come fa `Reading.setReachedThrough`.
  String _numberOf(int index) {
    final number = _chapters[index].number;
    return number.isEmpty ? '${index + 1}' : number;
  }

  _Mark _markOf(Chapter chapter) {
    final index = _chapters.indexOf(chapter);
    final start = _startIndex;
    if (_mode == ArchiveMode.card) {
      final reached = _reachedPosition;
      return index == reached
          ? _Mark.reached
          : index < reached
              ? _Mark.read
              : _Mark.none;
    }
    return switch (_mode) {
      ArchiveMode.all || ArchiveMode.card => _Mark.included,
      ArchiveMode.pick => _picked.contains(chapter.id) ? _Mark.included : _Mark.none,
      ArchiveMode.from => start < 0 || index < start
          ? _Mark.none
          : index == start
              ? _Mark.start
              : _Mark.included,
      ArchiveMode.ahead => start < 0 || index < start
          ? _Mark.none
          : index == start
              ? _Mark.start
              : index < start + readAheadWindow
                  ? _Mark.included
                  : _Mark.later,
    };
  }

  Widget _chapterTools(Set<String> have) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KSection(
          _mode == ArchiveMode.card ? l10n.archiveReachedSection : l10n.archiveChaptersCount(_chapters.length),
          trailing: IconButton(
            tooltip: _newestFirst ? l10n.archiveOldestFirst : l10n.archiveNewestFirst,
            visualDensity: VisualDensity.compact,
            icon: Icon(_newestFirst ? LucideIcons.arrowUpWideNarrow : LucideIcons.arrowDownNarrowWide, size: 18),
            onPressed: () => setState(() => _newestFirst = !_newestFirst),
          ),
        ),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: _submitSearch,
          decoration: InputDecoration(
            hintText: l10n.archiveChapterSearch,
            prefixIcon: const Icon(LucideIcons.search, size: 18),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.archiveClear,
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        if (_mode == ArchiveMode.pick)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KChip(
                label: l10n.archiveSelectAll,
                icon: LucideIcons.checkCheck,
                onTap: () => setState(() => _picked.addAll(_chapters.map((c) => c.id))),
              ),
              if (have.isNotEmpty)
                KChip(
                  label: l10n.archiveSelectMissing,
                  icon: LucideIcons.cloudDownload,
                  onTap: () => setState(() => _picked
                    ..clear()
                    ..addAll([for (final c in _chapters) if (!have.contains(c.id)) c.id])),
                ),
              KChip(
                label: l10n.archiveSelectNone,
                icon: LucideIcons.eraser,
                onTap: () => setState(_picked.clear),
              ),
            ],
          )
        else if (_mode == ArchiveMode.card)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KChip(
                label: l10n.archiveReachedNone,
                icon: LucideIcons.circleDashed,
                active: _reached == null,
                onTap: () => setState(() => _reached = null),
              ),
              Text(l10n.archiveReachedHint, style: KagamiType.body(12.5, height: 1.4, color: muted)),
            ],
          )
        else
          Text(l10n.archiveChooseStart, style: KagamiType.body(12.5, color: muted)),
        if (_mode == ArchiveMode.pick) ...[
          const SizedBox(height: 8),
          Text(l10n.archiveRangeHint, style: KagamiType.body(12, height: 1.4, color: muted)),
        ],
      ],
    );
  }

  Widget _shelf() => ArchiveShelfFields(
        status: _status,
        favorite: _favorite,
        rating: _rating,
        notes: _notes,
        onStatus: (value) => setState(() => _status = value),
        onFavorite: () => setState(() => _favorite = !_favorite),
        onRating: (value) => setState(() => _rating = value),
      );

  Widget _advancedCard() {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    final pause = _delayMs == 0
        ? l10n.archiveDelayNone
        : l10n.archiveDelaySeconds(NumberFormat.decimalPattern(l10n.localeName).format(_delayMs / 1000));
    return KCard(
      padding: EdgeInsets.zero,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KTile(
              icon: LucideIcons.slidersHorizontal,
              title: l10n.archiveAdvanced,
              subtitle: l10n.archiveAdvancedLine(pause),
              trailing: Icon(_advanced ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18),
              onTap: () => setState(() => _advanced = !_advanced),
            ),
            if (_advanced)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KSection(l10n.archiveDelaySection, padding: const EdgeInsets.fromLTRB(4, 4, 4, 10)),
                    KSegmented(
                      options: [
                        for (final ms in _delays)
                          ms == 0
                              ? l10n.archiveDelayNone
                              : l10n.archiveDelaySeconds(
                                  NumberFormat.decimalPattern(l10n.localeName).format(ms / 1000)),
                      ],
                      index: math.max(0, _delays.indexOf(_delayMs)),
                      onChanged: (index) => setState(() => _delayMs = _delays[index]),
                    ),
                    const SizedBox(height: 10),
                    Text(l10n.archiveDelayHint, style: KagamiType.body(12.5, height: 1.45, color: muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Copertina, titolo e quello che il sito dice della serie.
class _Header extends StatelessWidget {
  const _Header({required this.series, required this.metadata, required this.have});

  final Series series;
  final Map<String, Object?> metadata;
  final int have;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    final placeholder = ColoredBox(color: muted.withValues(alpha: .15));
    final authors = (metadata['authors'] as List).cast<String>();
    final tags = [...(metadata['genres'] as List).cast<String>(), ...(metadata['tags'] as List).cast<String>()];
    final provider = providerById(series.provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 138,
                child: series.coverUrl == null
                    ? placeholder
                    : Image.network(
                        series.coverUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 288,
                        headers: {'Referer': series.url, 'User-Agent': defaultUserAgent},
                        errorBuilder: (_, _, _) => placeholder,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(series.title, style: KagamiType.display(19)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (provider != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.asset(provider.icon, width: 16, height: 16),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          l10n.archiveSeriesSummary(
                            provider?.name ?? series.provider,
                            series.chapters.length,
                            archiveStatusLabel(l10n, metadata['releaseStatus']),
                          ),
                          style: KagamiType.body(12.5, color: muted),
                        ),
                      ),
                    ],
                  ),
                  if (authors.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(authors.take(3).join(', '), style: KagamiType.body(12.5, color: muted)),
                  ],
                  if (have > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.libraryBig, size: 13, color: context.colors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.archiveInLibraryCount(have, series.chapters.length),
                              style: KagamiType.label(size: 12, color: context.colors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [for (final tag in tags.take(8)) KTag(label: tag, dense: true)],
          ),
        ],
      ],
    );
  }
}

/// Le cinque scelte in tre file: si vedono tutte insieme, con quello che
/// fanno scritto sotto il nome.
class _Modes extends StatelessWidget {
  const _Modes({required this.mode, required this.aheadPossible, required this.onChanged});

  final ArchiveMode mode;
  final bool aheadPossible;
  final ValueChanged<ArchiveMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget card(ArchiveMode value, IconData icon, String title, String line, {bool enabled = true}) => Expanded(
          child: _ModeCard(
            icon: icon,
            title: title,
            line: line,
            selected: mode == value,
            enabled: enabled,
            onTap: () => onChanged(value),
          ),
        );
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card(ArchiveMode.all, LucideIcons.library, l10n.archiveModeAll, l10n.archiveModeAllLine),
              const SizedBox(width: 10),
              card(ArchiveMode.ahead, LucideIcons.sparkles, l10n.archiveModeAhead,
                  l10n.archiveModeAheadLine(readAheadWindow),
                  enabled: aheadPossible),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card(ArchiveMode.from, LucideIcons.skipForward, l10n.archiveModeFrom, l10n.archiveModeFromLine),
              const SizedBox(width: 10),
              card(ArchiveMode.pick, LucideIcons.listChecks, l10n.archiveModePick, l10n.archiveModePickLine),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card(ArchiveMode.card, LucideIcons.bookmark, l10n.archiveModeCard, l10n.archiveModeCardLine),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.line,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String line;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final foreground = selected ? scheme.primary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: KPress(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
            decoration: BoxDecoration(
              color: selected ? scheme.primary.withValues(alpha: .13) : scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: foreground),
                    const Spacer(),
                    if (selected) Icon(LucideIcons.circleCheck, size: 16, color: scheme.primary),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: KagamiType.title(14.5, color: foreground)),
                const SizedBox(height: 3),
                Text(line, style: KagamiType.body(12, height: 1.35, color: context.tokens.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Che parte ha un capitolo in quello che si sta per scaricare.
enum _Mark {
  none,

  /// Il capitolo da cui si parte.
  start,
  included,

  /// Man mano: arriverà, ma solo leggendo.
  later,

  /// La scheda: l'ultimo capitolo letto, e quelli prima di lui.
  reached,
  read,
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.mark,
    required this.mode,
    required this.inLibrary,
    required this.onTap,
    required this.onLongPress,
  });

  final Chapter chapter;
  final _Mark mark;
  final ArchiveMode mode;
  final bool inLibrary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static String _badge(Chapter chapter) =>
      chapter.number.isNotEmpty && chapter.number.length <= 6 ? chapter.number : '·';

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final l10n = context.l10n;
    final strong = mark == _Mark.start || mark == _Mark.included || mark == _Mark.reached;
    final date = chapter.metadata['date'];
    final details = [
      if (date is String && date.isNotEmpty) date,
      if (inLibrary) l10n.archiveChapterInLibrary,
      if (mark == _Mark.start) l10n.archiveChapterStart,
      if (mark == _Mark.later) l10n.archiveChapterLater,
      if (mark == _Mark.reached) l10n.archiveChapterReached,
    ].join(' · ');
    final trailing = switch ((mode, mark)) {
      (ArchiveMode.pick, _Mark.included) => Icon(LucideIcons.squareCheck, size: 20, color: scheme.primary),
      (ArchiveMode.pick, _) => Icon(LucideIcons.square, size: 20, color: muted),
      (_, _Mark.start) => Icon(LucideIcons.circleDot, size: 20, color: scheme.primary),
      (_, _Mark.included) => Icon(LucideIcons.download, size: 17, color: scheme.primary),
      (_, _Mark.later) => Icon(LucideIcons.hourglass, size: 16, color: muted),
      (_, _Mark.reached) => Icon(LucideIcons.bookmarkCheck, size: 19, color: scheme.primary),
      (_, _Mark.read) => Icon(LucideIcons.check, size: 17, color: muted),
      _ => const SizedBox(width: 20),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: switch (mark) {
          _Mark.start || _Mark.reached => scheme.primary.withValues(alpha: .16),
          _Mark.included => scheme.primary.withValues(alpha: .08),
          _Mark.read => scheme.primary.withValues(alpha: .04),
          _ => Colors.transparent,
        },
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: strong ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _badge(chapter),
                    style: KagamiType.label(size: 12.5, color: strong ? scheme.onPrimary : scheme.onSurface),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KagamiType.body(
                          13.5,
                          weight: 600,
                          color: mark == _Mark.none || mark == _Mark.later ? muted : scheme.onSurface,
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (inLibrary) ...[
                              Icon(LucideIcons.circleCheck, size: 12, color: muted),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                details,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KagamiType.body(11.5, color: muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhereTile extends StatelessWidget {
  const _WhereTile({
    required this.where,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final ArchiveWhere where;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return KPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (selected ? scheme.primary : scheme.onSurface).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(where.icon, size: 18, color: selected ? scheme.primary : scheme.onSurface),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    where.label(context.l10n),
                    style: KagamiType.title(14.5, color: selected ? scheme.primary : scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(hint, style: KagamiType.body(12.5, height: 1.4, color: context.tokens.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: 20,
              color: selected ? scheme.primary : context.tokens.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Il riepilogo che resta in fondo: cosa partirà, e il pulsante.
class _Summary extends StatelessWidget {
  const _Summary({required this.text, required this.label, required this.icon, required this.onPressed});

  final String text;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceContainer,
          border: Border(top: BorderSide(color: context.tokens.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KagamiType.body(12.5, color: context.tokens.muted),
                ),
                const SizedBox(height: 10),
                KButton(label: label, icon: icon, expand: true, onPressed: onPressed),
              ],
            ),
          ),
        ),
      );
}

/// I campi del ripiano della scheda (`_Shelf` in `series_screen.dart`), da
/// riempire prima che la serie sia in libreria: stato, preferito, voto e
/// nota. Li tiene chi li usa.
class ArchiveShelfFields extends StatelessWidget {
  const ArchiveShelfFields({
    required this.status,
    required this.favorite,
    required this.rating,
    required this.notes,
    required this.onStatus,
    required this.onFavorite,
    required this.onRating,
    super.key,
  });

  final ShelfStatus status;
  final bool favorite;
  final int? rating;
  final TextEditingController notes;
  final ValueChanged<ShelfStatus> onStatus;
  final VoidCallback onFavorite;
  final ValueChanged<int?> onRating;

  Future<void> _rate(BuildContext context) async {
    final chosen = await showRatingSheet(context, rating);
    if (chosen == null) return;
    onRating(chosen < 0 ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KSection(l10n.seriesMyShelf),
        KChipBar(
          children: [
            for (final entry in shelfLabels.entries)
              KChip(
                label: entry.value,
                icon: shelfIcons[entry.key],
                active: entry.key == status,
                onTap: () => onStatus(entry.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KGhostButton(
                label: favorite ? l10n.seriesFavoriteOn : l10n.seriesFavoriteOff,
                icon: LucideIcons.heart,
                expand: true,
                height: 46,
                onPressed: onFavorite,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KGhostButton(
                label: rating == null ? l10n.seriesRatingButton : l10n.seriesRatingOutOfTen(rating!),
                icon: LucideIcons.star,
                expand: true,
                height: 46,
                onPressed: () => _rate(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.archiveCardNotesHint,
            prefixIcon: const Icon(LucideIcons.notebookPen, size: 18),
          ),
        ),
      ],
    );
  }
}
