/// La decodifica a fasce e il magazzino che le tiene: è la parte che decide
/// se scorrere un webtoon costa una schermata di memoria o una tavola da
/// cinquanta megabyte.
library;

import 'dart:ui' as ui;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/page_decoder.dart';
import 'package:kagami/src/data/phone_tiles.dart';
import 'package:kagami/src/ui/page_bands.dart';

/// Una fascia finta: quadrata, del lato chiesto, e costa quanto costerebbe.
Future<ui.Image> square(int side) async {
  final pixels = Uint8List(side * side * 4);
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: side,
    height: side,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}

/// Un decodificatore che non legge niente: conta solo quante volte lo si
/// chiama, che è l'unica cosa che il magazzino deve far diminuire.
class CountingDecoder extends PageDecoder {
  CountingDecoder({this.side = 64}) : super(native: false);

  final int side;
  final List<String> calls = [];

  /// File che il codec di Flutter non sa aprire.
  final Set<String> broken = {};

  @override
  Future<DecodedBand> decode(
    String path, {
    int top = 0,
    int height = 0,
    required int targetWidth,
  }) async {
    calls.add('$path:$top');
    return DecodedBand(await square(side), 1);
  }

  @override
  Future<DecodedBand> decodeImage(String address, {required int targetWidth}) async {
    calls.add('intera $address');
    if (broken.contains(address)) throw const FileSystemException('manca');
    return DecodedBand(await square(side), 1);
  }
}

/// Tessere del telefono già pronte per le tavole elencate.
class ReadyTiles extends PhoneTiles {
  ReadyTiles(this.pages);

  final Set<String> pages;

  @override
  String? peek(String address, int top) =>
      pages.contains(address) ? '/tessere/$address/$top.jpg' : null;
}

/// Un Drive in cui le tavole arrivano quando lo dice il test.
class HeldDrive implements RemoteFiles {
  final Map<String, Completer<String>> arriving = {};
  final Set<String> here = {};
  final List<String> urgent = [];

  void arrive(String address) {
    here.add(address);
    arriving.remove(address)?.complete(address);
  }

  @override
  Future<String> fetch(String address, {bool urgent = false}) {
    if (here.contains(address)) return Future.value(address);
    if (urgent) this.urgent.add(address);
    return arriving.putIfAbsent(address, Completer.new).future;
  }

  @override
  String? peek(String address) => here.contains(address) ? address : null;

  @override
  void warm(Iterable<String> addresses) {}

