/// Impostazioni → «Privacy e Comunità»: acceso o spento, chi vede il profilo,
/// cosa si mostra, chi può scrivermi, e l'elenco di chi ho bloccato. Le scelte
/// sono locali (`social.*`) e valgono anche a Comunità spenta. Contratto in
/// `docs/social.md`, §«Chi vede cosa».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/social/profile.dart';
import '../l10n.dart';
import '../providers_social.dart';
import 'social_screen.dart';
import 'theme.dart';
import 'widgets/kit.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(socialSettingsProvider).value;
    final enabled = settings?.enabled ?? false;
    final status = ref.watch(socialControllerProvider);
    final muted = context.tokens.muted;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                KGroup(children: [
                  KTile(
                    icon: LucideIcons.users,
                    title: l10n.socialTitle,
                    subtitle: enabled ? l10n.socialSubtitleOn : l10n.socialSubtitleOff,
                    trailing: Switch(value: enabled, onChanged: status.busy ? null : (_) => _toggle(context, ref, settings)),
                    onTap: status.busy ? null : () => _toggle(context, ref, settings),
                  ),
                ]),
                if (!enabled) ...[
                  const SizedBox(height: 8),
                  Text(l10n.privacyOffNote, style: KagamiType.body(12.5, color: muted)),
                ],
                const SocialVisibilityControls(),
                KSection(l10n.privacyMessagesSection),
                KGroup(children: [
                  for (final policy in MessagePolicy.values)
                    KTile(
                      icon: switch (policy) {
                        MessagePolicy.everyone => LucideIcons.globe,
                        MessagePolicy.following => LucideIcons.userCheck,
                        MessagePolicy.mutual => LucideIcons.handshake,
                        MessagePolicy.nobody => LucideIcons.messageCircleOff,
                      },
                      title: switch (policy) {
                        MessagePolicy.everyone => l10n.socialAudienceEveryone,
                        MessagePolicy.following => l10n.socialAudienceFollowing,
                        MessagePolicy.mutual => l10n.socialAudienceMutual,
                        MessagePolicy.nobody => l10n.privacyMessagesNobody,
                      },
                      trailing: settings.messages == policy ? const Icon(LucideIcons.check, size: 18) : null,
                      onTap: () => ref.read(socialSettingsProvider.notifier).save(settings.copyWith(messages: policy)),
                    ),
                ]),
                KSection(l10n.privacyBlockedSection),
                const _Blocked(),
              ],
            ),
    );
  }

  /// Spegnere cancella dal backend ciò che era mio, quindi conferma; accendere
  /// vuole un soprannome valido, che si sceglie in Comunità.
  Future<void> _toggle(BuildContext context, WidgetRef ref, SocialSettings settings) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (settings.enabled) {
      await confirmSocialTurnOff(context, ref);
      return;
    }
    if (!settings.hasValidName || ref.read(socialBackendProvider) == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.privacyNeedsName)));
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SocialScreen()));
      return;
    }
    try {
      await ref.read(socialControllerProvider.notifier).turnOn(settings.copyWith(enabled: true));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.socialLoadError)));
    }
  }
}

/// Chi vede il profilo e cosa mostra: lo stesso blocco sta nella pagina
/// Privacy e nell'invito di Comunità, ogni scelta si salva subito.
class SocialVisibilityControls extends ConsumerWidget {
  const SocialVisibilityControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(socialSettingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    void change(SocialSettings next) => ref.read(socialSettingsProvider.notifier).save(next);
    final note = switch (settings.audience) {
      SocialAudience.everyone => l10n.socialAudienceEveryoneNote,
      SocialAudience.following => l10n.socialAudienceFollowingNote,
      SocialAudience.mutual => l10n.socialAudienceMutualNote,
    };
    Widget toggle(IconData icon, String title, bool value, ValueChanged<bool> onChanged) => KTile(
          icon: icon,
          title: title,
          trailing: Switch(value: value, onChanged: onChanged),
          onTap: () => onChanged(!value),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KSection(l10n.socialAudienceSection),
        KSegmented(
          options: [l10n.socialAudienceEveryone, l10n.socialAudienceFollowing, l10n.socialAudienceMutual],
          index: SocialAudience.values.indexOf(settings.audience),
          onChanged: (index) => change(settings.copyWith(audience: SocialAudience.values[index])),
        ),
        const SizedBox(height: 8),
        Text(note, style: KagamiType.body(12.5, color: context.tokens.muted)),
        KSection(l10n.socialSwitchesSection),
        KGroup(children: [
          toggle(LucideIcons.image, l10n.socialShowPhoto, settings.showPhoto, (v) => change(settings.copyWith(showPhoto: v))),
          toggle(LucideIcons.bookMarked, l10n.socialShowSeries, settings.showSeries, (v) => change(settings.copyWith(showSeries: v))),
          toggle(LucideIcons.activity, l10n.socialShowActivity, settings.showActivity, (v) => change(settings.copyWith(showActivity: v))),
        ]),
      ],
    );
  }
}

class _Blocked extends ConsumerWidget {
  const _Blocked();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final blocked = ref.watch(socialBlockedProvider).value ?? const <String>{};
    final names = ref.watch(socialBlockedNamesProvider).value ?? const <String, String>{};
    if (blocked.isEmpty) {
      return Text(l10n.privacyBlockedEmpty, style: KagamiType.body(13, color: context.tokens.muted));
    }
    return KGroup(children: [
      for (final uid in blocked)
        KTile(
          icon: LucideIcons.ban,
          title: names[uid] ?? l10n.privacyBlockedPerson,
          trailing: TextButton(
            onPressed: () => _unblock(context, ref, uid),
            child: Text(l10n.privacyUnblock),
          ),
        ),
    ]);
  }

  Future<void> _unblock(BuildContext context, WidgetRef ref, String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await setBlocked(ref, uid, blocked: false);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.socialRefusedSnack)));
    }
  }
}
