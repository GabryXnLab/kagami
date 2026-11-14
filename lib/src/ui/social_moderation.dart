/// Silenziare, segnalare e bloccare una persona o un suo contenuto: il menu
/// che sta sul profilo, su un post e su un commento di un altro. Contratto in
/// `docs/social.md`: il blocco è reciproco e l'altro non lo sa, la
/// segnalazione non si rilegge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/social/content.dart';
import '../data/social/profile.dart';
import '../l10n.dart';
import '../providers_social.dart';
import 'theme.dart';

/// Il menu «altre azioni» su [uid]. Con [target] (e [targetId] se non è la
/// persona) si può anche segnalare quel contenuto, di cui [snapshot] è la
/// copia che la segnalazione si porta dietro.
class ModerationMenu extends ConsumerWidget {
  const ModerationMenu({
    required this.uid,
    required this.name,
    this.target = ReportTarget.user,
    this.targetId,
    this.snapshot = '',
    this.icon,
    super.key,
  });

  final String uid;
  final String name;
  final ReportTarget target;
  final String? targetId;
  final String snapshot;
  final Widget? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final muted = ref.watch(socialSettingsProvider.select((settings) => settings.value?.muted.contains(uid) ?? false));
    Widget row(IconData data, String label, {Color? color}) => Row(children: [
          Icon(data, size: 17, color: color),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: TextStyle(color: color))),
        ]);
    return PopupMenuButton<void>(
      tooltip: l10n.socialMoreActions,
      icon: icon,
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          onTap: () => setMuted(ref, uid, muted: !muted),
          child: row(muted ? LucideIcons.bell : LucideIcons.bellOff, muted ? l10n.socialUnmute : l10n.socialMute),
        ),
        PopupMenuItem<void>(
          onTap: () => _report(context, ref),
          child: row(LucideIcons.flag, l10n.socialReport, color: tokens.warning),
        ),
        PopupMenuItem<void>(
          onTap: () => _block(context, ref),
          child: row(LucideIcons.ban, l10n.socialBlockPerson(name), color: tokens.danger),
        ),
      ],
    );
  }

  void _say(BuildContext context, String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final answer = await showDialog<(ReportReason, String)>(context: context, builder: (_) => const _ReportDialog());
    if (answer == null) return;
    try {
      await sendReport(
        ref,
        Report(target: target, user: uid, targetId: targetId, reason: answer.$1, note: answer.$2.trim(), snapshot: snapshot),
      );
      if (context.mounted) _say(context, context.l10n.socialReportSent);
    } on Object {
      // Un blocco, un limite e una rete che manca dicono la stessa cosa.
      if (context.mounted) _say(context, context.l10n.socialRefusedSnack);
    }
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.socialBlockPerson(name)),
        content: Text(l10n.socialBlockConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.socialBlockAction, style: TextStyle(color: context.tokens.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await setBlocked(ref, uid, blocked: true, name: name);
      if (context.mounted) _say(context, context.l10n.socialBlockedSnack);
    } on Object {
      if (context.mounted) _say(context, context.l10n.socialRefusedSnack);
    }
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _note = TextEditingController();
  ReportReason? _reason;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      ReportReason.spam: l10n.socialReportReasonSpam,
      ReportReason.harassment: l10n.socialReportReasonHarassment,
      ReportReason.spoiler: l10n.socialReportReasonSpoiler,
      ReportReason.inappropriate: l10n.socialReportReasonInappropriate,
      ReportReason.other: l10n.socialReportReasonOther,
    };
    return AlertDialog(
      title: Text(l10n.socialReport),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.socialReportIntro, style: KagamiType.body(13, color: context.tokens.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final MapEntry(key: reason, value: label) in labels.entries)
              ChoiceChip(label: Text(label), selected: _reason == reason, onSelected: (_) => setState(() => _reason = reason)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: SocialLimits.reportNote,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(hintText: l10n.socialReportNoteHint),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        TextButton(
          onPressed: _reason == null ? null : () => Navigator.of(context).pop((_reason!, _note.text)),
          child: Text(l10n.socialReportSend),
        ),
      ],
    );
  }
}
