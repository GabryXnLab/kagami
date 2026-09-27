/// Miniatura della copertina e tessere delle tavole alte.
///
/// Sul telefono le fa Android (`NativeImageTools` nell'app, `ArchiveImages.kt`): una
/// tavola di manhwa arriva a 16383 pixel, e decodificarla e ricodificarla
/// in Dart sarebbe lento e terrebbe in memoria Dart una bitmap da decine di
/// megabyte. Dove il Kotlin non c'è — build Linux, test — non si fa niente:
/// la miniatura manca e le tavole restano senza tessere, che per MALF è una
/// libreria valida (il lettore legge la tavola).
library;

import 'dart:io';
import 'dart:typed_data';

abstract interface class ImageTools {
  /// La miniatura WebP della copertina in [cover], al più 360×540.
  Future<Uint8List?> thumbnail(File cover);

  /// La tavola in [page] tagliata dall'alto in basso in tessere WebP alte
  /// [heights]; `null` se non si può.
  Future<List<Uint8List>?> tiles(File page, List<int> heights);
}

class NoImageTools implements ImageTools {
  const NoImageTools();

  @override
  Future<Uint8List?> thumbnail(File cover) async => null;

  @override
  Future<List<Uint8List>?> tiles(File page, List<int> heights) async => null;
}
