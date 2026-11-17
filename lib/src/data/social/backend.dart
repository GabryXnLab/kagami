/// Ciò che il social chiede al backend. L'app parla con queste interfacce,
/// non con le tabelle: sul backend di chi compila le realizza `HestiaSocial`,
/// nei test `MemorySocial`. Contratto e regole in `docs/social.md`.
///
/// Tre stati valgono per ogni lettura: una che fallisce lancia, e non torna
/// mai una lista vuota o `null`. `null` e vuoto vogliono dire che il backend
/// ha risposto.
library;

import 'content.dart';
import 'profile.dart';

/// Il backend non ha il social (schema non applicato): la sezione lo dice, e
/// non riprova a ogni avvio. Si decide **leggendo**: una tabella assente o
/// non concessa a una lettura.
class SocialUnavailable implements Exception {
  const SocialUnavailable();
}

/// Il backend ha rifiutato una **scrittura** che le regole non ammettono:
/// l'altro ti ha bloccato, non accetta messaggi, hai superato un limite.
/// Sul filo è lo stesso `42501` di una tabella non concessa, per questo si
/// distingue dall'operazione: una scrittura rifiutata dove le letture
/// funzionano è questo, non [SocialUnavailable]. L'interfaccia non dice
/// quale regola: «non è stato possibile», senza rivelare un blocco.
class SocialRefused implements Exception {
  const SocialRefused();
}

enum Board { week, month, allTime, streak }

/// I miei legami: chi seguo, e chi mi segue col nome che aveva seguendomi
/// (di chi mi segue posso non vedere il profilo).
class SocialGraph {
  const SocialGraph({this.following = const {}, this.followers = const []});

  final Set<String> following;
  final List<SocialCard> followers;

  bool follows(String uid) => following.contains(uid);
  bool followedBy(String uid) => followers.any((card) => card.id == uid);
  bool mutual(String uid) => follows(uid) && followedBy(uid);
}

/// Profili, legami e blocchi: il nucleo, da cui dipende chi vede cosa.
abstract interface class SocialBackend {
  /// Scrive il proprio profilo, sostituendo quello di prima.
  Future<void> publish(PublicProfile profile);

  /// Esce: toglie il profilo e, con lui, tutto ciò che è suo sulla rete —
  /// post, commenti, mi piace, legami, messaggi. Chi non c'era non è un
  /// errore.
  Future<void> withdraw();

  /// Un profilo. `null` se non c'è **o non lo si può vedere**: da fuori i due
  /// casi non si distinguono, apposta.
  Future<PublicProfile?> profile(String uid);

  /// I primi di una classifica, fra i profili che chi chiede può vedere.
  Future<List<PublicProfile>> board(Board board, {int limit = 50});

  /// Le persone il cui nome contiene [name], fra quelle visibili.
  Future<List<PublicProfile>> search(String name, {int limit = 20});

  /// I profili di [uids] che si possono vedere, in un colpo.
  Future<List<PublicProfile>> people(Iterable<String> uids);

  /// Segue [uid]. [name] è il proprio soprannome: chi è seguito lo legge
  /// dal legame, anche quando il profilo non gli è visibile.
  Future<void> follow(String uid, {required String name});
  Future<void> unfollow(String uid);

  /// Toglie [uid] da chi mi segue.
  Future<void> removeFollower(String uid);
  Future<SocialGraph> graph();

  /// Blocca [uid]: nessuno dei due vede più l'altro né gli scrive, e i
  /// legami fra i due cadono. L'altro non lo viene a sapere.
  Future<void> block(String uid);
  Future<void> unblock(String uid);
  Future<Set<String>> blocked();
}

enum FeedScope { everyone, following }

/// Post, commenti e mi piace.
abstract interface class SocialPosts {
  /// I post più recenti prima di [before], di tutti quelli visibili o solo
  /// di chi si segue.
  Future<List<Post>> feed(FeedScope scope, {DateTime? before, int limit = 30});

  /// I post su una serie (`seriesRef`).
  Future<List<Post>> about(String series, {DateTime? before, int limit = 30});
  Future<List<Post>> by(String uid, {DateTime? before, int limit = 30});
  Future<Post> publish(PostDraft draft);

  /// Toglie un proprio post, con commenti e mi piace.
  Future<void> remove(String postId);

  Future<List<Comment>> comments(String postId);
  Future<Comment> comment(
    String postId,
    String body, {
    String? parent,
    bool spoiler = false,
    num? chapter,
  });

  /// Toglie un commento: proprio, o sotto un proprio post.
  Future<void> removeComment(String commentId);

  Future<void> like({String? post, String? comment, required bool liked});
}

/// Messaggi privati fra due persone.
abstract interface class SocialMessages {
  /// Le conversazioni, la più recente per prima.
  Future<List<Conversation>> conversations();
  Future<List<Message>> thread(String peer, {DateTime? before, int limit = 50});
  Future<Message> send(
    String to,
    String body, {
    MessageKind kind = MessageKind.text,
    String? share,
  });

  /// Segna letti i messaggi ricevuti da [peer].
  Future<void> markRead(String peer);

  /// Toglie un messaggio, per tutti e due.
  Future<void> remove(String messageId);

  /// Un evento quando può essere arrivato un messaggio. È un di più: se il
  /// canale non si apre tace, e restano le riletture.
  Stream<void> changes();
}

abstract interface class SocialReports {
  /// Segnala. Chi segnala non rilegge le sue segnalazioni: le legge chi
  /// gestisce il backend.
  Future<void> report(Report report);
}
