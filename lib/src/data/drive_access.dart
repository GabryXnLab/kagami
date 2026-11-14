/// La libreria su Drive che un account lascia leggere a un altro: le due
/// scritture (permesso su Drive, riga sul backend) nell'ordine del contratto
/// in docs/drive.md, «La libreria condivisa».
library;

import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/remote.dart' show ServerUnauthorized;

import '../format/malf.dart' show readingDirectory;
import 'cloud.dart';
import 'share_directory.dart';

export 'share_directory.dart';

/// Chi può leggere una cartella, come lo sa chi condivide.
class ShareReaders {
  const ShareReaders({
    required this.shares,
    required this.withoutRow,
    required this.linkAccess,
    required this.driveAnswered,
    this.personal = const [],
  });

  /// Le righe di chi condivide, anche di altre cartelle.
  final List<DriveShare> shares;

  /// Persone o gruppi che Drive elenca sulla cartella senza una riga.
  final List<DrivePermission> withoutRow;

  /// Esiste un permesso per link o dominio: si gestisce da Drive.
  final bool linkAccess;

  /// Falso se `sharedWith` è fallito: allora `withoutRow` e `linkAccess` non
  /// dicono niente, non che non ci sia nessuno.
  final bool driveAnswered;

  /// Dati personali rimasti nella cartella che qualcuno può leggere
  /// ([DriveAccess.personalData]). `null`: c'è chi legge ma non ho potuto
  /// controllare; vuoto anche quando nessuno legge e non serviva chiedere.
  final List<DriveItem>? personal;
}

class DriveAccess {
  const DriveAccess({required this.directory, required this.drive, this.account, this.now = DateTime.now});

  final ShareDirectory directory;
  final DriveClient drive;

  /// Chi è dentro; di serie l'account della sessione del backend.
  final CloudAccount? Function()? account;
  final DateTime Function() now;

  static const int _maxText = 127;

  CloudAccount _me() {
    final me = account != null ? account!() : const CloudAuth().current;
    if (me == null || me.email.isEmpty) throw const ServerUnauthorized();
    return me;
  }

  static String _cut(String text) => text.length <= _maxText ? text : text.substring(0, _maxText);

  /// Le righe scritte dall'account corrente.
  Future<List<DriveShare>> mine() => directory.mine(_me().email);

  /// Ciò che di personale resta in `reading/` della cartella (docs/malf.md,
  /// § `reading/`): la cartella `backup` e i due JSON di prima del database.
  /// Un elenco fallito esce: «non ho potuto controllare» non è «niente».
  Future<List<DriveItem>> personalData(String folderId) async {
    final readings = await drive.query(
      "'${DriveClient.quote(folderId)}' in parents and name = '$readingDirectory' "
      "and mimeType = '$folderMimeType' and trashed = false",
    );
    return [
      for (final reading in readings)
        for (final item in await drive.children(reading.id))
          if (item.folder ? item.name == 'backup' : _personalFiles.contains(item.name)) item,
    ];
  }

  static const Set<String> _personalFiles = {'state.json', 'collections.json'};

  /// Sposta nel cestino di Drive i dati personali di [folderId]; dice quanti.
  /// Il primo cestino fallito esce.
  Future<int> clearPersonalData(String folderId) async {
    final items = await personalData(folderId);
    for (final item in items) {
      await drive.trash(item.id);
    }
    return items.length;
  }

  /// Lascia leggere [folderId] a [email]. Passo zero: i dati personali della
  /// cartella vanno nel cestino, e se non si possono elencare o cestinare non
  /// nasce nessun permesso. Poi il permesso, poi la riga: se la riga non si
  /// scrive il permesso si ritira e l'errore della riga esce.
  Future<DriveShare> share({
    required String folderId,
    required String folderName,
    required String email,
    Duration? duration,
    bool download = false,
  }) async {
    if (email.trim().toLowerCase() == _me().email.toLowerCase()) {
      throw ArgumentError.value(email, 'email', 'è il tuo stesso indirizzo');
    }
    await clearPersonalData(folderId);
    return _grant(folderId: folderId, folderName: folderName, email: email, duration: duration, download: download);
  }

