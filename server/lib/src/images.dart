/// Miniature e tessere sul server, con libvips.
///
/// È ciò che sul telefono fa `ArchiveImages.kt`, con gli stessi numeri
/// (`images.dart` del pacchetto): miniatura WebP q80 dentro 360×540, mai
/// ingrandita; tessere WebP q[tileQuality] alte quanto dice [tileHeights].
/// libvips perché decodifica a strisce: una tavola da 16383 pixel non passa
/// mai intera dalla memoria, ed è in ogni distribuzione e nell'immagine
/// Docker. Senza `vips` si rinuncia come sul Linux dell'app: la libreria
/// resta valida, il lettore legge la tavola.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/images.dart';
import 'package:path/path.dart' as p;

class VipsImageTools implements ImageTools {
  VipsImageTools(this.scratch, {this.vips = 'vips', this.header = 'vipsheader'});

  final Directory scratch;
  final String vips;
  final String header;

  /// Se `vips` c'è: altrimenti il server usa [NoImageTools].
  static Future<bool> available({String vips = 'vips'}) async {
    try {
      return (await Process.run(vips, ['--version'])).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  Future<T?> _inTemp<T>(Future<T?> Function(Directory dir) body) async {
    await scratch.create(recursive: true);
    final dir = await scratch.createTemp('vips-');
    try {
      return await body(dir);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<bool> _run(String command, List<String> args) async =>
      (await Process.run(command, args)).exitCode == 0;

  @override
  Future<Uint8List?> thumbnail(File cover) => _inTemp((dir) async {
        final out = p.join(dir.path, 'thumb.webp');
        final ok = await _run(vips, [
          'thumbnail',
          cover.path,
          '$out[Q=80]',
          '$thumbnailWidth',
          '--height',
          '$thumbnailHeight',
          // Come il Kotlin: una copertina piccola resta com'è.
          '--size',
          'down',
        ]);
        return ok ? await File(out).readAsBytes() : null;
      });

  @override
  Future<List<Uint8List>?> tiles(File page, List<int> heights) => _inTemp((dir) async {
        final width = await Process.run(header, ['-f', 'width', page.path]);
        final pixels = int.tryParse('${width.stdout}'.trim());
        if (width.exitCode != 0 || pixels == null) return null;
        // Decodificata una volta nel formato di vips, che si legge a
        // ritagli senza ridecodificare: altrimenti ogni tessera rileggerebbe
        // il WebP dall'inizio, e l'ultima costerebbe quanto la tavola.
        final source = p.join(dir.path, 'page.v');
        if (!await _run(vips, ['copy', page.path, source])) return null;
        final parts = <Uint8List>[];
        var top = 0;
        for (final (index, height) in heights.indexed) {
          final out = p.join(dir.path, 'tile-$index.webp');
          if (!await _run(vips, ['crop', source, '$out[Q=$tileQuality]', '0', '$top', '$pixels', '$height'])) {
            return null;
          }
          parts.add(await File(out).readAsBytes());
          top += height;
        }
        return parts;
      });
}
