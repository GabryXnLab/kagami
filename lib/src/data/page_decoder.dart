/// Da file a immagine: una fascia alla volta, mai la tavola intera.
///
/// Una tavola di webtoon arriva a 16383 pixel di altezza. Chiederla a
/// `dart:ui` — che sia `Image.file`, `ResizeImage` o il codec a mano — vuol
/// dire in ogni caso decomprimerla tutta in memoria: cinquanta megabyte per
/// tavola, tre o quattro tavole vive nella lista, e il sistema chiude l'app.
/// Ridurre la risoluzione risolverebbe la memoria buttando via l'unica cosa
/// che il lettore deve fare bene, cioè mostrare la tavola com'è.
///
/// Android sa fare di meglio: `BitmapRegionDecoder` apre il file e ne
/// decodifica **un ritaglio**, con il sottocampionamento che serve e senza
/// passare dalla bitmap intera. È la stessa cosa che fa una mappa quando la
/// si scorre, ed è l'unica che tenga insieme piena qualità e memoria
/// costante.
///
/// Dove quel decodificatore non c'è — la build Linux, i test — si ricade sul
/// codec di `dart:ui`, che la tavola la prende intera: lì [bandHeight] dice
/// al lettore di non tagliare niente e un tetto ai pixel evita il disastro.
///
/// Il ritaglio nativo però è l'ultima risorsa, non la via normale. Un file
/// che si può decodificare intero — una tessera dell'archivio, una tavola
/// bassa, una tessera fatta dal telefono — passa da [PageDecoder.decodeImage],
/// cioè dal codec di Flutter: legge il file e decodifica fuori dal thread
/// dell'interfaccia, su più thread insieme, e i pixel non attraversano mai
/// Dart. Le fasce native invece arrivano come byte in una risposta, che Dart
/// deve ricopiare e che pesa sul suo raccoglitore; oppure, con le texture
/// accese, restano nel Kotlin e arrivano alla GPU senza passare di qui.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'library.dart';
import 'reader_probe.dart';

/// Il canale del decodificatore nativo. Il nome sta anche nel Kotlin di
/// `android/app/src/main/kotlin/dev/local/kagami/PageDecoder.kt`.
const MethodChannel pageDecoderChannel = MethodChannel('kagami/pages');

/// Il tetto ai pixel di una singola decodifica.
///
/// Una fascia non ci arriva mai nemmeno da lontano. Ci arriva una tavola
/// chiesta intera — perché l'indice non ne dichiarava le dimensioni, o perché
/// il decodificatore a ritagli non c'è — e per quella il tetto è l'ultima
/// difesa: meglio una tavola ridotta che l'app che sparisce.
const int maxWholePagePixels = 8 * 1000 * 1000;

/// Le dimensioni reali di un'immagine appena decodificata.
///
/// È un'immagine di `dart:ui` oppure una texture nativa: la seconda i pixel
/// li tiene il Kotlin, e da qui se ne conosce solo il numero e la misura.
class DecodedBand {
  const DecodedBand(ui.Image this.image, this.ratio)
      : texture = null,
        width = 0,
        height = 0;

  const DecodedBand.texture(int this.texture, this.width, this.height)
      : image = null,
        ratio = width / height;

  final ui.Image? image;
  final int? texture;

  /// La misura della texture; per un'immagine vale quella dell'immagine.
  final int width;
  final int height;

  /// Il rapporto della fascia com'è uscita dalla sorgente: è quello che
  /// corregge la geometria quando `pages.json` mente.
  final double ratio;
}

/// Il decodificatore: uno per tutta l'app.
class PageDecoder {
  PageDecoder({this.channel = pageDecoderChannel, bool? native})
      : _native = native ?? (!kIsWeb && Platform.isAndroid);

  static final PageDecoder instance = PageDecoder();

  final MethodChannel channel;

  /// Se il decodificatore a ritagli è disponibile. Si spegne da sé alla prima
  /// chiamata che non trova il canale: succede una volta sola, non a ogni
  /// fascia.
  bool _native;

  /// Se si può chiedere un pezzo di tavola invece della tavola intera. È la
  /// domanda da cui dipende se la striscia si taglia in fasce.
  bool get canDecodeRegions => _native;

