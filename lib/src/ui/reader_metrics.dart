/// La geometria della striscia: in quante fasce si taglia una tavola, quanto
/// spazio occupa ognuna e dove comincia.
///
/// Sta fuori dal lettore perché è la parte che decide se il capitolo si legge
/// senza giunture, ed è l'unica del lettore che si possa provare senza uno
/// schermo.
///
/// Una tavola di webtoon è alta fino a 16383 pixel: decodificarla intera
/// vuol dire una bitmap da cinquanta megabyte e una texture più grande di
/// quanto la GPU accetti. La striscia quindi non è fatta di tavole ma di
/// **fasce**: pezzi alti al più [pageBandHeight] pixel della sorgente, che il
/// lettore chiede e butta via uno alla volta mano a mano che passano sullo
/// schermo. Una tavola normale è una fascia sola e non cambia niente.
///
/// Il rapporto di una fascia può arrivare da tre posti, in quest'ordine:
/// quello misurato sull'immagine decodificata, quello dichiarato da
/// `pages.json`, e una proporzione plausibile per il tempo di un fotogramma.
/// Contano tutti e tre perché l'indice può essere vecchio, incompleto o
/// sbagliato, e uno spazio riservato male è esattamente ciò che apre un buco
/// fra due tavole.
library;

/// Il rapporto di una tavola di cui non si sa niente: una pagina di manga
/// tipica.
const double unknownPageRatio = 1 / 1.45;

/// Quanto è alta al massimo una fascia, in pixel della sorgente.
///
/// Un terzo di schermata di webtoon, come le tessere in cui i lettori
/// professionali tagliano le tavole. Ogni fascia è una texture che la GPU
/// carica in un colpo solo, e sul telefono lo scatto cadeva proprio quando
/// ne entrava una nuova: con 1536 px erano quattro-sei megabyte per volta,
/// con un terzo il lavoro si divide in tre momenti più leggeri. Ritagliarne
/// di più costa poco, perché il decodificatore nativo ritaglia da una
/// tavola già decodificata e non dal file.
const int pageBandHeight = 512;

/// Dove sta, dall'alto dello schermo, la riga che decide a che punto si è.
const double readingLine = 0.3;

/// Fin dove una tavola senza tessere resta intera anche potendo tagliarla.
///
/// Una tavola di manga o un pezzo di webtoon di un paio di schermate si
/// decodifica tutta, con il codec di Flutter e fuori dal thread
/// dell'interfaccia, come una foto: tagliarla vorrebbe dire passare dal
/// decodificatore nativo per niente. Il taglio serve solo alle tavole
/// stitchate che l'archivio non ha ancora diviso in tessere.
const int wholePageLimit = 2048;

/// L'altezza con cui non si taglia niente: una tavola, una fascia. È la
/// misura giusta per la lettura a pagine, dove la tavola sta tutta nello
/// schermo, e l'unica possibile dove il decodificatore a ritagli non c'è.
const int wholePageBand = 1 << 30;

/// La forma di una tavola come la dichiara `pages.json`: `null` dove l'indice
/// non la sa. [tiles] sono le altezze delle tessere in cui l'archivio l'ha
/// già tagliata, vuota se non l'ha fatto.
typedef PageShape = ({int? width, int? height, List<int> tiles});

/// Una fascia: un pezzo di tavola, o una tavola intera quando ci sta.
class StripBand {
  const StripBand({
    required this.page,
    required this.index,
    required this.count,
    required this.top,
    required this.height,
    required this.ratio,
    this.tile,
  });

  /// La tavola a cui appartiene.
  final int page;

  /// Quale fascia della tavola è, e quante ne ha in tutto.
  final int index;
  final int count;

  /// Il primo pixel della sorgente e quanti ne prende. Valgono zero quando
  /// l'indice non dichiara le dimensioni: allora la tavola è una fascia sola
  /// e la si chiede intera.
  final int top;
  final int height;

  /// Larghezza diviso altezza della fascia.
  final double ratio;

  /// Quale tessera dell'archivio è, se la fascia ne è una: allora la si
  /// legge da quel file, che contiene esattamente queste righe.
  final int? tile;

  /// Se è la tavola intera: allora la si chiede intera, al codec di Flutter.
  bool get whole => count == 1 && tile == null;
}

