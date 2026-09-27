/// Le fasce sullo schermo: chi le chiede, chi le tiene e chi le butta.
///
/// È la metà in memoria della soluzione che sta in
/// `lib/src/data/page_decoder.dart`: quello decodifica un pezzo di tavola
/// alla volta, questo decide quali pezzi valga la pena tenere. Insieme fanno
/// sì che la memoria del lettore dipenda da quanto è grande lo schermo e non
/// da quanto è alta la tavola — che è la differenza fra scorrere un webtoon e
/// vedersi chiudere l'app.
///
/// Una fascia sono sempre le stesse righe della stessa tavola, ma i pixel
/// possono arrivare da più posti, e il magazzino li prova in quest'ordine:
/// la tessera che l'archivio ha già tagliato, la tavola intera se è bassa,
/// la tessera che il telefono ha tagliato da sé, e solo alla fine il ritaglio
/// nativo. Le prime tre sono file interi per il codec di Flutter, cioè la via
/// che non pesa sul thread dell'interfaccia; l'ultima è quella che c'era
/// prima, e resta per le tavole che nessuno ha ancora tagliato. Siccome le
/// righe sono le stesse, una fonte che manca lascia il posto alla seguente
/// senza che la striscia se ne accorga.
///
/// Il pezzo è riusabile apposta: chi disegna una fascia ne chiede una copia e
/// la restituisce, e finché qualcuno la tiene in mano nessuno gliela leva.
/// Quelle che non tiene più nessuno restano lì pronte finché c'è posto, e chi
/// esce per primo è chi è servito da più tempo.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../data/drive.dart';
import '../data/library.dart';
import '../data/network.dart';
import '../data/page_decoder.dart';
import '../data/phone_tiles.dart';
import '../data/reader_probe.dart';
import 'reader_metrics.dart';

/// Quale fascia, di quale tavola, a quale larghezza.
@immutable
class BandKey {
  const BandKey({
    required this.path,
    required this.top,
    required this.height,
    required this.width,
    this.tile,
    this.whole = false,
  });

  final String path;
  final int top;
  final int height;

  /// I pixel veri a cui la fascia si vede: è parte dell'identità, perché
  /// ruotando lo schermo la stessa fascia va decodificata di nuovo.
  final int width;

  /// La tessera dell'archivio che contiene esattamente queste righe, se c'è.
  /// Non è parte dell'identità: dice da dove prendere i pixel, non quali.
  final String? tile;

  /// Se la fascia è la tavola intera: si chiede al codec di Flutter.
  final bool whole;

  @override
  bool operator ==(Object other) =>
      other is BandKey &&
      other.path == path &&
      other.top == top &&
      other.height == height &&
      other.width == width;

  @override
  int get hashCode => Object.hash(path, top, height, width);
}

/// Una fascia in memoria, con chi la sta guardando.
///
/// È pubblica perché è ciò che il magazzino consegna e si fa restituire: chi
/// la tiene non ne guarda dentro, la passa indietro e basta.
class PageBand {
  PageBand(this.key);

  final BandKey key;
  final Set<VoidCallback> listeners = {};

  int leases = 0;
  ui.Image? image;

  /// La texture nativa che la mostra, al posto di [image], quando le fasce
  /// native si chiedono come texture.
  int? texture;
  int textureWidth = 0;
  int textureHeight = 0;
  double ratio = 0;

  /// La tessera dell'archivio non si è potuta leggere: da qui in poi la
  /// fascia si prende dalla tavola.
  bool tileFailed = false;
  Object? error;
  bool loading = false;
  bool wanted = true;

  /// Se si sta aspettando che la sua tavola arrivi da Drive. È un'attesa
  /// diversa da [loading]: non occupa il decodificatore.
  bool arriving = false;

  /// Quante volte di fila la rete l'ha fatta mancare: allunga l'attesa del
  /// tentativo seguente.
  int misses = 0;
  Timer? retry;

  bool get ready => image != null || texture != null;

  /// Una texture pesa due volte: la bitmap nativa da cui la si ridisegna e
  /// il buffer della superficie.
  int get bytes => image != null
      ? image!.width * image!.height * 4
      : textureWidth * textureHeight * 8;

