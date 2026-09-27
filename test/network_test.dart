/// La rete che va e viene: quello che deve succedere senza, e quando torna.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/page_decoder.dart';
import 'package:kagami/src/ui/page_bands.dart';

import 'network_helpers.dart';

Future<ui.Image> square(int side) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(Uint8List(side * side * 4));
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: side,
    height: side,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Un decodificatore che fallisce per la rete finché la si lascia fallire.
class FlakyDecoder extends PageDecoder {
  FlakyDecoder() : super(native: false);

  bool offline = true;
  int calls = 0;

  @override
  Future<DecodedBand> decode(
    String address, {
    int top = 0,
    int height = 0,
    required int targetWidth,
  }) async {
    calls++;
    if (offline) throw const DriveOffline();
    return DecodedBand(await square(8), 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('il monitor', () {
    test('una richiesta fallita, confermata dalla sonda, vuol dire offline',
        () async {
      final network = monitor(reachable: false);
      expect(network.isOnline, isTrue);
      network.failed();
      await network.check();
      expect(network.isOnline, isFalse);

      var back = false;
      unawaited(network.whenOnline().then((_) => back = true));
      await (network as Switchable).goOnline();
      await pumpEventQueue();
      expect(network.isOnline, isTrue);
      expect(back, isTrue);
      network.dispose();
    });

    test('su una rete a scatti una richiesta persa non basta', () async {
      final network = monitor();
      network.failed();
      await network.check();
      expect(network.isOnline, isTrue);
    });
  });

  group('le fasce', () {
    test('senza rete la fascia avvisa, e tornata la rete arriva da sola',
        () async {
      final network = monitor();
      final decoder = FlakyDecoder();
      final cache = PageBandCache(decoder: decoder, network: network);
      var changes = 0;
      final arrived = Completer<void>();
      late final PageBand band;
      band = cache.acquire(
        const BandKey(path: 'drive:S/c/1.webp', top: 0, height: 0, width: 8),
        () {
          changes++;
          if (band.image != null && !arrived.isCompleted) arrived.complete();
        },
      );
      await pumpEventQueue();
      expect(isNetworkFailure(band.error), isTrue);

      decoder.offline = false;
      await (network as Switchable).goOffline();
      await network.goOnline();
      await arrived.future;
      expect(band.error, isNull);
      expect(band.image, isNotNull);
      expect(changes, greaterThanOrEqualTo(2));
      band.discard(decoder);
    });

    test('una tavola guardata di nuovo, con la rete, riparte subito', () async {
      final network = monitor();
      final decoder = FlakyDecoder();
      final cache = PageBandCache(decoder: decoder, network: network);
      const key = BandKey(path: 'drive:S/c/2.webp', top: 0, height: 0, width: 8);
      void listener() {}
      final band = cache.acquire(key, listener);
      await pumpEventQueue();
      expect(band.error, isNotNull);
      cache.release(band, listener);

      decoder.offline = false;
      // Si aspetta l'avviso e non un numero di giri della coda: l'immagine la
      // crea l'engine, e con la macchina carica arriva quando vuole.
      final arrived = Completer<void>();
      void notified() {
        if (!arrived.isCompleted) arrived.complete();
      }
      final again = cache.acquire(key, notified);
      await arrived.future;
      expect(again.image, isNotNull);
      expect(decoder.calls, 2);
      again.discard(decoder);
    });
  });
}
