/// Le tre schede della Comunità accesa: classifiche, feed e persone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/social/backend.dart';
import '../data/social/content.dart';
import '../data/social/profile.dart';
import '../l10n.dart';
import '../providers_social.dart';
import 'social_posts.dart';
import 'social_profile_screen.dart';
import 'social_widgets.dart';
import 'theme.dart';
import 'widgets/kit.dart';

void _openProfile(BuildContext context, String uid) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SocialProfileScreen(uid: uid)),
    );

/// Una lettura fallita: «non disponibile» senza riprovare, oppure rete con
/// «Riprova» (`docs/social.md`, «Errori»).
class SocialLoadFailure extends StatelessWidget {
  const SocialLoadFailure({required this.error, required this.retry, super.key});

  final Object error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (error is SocialUnavailable) {
      return KEmpty(icon: LucideIcons.cloudOff, title: l10n.socialUnavailableTitle, message: l10n.socialUnavailableBody);
    }
    return KEmpty(
      icon: LucideIcons.wifiOff,
      title: l10n.socialLoadError,
      action: KButton(label: l10n.socialRetry, onPressed: retry),
    );
  }
}

// ---------------------------------------------------------------- classifiche

const _boards = [Board.week, Board.month, Board.allTime, Board.streak];

class BoardsTab extends ConsumerStatefulWidget {
  const BoardsTab({super.key});

  @override
  ConsumerState<BoardsTab> createState() => _BoardsTabState();
}

class _BoardsTabState extends ConsumerState<BoardsTab> {
  Board _board = Board.week;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [l10n.socialBoardWeek, l10n.socialBoardMonth, l10n.socialBoardAllTime, l10n.socialBoardStreak];
    final rows = ref.watch(socialBoardProvider(_board));
    final me = ref.watch(socialMeProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: KSegmented(
            options: labels,
            index: _boards.indexOf(_board),
            onChanged: (index) => setState(() => _board = _boards[index]),
          ),
        ),
        Expanded(
          child: switch (rows) {
            AsyncLoading() => const Center(child: CircularProgressIndicator()),
            AsyncError(:final error) =>
              SocialLoadFailure(error: error, retry: () => ref.invalidate(socialBoardProvider(_board))),
            AsyncData(:final value) when value.isEmpty =>
              KEmpty(icon: LucideIcons.trophy, title: l10n.socialBoardEmpty),
            AsyncData(:final value) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                itemCount: value.length,
                itemBuilder: (context, index) =>
                    _BoardRow(position: index + 1, profile: value[index], board: _board, mine: value[index].id == me),
              ),
          },
        ),
      ],
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.position, required this.profile, required this.board, required this.mine});

  final int position;
  final PublicProfile profile;
  final Board board;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = switch (board) {
      Board.week => l10n.socialChapters(profile.weekChapters),
      Board.month => l10n.socialChapters(profile.monthChapters),
      Board.allTime => l10n.socialChapters(profile.chapters),
      Board.streak => l10n.socialStreakDays(profile.streak),
    };
    final genres = profile.genres.take(2).map((genre) => genre.$1).join(' · ');
    final muted = context.tokens.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 16,
        color: mine ? context.colors.primary.withValues(alpha: 0.12) : null,
        onTap: () => _openProfile(context, profile.id),
        child: Row(children: [
          SizedBox(width: 28, child: Text('$position', style: KagamiType.figure(15, color: muted))),
          SocialAvatar(name: profile.name, photo: profile.photo, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KagamiType.title(15))),
                if (mine) ...[const SizedBox(width: 6), KTag(label: l10n.socialYouBadge, dense: true)],
              ]),
              if (genres.isNotEmpty) Text(genres, maxLines: 1, overflow: TextOverflow.ellipsis, style: KagamiType.body(12.5, color: muted)),
            ]),
          ),
          Text(value, style: KagamiType.body(13, color: muted)),
        ]),
      ),
    );
  }
}

// ----------------------------------------------------------------------- feed

