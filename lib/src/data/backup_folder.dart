/// La cartella dove l'utente vuole, in più, la copia automatica.
///
/// Come lo stato di FolderSync non sta nel database e quindi non viaggia con
/// backup e account: una cartella del telefono ha senso solo su quel telefono.
/// E non può stare dentro la radice di una sorgente: la libreria si condivide
/// e si sincronizza, e la copia contiene letture, voti e impostazioni (D5).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Cosa si sa della cartella scelta. Tre stati: *non ho potuto leggere* non è
/// *non c'è*, e chi scrive a partire da uno stato letto deve distinguerli.
sealed class BackupFolderState {
  const BackupFolderState();
}

class BackupFolderNone extends BackupFolderState {
  const BackupFolderNone();
}

class BackupFolderChosen extends BackupFolderState {
  const BackupFolderChosen(this.path);

  final String path;
}

class BackupFolderUnreadable extends BackupFolderState {
  const BackupFolderUnreadable();
}

/// Perché una cartella non è stata accettata.
enum BackupFolderRefusal { insideSource }

class BackupFolderStore {
  BackupFolderStore(String supportDirectory)
      : file = File(p.join(supportDirectory, 'backup-folder.json'));

  final File file;

  Future<BackupFolderState> read() async {
    try {
      if (!await file.exists()) return const BackupFolderNone();
      final json = jsonDecode(await file.readAsString());
      final path = json is Map ? json['path'] : null;
      if (path is! String || path.isEmpty) return const BackupFolderUnreadable();
      return BackupFolderChosen(path);
    } on Object {
      return const BackupFolderUnreadable();
    }
  }

  /// `null` se la cartella è stata salvata; altrimenti il motivo. [sourceRoots]
  /// sono le radici locali delle sorgenti.
  Future<BackupFolderRefusal?> choose(
    String path,
    Iterable<String> sourceRoots,
  ) async {
    if (insideAny(path, sourceRoots)) return BackupFolderRefusal.insideSource;
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.part');
    await pending.writeAsString(jsonEncode({'path': path}), flush: true);
    await pending.rename(file.path);
    return null;
  }

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }

  /// Se [path] è una radice o sta sotto una.
  static bool insideAny(String path, Iterable<String> roots) {
    final target = p.normalize(p.absolute(path));
    return roots.any((root) {
      final normalized = p.normalize(p.absolute(root));
      return target == normalized || p.isWithin(normalized, target);
    });
  }
}
