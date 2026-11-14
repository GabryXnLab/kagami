/// [SocialPosts] in memoria, per i test: le regole di `posts`, `comments` e
/// `likes` di `docs/social.md` (si vede ciò di cui si vede l'autore, un
/// commento dove si vede il post, l'autore del post toglie i commenti, mi
/// piace solo su ciò che si vede, limiti), sopra la rete di un [MemorySocial].
library;

// Anche questa è solo per i test: sta sopra MemorySocial, che lo è.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'content.dart';
import 'memory_social.dart';
import 'profile.dart';

class _StoredPost {
  _StoredPost(this.id, this.author, this.draft, this.at);

  final String id;
  final String author;
  final PostDraft draft;
  final DateTime at;
  int flags = 0;
}

class _StoredComment {
  _StoredComment(this.id, this.post, this.author, this.authorName, this.parent, this.body, this.spoiler, this.chapter, this.at);

  final String id;
  final String post;
  final String author;

  /// Il soprannome di quando ha scritto, come `author_name` sul backend.
  final String authorName;
  final String? parent;
  final String body;
  final bool spoiler;
  final num? chapter;
  final DateTime at;
  int flags = 0;
}

class _Content {
  final List<_StoredPost> posts = [];
  final List<_StoredComment> comments = [];

  /// `uid` → id di post e commenti che gli piacciono.
  final Map<String, Set<String>> likes = {};
  int next = 0;
}

@visibleForTesting
class MemoryPosts implements SocialPosts {
  MemoryPosts(MemorySocial social, {DateTime Function()? clock}) : this._(social, _Content(), clock ?? DateTime.now, []);

  MemoryPosts._(this.social, this._content, this._clock, this.calls);

  /// Profili, legami e blocchi: decidono chi vede cosa.
  final MemorySocial social;
  final _Content _content;
  final DateTime Function() _clock;

  /// Ogni chiamata, per nome, di tutte le persone che condividono lo stato.
  final List<String> calls;

  /// Se impostato, ogni chiamata lo lancia.
  Object? failure;

  String get me => social.me;

  /// Un'altra persona sulla stessa rete.
  MemoryPosts as(String uid) => MemoryPosts._(social.as(uid), _content, _clock, calls);

  /// I post come sono salvati, di tutti.
  List<String> get postIds => [for (final post in _alive()) post.id];
  List<String> get commentIds => [for (final comment in _content.comments) comment.id];

  /// Le segnalazioni le conta il backend: qui le si impone.
  void flag(String id, int flags) {
    for (final post in _content.posts) {
      if (post.id == id) post.flags = flags;
    }
    for (final comment in _content.comments) {
      if (comment.id == id) comment.flags = flags;
    }
  }

  void _call(String name) {
    calls.add('$me $name');
    if (failure case final error?) throw error;
  }

  /// Uscire cancella i post a cascata: un autore senza profilo non ha più niente.
  Iterable<_StoredPost> _alive() => _content.posts.where((post) => social.profiles.containsKey(post.author));

  bool _on() => social.profiles.containsKey(me);

  _StoredPost? _visible(String postId) {
    if (!_on()) return null;
    for (final post in _alive()) {
      if (post.id == postId && social.sees(post.author)) return post;
    }
    return null;
  }

  int _likes(String id) => _content.likes.values.where((liked) => liked.contains(id)).length;
  bool _liked(String id) => _content.likes[me]?.contains(id) ?? false;

  Post _post(_StoredPost stored) {
    final author = social.profiles[stored.author];
    final draft = stored.draft;
    return Post(
      id: stored.id,
      author: SocialCard(id: stored.author, name: author?.name ?? '', photo: author?.photo),
      kind: draft.kind,
      body: draft.body.trim(),
      seriesTitle: draft.seriesTitle,
      rating: draft.kind == PostKind.review ? draft.rating : null,
      spoiler: draft.spoiler,
      chapter: draft.spoiler ? draft.chapter : null,
      at: stored.at,
      likes: _likes(stored.id),
      comments: _content.comments.where((comment) => comment.post == stored.id).length,
      flags: stored.flags,
      liked: _liked(stored.id),
    );
  }

  Comment _comment(_StoredComment stored) {
    // Come sul backend: il profilo di chi commenta può non essere visibile, e
    // allora resta il soprannome salvato sul commento.
    final author = social.sees(stored.author) ? social.profiles[stored.author] : null;
    return Comment(
      id: stored.id,
      post: stored.post,
      author: author == null
          ? SocialCard(id: stored.author, name: stored.authorName, closed: true)
          : SocialCard(id: stored.author, name: author.name, photo: author.photo),
      parent: stored.parent,
      body: stored.body,
      spoiler: stored.spoiler,
      chapter: stored.chapter,
      at: stored.at,
      likes: _likes(stored.id),
      flags: stored.flags,
      liked: _liked(stored.id),
    );
  }

