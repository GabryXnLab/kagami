/// Lanciare la riparazione delle serie archiviate (`docs/malf.md`, «Cambi
/// d'identità e riparazione») e proporla quando un sito rotto torna sano.
///
/// Chi ripara lo decide chi lavora ([archiveEngineProvider]): il server con
/// `POST /v2/repair`, il telefono con `repairLibrary`, mai metà e metà.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/http.dart' show ProviderOffline;
import 'package:kagami_archive/model.dart' show ProviderError;
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/repair.dart';
import 'package:kagami_archive/tracking.dart';

import '../data/cloud.dart';
import '../data/drive.dart';
import '../data/network.dart';
import '../l10n.dart';
import '../providers.dart';
import 'background.dart';
import 'device.dart';
import 'phone_check.dart';

/// Come si è messa la richiesta di riparare.
enum RepairStart {
  /// Il server l'ha accettata: gli esiti arrivano nella sua cronologia.
  server,

  /// Il telefono ha finito.
  phone,

  /// Ce n'è già una in corso.
  busy,

  /// Non c'è dove (nessuna libreria, o un server che non ripara).
  unavailable,

  /// Non è riuscita; il motivo è in [RepairView.error].
  failed,
}

/// Cosa riparare: tutta la libreria, un sito o alcune serie.
typedef RepairScope = ({String? site, Set<String>? keys});

/// Ripara dal server; lancia [RepairUnsupported] se non sa farlo.
typedef ServerRepairRun = Future<void> Function({String? site, Set<String>? keys});

/// Ripara dal telefono, con l'avanzamento. Gli esiti sono già nella cronologia.
typedef PhoneRepairRun = Future<int> Function({
  String? site,
  Set<String>? keys,
  void Function(int done, int total, String title)? progress,
});

class RepairUnsupported implements Exception {
  const RepairUnsupported();
}

/// Il giro del telefono sta scaricando.
class RepairBusy implements Exception {
  const RepairBusy();
}

class RepairView {
  const RepairView({this.running = false, this.done = 0, this.total = 0, this.title = '', this.error});

  final bool running;
  final int done;
  final int total;
  final String title;
  final String? error;
}

/// La libreria che il telefono ripara: quella di Drive se ce n'è la cartella,
/// anche se ne tiene una copia sincronizzata (rinominerebbe la copia), altrimenti
/// la cartella scelta. `null` se non ne ha nessuna.
ArchiveTarget? repairTargetOf(Ref ref) {
  final folder = ref.read(driveFolderProvider).value;
  final signedIn = ref.read(cloudAccountProvider.select((status) => status.signedIn));
  if (cloudAvailable && signedIn && folder != null) {
    return ArchiveTarget(destination: ArchiveDestination.drive, folderId: folder.id);
  }
  final root = ref.read(libraryRootProvider);
  if (root == null) return null;
  return ArchiveTarget(
    destination: ArchiveDestination.phone,
    root: root,
    private: root == ref.read(appDirectoriesProvider).privateLibrary,
  );
}

final serverRepairRunProvider = Provider<ServerRepairRun>((ref) {
  return ({site, keys}) async {
    final link = ref.read(serverLinkProvider).value;
    if (link == null) throw const RepairUnsupported();
    final client = serverClient(ref, link);
    try {
      if (!(await client.info()).repair) throw const RepairUnsupported();
      await client.repair(site: site, keys: keys);
    } finally {
      client.close();
    }
  };
});

final phoneRepairRunProvider = Provider<PhoneRepairRun>((ref) {
  return ({site, keys, progress}) async {
    final target = repairTargetOf(ref);
    if (target == null) throw const RepairUnsupported();
    final files = ref.read(archiveFilesProvider);
    // Come sul server, mai insieme al giro: la riparazione rinomina cartelle
    // e riscrive manifest che un download in corso sta scrivendo.
    if (await files.running()) throw const RepairBusy();
    final auth = ref.read(driveAuthProvider);
    final drive = target.destination == ArchiveDestination.drive;
    if (drive) await auth.authorize(write: true);
    final client = DriveClient(auth.writeToken, network: NetworkMonitor.instance);
    final lock = RunLock(files.runLock);
    await lock.acquire();
    try {
      final environment = deviceEnvironment(files, client, ref.read(appDirectoriesProvider).cache);
      final outcomes = await repairLibrary(
        store: environment.storeFor(target),
        httpFor: (provider) => environment.httpFor(provider),
        scratch: environment.scratch,
        images: environment.images,
        browser: const NativePageBrowser(),
        health: files.health,
        tracking: Tracking(files.ongoing),
        files: files,
        target: target,
        only: keys,
        site: site,
        progress: progress,
        onOutcome: (outcome) => files.remember(outcome.toArchiveOutcome()),
      );
      if (outcomes.any((outcome) => outcome.incomplete.isNotEmpty)) await const ArchiveScheduler().start();
      return outcomes.length;
    } finally {
      client.close();
      await lock.release();
    }
  };
});

/// Se si può riparare adesso: col server, solo se dice `repair`; col telefono,
/// se ha una libreria.
final repairAvailableProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (ref.watch(archiveEngineProvider) == ArchiveEngine.phone) {
    ref.watch(driveFolderProvider);
    ref.watch(libraryRootProvider);
    return repairTargetOf(ref) != null;
  }
  final link = ref.watch(serverLinkProvider).value;
  if (link == null) return false;
  final client = serverClient(ref, link);
  try {
    return (await client.info()).repair;
  } on ServerException {
    return false;
  } on IOException {
    return false;
  } finally {
    client.close();
  }
});

