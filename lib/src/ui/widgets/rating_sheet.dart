/// Il foglio che invita a votare una serie appena aperta.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n.dart';
import '../../providers.dart';
import '../theme.dart';
import 'kit.dart';

enum _Answer { rate, never }

/// Invita a votare la serie. «Vota» chiude il foglio e chiama [onRate] (il
/// foglio del voto vero e proprio sta nella scheda); «Non chiedere più» spegne
/// l'invito ovunque; chiuderlo in altro modo vale «più tardi».
Future<void> offerRating(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function() onRate,
}) async {
  final l10n = context.l10n;
  final answer = await showKagamiSheet<_Answer>(
    context,
    title: l10n.seriesRatingInviteTitle,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.seriesRatingInviteBody,
            style: KagamiType.body(13).copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          KButton(
            label: l10n.seriesRatingInviteRate,
            expand: true,
            onPressed: () => Navigator.of(context).pop(_Answer.rate),
          ),
          const SizedBox(height: 4),
          KGhostButton(
            label: l10n.seriesRatingInviteIgnore,
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_Answer.never),
            child: Text(l10n.seriesRatingInviteNever),
          ),
        ],
      ),
    ),
  );
  switch (answer) {
    case _Answer.rate:
      await onRate();
    case _Answer.never:
      await ref.read(ratingInviteProvider.notifier).set(false);
    case null:
      break;
  }
}