/// Un capitolo come striscia di fasce.
class ChapterStrip {
  ChapterStrip(
    List<PageShape> pages, {
    int bandHeight = pageBandHeight,
    int wholeUpTo = wholePageLimit,
    bool useTiles = true,
  }) : pageCount = pages.length {
    for (var page = 0; page < pages.length; page++) {
      _firstBand.add(bands.length);
      final shape = pages[page];
      final width = shape.width;
      final height = shape.height;
      if (width == null || height == null || width <= 0 || height <= 0) {
        // Senza dimensioni non si può tagliare niente: la tavola resta intera
        // e il rapporto vero arriverà dalla decodifica.
        bands.add(
          StripBand(
            page: page,
            index: 0,
            count: 1,
            top: 0,
            height: 0,
            ratio: unknownPageRatio,
          ),
        );
        continue;
      }
      if (useTiles && shape.tiles.isNotEmpty) {
        // Le tessere le ha già tagliate l'archivio: sono le fasce, e i loro
        // bordi sono quelli dei file, non quelli che sceglierebbe il lettore.
        var top = 0;
        for (var index = 0; index < shape.tiles.length; index++) {
          final tall = shape.tiles[index];
          bands.add(
            StripBand(
              page: page,
              index: index,
              count: shape.tiles.length,
              top: top,
              height: tall,
              ratio: width / tall,
              tile: index,
            ),
          );
          top += tall;
        }
        continue;
      }
      final cut = height <= wholeUpTo ? height : bandHeight;
      final count = (height + cut - 1) ~/ cut;
      for (var index = 0; index < count; index++) {
        final top = index * cut;
        final band = height - top < cut ? height - top : cut;
        bands.add(
          StripBand(
            page: page,
            index: index,
            count: count,
            top: top,
            height: band,
            ratio: width / band,
          ),
        );
      }
    }
    _firstBand.add(bands.length);
  }

  final int pageCount;
  final List<StripBand> bands = [];

  /// La prima fascia di ogni tavola, più la fine dell'ultima: dice anche
  /// quante fasce ha una tavola senza ripercorrerle.
  final List<int> _firstBand = [];

  final Map<int, double> _measured = {};

  List<double>? _offsets;
  double _offsetsWidth = -1;

  int get length => bands.length;


  double ratioOf(int band) {
    final measured = _measured[band];
    if (measured != null && measured > 0) return measured;
    final declared = bands[band].ratio;
    return declared <= 0 ? unknownPageRatio : declared;
  }

  double heightOf(int band, double width) => width / ratioOf(band);

  /// Il bordo superiore di ogni fascia, più la fine dell'ultima: il bordo
  /// inferiore dell'una è il bordo superiore dell'altra, che è tutto ciò che
  /// "senza spazi" vuol dire.
  ///
  /// Si ricalcola solo quando cambia qualcosa: lo scorrimento lo interroga a
  /// ogni fotogramma e rifarlo ogni volta è una lista nuova per fotogramma.
  List<double> offsets(double width) {
    final cached = _offsets;
    if (cached != null && _offsetsWidth == width) return cached;
    final offsets = List<double>.filled(bands.length + 1, 0);
    for (var band = 0; band < bands.length; band++) {
      offsets[band + 1] = offsets[band] + heightOf(band, width);
    }
    _offsets = offsets;
    _offsetsWidth = width;
    return offsets;
  }


  /// Quanto spazio prende una tavola intera: la somma delle sue fasce.
  double pageHeight(int page, double width) {
    final offsets = this.offsets(width);
    final row = page.clamp(0, pageCount - 1);
    return offsets[_firstBand[row + 1]] - offsets[_firstBand[row]];
  }


  /// Se registrare [ratio] per la fascia [band] sposterebbe qualcosa di
  /// visibile. Una correzione da un decimo di pixel costa una ricostruzione
  /// della lista e non si vede: è rumore, e in un capitolo di duecento fasce
  /// è rumore duecento volte.
  bool worthApplying(int band, double ratio, double width) {
    if (ratio <= 0 || band < 0 || band >= bands.length) return false;
    if (_measured[band] == ratio) return false;
    return (width / ratio - heightOf(band, width)).abs() >= 0.5;
  }

