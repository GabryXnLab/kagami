/// Lo stato della «Comunità»: impostazioni, profilo da pubblicare, letture dal
/// backend e i tre momenti in cui il profilo esce. Contratto in `docs/social.md`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/cloud.dart';
import 'data/db/account_databases.dart' show sessionOwnsSlot;
import 'data/notifications.dart';
import 'data/share_directory.dart';
import 'data/social/backend.dart';
import 'data/social/content.dart';
import 'data/social/hestia_messages.dart';
import 'data/social/message_alerts.dart';
import 'data/social/hestia_posts.dart';
import 'data/social/hestia_reports.dart';
import 'data/social/hestia_social.dart';
import 'data/social/profile.dart';
import 'data/social/sync.dart';
import 'data/statistics.dart';
import 'format/kind.dart';
import 'l10n.dart';
import 'providers.dart';

/// Le scelte dell'utente, da `social.*` nel database (quindi in backup e account).
class SocialSettingsNotifier extends AsyncNotifier<SocialSettings> {
  @override
  Future<SocialSettings> build() async {
    final repository = ref.watch(userRepositoryProvider);
    return SocialSettings.fromSettings({
      for (final key in SocialSettings.keys) key: await repository.readSetting(key),
    });
  }

  Future<void> save(SocialSettings settings) async {
    final before = state.value;
    state = AsyncData(settings);
    final repository = ref.read(userRepositoryProvider);
    final values = settings.toSettings();
    for (final entry in values.entries) {
      if (before == null || before.toSettings()[entry.key] != entry.value) {
        await repository.writeSetting(entry.key, entry.value);
      }
    }
  }
}

final socialSettingsProvider =
    AsyncNotifierProvider<SocialSettingsNotifier, SocialSettings>(SocialSettingsNotifier.new);

/// Il backend del social, solo con un account: senza, l'app non chiede niente.
final socialBackendProvider = Provider<SocialBackend?>((ref) {
  if (!cloudAvailable || !ref.watch(cloudAccountProvider.select((status) => status.signedIn))) return null;
  return HestiaSocial();
});

/// Post, commenti e mi piace, con lo stesso account del backend del social.
final socialPostsProvider = Provider<SocialPosts?>((ref) => ref.watch(socialBackendProvider) == null ? null : HestiaPosts());

/// Messaggi privati, con lo stesso account del backend del social.
final socialMessagesProvider =
    Provider<SocialMessages?>((ref) => ref.watch(socialBackendProvider) == null ? null : HestiaMessages());

/// Un evento a ogni messaggio che può essere arrivato (realtime). Chi legge i
/// messaggi lo guarda per rileggersi; un canale che non si apre tace.
final socialMessagesTickProvider = StreamProvider<void>((ref) {
  final messages = ref.watch(socialMessagesProvider);
  return messages == null ? const Stream.empty() : messages.changes();
});

/// Le segnalazioni: si scrivono e non si rileggono.
final socialReportsProvider = Provider<SocialReports?>((ref) => ref.watch(socialBackendProvider) == null ? null : HestiaReports());

/// Chi sono io sul backend (l'`uid` dell'account).
final socialMeProvider = Provider<String?>(
  (ref) => ref.watch(cloudAccountProvider.select((status) => status.account?.id)),
);

/// Il profilo che si pubblicherebbe adesso: la stessa funzione che lo
/// pubblica, con le statistiche chieste senza le serie nascoste. Serve anche
/// all'anteprima della schermata di adesione.
final socialDraftProvider = FutureProvider<PublicProfile>((ref) async {
  final settings = await ref.watch(socialSettingsProvider.future);
  ref.watch(readingProvider);
  final hidden = ref.watch(hiddenSeriesKeysProvider);
  final signals = ref.watch(librarySignalsProvider);
  final statistics = await StatisticsRepository(ref.watch(databaseProvider)).load(excluding: hidden);
  return buildPublicProfile(
    uid: ref.watch(socialMeProvider) ?? '',
    settings: settings,
    statistics: statistics,
    series: [
      for (final s in signals)
        ProfileSeries(
          key: s.entry.key,
          title: s.entry.title,
          genres: s.entry.genres,
          kind: kindOf(s.entry.type),
          read: s.readCount,
          status: s.state.status,
          rating: s.state.rating,
        ),
    ],
    hidden: hidden,
    now: DateTime.now(),
    photo: ref.watch(cloudAccountProvider.select((status) => status.account?.photo)),
  );
});

