/// Da dove parte un giro di sincronizzazione: dall'app o all'ora scelta.
///
/// Il giro è lo stesso nei due casi ([runFolderSync]) e legge tutto dal
/// file delle impostazioni, perché il lavoro programmato
/// (`FolderSyncWorker.kt`) gira in un motore senza schermo che non ha né
/// l'app né il suo grafo delle dipendenze.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'drive.dart';
import 'folder_sync.dart';
import 'library_location.dart';
import 'network.dart';

/// Un giro con le impostazioni salvate. `null` se manca qualcosa — la
/// direzione, la cartella del telefono o quella di Drive — e quindi non c'è
/// niente da fare.
///
/// Chi carica chiede il token con cui si scrive; chi scarica soltanto si
/// accontenta di quello in sola lettura.
Future<SyncReport?> runFolderSync(
  SyncFiles files,
  DriveAuth auth, {
  bool scheduled = false,
  void Function(SyncProgress progress)? onProgress,
  bool Function()? cancelled,
}) async {
  final settings = await files.readSettings();
  if (!settings.ready) return null;
  final direction = settings.direction!;
  final client =
      DriveClient(direction.uploads ? auth.writeToken : auth.token, network: NetworkMonitor.instance);
  try {
    return await FolderSync(
      remote: DriveSyncRemote(client),
      root: settings.root!,
      folderId: settings.folderId!,
      direction: direction,
      deletions: settings.deletions,
      files: files,
      scheduled: scheduled,
    ).run(onProgress: onProgress, cancelled: cancelled);
  } finally {
    client.close();
  }
}

/// Il giro programmato, dentro il motore acceso da `FolderSyncWorker.kt`.
/// Dice sempre `done`, anche quando non riesce: è ciò che il lavoro aspetta
/// per spegnere il motore.
Future<void> runScheduledFolderSync() async {
  const channel = MethodChannel('kagami/sync');
  var stopped = false;
  channel.setMethodCallHandler((call) async {
    if (call.method == 'stop') stopped = true;
  });
  try {
    final directories = await AppDirectories.resolve();
    await GoogleSignIn.instance.initialize();
    await runFolderSync(
      SyncFiles(directories.support),
      DriveAuth(),
      scheduled: true,
      cancelled: () => stopped,
    );
  } on SyncBusy {
    // L'app aperta sta già sincronizzando: il giro è quello.
  } finally {
    await channel.invokeMethod<void>('done');
  }
}

/// Programma o toglie il giro all'ora scelta.
class FolderSyncScheduler {
  const FolderSyncScheduler();

  static const MethodChannel _channel = MethodChannel('kagami/sync-schedule');

  bool get _native => !kIsWeb && Platform.isAndroid;

  Future<void> apply(SyncSettings settings) async {
    if (!_native) return;
    if (settings.scheduled) {
      await _channel.invokeMethod<void>('schedule', {
        'minutes': settings.scheduleMinutes,
        'wifiOnly': settings.wifiOnly,
      });
    } else {
      await _channel.invokeMethod<void>('cancel');
    }
  }
}
