/// Post e commenti della Comunità: la scheda di un post, la scrittura, i
/// commenti con le risposte, i post su una serie. Contratto in
/// `docs/social.md`: un post non si modifica, le serie nascoste non escono.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library_view.dart';
import '../data/social/content.dart';
import '../data/social/profile.dart';
import '../l10n.dart';
import '../providers.dart';
import '../providers_social.dart';
import 'social_moderation.dart';
import 'social_profile_screen.dart';
import 'social_widgets.dart';
import 'theme.dart';
import 'widgets/kit.dart';

void _openProfile(BuildContext context, String uid) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SocialProfileScreen(uid: uid)),
    );

/// L'autore di un commento: il suo profilo, o, se a chi guarda è chiuso, solo
/// l'avviso (il soprannome sul commento non apre niente di più).
void _openAuthor(BuildContext context, SocialCard author) {
  if (!author.closed) return _openProfile(context, author.id);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.socialProfilePrivate)));
}

void _failed(BuildContext context) {
  // Un blocco, un limite e una rete che manca dicono la stessa cosa.
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.socialRefusedSnack)));
}

String _when(BuildContext context, DateTime at) =>
    DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(at.toLocal());

String _chapter(num chapter) => chapter.toString().replaceAll(RegExp(r'\.0$'), '');

String _name(BuildContext context, SocialCard card) => card.name.isEmpty ? context.l10n.socialUnknownReader : card.name;

/// Il velo sopra un contenuto coperto: spoiler o troppe segnalazioni.
class _Veil extends StatelessWidget {
  const _Veil({required this.title, required this.subtitle, required this.icon, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return KPress(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: KagamiType.title(13.5)),
            Text(subtitle, style: KagamiType.body(12.5, color: muted)),
          ]),
        ),
      ]),
    );
  }
}

/// Il testo di un post o di un commento, o il suo velo finché non lo si tocca.
class _Body extends StatefulWidget {
  const _Body({required this.content, required this.author, required this.flags, required this.progress, required this.text});

  final Spoilable content;
  final SocialCard author;
  final int flags;
  final num? progress;
  final String text;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = widget.content;
    if (!_shown && widget.flags >= Post.flagged) {
      return _Veil(
        icon: LucideIcons.flag,
        title: l10n.socialFlaggedTitle,
        subtitle: l10n.socialFlaggedReveal(_name(context, widget.author)),
        onTap: () => setState(() => _shown = true),
      );
    }
    if (!_shown && content.concealedFor(widget.progress)) {
      return _Veil(
        icon: LucideIcons.eyeOff,
        title: content.chapter == null ? l10n.socialSpoilerGeneric : l10n.socialSpoilerUpTo(_chapter(content.chapter!)),
        subtitle: l10n.socialSpoilerReveal,
        onTap: () => setState(() => _shown = true),
      );
    }
    return Text(widget.text, style: KagamiType.body(14.5));
  }
}

