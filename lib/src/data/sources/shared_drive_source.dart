/// La libreria che un altro ha condiviso su Drive, letta in sola lettura
/// (contratto in docs/drive.md, «La libreria condivisa»).
library;

import 'package:kagami_archive/drive.dart';

import '../drive_library.dart';
import '../library.dart';
import '../shared_copies.dart';
import 'source.dart';

/// Un [DriveRepository] sulla cartella dell'altro, con la sua cache e il suo
/// stato, rivestito del contratto delle sorgenti. A differenza del Drive
/// dell'account possiede client e file: li chiude quando si spegne.
class SharedDriveSource implements StorageSource {
  SharedDriveSource({
    required this.config,
    required this.client,
    required this.repository,
  }) : files = DriveFiles(repository);

  @override
  final SourceConfig config;

  final DriveClient client;
  final DriveRepository repository;

  @override
  final DriveFiles files;

  /// Né caricare, né riscrivere gli indici, né togliere, né lavorare ad app
  /// chiusa: la cartella è di un altro. Scaricare solo se la riga lo permette.
  @override
  SourceCapabilities get capabilities => SourceCapabilities(download: sharedDownloadAllowed(config));

  @override
  LibraryShelf get shelf => repository;

  /// Lo dice leggendo, con [SourceUnavailable].
  @override
  Future<SourceState> probe() async => SourceState.ready;

  @override
  void dispose() {
    files.dispose();
    client.close();
  }
}
