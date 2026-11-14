/// L'avviso a chi riceve una libreria di Drive che il suo accesso sta per
/// scadere (docs/drive.md, «La libreria condivisa», punto «Chi riceve»).
/// Qui sta solo la scelta di chi annunciare: la notifica la manda il chiamante.
library;

import 'share_directory.dart';
import 'shared_library.dart';
import 'sources/source.dart';
import 'user_repository.dart';

/// Impostazione degli avvisi di scadenza già dati. Sta fra le impostazioni
/// perché un secondo telefono con lo stesso account non ripeta la notifica.
const String expiryNoticesKey = 'drive.shares.expiry.seen';

/// Le soglie, dalla più lontana alla più vicina.
const List<Duration> expiryThresholds = [Duration(days: 7), Duration(days: 1)];

/// Un avviso da dare: la riga e la soglia che è scattata.
typedef ExpiryNotice = ({DriveShare share, Duration threshold});

/// `id@at`, termine e soglia insieme: un rinnovo cambia il termine, quindi
/// riarma le soglie (un termine spostato oltre i 7 giorni avvisa di nuovo a 7
/// e a 1).
String expiryStamp(DriveShare share, Duration threshold) =>
    '${shareStamp(share)}#${share.expiresAt!.toUtc().toIso8601String()}#${threshold.inDays}';

/// Gli avvisi da dare adesso: righe accettate (seguite da una sorgente),
/// non rifiutate, con un termine non ancora passato. Per riga al più uno, il
/// più urgente fra le soglie scattate e non ancora date: se l'app si apre a
/// 20 ore dal termine, «1 giorno» e basta, e anche i 7 giorni contano come dati.
/// Il secondo elemento è il nuovo insieme degli avvisi dati.
({List<ExpiryNotice> notices, Set<String> seen}) dueExpiryNotices(
  List<DriveShare> rows,
  Iterable<SourceConfig> sources,
  Set<String> dismissed,
  Set<String> seen,
  DateTime now,
) {
  final notices = <ExpiryNotice>[];
  final updated = {...seen};
  for (final row in rows) {
    final expiresAt = row.expiresAt;
    if (expiresAt == null || row.expiredAt(now) || dismissed.contains(shareStamp(row))) continue;
    if (!sources.any((source) => followsShare(source, row))) continue;
    final left = expiresAt.difference(now);
    final reached = [for (final threshold in expiryThresholds) if (left <= threshold) threshold];
    if (reached.isEmpty) continue;
    final fresh = [for (final threshold in reached) if (!seen.contains(expiryStamp(row, threshold))) threshold];
    if (fresh.isEmpty) continue;
    notices.add((share: row, threshold: reached.last));
    for (final threshold in reached) {
      updated.add(expiryStamp(row, threshold));
    }
  }
  return (notices: notices, seen: updated);
}

/// Dà gli avvisi dovuti e ricorda quelli dati. Se [notify] fallisce niente si
/// ricorda: si riprova alla lettura dopo.
Future<void> announceShareExpiries(
  UserRepository user,
  List<DriveShare> rows,
  Iterable<SourceConfig> sources,
  Set<String> dismissed,
  Future<void> Function(ExpiryNotice notice) notify, {
  DateTime? now,
}) async {
  final seen = parseStamps(await user.readSetting(expiryNoticesKey));
  final due = dueExpiryNotices(rows, sources, dismissed, seen, now ?? DateTime.now());
  if (due.notices.isEmpty) return;
  for (final notice in due.notices) {
    await notify(notice);
  }
  await user.writeSetting(expiryNoticesKey, encodeStamps(due.seen));
}