  Future<DriveShare> _grant({
    required String folderId,
    required String folderName,
    required String email,
    Duration? duration,
    bool download = false,
  }) async {
    final me = _me();
    final target = email.trim().toLowerCase();
    final from = me.email.toLowerCase();
    if (target == from) throw ArgumentError.value(email, 'email', 'è il tuo stesso indirizzo');
    final start = now();
    final expiry = duration == null ? null : start.add(duration);
    final permission = await drive.share(folderId, target, expiresAt: expiry);
    final to = permission.email ?? target;
    final row = DriveShare(
      id: DriveShare.shareId(from, to, folderId),
      to: to,
      from: from,
      fromName: me.name == null ? null : _cut(me.name!),
      folderId: folderId,
      folderName: _cut(folderName),
      permissionId: permission.id,
      at: start,
      expiresAt: expiry,
      download: download,
    );
    try {
      await directory.put(row);
    } on Object {
      try {
        await drive.unshare(folderId, permission.id);
      } on Object {
        // Resta un permesso senza riga, che il foglio mostra.
      }
      rethrow;
    }
    return row;
  }

  /// Sposta il termine di [share] (o lo toglie con [duration] vuota), dopo lo
  /// stesso passo zero di [share]. Se Drive non ha più il permesso se ne crea
  /// uno nuovo.
  Future<DriveShare> renew(DriveShare share, Duration? duration) async {
    await clearPersonalData(share.folderId);
    final start = now();
    final expiry = duration == null ? null : start.add(duration);
    final DrivePermission permission;
    try {
      permission = await drive.renewShare(share.folderId, share.permissionId, expiry);
    } on DriveException catch (error) {
      if (error.status != 404) rethrow;
      return _grant(
        folderId: share.folderId,
        folderName: share.folderName,
        email: share.to,
        duration: duration,
        download: share.download,
      );
    }
    final row = share.copyWith(permissionId: permission.id, expiresAt: expiry, clearExpiry: expiry == null);
    await directory.put(row);
    return row;
  }

  /// Cambia solo il permesso di scaricare di [share]: su Drive non cambia
  /// niente, è una riga sola (FASE-5b §4). Su un backend senza la colonna,
  /// concederlo lancia [ShareDownloadUnavailable].
  Future<DriveShare> setDownload(DriveShare share, bool download) async {
    final row = share.copyWith(download: download);
    await directory.put(row);
    return row;
  }

  /// Ritira il permesso e, solo se Drive ha risposto, la riga. Senza rete (o
  /// con ogni altro errore) esce l'errore e la riga resta.
  Future<void> revoke(DriveShare share) async {
    await drive.unshare(share.folderId, share.permissionId);
    await directory.remove(share.id);
  }

  /// Ritira le condivisioni scadute; dice quante. Un errore su una riga non
  /// ferma le altre, e non apre mai la finestra del consenso.
  Future<int> sweep() async {
    final at = now();
    var done = 0;
    for (final share in await mine()) {
      if (!share.expiredAt(at)) continue;
      try {
        await revoke(share);
        done++;
      } on Object {
        // La riga resta: si riprova al giro dopo.
      }
    }
    return done;
  }

  /// Chi può leggere [folderId]: le righe e, se Drive risponde, ciò che Drive
  /// aggiunge; se qualcuno legge, anche i dati personali rimasti (per chi ha
  /// condiviso prima del passo zero, o da Drive a mano). Un errore delle righe
  /// esce; uno di Drive no.
  Future<ShareReaders> readers(String folderId) async {
    final shares = await mine();
    final known = [for (final row in shares) if (row.folderId == folderId) row];
    List<DrivePermission> withoutRow = const [];
    var linkAccess = false;
    var driveAnswered = false;
    try {
      final permissions = await drive.sharedWith(folderId);
      final ids = {for (final row in known) row.permissionId};
      final addresses = {for (final row in known) row.to};
      withoutRow = [
        for (final permission in permissions)
          if (permission.role != 'owner' &&
              (permission.type == 'user' || permission.type == 'group') &&
              !ids.contains(permission.id) &&
              !addresses.contains(permission.email))
            permission,
      ];
      linkAccess = permissions.any(
        (permission) => permission.role != 'owner' && (permission.type == 'anyone' || permission.type == 'domain'),
      );
      driveAnswered = true;
    } on DriveException {
      // Chi aggiunge Drive non si sa: restano le righe.
    }
    List<DriveItem>? personal = const [];
    if (known.isNotEmpty || withoutRow.isNotEmpty || linkAccess) {
      try {
        personal = await personalData(folderId);
      } on DriveException {
        personal = null;
      }
    }
    return ShareReaders(
      shares: shares,
      withoutRow: withoutRow,
      linkAccess: linkAccess,
      driveAnswered: driveAnswered,
      personal: personal,
    );
  }

  /// Ritira un permesso che non ha riga.
  Future<void> revokePermission(String folderId, String permissionId) => drive.unshare(folderId, permissionId);
}
