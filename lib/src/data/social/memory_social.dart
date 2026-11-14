/// [SocialBackend] in memoria, per i test: le regole essenziali di
/// `docs/social.md` (chi vede cosa, blocco reciproco, uscita che lascia i
/// blocchi), su uno stato che più persone condividono con [MemorySocial.as].
library;

import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'content.dart';
import 'profile.dart';

class _Network {
  final Map<String, PublicProfile> profiles = {};

  /// follower → (followee → follower_name).
  final Map<String, Map<String, String>> follows = {};

  /// blocker → bloccati.
  final Map<String, Set<String>> blocks = {};
}

@visibleForTesting
class MemorySocial implements SocialBackend {
  MemorySocial(String me, {DateTime Function()? clock}) : this._(me, _Network(), clock ?? DateTime.now, []);

  MemorySocial._(this.me, this._network, this._clock, this.calls);

  /// Chi chiama: il suo `auth.uid()`.
  final String me;
  final _Network _network;
  final DateTime Function() _clock;

  /// Ogni chiamata, per nome, di tutte le persone che condividono lo stato.
  final List<String> calls;

  /// Se impostato, ogni chiamata lo lancia.
  Object? failure;

  /// Un'altra persona sulla stessa rete.
  MemorySocial as(String uid) => MemorySocial._(uid, _network, _clock, calls);

  Map<String, PublicProfile> get profiles => _network.profiles;
  Map<String, Map<String, String>> get follows => _network.follows;
  Map<String, Set<String>> get blocks => _network.blocks;

  void _call(String name) {
    calls.add('$me $name');
    if (failure case final error?) throw error;
  }

  bool _follows(String a, String b) => _network.follows[a]?.containsKey(b) ?? false;

  bool _blocked(String a, String b) =>
      (_network.blocks[a]?.contains(b) ?? false) || (_network.blocks[b]?.contains(a) ?? false);

  bool _sees(String owner) {
    if (owner == me) return true;
    final profile = _network.profiles[owner];
    if (profile == null || !_network.profiles.containsKey(me) || _blocked(me, owner)) return false;
    return switch (profile.audience) {
      SocialAudience.everyone => true,
      SocialAudience.following => _follows(owner, me),
      SocialAudience.mutual => _follows(owner, me) && _follows(me, owner),
    };
  }

  /// `kagami_sees(owner)` per chi chiama: serve anche a `MemoryPosts`.
  bool sees(String owner) => _sees(owner);

  /// `kagami_blocked(me, uid)`, in un verso o nell'altro.
  bool blockedWith(String uid) => _blocked(me, uid);

  List<PublicProfile> _visible() => [
        for (final profile in _network.profiles.values)
          if (_sees(profile.id)) profile,
      ];

  @override
  Future<void> publish(PublicProfile profile) async {
    _call('publish');
    if (profile.id != me) throw const SocialRefused();
    _network.profiles[me] = profile;
  }

  @override
  Future<void> withdraw() async {
    _call('withdraw');
    _network.profiles.remove(me);
    _network.follows.remove(me);
    for (final followed in _network.follows.values) {
      followed.remove(me);
    }
  }

  @override
  Future<PublicProfile?> profile(String uid) async {
    _call('profile');
    return _sees(uid) ? _network.profiles[uid] : null;
  }

  @override
  Future<List<PublicProfile>> board(Board board, {int limit = 50}) async {
    _call('board');
    final now = _clock();
    final rows = switch (board) {
      Board.week => [for (final p in _visible()) if (p.weekId == weekId(now)) p]
        ..sort((a, b) => b.weekChapters.compareTo(a.weekChapters)),
      Board.month => [for (final p in _visible()) if (p.monthId == monthId(now)) p]
        ..sort((a, b) => b.monthChapters.compareTo(a.monthChapters)),
      Board.allTime => _visible()..sort((a, b) => b.chapters.compareTo(a.chapters)),
      Board.streak => _visible()..sort((a, b) => b.streak.compareTo(a.streak)),
    };
    return rows.take(limit).toList();
  }

  @override
  Future<List<PublicProfile>> search(String name, {int limit = 20}) async {
    _call('search');
    final wanted = name.trim().toLowerCase();
    return [
      for (final profile in _visible())
        if (profile.name.toLowerCase().contains(wanted)) profile,
    ].take(limit).toList();
  }

  @override
  Future<List<PublicProfile>> people(Iterable<String> uids) async {
    _call('people');
    return [
      for (final uid in uids.toSet())
        if (_sees(uid) && _network.profiles[uid] != null) _network.profiles[uid]!,
    ];
  }

  @override
  Future<void> follow(String uid, {required String name}) async {
    _call('follow');
    final mine = _network.follows[me] ?? {};
    if (!_network.profiles.containsKey(me) ||
        !_network.profiles.containsKey(uid) ||
        uid == me ||
        _blocked(me, uid) ||
        (!mine.containsKey(uid) && mine.length >= SocialLimits.following)) {
      throw const SocialRefused();
    }
    _network.follows[me] = mine..[uid] = name;
  }

  @override
  Future<void> unfollow(String uid) async {
    _call('unfollow');
    _network.follows[me]?.remove(uid);
  }

  @override
  Future<void> removeFollower(String uid) async {
    _call('removeFollower');
    _network.follows[uid]?.remove(me);
  }

  @override
  Future<SocialGraph> graph() async {
    _call('graph');
    if (!_network.profiles.containsKey(me)) return const SocialGraph();
    return SocialGraph(
      following: {...?_network.follows[me]?.keys},
      followers: [
        for (final MapEntry(key: follower, value: followed) in _network.follows.entries)
          if (followed[me] case final name?) SocialCard(id: follower, name: name),
      ],
    );
  }

  @override
  Future<void> block(String uid) async {
    _call('block');
    if (!_network.profiles.containsKey(me) || uid == me) throw const SocialRefused();
    (_network.blocks[me] ??= {}).add(uid);
    _network.follows[me]?.remove(uid);
    _network.follows[uid]?.remove(me);
  }

  @override
  Future<void> unblock(String uid) async {
    _call('unblock');
    if (!_network.profiles.containsKey(me)) return;
    _network.blocks[me]?.remove(uid);
  }

  @override
  Future<Set<String>> blocked() async {
    _call('blocked');
    if (!_network.profiles.containsKey(me)) return const {};
    return {...?_network.blocks[me]};
  }
}