  /// Da dove leggere i pixel adesso.
  String get source => key.tile != null && !tileFailed ? key.tile! : key.path;

  void notify() {
    for (final listener in listeners.toList(growable: false)) {
      listener();
    }
  }

  void discard(PageDecoder decoder) {
    retry?.cancel();
    retry = null;
    image?.dispose();
    image = null;
    final texture = this.texture;
    if (texture != null) decoder.releaseTexture(texture);
    this.texture = null;
  }
}

/// Il magazzino delle fasce.
class PageBandCache {
  PageBandCache({
    PageDecoder? decoder,
    NetworkMonitor? network,
    PhoneTiles? phoneTiles,
    this.budgetBytes = 64 << 20,
  })  : decoder = decoder ?? PageDecoder.instance,
        network = network ?? NetworkMonitor.instance,
        phoneTiles = phoneTiles ?? PhoneTiles.instance {
    this.network.online.addListener(_onNetwork);
  }

  static final PageBandCache instance = PageBandCache();

  final PageDecoder decoder;

  /// Chi dice quando la rete torna: è il momento di riprovare le fasce di
  /// Drive rimaste senza tavola.
  final NetworkMonitor network;

  /// Le tessere tagliate dal telefono per le tavole alte che l'archivio non
  /// ha diviso.
  final PhoneTiles phoneTiles;

  /// Quanti byte di fasce si possono tenere. Il lettore lo rialza in base allo
  /// schermo: su un telefono grande una schermata di webtoon pesa il doppio e
  /// un magazzino troppo stretto vorrebbe dire ridecodificare scorrendo
  /// avanti e indietro, che è il modo di consumare batteria senza guadagnarci
  /// niente.
  int budgetBytes;

  /// Una decodifica alla volta. Il lato nativo ha un thread solo e chiedergli
  /// dieci fasce insieme non le farebbe arrivare prima: farebbe solo arrivare
  /// per ultima quella che si sta guardando.
  static const int _atOnce = 1;

  final LinkedHashMap<BandKey, PageBand> _bands = LinkedHashMap();
  final List<PageBand> _queue = [];
  int _bytes = 0;
  int _running = 0;

  int get bytes => _bytes;

  int get count => _bands.length;

  /// Prende una fascia e la tiene ferma finché non la si restituisce.
  PageBand acquire(BandKey key, VoidCallback listener) {
    final band = _touch(key);
    band.leases++;
    band.wanted = true;
    band.listeners.add(listener);
    // Tornando su una tavola che la rete aveva fatto mancare, con la rete di
    // nuovo presente, non si aspetta il tentativo programmato.
    if (isNetworkFailure(band.error) && network.isOnline) {
      band.retry?.cancel();
      band.retry = null;
      band.error = null;
    }
    _start(band);
    return band;
  }

  void release(PageBand band, VoidCallback listener) {
    band.listeners.remove(listener);
    band.leases--;
    if (band.leases <= 0) {
      band.leases = 0;
      band.wanted = false;
      _forgetIfEmpty(band);
      _evict();
    }
  }

  /// Una fascia passata sotto il dito senza arrivare non ha niente da
  /// tenere: lasciarla nella mappa voleva dire accumularne centinaia a ogni
  /// lancio, e ripercorrerle tutte a ogni sfratto.
  void _forgetIfEmpty(PageBand band) {
    if (band.leases > 0 || band.ready || band.loading || band.arriving) return;
    if (band.error != null || band.retry != null) return;
    if (identical(_bands[band.key], band)) _bands.remove(band.key);
  }

  /// Chiede una fascia senza tenerla: serve a portarsi avanti con il capitolo
  /// seguente, dove nessuno la sta ancora guardando.
  void prefetch(BandKey key) {
    final band = _touch(key);
    _start(band);
    _evict();
  }

  PageBand _touch(BandKey key) {
    final existing = _bands.remove(key);
    final band = existing ?? PageBand(key);
    _bands[key] = band;
    return band;
  }