class RepairController extends Notifier<RepairView> {
  @override
  RepairView build() => const RepairView();

  /// Lancia la riparazione di [site], di [keys] o, senza niente, di tutta la
  /// libreria, da chi lavora. Dopo, la libreria si rilegge.
  Future<RepairStart> start({String? site, Set<String>? keys}) async {
    if (state.running) return RepairStart.busy;
    final l10n = currentL10n();
    state = const RepairView(running: true);
    try {
      if (ref.read(archiveEngineProvider) == ArchiveEngine.server) {
        await ref.read(serverRepairRunProvider)(site: site, keys: keys);
        state = const RepairView();
        return RepairStart.server;
      }
      await ref.read(phoneRepairRunProvider)(
        site: site,
        keys: keys,
        progress: (done, total, title) {
          if (ref.mounted) state = RepairView(running: true, done: done, total: total, title: title);
        },
      );
      ref.read(driveRepositoryProvider)?.refresh();
      ref.invalidate(libraryCatalogProvider);
      state = const RepairView();
      return RepairStart.phone;
    } on RepairBusy {
      state = const RepairView();
      return RepairStart.busy;
    } on RepairUnsupported {
      final server = ref.read(archiveEngineProvider) == ArchiveEngine.server;
      state = RepairView(error: server ? l10n.archiveRepairNoServer : l10n.archiveRepairNoLibrary);
      return RepairStart.unavailable;
    } on ProviderOffline {
      state = RepairView(error: l10n.archiveErrOffline);
      return RepairStart.failed;
    } on DriveOffline {
      state = RepairView(error: l10n.archiveErrOffline);
      return RepairStart.failed;
    } on DriveAuthRequired {
      state = const RepairView();
      return RepairStart.unavailable;
    } on ProviderError catch (error) {
      state = RepairView(error: error.message);
      return RepairStart.failed;
    } on ServerException catch (error) {
      state = RepairView(error: error.message);
      return RepairStart.failed;
    } on IOException catch (error) {
      state = RepairView(error: '$error');
      return RepairStart.failed;
    }
  }
}

final repairProvider = NotifierProvider<RepairController, RepairView>(RepairController.new);

/// I siti tornati sani per cui si propone di riparare, ciascuno una volta
/// per ritorno. Sta fra le impostazioni del database: i siti rotti già visti
/// e le proposte non ancora risolte, perché una proposta ignorata non
/// ricompaia e una non vista non si perda chiudendo l'app.
class SiteRecoveryNotifier extends AsyncNotifier<Set<String>> {
  static const String _key = 'archive.siteRecovery';

  @override
  Future<Set<String>> build() async {
    final saved = await _read();
    ref.listen(siteHealthProvider, (_, next) {
      final sites = next.value;
      if (sites != null) unawaited(observe({for (final MapEntry(:key, :value) in sites.entries) if (value.broken) key}));
    }, fireImmediately: true);
    // Il file del telefono lo scrivono i giri ad app chiusa, la risposta del
    // server cambia da sola: rientrando in primo piano si rilegge.
    final lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(siteHealthProvider));
    ref.onDispose(lifecycle.dispose);
    return saved.offers;
  }

  Future<({Set<String> broken, Set<String> offers})> _read() async {
    final value = await ref.read(userRepositoryProvider).readSetting(_key);
    if (value == null || value.isEmpty) return (broken: <String>{}, offers: <String>{});
    try {
      final json = jsonDecode(value) as Map<String, Object?>;
      Set<String> list(String name) => {...(json[name] as List? ?? const []).whereType<String>()};
      return (broken: list('broken'), offers: list('offers'));
    } on FormatException {
      return (broken: <String>{}, offers: <String>{});
    } on TypeError {
      return (broken: <String>{}, offers: <String>{});
    }
  }

  /// Registra i siti rotti di adesso ([broken], letti davvero): quelli rotti
  /// l'ultima volta e ora no sono tornati sani, e si propongono.
  Future<void> observe(Set<String> broken) async {
    final saved = await _read();
    final offers = {...saved.offers, ...saved.broken.difference(broken)}.difference(broken);
    if (const SetEquality<String>().equals(saved.broken, broken) &&
        const SetEquality<String>().equals(saved.offers, offers)) {
      if (!state.hasValue) state = AsyncData(offers);
      return;
    }
    await _write(broken, offers);
    if (ref.mounted) state = AsyncData(offers);
  }

  /// Toglie la proposta per [site]: ignorata o accettata.
  Future<void> dismiss(String site) async {
    final saved = await _read();
    await _write(saved.broken, saved.offers.difference({site}));
    if (ref.mounted) state = AsyncData((state.value ?? const <String>{}).difference({site}));
  }

  Future<void> _write(Set<String> broken, Set<String> offers) => ref
      .read(userRepositoryProvider)
      .writeSetting(_key, jsonEncode({'broken': [...broken], 'offers': [...offers]}));
}

final siteRecoveryProvider =
    AsyncNotifierProvider<SiteRecoveryNotifier, Set<String>>(SiteRecoveryNotifier.new);
