/// Kagami cancella solo dove l'utente possiede (FASE-5b §5, `docs/libreria.md`
/// «Cancellare solo dove si possiede»): lo scaffale del Drive dell'account fra
/// quelli di una serie, e se la cartella della libreria è davvero sua.
library;

import 'package:collection/collection.dart';
import 'package:kagami_archive/drive.dart';

import 'drive_library.dart';
import 'library.dart';

/// Lo scaffale del Drive dell'account fra [holders]: mai quello di una
/// condivisione, che è anch'esso un [DriveRepository].
DriveRepository? ownDriveShelf(Iterable<LibraryShelf> holders) => holders
    .whereType<DriveRepository>()
    .firstWhereOrNull((shelf) => shelf.origin == LibraryOrigin.drive);

/// L'impostazione che ricorda se la cartella è dell'account:
/// `<folderId>:<true|false>`. Con l'id, perché cambiando cartella la risposta
/// di prima non vale più.
const String driveFolderOwnedKey = 'drive.folder.owned';

/// La risposta salvata in [stored] per [folderId]; `null` se non c'è o è di
/// un'altra cartella.
bool? storedFolderOwnership(String? stored, String folderId) => switch (stored) {
      final value? when value == '$folderId:true' => true,
      final value? when value == '$folderId:false' => false,
      _ => null,
    };

/// Se la cartella [folderId] è dell'account, a tre stati: la risposta già
/// salvata in [stored], altrimenti quella di Drive ([ask]), che si salva con
/// [save]. `null` vuol dire «non ho potuto chiedere»: niente cancellazioni su
/// Drive e si richiede al giro dopo, senza salvare niente.
Future<bool?> resolveFolderOwnership({
  required String folderId,
  required String? stored,
  required Future<bool> Function(String folderId) ask,
  required Future<void> Function(String value) save,
}) async {
  final known = storedFolderOwnership(stored, folderId);
  if (known != null) return known;
  final bool owned;
  try {
    owned = await ask(folderId);
  } on DriveException {
    return null;
  }
  await save('$folderId:$owned');
  return owned;
}
