/// Le notifiche locali dei messaggi privati nuovi, ad app aperta (nessun push:
/// `docs/social.md`). Cosa annunciare lo decide [messageAlerts], pura; di cosa
/// è già stato annunciato si ricorda l'ultimo messaggio per conversazione.
library;

import 'dart:convert';

import '../user_repository.dart';
import 'content.dart';
import 'profile.dart';

const String messagesSeenKey = 'social.messages.seen';

/// Un'anteprima più lunga di così non entra nella notifica.
const int messagePreviewLength = 80;

typedef MessageAlert = ({String peer, String name, String preview, String messageId});

/// Le conversazioni da annunciare: con non letti, l'ultimo messaggio dell'altro
/// non ancora annunciato ([seen], peer → id del messaggio), e solo se il
/// social è acceso, ricevo messaggi e il mittente non è bloccato né silenziato.
List<MessageAlert> messageAlerts({
  required List<Conversation> conversations,
  required Map<String, String> seen,
  required SocialSettings settings,
  required Set<String> blocked,
  required String unknownName,
}) {
  if (!settings.enabled || settings.messages == MessagePolicy.nobody) return const [];
  return [
    for (final c in conversations)
      if (c.unread > 0 &&
          c.last.from == c.peer &&
          seen[c.peer] != c.last.id &&
          !blocked.contains(c.peer) &&
          !settings.muted.contains(c.peer))
        (
          peer: c.peer,
          name: c.card?.name.isNotEmpty == true ? c.card!.name : unknownName,
          preview: _preview(c.last.body),
          messageId: c.last.id,
        ),
  ];
}

String _preview(String body) {
  final line = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return line.length <= messagePreviewLength ? line : '${line.substring(0, messagePreviewLength - 1)}…';
}

Future<Map<String, String>> readMessagesSeen(UserRepository user) async {
  try {
    final decoded = jsonDecode(await user.readSetting(messagesSeenKey) ?? '{}');
    if (decoded is Map) return {for (final e in decoded.entries) if (e.value is String) '${e.key}': e.value as String};
  } on FormatException {
    // Un valore illeggibile vale «niente annunciato».
  }
  return const {};
}

/// Annuncia [alerts] una volta sola: l'ultimo id per conversazione sta fra le
/// impostazioni, così lo stesso messaggio non torna a ogni rilettura.
Future<void> announceMessages(
  UserRepository user,
  List<MessageAlert> alerts,
  Future<void> Function(MessageAlert alert) notify,
) async {
  if (alerts.isEmpty) return;
  final seen = {...await readMessagesSeen(user)};
  for (final alert in alerts) {
    await notify(alert);
    seen[alert.peer] = alert.messageId;
  }
  await user.writeSetting(messagesSeenKey, jsonEncode(seen));
}