  /// Registra i rapporti veri e dice di quanto va spostato lo scorrimento
  /// perché la fascia che si sta guardando resti ferma: quelle già passate
  /// cambiano altezza sotto la lista, e senza compenso il capitolo scivola
  /// via da solo.
  double apply(
    Map<int, double> measured, {
    required double width,
    required double top,
  }) {
    final offsets = this.offsets(width);
    var shift = 0.0;
    for (final entry in measured.entries) {
      if (entry.value <= 0 || entry.key < 0 || entry.key >= bands.length) {
        continue;
      }
      final before = heightOf(entry.key, width);
      _measured[entry.key] = entry.value;
      if (offsets[entry.key] < top) {
        shift += heightOf(entry.key, width) - before;
      }
    }
    _offsets = null;
    _offsetsWidth = -1;
    return shift;
  }

  /// A quale fascia appartiene un punto della striscia. È una ricerca
  /// binaria perché la si fa a ogni fotogramma su capitoli di centinaia di
  /// fasce.
  int bandAt(double offset, List<double> offsets) {
    var low = 0;
    var high = bands.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (offsets[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low < 0 ? 0 : low;
  }

  /// Dove si è arrivati: la tavola e quanto se n'è già passato.
  ///
  /// La frazione dentro la tavola è il dato che mancava. Su un webtoon una
  /// tavola è dieci schermate: riprendere dalla tavola voleva dire riprendere
  /// dieci schermate prima.
  ReadingSpot positionAt(double offset, double width) {
    final offsets = this.offsets(width);
    final band = bandAt(offset, offsets);
    final page = bands[band].page;
    final first = _firstBand[page];
    final start = offsets[first];
    final pageHeight = offsets[_firstBand[page + 1]] - start;
    if (pageHeight <= 0) return ReadingSpot(page, 0);
    return ReadingSpot(page, ((offset - start) / pageHeight).clamp(0.0, 1.0));
  }

  /// Dove si è arrivati guardando lo schermo che comincia a [pixels]: il
  /// punto che conta è la [readingLine], non il bordo in alto, perché la
  /// tavola che si sta leggendo è quella che occupa lo schermo, non quella
  /// che ne sta uscendo.
  ReadingSpot spotOnScreen(double pixels, double width, double viewport) =>
      positionAt(pixels + viewport * readingLine, width);

  /// Il contrario: da dove far cominciare lo schermo perché la posizione
  /// ricordata torni sulla linea di lettura. Senza sottrarla ogni ripresa
  /// portava avanti di un terzo di schermata.
  ///
  /// Una posizione all'inizio esatto di una tavola — un salto, un segnalibro
  /// — mette invece la tavola in cima: si vuole vederla cominciare, non la
  /// coda di quella prima.
  double screenOffsetOf(ReadingSpot spot, double width, double viewport) {
    final offset = offsetOf(spot, width);
    if (spot.fraction <= 0) return offset;
    final top = offset - viewport * readingLine;
    return top < 0 ? 0 : top;
  }

  /// Il contrario: da dove ripartire per ritrovarsi dove si era smesso.
  double offsetOf(ReadingSpot spot, double width) {
    final page = spot.page.clamp(0, pageCount - 1);
    final offsets = this.offsets(width);
    final start = offsets[_firstBand[page]];
    final pageHeight = offsets[_firstBand[page + 1]] - start;
    return start + pageHeight * spot.fraction.clamp(0.0, 1.0);
  }
}

/// Dove si è arrivati dentro un capitolo: la tavola e quanto se n'è già
/// scorso.
class ReadingSpot {
  const ReadingSpot(this.page, this.fraction);

  final int page;
  final double fraction;

  /// Due posizioni si equivalgono finché non cambia la tavola o non si è
  /// scorso un pezzo apprezzabile di quella corrente: è il filtro che tiene
  /// le scritture lontane dal ritmo dello scorrimento.
  bool near(ReadingSpot other) =>
      page == other.page && (fraction - other.fraction).abs() < 0.05;

  @override
  bool operator ==(Object other) =>
      other is ReadingSpot && other.page == page && other.fraction == fraction;

  @override
  int get hashCode => Object.hash(page, fraction);

  @override
  String toString() => 'ReadingSpot($page, $fraction)';
}
