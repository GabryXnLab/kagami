/// Le scadenze delle condivisioni su Drive, affidate al Kagami Server perché
/// le faccia valere anche ad app chiusa (docs/server-api.md, `PUT /v2/me/shares`).
library;

import 'package:kagami_archive/remote.dart';

import 'share_directory.dart';

/// Il tetto di voci che il server accetta.
const int maxServerShares = 200;

/// Le righe che il server deve conoscere: quelle con un termine e un
/// permesso, una volta sola per coppia cartella-permesso, le più vicine
/// a scadere se sono troppe.
List<RemoteShare> serverSharesOf(Iterable<DriveShare> rows) {
  final byKey = <String, RemoteShare>{};
  for (final row in rows) {
    final expiry = row.expiresAt;
    if (expiry == null || row.folderId.isEmpty || row.permissionId.isEmpty) continue;
    byKey['${row.folderId}\u0000${row.permissionId}'] =
        RemoteShare(folderId: row.folderId, permissionId: row.permissionId, expiresAt: expiry.toUtc());
  }
  final shares = byKey.values.toList()..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  return shares.length <= maxServerShares ? shares : shares.sublist(0, maxServerShares);
}

/// Allinea l'elenco del server alle [rows]; dice se ha dovuto mandarlo.
///
/// Un server senza `shares` fra le `features` non riceve niente. Un server che
/// non risponde lascia l'eccezione a chi chiama: non è «nessuna scadenza», e
/// non si manda un elenco vuoto per una lettura fallita.
Future<bool> alignServerShares(ServerClient client, Iterable<DriveShare> rows) async {
  if (!(await client.info()).shares) return false;
  final wanted = serverSharesOf(rows);
  final held = await client.heldShares();
  if (held.length == wanted.length && held.toSet().containsAll(wanted)) return false;
  await client.replaceShares(wanted);
  return true;
}
