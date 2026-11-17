/// [SocialMessages] sul backend di chi compila (tabella `messages` della
/// migrazione `backend/migrations/0005_social.sql`, realtime filtrato per
/// `recipient`).
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';
import 'backend.dart';
import 'content.dart';
import 'hestia_social.dart';

class HestiaMessages implements SocialMessages {
  HestiaMessages({this.client});

  final SupabaseClient? client;

  /// Come in `HestiaPosts`: senza sessione ogni risposta sarebbe un `42501`.
  SupabaseClient _session() {
    final active = client ?? backend;
    if (active == null || active.auth.currentSession == null) throw AuthSessionMissingException();
    return active;
  }

  String _me(SupabaseClient client) => client.auth.currentUser?.id ?? (throw AuthSessionMissingException());

  /// Quante righe recenti si leggono per comporre l'elenco: i non letti e
  /// l'ultimo messaggio di ogni conversazione vengono da qui.
  static const int _window = 400;

  @override
  Future<List<Conversation>> conversations() => guardSocialRead(() async {
        final client = _session();
        final me = _me(client);
        final rows = await client
            .from('messages')
            .select()
            .or('sender.eq.$me,recipient.eq.$me')
            .order('at')
            .limit(_window);
        final last = <String, Message>{};
        final unread = <String, int>{};
        for (final row in rows) {
          final message = messageFromRow(row);
          final peer = message.peer(me);
          last.putIfAbsent(peer, () => message);
          if (message.to == me && message.readAt == null) unread[peer] = (unread[peer] ?? 0) + 1;
        }
        // Un profilo che non si vede più non torna: la conversazione resta col solo `uid`.
        final cards = last.isEmpty
            ? const <String, SocialCard>{}
            : {
                for (final row in await client.from('profiles').select('id, name, photo').inFilter('id', last.keys.toList()))
                  row['id'] as String: SocialCard.fromRow(row),
              };
        return [
          for (final entry in last.entries)
            (peer: entry.key, card: cards[entry.key], last: entry.value, unread: unread[entry.key] ?? 0),
        ];
      });

  @override
  Future<List<Message>> thread(String peer, {DateTime? before, int limit = 50}) => guardSocialRead(() async {
        final client = _session();
        final me = _me(client);
        var query = client
            .from('messages')
            .select()
            .or('and(sender.eq.$me,recipient.eq.$peer),and(sender.eq.$peer,recipient.eq.$me)');
        if (before != null) query = query.lt('at', before.toUtc().toIso8601String());
        return [for (final row in await query.order('at').limit(limit)) messageFromRow(row)];
      });

  @override
  Future<Message> send(String to, String body, {MessageKind kind = MessageKind.text, String? share}) =>
      guardSocialWrite(() async {
        final client = _session();
        final row = await client
            .from('messages')
            .insert({'sender': _me(client), 'recipient': to, 'kind': kind.name, 'body': body.trim(), 'share': share})
            .select()
            .single();
        return messageFromRow(row);
      });

  @override
  Future<void> markRead(String peer) => guardSocialWrite(() async {
        final client = _session();
        await client
            .from('messages')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('sender', peer)
            .eq('recipient', _me(client))
            .isFilter('read_at', null);
      });

  @override
  Future<void> remove(String messageId) => guardSocialWrite(() async {
        await _session().from('messages').delete().eq('id', messageId);
      });

  @override
  Stream<void> changes() {
    final active = client ?? backend;
    final me = active?.auth.currentUser?.id;
    if (active == null || active.auth.currentSession == null || me == null) return const Stream.empty();
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        try {
          channel = active
              .channel('messages:$me')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'messages',
                filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'recipient', value: me),
                callback: (_) => controller.add(null),
              )
              .subscribe();
        } on Object {
          // Senza canale restano le riletture.
        }
      },
      onCancel: () async {
        final open = channel;
        if (open == null) return;
        try {
          await active.removeChannel(open);
        } on Object {
          // Già chiuso.
        }
      },
    );
    return controller.stream;
  }
}

Message messageFromRow(Map<String, dynamic> row) => Message(
      id: row['id'] as String,
      from: row['sender'] as String,
      to: row['recipient'] as String,
      kind: MessageKind.parse(row['kind']),
      body: row['body'] as String? ?? '',
      share: row['share'] as String?,
      at: DateTime.parse(row['at'] as String),
      readAt: row['read_at'] == null ? null : DateTime.parse(row['read_at'] as String),
    );
