/// [SocialReports] sul backend di chi compila (tabella `reports` della
/// migrazione `backend/migrations/0005_social.sql`): si scrive e basta, le
/// regole non lasciano rileggerla.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';
import 'backend.dart';
import 'content.dart';
import 'hestia_social.dart';

class HestiaReports implements SocialReports {
  HestiaReports({this.client});

  final SupabaseClient? client;

  @override
  Future<void> report(Report report) => guardSocialWrite(() async {
        final active = client ?? backend;
        final me = active?.auth.currentUser?.id;
        if (active == null || active.auth.currentSession == null || me == null) throw AuthSessionMissingException();
        try {
          await active.from('reports').insert({
            'reporter': me,
            'target': report.target.name,
            'target_id': report.targetId,
            'target_user': report.user,
            'reason': report.reason.name,
            'note': report.note,
            'snapshot': report.snapshot,
          });
        } on PostgrestException catch (error) {
          // Una per persona e oggetto: segnalare di nuovo è già fatto.
          if (error.code != '23505') rethrow;
        }
      });
}