  @override
  void rememberChapter(String series, String chapter, List<String> addresses) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('il decodificatore', () {
    tearDown(
      () => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMessageHandler(pageDecoderChannel.name, null),
    );

    /// Risponde come `PageDecoder.kt`: una risposta nulla è il canale che
    /// non c'è.
    void answer(ByteData? Function(MethodCall call) handler) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(
          pageDecoderChannel.name,
          (message) async =>
              handler(pageDecoderChannel.codec.decodeMethodCall(message)),
        );

    /// L'intestazione di `PageDecoder.kt`: dodici `int32`, con la texture a
    /// -1 quando i pixel viaggiano nella risposta.
    ByteData header(int size, {int status = 0, int width = 0, int height = 0, int texture = -1}) =>
        ByteData(size)
          ..setInt32(0, status, Endian.little)
          ..setInt32(4, width, Endian.little)
          ..setInt32(8, height, Endian.little)
          ..setInt32(12, width * 4, Endian.little)
          ..setInt32(16, 1500, Endian.little)
          ..setInt32(36, texture, Endian.little);

    ByteData pixels(int width, int height) =>
        header(48 + width * height * 4, width: width, height: height);

    test('una fascia nativa arriva come immagine con il suo rapporto', () async {
      late MethodCall received;
      answer((call) {
        received = call;
        return pixels(4, 2);
      });

      final band = await PageDecoder(native: true)
          .decode('/tavola.webp', top: 1536, height: 1536, targetWidth: 1080);

      expect(received.method, 'decode');
      expect(received.arguments['top'], 1536);
      expect(received.arguments['targetWidth'], 1080);
      expect(band.image!.width, 4);
      expect(band.image!.height, 2);
      expect(band.ratio, 2);
    });

    test('una fascia come texture non porta pixel', () async {
      late MethodCall received;
      answer((call) {
        received = call;
        return header(48, width: 720, height: 512, texture: 7);
      });
      final decoder = PageDecoder(native: true)..textures = true;

      final band = await decoder.decode('/tavola.webp', top: 0, height: 512, targetWidth: 1080);

      expect(received.arguments['texture'], isTrue);
      expect(band.image, isNull);
      expect(band.texture, 7);
      expect(band.ratio, 720 / 512);
    });

    test('se il telefono non sa fare texture si torna ai pixel', () async {
      final asked = <bool>[];
      answer((call) {
        final texture = call.arguments['texture'] as bool;
        asked.add(texture);
        return texture ? (ByteData(4)..setInt32(0, 2, Endian.little)) : pixels(4, 2);
      });
      final decoder = PageDecoder(native: true)..textures = true;

      final band = await decoder.decode('/tavola.webp', top: 0, height: 512, targetWidth: 1080);

      expect(asked, [true, false]);
      expect(band.image, isNotNull);
      expect(decoder.textures, isFalse);
    });

    test('senza canale il lettore smette di chiedere ritagli', () async {
      answer((call) => null);
      final decoder = PageDecoder(native: true);

      // Il primo tentativo spegne il decodificatore nativo: da lì in poi il
      // lettore non taglia più niente e si arrangia con il codec di Flutter,
      // che su un file inesistente fallisce — ed è quello che deve fare.
      expect(decoder.canDecodeRegions, isTrue);
      await expectLater(
        decoder.decode('/manca.webp', targetWidth: 1080),
        throwsA(anything),
      );
      expect(decoder.canDecodeRegions, isFalse);
    });

    test('un file che non si lascia ritagliare non spegne i ritagli', () async {
      answer((call) => ByteData(4)..setInt32(0, 1, Endian.little));
      final decoder = PageDecoder(native: true);

      await expectLater(
        decoder.decode('/strana.webp', targetWidth: 1080),
        throwsA(anything),
      );
      expect(decoder.canDecodeRegions, isTrue);
    });
  });

