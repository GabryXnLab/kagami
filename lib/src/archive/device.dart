/// Il motore dell'archivio sul telefono: Drive col client dell'account, le
/// cartelle del telefono, le immagini dal Kotlin, il lavoro in primo piano.
///
/// Il resto del motore sta nel pacchetto `kagami_archive`, che non conosce
/// Flutter perché lo usa anche il server.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/image_tools.dart';
import 'package:kagami_archive/images.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';

import '../l10n.dart';

class NativeImageTools implements ImageTools {
  const NativeImageTools();

  static const MethodChannel _channel = MethodChannel('kagami/archive-images');

  /// Il Kotlin c'è solo su Android; altrove si rinuncia in silenzio.
  static ImageTools get platform =>
      Platform.isAndroid ? const NativeImageTools() : const NoImageTools();

  @override
  Future<Uint8List?> thumbnail(File cover) async {
    try {
      return await _channel.invokeMethod<Uint8List>('thumbnail', {
        'path': cover.path,
        'width': thumbnailWidth,
        'height': thumbnailHeight,
      });
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<List<Uint8List>?> tiles(File page, List<int> heights) async {
    try {
      final parts = await _channel.invokeListMethod<Uint8List>('tiles', {
        'path': page.path,
        'heights': heights,
        'quality': tileQuality,
      });
      return parts == null || parts.length != heights.length ? null : parts;
    } on PlatformException {
      return null;
    }
  }
}

/// I posti veri: Drive col client dell'account, il telefono con le sue
/// cartelle, le immagini dal Kotlin.
ArchiveEnvironment deviceEnvironment(ArchiveFiles files, DriveClient client, String cache) =>
    ArchiveEnvironment(
      scratch: Directory('$cache/archive'),
      images: NativeImageTools.platform,
      storeFor: (target) {
        LocalStore? phone() => target.root == null
            ? null
            : LocalStore(target.root!, hideFromGallery: !target.private);
        return switch (target.destination) {
          ArchiveDestination.phone => phone() ?? (throw ProviderError(currentL10n().dataArchivePhoneFolderMissing)),
          _ => DriveStore(
              remote: DriveSyncRemote(client),
              folderId: target.folderId ?? (throw ProviderError(currentL10n().dataArchiveDriveFolderMissing)),
              staging: files.staging(target.folderId!).path,
              mirror: target.destination == ArchiveDestination.driveAndPhone ? phone() : null,
            ),
        };
      },
    );

/// Avvia, ferma e programma il lavoro in primo piano.
class ArchiveScheduler {
  const ArchiveScheduler();

  static const MethodChannel _channel = MethodChannel('kagami/archive');

  bool get _native => !kIsWeb && Platform.isAndroid;

  /// Fa partire il giro della coda, se non è già in corso.
  Future<void> start() async {
    if (_native) await _channel.invokeMethod<void>('start');
  }

  /// Ferma il giro in corso: il lavoro resta in coda, se non lo si toglie.
  Future<void> stop() async {
    if (_native) await _channel.invokeMethod<void>('stop');
  }

  /// Con [keep] non sposta un controllo già in attesa: serve all'avvio, a
  /// rimettere in piedi la catena dei giorni se un giro è morto prima di
  /// accodare il seguente.
  Future<void> apply(CheckSettings settings, {bool keep = false}) async {
    if (!_native) return;
    final minutes = settings.minutes;
    if (minutes == null) {
      if (!keep) await _channel.invokeMethod<void>('unschedule');
    } else {
      await _channel.invokeMethod<void>('schedule', {
        'minutes': minutes,
        'wifiOnly': settings.wifiOnly,
        'keep': keep,
      });
    }
  }
}
