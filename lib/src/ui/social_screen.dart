/// «Comunità»: da spenta è l'invito ad accenderla con l'anteprima esatta di ciò
/// che uscirebbe; da accesa, classifiche, feed e persone. Contratto in
/// `docs/social.md`, piano in `handoff/raccolte-social-sorgenti/FASE-7.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/social/profile.dart';
import '../l10n.dart';
import '../providers_social.dart';
import 'social_messages.dart';
import 'privacy_screen.dart';
import 'social_tabs.dart';
import 'social_widgets.dart';
import 'theme.dart';
import 'widgets/kit.dart';

class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(socialSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.socialTitle),
        actions: [
          if (settings.value?.enabled ?? false) const MessagesButton(),
          if (settings.value?.enabled ?? false)
            IconButton(
              tooltip: context.l10n.socialTurnOff,
              icon: const Icon(LucideIcons.power, size: 20),
              onPressed: () => confirmSocialTurnOff(context, ref),
            ),
        ],
      ),
      body: switch (settings) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError() => const SizedBox.shrink(),
        AsyncData(:final value) when value.enabled => const _Hub(),
        AsyncData(:final value) => _OffPage(initial: value),
      },
    );
  }
}

Future<void> confirmSocialTurnOff(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.socialTurnOff),
      content: Text(l10n.socialWipeWarning),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.socialTurnOff, style: TextStyle(color: context.tokens.danger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(socialControllerProvider.notifier).turnOff();
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.socialRefusedSnack)));
    }
  }
}

class _Hub extends ConsumerStatefulWidget {
  const _Hub();

  @override
  ConsumerState<_Hub> createState() => _HubState();
}

class _HubState extends ConsumerState<_Hub> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (ref.watch(socialControllerProvider.select((status) => status.unavailable))) {
      return KEmpty(icon: LucideIcons.cloudOff, title: l10n.socialUnavailableTitle, message: l10n.socialUnavailableBody);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: KSegmented(
            options: [l10n.socialTabBoards, l10n.socialTabFeed, l10n.socialTabPeople],
            index: _tab,
            onChanged: (index) => setState(() => _tab = index),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => const BoardsTab(),
            1 => const FeedTab(),
            _ => const PeopleTab(),
          },
        ),
      ],
    );
  }
}

/// Spenta: da qui non parte nessuna chiamata al backend. Ogni scelta si
/// salva subito (è solo sul telefono) e l'anteprima la segue.
class _OffPage extends ConsumerStatefulWidget {
  const _OffPage({required this.initial});

  final SocialSettings initial;

  @override
  ConsumerState<_OffPage> createState() => _OffPageState();
}

class _OffPageState extends ConsumerState<_OffPage> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _bio = TextEditingController(text: widget.initial.bio);

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  SocialSettings get _current => ref.read(socialSettingsProvider).value ?? widget.initial;

  void _change(SocialSettings settings) => ref.read(socialSettingsProvider.notifier).save(settings);

  Future<void> _turnOn() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(socialControllerProvider.notifier).turnOn(_current.copyWith(enabled: true));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.socialLoadError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(socialSettingsProvider).value ?? widget.initial;
    final status = ref.watch(socialControllerProvider);
    final hasBackend = ref.watch(socialBackendProvider) != null;
    final muted = context.tokens.muted;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text(l10n.socialOffIntro, style: KagamiType.body(14, color: muted)),
        const SizedBox(height: 18),
        TextField(
          controller: _name,
          maxLength: SocialLimits.nameMax,
          onChanged: (value) => _change(_current.copyWith(name: value)),
          decoration: InputDecoration(labelText: l10n.socialNameLabel, helperText: l10n.socialNameHint),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bio,
          maxLength: SocialLimits.bio,
          onChanged: (value) => _change(_current.copyWith(bio: value)),
          decoration: InputDecoration(labelText: l10n.socialBioLabel),
        ),
        const SocialVisibilityControls(),
        KSection(l10n.socialPreviewSection, trailing: Text(l10n.socialPreviewHiddenExcluded, style: KagamiType.body(12, color: context.tokens.success))),
        const _Preview(),
        const SizedBox(height: 22),
        if (status.unavailable)
          KEmpty(icon: LucideIcons.cloudOff, title: l10n.socialUnavailableTitle, message: l10n.socialUnavailableBody, compact: true)
        else if (!hasBackend)
          Text(l10n.socialNeedsAccount, style: KagamiType.body(13, color: muted))
        else ...[
          KButton(
            label: l10n.socialTurnOn,
            icon: LucideIcons.users,
            expand: true,
            onPressed: settings.hasValidName && !status.busy ? _turnOn : null,
          ),
          const SizedBox(height: 10),
          Text(l10n.socialWipeWarning, style: KagamiType.body(12.5, color: muted)),
        ],
      ],
    );
  }
}

/// Il profilo come lo vedrebbero gli altri: lo stesso `buildPublicProfile`
/// che lo pubblica. Ciò che un interruttore tiene spento è una riga col
/// lucchetto, non un campo vuoto.
class _Preview extends ConsumerWidget {
  const _Preview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final draft = ref.watch(socialDraftProvider);
    final profile = draft.value;
    if (profile == null) {
      return const KCard(child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())));
    }
    final muted = context.tokens.muted;
    Widget locked(String what) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(LucideIcons.lock, size: 14, color: muted),
            const SizedBox(width: 8),
            Text(l10n.socialPreviewLocked(what), style: KagamiType.body(12.5, color: muted)),
          ]),
        );
    return KCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SocialAvatar(name: profile.name, photo: profile.photo, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              profile.name.isEmpty ? l10n.socialNameLabel : profile.name,
              style: KagamiType.title(18, color: profile.name.isEmpty ? muted : null),
            ),
          ),
        ]),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(profile.bio, style: KagamiType.body(13.5)),
        ],
        const SizedBox(height: 16),
        ProfileFigures(profile: profile),
        if (profile.genres.isNotEmpty) ...[
          const SizedBox(height: 14),
          GenreBars(genres: profile.genres, limit: 3),
        ],
        if (profile.series != null)
          for (final (title, chapters) in profile.series!.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$title · ${l10n.socialChapters(chapters)}', style: KagamiType.body(13)),
            )
        else
          locked(l10n.socialPreviewSeries),
        if (profile.activity != null) ...[
          const SizedBox(height: 10),
          ActivityStrip(days: profile.activity!),
        ] else
          locked(l10n.socialPreviewActivity),
        if (profile.photo == null) locked(l10n.socialPreviewPhoto),
      ]),
    );
  }
}
