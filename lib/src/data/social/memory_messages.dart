/// [SocialMessages] in memoria, per i test: le regole di `messages` di
/// `docs/social.md` (chi mi accetta, si risponde sempre a chi ha scritto, la
/// proroga solo con la riga `drive_shares` giusta e una al giorno, 60 l'ora,
/// `read_at` solo del destinatario), sopra un [MemorySocial].
library;

// Anche questa è solo per i test: sta sopra MemorySocial, che lo è.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'content.dart';
import 'memory_social.dart';
import 'profile.dart';

class _Mail {
  final List<Message> messages = [];

  /// `id` della condivisione → (chi condivide, indirizzo di chi la riceve).
  final Map<String, ({String from, String toEmail})> shares = {};

  /// `uid` → indirizzo dell'account (`kagami_me()`).
  final Map<String, String> emails = {};
  final StreamController<String> arrivals = StreamController<String>.broadcast();
  int next = 0;
}

@visibleForTesting
class MemoryMessages implements SocialMessages {
  MemoryMessages(MemorySocial social, {DateTime Function()? clock}) : this._(social, _Mail(), clock ?? DateTime.now, []);

  MemoryMessages._(this.social, this._mail, this._clock, this.calls);

  final MemorySocial social;
  final _Mail _mail;
  final DateTime Function() _clock;

  /// Ogni chiamata, per nome, di tutte le persone che condividono lo stato.
  final List<String> calls;

  /// Se impostato, ogni chiamata lo lancia.
  Object? failure;

  String get me => social.me;

  MemoryMessages as(String uid) => MemoryMessages._(social.as(uid), _mail, _clock, calls);

  /// La riga `drive_shares` [id]: [from] condivide con l'account che ha [toEmail].
  void addShare(String id, {required String from, required String toEmail}) =>
      _mail.shares[id] = (from: from, toEmail: toEmail.toLowerCase());

  void setEmail(String uid, String email) => _mail.emails[uid] = email.toLowerCase();

  List<Message> get stored => List.unmodifiable(_mail.messages);

  void _call(String name) {
    calls.add('$me $name');
    if (failure case final error?) throw error;
  }

  /// `kagami_accepts(to)`.
  bool _accepts(String to) {
    final policy = social.profiles[to]?.messages ?? MessagePolicy.nobody;
    final follows = social.follows;
    final bool byPolicy = switch (policy) {
      MessagePolicy.everyone => true,
      MessagePolicy.following => follows[to]?.containsKey(me) ?? false,
      MessagePolicy.mutual => (follows[to]?.containsKey(me) ?? false) && (follows[me]?.containsKey(to) ?? false),
      MessagePolicy.nobody => false,
    };
    return byPolicy || _mail.messages.any((m) => m.from == to && m.to == me);
  }

  @override
  Future<List<Conversation>> conversations() async {
    _call('conversations');
    final last = <String, Message>{};
    final unread = <String, int>{};
    for (final m in _mail.messages.where((m) => m.from == me || m.to == me)) {
      final peer = m.peer(me);
      if (last[peer] == null || m.at.isAfter(last[peer]!.at)) last[peer] = m;
      if (m.to == me && m.readAt == null) unread[peer] = (unread[peer] ?? 0) + 1;
    }
    final list = [
      for (final entry in last.entries)
        (
          peer: entry.key,
          card: social.sees(entry.key)
              ? SocialCard(id: entry.key, name: social.profiles[entry.key]!.name, photo: social.profiles[entry.key]!.photo)
              : null,
          last: entry.value,
          unread: unread[entry.key] ?? 0,
        ),
    ]..sort((a, b) => b.last.at.compareTo(a.last.at));
    return list;
  }

  @override
  Future<List<Message>> thread(String peer, {DateTime? before, int limit = 50}) async {
    _call('thread');
    final rows = [
      for (final m in _mail.messages)
        if (((m.from == me && m.to == peer) || (m.from == peer && m.to == me)) && (before == null || m.at.isBefore(before))) m,
    ]..sort((a, b) => b.at.compareTo(a.at));
    return rows.take(limit).toList();
  }

  @override
  Future<Message> send(String to, String body, {MessageKind kind = MessageKind.text, String? share}) async {
    _call('send');
    final now = _clock();
    final hour = _mail.messages.where((m) => m.from == me && now.difference(m.at) < const Duration(hours: 1));
    final profiles = social.profiles;
    if (!profiles.containsKey(me) || !profiles.containsKey(to) || to == me || social.blockedWith(to) || hour.length >= 60) {
      throw const SocialRefused();
    }
    final text = body.trim();
    if (text.isEmpty || text.runes.length > 2000) throw ArgumentError('body');
    if (kind == MessageKind.extension && share == null) throw ArgumentError('share');
    switch (kind) {
      case MessageKind.text:
        if (!_accepts(to)) throw const SocialRefused();
      case MessageKind.extension:
        final row = _mail.shares[share];
        if (row == null || row.from != to || row.toEmail != _mail.emails[me]) throw const SocialRefused();
        final today = _mail.messages.where(
          (m) => m.from == me && m.kind == kind && m.share == share && now.difference(m.at) < const Duration(days: 1),
        );
        if (today.isNotEmpty) throw const SocialRefused();
    }
    final message = Message(id: 'm${_mail.next++}', from: me, to: to, body: text, at: now, kind: kind, share: share);
    _mail.messages.add(message);
    _mail.arrivals.add(to);
    return message;
  }

  @override
  Future<void> markRead(String peer) async {
    _call('markRead');
    final now = _clock();
    final list = _mail.messages;
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (m.from == peer && m.to == me && m.readAt == null) {
        list[i] = Message(id: m.id, from: m.from, to: m.to, body: m.body, at: m.at, kind: m.kind, share: m.share, readAt: now);
      }
    }
  }

  @override
  Future<void> remove(String messageId) async {
    _call('remove');
    _mail.messages.removeWhere((m) => m.id == messageId && (m.from == me || m.to == me));
  }

  @override
  Stream<void> changes() => _mail.arrivals.stream.where((recipient) => recipient == me).map((_) {});
}
