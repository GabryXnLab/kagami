/// [SocialReports] in memoria, per i test: le regole di `reports` di
/// `docs/social.md` (serve un profilo, una per persona e oggetto, venti al
/// giorno, `target_id` solo se non è una persona), sopra un [MemorySocial].
library;

// Anche questa è solo per i test: sta sopra MemorySocial, che lo è.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'content.dart';
import 'memory_social.dart';

@visibleForTesting
class MemoryReports implements SocialReports {
  MemoryReports(this.social, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final MemorySocial social;
  final DateTime Function() _clock;

  /// Chi le ha scritte, con la segnalazione e quando: le legge chi gestisce il backend.
  final List<({String reporter, Report report, DateTime at})> stored = [];

  /// Se impostato, ogni chiamata lo lancia.
  Object? failure;

  @override
  Future<void> report(Report report) async {
    if (failure case final error?) throw error;
    final me = social.me;
    final now = _clock();
    final today = stored.where((s) => s.reporter == me && now.difference(s.at) < const Duration(days: 1));
    if (!social.profiles.containsKey(me) || today.length >= 20) throw const SocialRefused();
    if ((report.target == ReportTarget.user) != (report.targetId == null)) throw ArgumentError('target_id');
    if (report.note.runes.length > 500 || report.snapshot.runes.length > 2000) throw ArgumentError('length');
    final same = stored.any(
      (s) => s.reporter == me && s.report.target == report.target && s.report.targetId == report.targetId && s.report.user == report.user,
    );
    if (!same) stored.add((reporter: me, report: report, at: now));
  }
}
