/// Il giro dentro il motore acceso da `ArchiveWorker.kt`, ad app chiusa o
/// in secondo piano.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart' show installUserProviders;
import 'package:kagami_archive/remote.dart' show ServerLink;
import 'package:kagami_archive/runner.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/drive.dart';
import '../data/library_location.dart';
import '../data/network.dart';
import '../data/site_replacements.dart';
import 'device.dart';
import 'phone_check.dart';

/// Il lucchetto del giro: un file ritoccato ogni tanto, come quello della
/// sincronizzazione. I motori stanno nello stesso processo, e un lucchetto
/// del sistema li vedrebbe come la stessa persona.
class RunLock {
  RunLock(this.file);

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

/// Installa nel motore di questo isolate i siti degli utenti in `providers/`
/// della libreria che usa il giro (Drive prima della cartella del telefono, come
/// [checkFromPhone]): l'isolate di sfondo non ha l'app che li carica. Una lettura
/// fallita non ferma il giro, che va avanti coi soli siti inclusi.
Future<void> installUserSitesForRun(ArchiveFiles files, ArchiveEnvironment environment) async {
  try {
    final scope = await files.scope();
    final drive = scope.driveFolder;
    final local = scope.localRoot;
    final target = drive != null
        ? ArchiveTarget(destination: ArchiveDestination.drive, folderId: drive)
        : local != null
            ? ArchiveTarget(destination: ArchiveDestination.phone, root: local)
            : null;
    if (target == null) return;
    final confirmed = await SiteReplacements(File('${files.directory.path}/site-replacements.json')).read();
    installUserProviders(SiteReplacements.usable(await loadSites(environment.storeFor(target)), confirmed));
  } on Object {
    // Solo gli inclusi: meglio un giro scarso che nessun giro.
  }
}

/// Esegue la coda; con [check], prima controlla le serie in corso
/// ([checkFromPhone]). Dice
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
  // Le serie che solo una persona può sbloccare: le annuncia il Kotlin, a
  // giro finito.
  var gated = const <GatedSeries>[];
  DriveClient? client;
  RunLock? lock;
  try {
    final directories = await AppDirectories.resolve();
    final files = ArchiveFiles(directories.support);
    await GoogleSignIn.instance.initialize();
    client = DriveClient(DriveAuth().writeToken, network: NetworkMonitor.instance);
    final environment = deviceEnvironment(files, client, directories.cache);
    await installUserSitesForRun(files, environment);
    if (check) {
      try {
        const browser = NativePageBrowser();
        final scope = await files.scope();
        final server = scope.server;
        gated = [
          if (server != null)
            ...await passServerGated(
              ServerLink(Uri.parse(server), id: scope.serverId, owner: scope.serverOwner),
              browser,
            ),
          // Col server, al telefono restano i siti degli utenti che lui non sa usare.
          if (server == null || scope.userSitesOnPhone)
            ...(await checkFromPhone(files, environment, browser: browser, cancelled: () => stopped)).gated,
        ];
      } on ProviderOffline {
        end = RunEnd.retry;
        checkFailed = true;
      } on DriveOffline {
        end = RunEnd.retry;
        checkFailed = true;
      } on DriveException {
        // Permesso o cartella di Drive che non vanno: riprovare fra mezz'ora
        // non li aggiusta, e la coda gira lo stesso.
      }
    }
    // Un altro motore sta già scaricando: i capitoli messi in coda dal
    // controllo li prende lui. Si riprova comunque fra poco, perché il
    // lucchetto può essere quello di un processo morto a metà, che scade da
    // solo: chiudere come «fatto» lasciava la coda ferma fino a un tocco.
    if (end == RunEnd.done && await files.running()) {
      end = RunEnd.retry;
    } else if (end == RunEnd.done) {
      lock = RunLock(files.runLock);
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
    final notice = gated.isEmpty ? null : gatedNotice(gated);
    await channel.invokeMethod<void>('done', {
      'end': end.name,
      'checkFailed': checkFailed,
      'verifyTitle': ?notice?.title,
      'verifyText': ?notice?.text,
    });
  }
}
