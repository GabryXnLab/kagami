/// Formato e dimensioni delle immagini archiviate, letti dagli header.
///
/// Il lettore impagina un capitolo dalle sole dimensioni di `pages.json`,
/// quindi vanno misurate su ciò che è arrivato davvero, senza decodificare
/// un pixel. Porting di `mangaarchive/images.py`.
library;

import 'dart:typed_data';

import 'model.dart';

const int thumbnailWidth = 360;
const int thumbnailHeight = 540;

// Le tessere delle tavole alte: gli stessi numeri del server, perché la
// firma del taglio (`tileFormat`) deve essere la stessa da tutt'e due i lati.
const int tileHeight = 1024;
const int tileAbove = 1536;
const int tileQuality = 92;
const String tileFormat = 'webp-q$tileQuality-$tileHeight';

bool _starts(Uint8List body, List<int> prefix) {
  if (body.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (body[i] != prefix[i]) return false;
  }
  return true;
}

bool _at(Uint8List body, int offset, String text) {
  if (body.length < offset + text.length) return false;
  for (var i = 0; i < text.length; i++) {
    if (body[offset + i] != text.codeUnitAt(i)) return false;
  }
  return true;
}

const List<int> _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// L'estensione del file dal contenuto; un WebP troncato non passa, perché
/// un download interrotto a metà non deve diventare una tavola archiviata.
String imageExtension(Uint8List body) {
  if (_at(body, 0, 'RIFF') && _at(body, 8, 'WEBP')) {
    final declared = ByteData.sublistView(body, 4, 8).getUint32(0, Endian.little);
    if (declared + 8 != body.length) {
      throw const ProviderError('Immagine WebP incompleta.');
    }
    return '.webp';
  }
  if (_starts(body, _png)) return '.png';
  if (_starts(body, const [0xFF, 0xD8, 0xFF])) return '.jpg';
  if (_at(body, 0, 'GIF87a') || _at(body, 0, 'GIF89a')) return '.gif';
  if (body.length > 12 && _at(body, 4, 'ftyp')) {
    final brand = String.fromCharCodes(body.sublist(8, body.length < 24 ? body.length : 24));
    if (brand.contains('avif')) return '.avif';
  }
  throw const ProviderError(
    'Il provider ha restituito dati che non sono un’immagine supportata.',
  );
}

int _le(Uint8List body, int start, int length) {
  var value = 0;
  for (var i = length - 1; i >= 0; i--) {
    value = (value << 8) | body[start + i];
  }
  return value;
}

int _be(Uint8List body, int start, int length) {
  var value = 0;
  for (var i = 0; i < length; i++) {
    value = (value << 8) | body[start + i];
  }
  return value;
}

(int, int)? _webp(Uint8List body) {
  if (_at(body, 12, 'VP8 ')) {
    return (_le(body, 26, 2) & 0x3FFF, _le(body, 28, 2) & 0x3FFF);
  }
  if (_at(body, 12, 'VP8L')) {
    final bits = _le(body, 21, 4);
    return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
  }
  if (_at(body, 12, 'VP8X')) {
    return (_le(body, 24, 3) + 1, _le(body, 27, 3) + 1);
  }
  return null;
}

(int, int)? _jpeg(Uint8List body) {
  var offset = 2;
  while (offset + 9 < body.length) {
    if (body[offset] != 0xFF) return null;
    final marker = body[offset + 1];
    final length = _be(body, offset + 2, 2);
    if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
      return (_be(body, offset + 7, 2), _be(body, offset + 5, 2));
    }
    if (length < 2) return null;
    offset += 2 + length;
  }
  return null;
}

(int, int)? _avif(Uint8List body) {
  for (var i = 0; i + 16 <= body.length; i++) {
    if (_at(body, i, 'ispe')) return (_be(body, i + 8, 4), _be(body, i + 12, 4));
  }
  return null;
}

/// Larghezza e altezza dagli header, o `null` se non si ricavano.
(int, int)? imageSize(Uint8List body) {
  (int, int)? size;
  try {
    if (_at(body, 0, 'RIFF')) {
      size = _webp(body);
    } else if (_starts(body, _png)) {
      size = (_be(body, 16, 4), _be(body, 20, 4));
    } else if (_starts(body, const [0xFF, 0xD8, 0xFF])) {
      size = _jpeg(body);
    } else if (_at(body, 0, 'GIF87a') || _at(body, 0, 'GIF89a')) {
      size = (_le(body, 6, 2), _le(body, 8, 2));
    } else {
      size = _avif(body);
    }
  } on RangeError {
    return null;
  }
  if (size == null || size.$1 <= 0 || size.$2 <= 0) return null;
  return size;
}

/// Le altezze delle tessere di una tavola alta [height] pixel, o nessuna.
///
/// Il taglio è in parti uguali e non a blocchi fissi: a blocchi, una tavola
/// di 2049 pixel lascerebbe una tessera di una riga sola, cioè un file e una
/// richiesta a Drive per niente.
List<int> tileHeights(int height) {
  if (height <= tileAbove) return const [];
  final count = (height + tileHeight - 1) ~/ tileHeight;
  final base = height ~/ count;
  final extra = height % count;
  return [for (var i = 0; i < count; i++) i < extra ? base + 1 : base];
}