  void _start(PageBand band) {
    if (band.loading || band.arriving || band.ready || band.error != null) {
      return;
    }
    final path = band.source;
    final remote = isRemote(path) ? RemoteFiles.instance : null;
    if (remote != null && remote.peek(path) == null) {
      ReaderProbe.instance.noteDriveWait();
      _await(band, remote.fetch(path));
      return;
    }
    _decode(band);
  }

  void _decode(PageBand band) {
    band.loading = true;
    _queue.add(band);
    _pump();
  }

  /// Una tavola di Drive che non è ancora sul telefono si aspetta fuori dal
  /// decodificatore, e senza passare davanti a nessuno: la scarica il
  /// precarico del lettore, in ordine di capitolo. Metterla in fila per la
  /// decodifica voleva dire fermare dietro a un download anche le fasce già
  /// scese, e chiederla urgente a ogni fascia che scorreva sotto il dito
  /// voleva dire scaricare il capitolo a salti.
  void _await(PageBand band, Future<String> arrival) {
    band.arriving = true;
    arrival.then(
      (_) {
        band.arriving = false;
        if (!identical(_bands[band.key], band)) return;
        if (!band.ready && (band.wanted || band.leases > 0)) {
          _decode(band);
        } else {
          _forgetIfEmpty(band);
        }
      },
      onError: (Object error) {
        band.arriving = false;
        // Chi non la guarda più non deve trovarla segnata come persa quando
        // ci torna: la chiederà da capo.
        if (!identical(_bands[band.key], band) || band.leases == 0) {
          _forgetIfEmpty(band);
          return;
        }
        if (_fallBack(band, error)) return;
        band.error = error;
        if (isNetworkFailure(error)) _retryLater(band);
        band.notify();
      },
    );
  }

  void _pump() {
    while (_running < _atOnce && _queue.isNotEmpty) {
      // L'ultima chiesta per prima: scorrendo, è quella sotto gli occhi.
      final band = _queue.removeLast();
      if (!band.wanted && band.leases == 0) {
        band.loading = false;
        _forgetIfEmpty(band);
        continue;
      }
      _running++;
      unawaited(_load(band));
    }
  }

  Future<void> _load(PageBand band) async {
    var fellBack = false;
    try {
      final decoded = await _fetch(band);
      if (!identical(_bands[band.key], band)) {
        decoded.image?.dispose();
        final texture = decoded.texture;
        if (texture != null) decoder.releaseTexture(texture);
        return;
      }
      band.image = decoded.image;
      band.texture = decoded.texture;
      band.textureWidth = decoded.width;
      band.textureHeight = decoded.height;
      band.ratio = decoded.ratio;
      band.misses = 0;
      _bytes += band.bytes;
    } on Object catch (error) {
      fellBack = _fallBack(band, error, loading: true);
      if (!fellBack) {
        band.error = error;
        if (isNetworkFailure(error)) _retryLater(band);
      }
    } finally {
      band.loading = false;
      _running--;
    }
    if (fellBack) {
      _start(band);
    } else {
      band.notify();
    }
    _evict();
    _pump();
  }

  /// I pixel della fascia, dalla prima fonte che li ha.
  Future<DecodedBand> _fetch(PageBand band) async {
    final key = band.key;
    final probe = ReaderProbe.instance;
    if (key.tile != null && !band.tileFailed) {
      final decoded = await decoder.decodeImage(key.tile!, targetWidth: key.width);
      probe.noteTile();
      return decoded;
    }
    if (key.whole) {
      final decoded = await decoder.decodeImage(key.path, targetWidth: key.width);
      probe.noteWhole();
      return decoded;
    }
    final made = phoneTiles.peek(key.path, key.top);
    if (made != null) {
      try {
        final decoded = await decoder.decodeImage(made, targetWidth: key.width);
        probe.notePhoneTile();
        return decoded;
      } on Object {
        // Il telefono può aver buttato la cartella delle tessere per fare
        // spazio: la fascia si ritaglia dalla tavola come prima.
        phoneTiles.forget(key.path);
      }
    }
    return decoder.decode(
      key.path,
      top: key.top,
      height: key.height,
      targetWidth: key.width,
    );
  }

