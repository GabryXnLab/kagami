/// Le copie scaricate da una libreria condivisa (FASE-5b §4, docs/drive.md,
/// «La libreria condivisa»): stanno nello scaffale privato della sorgente,
/// mai nella cartella scelta dall'utente — da lì la sincronizzazione le
/// porterebbe nel suo Drive e la scadenza non le raggiungerebbe più — e
/// seguono il permesso.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'library_location.dart';
import 'library_repository.dart';
import 'shared_library.dart';
import 'sources/source.dart';

/// Se chi ha condiviso lascia anche scaricare. Una riga senza il campo vale
/// «solo streaming», e così una sorgente che non l'ha ancora preso.
bool sharedDownloadAllowed(SourceConfig config) =>
    config.kind == SourceKind.driveShared && config.params['download'] == true;

/// Stato della sorgente: istantanea degli indici e, in `library/`, le copie.
String sharedStateDirectory(AppDirectories directories, String id) =>
    p.join(directories.support, 'drive-shared', id);

/// La cache delle tavole lette in streaming.
String sharedCacheDirectory(AppDirectories directories, String id) =>
    p.join(directories.cache, 'drive-shared', id);

/// Lo scaffale privato: le cartelle di Drive non si chiamano `library`, e lo
/// stato del [DriveRepository] sta sotto l'id della cartella.
String sharedCopiesDirectory(AppDirectories directories, String id) =>
    p.join(sharedStateDirectory(directories, id), 'library');

/// Le copie di una libreria condivisa come scaffale del telefono: per la
/// pulizia e per «Elimina serie» è una copia del telefono come le altre
/// (FASE-5b §5), privata perché nessuno la sincronizza.
class SharedCopiesShelf extends LibraryRepository {
  SharedCopiesShelf(AppDirectories directories, this.shareId)
      : super(sharedCopiesDirectory(directories, shareId), requireIndex: false, private: true);

  /// L'id della sorgente condivisa da cui vengono.
  final String shareId;

  /// Diverso da quello della sorgente: da qui non si riscarica.
  @override
  String get sourceId => '$shareId.copies';
}

enum SharedCopiesFate {
  keep,

  /// Il permesso è tornato «solo streaming»: via le copie, la sorgente resta.
  copies,

  /// Scaduta (o riga sparita, che la fa scadere) o di un altro account: via
  /// copie, istantanea e cache delle tavole.
  everything,
}

/// Cosa resta sul telefono di una libreria condivisa. Lo sa da sé, senza
/// rete: una rilettura fallita o un 403 non passano di qui.
SharedCopiesFate sharedCopiesFate(SourceConfig config, {required String? account, required DateTime now}) {
  if (config.kind != SourceKind.driveShared) return SharedCopiesFate.keep;
  if (config.expiredAt(now) || belongsToOtherAccount(config, account)) return SharedCopiesFate.everything;
  return sharedDownloadAllowed(config) ? SharedCopiesFate.keep : SharedCopiesFate.copies;
}

/// Toglie dal telefono ciò che [fate] dice.
Future<void> dropSharedCopies(AppDirectories directories, String id, SharedCopiesFate fate) async {
  final paths = switch (fate) {
    SharedCopiesFate.keep => const <String>[],
    SharedCopiesFate.copies => [sharedCopiesDirectory(directories, id)],
    SharedCopiesFate.everything => [
        sharedStateDirectory(directories, id),
        sharedCacheDirectory(directories, id),
      ],
  };
  for (final path in paths) {
    final directory = Directory(path);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
