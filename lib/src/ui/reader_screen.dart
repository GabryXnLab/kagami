/// Il lettore: senza cornice, con ripresa esatta e passaggio al capitolo
/// successivo senza tornare all'elenco.
///
/// Tre vincoli ne decidono la forma:
///   * in modalità continua le tavole stanno attaccate, senza un pixel di
///     margine fra l'una e l'altra: un capitolo è una striscia sola, non un
///     elenco di figure. Lo spazio di scorrimento si riserva dalle dimensioni
///     in `pages.json` e si corregge con quelle vere appena l'immagine è
///     decodificata, perché una stima sbagliata è esattamente ciò che apre un
///     buco fra due tavole;
///   * la striscia è fatta di fasce, non di tavole: una tavola di webtoon
///     intera sarebbe cinquanta megabyte, e la lista ne tiene vive più d'una.
///     Chi le decodifica e chi le tiene stanno in `data/page_decoder.dart` e
///     `ui/page_bands.dart`, e si decodificano solo quelle visibili e le
///     adiacenti;
///   * niente ricostruisce la striscia al ritmo dello scorrimento: la
///     posizione è un valore osservabile, e su disco arriva dopo una pausa;
///   * un capitolo incompleto si apre per le pagine che ci sono.
library;

import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/drive.dart';
import '../data/library.dart';
import '../data/network.dart';
import '../data/page_decoder.dart';
import '../data/phone_tiles.dart';
import '../data/reader_probe.dart';
import '../data/reader_settings.dart';
import '../data/user_repository.dart';
import '../format/malf.dart';
import '../format/reading.dart';
import '../providers.dart';
import 'page_bands.dart';
import 'reader_metrics.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// Ogni quanto la posizione arriva su disco.
///
/// Scorrendo, la posizione cambia a ogni fotogramma. Scriverla subito voleva
/// dire due scritture ogni sette decimi di secondo e, peggio, rifare la
/// fotografia dello stato: la libreria sotto il lettore si riordinava da capo
/// mentre si leggeva. Ora la riga va giù dopo una pausa, e la fotografia si
/// rifà una volta sola quando si esce.
const Duration _progressDelay = Duration(milliseconds: 1500);

/// Quanto aspettano le impostazioni del lettore prima di andare su disco.
const Duration _settingsDelay = Duration(milliseconds: 600);

/// Quanta memoria può occupare il magazzino delle fasce, in schermate.
///
/// Il conto è sulle dimensioni dello schermo perché è lo schermo a dire
/// quanto pesa una schermata: tenerne una decina vuol dire poter tornare
/// indietro di qualche tavola senza ridecodificare niente, e non dipende
/// dall'altezza delle tavole del webtoon di turno.
const int _bandBudgetScreens = 6;

/// Quanto di un capitolo basta perché sia finito. L'ultima tavola è spesso una
/// nota dell'autore che nessuno scorre: aspettarla vorrebbe dire lasciare
/// mezza libreria segnata da leggere.
const double _finishedAt = 0.9;

/// La forma di ogni tavola per la striscia, con le altezze delle tessere
/// dove il capitolo le ha davvero: [tiles] dice quali indirizzi ci sono, e
/// una tavola senza indirizzi di tessere si legge intera o a fasce.
List<PageShape> _pageShapes(
  List<PageEntry> pages,
  int count,
  List<List<String>> tiles,
) =>
    [
      for (var position = 0; position < count; position++)
        position < pages.length
            ? (
                width: pages[position].width,
                height: pages[position].height,
                tiles: position < tiles.length && tiles[position].isNotEmpty
                    ? [for (final tile in pages[position].tiles) tile.height]
                    : const <int>[],
              )
            : (width: null, height: null, tiles: const <int>[]),
    ];

/// Ciò che si scarica da Drive per leggere ogni tavola, nell'ordine: le
/// tessere dove ci sono, altrimenti la tavola.
List<List<String>> _sources(List<String> files, List<List<String>> tiles) => [
      for (var position = 0; position < files.length; position++)
        position < tiles.length && tiles[position].isNotEmpty
            ? tiles[position]
            : [files[position]],
    ];