  List<Post> _page(bool Function(_StoredPost post) wanted, DateTime? before, int limit) {
    if (!_on()) return const [];
    final rows = [
      for (final post in _alive())
        if (social.sees(post.author) && wanted(post) && (before == null || post.at.isBefore(before))) post,
    ]..sort((a, b) => b.at.compareTo(a.at));
    return [for (final post in rows.take(limit)) _post(post)];
  }

  @override
  Future<List<Post>> feed(FeedScope scope, {DateTime? before, int limit = 30}) async {
    _call('feed');
    return _page(
      (post) => scope == FeedScope.everyone || (social.follows[me]?.containsKey(post.author) ?? false),
      before,
      limit,
    );
  }

  @override
  Future<List<Post>> about(String series, {DateTime? before, int limit = 30}) async {
    _call('about $series');
    return _page((post) => post.draft.seriesTitle != null && seriesRef(post.draft.seriesTitle!) == series, before, limit);
  }

  @override
  Future<List<Post>> by(String uid, {DateTime? before, int limit = 30}) async {
    _call('by');
    return _page((post) => post.author == uid, before, limit);
  }

  @override
  Future<Post> publish(PostDraft draft) async {
    _call('publish');
    final now = _clock();
    final today = _content.posts.where((post) => post.author == me && now.difference(post.at) < const Duration(days: 1));
    if (!_on() || today.length >= 20) throw const SocialRefused();
    // I CHECK della tabella: una riga fuori forma non entra.
    final text = draft.body.trim();
    if (text.isEmpty || text.runes.length > SocialLimits.post) throw ArgumentError('body');
    if (draft.kind != PostKind.note && draft.seriesTitle == null) throw ArgumentError('series');
    if (draft.kind == PostKind.review && draft.rating == null) throw ArgumentError('rating');
    final stored = _StoredPost('p${_content.next++}', me, draft, now);
    _content.posts.add(stored);
    return _post(stored);
  }

  @override
  Future<void> remove(String postId) async {
    _call('remove');
    final gone = {
      for (final post in _content.posts)
        if (post.id == postId && post.author == me) post.id,
    };
    _content.posts.removeWhere((post) => gone.contains(post.id));
    _drop(_content.comments.where((comment) => gone.contains(comment.post)).map((comment) => comment.id).toSet());
    for (final liked in _content.likes.values) {
      liked.removeAll(gone);
    }
  }

  void _drop(Set<String> commentIds) {
    _content.comments.removeWhere((comment) => commentIds.contains(comment.id));
    for (final liked in _content.likes.values) {
      liked.removeAll(commentIds);
    }
  }

  @override
  Future<List<Comment>> comments(String postId) async {
    _call('comments');
    if (_visible(postId) == null) return const [];
    return [
      for (final comment in _content.comments)
        if (comment.post == postId && !social.blockedWith(comment.author)) _comment(comment),
    ];
  }

  @override
  Future<Comment> comment(String postId, String body, {String? parent, bool spoiler = false, num? chapter}) async {
    _call('comment');
    final now = _clock();
    final hour = _content.comments.where((c) => c.author == me && now.difference(c.at) < const Duration(hours: 1));
    if (_visible(postId) == null || hour.length >= 60) throw const SocialRefused();
    final text = body.trim();
    if (text.isEmpty || text.runes.length > 1000) throw ArgumentError('body');
    // La chiave (parent, post): una risposta sta sotto lo stesso post.
    if (parent != null && !_content.comments.any((c) => c.id == parent && c.post == postId)) {
      throw ArgumentError('parent');
    }
    final stored = _StoredComment(
        'c${_content.next++}', postId, me, social.profiles[me]?.name ?? '', parent, text, spoiler, spoiler ? chapter : null, now);
    _content.comments.add(stored);
    return _comment(stored);
  }

  @override
  Future<void> removeComment(String commentId) async {
    _call('removeComment');
    final target = _content.comments.where((c) => c.id == commentId).firstOrNull;
    if (target == null) return;
    final postAuthor = _content.posts.where((post) => post.id == target.post).firstOrNull?.author;
    if (target.author != me && postAuthor != me) return;
    // Le risposte cadono col commento (chiave esterna a cascata).
    _drop({commentId, for (final c in _content.comments) if (c.parent == commentId) c.id});
  }

  @override
  Future<void> like({String? post, String? comment, required bool liked}) async {
    _call('like');
    final id = post ?? comment!;
    if (!liked) {
      _content.likes[me]?.remove(id);
      return;
    }
    final visible = post != null
        ? _visible(post) != null
        : _content.comments.any((c) => c.id == comment && _visible(c.post) != null);
    if (!visible) throw const SocialRefused();
    (_content.likes[me] ??= {}).add(id);
  }
}
