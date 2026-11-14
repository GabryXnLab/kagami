/// Il profilo di un altro lettore: ciò che ha pubblicato e ciò che si ha in
/// comune con lui. Niente conteggi di seguaci: i legami li vedono solo i due
/// (`docs/social.md`, «Fuori, per scelta»).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/social/backend.dart';
import '../data/social/profile.dart';
import '../l10n.dart';
import '../providers_social.dart';
import 'social_messages.dart';
import 'social_moderation.dart';
import 'social_widgets.dart';
import 'theme.dart';
import 'widgets/kit.dart';

class SocialProfileScreen extends ConsumerWidget {
  const SocialProfileScreen({required this.uid, super.key});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(socialProfileProvider(uid));
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.value?.name ?? l10n.socialTitle),
        actions: [
          if (profile.value case final shown? when ref.watch(socialMeProvider) != shown.id)
            ModerationMenu(uid: shown.id, name: shown.name, snapshot: '${shown.name}\n${shown.bio}'),
        ],
      ),
      body: switch (profile) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => _ProfileError(error: error, uid: uid),
        // Non esiste e non lo si può vedere sono lo stesso, apposta.
        AsyncData(value: null) => KEmpty(icon: LucideIcons.userX, title: l10n.socialProfileUnavailable),
        AsyncData(:final value?) => _ProfileBody(profile: value),
      },
    );
  }
}

class _ProfileError extends ConsumerWidget {
  const _ProfileError({required this.error, required this.uid});

  final Object error;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (error is SocialUnavailable) {
      return KEmpty(icon: LucideIcons.cloudOff, title: l10n.socialUnavailableTitle, message: l10n.socialUnavailableBody);
    }
    return KEmpty(
      icon: LucideIcons.wifiOff,
      title: l10n.socialLoadError,
      action: KButton(label: l10n.socialRetry, onPressed: () => ref.invalidate(socialProfileProvider(uid))),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(socialDraftProvider).value;
    final graph = ref.watch(socialGraphProvider).value ?? const SocialGraph();
    final common = me == null ? const <String>[] : inCommon(me, profile);
    final isMe = ref.watch(socialMeProvider) == profile.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Row(children: [
          SocialAvatar(name: profile.name, photo: profile.photo, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.name, style: KagamiType.display(24)),
              if (me != null && !isMe)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.socialAffinityLabel(affinity(me, profile)),
                    style: KagamiType.body(13, color: context.colors.primary),
                  ),
                ),
            ]),
          ),
        ]),
        if (!isMe && ref.watch(socialSettingsProvider.select((settings) => settings.value?.muted.contains(profile.id) ?? false)))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l10n.socialMutedNote, style: KagamiType.body(12.5, color: context.tokens.muted)),
          ),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(profile.bio, style: KagamiType.body(14.5)),
        ],
        const SizedBox(height: 20),
        KCard(child: ProfileFigures(profile: profile)),
        if (!isMe) ...[
          const SizedBox(height: 14),
          _FollowButton(profile: profile, graph: graph),
          const SizedBox(height: 8),
          KGhostButton(
            label: l10n.messagesWrite,
            icon: LucideIcons.messageSquare,
            expand: true,
            onPressed: () => openConversation(context, profile.id, name: profile.name),
          ),
        ],
        if (profile.genres.isNotEmpty) ...[
          KSection(l10n.socialProfileGenres),
          KCard(child: GenreBars(genres: profile.genres)),
        ],
        if (common.isNotEmpty) ...[
          KSection(l10n.socialInCommonSection, trailing: Text(l10n.socialInCommonCount(common.length))),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final title in common) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(title))],
            ),
          ),
        ],
        if (profile.series != null && profile.series!.isNotEmpty) ...[
          KSection(l10n.socialProfileSeriesTitles),
          KCard(
            child: Column(children: [
              for (final (title, chapters) in profile.series!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(l10n.socialChapters(chapters), style: KagamiType.body(12.5, color: context.tokens.muted)),
                  ]),
                ),
            ]),
          ),
        ],
        if (profile.activity != null) ...[
          KSection(l10n.socialProfileActivity),
          KCard(child: ActivityStrip(days: profile.activity!)),
        ],
      ],
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.profile, required this.graph});

  final PublicProfile profile;
  final SocialGraph graph;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _busy = false;

  Future<void> _toggle(bool follow) async {
    setState(() => _busy = true);
    try {
      await setFollowing(ref, widget.profile.id, follow: follow);
    } on Object {
      // Un blocco, un limite e una rete che manca dicono la stessa cosa.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.socialRefusedSnack)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uid = widget.profile.id;
    final following = widget.graph.follows(uid);
    final label = widget.graph.mutual(uid)
        ? l10n.socialMutual
        : following
            ? l10n.socialFollowing
            : widget.graph.followedBy(uid)
                ? l10n.socialFollowBack
                : l10n.socialFollow;
    return following
        ? KGhostButton(label: label, icon: LucideIcons.userCheck, onPressed: _busy ? null : () => _toggle(false))
        : KButton(label: label, icon: LucideIcons.userPlus, expand: true, onPressed: _busy ? null : () => _toggle(true));
  }
}