/// Il cuore con il conteggio: si aggiorna subito, e torna indietro se la
/// scrittura fallisce.
class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({required this.liked, required this.count, this.post, this.comment});

  final bool liked;
  final int count;
  final Post? post;
  final Comment? comment;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton> {
  late bool _liked = widget.liked;
  late int _count = widget.count;

  @override
  void didUpdateWidget(_LikeButton old) {
    super.didUpdateWidget(old);
    if (old.liked != widget.liked || old.count != widget.count) {
      _liked = widget.liked;
      _count = widget.count;
    }
  }

  Future<void> _toggle() async {
    final liked = !_liked;
    setState(() {
      _liked = liked;
      _count += liked ? 1 : -1;
    });
    try {
      await ref.read(socialPostsControllerProvider.notifier).like(post: widget.post, comment: widget.comment, liked: liked);
    } on Object {
      if (!mounted) return;
      setState(() {
        _liked = !liked;
        _count += liked ? -1 : 1;
      });
      _failed(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _liked ? context.colors.primary : context.tokens.muted;
    return Tooltip(
      message: context.l10n.socialLike,
      child: KPress(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.heart, size: 17, color: color),
            const SizedBox(width: 5),
            Text('$_count', style: KagamiType.figure(13, color: color)),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- post

class PostCard extends ConsumerWidget {
  const PostCard({required this.post, this.showSeries = true, super.key});

  final Post post;

  /// Nel foglio dei post su una serie la serie è già detta.
  final bool showSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    final mine = ref.watch(socialMeProvider) == post.author.id;
    final progress = post.series == null ? null : ref.watch(socialProgressProvider)[post.series];
    final kind = switch (post.kind) {
      PostKind.note => l10n.socialPostKindNote,
      PostKind.review => l10n.socialPostKindReview,
      PostKind.recommendation => l10n.socialPostKindRecommendation,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KPress(
            onTap: () => _openProfile(context, post.author.id),
            child: Row(children: [
              SocialAvatar(name: post.author.name, photo: post.author.photo, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name(context, post.author), style: KagamiType.title(14.5)),
                  Text(_when(context, post.at), style: KagamiType.body(12, color: muted)),
                ]),
              ),
              KTag(label: kind, dense: true),
            ]),
          ),
          if (post.seriesTitle != null && (showSeries || post.rating != null)) ...[
            const SizedBox(height: 8),
            KPress(
              onTap: showSeries ? () => showSeriesPosts(context, ref, title: post.seriesTitle!) : null,
              child: Row(children: [
                if (showSeries)
                  Flexible(
                    child: Text(post.seriesTitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: KagamiType.title(13.5, color: context.colors.primary)),
                  ),
                if (post.rating != null) ...[
                  if (showSeries) const SizedBox(width: 8),
                  Text('★ ${post.rating}/10', style: KagamiType.figure(13, color: ratingTint(context, post.rating!))),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 8),
          _Body(content: post, author: post.author, flags: post.flags, progress: progress, text: post.body),
          const SizedBox(height: 4),
          Row(children: [
            _LikeButton(liked: post.liked, count: post.likes, post: post),
            const SizedBox(width: 8),
            KPress(
              onTap: () => showPostComments(context, post),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.messageCircle, size: 17, color: muted),
                  const SizedBox(width: 5),
                  Text(l10n.socialCommentsCount(post.comments), style: KagamiType.body(13, color: muted)),
                ]),
              ),
            ),
            const Spacer(),
            if (!mine)
              ModerationMenu(
                uid: post.author.id,
                name: _name(context, post.author),
                target: ReportTarget.post,
                targetId: post.id,
                snapshot: post.body,
                icon: Icon(LucideIcons.ellipsis, size: 18, color: muted),
              )
            else
              PopupMenuButton<void>(
                tooltip: l10n.socialMoreActions,
                icon: Icon(LucideIcons.ellipsis, size: 18, color: muted),
                itemBuilder: (_) => [
                  PopupMenuItem<void>(
                    onTap: () => _confirmRemove(context, ref, post),
                    child: Row(children: [
                      Icon(LucideIcons.trash2, size: 17, color: context.tokens.danger),
                      const SizedBox(width: 10),
                      Text(l10n.socialRemovePost, style: TextStyle(color: context.tokens.danger)),
                    ]),
                  ),
                ],
              ),
          ]),
        ]),
      ),
    );
  }
}

Future<void> _confirmRemove(BuildContext context, WidgetRef ref, Post post) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.socialRemovePost),
      content: Text(l10n.socialRemovePostConfirm),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.socialRemovePost, style: TextStyle(color: context.tokens.danger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(socialPostsControllerProvider.notifier).remove(post);
  } on Object {
    if (context.mounted) _failed(context);
  }
}

// ------------------------------------------------------------------ scrivere

