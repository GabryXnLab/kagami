/// Il giro dentro il motore acceso da `ArchiveWorker.kt`, ad app chiusa o
/// in secondo piano.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/drive.dart';
import '../data/library_location.dart';
import '../data/network.dart';
import 'device.dart';

/// Il lucchetto del giro: un file ritoccato ogni tanto, come quello della
/// sincronizzazione. I motori stanno nello stesso processo, e un lucchetto
/// del sistema li vedrebbe come la stessa persona.
class _RunLock {
  _RunLock(this.file);

  final File file;
  Timer? _beat;

  Future<void> acquire() async {
    await file.parent.create(recursive: true);
    await file.writeAsString('$pid');
    _beat = Timer.periodic(const Duration(seconds: 30), (_) {
      file.setLastModified(DateTime.now()).catchError((_) {});
    });
  }

  Future<void> release() async {
    _beat?.cancel();
    await file.delete().catchError((_) => file);
  }
}

/// Esegue la coda; con [check], prima controlla le serie in corso. Dice
/// sempre `done` al Kotlin, con come è finita: è ciò che il lavoro aspetta
/// per spegnere il motore e decidere se ripartire.
Future<void> runBackgroundArchive({required bool check}) async {
  const channel = MethodChannel('kagami/archive-worker');
  var stopped = false;
  channel.setMethodCallHandler((call) async {
    if (call.method == 'stop') stopped = true;
  });
  var end = RunEnd.done;
  // Il controllo non riuscito per la rete si ritenta fra poco, non domani.
  var checkFailed = false;
  DriveClient? client;
  _RunLock? lock;
  try {
    final directories = await AppDirectories.resolve();
    final files = ArchiveFiles(directories.support);
    await GoogleSignIn.instance.initialize();
    client = DriveClient(DriveAuth().writeToken, network: NetworkMonitor.instance);
    final environment = deviceEnvironment(files, client, directories.cache);
    if (check) {
      try {
        await Tracking(files.ongoing).check(
          files,
          (provider) => environment.httpFor(provider),
          cancelled: () => stopped,
        );
      } on ProviderOffline {
        end = RunEnd.retry;
        checkFailed = true;
      }
    }
    // Un altro motore sta già scaricando: i capitoli messi in coda dal
    // controllo li prende lui. Si riprova comunque fra poco, perché il
    // lucchetto può essere quello di un processo morto a metà, che scade da
    // solo: chiudere come «fatto» lasciava la coda ferma fino a un tocco.
    if (end == RunEnd.done && await files.running()) {
      end = RunEnd.retry;
    } else if (end == RunEnd.done) {
      lock = _RunLock(files.runLock);
      await lock.acquire();
      var lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
      end = await ArchiveRunner(
        files,
        environment,
        cancelled: () => stopped,
        onError: (error, stack) => Sentry.captureException(error, stackTrace: stack),
        onStatus: (status) {
          final now = DateTime.now();
          if (now.difference(lastProgress) < const Duration(seconds: 1)) return;
          lastProgress = now;
          unawaited(channel.invokeMethod<void>('progress', {
            'title': status.title,
            'text': status.message,
            'done': status.done,
            'total': status.total,
          }).catchError((_) {}));
        },
      ).run();
    }
  } finally {
    await lock?.release();
    client?.close();
    await channel.invokeMethod<void>('done', {'end': end.name, 'checkFailed': checkFailed});
  }
}
