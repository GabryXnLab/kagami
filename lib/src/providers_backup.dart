/// La cartella delle copie scelta dall'utente, come la tiene l'app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/backup_folder.dart';
import 'providers.dart';

final backupFolderStoreProvider = Provider<BackupFolderStore>(
  (ref) => BackupFolderStore(ref.watch(appDirectoriesProvider).support),
);

/// Le radici locali delle sorgenti: la cartella scelta e lo spazio dell'app.
final localSourceRootsProvider = Provider<List<String>>((ref) => [
      ?ref.watch(libraryRootProvider),
      ref.watch(appDirectoriesProvider).privateLibrary,
    ]);

class BackupFolder extends AsyncNotifier<BackupFolderState> {
  @override
  Future<BackupFolderState> build() => ref.watch(backupFolderStoreProvider).read();

  /// `null` se salvata, altrimenti il motivo del rifiuto.
  Future<BackupFolderRefusal?> choose(String path) async {
    final refusal = await ref
        .read(backupFolderStoreProvider)
        .choose(path, ref.read(localSourceRootsProvider));
    if (refusal == null) state = AsyncData(BackupFolderChosen(path));
    return refusal;
  }

  Future<void> clear() async {
    await ref.read(backupFolderStoreProvider).clear();
    state = const AsyncData(BackupFolderNone());
  }
}

final backupFolderProvider =
    AsyncNotifierProvider<BackupFolder, BackupFolderState>(BackupFolder.new);
