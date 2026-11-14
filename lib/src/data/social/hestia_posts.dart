/// [SocialPosts] sul backend di chi compila (PostgREST, tabelle `posts`,
/// `comments`, `likes` e vista `following_posts` della migrazione
/// `backend/migrations/0005_social.sql`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';
import 'backend.dart';
import 'content.dart';
import 'hestia_social.dart';
import 'profile.dart';

class HestiaPosts implements SocialPosts {
  HestiaPosts({this.client});

  final SupabaseClient? client;

  /// Come in `HestiaSocial`: senza sessione ogni risposta sarebbe un `42501`
  /// che sembra un social assente.
  SupabaseClient _session() {
    final active = client ?? backend;
    if (active == null || active.auth.currentSession == null) throw AuthSessionMissingException();
    return active;
  }

  String _me(SupabaseClient client) => client.auth.currentUser?.id ?? (throw AuthSessionMissingException());

  /// Chi ha scritto, in una lettura sola. Un autore il cui profilo non si
  /// vede (può succedere a chi commenta in casa d'altri) resta col solo `uid`.
  Future<Map<String, SocialCard>> _cards(SupabaseClient client, Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await client.from('profiles').select('id, name, photo').inFilter('id', ids);
    return {for (final row in rows) row['id'] as String: SocialCard.fromRow(row)};
  }

  /// Gli oggetti fra [ids] a cui ho messo mi piace.
  Future<Set<String>> _liked(SupabaseClient client, String column, List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await client.from('likes').select(column).eq('uid', _me(client)).inFilter(column, ids);
    return {for (final row in rows) row[column] as String};
  }

  Future<List<Post>> _posts(SupabaseClient client, List<Map<String, dynamic>> rows) async {
    final cards = await _cards(client, rows.map((row) => row['author'] as String));
    final liked = await _liked(client, 'post', [for (final row in rows) row['id'] as String]);
    return [for (final row in rows) _post(row, cards, liked)];
  }

  Future<List<Post>> _page(
    String table, {
    String? column,
    String? value,
    DateTime? before,
    required int limit,
  }) =>
      guardSocialRead(() async {
        final client = _session();
        var query = client.from(table).select();
        if (column != null) query = query.eq(column, value!);
        if (before != null) query = query.lt('at', before.toUtc().toIso8601String());
        return _posts(client, await query.order('at').limit(limit));
      });

  @override
  Future<List<Post>> feed(FeedScope scope, {DateTime? before, int limit = 30}) => _page(
        scope == FeedScope.following ? 'following_posts' : 'posts',
        before: before,
        limit: limit,
      );

  @override
  Future<List<Post>> about(String series, {DateTime? before, int limit = 30}) =>
      _page('posts', column: 'series_ref', value: series, before: before, limit: limit);

  @override
  Future<List<Post>> by(String uid, {DateTime? before, int limit = 30}) =>
      _page('posts', column: 'author', value: uid, before: before, limit: limit);

  @override
  Future<Post> publish(PostDraft draft) => guardSocialWrite(() async {
        final client = _session();
        final title = draft.seriesTitle;
        final row = await client
            .from('posts')
            .insert({
              'author': _me(client),
              'kind': draft.kind.name,
              'body': draft.body.trim(),
              'series_ref': title == null ? null : seriesRef(title),
              'series_title': title,
              'rating': draft.kind == PostKind.review ? draft.rating : null,
              'spoiler': draft.spoiler,
              'chapter': draft.spoiler ? draft.chapter : null,
            })
            .select()
            .single();
        return _post(row, await _cards(client, [row['author'] as String]), const {});
      });

  @override
  Future<void> remove(String postId) => guardSocialWrite(() async {
        await _session().from('posts').delete().eq('id', postId);
      });

  @override
  Future<List<Comment>> comments(String postId) => guardSocialRead(() async {
        final client = _session();
        final rows = await client.from('comments').select().eq('post', postId).order('at', ascending: true);
        final cards = await _cards(client, rows.map((row) => row['author'] as String));
        final liked = await _liked(client, 'comment', [for (final row in rows) row['id'] as String]);
        return [for (final row in rows) _comment(row, cards, liked)];
      });

  @override
  Future<Comment> comment(String postId, String body, {String? parent, bool spoiler = false, num? chapter}) =>
      guardSocialWrite(() async {
        final client = _session();
        final row = await client
            .from('comments')
            .insert({
              'post': postId,
              'author': _me(client),
              'parent': parent,
              'body': body.trim(),
              'spoiler': spoiler,
              'chapter': spoiler ? chapter : null,
            })
            .select()
            .single();
        return _comment(row, await _cards(client, [row['author'] as String]), const {});
      });

  @override
  Future<void> removeComment(String commentId) => guardSocialWrite(() async {
        await _session().from('comments').delete().eq('id', commentId);
      });

  @override
  Future<void> like({String? post, String? comment, required bool liked}) => guardSocialWrite(() async {
        assert((post == null) != (comment == null));
        final client = _session();
        final me = _me(client);
        final (column, id) = post != null ? ('post', post) : ('comment', comment!);
        if (!liked) {
          await client.from('likes').delete().eq('uid', me).eq(column, id);
          return;
        }
        try {
          await client.from('likes').insert({'uid': me, column: id});
        } on PostgrestException catch (error) {
          // Piaceva già: è lo stato che si voleva.
          if (error.code != '23505') rethrow;
        }
      });
}

SocialCard _card(Map<String, SocialCard> cards, Map<String, dynamic> row) {
  final author = row['author'] as String;
  return cards[author] ?? SocialCard(id: author, name: '');
}

/// Chi commenta in casa d'altri può avere un profilo chiuso a chi legge: resta
/// il soprannome che il backend ha salvato sul commento quando l'ha scritto.
SocialCard _commentAuthor(Map<String, SocialCard> cards, Map<String, dynamic> row) {
  final author = row['author'] as String;
  return cards[author] ?? SocialCard(id: author, name: row['author_name'] as String? ?? '', closed: true);
}

num? _num(Object? value) => value is num ? value : num.tryParse('${value ?? ''}');

Post _post(Map<String, dynamic> row, Map<String, SocialCard> cards, Set<String> liked) => Post(
      id: row['id'] as String,
      author: _card(cards, row),
      kind: PostKind.parse(row['kind']),
      body: row['body'] as String? ?? '',
      seriesTitle: row['series_title'] as String?,
      rating: (row['rating'] as num?)?.toInt(),
      spoiler: row['spoiler'] == true,
      chapter: _num(row['chapter']),
      at: DateTime.parse(row['at'] as String),
      likes: (row['likes'] as num?)?.toInt() ?? 0,
      comments: (row['comments'] as num?)?.toInt() ?? 0,
      flags: (row['flags'] as num?)?.toInt() ?? 0,
      liked: liked.contains(row['id']),
    );

Comment _comment(Map<String, dynamic> row, Map<String, SocialCard> cards, Set<String> liked) => Comment(
      id: row['id'] as String,
      post: row['post'] as String,
      author: _commentAuthor(cards, row),
      parent: row['parent'] as String?,
      body: row['body'] as String? ?? '',
      spoiler: row['spoiler'] == true,
      chapter: _num(row['chapter']),
      at: DateTime.parse(row['at'] as String),
      likes: (row['likes'] as num?)?.toInt() ?? 0,
      flags: (row['flags'] as num?)?.toInt() ?? 0,
      liked: liked.contains(row['id']),
    );