  /// Se le fasce native si chiedono come texture invece che come pixel.
  ///
  /// È una prova, accesa dalle impostazioni: i pixel non passano più da Dart,
  /// ma il disegno sulla superficie nativa si può giudicare solo a occhio,
  /// su un telefono. Se il Kotlin dice di non saperle fare si spegne da sé. Non
  /// si salva, come la misura: riaprendo l'app si torna ai pixel.
  final ValueNotifier<bool> textureMode = ValueNotifier(false);

  bool get textures => textureMode.value;
  set textures(bool value) => textureMode.value = value;

  /// Una tavola o una tessera intera, dal codec di Flutter.
  ///
  /// [targetWidth] è un tetto: un file più stretto resta com'è.
  Future<DecodedBand> decodeImage(String address, {required int targetWidth}) async {
    final path = await localFileOf(address);
    return _decodeWhole(path, 0, 0, targetWidth);
  }

  /// Una fascia della tavola [address], larga [targetWidth] pixel sullo schermo.
  ///
  /// [top] e [height] sono pixel della sorgente; `height` a zero vuol dire
  /// tutta la tavola. La larghezza chiesta è un tetto, non una misura: una
  /// tavola più stretta resta com'è — ingrandirla per riempire lo schermo
  /// vorrebbe dire quadruplicare la memoria per non aggiungere un dettaglio.
  ///
  /// [address] può essere una tavola di Drive: la si porta sul telefono
  /// prima, e da lì in poi è un file come gli altri.
  Future<DecodedBand> decode(
    String address, {
    int top = 0,
    int height = 0,
    required int targetWidth,
  }) async {
    final path = await localFileOf(address);
    if (_native) {
      final band = await _decodeNative(path, top, height, targetWidth);
      if (band != null) return band;
    }
    ReaderProbe.instance.noteWholeDecode();
    return _decodeWhole(path, top, height, targetWidth);
  }