/// Entra in lettura con una dissolvenza: la tavola prende lo schermo senza uno
/// scorrimento laterale che somigli al voltare pagina.
Future<void> openReader(
  BuildContext context, {
  required String seriesKey,
  required String chapterId,
  int? page,
}) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, _, _) => ReaderScreen(
          seriesKey: seriesKey,
          chapterId: chapterId,
          page: page,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    required this.seriesKey,
    required this.chapterId,
    this.page,
    super.key,
  });

  final String seriesKey;
  final String chapterId;

  /// Da quale pagina aprire, quando ci si arriva da un segnalibro invece che
  /// dalla ripresa.
  final int? page;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late String _chapterId = widget.chapterId;
  ReaderSettings _settings = const ReaderSettings();
  bool _controlsVisible = false;
  bool _rotationLocked = false;
  Timer? _progressTimer;
  Timer? _settingsTimer;
  late final ReaderSettingsStore _settingsStore;

  /// Se le tavole del capitolo aperto sono davvero sul telefono, chiesto una
  /// volta per capitolo.
  String? _checked;
  Future<bool>? _arrival;

  /// Il capitolo di cui si stanno portando giù le tavole da Drive.
  String? _warmed;
  List<List<String>> _warmedFiles = const [];
  int _warmedFrom = 0;

  /// Le prime tavole del capitolo seguente, quando si è vicini alla fine.
  List<String> _warmedAfter = const [];

  /// Se in questa lettura si è già chiesto di segnare letti i precedenti.
  bool _offeredEarlier = false;

  /// La sessione in corso. Serve a sapere quanto tempo si è letto, che nessun
  /// conteggio di capitoli sa dire; il repository si prende all'avvio e non
  /// alla chiusura, perché in `dispose` il `ref` non è più utilizzabile e la
  /// sessione si chiude proprio lì.
  late UserRepository _repository;

  /// Chi tiene la fotografia dei dati personali. Si prende all'avvio perché
  /// in `dispose` il `ref` non è più utilizzabile, ed è lì che la posizione
  /// diventa pubblica.
  late Reading _reading;

  /// L'ultima posizione vista, in attesa di arrivare su disco.
  ReadingSpot? _pending;
  String? _pendingChapter;
  int _pendingCount = 0;

  DateTime? _sessionStart;
  DateTime _lastActivity = DateTime.now().toUtc();
  int _pagesRead = 0;
  bool _incognito = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(userRepositoryProvider);
    _settingsStore = ref.read(readerSettingsProvider);
    _reading = ref.read(readingProvider.notifier);
    _loadSettings();
    _hideSystemBars();
  }

  @override
  void dispose() {
    _flushSettings();
    _flushProgress();
    _progressTimer?.cancel();
    _reading.commitProgress();
    _closeSession();
    PhoneTiles.instance.stop();
    // Le fasce servivano a questa lettura: fuori dal lettore nessuno le
    // guarda più, e sono la parte pesante della memoria dell'app.
    PageBandCache.instance.clear();
    unawaited(WakelockPlus.disable());
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings =
        await ref.read(readerSettingsProvider).forSeries(widget.seriesKey);
    final incognito = await ref.read(incognitoProvider.future);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _incognito = incognito;
    });
    await _applyWakelock();
  }

  /// Le impostazioni cambiano subito sullo schermo e vanno su disco dopo una
  /// pausa: uno slider ne manda decine al secondo, e ognuna erano due
  /// scritture e una chiamata al sistema mentre si trascinava il dito.
  void _saveSettings(ReaderSettings settings) {
    final awake = settings.keepAwake != _settings.keepAwake;
    setState(() => _settings = settings);
    if (awake) unawaited(_applyWakelock());
    _settingsTimer?.cancel();
    _settingsTimer = Timer(_settingsDelay, _flushSettings);
  }

  void _flushSettings() {
    if (_settingsTimer == null) return;
    _settingsTimer!.cancel();
    _settingsTimer = null;
    unawaited(_settingsStore.save(widget.seriesKey, _settings));
  }

  /// Lo schermo non deve spegnersi su una tavola lunga: leggere non conta come
  /// inattività, ma il sistema non ha modo di saperlo.
  Future<void> _applyWakelock() =>
      WakelockPlus.toggle(enable: _settings.keepAwake);

  void _hideSystemBars() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    } else {
      _hideSystemBars();
    }
  }

  void _toggleRotationLock() {
    final locked = !_rotationLocked;
    setState(() => _rotationLocked = locked);
    if (!locked) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      return;
    }
    final size = MediaQuery.sizeOf(context);
    SystemChrome.setPreferredOrientations(
      size.width > size.height
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
  }

  /// Segna che si sta ancora leggendo. Una pausa più lunga del limite chiude
  /// la sessione e ne apre un'altra: il lettore lasciato aperto non è tempo
  /// di lettura.
  void _noteActivity() {
    final now = DateTime.now().toUtc();
    if (_sessionStart == null ||
        now.difference(_lastActivity) > sessionIdleLimit) {
      _closeSession();
      _sessionStart = now;
      _pagesRead = 0;
    }
    _lastActivity = now;
    _pagesRead++;
  }

  void _closeSession() {
    final started = _sessionStart;
    _sessionStart = null;
    if (started == null || _incognito || _pagesRead == 0) return;
    unawaited(
      _repository.logSession(
        seriesKey: widget.seriesKey,
        chapterId: _chapterId,
        startedAt: started,
        endedAt: _lastActivity,
        pagesRead: _pagesRead,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(seriesEntryProvider(widget.seriesKey));
    final library = ref.watch(libraryProvider);
    final chapters = ref.watch(seriesChaptersProvider(widget.seriesKey)).value;
    final index = chapters?.index;
    final pages = ref.watch(pagesIndexProvider(widget.seriesKey)).value;

    if (entry == null || library == null) {
      return const _ReaderMessage('Serie non disponibile.');
    }
    final pagesState = ref.watch(pagesIndexProvider(widget.seriesKey));
    if (chapters != null && pagesState is AsyncData && pages == null) {
      // Le pagine della serie stanno in `pages.json`, e di una serie di Drive
      // mai aperta non ce n'è copia: senza rete non si può impaginare niente.
      return _ReaderMessage(
        NetworkMonitor.instance.isOnline
            ? 'Questa serie non ha un pages.json: vanno rigenerati gli '
                'indici con l\'archiviatore che l\'ha scritta.'
            : 'Senza connessione non si può aprire questa serie: l\'elenco '
                'delle sue tavole è su Drive. Si apre appena torna la rete.',
      );
    }
    if (chapters == null || index == null || pages == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final readable = index.readable.sorted((a, b) => a.order.compareTo(b.order));
    final position = readable.indexWhere((chapter) => chapter.id == _chapterId);
    if (position < 0) {
      return const _ReaderMessage(
        'Questo capitolo non è ancora sul telefono. '
        'La sincronizzazione può essere a metà: riprovare più tardi.',
      );
    }
    final chapter = readable[position];
    final files = library.pagePaths(entry, chapter, pages, chapters);
    if (files.isEmpty) {
      return const _ReaderMessage('Il capitolo non ha pagine leggibili.');
    }
    final tiles = library.tilePaths(entry, chapter, pages, chapters);

    final next = position + 1 < readable.length ? readable[position + 1] : null;
    final previous = position > 0 ? readable[position - 1] : null;
    _sizeBandCache(context);
    if (_warmed != chapter.id) {
      _warmedAfter = const [];
      final sources = _sources(files, tiles);
      RemoteFiles.instance?.rememberChapter(
        widget.seriesKey,
        chapter.id,
        [...files, ...tiles.expand((row) => row)],
      );
      final from = _resumeSpot(chapter.id, files.length).page;
      _warm(chapter.id, sources, from: from);
      _planTiles(files, tiles, pages.of(chapter.id), from: from);
    }

    return FutureBuilder<bool>(
      future: _arrived(chapter.id, files.first),
      // Finché non si sa si apre il lettore: il controllo è una stat sola, e
      // un lampo di messaggio sarebbe peggio dell'attesa.
      builder: (context, arrived) {
        if (arrived.data == false) {
          return const _ReaderMessage(
            'Le tavole di questo capitolo non sono ancora sul telefono. '
            "L'indice le annuncia, i file no: è la cartella sincronizzata a "
            'doverli portare.',
          );
        }
        return Scaffold(
          backgroundColor: switch (_settings.background) {
            ReaderBackground.black => Colors.black,
            ReaderBackground.grey => const Color(0xFF222226),
            ReaderBackground.white => Colors.white,
          },
          body: Stack(
            children: [
              _ChapterView(
                // Cambiando capitolo lo scorrimento va rifatto da zero.
                key: ValueKey(chapter.id),
                files: files,
                tiles: tiles,
                pages: pages.of(chapter.id),
                settings: _settings,
                initialSpot: _resumeSpot(chapter.id, files.length),
                controlsVisible: _controlsVisible,
                rotationLocked: _rotationLocked,
                chapterLabel: chapter.label(),
                chapterNumber: position + 1,
                chapterCount: readable.length,
                seriesTitle: entry.title,
                onToggleControls: _toggleControls,
                onToggleRotation: _toggleRotationLock,
                onSettings: _saveSettings,
                onClose: () => Navigator.of(context).pop(),
                onSpot: (spot, {required turned}) =>
                    _remember(chapter.id, spot, files.length, turned: turned),
                onFinished: () => _finish(chapter.id, next?.id),
                onNext: next == null ? null : () => _go(next.id),
                onPrevious: previous == null ? null : () => _go(previous.id),
                onBookmark: _bookmark,
                onShowBookmarks: () => _showBookmarks(context, readable),
                onShowChapters: () => _showChapters(context, readable),
                nextLabel: next?.label(),
              ),
              // Il velo sta sopra la tavola e sotto i comandi: attenua la
              // lettura, non l'interfaccia.
              if (_settings.brightness < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: 1 - _settings.brightness,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Un capitolo può stare nell'indice e non sul telefono: gli indici pesano
  /// qualche centinaio di kilobyte e arrivano per primi, le tavole sono
  /// gigabyte e arrivano dopo. Si guarda la prima tavola: se manca quella
  /// manca il capitolo, e dirlo una volta vale più di sessanta riquadri vuoti.
  Future<bool> _arrived(String chapterId, String first) {
    if (_checked != chapterId) {
      _checked = chapterId;
      // Un capitolo di Drive c'è per definizione: le tavole arrivano mentre
      // si legge, ed è il loro segnaposto a dirlo.
      _arrival = isRemote(first) ? Future.value(true) : File(first).exists();
    }
    return _arrival!;
  }

  /// Le tavole di Drive del capitolo aperto, nell'ordine del capitolo: una
  /// dopo l'altra, dalla prima all'ultima, qualunque cosa ci sia sullo
  /// schermo. Scaricare per prima la tavola sotto il dito sembrava più
  /// svelto e riempiva il capitolo a buchi, con decine di download iniziati
  /// e abbandonati da chi scorreva veloce. L'unica eccezione è la ripresa a
  /// metà capitolo: si parte dalla tavola dove si era rimasti, perché le
  /// venti prima non si guarderanno.
  void _warm(
    String chapterId,
    List<List<String>> sources, {
    int from = 0,
    List<String> after = const [],
  }) {
    if (_warmed == chapterId && after.isEmpty && from == _warmedFrom) return;
    _warmed = chapterId;
    _warmedFiles = sources;
    _warmedFrom = from;
    final start = from.clamp(0, sources.length);
    final ordered = [
      ...sources.skip(start).expand((row) => row),
      ...after,
      ...sources.take(start).toList().reversed.expand((row) => row),
    ].where(isRemote);
    if (ordered.isNotEmpty) RemoteFiles.instance?.warm(ordered);
  }

  /// Le tavole alte che l'archivio non ha tagliato si fanno tagliare al
  /// telefono, dalla tavola da cui si riprende in avanti: le altre hanno già
  /// le loro tessere, o sono basse abbastanza da leggersi intere.
  void _planTiles(
    List<String> files,
    List<List<String>> tiles,
    List<PageEntry> pages, {
    required int from,
  }) {
    if (!PageDecoder.instance.canDecodeRegions) return;
    final tall = <String>[];
    var start = 0;
    for (var position = 0; position < files.length; position++) {
      final height = position < pages.length ? pages[position].height : null;
      final tiled = position < tiles.length && tiles[position].isNotEmpty;
      if (tiled || height == null || height <= wholePageLimit) continue;
      if (position < from) start = tall.length + 1;
      tall.add(files[position]);
    }
    if (tall.isEmpty) {
      PhoneTiles.instance.stop();
      return;
    }
    unawaited(
      PhoneTiles.instance.plan(
        tall,
        from: start,
        bandHeight: pageBandHeight,
        targetWidth: (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round(),
      ),
    );
  }

  ReadingSpot _resumeSpot(String chapterId, int pageCount) {
    if (widget.page != null && chapterId == widget.chapterId) {
      return ReadingSpot(widget.page!.clamp(0, pageCount - 1), 0);
    }
    final progress = _reading.peek(widget.seriesKey).positions[chapterId];
    if (progress == null) return const ReadingSpot(0, 0);
    return ReadingSpot(
      progress.page.clamp(0, pageCount - 1),
      progress.offset,
    );
  }

  /// Il magazzino delle fasce, dimensionato sullo schermo di questo telefono.
  void _sizeBandCache(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final screen = (size.width * ratio * size.height * ratio * 4).round();
    PageBandCache.instance.budgetBytes = screen * _bandBudgetScreens;
  }

  /// Dove si è arrivati.
  ///
  /// La riga su disco aspetta una pausa; la fotografia in memoria aspetta
  /// l'uscita dal lettore. Pubblicarla a ogni movimento voleva dire
  /// ricalcolare segnali, filtri e ordinamenti di tutta la libreria — che sta
  /// ancora montata sotto il lettore — al ritmo dello scorrimento.
  void _remember(
    String chapterId,
    ReadingSpot spot,
    int pageCount, {
    required bool turned,
  }) {
    if (turned) _noteActivity();
    if (_incognito) return;
    _pending = spot;
    _pendingChapter = chapterId;
    _pendingCount = pageCount;
    _progressTimer?.cancel();
    _progressTimer = Timer(_progressDelay, _flushProgress);
  }

  void _flushProgress() {
    final spot = _pending;
    final chapterId = _pendingChapter;
    if (spot == null || chapterId == null) return;
    _progressTimer?.cancel();
    // Scritta una volta, non si riscrive: uscendo dal lettore si ripassa di
    // qui, e la stessa riga due volte è una scrittura per niente.
    _pending = null;
    unawaited(
      _reading.noteProgress(
        widget.seriesKey,
        chapterId: chapterId,
        page: spot.page,
        offset: spot.fraction,
        pageCount: _pendingCount,
      ),
    );
  }

  /// Fine del capitolo: si segna letto e si precarica l'inizio del seguente,
  /// perché il gesto che arriva dopo è quasi sempre "avanti".
  void _finish(String chapterId, String? nextId) {
    if (!_incognito) {
      unawaited(_reading.noteChapterRead(widget.seriesKey, chapterId));
      unawaited(_offerEarlier(chapterId));
    }
    if (nextId != null) _preload(nextId);
  }

  /// Finito un capitolo con dei precedenti ancora da leggere, chiede se
  /// segnarli letti. Una volta per lettura: chi ha detto di no al 21 non
  /// vuole sentirselo richiedere al 22.
  Future<void> _offerEarlier(String chapterId) async {
    if (_offeredEarlier) return;
    final chapters =
        ref.read(seriesChaptersProvider(widget.seriesKey)).value?.index.chapters;
    if (chapters == null) return;
    final earlier = unreadBefore(
      chapters,
      chapterId,
      _reading.peek(widget.seriesKey).readChapters,
    );
    if (earlier.isEmpty) return;
    _offeredEarlier = true;
    final chapter = chapters.firstWhere((row) => row.id == chapterId);
    final many = earlier.length == 1
        ? 'Il capitolo precedente risulta'
        : 'I ${earlier.length} capitoli precedenti risultano';
    final sure = await showKagamiSheet<bool>(
      context,
      title: 'Segnare letti i precedenti?',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hai finito ${chapter.label()}. $many ancora da leggere: se '
              'li hai già letti altrove, segnali letti tutti insieme.',
              style: KagamiType.body(13.5,
                  height: 1.5, color: context.tokens.muted),
            ),
            const SizedBox(height: 20),
            KButton(
              label: earlier.length == 1
                  ? 'Segna letto il precedente'
                  : 'Segna letti tutti i ${earlier.length}',
              icon: LucideIcons.checkCheck,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            KGhostButton(
              label: 'Lasciali da leggere',
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (sure != true) return;
    await _reading.noteChaptersRead(widget.seriesKey, earlier, estimated: true);
  }

  /// Le prime fasce del capitolo seguente, non le prime tavole: di una
  /// tavola di webtoon serve l'inizio, ed è anche tutto quello che si vedrà
  /// prima che ne arrivi il resto.
  void _preload(String chapterId) {
    final entry = ref.read(seriesEntryProvider(widget.seriesKey));
    final library = ref.read(libraryProvider);
    final chapters = ref.read(seriesChaptersProvider(widget.seriesKey)).value;
    final pages = ref.read(pagesIndexProvider(widget.seriesKey)).value;
    if (entry == null || library == null || chapters == null || pages == null) {
      return;
    }
    final chapter = chapters.index.chapters
        .firstWhereOrNull((row) => row.id == chapterId);
    if (chapter == null) return;
    final files = library.pagePaths(entry, chapter, pages, chapters);
    if (files.isEmpty) return;
    final tiles = library.tilePaths(entry, chapter, pages, chapters);
    // Da Drive, del capitolo seguente si portano giù i primi file: quelli
    // che servono a non aspettare voltando capitolo.
    _warmedAfter = _sources(files, tiles)
        .expand((row) => row)
        .take(6)
        .toList(growable: false);
    _warm(_chapterId, _warmedFiles, from: _warmedFrom, after: _warmedAfter);
    final strip = ChapterStrip(
      _pageShapes(pages.of(chapter.id), files.length, tiles),
      bandHeight: PageDecoder.instance.canDecodeRegions
          ? pageBandHeight
          : wholePageBand,
    );
    final width = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round();
    // Più o meno una schermata: sei fasce, o due tavole dove non si taglia.
    final ahead = PageDecoder.instance.canDecodeRegions ? 6 : 2;
    for (var position = 0;
        position < strip.length && position < ahead;
        position++) {
      final band = strip.bands[position];
      PageBandCache.instance.prefetch(
        BandKey(
          path: files[band.page],
          top: band.height <= 0 ? 0 : band.top,
          height: band.height,
          width: width,
          tile: band.tile == null ? null : tiles[band.page][band.tile!],
          whole: band.whole,
        ),
      );
    }
  }

  void _go(String chapterId) {
    _flushProgress();
    _progressTimer?.cancel();
    _pending = null;
    _pendingChapter = null;
    setState(() => _chapterId = chapterId);
  }

  Future<void> _bookmark(int page) async {
    await _repository.addBookmark(
      seriesKey: widget.seriesKey,
      chapterId: _chapterId,
      page: page,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pagina ${page + 1} messa da parte')),
    );
  }

  /// L'elenco dei capitoli senza uscire dal lettore: è il gesto con cui si
  /// torna indietro di tre capitoli, e passare dalla scheda serie per farlo
  /// significa perdere il posto.
  Future<void> _showChapters(
    BuildContext context,
    List<ChapterEntry> readable,
  ) =>
      showKagamiSheet<void>(
        context,
        title: 'Capitoli',
        scrollable: true,
        builder: (context) => _ChaptersSheet(
          chapters: readable,
          // Letto al momento e non osservato: il lettore non deve ricostruirsi
          // ogni volta che un capitolo cambia stato sotto di lui.
          read: _reading.peek(widget.seriesKey).readChapters,
          currentId: _chapterId,
          onPick: (id) {
            Navigator.of(context).pop();
            _go(id);
          },
        ),
      );

  Future<void> _showBookmarks(
    BuildContext context,
    List<ChapterEntry> readable,
  ) async {
    final bookmarks = await _repository.bookmarks(widget.seriesKey);
    if (!context.mounted) return;
    await showKagamiSheet<void>(
      context,
      title: 'Pagine messe da parte',
      scrollable: true,
      builder: (context) => bookmarks.isEmpty
          ? const KEmpty(
              icon: LucideIcons.bookmark,
              compact: true,
              title: 'Nessuna pagina da parte',
              message: 'Il segnalibro tiene il punto di una tavola; quello '
                  'del capitolo lo tiene già la ripresa.',
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
              children: [
                for (final bookmark in bookmarks)
                  KTile(
                    icon: LucideIcons.bookmark,
                    title: readable
                            .firstWhereOrNull(
                              (row) => row.id == bookmark.chapterId,
                            )
                            ?.label() ??
                        bookmark.chapterId,
                    subtitle: 'pagina ${bookmark.page + 1}',
                    trailing: IconButton(
                      tooltip: 'Togli',
                      icon: const Icon(LucideIcons.trash2, size: 17),
                      onPressed: () async {
                        await _repository.deleteBookmark(bookmark.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _go(bookmark.chapterId);
                    },
                  ),
              ],
            ),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: KagamiType.body(14, color: Colors.white70),
            ),
          ),
        ),
      );
}

/// Un capitolo, nella modalità scelta per la serie.
class _ChapterView extends StatefulWidget {
  const _ChapterView({
    required this.files,
    required this.tiles,
    required this.pages,
    required this.settings,
    required this.initialSpot,
    required this.controlsVisible,
    required this.rotationLocked,
    required this.chapterLabel,
    required this.chapterNumber,
    required this.chapterCount,
    required this.seriesTitle,
    required this.onToggleControls,
    required this.onToggleRotation,
    required this.onSettings,
    required this.onClose,
    required this.onSpot,
    required this.onFinished,
    required this.onNext,
    required this.onPrevious,
    required this.onBookmark,
    required this.onShowBookmarks,
    required this.onShowChapters,
    required this.nextLabel,
    super.key,
  });

  final List<String> files;

  /// Le tessere di ogni tavola, vuote dove non ce ne sono.
  final List<List<String>> tiles;
  final List<PageEntry> pages;
  final ReaderSettings settings;

  /// Da dove riprendere: la tavola e quanto se n'era già scorso.
  final ReadingSpot initialSpot;
  final bool controlsVisible;
  final bool rotationLocked;
  final String chapterLabel;
  final int chapterNumber;
  final int chapterCount;
  final String seriesTitle;
  final VoidCallback onToggleControls;
  final VoidCallback onToggleRotation;
  final ValueChanged<ReaderSettings> onSettings;
  final VoidCallback onClose;

  /// Dove si è arrivati. `turned` distingue l'aver cambiato tavola
  /// dall'essersi mossi dentro la stessa: la prima cosa conta come una pagina
  /// letta, la seconda no.
  final void Function(ReadingSpot spot, {required bool turned}) onSpot;
  final VoidCallback onFinished;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final ValueChanged<int> onBookmark;
  final VoidCallback onShowBookmarks;
  final VoidCallback onShowChapters;
  final String? nextLabel;

  @override
  State<_ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends State<_ChapterView>
    with SingleTickerProviderStateMixin {
  final TransformationController _zoom = TransformationController();
  final FocusNode _keyboard = FocusNode();

  /// La striscia in fasce: la geometria della lettura continua. I rapporti
  /// misurati hanno la precedenza su quelli dichiarati, ed è ciò che la tiene
  /// senza giunture anche quando `pages.json` è vecchio o incompleto.
  late final ChapterStrip _strip = ChapterStrip(
    _shapes(),
    // Senza ritagli non si taglia: chiedere un pezzo costerebbe comunque
    // decodificare tutto, e allora tanto vale una tavola sola.
    bandHeight: PageDecoder.instance.canDecodeRegions
        ? pageBandHeight
        : wholePageBand,
  );

  /// La stessa striscia senza tagli: nella lettura a pagine una tavola sta
  /// tutta nello schermo, quindi la si chiede intera e ridotta a quanto si
  /// vede — che è sempre molto meno di com'è.
  late final ChapterStrip _whole =
      ChapterStrip(_shapes(), bandHeight: wholePageBand, useTiles: false);

  final Map<int, double> _pending = {};
  bool _flushing = false;

  /// Dove si è arrivati. È un valore osservabile e non uno stato del widget
  /// perché cambia a ogni fotogramma di scorrimento: ricostruire la lista per
  /// aggiornare un numero di pagina è esattamente ciò che fa scattare la
  /// lettura.
  final ValueNotifier<ReadingSpot> _spot =
      ValueNotifier(const ReadingSpot(0, 0));
  final ValueNotifier<bool> _atTop = ValueNotifier(true);

  ScrollController? _scroll;
  PageController? _pager;
  Ticker? _autoScroll;
  Duration _lastTick = Duration.zero;
  bool _reportedEnd = false;
  double _scale = 1;

  int get _page => _spot.value.page;

  List<PageShape> _shapes() =>
      _pageShapes(widget.pages, widget.files.length, widget.tiles);

  @override
  void initState() {
    super.initState();
    _spot.value = widget.initialSpot;
  }

  @override
  void didUpdateWidget(_ChapterView old) {
    super.didUpdateWidget(old);
    if (old.settings.autoScroll != widget.settings.autoScroll ||
        old.settings.mode != widget.settings.mode) {
      _syncAutoScroll();
    }
  }

  @override
  void dispose() {
    _autoScroll?.dispose();
    _zoom.dispose();
    _keyboard.dispose();
    _scroll?.dispose();
    _pager?.dispose();
    _spot.dispose();
    _atTop.dispose();
    super.dispose();
  }

  bool get _continuous => widget.settings.mode == ReaderMode.continuous;

  /// Due tavole affiancate solo quando lo schermo è più largo che alto: in
  /// verticale sarebbero due francobolli.
  bool _spread(Size size) =>
      widget.settings.doublePage && !_continuous && size.width > size.height;

  /// Le coppie di tavole della modalità affiancata. La prima resta sola: è la
  /// copertina, e appaiarla sfalsa tutte quelle dopo.
  List<List<int>> _pairs() {
    final pairs = <List<int>>[];
    for (var position = 0; position < widget.files.length; position++) {
      if (position == 0 || pairs.last.length == 2) {
        pairs.add([position]);
      } else {
        pairs.last.add(position);
      }
    }
    return pairs;
  }

  /// Una fascia è stata decodificata e il suo rapporto vero è noto. Le
  /// correzioni si accumulano e si applicano a fine fotogramma: arrivano
  /// mentre la lista si costruisce, e ricostruirla da dentro la costruzione
  /// non si può.
  void _noteRatio(int band, double ratio) {
    if (!_continuous) return;
    if (!_strip.worthApplying(band, ratio, MediaQuery.sizeOf(context).width)) {
      return;
    }
    _pending[band] = ratio;
    if (_flushing) return;
    _flushing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRatios());
  }

  void _applyRatios() {
    _flushing = false;
    if (!mounted || _pending.isEmpty) return;
    final width = MediaQuery.sizeOf(context).width;
    final scroll = _scroll;
    final shift = _strip.apply(
      _pending,
      width: width,
      top: scroll != null && scroll.hasClients ? scroll.offset : 0,
    );
    _pending.clear();
    ReaderProbe.instance.noteCorrection(shift);
    setState(() {});
    if (shift.abs() < 0.5 || scroll == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.jumpTo(
        (scroll.offset + shift).clamp(0, scroll.position.maxScrollExtent),
      );
    });
  }

  /// Dove si è arrivati, riferito a chi tiene il conto. Una posizione che non
  /// si discosta da quella di prima non è una notizia: fra due fotogrammi di
  /// scorrimento non cambia niente che valga una scrittura.
  void _reportSpot(ReadingSpot spot) {
    final previous = _spot.value;
    if (spot.near(previous)) return;
    _spot.value = spot;
    widget.onSpot(spot, turned: spot.page != previous.page);
    if (spot.page + 1 >= (widget.files.length * _finishedAt).ceil()) {
      _reportEnd();
    }
  }

  void _reportPage(int page) => _reportSpot(ReadingSpot(page, 0));

  void _reportEnd() {
    if (_reportedEnd) return;
    _reportedEnd = true;
    widget.onFinished();
  }

  /// Lo scorrimento automatico: tante tavole al minuto quante ne dice
  /// l'impostazione, tradotte nell'altezza che quelle tavole occupano.
  void _syncAutoScroll() {
    _autoScroll?.dispose();
    _autoScroll = null;
    final speed = widget.settings.autoScroll;
    if (speed <= 0 || !_continuous) return;
    _lastTick = Duration.zero;
    _autoScroll = createTicker((elapsed) {
      final scroll = _scroll;
      if (scroll == null || !scroll.hasClients) return;
      final delta = elapsed - _lastTick;
      _lastTick = elapsed;
      final width = MediaQuery.sizeOf(context).width;
      final pixels = _strip.pageHeight(_page, width) *
          speed /
          60 *
          delta.inMilliseconds /
          1000;
      final target = scroll.offset + pixels;
      if (target >= scroll.position.maxScrollExtent) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        widget.onSettings(widget.settings.copyWith(autoScroll: 0));
        return;
      }
      scroll.jumpTo(target);
    })
      ..start();
  }

  void _toggleZoom(Offset focal) {
    setState(() {
      if (_scale > 1) {
        _zoom.value = Matrix4.identity();
        _scale = 1;
      } else {
        _zoom.value = Matrix4.identity()
          ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
          ..scaleByDouble(2, 2, 1, 1);
        _scale = 2;
      }
    });
  }

  void _toTop() {
    final scroll = _scroll;
    if (scroll == null || !scroll.hasClients) {
      _pager?.jumpToPage(0);
      return;
    }
    scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        // I tasti servono sul desktop, dove il tocco non c'è: frecce e barra
        // spaziatrice fanno quello che ci si aspetta.
        Focus(
          focusNode: _keyboard,
          autofocus: true,
          onKeyEvent: (_, event) => _onKey(event, size),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _onTap(details.localPosition, size),
            onDoubleTapDown: (details) => _toggleZoom(details.localPosition),
            onDoubleTap: () {},
            child: _continuous ? _buildContinuous(size) : _buildPaged(size),
          ),
        ),
        if (widget.settings.showPageNumber && !widget.controlsVisible)
          Positioned(
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            child: ValueListenableBuilder<ReadingSpot>(
              valueListenable: _spot,
              builder: (context, spot, _) =>
                  _PageNumber(page: spot.page, total: widget.files.length),
            ),
          ),
        // Il pulsante che riporta in cima al capitolo: su una striscia di
        // duecento tavole il gesto alternativo è scorrere all'indietro per un
        // minuto.
        if (widget.settings.showScrollTop &&
            _continuous &&
            !widget.controlsVisible)
          Positioned(
            left: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            child: ValueListenableBuilder<bool>(
              valueListenable: _atTop,
              builder: (context, atTop, child) =>
                  atTop ? const SizedBox.shrink() : child!,
              child: _RoundAction(
                icon: LucideIcons.arrowUp,
                tooltip: 'Torna in cima',
                onTap: _toTop,
              ),
            ),
          ),
        // L'avanzamento resta visibile anche a comandi nascosti: è una riga di
        // quattro pixel in fondo allo schermo, non un'interfaccia.
        if (widget.settings.showProgress && !widget.controlsVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<ReadingSpot>(
                valueListenable: _spot,
                builder: (context, spot, _) => LinearProgressIndicator(
                  value: widget.files.length < 2
                      ? 1.0
                      : ((spot.page + spot.fraction) / widget.files.length)
                          .clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ),
        const _ProbeReadout(),
        if (widget.controlsVisible)
          ValueListenableBuilder<ReadingSpot>(
            valueListenable: _spot,
            builder: (context, spot, _) => _Controls(
              title: widget.chapterLabel,
              seriesTitle: widget.seriesTitle,
              settings: widget.settings,
              rotationLocked: widget.rotationLocked,
              page: spot.page,
              pageCount: widget.files.length,
              chapterNumber: widget.chapterNumber,
              chapterCount: widget.chapterCount,
              onSeek: (page) => _seek(page, size),
              onSettings: widget.onSettings,
              onClose: widget.onClose,
              onNext: widget.onNext,
              onPrevious: widget.onPrevious,
              onToggleRotation: widget.onToggleRotation,
              onBookmark: () => widget.onBookmark(spot.page),
              onShowBookmarks: widget.onShowBookmarks,
              onShowChapters: widget.onShowChapters,
              onToTop: _toTop,
            ),
          ),
      ],
    );
  }

  KeyEventResult _onKey(KeyEvent event, Size size) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final forward = event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.pageDown;
    final backward = event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.pageUp;
    if (!forward && !backward) return KeyEventResult.ignored;
    if (_continuous) {
      final scroll = _scroll;
      if (scroll == null || !scroll.hasClients) return KeyEventResult.ignored;
      scroll.animateTo(
        (scroll.offset + (forward ? 1 : -1) * size.height * 0.85)
            .clamp(0, scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      _turn(forward);
    }
    return KeyEventResult.handled;
  }

  /// Salto rapido: la barra di avanzamento porta dove si vuole senza
  /// attraversare le pagine in mezzo, e quindi senza decodificarle.
  void _seek(int page, Size size) {
    final target = page.clamp(0, widget.files.length - 1);
    _reportPage(target);
    if (_continuous) {
      _scroll?.jumpTo(_strip.offsetOf(ReadingSpot(target, 0), size.width));
      return;
    }
    if (_spread(size)) {
      final pairs = _pairs();
      _pager?.jumpToPage(pairs.indexWhere((pair) => pair.contains(target)));
      return;
    }
    _pager?.jumpToPage(target);
  }

  void _onTap(Offset position, Size size) {
    // Il terzo centrale richiama i comandi; ai lati, in paginata, si cambia
    // tavola — il gesto con cui si legge non deve spostare la mano.
    final third = size.width / 3;
    if (_continuous || (position.dx > third && position.dx < third * 2)) {
      widget.onToggleControls();
      return;
    }
    final forward = widget.settings.direction == ReaderDirection.rightToLeft
        ? position.dx < third
        : position.dx > third * 2;
    _turn(forward);
  }

  void _turn(bool forward) {
    final pager = _pager;
    if (pager == null) return;
    final current = pager.page?.round() ?? 0;
    final target = current + (forward ? 1 : -1);
    if (target < 0) {
      widget.onPrevious?.call();
      return;
    }
    final last = _spread(MediaQuery.sizeOf(context))
        ? _pairs().length
        : widget.files.length;
    if (target >= last) {
      _reportEnd();
      widget.onNext?.call();
      return;
    }
    pager.animateToPage(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  /// La striscia: tutte le fasce del capitolo una sotto l'altra, attaccate.
  ///
  /// Niente margini, niente separatori, niente riquadri — ogni fascia occupa
  /// esattamente l'altezza che le tocca alla larghezza dello schermo, quindi
  /// il bordo inferiore dell'una è il bordo superiore dell'altra e un capitolo
  /// si legge come una pagina sola.
  ///
  /// Che le fasce siano gli elementi della lista, e non le tavole, è la
  /// ragione per cui scorrere un webtoon non fa crescere la memoria: la lista
  /// costruisce e butta via quello che passa, e quello che passa è una
  /// schermata, non una tavola da cinquanta megabyte.
  Widget _buildContinuous(Size size) {
    _scroll ??= ScrollController(
      initialScrollOffset: _strip.screenOffsetOf(
        widget.initialSpot,
        size.width,
        size.height,
      ),
    );
    if (_autoScroll == null && widget.settings.autoScroll > 0) {
      // Il ticker parte solo quando c'è una lista a cui attaccarsi.
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncAutoScroll());
    }
    return InteractiveViewer(
      transformationController: _zoom,
      minScale: 1,
      maxScale: 4,
      // Con scala 1 il trascinamento deve restare allo scorrimento della
      // lista, altrimenti il lettore non scorre più.
      panEnabled: _scale > 1,
      onInteractionEnd: (_) =>
          setState(() => _scale = _zoom.value.getMaxScaleOnAxis()),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            ReaderProbe.instance.scrolling = true;
          } else if (notification is ScrollEndNotification) {
            ReaderProbe.instance.scrolling = false;
          }
          if (notification is ScrollUpdateNotification ||
              notification is ScrollEndNotification) {
            final metrics = notification.metrics;
            _reportSpot(
              _strip.spotOnScreen(metrics.pixels, size.width, size.height),
            );
            _atTop.value = metrics.pixels <= size.height * 0.5;
            if (metrics.pixels >= metrics.maxScrollExtent - size.height * 0.15) {
              _reportEnd();
            }
          }
          return false;
        },
        child: ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.zero,
          // Una schermata di margine: si decodifica la fascia che sta per
          // entrare, non tutto il capitolo.
          scrollCacheExtent: const ScrollCacheExtent.viewport(1),
          itemCount: _strip.length + 1,
          // Le altezze la lista le sa prima di costruire niente: la striscia
          // è lunga quanto tutto il capitolo anche dove nessuna tavola è
          // ancora arrivata, e un salto con la barra non costruisce — né
          // chiede — ogni fascia che sta in mezzo.
          // Le chiede dalla prima a ogni disposizione, quindi le prende dai
          // bordi già calcolati invece di rifare ogni divisione.
          itemExtentBuilder: (position, _) {
            if (position > _strip.length) return null;
            if (position == _strip.length) return _ChapterFooter.height;
            final offsets = _strip.offsets(size.width);
            return offsets[position + 1] - offsets[position];
          },
          itemBuilder: (context, position) {
            if (position == _strip.length) {
              return _ChapterFooter(
                label: widget.nextLabel,
                onNext: widget.onNext,
              );
            }
            final band = _strip.bands[position];
            final path = widget.files[band.page];
            final tile = band.tile;
            // Il nero sta sotto ogni fascia, qualunque sia lo sfondo scelto:
            // è il posto della tavola che non è ancora arrivata.
            return ColoredBox(
              color: Colors.black,
              child: PageBandView(
                path: path,
                tile: tile == null ? null : widget.tiles[band.page][tile],
                band: band,
                width: size.width,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                onRatio: (ratio) => _noteRatio(position, ratio),
                // L'attesa si annuncia una volta per tavola: una fascia in
                // mezzo a una tavola già cominciata è solo il seguito.
                placeholder:
                    band.index == 0 ? const _PageWaiting() : const SizedBox(),
                errorBuilder: (context, error) => isNetworkFailure(error)
                    ? _OfflinePage(first: band.index == 0)
                    : _pageProblem(path),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaged(Size size) {
    final pairs = _spread(size) ? _pairs() : null;
    _pager ??= PageController(
      initialPage: pairs == null
          ? widget.initialSpot.page
          : pairs.indexWhere((pair) => pair.contains(widget.initialSpot.page)),
    );
    return PageView.builder(
      controller: _pager,
      reverse: widget.settings.direction == ReaderDirection.rightToLeft,
      // Precarica la tavola adiacente: è quella che serve fra un secondo.
      allowImplicitScrolling: true,
      itemCount: pairs?.length ?? widget.files.length,
      onPageChanged: (page) {
        _reportPage(pairs == null ? page : pairs[page].first);
        if (page == (pairs?.length ?? widget.files.length) - 1) _reportEnd();
      },
      itemBuilder: (context, position) {
        final indices = pairs == null ? [position] : pairs[position];
        return InteractiveViewer(
          transformationController: indices.contains(_page) ? _zoom : null,
          minScale: 1,
          maxScale: 4,
          onInteractionEnd: (_) =>
              setState(() => _scale = _zoom.value.getMaxScaleOnAxis()),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            // Affiancate si leggono nello stesso verso in cui si sfoglia.
            textDirection:
                widget.settings.direction == ReaderDirection.rightToLeft
                    ? TextDirection.rtl
                    : TextDirection.ltr,
            children: [
              for (final index in indices)
                Expanded(
                  child: PageBandView(
                    path: widget.files[index],
                    band: _whole.bands[index],
                    width: _pagedWidth(size, index, indices.length),
                    fit: switch (widget.settings.fit) {
                      ReaderFit.width => BoxFit.contain,
                      ReaderFit.height => BoxFit.fitHeight,
                      ReaderFit.original => BoxFit.none,
                    },
                    alignment: Alignment.center,
                    placeholder: const _PageWaiting(),
                    errorBuilder: (context, error) => isNetworkFailure(error)
                        ? const _OfflinePage(first: true, centered: true)
                        : _pageProblem(widget.files[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// A quanti pixel serve davvero una tavola sfogliata: quelli che occupa
  /// dentro lo schermo, non quelli che ha nel file. Una tavola di webtoon
  /// dentro una pagina intera si vede larga un dito, e decodificarla per
  /// intero sarebbe pagare cinquanta megabyte per mostrarne mille.
  double _pagedWidth(Size size, int index, int count) {
    final box = size.width / count;
    if (widget.settings.fit == ReaderFit.original) return box;
    final fitted = size.height * _whole.ratioOf(index);
    return fitted < box ? fitted : box;
  }

  /// Perché la tavola non c'è, quando non c'è: distinguere il file che non è
  /// ancora arrivato da quello che non si è potuto aprire è l'unica cosa che
  /// l'utente possa usare per capire a chi chiedere.
  Widget _pageProblem(String path) => _MissingPage(
        isRemote(path)
            ? 'Tavola non arrivata da Drive'
            : File(path).existsSync()
                ? 'Tavola illeggibile'
                : 'Tavola non sincronizzata',
      );
}

/// Una tavola di Drive che la rete non ha portato.
///
/// Le tavole già scese restano visibili tutt'intorno: l'avviso sta solo su
/// quelle che mancano, e se ne va da solo quando la rete torna — il magazzino
/// delle fasce le riprova e al posto dell'avviso ricompare l'attesa. Il
/// pulsante serve a chi non vuole aspettare il prossimo tentativo.
class _OfflinePage extends StatelessWidget {
  const _OfflinePage({this.first = true, this.centered = false});

  /// Solo la prima fascia di una tavola lo dice per intero: su una tavola di
  /// webtoon alta dieci schermate, dieci avvisi uguali sarebbero rumore.
  final bool first;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    const muted = Colors.white54;
    if (!first) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 56),
          child: Icon(LucideIcons.cloudOff, size: 18, color: Colors.white24),
        ),
      );
    }
    final notice = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.cloudOff, color: muted),
          const SizedBox(height: 10),
          const Text(
            'Tavola non ancora scaricata',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Senza connessione. Arriva da sola appena torna la rete.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () async {
              if (await NetworkMonitor.instance.check()) {
                PageBandCache.instance.retryFailed();
              }
            },
            icon: const Icon(LucideIcons.refreshCw, size: 15),
            label: const Text('Riprova ora'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
        ],
      ),
    );
    return Align(
      alignment: centered ? Alignment.center : Alignment.topCenter,
      child: notice,
    );
  }
}

/// Il posto di una tavola che si sta ancora aprendo. L'indicatore sta in alto
/// perché una tavola di un manhwa è alta quanto dieci schermate: al centro
/// finirebbe fuori dallo schermo proprio mentre la si aspetta.
/// I numeri di [ReaderProbe], sopra la tavola, finché la misura è accesa.
/// Si rileggono una volta al secondo: aggiornarli a ogni fotogramma
/// sarebbe proprio il lavoro che si sta cercando di misurare.
class _ProbeReadout extends StatefulWidget {
  const _ProbeReadout();

  @override
  State<_ProbeReadout> createState() => _ProbeReadoutState();
}

class _ProbeReadoutState extends State<_ProbeReadout> {
  final ReaderProbe _probe = ReaderProbe.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _probe.enabled.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    _probe.enabled.removeListener(_sync);
    _tick?.cancel();
    super.dispose();
  }

  void _sync() {
    _tick?.cancel();
    _tick = _probe.on
        ? Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}))
        : null;
    if (mounted) setState(() {});
  }

  static String _ms(Duration value) =>
      (value.inMicroseconds / 1000).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (!_probe.on) return const SizedBox.shrink();
    final p = _probe;
    final bands = p.bands == 0 ? 1 : p.bands;
    final lines = [
      'Fotogrammi ${p.frames} · limite ${_ms(p.budget)} ms',
      'Lenti UI ${p.slowBuild} (max ${_ms(p.worstBuild)} ms) · '
          'GPU ${p.slowRaster} (max ${_ms(p.worstRaster)} ms)',
      'Partiti tardi ${p.lateStarts} (max ${_ms(p.worstStart)} ms)',
      'Scorrendo ${p.scrollFrames} · saltati ${p.missedFrames} '
          '(buco max ${_ms(p.worstGap)} ms)',
      'Tessere ${p.tileBands} · intere ${p.wholeBands} · '
          'del telefono ${p.phoneBands} (fatte ${p.phoneTiled})',
      'Native ${p.bands} (texture ${p.textureBands}) · '
          'tavole decodificate ${p.pageDecodes}',
      'Decodifica ${_ms(p.decodeTotal ~/ bands)} ms '
          '(max ${_ms(p.decodeWorst)}) · arrivo ${_ms(p.nativeTotal ~/ bands)} '
          'ms (max ${_ms(p.nativeWorst)})',
      'Copia max ${_ms(p.copyWorst)} ms · GC Android ${p.gcCount} '
          '(${p.gcMillis} ms) · bloccanti ${p.blockingCount} '
          '(${p.blockingMillis} ms)',
      'Attese da Drive ${p.driveWaits} · ripieghi Dart ${p.wholeDecodes}',
      'Correzioni ${p.corrections} · '
          'salti ${p.jumps} (${p.jumped.toStringAsFixed(0)} px)',
    ];
    return Positioned(
      left: 8,
      top: MediaQuery.paddingOf(context).top + 8,
      child: GestureDetector(
        // Un tocco azzera: si misura da un punto preciso del capitolo.
        onTap: () => setState(p.reset),
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                lines.join('\n'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.35,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageWaiting extends StatelessWidget {
  const _PageWaiting();

  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 56),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
}

/// Una tavola che non si vede è un riquadro con il motivo: il capitolo resta
/// leggibile per il resto, e il motivo dice se manca il file — la
/// sincronizzazione può essere a metà — o se il file c'è e non si apre.
class _MissingPage extends StatelessWidget {
  const _MissingPage(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.imageOff, color: Colors.white38),
              const SizedBox(height: 8),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

/// Il numero di pagina mentre i comandi sono nascosti: dice a che punto si è
/// senza occupare lo schermo.
class _PageNumber extends StatelessWidget {
  const _PageNumber({required this.page, required this.total});

  final int page;
  final int total;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Text(
              '${page + 1} / $total',
              style: KagamiType.figure(11.5, color: Colors.white70),
            ),
          ),
        ),
      );
}

/// Un'azione rotonda sopra la tavola, scura perché non deve illuminare la
/// pagina che copre.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = KPress(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _ChapterFooter extends StatelessWidget {
  const _ChapterFooter({required this.label, required this.onNext});

  /// Fissa perché la lista conosce l'altezza di ogni elemento prima di
  /// costruirlo, e il piede è uno di quelli.
  static const double height = 220;

  final String? label;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onNext == null)
              Text(
                'È l\'ultimo capitolo che c\'è sul telefono.',
                textAlign: TextAlign.center,
                style: KagamiType.body(13.5, color: Colors.white54),
              )
            else ...[
              Text(
                'Capitolo seguente',
                style:
                    KagamiType.overline(size: 10.5, color: Colors.white38),
              ),
              const SizedBox(height: 12),
              KButton(
                label: label ?? 'Continua',
                icon: LucideIcons.arrowDown,
                onPressed: onNext,
              ),
            ],
          ],
        ),
      );
}

/// I comandi, che esistono solo mentre servono: una barra in alto per uscire e
/// mettere da parte, una pastiglia in basso per muoversi fra capitoli e
/// pagine. Tutto il resto sta in due fogli, perché una fila di venti icone
/// sopra una tavola è una fila di venti icone da leggere ogni volta.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.title,
    required this.seriesTitle,
    required this.settings,
    required this.rotationLocked,
    required this.page,
    required this.pageCount,
    required this.chapterNumber,
    required this.chapterCount,
    required this.onSeek,
    required this.onSettings,
    required this.onClose,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleRotation,
    required this.onBookmark,
    required this.onShowBookmarks,
    required this.onShowChapters,
    required this.onToTop,
  });

  final String title;
  final String seriesTitle;
  final ReaderSettings settings;
  final bool rotationLocked;
  final int page;
  final int pageCount;
  final int chapterNumber;
  final int chapterCount;
  final ValueChanged<int> onSeek;
  final ValueChanged<ReaderSettings> onSettings;
  final VoidCallback onClose;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onToggleRotation;
  final VoidCallback onBookmark;
  final VoidCallback onShowBookmarks;
  final VoidCallback onShowChapters;
  final VoidCallback onToTop;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Column(
          children: [
            _Veil(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 8, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(LucideIcons.arrowLeft,
                            color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seriesTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KagamiType.label(
                                size: 11,
                                color: Colors.white54,
                              ),
                            ),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KagamiType.title(15,
                                  weight: 700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Metti da parte questa pagina',
                        onPressed: onBookmark,
                        icon: const Icon(LucideIcons.bookmarkPlus,
                            color: Colors.white),
                      ),
                      IconButton(
                        tooltip: 'Pagine messe da parte',
                        onPressed: onShowBookmarks,
                        icon: const Icon(LucideIcons.bookmark,
                            color: Colors.white),
                      ),
                      IconButton(
                        tooltip: 'Come si legge',
                        onPressed: () => _showSettings(context),
                        icon: const Icon(LucideIcons.settings2,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            _Veil(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          Text(
                            '${page + 1}',
                            style: KagamiType.figure(12.5,
                                color: Colors.white70),
                          ),
                          Expanded(
                            child: Slider(
                              value: page.clamp(0, pageCount - 1).toDouble(),
                              max: (pageCount - 1).toDouble(),
                              divisions: pageCount > 1 ? pageCount - 1 : null,
                              label: '${page + 1} / $pageCount',
                              onChanged: (value) => onSeek(value.round()),
                            ),
                          ),
                          Text(
                            '$pageCount',
                            style: KagamiType.figure(12.5,
                                color: Colors.white70),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ChapterPill(
                              title: title,
                              position: '$chapterNumber/$chapterCount',
                              onPrevious: onPrevious,
                              onNext: onNext,
                              onTap: onShowChapters,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _RoundAction(
                            icon: LucideIcons.chevronUp,
                            tooltip: 'Torna in cima',
                            onTap: onToTop,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  void _showSettings(BuildContext context) => showKagamiSheet<void>(
        context,
        title: 'Come si legge',
        scrollable: true,
        builder: (context) => _ReaderSettingsSheet(
          settings: settings,
          rotationLocked: rotationLocked,
          onChanged: onSettings,
          onToggleRotation: onToggleRotation,
        ),
      );
}

/// Il velo sotto le barre: un gradiente, non una fascia piena, perché la
/// tavola sotto deve continuare a vedersi.
class _Veil extends StatelessWidget {
  const _Veil({required this.begin, required this.end, required this.child});

  final Alignment begin;
  final Alignment end;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [
              Colors.black.withValues(alpha: 0.88),
              Colors.black.withValues(alpha: 0.72),
              Colors.transparent,
            ],
            stops: const [0, 0.65, 1],
          ),
        ),
        child: child,
      );
}

/// La pastiglia del capitolo: indietro, il nome con la sua posizione, avanti.
/// Toccando il centro si apre l'elenco.
class _ChapterPill extends StatelessWidget {
  const _ChapterPill({
    required this.title,
    required this.position,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
  });

  final String title;
  final String position;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Capitolo precedente',
              onPressed: onPrevious,
              icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KagamiType.title(14,
                            weight: 700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      position,
                      style: KagamiType.figure(12, color: Colors.white54),
                    ),
                    const Icon(LucideIcons.chevronDown,
                        size: 16, color: Colors.white54),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Capitolo successivo',
              onPressed: onNext,
              icon: const Icon(LucideIcons.chevronRight, color: Colors.white),
            ),
          ],
        ),
      );
}

/// L'elenco dei capitoli dentro il lettore, con la sua ricerca: su una serie
/// di duecento capitoli scorrere fino al numero che si cerca è il gesto più
/// lungo dell'app.
class _ChaptersSheet extends StatefulWidget {
  const _ChaptersSheet({
    required this.chapters,
    required this.read,
    required this.currentId,
    required this.onPick,
  });

  final List<ChapterEntry> chapters;
  final Set<String> read;
  final String currentId;
  final ValueChanged<String> onPick;

  @override
  State<_ChaptersSheet> createState() => _ChaptersSheetState();
}

class _ChaptersSheetState extends State<_ChaptersSheet> {
  String _query = '';
  bool _newestFirst = true;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final query = _query.trim().toLowerCase();
    final chapters = widget.chapters
        .where((chapter) =>
            query.isEmpty || chapter.label().toLowerCase().contains(query))
        .toList();
    if (_newestFirst) chapters.sort((a, b) => b.order.compareTo(a.order));

    final current =
        widget.chapters.indexWhere((row) => row.id == widget.currentId) + 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Cerca capitolo…',
                    prefixIcon: Icon(LucideIcons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              KIconAction(
                icon: _newestFirst
                    ? LucideIcons.arrowDownWideNarrow
                    : LucideIcons.arrowUpWideNarrow,
                tooltip: _newestFirst ? 'Dal più recente' : 'Dal primo',
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              final selected = chapter.id == widget.currentId;
              final read = widget.read.contains(chapter.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: KPress(
                  onTap: () => widget.onPick(chapter.id),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          read ? LucideIcons.bookCheck : LucideIcons.book,
                          size: 17,
                          color: selected
                              ? scheme.onPrimary
                              : read
                                  ? context.tokens.success
                                  : muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            chapter.label(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KagamiType.title(
                              14.5,
                              weight: selected ? 700 : 500,
                              color: selected
                                  ? scheme.onPrimary
                                  : read
                                      ? muted
                                      : scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, color: context.tokens.line),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Text(
                'In lettura: ',
                style: KagamiType.body(13, color: muted),
              ),
              Text(
                '$current',
                style: KagamiType.figure(13, color: scheme.onSurface),
              ),
              Text(
                ' / ${widget.chapters.length} capitoli',
                style: KagamiType.body(13, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Come si legge: le impostazioni della serie, raccolte in un foglio invece
/// che sparse sopra la tavola.
class _ReaderSettingsSheet extends StatefulWidget {
  const _ReaderSettingsSheet({
    required this.settings,
    required this.rotationLocked,
    required this.onChanged,
    required this.onToggleRotation,
  });

  final ReaderSettings settings;
  final bool rotationLocked;
  final ValueChanged<ReaderSettings> onChanged;
  final VoidCallback onToggleRotation;

  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  late ReaderSettings _settings = widget.settings;
  late bool _rotationLocked = widget.rotationLocked;

  void _apply(ReaderSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    final continuous = _settings.mode == ReaderMode.continuous;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KSection('Modalità di lettura'),
          KSegmented(
            options: const ['Striscia', 'Pagina'],
            icons: const [LucideIcons.gripHorizontal, LucideIcons.square],
            index: continuous ? 0 : 1,
            onChanged: (index) => _apply(
              _settings.copyWith(
                mode: index == 0 ? ReaderMode.continuous : ReaderMode.paged,
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (!continuous) ...[
            const KSection('Verso di lettura'),
            KSegmented(
              options: const ['Sinistra → destra', 'Destra → sinistra'],
              index:
                  _settings.direction == ReaderDirection.rightToLeft ? 1 : 0,
              onChanged: (index) => _apply(
                _settings.copyWith(
                  direction: index == 1
                      ? ReaderDirection.rightToLeft
                      : ReaderDirection.leftToRight,
                ),
              ),
            ),
            const SizedBox(height: 22),
            const KSection('Adattamento'),
            KSegmented(
              options: [for (final fit in ReaderFit.values) fit.label],
              index: _settings.fit.index,
              onChanged: (index) =>
                  _apply(_settings.copyWith(fit: ReaderFit.values[index])),
            ),
            const SizedBox(height: 22),
          ],
          const KSection('Sfondo'),
          KSegmented(
            options: [
              for (final background in ReaderBackground.values) background.label,
            ],
            index: _settings.background.index,
            onChanged: (index) => _apply(
              _settings.copyWith(background: ReaderBackground.values[index]),
            ),
          ),
          const SizedBox(height: 22),
          const KSection('Luminosità'),
          Slider(
            value: _settings.brightness,
            min: 0.25,
            onChanged: (value) =>
                _apply(_settings.copyWith(brightness: value)),
          ),
          if (continuous) ...[
            const SizedBox(height: 6),
            KSection(
              'Scorrimento automatico',
              trailing: Text(
                _settings.autoScroll == 0
                    ? 'spento'
                    : '${_settings.autoScroll.round()} tavole/min',
                style: KagamiType.label(size: 12, color: context.tokens.muted),
              ),
            ),
            Slider(
              value: _settings.autoScroll,
              max: 12,
              divisions: 12,
              onChanged: (value) =>
                  _apply(_settings.copyWith(autoScroll: value)),
            ),
          ],
          const SizedBox(height: 14),
          KGroup(
            children: [
              _Toggle(
                icon: LucideIcons.hash,
                label: 'Numero di pagina',
                value: _settings.showPageNumber,
                onChanged: (value) =>
                    _apply(_settings.copyWith(showPageNumber: value)),
              ),
              _Toggle(
                icon: LucideIcons.listOrdered,
                label: 'Barra di avanzamento',
                value: _settings.showProgress,
                onChanged: (value) =>
                    _apply(_settings.copyWith(showProgress: value)),
              ),
              _Toggle(
                icon: LucideIcons.arrowUp,
                label: 'Pulsante per tornare in cima',
                value: _settings.showScrollTop,
                onChanged: (value) =>
                    _apply(_settings.copyWith(showScrollTop: value)),
              ),
              _Toggle(
                icon: LucideIcons.lightbulb,
                label: 'Tieni acceso lo schermo',
                value: _settings.keepAwake,
                onChanged: (value) =>
                    _apply(_settings.copyWith(keepAwake: value)),
              ),
              if (!continuous)
                _Toggle(
                  icon: LucideIcons.bookOpen,
                  label: 'Due tavole affiancate',
                  value: _settings.doublePage,
                  onChanged: (value) =>
                      _apply(_settings.copyWith(doublePage: value)),
                ),
              _Toggle(
                icon: LucideIcons.rotateCcw,
                label: 'Blocca la rotazione',
                value: _rotationLocked,
                onChanged: (_) {
                  setState(() => _rotationLocked = !_rotationLocked);
                  widget.onToggleRotation();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => KTile(
        icon: icon,
        title: label,
        onTap: () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      );
}
