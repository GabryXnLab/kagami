/// Il Drive di un utente sul server: il suo permesso e la sua cartella.
///
/// Il permesso è un refresh token che l'app ha ottenuto da Google per il
/// client «Web» del progetto (vedi `google_token.dart` del pacchetto): quello
/// del proprietario arriva col comando di avvio, quello degli altri dall'app,
/// quando collegano il server. Sta in `drive.json` nella cartella
/// dell'utente, leggibile solo dal server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/stores.dart';

import 'config.dart';
import 'worker.dart';

/// Il permesso non c'è o non vale più: l'utente lo ridà dall'app.
class DriveNotAuthorized extends DriveAuthRequired {
  const DriveNotAuthorized([this.reason = 'Il server non ha il permesso di scrivere sul tuo Drive: '
      'collega di nuovo il server dall\'app.']);

  final String reason;

  @override
  String toString() => reason;
}

/// Ciò che l'API vede del Drive di un utente.
abstract interface class DriveSetup {
  Future<bool> get authorized;
  String? get folderId;
  String? get folderName;

  /// Se la cartella è dell'account (`ownedByMe`), `null` se non è stato
  /// letto: il server sposta nel cestino solo con `true` (`owner`).
  bool? get folderOwned;

  /// Prova il permesso e la cartella, e solo se vanno tutti e due li salva.
  Future<void> grant(String refreshToken, String folderId);

  /// Controlla che il server veda e possa usare la cartella, e la sceglie.
  Future<DriveItem> choose(String folderId);

  /// Dimentica permesso e cartella.
  Future<void> forget();

  /// Ritira un permesso di una cartella (`DriveClient.unshare`: 404 è già
  /// ritirato). Senza il permesso dell'utente lancia [DriveNotAuthorized].
  Future<void> unshare(String folderId, String permissionId);
}

class UserDrive implements DriveSetup {
  UserDrive(this.file, this.client, {this.endpoint, this.driveFor});

  final File file;
  final GoogleClient client;
  final Uri? endpoint;

  /// Il client di Drive col token di [token], nei test uno che risponde in locale.
  final DriveClient Function(Future<String> Function({bool refresh}) token)? driveFor;

  String? _refresh;
  String? _folderId;
  String? _folderName;
  bool? _owned;
  String? _access;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);

  late final DriveClient drive =
      driveFor?.call(token) ?? DriveClient(token, network: const ServerNetwork(), connections: driveLanes);

  Future<void> load() async {
    final json = await readJsonFile(file) ?? const {};
    _refresh = json['refreshToken'] as String?;
    _folderId = json['folderId'] as String?;
    _folderName = json['folderName'] as String?;
    // Di un'altra cartella non vale: non letto.
    final owned = json['owned'];
    _owned = owned is Map && owned['folderId'] == _folderId ? owned['owned'] as bool? : null;
  }

  @override
  Future<bool> get authorized async => _refresh != null;

  @override
  String? get folderId => _folderId;

  @override
  String? get folderName => _folderName;

  @override
  bool? get folderOwned => _owned;

  /// La proprietà della cartella [id], se è quella della libreria: un lavoro
  /// messo in coda per una cartella di prima non sposta niente nel cestino.
  bool? ownedOf(String id) => id == _folderId ? _owned : null;

  /// Chiede a Drive se la cartella è dell'account; un errore la lascia non
  /// letta, e si richiede al giro dopo ([blocked]).
  Future<void> _readOwner() async {
    final id = _folderId;
    if (id == null) return;
    bool? owned;
    try {
      owned = await drive.owned(id);
    } on DriveException {
      owned = null;
    }
    if (id != _folderId) return;
    _owned = owned;
  }

  /// Il token per [DriveClient].
  Future<String> token({bool refresh = false}) async {
    final access = _access;
    if (!refresh && access != null && DateTime.now().isBefore(_expires)) return access;
    final saved = _refresh;
    if (saved == null) throw const DriveNotAuthorized();
    return _accessFor(saved);
  }

  Future<String> _accessFor(String refreshToken) async {
    final Map<String, Object?> json;
    try {
      json = await requestGoogleToken({
        'client_id': client.id,
        'client_secret': client.secret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      }, endpoint: endpoint);
    } on GrantRejected catch (error) {
      throw DriveNotAuthorized('$error: collega di nuovo il server dall\'app.');
    }
    final fresh = json['access_token'] as String;
    final seconds = (json['expires_in'] as num?)?.toInt() ?? 3600;
    // Qualche minuto prima della scadenza: un caricamento cominciato con un
    // token al limite finirebbe con un 401 a metà.
    _expires = DateTime.now().add(Duration(seconds: max(60, seconds - 300)));
    return _access = fresh;
  }

  @override
  Future<void> grant(String refreshToken, String folderId) async {
    await _accessFor(refreshToken);
    final previous = _refresh;
    _refresh = refreshToken;
    try {
      final item = await _check(folderId);
      _folderId = item.id;
      _folderName = item.name;
      _owned = null;
    } on Object {
      _refresh = previous;
      _access = null;
      rethrow;
    }
    await _readOwner();
    await _save();
  }

  /// Senza toccare Drive: il comando di avvio si applica anche offline, e
  /// il giro dice poi se il permesso non va.
  Future<void> put(String refreshToken, String folderId, String? folderName) async {
    _refresh = refreshToken;
    _folderId = folderId;
    _folderName = folderName;
    _owned = null;
    _access = null;
    await _save();
  }

  @override
  Future<DriveItem> choose(String folderId) async {
    final item = await _check(folderId);
    _folderId = item.id;
    _folderName = item.name;
    _owned = null;
    await _readOwner();
    await _save();
    return item;
  }

  Future<DriveItem> _check(String folderId) async {
    final item = await drive.file(folderId);
    if (!item.folder) throw const DriveException('Non è una cartella.');
    // Un elenco dice anche che il server ci può entrare: `file` risponde
    // pure per una cartella vista solo di sfuggita da un link condiviso.
    await drive.children(folderId);
    return item;
  }

  @override
  Future<void> forget() async {
    _refresh = null;
    _folderId = null;
    _folderName = null;
    _owned = null;
    _access = null;
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> unshare(String folderId, String permissionId) => drive.unshare(folderId, permissionId);

  Future<void> _save() => writeSecret(
        file,
        jsonEncode({
          'refreshToken': ?_refresh,
          'folderId': ?_folderId,
          'folderName': ?_folderName,
          if (_owned != null) 'owned': {'folderId': _folderId, 'owned': _owned},
        }),
      );

  /// Perché un giro non può partire, o `null`.
  Future<String?> blocked() async {
    if (_refresh == null) return 'Il server non ha il permesso del tuo Drive: collegalo dall\'app.';
    if (_folderId == null) return 'Manca la cartella della libreria: sceglila dall\'app.';
    try {
      await token();
      if (_owned == null) {
        await _readOwner();
        if (_owned != null) await _save();
      }
      return null;
    } on DriveNotAuthorized catch (error) {
      return '$error';
    } on DriveOffline {
      return 'Google non risponde: si riprova fra poco.';
    }
  }

  void close() => drive.close();
}