class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key});

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  FeedScope _scope = FeedScope.everyone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final posts = ref.watch(socialFeedProvider(_scope));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(children: [
            Expanded(
              child: KSegmented(
                options: [l10n.socialAudienceEveryone, l10n.socialAudienceFollowing],
                index: _scope.index,
                onChanged: (index) => setState(() => _scope = FeedScope.values[index]),
              ),
            ),
            const SizedBox(width: 10),
            KButton(label: l10n.socialWrite, icon: LucideIcons.penLine, height: 40, onPressed: () => showComposePost(context)),
          ]),
        ),
        Expanded(
          child: switch (posts) {
            AsyncLoading() => const Center(child: CircularProgressIndicator()),
            AsyncError(:final error) =>
              SocialLoadFailure(error: error, retry: () => ref.invalidate(socialFeedProvider(_scope))),
            AsyncData(:final value) when value.isEmpty => KEmpty(
                icon: LucideIcons.messageSquareText,
                title: l10n.socialFeedEmptyTitle,
                message: l10n.socialFeedEmptyMessage,
              ),
            AsyncData(:final value) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                itemCount: value.length,
                itemBuilder: (context, index) => PostCard(key: ValueKey(value[index].id), post: value[index]),
              ),
          },
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- persone

class PeopleTab extends ConsumerStatefulWidget {
  const PeopleTab({super.key});

  @override
  ConsumerState<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<PeopleTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final searching = _query.trim().length >= 2 && !_query.contains('@');
    final AsyncValue<List<PublicProfile>> people =
        searching ? ref.watch(socialSearchProvider(_query)) : ref.watch(socialFollowingProvider);
    final graph = ref.watch(socialGraphProvider).value ?? const SocialGraph();
    // Chi mi segue e io no: il nome è quello che aveva seguendomi, perché il
    // profilo può non essere visibile.
    final followers = searching ? const <SocialCard>[] : [for (final card in graph.followers) if (!graph.follows(card.id)) card];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: l10n.socialSearchPeopleHint,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
            ),
          ),
        ),
        if (_query.contains('@'))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(l10n.socialSearchNoEmailNotice, style: KagamiType.body(12.5, color: context.tokens.muted)),
          ),
        Expanded(
          child: switch (people) {
            AsyncLoading() => const Center(child: CircularProgressIndicator()),
            AsyncError(:final error) => SocialLoadFailure(
                error: error,
                retry: () => searching ? ref.invalidate(socialSearchProvider(_query)) : ref.invalidate(socialFollowingProvider),
              ),
            AsyncData(:final value) when value.isEmpty && followers.isEmpty => KEmpty(
                icon: LucideIcons.users,
                title: searching ? l10n.socialSearchNone : l10n.socialPeopleEmpty,
              ),
            AsyncData(:final value) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  if (!searching && value.isNotEmpty)
                    KSection(l10n.socialPeopleFollowingSection, padding: const EdgeInsets.only(bottom: 8)),
                  for (final profile in value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: KCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        radius: 16,
                        onTap: () => _openProfile(context, profile.id),
                        child: Row(children: [
                          SocialAvatar(name: profile.name, photo: profile.photo, size: 36),
                          const SizedBox(width: 12),
                          Expanded(child: Text(profile.name, style: KagamiType.title(15))),
                          Text(l10n.socialChapters(profile.chapters), style: KagamiType.body(13, color: context.tokens.muted)),
                        ]),
                      ),
                    ),
                  if (followers.isNotEmpty) ...[
                    KSection(l10n.socialFollowersSection, padding: const EdgeInsets.only(top: 12, bottom: 8)),
                    for (final card in followers) _FollowerRow(card: card, onOpen: () => _openProfile(context, card.id)),
                  ],
                ],
              ),
          },
        ),
      ],
    );
  }
}

/// Chi mi segue e io no, con «Segui anche tu».
class _FollowerRow extends ConsumerStatefulWidget {
  const _FollowerRow({required this.card, required this.onOpen});

  final SocialCard card;
  final VoidCallback onOpen;

  @override
  ConsumerState<_FollowerRow> createState() => _FollowerRowState();
}

class _FollowerRowState extends ConsumerState<_FollowerRow> {
  bool _busy = false;

  Future<void> _followBack() async {
    setState(() => _busy = true);
    try {
      await setFollowing(ref, widget.card.id, follow: true);
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.socialRefusedSnack)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = widget.card;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 16,
        onTap: widget.onOpen,
        child: Row(children: [
          SocialAvatar(name: card.name, photo: card.photo, size: 36),
          const SizedBox(width: 12),
          Expanded(child: Text(card.name.isEmpty ? l10n.socialUnknownReader : card.name, style: KagamiType.title(15))),
          KGhostButton(label: l10n.socialFollowBack, icon: LucideIcons.userPlus, onPressed: _busy ? null : _followBack),
        ]),
      ),
    );
  }
}
