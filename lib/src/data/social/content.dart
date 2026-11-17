/// Ciò che le persone scrivono nel social: post, commenti, messaggi e
/// segnalazioni. Contratto in `docs/social.md`.
library;

import 'profile.dart';

/// Chi ha scritto, come lo si mostra: il minimo di un profilo. Arriva con
/// ogni post e commento, perché chi vede un contenuto vede chi l'ha scritto.
class SocialCard {
  const SocialCard({required this.id, required this.name, this.photo, this.closed = false});

  factory SocialCard.fromRow(Map<String, Object?> row) => SocialCard(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        photo: row['photo'] as String?,
      );

  final String id;
  final String name;
  final String? photo;

  /// Un profilo che chi guarda non può vedere: [name] è il soprannome salvato
  /// sul commento (migrazione 0006), senza foto, e toccarlo non apre niente.
  final bool closed;
}

enum PostKind {
  /// Un pensiero, su una serie o no.
  note,

  /// Su una serie, con un voto.
  review,

  /// Su una serie: «leggetela».
  recommendation;

  static PostKind parse(Object? value) => values.asNameMap()[value] ?? PostKind.note;
}

/// Ciò che può rovinare una lettura: un contenuto con [spoiler] si mostra
/// coperto finché chi legge non c'è arrivato.
mixin Spoilable {
  bool get spoiler;

  /// Fino a quale capitolo racconta, se chi scrive l'ha detto.
  num? get chapter;

  /// Se va coperto per chi ha letto fino a [progress] di quella serie
  /// (`null`: non ce l'ha, o non si sa). Senza capitolo dichiarato un avviso
  /// vale per tutti: non si può sapere quanto racconta.
  bool concealedFor(num? progress) =>
      spoiler && (chapter == null || progress == null || progress < chapter!);
}

class Post with Spoilable {
  const Post({
    required this.id,
    required this.author,
    required this.body,
    required this.at,
    this.kind = PostKind.note,
    this.seriesTitle,
    this.rating,
    this.spoiler = false,
    this.chapter,
    this.likes = 0,
    this.comments = 0,
    this.flags = 0,
    this.liked = false,
  });

  final String id;
  final SocialCard author;
  final PostKind kind;
  final String body;

  /// La serie di cui parla, col titolo di chi scrive. Due post parlano della
  /// stessa serie se hanno lo stesso [seriesRef].
  final String? seriesTitle;

  /// Il voto, nella scala dell'app. Solo per [PostKind.review].
  final int? rating;
  @override
  final bool spoiler;
  @override
  final num? chapter;
  final DateTime at;

  /// Li conta il backend.
  final int likes;
  final int comments;

  /// Quante persone diverse l'hanno segnalato: da [flagged] in su si mostra
  /// coperto, con un tocco per vederlo.
  final int flags;

  /// Se piace a chi guarda.
  final bool liked;

  static const int flagged = 3;

  String? get series => seriesTitle == null ? null : seriesRef(seriesTitle!);
}

/// Un post da pubblicare. [seriesKey] è la chiave nella libreria di chi
/// scrive, e non esce: serve a rifiutare qui una serie nascosta.
class PostDraft {
  const PostDraft({
    required this.body,
    this.kind = PostKind.note,
    this.seriesKey,
    this.seriesTitle,
    this.rating,
    this.spoiler = false,
    this.chapter,
  });

  final String body;
  final PostKind kind;
  final String? seriesKey;
  final String? seriesTitle;
  final int? rating;
  final bool spoiler;
  final num? chapter;

  /// Perché non si può pubblicare, o `null`. Una serie nascosta non si
  /// nomina, nemmeno per scelta: chi la vuole mostrare la toglie prima dalle
  /// nascoste.
  PostRefusal? refusal({required Set<String> hidden}) {
    final text = body.trim();
    if (text.isEmpty) return PostRefusal.empty;
    if (text.runes.length > SocialLimits.post) return PostRefusal.tooLong;
    if (seriesKey != null && hidden.contains(seriesKey)) return PostRefusal.hiddenSeries;
    if (kind != PostKind.note && seriesTitle == null) return PostRefusal.needsSeries;
    if (kind == PostKind.review && rating == null) return PostRefusal.needsRating;
    return null;
  }
}

enum PostRefusal { empty, tooLong, hiddenSeries, needsSeries, needsRating }

class Comment with Spoilable {
  const Comment({
    required this.id,
    required this.post,
    required this.author,
    required this.body,
    required this.at,
    this.parent,
    this.spoiler = false,
    this.chapter,
    this.likes = 0,
    this.flags = 0,
    this.liked = false,
  });

  final String id;
  final String post;
  final SocialCard author;

  /// Il commento a cui risponde. Un solo livello: la risposta a una risposta
  /// si attacca allo stesso commento.
  final String? parent;
  final String body;
  @override
  final bool spoiler;
  @override
  final num? chapter;
  final DateTime at;
  final int likes;
  final int flags;
  final bool liked;
}

enum MessageKind {
  text,

  /// Chi legge una libreria condivisa chiede più tempo a chi la condivide
  /// (`docs/drive.md`): [Message.share] dice quale condivisione.
  extension;

  static MessageKind parse(Object? value) => values.asNameMap()[value] ?? MessageKind.text;
}

class Message {
  const Message({
    required this.id,
    required this.from,
    required this.to,
    required this.body,
    required this.at,
    this.kind = MessageKind.text,
    this.share,
    this.readAt,
  });

  final String id;
  final String from;
  final String to;
  final MessageKind kind;
  final String body;

  /// L'`id` della riga `drive_shares`, per [MessageKind.extension].
  final String? share;
  final DateTime at;
  final DateTime? readAt;

  /// L'altra persona della conversazione, per [me].
  String peer(String me) => from == me ? to : from;
}

/// Una conversazione: l'altra persona, l'ultimo messaggio e quanti non letti.
///
/// `card` manca se il profilo dell'altro non si vede più: la conversazione
/// resta, col solo identificativo.
typedef Conversation = ({String peer, SocialCard? card, Message last, int unread});

enum ReportReason { spam, harassment, spoiler, inappropriate, other }

enum ReportTarget { user, post, comment, message }

/// Una segnalazione. Porta con sé una copia del testo ([snapshot]): chi ha
/// scritto può cancellare, e la segnalazione deve restare leggibile.
class Report {
  const Report({
    required this.target,
    required this.user,
    required this.reason,
    this.targetId,
    this.note = '',
    this.snapshot = '',
  });

  final ReportTarget target;

  /// La persona segnalata.
  final String user;

  /// Il contenuto, se non è la persona.
  final String? targetId;
  final ReportReason reason;
  final String note;
  final String snapshot;
}