  /// Restituisce al Kotlin una texture che nessuno mostra più.
  void releaseTexture(int texture) {
    if (!_native) return;
    final sent = channel.binaryMessenger.send(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('release', {'texture': texture}),
      ),
    );
    if (sent != null) unawaited(sent.then((_) {}, onError: (Object _) {}));
  }

  /// Taglia la tavola [path] — un file sul telefono — in tessere JPEG alte
  /// [bandHeight] righe della sorgente, dentro [directory]: è il lavoro che
  /// l'archivio fa per le tavole nuove, rifatto qui per quelle archiviate
  /// prima. Il Kotlin lo fa quando non ha fasce da dare, un pezzo alla volta.
  ///
  /// Dice se le tessere ci sono: `false` anche dove il canale non c'è.
  Future<bool> tile(
    String path, {
    required String directory,
    required int bandHeight,
    required int targetWidth,
  }) async {
    if (!_native) return false;
    final reply = await _call('tile', {
      'path': path,
      'directory': directory,
      'bandHeight': bandHeight,
      'targetWidth': targetWidth,
    });
    return reply != null;
  }

  Future<DecodedBand?> _decodeNative(
    String path,
    int top,
    int height,
    int targetWidth,
  ) async {
    final asked = Stopwatch()..start();
    final texture = textures;
    var reply = await _call('decode', {
      'path': path,
      'top': top,
      'height': height,
      'targetWidth': targetWidth,
      'maxPixels': maxWholePagePixels,
      'texture': texture,
    });
    if (texture && reply == null && _lastStatus == _noTextures) {
      // Il Kotlin non sa fare le texture su questo telefono: si torna ai
      // pixel, per questa fascia e per tutte le prossime.
      textures = false;
      reply = await _call('decode', {
        'path': path,
        'top': top,
        'height': height,
        'targetWidth': targetWidth,
        'maxPixels': maxWholePagePixels,
        'texture': false,
      });
    }
    if (reply == null || reply.lengthInBytes < _header) return null;
    final width = reply.getInt32(4, Endian.little);
    final tall = reply.getInt32(8, Endian.little);
    if (width <= 0 || tall <= 0) return null;
    final native = asked.elapsed;
    final decode = Duration(microseconds: reply.getInt32(16, Endian.little));
    final probe = ReaderProbe.instance;
    probe.noteRuntime(
      gcCount: reply.getInt32(20, Endian.little),
      gcMillis: reply.getInt32(24, Endian.little),
      blockingCount: reply.getInt32(28, Endian.little),
      blockingMillis: reply.getInt32(32, Endian.little),
      pageDecoded: reply.getInt32(40, Endian.little) != 0,
    );
    final id = reply.getInt32(36, Endian.little);
    if (id >= 0) {
      probe.noteBand(native: native, decode: decode, copy: Duration.zero, texture: true);
      return DecodedBand.texture(id, width, tall);
    }
    final rowBytes = reply.getInt32(12, Endian.little);
    final pixels = reply.buffer.asUint8List(
      reply.offsetInBytes + _header,
      reply.lengthInBytes - _header,
    );
    // Da qui la risposta non serve più: non deve restare viva attraverso le
    // attese che seguono, o il raccoglitore la promuove con i suoi megabyte.
    reply = null;
    final image = await _fromPixels(
      pixels,
      width,
      tall,
      rowBytes,
      native: native,
      decode: decode,
    );
    return DecodedBand(image, width / tall);
  }

  /// La via di ripiego: la tavola intera, ridotta quanto basta a non essere
  /// un pericolo, e ritagliata dopo se la fascia era un pezzo.
  Future<DecodedBand> _decodeWhole(
    String path,
    int top,
    int height,
    int targetWidth,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final source = (width: descriptor.width, height: descriptor.height);
    var width = targetWidth < source.width ? targetWidth : source.width;
    if (width < 1) width = 1;
    var tall = (source.height * width / source.width).round();
    if (tall < 1) tall = 1;
    if (width * tall > maxWholePagePixels) {
      final factor = maxWholePagePixels / (width * tall);
      width = (width * factor).floor().clamp(1, source.width);
      tall = (source.height * width / source.width).round().clamp(1, 1 << 20);
    }
    final codec = await descriptor.instantiateCodec(
      targetWidth: width,
      targetHeight: tall,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    final whole = frame.image;
    if (height <= 0 || height >= source.height) {
      return DecodedBand(whole, whole.width / whole.height);
    }
    final band = await _crop(whole, top / source.height, height / source.height);
    whole.dispose();
    return band;
  }

  Future<DecodedBand> _crop(ui.Image whole, double top, double height) async {
    final cut = (whole.height * height).round().clamp(1, whole.height);
    final from = (whole.height * top).round().clamp(0, whole.height - cut);
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      whole,
      ui.Rect.fromLTWH(0, from.toDouble(), whole.width.toDouble(), cut.toDouble()),
      ui.Rect.fromLTWH(0, 0, whole.width.toDouble(), cut.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(whole.width, cut);
    picture.dispose();
    return DecodedBand(image, whole.width / cut);
  }

  Future<ui.Image> _fromPixels(
    Uint8List pixels,
    int width,
    int height,
    int? rowBytes, {
    required Duration native,
    required Duration decode,
  }) async {
    // La copia avviene dentro la chiamata, prima che il futuro torni: è la
    // parte che pesa sul thread dell'interfaccia.
    final copying = Stopwatch()..start();
    final copied = ui.ImmutableBuffer.fromUint8List(pixels);
    ReaderProbe.instance.noteBand(
      native: native,
      decode: decode,
      copy: copying.elapsed,
    );
    final buffer = await copied;
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      rowBytes: rowBytes,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return frame.image;
  }

  /// Dodici `int32` davanti ai pixel: esito, larghezza, altezza, byte per
  /// riga, microsecondi di decodifica, poi quattro contatori del GC di
  /// Android (raccolte e millisecondi, tutte e bloccanti), il numero della
  /// texture (-1 se la fascia è in pixel), se per questa fascia si è
  /// decodificata una tavola intera, e uno di riserva. Il perché di un
  /// formato proprio invece di `invokeMethod` sta in `PageDecoder.kt`: i
  /// pixel non devono passare dal codec standard sul thread dell'interfaccia.
  static const int _header = 48;

  /// L'esito con cui il Kotlin dice di non saper fare le texture.
  static const int _noTextures = 2;

  int _lastStatus = 0;

  /// Una chiamata al canale che non fa saltare la lettura se il canale non
  /// c'è: si spegne il decodificatore nativo e si continua con l'altro.
  ///
  /// Un esito diverso da zero è un file che il decodificatore a ritagli non
  /// sa aprire, e non lo spegne: lo sa aprire forse l'altro, e il resto del
  /// capitolo continua a passare di qui.
  Future<ByteData?> _call(String method, Map<String, Object?> arguments) async {
    final reply = await channel.binaryMessenger.send(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    );
    if (reply == null) {
      _native = false;
      return null;
    }
    _lastStatus = reply.lengthInBytes < 4 ? 1 : reply.getInt32(0, Endian.little);
    if (_lastStatus != 0) return null;
    return reply;
  }
}