  group('il magazzino delle fasce', () {
    /// Prende una fascia e aspetta che sia arrivata: il magazzino avvisa chi
    /// la tiene, e quell'avviso è tutto ciò che serve per non misurare il
    /// tempo a occhio.
    Future<PageBand> hold(
      PageBandCache cache,
      BandKey key,
      VoidCallback listener,
    ) async {
      final band = cache.acquire(key, listener);
      while (band.image == null && band.error == null) {
        await Future<void>.delayed(Duration.zero);
      }
      return band;
    }

    test('la stessa fascia non si decodifica due volte', () async {
      final decoder = CountingDecoder();
      final cache = PageBandCache(decoder: decoder);
      const key = BandKey(path: '/a.webp', top: 0, height: 1536, width: 1080);
      void nothing() {}

      final first = await hold(cache, key, nothing);
      final second = await hold(cache, key, nothing);

      expect(identical(first, second), isTrue);
      expect(decoder.calls, ['/a.webp:0']);
      expect(first.image, isNotNull);
      expect(cache.bytes, 64 * 64 * 4);
    });

    test('quando non c\'è più posto escono quelle che non guarda nessuno',
        () async {
      final decoder = CountingDecoder();
      // Due fasce di posto: la terza deve far uscire la prima.
      final cache =
          PageBandCache(decoder: decoder, budgetBytes: 64 * 64 * 4 * 2);
      void nothing() {}

      for (final top in [0, 1536, 3072]) {
        final key =
            BandKey(path: '/a.webp', top: top, height: 1536, width: 1080);
        cache.release(await hold(cache, key, nothing), nothing);
      }

      expect(cache.count, 2);
      expect(cache.bytes, lessThanOrEqualTo(64 * 64 * 4 * 2));
    });

    group('con Drive', () {
      late HeldDrive drive;
      setUp(() => RemoteFiles.instance = drive = HeldDrive());
      tearDown(() => RemoteFiles.instance = null);

      test('una tavola ancora in viaggio non ferma quelle già scese',
          () async {
        final decoder = CountingDecoder();
        final cache = PageBandCache(decoder: decoder);
        void nothing() {}
        const away =
            BandKey(path: 'drive:S/c/1.webp', top: 0, height: 1536, width: 1080);
        const ready =
            BandKey(path: 'drive:S/c/2.webp', top: 0, height: 1536, width: 1080);
        drive.here.add(ready.path);

        final waiting = cache.acquire(away, nothing);
        final shown = await hold(cache, ready, nothing);

        expect(shown.image, isNotNull);
        expect(waiting.image, isNull);
        expect(decoder.calls, ['drive:S/c/2.webp:0']);
        // Aspettarla non la fa passare davanti al precarico.
        expect(drive.urgent, isEmpty);

        drive.arrive(away.path);
        await hold(cache, away, nothing);
        expect(decoder.calls, hasLength(2));
      });

      test('arrivata quando nessuno la guarda più, non si decodifica',
          () async {
        final decoder = CountingDecoder();
        final cache = PageBandCache(decoder: decoder);
        void nothing() {}
        const key =
            BandKey(path: 'drive:S/c/3.webp', top: 0, height: 1536, width: 1080);

        cache.release(cache.acquire(key, nothing), nothing);
        drive.arrive(key.path);
        await pumpEventQueue();
        expect(decoder.calls, isEmpty);

        await hold(cache, key, nothing);
        expect(decoder.calls, hasLength(1));
      });
    });

    test('le fonti si provano in ordine: tessera, intera, telefono, ritaglio',
        () async {
      final decoder = CountingDecoder();
      final cache = PageBandCache(
        decoder: decoder,
        phoneTiles: ReadyTiles({'/c.webp'}),
      );
      void nothing() {}

      await hold(cache, const BandKey(path: '/a.webp', top: 0, height: 1000, width: 1080, tile: '/a-01.webp'), nothing);
      await hold(cache, const BandKey(path: '/b.webp', top: 0, height: 900, width: 1080, whole: true), nothing);
      await hold(cache, const BandKey(path: '/c.webp', top: 512, height: 512, width: 1080), nothing);
      await hold(cache, const BandKey(path: '/d.webp', top: 512, height: 512, width: 1080), nothing);

      expect(decoder.calls, [
        'intera /a-01.webp',
        'intera /b.webp',
        'intera /tessere//c.webp/512.jpg',
        '/d.webp:512',
      ]);
    });

    test('una tessera che non si apre lascia il posto alla tavola', () async {
      final decoder = CountingDecoder()..broken.add('/a-02.webp');
      final cache = PageBandCache(decoder: decoder);
      void nothing() {}

      final band = await hold(
        cache,
        const BandKey(path: '/a.webp', top: 1000, height: 1000, width: 1080, tile: '/a-02.webp'),
        nothing,
      );

      expect(band.error, isNull);
      expect(band.image, isNotNull);
      expect(decoder.calls, ['intera /a-02.webp', '/a.webp:1000']);
    });

    test('una fascia passata senza arrivare non resta nel magazzino', () async {
      final decoder = CountingDecoder();
      final cache = PageBandCache(decoder: decoder);
      void nothing() {}

      await hold(cache, const BandKey(path: '/a.webp', top: 0, height: 512, width: 1080), nothing);
      for (final top in [512, 1024, 1536]) {
        final key = BandKey(path: '/a.webp', top: top, height: 512, width: 1080);
        cache.release(cache.acquire(key, nothing), nothing);
      }
      await pumpEventQueue();

      // La prima lasciata ha trovato il decodificatore libero ed è arrivata
      // lo stesso; le altre due non hanno niente da tenere e se ne vanno.
      expect(decoder.calls, ['/a.webp:0', '/a.webp:512']);
      expect(cache.count, 2);
    });

    test('la fascia che qualcuno sta guardando non esce', () async {
      final decoder = CountingDecoder();
      final cache = PageBandCache(decoder: decoder, budgetBytes: 1);
      void nothing() {}

      const held = BandKey(path: '/a.webp', top: 0, height: 1536, width: 1080);
      final band = await hold(cache, held, nothing);

      for (final top in [1536, 3072, 4608]) {
        final key =
            BandKey(path: '/a.webp', top: top, height: 1536, width: 1080);
        cache.release(await hold(cache, key, nothing), nothing);
      }

      expect(band.image, isNotNull);
      expect(cache.count, 1);
    });
  });
}
