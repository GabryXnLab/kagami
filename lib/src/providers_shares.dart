/// La libreria su Drive che si lascia leggere ad altri, come la tiene l'app
/// (contratto in docs/drive.md, «La libreria condivisa»).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/cloud.dart';
import 'data/drive.dart';
import 'data/drive_access.dart';
import 'data/network.dart';
import 'data/notifications.dart';
import 'data/share_expiry_notice.dart';
import 'data/share_server.dart';
import 'data/shared_library.dart';
import 'data/sources/source.dart';
import 'data/user_repository.dart';
import 'l10n.dart';
import 'providers.dart';
import 'providers_sources.dart';

/// Chi condivide, se c'è un account, il backend e una cartella di Drive; se no
/// niente. Il token è quello con cui si scrive quando l'utente l'ha già dato,
/// altrimenti quello di sola lettura: non apre mai la finestra del consenso, che
/// spetta a un gesto (`DriveAuth.authorize`).
final driveAccessProvider = Provider<DriveAccess?>((ref) {
  if (!cloudAvailable) return null;
  final signedIn = ref.watch(cloudAccountProvider.select((s) => s.signedIn));
  final folderId = ref.watch(driveFolderProvider.select((folder) => folder.value?.id));
  if (!signedIn || folderId == null) return null;
  final auth = ref.watch(driveAuthProvider);
  final client = DriveClient(({bool refresh = false}) async {
    try {
      return await auth.writeToken(refresh: refresh);
    } on DriveAuthRequired {
      return auth.token(refresh: refresh);
    }
  }, network: NetworkMonitor.instance);
  ref.onDispose(client.close);
  return DriveAccess(directory: const SupabaseShareDirectory(), drive: client);
});

/// Ritira le condivisioni scadute senza dire niente a nessuno: un errore qui è
/// una passata che si rifà al giro dopo.
Future<int> sweepSilently(DriveAccess access) async {
  try {
    return await access.sweep();
  } on Object {
    return 0;
  }
}

/// Dice al server collegato (se c'è, e se sa ritirare le condivisioni) le
/// scadenze di adesso. Senza server, con un server vecchio o spento non fa
/// niente e non dice niente: lo si rifà al giro dopo (avvio, secondo piano,
/// un gesto sul foglio).
Future<void> syncServerShares(Ref ref) async {
  final access = ref.read(driveAccessProvider);
  final link = ref.read(serverLinkProvider).value;
  if (access == null || link == null) return;
  try {
    await alignServerShares(serverClient(ref, link), await access.mine());
  } on Object {
    // Il server non c'è o non risponde: non è «nessuna scadenza».
  }
}

final driveShareServerSyncProvider = Provider<Future<void> Function()>((ref) => () => syncServerShares(ref));

/// La passata delle scadenze fuori dal foglio: all'avvio (e quando l'account o
/// la cartella cambiano), da `AppShell`, e andando in secondo piano.
final driveShareSweepProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final access = ref.read(driveAccessProvider);
    if (access == null) return;
    if (await sweepSilently(access) > 0) ref.invalidate(driveShareReadersProvider);
    await syncServerShares(ref);
  };
});

/// Chi può leggere la cartella di adesso. Prima la passata delle scadenze, così
/// il foglio non mostra come vivo ciò che si può già ritirare. Un errore delle
/// righe esce (mai «nessuno»); `null` se non c'è chi condivide.
final driveShareReadersProvider = FutureProvider.autoDispose<ShareReaders?>((ref) async {
  final access = ref.watch(driveAccessProvider);
  final folderId = ref.watch(driveFolderProvider.select((folder) => folder.value?.id));
  if (access == null || folderId == null) return null;
  await sweepSilently(access);
  return access.readers(folderId);
});


// ---------------------------------------------------------------------------
// Chi riceve (docs/drive.md, «La libreria condivisa», punto «Chi riceve»)
// ---------------------------------------------------------------------------

final shareDirectoryProvider = Provider<ShareDirectory>((ref) => const SupabaseShareDirectory());

/// L'indirizzo con cui si cercano le righe per me; `null` senza account o
/// senza backend. Chi riceve non ha bisogno di una cartella sua.
final shareReceiverProvider = Provider<String?>((ref) {
  if (!cloudAvailable) return null;
  final email = ref.watch(cloudAccountProvider.select((status) => status.account?.email));
  return email == null || email.isEmpty ? null : email.toLowerCase();
});

/// Le righe `drive_shares` per me: lette all'avvio, tornando in primo piano e a
/// ogni evento del realtime. Una lettura fallita lascia l'elenco di prima (non
/// è «nessuna riga»); [ShareUnavailable] vuol dire funzione assente e non si
/// riprova. Senza una lettura riuscita il provider non ha valore.
final incomingSharesProvider = StreamProvider<List<DriveShare>>((ref) {
  final email = ref.watch(shareReceiverProvider);
  if (email == null) return const Stream.empty();
  final resumed = StreamController<void>();
  final lifecycle = AppLifecycleListener(onResume: () => resumed.add(null));
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(resumed.close());
  });
  return watchSharesForMe(ref.watch(shareDirectoryProvider), email, resumed: resumed.stream);
});

/// Gli inviti rifiutati (`id@at`), come stanno in `drive.shares.dismissed`.
class DismissedShares extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async =>
      parseStamps(await ref.watch(userRepositoryProvider).readSetting(dismissedSharesKey));

  /// Un gesto dell'utente: rifiutare un invito o togliere la sorgente.
  Future<void> dismiss(DriveShare share) async {
    final stamps = {...await future, shareStamp(share)};
    await ref.read(userRepositoryProvider).writeSetting(dismissedSharesKey, encodeStamps(stamps));
    state = AsyncData(stamps);
  }
}

