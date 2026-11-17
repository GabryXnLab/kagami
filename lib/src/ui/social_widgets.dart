/// Pezzi della «Comunità» che stanno in più schermate: avatar, numeri e generi
/// di un profilo pubblico. Contratto in `docs/social.md`.
library;

import 'package:flutter/material.dart';

import '../data/social/profile.dart';
import '../l10n.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// L'avatar: la foto se il proprietario l'ha pubblicata ed è di Google
/// ([isProfilePhoto]), altrimenti l'iniziale del soprannome.
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({required this.name, this.photo, this.size = 40, super.key});

  final String name;
  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : String.fromCharCode(name.trim().runes.first).toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: context.colors.primary.withValues(alpha: 0.18),
      child: Text(initial, style: KagamiType.title(size * 0.42, color: context.colors.primary)),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: !isProfilePhoto(photo)
            ? fallback
            : Image.network(photo!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

/// Capitoli, serie e giorni di fila: i numeri che ci sono sempre in un profilo.
class ProfileFigures extends StatelessWidget {
  const ProfileFigures({required this.profile, super.key});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return KFigureRow(children: [
      KFigure(value: '${profile.chapters}', label: l10n.socialStatChapters),
      KFigure(value: '${profile.seriesCount}', label: l10n.socialStatSeries),
      KFigure(value: '${profile.streak}', label: l10n.socialStatStreak),
    ]);
  }
}

/// I generi come barre: le parti sono quote di un intero, ma otto fette
/// sarebbero illeggibili.
class GenreBars extends StatelessWidget {
  const GenreBars({required this.genres, this.limit = 5, super.key});

  final List<(String, int)> genres;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        for (final (name, share) in genres.take(limit))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 96, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KagamiType.body(13))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share / 100,
                    minHeight: 8,
                    backgroundColor: tokens.line,
                    color: context.colors.primary,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('$share%', textAlign: TextAlign.end, style: KagamiType.body(12.5, color: tokens.muted)),
              ),
            ]),
          ),
      ],
    );
  }
}

/// I capitoli delle ultime due settimane, un giorno per colonna.
class ActivityStrip extends StatelessWidget {
  const ActivityStrip({required this.days, super.key});

  final List<int> days;

  @override
  Widget build(BuildContext context) {
    final most = days.fold<int>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: 4 + 40 * day / most,
                  decoration: BoxDecoration(
                    color: day == 0 ? context.tokens.line : context.colors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
