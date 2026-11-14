/// Chi riceve una libreria di Drive condivisa: quali righe di `drive_shares`
/// sono inviti, come diventano sorgenti e come le sorgenti seguono la riga
/// (contratto in docs/drive.md, «La libreria condivisa», punto «Chi riceve»).
library;

import 'dart:async';

import 'backend.dart';
import 'share_directory.dart';
import 'sources/source.dart';

/// Impostazione dei rifiutati: `id@at` delle righe, separati da virgola.
const String dismissedSharesKey = 'drive.shares.dismissed';

/// Impostazione degli inviti già annunciati, stessa forma. Sta fra le
/// impostazioni perché un secondo telefono con lo stesso account non ripeta
/// la notifica.
const String announcedSharesKey = 'drive.shares.seen';

/// `id` e `at` insieme: un invito riscritto dopo un ritiro ha un `at` nuovo
/// e quindi è un'altra cosa.
String shareStamp(DriveShare share) => '${share.id}@${share.at.toUtc().toIso8601String()}';

Set<String> parseStamps(String? raw) => {
      ...(raw ?? '').split(',').where((stamp) => stamp.isNotEmpty),
    };

String encodeStamps(Set<String> stamps) => stamps.join(',');

/// L'account che ha accettato la libreria (minuscolo), se la sorgente lo
/// ricorda: una configurazione di prima di F5.20 non ha `account`.
String? sharedAccountOf(SourceConfig config) {
  final account = config.params['account'];
  return account is String && account.isNotEmpty ? account.toLowerCase() : null;
}

/// Una libreria condivisa accettata da un altro account di quello entrato (o
/// con nessuno entrato): resta in elenco ma non si legge. Senza `account`
/// salvato si comporta come sempre.
bool belongsToOtherAccount(SourceConfig config, String? current) {
  if (config.kind != SourceKind.driveShared) return false;
  final account = sharedAccountOf(config);
  return account != null && account != current?.toLowerCase();
}

/// La sorgente che segue questa riga: stesso proprietario e stessa cartella,
/// e, se la sorgente ricorda l'account, la riga è per quello.
bool followsShare(SourceConfig config, DriveShare share) =>
    config.kind == SourceKind.driveShared &&
    config.params['folderId'] == share.folderId &&
    '${config.params['owner']}'.toLowerCase() == share.from.toLowerCase() &&
    (sharedAccountOf(config) ?? share.to.toLowerCase()) == share.to.toLowerCase();

/// Le righe che sono inviti: non ancora una sorgente, non rifiutate, e non
/// già scadute (un invito che non si può usare non si propone).
List<DriveShare> pendingShares(
  List<DriveShare> rows,
  Iterable<SourceConfig> sources,
  Set<String> dismissed,
  DateTime now,
) =>
    [
      for (final row in rows)
        if (!row.expiredAt(now) &&
            !dismissed.contains(shareStamp(row)) &&
            !sources.any((source) => followsShare(source, row)))
          row,
    ];

/// L'indirizzo che si mostra: il nome accanto, ma l'indirizzo c'è sempre.
String shareOwnerLabel(DriveShare share) =>
    share.fromName == null || share.fromName!.isEmpty ? share.from : '${share.fromName} (${share.from})';

SourceConfig sourceFromShare(DriveShare share, {required String id, int order = 0}) => SourceConfig(
      id: id,
      kind: SourceKind.driveShared,
      label: share.folderName,
      params: {
        'folderId': share.folderId,
        'folderName': share.folderName,
        'owner': share.from,
        'account': share.to.toLowerCase(),
        'download': share.download,
        if (share.fromName != null) 'ownerName': share.fromName,
      },
      expiresAt: share.expiresAt,
      order: order,
    );

/// Come stanno le sorgenti condivise dopo una rilettura **riuscita** delle
/// righe: termine e permesso di scaricare seguono la riga; di una riga sparita la sorgente scade da
/// adesso e resta in elenco. Le altre sorgenti non si toccano. Lo stato di
/// lettura non passa di qui.
///
/// [rows] sono le righe di [account]: le sorgenti di un altro account non si
/// toccano, e una senza `account` lo prende dalla prima riga che combacia.
List<SourceConfig> followShares(
  List<SourceConfig> sources,
  List<DriveShare> rows,
  DateTime now, {
  required String account,
}) =>
    [
      for (final source in sources) _follow(source, rows, now, account.toLowerCase()),
    ];

SourceConfig _follow(SourceConfig source, List<DriveShare> rows, DateTime now, String account) {
  if (source.kind != SourceKind.driveShared) return source;
  if (belongsToOtherAccount(source, account)) return source;
  DriveShare? row;
  for (final candidate in rows) {
    if (followsShare(source, candidate)) row = candidate;
  }
  if (row == null) {
    final expiry = source.expiresAt;
    return expiry != null && !expiry.isAfter(now) ? source : source.copyWith(expiresAt: now.toUtc());
  }
  final adopt = sharedAccountOf(source) == null;
  final download = (source.params['download'] == true) != row.download;
  if (row.expiresAt == source.expiresAt && !adopt && !download) return source;
  return source.copyWith(
    params: adopt || download
        ? {...source.params, if (adopt) 'account': account, 'download': row.download}
        : null,
    expiresAt: row.expiresAt,
    clearExpiry: row.expiresAt == null,
  );
}

/// Le righe per [email] nel tempo: lette subito, e riletta a ogni evento di
/// `changes` e di [resumed]. Una lettura fallita non emette niente (l'elenco
/// di prima resta); [ShareUnavailable] vuol dire funzione assente e non si
/// riprova.
Stream<List<DriveShare>> watchSharesForMe(
  ShareDirectory directory,
  String email, {
  Stream<void> resumed = const Stream.empty(),
}) {
  late final StreamController<List<DriveShare>> controller;
  final subscriptions = <StreamSubscription<void>>[];
  var unavailable = false;
  Future<void> load() async {
    if (unavailable || controller.isClosed) return;
    try {
      final rows = await directory.forMe(email);
      if (!controller.isClosed) controller.add(rows);
    } on ShareUnavailable {
      unavailable = true;
    } on Object catch (error) {
      if (backendFailure(error) == BackendFailure.unavailable) unavailable = true;
    }
  }

  controller = StreamController<List<DriveShare>>(
    onListen: () {
      for (final source in [directory.changes(email), resumed]) {
        subscriptions.add(source.listen((_) => load(), onError: (Object _) {}));
      }
      unawaited(load());
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