/// Fin dove si è arrivati in ogni serie, per `Spoilable.concealedFor`: la
/// chiave è `seriesRef(titolo)`, l'unico nome che due lettori hanno in comune.
final socialProgressProvider = Provider<Map<String, num?>>((ref) => {
      for (final s in ref.watch(shownSignalsProvider)) seriesRef(s.entry.title): num.tryParse(s.state.reachedChapter ?? ''),
    });

class SocialStatus {
  const SocialStatus({this.busy = false, this.unavailable = false, this.refused = false});

  final bool busy;

  /// Il backend non ha il social: lo si è scoperto leggendo, e non si riprova.
  final bool unavailable;

  /// L'ultima scrittura è stata rifiutata dalle regole.
  final bool refused;
}

/// Accende, pubblica e spegne. Le letture e le scritture fallite arrivano a
/// chi chiama; `SocialUnavailable` si ricorda in [SocialStatus].
class SocialController extends Notifier<SocialStatus> {
  @override
  SocialStatus build() => const SocialStatus();

  SocialSync? get _sync {
    final backend = ref.read(socialBackendProvider);
    if (backend == null) return null;
    final repository = ref.read(userRepositoryProvider);
    return SocialSync(
      backend: backend,
      readPublished: () async {
        final value = await repository.readSetting(SocialSync.publishedKey);
        return value == null || value.isEmpty ? null : value;
      },
      writePublished: (value) => repository.writeSetting(SocialSync.publishedKey, value ?? ''),
    );
  }

  /// Pubblica se acceso e cambiato (o sempre, con [force]). Mai un errore
  /// rumoroso: è un giro che si rifà al prossimo momento.
  ///
  /// Solo se la sessione è quella dello slot: statistiche e serie nascoste
  /// vengono dal file di questo contenitore, e non vanno nel profilo di un
  /// altro account entrato nel frattempo.
  Future<SocialPublish?> publish({bool force = false}) async {
    if (!sessionOwnsSlot(ref.read(databaseSlotProvider), ref.read(cloudAuthProvider).current?.id)) {
      return null;
    }
    final sync = _sync;
    if (sync == null || state.unavailable) return null;
    final settings = await ref.read(socialSettingsProvider.future);
    if (!settings.enabled) return SocialPublish.disabled;
    try {
      return await sync.publish(settings, () => ref.read(socialDraftProvider.future), force: force);
    } on SocialUnavailable {
      state = const SocialStatus(unavailable: true);
    } on Object {
      // Rete o backend: si riprova al prossimo avvio o a richiesta.
    }
    return null;
  }

  /// Accende con [settings] e pubblica subito. Un errore resta acceso ma non
  /// pubblicato: lo dice chi chiama, e il prossimo giro riprova.
  Future<void> turnOn(SocialSettings settings) async {
    state = const SocialStatus(busy: true);
    await ref.read(socialSettingsProvider.notifier).save(settings);
    try {
      await ref.read(socialDraftProvider.future);
      final sync = _sync;
      if (sync == null) throw const SocialUnavailable();
      await sync.publish(settings, () => ref.read(socialDraftProvider.future), force: true);
      state = const SocialStatus();
    } on SocialUnavailable {
      await ref.read(socialSettingsProvider.notifier).save(settings.copyWith(enabled: false));
      state = const SocialStatus(unavailable: true);
    } on SocialRefused {
      await ref.read(socialSettingsProvider.notifier).save(settings.copyWith(enabled: false));
      state = const SocialStatus(refused: true);
    } on Object {
      await ref.read(socialSettingsProvider.notifier).save(settings.copyWith(enabled: false));
      state = const SocialStatus();
      rethrow;
    }
  }

  /// Spegne: cancella dal backend ciò che era suo, poi lo dimentica qui. Se
  /// la cancellazione fallisce resta acceso, perché spento vorrebbe dire
  /// «via» a chi ha ancora il profilo in rete.
  Future<void> turnOff() async {
    state = const SocialStatus(busy: true);
    try {
      await leave();
      final settings = await ref.read(socialSettingsProvider.future);
      await ref.read(socialSettingsProvider.notifier).save(settings.copyWith(enabled: false));
    } finally {
      state = const SocialStatus();
    }
  }

  /// Toglie il profilo dalla rete (anche per «Elimina i dati dall'account»).
  /// Senza account o con il social spento non fa niente.
  Future<void> leave() async {
    final settings = await ref.read(socialSettingsProvider.future);
    final sync = _sync;
    if (sync == null || !settings.enabled) return;
    try {
      await sync.leave();
    } on SocialUnavailable {
      // Niente schema, niente da cancellare.
    }
  }
}

final socialControllerProvider = NotifierProvider<SocialController, SocialStatus>(SocialController.new);