  /// Una tessera dell'archivio che non c'è o non si apre non è una tavola
  /// persa: le stesse righe stanno nella tavola. Si riprova da lì, subito.
  /// Una rete che manca invece non si aggira — anche la tavola è su Drive —
  /// e resta un'attesa come le altre.
  bool _fallBack(PageBand band, Object error, {bool loading = false}) {
    if (band.key.tile == null || band.tileFailed || isNetworkFailure(error)) {
      return false;
    }
    band.tileFailed = true;
    if (!loading) _start(band);
    return true;
  }

  /// Una fascia persa per la rete si riprova da sola finché è sullo schermo:
  /// dopo due secondi, poi quattro, otto, fino a mezzo minuto. Senza rete il
  /// tentativo aspetta: lo farà partire [_onNetwork] quando torna.
  void _retryLater(PageBand band) {
    band.retry?.cancel();
    final seconds = (2 << band.misses).clamp(2, 30);
    band.misses++;
    band.retry = Timer(Duration(seconds: seconds), () {
      band.retry = null;
      if (network.isOnline) _again(band);
    });
  }

  void _again(PageBand band) {
    if (!identical(_bands[band.key], band) || band.error == null) return;
    if (band.leases == 0) {
      // Non la guarda più nessuno: la si dimentica, e chi tornerà a guardarla
      // la chiederà da capo.
      _bands.remove(band.key);
      return;
    }
    band.error = null;
    // L'avviso sparisce subito e torna il segnaposto dell'attesa: la tavola
    // sta arrivando.
    band.notify();
    _start(band);
  }

  /// Riprova adesso tutte le fasce perse per la rete. È ciò che succede
  /// quando la rete torna, e quando l'utente tocca «Riprova».
  void retryFailed() {
    for (final band in _bands.values.toList(growable: false)) {
      if (!isNetworkFailure(band.error)) continue;
      band.retry?.cancel();
      band.retry = null;
      _again(band);
    }
  }

  void _onNetwork() {
    if (network.isOnline) retryFailed();
  }

  /// Fa posto buttando le fasce che non guarda più nessuno, dalla più vecchia.
  /// Quelle in mano a qualcuno non si toccano: sono quelle sullo schermo.
  void _evict() {
    if (_bytes <= budgetBytes) return;
    for (final band in _bands.values.toList(growable: false)) {
      if (_bytes <= budgetBytes) break;
      if (band.leases > 0 || band.loading) continue;
      _bytes -= band.bytes;
      band.discard(decoder);
      _bands.remove(band.key);
    }
  }

  /// Svuota tutto: uscendo dal lettore non c'è più niente da rivedere.
  void clear() {
    for (final band in _bands.values) {
      if (band.leases == 0) band.discard(decoder);
    }
    _bands.removeWhere((_, band) => band.leases == 0);
    _bytes = _bands.values.fold(0, (sum, band) => sum + band.bytes);
  }
}

/// Una fascia disegnata.
///
/// Chiede la sua al magazzino quando entra nello schermo e la restituisce
/// appena ne esce: è la lista a decidere quali esistono, e quindi quanta
/// memoria il lettore occupa davvero.
class PageBandView extends StatefulWidget {
  const PageBandView({
    required this.path,
    required this.band,
    this.tile,
    required this.width,
    required this.fit,
    this.alignment = Alignment.topCenter,
    this.cache,
    this.onRatio,
    this.placeholder,
    this.errorBuilder,
    super.key,
  });

  final String path;
  final StripBand band;

  /// La tessera dell'archivio con queste righe, se la fascia ne è una.
  final String? tile;

  /// La larghezza a cui la fascia si vede, in pixel logici.
  final double width;

  final BoxFit fit;
  final AlignmentGeometry alignment;
  final PageBandCache? cache;

  /// Il rapporto vero, appena la decodifica lo rende noto: è quello che
  /// toglie il buco fra una fascia e la seguente quando l'indice sbagliava.
  final ValueChanged<double>? onRatio;

  final Widget? placeholder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<PageBandView> createState() => _PageBandViewState();
}

class _PageBandViewState extends State<PageBandView> {
  PageBandCache get _cache => widget.cache ?? PageBandCache.instance;