/// Il foglio per scrivere un post. Con [series] parla di quella serie e non
/// la si cambia (dalla scheda della serie); senza, la si sceglie fra quelle
/// non nascoste.
Future<void> showComposePost(BuildContext context, {SeriesSignals? series}) => showKagamiSheet<void>(
      context,
      title: context.l10n.socialComposeTitle,
      scrollable: true,
      builder: (_) => _ComposeSheet(series: series),
    );

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet({this.series});

  final SeriesSignals? series;

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _body = TextEditingController();
  final _chapter = TextEditingController();
  PostKind _kind = PostKind.note;
  late SeriesSignals? _series = widget.series;
  int? _rating;
  bool _spoiler = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// Il voto e il capitolo che si sono già dati alla serie in libreria.
  void _prefill() {
    final state = _series?.state;
    final rating = state?.rating;
    _rating = rating != null && rating >= 1 && rating <= 10 ? rating : null;
    _chapter.text = state?.reachedChapter ?? '';
  }

  @override
  void dispose() {
    _body.dispose();
    _chapter.dispose();
    super.dispose();
  }

  String _refusal(PostRefusal refusal) {
    final l10n = context.l10n;
    return switch (refusal) {
      PostRefusal.empty => l10n.socialRefusalEmpty,
      PostRefusal.tooLong => l10n.socialRefusalTooLong,
      PostRefusal.hiddenSeries => l10n.socialRefusalHiddenSeries,
      PostRefusal.needsSeries => l10n.socialRefusalNeedsSeries,
      PostRefusal.needsRating => l10n.socialRefusalNeedsRating,
    };
  }

  Future<void> _publish() async {
    final series = _series;
    final draft = PostDraft(
      body: _body.text,
      kind: _kind,
      seriesKey: series?.entry.key,
      seriesTitle: series?.entry.title,
      rating: _kind == PostKind.review ? _rating : null,
      spoiler: _spoiler,
      chapter: _spoiler ? num.tryParse(_chapter.text.trim().replaceAll(',', '.')) : null,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final refusal = await ref.read(socialPostsControllerProvider.notifier).publish(draft);
      if (!mounted) return;
      if (refusal == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _error = _refusal(refusal));
    } on Object {
      if (mounted) setState(() => _error = context.l10n.socialRefusedSnack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    final library = widget.series == null
        ? ([...ref.watch(shownSignalsProvider)]..sort((a, b) => a.entry.title.toLowerCase().compareTo(b.entry.title.toLowerCase())))
        : const <SeriesSignals>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KSegmented(
          options: [l10n.socialPostKindNote, l10n.socialPostKindReview, l10n.socialPostKindRecommendation],
          index: _kind.index,
          onChanged: (index) => setState(() => _kind = PostKind.values[index]),
        ),
        const SizedBox(height: 14),
        if (widget.series != null)
          Text(widget.series!.entry.title, style: KagamiType.title(15, color: context.colors.primary))
        else
          DropdownMenu<String>(
            label: Text(l10n.socialComposeSeries),
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            initialSelection: '',
            onSelected: (key) => setState(() {
              _series = library.where((s) => s.entry.key == key).firstOrNull;
              _prefill();
            }),
            dropdownMenuEntries: [
              DropdownMenuEntry(value: '', label: l10n.socialComposeNoSeries),
              for (final s in library) DropdownMenuEntry(value: s.entry.key, label: s.entry.title),
            ],
          ),
        if (_kind == PostKind.review) ...[
          KSection(l10n.socialComposeRating, padding: const EdgeInsets.only(top: 16, bottom: 8)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 1; i <= 10; i++)
              KChip(label: '$i', active: _rating == i, tint: ratingTint(context, i), onTap: () => setState(() => _rating = i)),
          ]),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _body,
          minLines: 3,
          maxLines: 8,
          maxLength: SocialLimits.post,
          decoration: InputDecoration(hintText: l10n.socialComposeBodyHint),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.socialComposeSpoiler),
          value: _spoiler,
          onChanged: (value) => setState(() => _spoiler = value),
        ),
        if (_spoiler)
          TextField(
            controller: _chapter,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: l10n.socialComposeSpoilerChapter),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: KagamiType.body(13, color: context.tokens.danger)),
          ),
        const SizedBox(height: 16),
        KButton(label: l10n.socialComposePublish, icon: LucideIcons.send, expand: true, onPressed: _busy ? null : _publish),
        if (_busy) Padding(padding: const EdgeInsets.only(top: 8), child: LinearProgressIndicator(color: muted)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ commenti

Future<void> showPostComments(BuildContext context, Post post) => showKagamiSheet<void>(
      context,
      title: context.l10n.socialCommentsTitle,
      scrollable: true,
      builder: (_) => _CommentsSheet(post: post),
    );

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.post});

  final Post post;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _text = TextEditingController();
  Comment? _replyTo;
  bool _spoiler = false;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(socialPostsControllerProvider.notifier).comment(widget.post, _text.text, replyTo: _replyTo, spoiler: _spoiler);
      _text.clear();
      if (mounted) {
        setState(() {
          _replyTo = null;
          _spoiler = false;
        });
      }
    } on Object {
      if (mounted) _failed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Comment comment) async {
    try {
      await ref.read(socialPostsControllerProvider.notifier).removeComment(widget.post, comment);
    } on Object {
      if (mounted) _failed(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final post = widget.post;
    final me = ref.watch(socialMeProvider);
    final progress = post.series == null ? null : ref.watch(socialProgressProvider)[post.series];
    final comments = ref.watch(socialCommentsProvider(post.id));
    final list = switch (comments) {
      AsyncLoading() => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
      AsyncError() => KEmpty(
          icon: LucideIcons.wifiOff,
          title: l10n.socialLoadError,
          action: KButton(label: l10n.socialRetry, onPressed: () => ref.invalidate(socialCommentsProvider(post.id))),
        ),
      AsyncData(:final value) when value.isEmpty => KEmpty(icon: LucideIcons.messageCircle, title: l10n.socialCommentsEmpty),
      AsyncData(:final value) => Column(children: [
          // Le risposte sotto il commento a cui rispondono; quelle il cui
          // commento non c'è più non hanno dove stare.
          for (final top in value.where((c) => c.parent == null)) ...[
            _CommentTile(
              key: ValueKey(top.id),
              comment: top,
              progress: progress,
              mine: top.author.id == me,
              removable: top.author.id == me || post.author.id == me,
              onReply: () => setState(() => _replyTo = top),
              onRemove: () => _remove(top),
            ),
            for (final reply in value.where((c) => c.parent == top.id))
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: _CommentTile(
                  key: ValueKey(reply.id),
                  comment: reply,
                  progress: progress,
                  mine: reply.author.id == me,
                  removable: reply.author.id == me || post.author.id == me,
                  onReply: () => setState(() => _replyTo = reply),
                  onRemove: () => _remove(reply),
                ),
              ),
          ],
        ]),
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: list)),
      Divider(height: 1, color: context.tokens.line),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          if (_replyTo != null)
            IconButton(
              tooltip: l10n.socialCancelReply,
              icon: const Icon(LucideIcons.cornerDownRight, size: 18),
              onPressed: () => setState(() => _replyTo = null),
            ),
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                counterText: '',
                hintText: _replyTo == null ? l10n.socialCommentHint : l10n.socialReplyHint(_name(context, _replyTo!.author)),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.socialComposeSpoiler,
            isSelected: _spoiler,
            icon: const Icon(LucideIcons.eye, size: 18),
            selectedIcon: Icon(LucideIcons.eyeOff, size: 18, color: context.tokens.warning),
            onPressed: () => setState(() => _spoiler = !_spoiler),
          ),
          IconButton(
            tooltip: l10n.socialSend,
            icon: Icon(LucideIcons.send, size: 18, color: context.colors.primary),
            onPressed: _busy ? null : _send,
          ),
        ]),
      ),
    ]);
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.progress,
    required this.mine,
    required this.removable,
    required this.onReply,
    required this.onRemove,
    super.key,
  });

  final Comment comment;
  final num? progress;
  final bool mine;
  final bool removable;
  final VoidCallback onReply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    final action = KagamiType.body(12.5, color: muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KPress(
          onTap: () => _openAuthor(context, comment.author),
          child: SocialAvatar(name: comment.author.name, photo: comment.author.photo, size: 28),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KPress(
              onTap: () => _openAuthor(context, comment.author),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: _name(context, comment.author), style: KagamiType.title(13.5)),
                TextSpan(text: '  ${_when(context, comment.at)}', style: KagamiType.body(12, color: muted)),
              ])),
            ),
            const SizedBox(height: 2),
            _Body(content: comment, author: comment.author, flags: comment.flags, progress: progress, text: comment.body),
            Row(children: [
              _LikeButton(liked: comment.liked, count: comment.likes, comment: comment),
              KPress(
                onTap: onReply,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Text(l10n.socialReply, style: action)),
              ),
              if (removable)
                KPress(
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Text(l10n.socialRemoveComment, style: action),
                  ),
                ),
              if (!mine)
                ModerationMenu(
                  uid: comment.author.id,
                  name: _name(context, comment.author),
                  target: ReportTarget.comment,
                  targetId: comment.id,
                  snapshot: comment.body,
                  icon: Icon(LucideIcons.ellipsis, size: 16, color: muted),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------- su una serie

/// I post della Comunità su una serie. Con [signals] (una serie della mia
/// libreria) si può anche scriverne. Una serie nascosta non arriva qui: chi
/// chiama non la offre, e `socialSeriesPostsProvider` non la chiede.
Future<void> showSeriesPosts(BuildContext context, WidgetRef ref, {required String title, SeriesSignals? signals}) {
  final ref0 = seriesRef(title);
  final mine = signals ?? ref.read(shownSignalsProvider).where((s) => seriesRef(s.entry.title) == ref0).firstOrNull;
  return showKagamiSheet<void>(
    context,
    title: title,
    scrollable: true,
    action: mine == null
        ? null
        : Builder(
            builder: (context) => KIconAction(
              icon: LucideIcons.penLine,
              size: 40,
              tooltip: context.l10n.socialWrite,
              onPressed: () => showComposePost(context, series: mine),
            ),
          ),
    builder: (_) => _SeriesPosts(series: ref0),
  );
}

class _SeriesPosts extends ConsumerWidget {
  const _SeriesPosts({required this.series});

  final String series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final posts = ref.watch(socialSeriesPostsProvider(series));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: switch (posts) {
        AsyncLoading() => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        AsyncError() => KEmpty(
            icon: LucideIcons.wifiOff,
            title: l10n.socialLoadError,
            action: KButton(label: l10n.socialRetry, onPressed: () => ref.invalidate(socialSeriesPostsProvider(series))),
          ),
        AsyncData(:final value) when value.isEmpty => KEmpty(icon: LucideIcons.messagesSquare, title: l10n.socialSeriesPostsEmpty),
        AsyncData(:final value) => Column(children: [for (final post in value) PostCard(key: ValueKey(post.id), post: post, showSeries: false)]),
      },
    );
  }
}

/// Il tondo sulla copertina di una serie che apre i suoi post: c'è solo con
/// la Comunità accesa e se la serie non è nascosta.
class SeriesSocialAction extends ConsumerWidget {
  const SeriesSocialAction({required this.signals, super.key});

  final SeriesSignals signals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(socialPostsProvider) != null;
    final enabled = ref.watch(socialSettingsProvider.select((s) => s.value?.enabled ?? false));
    final hidden = ref.watch(hiddenSeriesKeysProvider).contains(signals.entry.key);
    if (!available || !enabled || hidden) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
      child: Tooltip(
        message: context.l10n.socialSeriesTalk,
        child: KPress(
          onTap: () => showSeriesPosts(context, ref, title: signals.entry.title, signals: signals),
          child: Container(
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
            child: const Icon(LucideIcons.messagesSquare, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
