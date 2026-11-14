/// Da dove un capitolo scende sul telefono: il Drive dell'account, una
/// libreria condivisa che lo permette o una sorgente per percorsi (WebDAV, SMB).
///
/// `ChapterDownloader` scrive l'albero MALF, i `.part` e `downloads.json`
/// senza sapere da chi arrivano i byte; questo è il solo punto che lo sa.
library;

import 'dart:io';

import 'package:kagami_archive/transport.dart';
import 'package:path/path.dart' as p;

import '../format/malf.dart';
import '../l10n.dart';
import 'drive.dart';
import 'drive_library.dart';
import 'library.dart';
import 'network.dart';
import 'sources/path_shelf.dart';

abstract interface class DownloadOrigin {
  /// Dove leggere gli indici di serie, capitoli e tavole.
  LibraryShelf get shelf;

  /// Un testo della serie così com'è sulla sorgente; `null` se non c'è.
  Future<String?> seriesText(SeriesEntry entry, String name);

  /// Porta [relative] (relativo alla radice della libreria) in [temporary].
  /// Se [temporary] c'è già a metà, riprende da lì quando la sorgente lo sa.
  /// Una sorgente che non risponde è [DriveOffline] o [TransportOffline].
  Future<void> fetch(SeriesEntry entry, String relative, File temporary);

  /// Se la rete c'è davvero: decide se vale la pena riprovare subito.
  Future<bool> online();

  /// Dove devono finire le copie, se la sorgente lo impone (lo scaffale
  /// privato di una libreria condivisa); `null`: dove sceglie l'utente.
  String? get destination;
}

class DriveOrigin implements DownloadOrigin {
  DriveOrigin(this.drive, this.files, {this.destination});

  final DriveRepository drive;
  final DriveFiles files;

  @override
  final String? destination;

  @override
  LibraryShelf get shelf => drive;

  @override
  Future<String?> seriesText(SeriesEntry entry, String name) =>
      drive.seriesText(entry, name);

  /// Una tavola già letta in streaming sta in cache: si copia invece di
  /// riscaricarla.
  @override
  Future<void> fetch(SeriesEntry entry, String relative, File temporary) async {
    final cached = files.peek(drive.locate(entry, relative));
    if (cached != null) {
      await File(cached).copy(temporary.path);
      return;
    }
    final item = await drive.resolve('${entry.path}/$relative');
    if (item == null) throw DriveException(currentL10n().dataPageNotOnDrive);
    await drive.client.download(item.id, temporary);
  }

  @override
  Future<bool> online() => drive.client.network.check();
}

class PathOrigin implements DownloadOrigin {
  PathOrigin(this.path, this.files, {Future<bool> Function()? online})
      : _online = online ?? NetworkMonitor.instance.check;

  final PathShelf path;
  final PathFiles files;
  final Future<bool> Function() _online;

  @override
  String? get destination => null;

  @override
  LibraryShelf get shelf => path;

  @override
  Future<String?> seriesText(SeriesEntry entry, String name) =>
      path.seriesText(entry, name);

  @override
  Future<void> fetch(SeriesEntry entry, String relative, File temporary) async {
    final cached = files.peek(path.locate(entry, relative));
    if (cached != null) {
      await File(cached).copy(temporary.path);
      return;
    }
    final from = await temporary.exists() ? await temporary.length() : 0;
    await path.transport.download(
      path.pathOf(p.posix.join(entry.path, relative)),
      temporary,
      resumeFrom: from,
    );
  }

  @override
  Future<bool> online() => _online();
}
