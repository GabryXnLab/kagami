/// Dove si trova la libreria e se l'app può leggerla.
///
/// Su Android la cartella sincronizzata da FolderSync sta fuori dallo spazio
/// privato dell'app: serve l'accesso a tutti i file, perché leggere decine di
/// migliaia di immagini attraverso il Storage Access Framework costerebbe una
/// chiamata di piattaforma per file. Vedere `docs/design.md`.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _libraryKey = 'library.root';

class LibraryLocation {
  const LibraryLocation(this._preferences);

  static Future<LibraryLocation> open() async =>
      LibraryLocation(await SharedPreferences.getInstance());

  final SharedPreferences _preferences;

  String? get root => _preferences.getString(_libraryKey);

  Future<void> setRoot(String? value) async {
    if (value == null) {
      await _preferences.remove(_libraryKey);
    } else {
      await _preferences.setString(_libraryKey, value);
    }
  }

  /// Chiede la cartella all'utente. Restituisce `null` se annulla.
  Future<String?> choose() async {
    final chosen = await FilePicker.getDirectoryPath(
      dialogTitle: 'Scegli la cartella della libreria manga',
    );
    if (chosen == null) return null;
    await setRoot(chosen);
    return chosen;
  }

  Future<bool> hasAccess() async {
    if (!Platform.isAndroid) return true;
    return Permission.manageExternalStorage.status
        .then((status) => status.isGranted);
  }

  Future<bool> requestAccess() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }
}

/// Le cartelle dell'app, risolte una volta prima del primo fotogramma: chi
/// costruisce la libreria le vuole subito, non dentro un `Future`.
class AppDirectories {
  const AppDirectories({required this.support, required this.cache});

  static Future<AppDirectories> resolve() async => AppDirectories(
        support: (await getApplicationSupportDirectory()).path,
        cache: (await getApplicationCacheDirectory()).path,
      );

  /// Sopravvive agli aggiornamenti, non a una disinstallazione.
  final String support;

  /// Il sistema può svuotarla quando manca spazio: ci sta solo ciò che si
  /// può sempre riscaricare.
  final String cache;

  /// La libreria dei download fatti senza una cartella scelta.
  String get privateLibrary => p.join(support, 'library');
}