  PageBand? _held;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _request();
  }

  @override
  void didUpdateWidget(PageBandView old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path ||
        old.tile != widget.tile ||
        old.width != widget.width ||
        old.band.top != widget.band.top ||
        old.band.height != widget.band.height) {
      _request();
    }
  }

  void _request() {
    final key = BandKey(
      path: widget.path,
      top: widget.band.height <= 0 ? 0 : widget.band.top,
      height: widget.band.height,
      width: (widget.width * MediaQuery.devicePixelRatioOf(context)).round(),
      tile: widget.tile,
      whole: widget.band.whole,
    );
    if (_held?.key == key) return;
    _drop();
    final band = _cache.acquire(key, _changed);
    _held = band;
    if (band.ready) _report(band);
  }

  void _drop() {
    final held = _held;
    if (held != null) _cache.release(held, _changed);
    _held = null;
  }

  void _changed() {
    if (!mounted) return;
    final band = _held;
    if (band != null && band.ready) _report(band);
    setState(() {});
  }

  void _report(PageBand band) {
    if (band.ratio > 0) widget.onRatio?.call(band.ratio);
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band = _held;
    final error = band?.error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error) ?? const SizedBox.expand();
    }
    // Le fasce interne si sovrappongono di mezzo pixel a quella dopo: alla
    // larghezza dello schermo il bordo fra due fasce cade a metà di un pixel
    // del dispositivo, e senza sovrapposizione ci si vede lo sfondo
    // attraverso.
    final bleed = widget.band.index + 1 < widget.band.count ? 0.5 : 0.0;
    final texture = band?.texture;
    if (band != null && texture != null) {
      return _TextureBand(
        texture: texture,
        width: band.textureWidth,
        height: band.textureHeight,
        fit: widget.fit,
        alignment: widget.alignment.resolve(Directionality.maybeOf(context)),
        bleed: bleed,
      );
    }
    final image = band?.image;
    if (image == null) return widget.placeholder ?? const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      isComplex: true,
      painter: PageBandPainter(
        image: image,
        fit: widget.fit,
        alignment: widget.alignment.resolve(Directionality.maybeOf(context)),
        bleed: bleed,
      ),
    );
  }
}

/// Una fascia che i pixel li ha nel Kotlin: la texture si adatta al posto
/// come l'immagine, e scende di [bleed] sotto il bordo allungandosi di
/// altrettanto — una texture non si può disegnare oltre il suo riquadro.
class _TextureBand extends StatelessWidget {
  const _TextureBand({
    required this.texture,
    required this.width,
    required this.height,
    required this.fit,
    required this.alignment,
    required this.bleed,
  });

  final int texture;
  final int width;
  final int height;
  final BoxFit fit;
  final Alignment alignment;
  final double bleed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final stretch =
              bleed > 0 && size.height > 0 ? (size.height + bleed) / size.height : 1.0;
          return Transform.scale(
            scaleY: stretch,
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: fit,
              alignment: alignment,
              child: SizedBox(
                width: width.toDouble(),
                height: height.toDouble(),
                child: Texture(
                  textureId: texture,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          );
        },
      );
}

class PageBandPainter extends CustomPainter {
  PageBandPainter({
    required this.image,
    required this.fit,
    required this.alignment,
    required this.bleed,
  });

  final ui.Image image;
  final BoxFit fit;
  final Alignment alignment;
  final double bleed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final source = Size(image.width.toDouble(), image.height.toDouble());
    final sizes = applyBoxFit(fit, source, size);
    final destination = alignment.inscribe(
      sizes.destination,
      Offset.zero & size,
    );
    final from = alignment.inscribe(sizes.source, Offset.zero & source);
    // Una fascia non deve mai disegnare fuori dal posto che le tocca: con un
    // rapporto dichiarato male, prima che la correzione arrivi, si
    // sovrapporrebbe a quella dopo.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height + bleed));
    canvas.drawImageRect(
      image,
      from,
      Rect.fromLTRB(
        destination.left,
        destination.top,
        destination.right,
        destination.bottom + bleed,
      ),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = false,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PageBandPainter old) =>
      old.image != image ||
      old.fit != fit ||
      old.alignment != alignment ||
      old.bleed != bleed;
}
