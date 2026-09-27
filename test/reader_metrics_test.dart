/// La geometria della striscia, senza schermo: è la parte che decide se un
/// capitolo si legge senza buchi fra una tavola e l'altra, e da dove si
/// riprende quando lo si riapre.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/ui/reader_metrics.dart';

void main() {
  const width = 400.0;

  /// Una tavola come la dichiara `pages.json`.
  PageShape shape(int? w, int? h, [List<int> tiles = const []]) =>
      (width: w, height: h, tiles: tiles);

  group('il taglio in fasce', () {
    test('una tavola che ci sta resta intera', () {
      final strip = ChapterStrip([shape(720, 1000)], bandHeight: 1536);

      expect(strip.length, 1);
      expect(strip.bands.single.count, 1);
      expect(strip.bands.single.height, 1000);
      expect(strip.bands.single.ratio, 720 / 1000);
    });

    test('una tavola stitchata diventa una fascia per schermata', () {
      // 736 x 16383: la tavola più alta che WebP sappia scrivere. Intera
      // sarebbe una bitmap da quarantotto megabyte.
      final strip = ChapterStrip([shape(736, 16383)], bandHeight: 1536);

      expect(strip.length, 11);
      expect(strip.bands.first.top, 0);
      expect(strip.bands[1].top, 1536);
      // Nessuna fascia sfora la tavola, e insieme la coprono tutta.
      expect(strip.bands.last.top + strip.bands.last.height, 16383);
      expect(
        strip.bands.fold<int>(0, (sum, band) => sum + band.height),
        16383,
      );
      expect(strip.bands.every((band) => band.height <= 1536), isTrue);
    });

    test('le fasce di una tavola occupano quanto la tavola', () {
      final strip = ChapterStrip([shape(720, 3000)], bandHeight: 1000);

      expect(strip.length, 3);
      expect(strip.pageHeight(0, width), closeTo(width * 3000 / 720, 0.001));
    });

    test('le tessere dell\'archivio sono le fasce, con i loro bordi', () {
      final strip = ChapterStrip(
        [shape(720, 3000, [1000, 1000, 1000]), shape(720, 900)],
        bandHeight: 512,
      );

      expect(strip.length, 4);
      expect([for (final band in strip.bands) band.tile], [0, 1, 2, null]);
      expect([for (final band in strip.bands) band.top], [0, 1000, 2000, 0]);
      expect(strip.bands.first.ratio, 720 / 1000);
      expect(strip.bands.first.whole, isFalse);
      expect(strip.bands.last.whole, isTrue);
      expect(strip.pageHeight(0, width), closeTo(width * 3000 / 720, 0.001));
    });

    test('una tavola bassa resta intera anche potendo tagliarla', () {
      final strip = ChapterStrip([shape(720, 1800), shape(720, 4000)], bandHeight: 512);

      expect(strip.bands.where((band) => band.page == 0), hasLength(1));
      expect(strip.bands.first.whole, isTrue);
      // Quella alta senza tessere si taglia come sempre.
      expect(strip.bands.where((band) => band.page == 1), hasLength(8));
    });

    test('la lettura a pagine non usa le tessere', () {
      final strip = ChapterStrip(
        [shape(720, 3000, [1500, 1500])],
        bandHeight: wholePageBand,
        useTiles: false,
      );

      expect(strip.length, 1);
      expect(strip.bands.single.whole, isTrue);
    });

    test('senza dimensioni non si taglia niente', () {
      final strip = ChapterStrip([shape(null, null), shape(720, null)]);

      expect(strip.length, 2);
      expect(strip.bands.every((band) => band.height == 0), isTrue);
      expect(strip.ratioOf(0), unknownPageRatio);
      expect(strip.heightOf(0, width), closeTo(width * 1.45, 0.001));
    });
  });

  group('la striscia', () {
    test('le fasce si toccano: ogni bordo è il bordo della seguente', () {
      final strip = ChapterStrip([shape(700, 1000), shape(700, 2500)],
          bandHeight: 1000);
      final offsets = strip.offsets(width);

      expect(offsets.first, 0);
      expect(offsets.length, strip.length + 1);
      for (var band = 0; band < strip.length; band++) {
        expect(
          offsets[band + 1] - offsets[band],
          closeTo(strip.heightOf(band, width), 0.0001),
        );
      }
      expect(
        offsets.last,
        closeTo(
          strip.pageHeight(0, width) + strip.pageHeight(1, width),
          0.001,
        ),
      );
    });

    test('il rapporto misurato ha la precedenza su quello dichiarato', () {
      final strip = ChapterStrip([shape(400, 800), shape(400, 800)],
          bandHeight: 1536);
      strip.apply({0: 2}, width: width, top: 0);

      expect(strip.ratioOf(0), 2);
      expect(strip.heightOf(0, width), closeTo(width / 2, 0.001));
      // Il vicino non si muove: si corregge solo quello che è stato misurato.
      expect(strip.ratioOf(1), 0.5);
    });

    test(
        'correggere una fascia già passata sposta lo scorrimento di altrettanto',
        () {
      final strip = ChapterStrip(
        [shape(400, 800), shape(400, 800), shape(400, 800)],
        bandHeight: 1536,
      );
      // La prima fascia è alta 800 e l'occhio sta sulla seconda.
      final shift = strip.apply({0: 1}, width: width, top: 900);

      expect(shift, closeTo(width / 1 - width / 0.5, 0.001));
      expect(shift, lessThan(0));
    });

    test('correggere una fascia non ancora raggiunta non sposta niente', () {
      final strip = ChapterStrip(
        [shape(400, 800), shape(400, 800), shape(400, 800)],
        bandHeight: 1536,
      );
      final shift = strip.apply({2: 1}, width: width, top: 10);

      expect(shift, 0);
      expect(strip.ratioOf(2), 1);
    });

    test('un rapporto assurdo o fuori elenco viene ignorato', () {
      final strip = ChapterStrip([shape(400, 800)], bandHeight: 1536);
      strip.apply({0: 0, 5: 2}, width: width, top: 0);

      expect(strip.ratioOf(0), 0.5);
      expect(strip.length, 1);
    });

    test('una correzione che non si vedrebbe non vale una ricostruzione', () {
      final strip = ChapterStrip([shape(400, 800)], bandHeight: 1536);

      // Un millesimo di rapporto su quattrocento pixel non muove niente.
      expect(strip.worthApplying(0, 0.50001, width), isFalse);
      expect(strip.worthApplying(0, 0.6, width), isTrue);
      expect(strip.worthApplying(0, 0, width), isFalse);
      expect(strip.worthApplying(0, 1, 0), isFalse);
    });

    test('la fascia sotto un punto si trova dai suoi bordi', () {
      final strip = ChapterStrip(
        [shape(400, 400), shape(400, 400), shape(400, 400)],
      );
      final offsets = strip.offsets(width);

      expect(strip.bandAt(0, offsets), 0);
      expect(strip.bandAt(width - 1, offsets), 0);
      expect(strip.bandAt(width, offsets), 1);
      expect(strip.bandAt(width * 2.5, offsets), 2);
      expect(strip.bandAt(width * 99, offsets), 2);
    });
  });

  group('dove si è arrivati', () {
    test('la posizione dice la tavola e quanto se n\'è passato', () {
      final strip = ChapterStrip([shape(720, 3000), shape(720, 3000)],
          bandHeight: 1000);
      final page = strip.pageHeight(0, width);

      expect(strip.positionAt(0, width), const ReadingSpot(0, 0));
      expect(strip.positionAt(page / 2, width).page, 0);
      expect(strip.positionAt(page / 2, width).fraction, closeTo(0.5, 0.001));
      expect(strip.positionAt(page * 1.25, width).page, 1);
      expect(
        strip.positionAt(page * 1.25, width).fraction,
        closeTo(0.25, 0.001),
      );
    });

    test('si riprende esattamente da dove si era smesso', () {
      final strip = ChapterStrip([shape(736, 16383), shape(736, 16383)]);
      const spot = ReadingSpot(1, 0.37);

      final offset = strip.offsetOf(spot, width);
      final back = strip.positionAt(offset, width);

      expect(back.page, 1);
      expect(back.fraction, closeTo(0.37, 0.001));
      // Mezza tavola di webtoon sono dieci schermate: è esattamente quello
      // che la ripresa per sola tavola buttava via.
      expect(offset, greaterThan(strip.pageHeight(0, width)));
    });

    test('riaprendo, lo schermo torna uguale a com\'era', () {
      final strip = ChapterStrip([shape(736, 16383), shape(736, 16383)]);
      const viewport = 800.0;
      const top = 12345.0;

      final saved = strip.spotOnScreen(top, width, viewport);
      final reopened = strip.screenOffsetOf(saved, width, viewport);

      // Prima la ripresa metteva in cima il punto che stava a un terzo dello
      // schermo, e ogni riapertura scivolava avanti di tanto.
      expect(reopened, closeTo(top, 0.5));
      expect(strip.spotOnScreen(reopened, width, viewport), saved);
    });

    test('un salto a una tavola la mette in cima', () {
      final strip = ChapterStrip([shape(400, 800), shape(400, 800)]);

      expect(
        strip.screenOffsetOf(const ReadingSpot(1, 0), width, 600),
        strip.offsetOf(const ReadingSpot(1, 0), width),
      );
    });

    test('una posizione fuori dal capitolo si riporta dentro', () {
      final strip = ChapterStrip([shape(400, 800)]);

      expect(strip.offsetOf(const ReadingSpot(9, 2), width), closeTo(800, 0.5));
      expect(strip.offsetOf(const ReadingSpot(-1, -1), width), 0);
    });

    test('due posizioni vicine non sono una notizia', () {
      const spot = ReadingSpot(3, 0.40);

      expect(spot.near(const ReadingSpot(3, 0.42)), isTrue);
      expect(spot.near(const ReadingSpot(3, 0.50)), isFalse);
      expect(spot.near(const ReadingSpot(4, 0.40)), isFalse);
    });
  });
}
