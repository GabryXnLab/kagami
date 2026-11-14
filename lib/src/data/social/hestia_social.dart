/// [SocialBackend] sul backend di chi compila (PostgREST, tabelle della
/// migrazione `backend/migrations/0005_social.sql`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';
import 'backend.dart';
import 'content.dart';
import 'profile.dart';

/// Una lettura: tabella assente o non concessa vuol dire che il backend non
/// ha il social.
Future<T> guardSocialRead<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on Object catch (error) {
    if (backendFailure(error) == BackendFailure.unavailable) throw const SocialUnavailable();
    rethrow;
  }
}

/// Una scrittura: `42501` è una regola che non la ammette (blocco, limite,
/// messaggi non accettati); una tabella che non c'è resta «non disponibile».
Future<T> guardSocialWrite<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on PostgrestException catch (error) {
    if (error.code == '42501') throw const SocialRefused();
    if (backendFailure(error) == BackendFailure.unavailable) throw const SocialUnavailable();
    rethrow;
  }
}

class HestiaSocial implements SocialBackend {
  HestiaSocial({this.client, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SupabaseClient? client;
  final DateTime Function() _clock;

  /// Senza sessione il backend risponde `42501` a tutto, che sembrerebbe un
  /// social assente: come in `SupabaseShareDirectory`, si ferma prima.
  SupabaseClient _session() {
    final active = client ?? backend;
    if (active == null || active.auth.currentSession == null) throw AuthSessionMissingException();
    return active;
  }

  String _me(SupabaseClient client) => client.auth.currentUser?.id ?? (throw AuthSessionMissingException());

  List<PublicProfile> _profiles(List<Map<String, dynamic>> rows) => [for (final row in rows) PublicProfile.fromRow(row)];

  @override
  Future<void> publish(PublicProfile profile) => guardSocialWrite(() async {
        await _session().from('profiles').upsert(profile.toRow());
      });

  @override
  Future<void> withdraw() => guardSocialWrite(() async {
        final client = _session();
        await client.from('profiles').delete().eq('id', _me(client));
      });

  @override
  Future<PublicProfile?> profile(String uid) => guardSocialRead(() async {
        // Una lista e non maybeSingle: così un rifiuto arriva col suo codice.
        final rows = await _session().from('profiles').select().eq('id', uid).limit(1);
        return rows.isEmpty ? null : PublicProfile.fromRow(rows.first);
      });

  @override
  Future<List<PublicProfile>> board(Board board, {int limit = 50}) => guardSocialRead(() async {
        final rows = _session().from('profiles').select();
        final now = _clock();
        final ordered = switch (board) {
          Board.week => rows.eq('week_id', weekId(now)).order('week_chapters'),
          Board.month => rows.eq('month_id', monthId(now)).order('month_chapters'),
          Board.allTime => rows.order('total_chapters', nullsFirst: false),
          Board.streak => rows.order('streak_current', nullsFirst: false),
        };
        return _profiles(await ordered.limit(limit));
      });

  @override
  Future<List<PublicProfile>> search(String name, {int limit = 20}) => guardSocialRead(() async {
        final pattern = name.trim().replaceAllMapped(RegExp(r'[\\%_]'), (match) => '\\${match[0]}');
        return _profiles(await _session().from('profiles').select().ilike('name', '%$pattern%').order('name', ascending: true).limit(limit));
      });

  @override
  Future<List<PublicProfile>> people(Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    if (ids.isEmpty) return const [];
    return guardSocialRead(() async => _profiles(await _session().from('profiles').select().inFilter('id', ids)));
  }

  @override
  Future<void> follow(String uid, {required String name}) => guardSocialWrite(() async {
        final client = _session();
        final me = _me(client);
        try {
          await client.from('follows').insert({'follower': me, 'followee': uid, 'follower_name': name});
        } on PostgrestException catch (error) {
          // Già seguito: si aggiorna solo il nome (l'upsert riscriverebbe anche le
          // due persone, colonne che l'app non ha il permesso di cambiare).
          if (error.code != '23505') rethrow;
          await client.from('follows').update({'follower_name': name}).eq('follower', me).eq('followee', uid);
        }
      });

  @override
  Future<void> unfollow(String uid) => guardSocialWrite(() async {
        final client = _session();
        await client.from('follows').delete().eq('follower', _me(client)).eq('followee', uid);
      });

  @override
  Future<void> removeFollower(String uid) => guardSocialWrite(() async {
        final client = _session();
        await client.from('follows').delete().eq('follower', uid).eq('followee', _me(client));
      });

  @override
  Future<SocialGraph> graph() => guardSocialRead(() async {
        final client = _session();
        final me = _me(client);
        final rows = await client.from('follows').select().or('follower.eq.$me,followee.eq.$me');
        return SocialGraph(
          following: {
            for (final row in rows)
              if (row['follower'] == me) row['followee'] as String,
          },
          followers: [
            for (final row in rows)
              if (row['followee'] == me)
                SocialCard(id: row['follower'] as String, name: row['follower_name'] as String? ?? ''),
          ],
        );
      });

  @override
  Future<void> block(String uid) => guardSocialWrite(() async {
        final client = _session();
        try {
          await client.from('blocks').insert({'blocker': _me(client), 'blocked': uid});
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
        }
      });

  @override
  Future<void> unblock(String uid) => guardSocialWrite(() async {
        final client = _session();
        await client.from('blocks').delete().eq('blocker', _me(client)).eq('blocked', uid);
      });

  @override
  Future<Set<String>> blocked() => guardSocialRead(() async {
        final client = _session();
        final rows = await client.from('blocks').select('blocked').eq('blocker', _me(client));
        return {for (final row in rows) row['blocked'] as String};
      });
}