/// La pubblicazione d'avvio, accanto alla sincronizzazione dell'account.
final socialSyncRunProvider = FutureProvider<void>((ref) async {
  if (ref.watch(socialBackendProvider) == null) return;
  final enabled = await ref.watch(socialSettingsProvider.selectAsync((settings) => settings.enabled));
  if (!enabled) return;
  await ref.read(socialControllerProvider.notifier).publish();
});

/// Le classifiche: una lettura per segmento, solo con il social acceso.
final socialBoardProvider = FutureProvider.family<List<PublicProfile>, Board>((ref, board) async {
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || !await _enabled(ref)) return const [];
  return backend.board(board);
});

final socialGraphProvider = FutureProvider<SocialGraph>((ref) async {
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || !await _enabled(ref)) return const SocialGraph();
  return backend.graph();
});

/// Un profilo; `null` se non c'è o non lo si può vedere (da fuori è lo stesso).
final socialProfileProvider = FutureProvider.family<PublicProfile?, String>((ref, uid) async {
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || !await _enabled(ref)) return null;
  return backend.profile(uid);
});

/// Ricerca per soprannome. Mai per indirizzo: una `@` non cerca niente.
final socialSearchProvider = FutureProvider.family<List<PublicProfile>, String>((ref, query) async {
  final text = query.trim();
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || text.length < 2 || text.contains('@') || !await _enabled(ref)) return const [];
  return backend.search(text);
});

/// Le persone che seguo, per la scheda «Persone».
final socialFollowingProvider = FutureProvider<List<PublicProfile>>((ref) async {
  final backend = ref.watch(socialBackendProvider);
  final graph = await ref.watch(socialGraphProvider.future);
  if (backend == null || graph.following.isEmpty) return const [];
  return backend.people(graph.following);
});

/// Le serie nascoste come le nomina la rete (`seriesRef` del titolo): i loro
/// post, anche di altri, non si mostrano, e di loro non si chiede niente.
final socialHiddenRefsProvider = Provider<Set<String>>((ref) {
  final hidden = ref.watch(hiddenSeriesKeysProvider);
  if (hidden.isEmpty) return const {};
  return {
    for (final s in ref.watch(librarySignalsProvider))
      if (hidden.contains(s.entry.key)) seriesRef(s.entry.title),
  };
});

/// Toglie i post delle persone silenziate e quelli sulle serie nascoste.
Future<List<Post>> _shown(Ref ref, Future<List<Post>> Function() read) async {
  final muted = (await ref.watch(socialSettingsProvider.future)).muted;
  final hidden = ref.watch(socialHiddenRefsProvider);
  return [
    for (final post in await read())
      if (!muted.contains(post.author.id) && !hidden.contains(post.series)) post,
  ];
}

/// Il feed: di tutti quelli che vedo, o solo di chi seguo.
final socialFeedProvider = FutureProvider.family<List<Post>, FeedScope>((ref, scope) async {
  final posts = ref.watch(socialPostsProvider);
  if (posts == null || !await _enabled(ref)) return const [];
  return _shown(ref, () => posts.feed(scope));
});

/// I post su una serie (`seriesRef`). Una serie nascosta non si chiede alla
/// rete: la richiesta ne porterebbe il titolo.
final socialSeriesPostsProvider = FutureProvider.family<List<Post>, String>((ref, series) async {
  final posts = ref.watch(socialPostsProvider);
  if (ref.watch(socialHiddenRefsProvider).contains(series)) throw StateError('serie nascosta');
  if (posts == null || !await _enabled(ref)) return const [];
  return _shown(ref, () => posts.about(series));
});

/// I commenti di un post, senza quelli delle persone silenziate.
final socialCommentsProvider = FutureProvider.family<List<Comment>, String>((ref, postId) async {
  final posts = ref.watch(socialPostsProvider);
  if (posts == null || !await _enabled(ref)) return const [];
  final muted = (await ref.watch(socialSettingsProvider.future)).muted;
  return [
    for (final comment in await posts.comments(postId))
      if (!muted.contains(comment.author.id)) comment,
  ];
});

/// Scrive, toglie e mette mi piace; dopo ogni scrittura si rileggono le liste
/// toccate. I rifiuti delle regole arrivano a chi chiama come `SocialRefused`.
class SocialPostsController extends Notifier<void> {
  @override
  void build() {}

  SocialPosts get _posts => ref.read(socialPostsProvider) ?? (throw const SocialUnavailable());

  void _reload({String? series}) {
    ref.invalidate(socialFeedProvider);
    if (series != null) ref.invalidate(socialSeriesPostsProvider(series));
  }