final dismissedSharesProvider = AsyncNotifierProvider<DismissedShares, Set<String>>(DismissedShares.new);

/// Le righe che sono inviti. Finché non si sa (righe, sorgenti o rifiutati non
/// ancora letti) è vuoto: mai un invito in più per una lettura che manca.
final shareInvitesProvider = Provider<List<DriveShare>>((ref) {
  final rows = ref.watch(incomingSharesProvider).value;
  final sources = ref.watch(librarySourcesProvider).value;
  final dismissed = ref.watch(dismissedSharesProvider).value;
  if (rows == null || sources == null || sources.unreadable || dismissed == null) return const [];
  return pendingShares(rows, sources.sources, dismissed, DateTime.now());
});

Future<void> _notifyShareInvite(String id, {required String title, required String text}) =>
    ArrivalNotifications.instance.shareInvite(id, title: title, text: text);

/// Dà notizia di un invito una volta sola: i già annunciati stanno fra le
/// impostazioni, così un secondo telefono con lo stesso account non ripete.
Future<void> announceShareInvites(
  UserRepository user,
  List<DriveShare> invites, {
  Future<void> Function(String id, {required String title, required String text}) notify =
      _notifyShareInvite,
}) async {
  final seen = parseStamps(await user.readSetting(announcedSharesKey));
  final fresh = [for (final invite in invites) if (!seen.contains(shareStamp(invite))) invite];
  if (fresh.isEmpty) return;
  for (final invite in fresh) {
    await notify(
      invite.id,
      title: currentL10n().driveReceivedNotificationTitle(invite.fromName ?? invite.from),
      text: currentL10n().driveReceivedNotificationText(invite.folderName),
    );
  }
  await user.writeSetting(announcedSharesKey, encodeStamps({...seen, for (final invite in fresh) shareStamp(invite)}));
}

/// Avvisa che una libreria accettata sta per scadere. Toccando la notifica si
/// apre il foglio delle librerie condivise, che ha «Chiedi più tempo».
Future<void> announceShareExpiry(UserRepository user, List<DriveShare> rows, List<SourceConfig> sources, Set<String> dismissed) =>
    announceShareExpiries(user, rows, sources, dismissed, (notice) {
      final share = notice.share;
      final l10n = currentL10n();
      return ArrivalNotifications.instance.shareInvite(
        'expiry-${shareStamp(share)}',
        title: l10n.driveExpiryNoticeTitle(share.fromName ?? share.from),
        text: l10n.driveExpiryNoticeText(share.folderName, share.expiresAt!.toLocal()),
      );
    });

/// Fa vivere ciò che chi riceve deve fare a app aperta: a ogni lettura
/// riuscita le sorgenti condivise seguono la riga, e gli inviti nuovi si
/// annunciano. Lo accende `AppShell`.
final sharedLibraryWatcherProvider = Provider<void>((ref) {
  // Una notifica alla volta: due eventi vicini non annunciano due volte.
  var announcing = Future<void>.value();
  ref.listen(incomingSharesProvider, (_, next) {
    final rows = next.value;
    final account = ref.read(shareReceiverProvider);
    if (rows == null || account == null) return;
    unawaited(ref.read(librarySourcesProvider.notifier).follow(rows, account: account).catchError((Object _) {}));
  }, fireImmediately: true);
  ref.listen(shareInvitesProvider, (_, invites) {
    if (invites.isEmpty) return;
    final user = ref.read(userRepositoryProvider);
    announcing = announcing.then((_) => announceShareInvites(user, invites)).catchError((Object _) {});
  }, fireImmediately: true);
  // Le scadenze vicine: a ogni lettura riuscita delle righe, o quando cambiano
  // sorgenti e rifiutati. Finché qualcosa non è letto non si avvisa di niente.
  void checkExpiry() {
    final rows = ref.read(incomingSharesProvider).value;
    final sources = ref.read(librarySourcesProvider).value;
    final dismissed = ref.read(dismissedSharesProvider).value;
    if (rows == null || sources == null || sources.unreadable || dismissed == null) return;
    final user = ref.read(userRepositoryProvider);
    announcing = announcing.then((_) => announceShareExpiry(user, rows, sources.sources, dismissed)).catchError((Object _) {});
  }
  ref.listen(incomingSharesProvider, (_, _) => checkExpiry());
  ref.listen(librarySourcesProvider, (_, _) => checkExpiry());
  ref.listen(dismissedSharesProvider, (_, _) => checkExpiry());
});

/// Chi riceve: rifiuta l'invito (solo locale: la riga non si tocca).
Future<void> declineShare(WidgetRef ref, DriveShare share) => ref.read(dismissedSharesProvider.notifier).dismiss(share);

/// Toglie la sorgente condivisa. La riga di chi condivide non si cancella; se
/// c'è ancora, si segna fra i rifiutati perché non torni a proporsi.
Future<void> removeSharedSource(WidgetRef ref, SourceConfig source) async {
  final rows = ref.read(incomingSharesProvider).value ?? const <DriveShare>[];
  for (final row in rows.where((row) => followsShare(source, row))) {
    await ref.read(dismissedSharesProvider.notifier).dismiss(row);
  }
  await ref.read(librarySourcesProvider.notifier).remove(source.id);
}

/// La voce in Impostazioni → Drive c'è se qualcuno ha condiviso qualcosa con
/// noi: un invito o una sorgente già accettata (anche scaduta, per il «Togli»).
final shareReceivedVisibleProvider = Provider<bool>((ref) {
  if (ref.watch(shareInvitesProvider).isNotEmpty) return true;
  final sources = ref.watch(librarySourcesProvider).value?.sources ?? const <SourceConfig>[];
  return sources.any((source) => source.kind == SourceKind.driveShared);
});
