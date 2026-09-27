/// Le tessere che il telefono taglia da sé, per le tavole che l'archivio
/// non ha diviso.
///
/// L'archivio taglia in tessere le tavole alte dei capitoli nuovi, e quelle
/// dei capitoli vecchi dopo `cobalt-ext mangaarchive tiles`. Finché una
/// tavola non ne ha, il lettore la ritaglia a fasce con il decodificatore
/// nativo, a ogni passaggio: una tavola intera decodificata nel Kotlin e i
/// pixel di ogni fascia copiati in Dart. È il lavoro che faceva scattare lo
/// scorrimento.
///
/// Qui lo si fa una volta sola, come fa Mihon con «split tall images»: il
/// Kotlin decodifica la tavola quando non ha fasce da dare, ne scrive le
/// fasce come JPEG nella cache dell'app, e da lì in poi quelle fasce sono
/// file interi per il codec di Flutter, come le tessere dell'archivio. Si
/// lavora nell'ordine di lettura a partire dalla tavola aperta, quindi è
/// anche la decodifica anticipata della tavola seguente.
///
/// Le tessere hanno esattamente le righe delle fasce del lettore
/// ([pageBandHeight] della sorgente) e il nome dice la prima riga: una
/// fascia trova la sua senza chiedere niente al disco.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'drive.dart';
import 'library.dart';
import 'page_decoder.dart';
import 'reader_probe.dart';

class PhoneTiles {
  PhoneTiles({PageDecoder? decoder, this.limitBytes = 400 << 20})
      : decoder = decoder ?? PageDecoder.instance;

  static final PhoneTiles instance = PhoneTiles();

  final PageDecoder decoder;

  /// Quanto spazio possono prendere. Sono JPEG: una tavola di 16383 pixel ne
  /// fa due o tre megabyte, e un capitolo qualche decina.
  final int limitBytes;

  /// La cartella delle tessere di ogni tavola pronta, per indirizzo.
  final Map<String, String> _ready = {};

  /// Cresce a ogni piano nuovo: il lavoro di un capitolo lasciato si ferma
  /// alla tavola che sta tagliando.
  int _generation = 0;

  Directory? _root;
  bool _trimmed = false;

  /// La tessera con le righe da [top] della tavola [address], se c'è.
  String? peek(String address, int top) {
    final directory = _ready[address];
    return directory == null ? null : p.join(directory, '$top.jpg');
  }

  /// Una tessera che non si è aperta: la tavola torna al ritaglio nativo, e
  /// alla prossima lettura si taglia di nuovo.
  void forget(String address) => _ready.remove(address);

  /// Taglia le tavole [addresses] di un capitolo, cominciando da [from] e
  /// facendo il giro. Un piano nuovo sostituisce il precedente.
  Future<void> plan(
    List<String> addresses, {
    required int from,
    required int bandHeight,
    required int targetWidth,
  }) async {
    final generation = ++_generation;
    if (!decoder.canDecodeRegions || addresses.isEmpty) return;
    final root = _root ??=
        Directory(p.join((await getApplicationCacheDirectory()).path, 'tiles'));
    if (!_trimmed) {
      _trimmed = true;
      await _trim(root).catchError((Object _) {});
    }
    final start = from.clamp(0, addresses.length);
    final ordered = [...addresses.skip(start), ...addresses.take(start)];
    for (final address in ordered) {
      if (generation != _generation) return;
      if (_ready.containsKey(address)) continue;
      try {
        // Una tavola di Drive si taglia quando è scesa: la aspetta in fila
        // con il precarico, senza passargli davanti.
        final path = await localFileOf(address, urgent: false);
        if (generation != _generation) return;
        final stat = await File(path).stat();
        if (stat.type != FileSystemEntityType.file) continue;
        final directory = p.join(
          root.path,
          _name(path, stat.size, stat.modified, bandHeight, targetWidth),
        );
        if (await File(p.join(directory, 'done')).exists()) {
          _ready[address] = directory;
          continue;
        }
        final made = await decoder.tile(
          path,
          directory: directory,
          bandHeight: bandHeight,
          targetWidth: targetWidth,
        );
        if (made) {
          _ready[address] = directory;
          ReaderProbe.instance.notePhoneTiled();
        }
      } on Object {
        // Una tavola che non scende o non si apre resta al ritaglio nativo:
        // il piano va avanti con le altre.
        continue;
      }
    }
  }

  /// Ferma il piano in corso: uscendo dal lettore non serve più niente.
  void stop() => _generation++;

  /// Il nome della cartella dice tutto ciò da cui le tessere dipendono: il
  /// file, com'era quando le si è tagliate, e la geometria delle fasce.
  static String _name(
    String path,
    int size,
    DateTime modified,
    int bandHeight,
    int targetWidth,
  ) =>
      addressKey(
        '$path|$size|${modified.millisecondsSinceEpoch}|$bandHeight|$targetWidth',
      );

  /// Tiene la cartella sotto [limitBytes], buttando per prime le tavole
  /// tagliate da più tempo. Si fa una volta per avvio, non a ogni tavola.
  Future<void> _trim(Directory root) async {
    if (!await root.exists()) return;
    final entries = <(Directory, DateTime, int)>[];
    var total = 0;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      var size = 0;
      var modified = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final file in entity.list(followLinks: false)) {
        if (file is! File) continue;
        final stat = await file.stat();
        size += stat.size;
        if (stat.modified.isAfter(modified)) modified = stat.modified;
      }
      entries.add((entity, modified, size));
      total += size;
    }
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (directory, _, size) in entries) {
      if (total <= limitBytes) break;
      await directory.delete(recursive: true).catchError((Object _) => directory);
      total -= size;
    }
  }
}