  /// Pubblica, o dice perché no senza chiamare la rete. Una serie nascosta si
  /// riconosce dalla chiave e anche dal titolo.
  Future<PostRefusal?> publish(PostDraft draft) async {
    final hiddenTitle = draft.seriesTitle != null && ref.read(socialHiddenRefsProvider).contains(seriesRef(draft.seriesTitle!));
    final refusal = hiddenTitle ? PostRefusal.hiddenSeries : draft.refusal(hidden: ref.read(hiddenSeriesKeysProvider));
    if (refusal != null) return refusal;
    final post = await _posts.publish(draft);
    _reload(series: post.series);
    return null;
  }

  Future<void> remove(Post post) async {
    await _posts.remove(post.id);
    _reload(series: post.series);
  }

  Future<void> comment(Post post, String body, {Comment? replyTo, bool spoiler = false}) async {
    // Un solo livello: la risposta a una risposta si attacca allo stesso commento.
    await _posts.comment(post.id, body, parent: replyTo == null ? null : replyTo.parent ?? replyTo.id, spoiler: spoiler);
    ref.invalidate(socialCommentsProvider(post.id));
    _reload(series: post.series);
  }

  Future<void> removeComment(Post post, Comment comment) async {
    await _posts.removeComment(comment.id);
    ref.invalidate(socialCommentsProvider(post.id));
    _reload(series: post.series);
  }

  /// Senza rilettura: chi chiama mostra subito il nuovo stato.
  Future<void> like({Post? post, Comment? comment, required bool liked}) =>
      _posts.like(post: post?.id, comment: comment?.id, liked: liked);
}

final socialPostsControllerProvider = NotifierProvider<SocialPostsController, void>(SocialPostsController.new);

Future<bool> _enabled(Ref ref) => ref.watch(socialSettingsProvider.selectAsync((settings) => settings.enabled));

/// Segui o smetti di seguire; poi il grafo si rilegge. La scrittura che le
/// regole rifiutano arriva a chi chiama come `SocialRefused`.
Future<void> setFollowing(WidgetRef ref, String uid, {required bool follow}) async {
  final backend = ref.read(socialBackendProvider);
  final settings = await ref.read(socialSettingsProvider.future);
  if (backend == null) return;
  if (follow) {
    await backend.follow(uid, name: settings.name.trim());
  } else {
    await backend.unfollow(uid);
  }
  ref.invalidate(socialGraphProvider);
  ref.invalidate(socialFollowingProvider);
}

/// Silenzia o riattiva una persona: solo su questo telefono (`social.muted`),
/// i suoi post e commenti non si mostrano più.
Future<void> setMuted(WidgetRef ref, String uid, {required bool muted}) async {
  final notifier = ref.read(socialSettingsProvider.notifier);
  final settings = await ref.read(socialSettingsProvider.future);
  await notifier.save(settings.copyWith(muted: muted ? {...settings.muted, uid} : ({...settings.muted}..remove(uid))));
}

/// Le persone che ho bloccato. Il loro profilo non si vede più: restano gli `uid`.
final socialBlockedProvider = FutureProvider<Set<String>>((ref) async {
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || !await _enabled(ref)) return const {};
  return backend.blocked();
});

const socialBlockedNamesKey = 'social.blockedNames';

bool _sameNames(Map<String, String> a, Map<String, String> b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// I soprannomi di chi ho bloccato, uid → nome, salvati al momento del blocco.
final socialBlockedNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final raw = await ref.watch(userRepositoryProvider).readSetting(socialBlockedNamesKey);
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {for (final e in decoded.entries) if (e.value is String) e.key.toString(): e.value as String};
  } on FormatException {
    return const {};
  }
});

/// Blocca o sblocca una persona. Cambiano i legami e ciò che si vede di lei:
/// tutto ciò che ne dipende si rilegge. Il rifiuto arriva come `SocialRefused`.
///
/// Il backend conosce solo l'`uid`: il [name] di chi si blocca si tiene sul
/// telefono (`social.blockedNames`) per riconoscerlo nell'elenco dei bloccati.
Future<void> setBlocked(WidgetRef ref, String uid, {required bool blocked, String? name}) async {
  final backend = ref.read(socialBackendProvider);
  if (backend == null) throw const SocialUnavailable();
  if (blocked) {
    await backend.block(uid);
  } else {
    await backend.unblock(uid);
  }
  final names = await ref.read(socialBlockedNamesProvider.future);
  final next = {...names};
  if (blocked && name != null && name.isNotEmpty) {
    next[uid] = name;
  } else if (!blocked) {
    next.remove(uid);
  }
  if (!_sameNames(next, names)) {
    await ref.read(userRepositoryProvider).writeSetting(socialBlockedNamesKey, jsonEncode(next));
  }
  ref.invalidate(socialBlockedNamesProvider);
  ref.invalidate(socialBlockedProvider);
  ref.invalidate(socialGraphProvider);
  ref.invalidate(socialFollowingProvider);
  ref.invalidate(socialFeedProvider);
  ref.invalidate(socialSeriesPostsProvider);
  ref.invalidate(socialCommentsProvider);
  ref.invalidate(socialProfileProvider);
}

