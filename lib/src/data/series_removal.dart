/// Togliere una serie dalla libreria, ovunque stia.
///
/// È l'altro punto, accanto a «Libera spazio» (`cleanup.dart`), in cui l'app
/// cancella dalla libreria, e anche questo solo quando lo chiede l'utente:
/// la cartella della serie sparisce dal telefono — cartella scelta e spazio
/// dell'app — e su Drive va nel cestino, con la sua riga di `library.json`
/// (regole in `docs/malf.md`, «Chi scrive»). Smette anche tutto ciò che la
/// riporterebbe: il controllo dei capitoli nuovi, i lavori in coda, lo
/// scarico man mano.
///
/// Lo stato di lettura resta: cronologia e statistiche sono letture fatte, e
/// se la serie torna riprende da dove era.
library;

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/manual.dart' show normalizeLink;
import 'package:kagami_archive/stores.dart';
import 'package:kagami_archive/tracking.dart';

import '../archive/device.dart';
import '../format/malf.dart';
import 'drive_library.dart';
import 'drive_ownership.dart';
import 'folder_sync.dart';
import 'library.dart';
import 'library_repository.dart';

/// Se una serie con questi [holders] si può togliere: serve almeno uno
/// scaffale su cui l'app ha il diritto di cancellare, cioè il telefono o il
/// Drive dell'account se la cartella è sua ([driveOwned] vero; senza
/// scaffali noti non c'è niente da proteggere: toglie ciò che toglieva). Una
/// serie che hanno soltanto le altre sorgenti remote (condivise da altri, in
/// sola lettura) o un Drive non proprio non si propone e non si tocca.
bool canRemoveSeries(List<LibraryShelf> holders, {required bool? driveOwned}) =>
    holders.isEmpty ||
    holders.any((shelf) => shelf is LibraryRepository) ||
    (driveOwned == true && ownDriveShelf(holders) != null);

/// Toglie [entry] da [holders]. Drive solo con [writer], che ha il permesso
/// di scrivere, [folderId], la cartella della libreria, e [driveOwned] vero:
/// Kagami cancella solo dove l'utente possiede, mai dallo scaffale di una
/// condivisione (FASE-5b §5).
///
/// I lavori in coda per i link di [keepUrls] (già normalizzati) restano: chi
/// toglie una scheda manuale per metterci al posto la serie vera li ha appena
/// accodati, e il link della scheda può essere lo stesso.
Future<void> removeSeries(
  SeriesEntry entry, {
  required List<LibraryShelf> holders,
  required ArchiveFiles archive,
  SyncFiles? sync,
  DriveFiles? drive,
  DriveClient? writer,
  String? folderId,
  bool? driveOwned,
  Set<String> keepUrls = const {},
}) async {
  // Prima ciò che la riscaricherebbe: un giro che finisse dopo riscriverebbe
  // cartella e riga.
  final tracking = Tracking(archive.ongoing);
  final urls = {
    for (final series in await tracking.load())
      if (series.key == entry.key) series.url,
    for (final outcome in await archive.history())
      if (outcome.seriesKey == entry.key) ?outcome.url,
  }..removeWhere((url) => keepUrls.contains(normalizeLink(url)));
  await tracking.forget(entry.key);
  final jobs = [for (final job in await archive.jobs()) if (urls.contains(job.url)) job];
  final status = await archive.status();
  final running = status.state == ArchiveState.running &&
      jobs.any((job) => job.id == status.jobId) &&
      await archive.running();
  if (running) await const ArchiveScheduler().stop();
  for (final job in jobs) {
    await archive.remove(job.id);
  }
  if (running && (await archive.jobs()).isNotEmpty) {
    // Il giro fermato ha qualche istante per chiudersi: la coda riparte
    // dopo, come quando si toglie un lavoro a mano.
    await Future<void>.delayed(const Duration(seconds: 2));
    await const ArchiveScheduler().start();
  }

  if (writer != null && folderId != null && driveOwned == true && ownDriveShelf(holders) != null) {
    await sync?.release([entry.path], SyncSide.remote);
    await DriveStore(
      remote: DriveSyncRemote(writer),
      folderId: folderId,
      staging: archive.staging(folderId).path,
    ).removeSeries(entry.path, entry.key);
  }
  for (final shelf in holders.whereType<LibraryRepository>()) {
    if (!shelf.private) await sync?.release([entry.path], SyncSide.local);
    await LocalStore(shelf.root).removeSeries(entry.path, entry.key);
  }
  await drive?.forgetSeries(entry.key);
}