/// Segnala. Chi segnala non lo rilegge, e un rifiuto è `SocialRefused`.
Future<void> sendReport(WidgetRef ref, Report report) {
  final reports = ref.read(socialReportsProvider);
  if (reports == null) throw const SocialUnavailable();
  return reports.report(report);
}

/// Le conversazioni, la più recente per prima, con i non letti. Spento il
/// social o senza account non chiede niente.
final socialConversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final messages = ref.watch(socialMessagesProvider);
  ref.watch(socialMessagesTickProvider);
  if (messages == null || !await _enabled(ref)) return const [];
  return messages.conversations();
});

/// Annuncia i messaggi privati nuovi (`message_alerts.dart`). Una lettura che
/// fallisce non annuncia niente: il messaggio resta da annunciare. Non si sa
/// quale conversazione è aperta, quindi quella aperta può avere una notifica
/// prima che la schermata la segni letta.
Future<void> announceNewMessages(ProviderContainer ref, List<Conversation> conversations) async {
  try {
    final user = ref.read(userRepositoryProvider);
    final l10n = currentL10n();
    final alerts = messageAlerts(
      conversations: conversations,
      seen: await readMessagesSeen(user),
      settings: await ref.read(socialSettingsProvider.future),
      blocked: await ref.read(socialBlockedProvider.future),
      unknownName: l10n.messagesUnknownPerson,
    );
    await announceMessages(
      user,
      alerts,
      (a) => ArrivalNotifications.instance.message(a.peer, title: l10n.messageNotificationTitle(a.name), text: a.preview),
    );
  } on Object {
    // Un'impostazione o i blocchi non letti: niente notifica, non un errore.
  }
}

/// I messaggi non letti di tutte le conversazioni.
final socialUnreadProvider = Provider<int>(
  (ref) => ref.watch(socialConversationsProvider).value?.fold<int>(0, (sum, c) => sum + c.unread) ?? 0,
);

/// Una conversazione, il messaggio più recente per primo.
final socialThreadProvider = FutureProvider.family<List<Message>, String>((ref, peer) async {
  final messages = ref.watch(socialMessagesProvider);
  ref.watch(socialMessagesTickProvider);
  if (messages == null || !await _enabled(ref)) return const [];
  return messages.thread(peer);
});

/// Scrive, toglie e segna letti; poi le liste toccate si rileggono. Un
/// rifiuto delle regole arriva a chi chiama come `SocialRefused`.
class SocialMessagesController extends Notifier<void> {
  @override
  void build() {}

  SocialMessages get _messages => ref.read(socialMessagesProvider) ?? (throw const SocialUnavailable());

  void _reload(String peer) {
    ref.invalidate(socialConversationsProvider);
    ref.invalidate(socialThreadProvider(peer));
  }

  Future<void> send(String to, String body, {MessageKind kind = MessageKind.text, String? share}) async {
    await _messages.send(to, body, kind: kind, share: share);
    _reload(to);
  }

  Future<void> remove(Message message, String peer) async {
    await _messages.remove(message.id);
    _reload(peer);
  }

  /// Chi apre la conversazione ha letto ciò che c'è: se la scrittura fallisce
  /// i non letti restano, e si rifà alla prossima apertura.
  Future<void> markRead(String peer) async {
    try {
      await _messages.markRead(peer);
    } on Object {
      return;
    }
    ref.invalidate(socialConversationsProvider);
  }
}

final socialMessagesControllerProvider = NotifierProvider<SocialMessagesController, void>(SocialMessagesController.new);

/// «Chiedi più tempo»: scrive a chi condivide la libreria [share], con il nome
/// della cartella come testo (la frase la compone chi legge, nella sua lingua).
/// Senza `from_uid` la riga non dice a chi scrivere: `SocialUnavailable`.
Future<void> requestMoreTime(WidgetRef ref, DriveShare share) {
  final owner = share.fromUid;
  if (owner == null) throw const SocialUnavailable();
  return ref.read(socialMessagesControllerProvider.notifier).send(
        owner,
        share.folderName.isEmpty ? share.id : share.folderName,
        kind: MessageKind.extension,
        share: share.id,
      );
}
