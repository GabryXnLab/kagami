/// Gli inviti a un Kagami Server su un backend compatibile Supabase: la
/// tabella `server_invites` dello schema in `backend/`.
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';
import 'server_access.dart';

/// Dove stanno gli inviti. L'app parla con questo, non con la tabella: è ciò
/// che i test sostituiscono con una copia in memoria.
abstract interface class InviteStore {
  /// Scrive l'invito, sostituendo quello con lo stesso `id`.
  Future<void> put(ServerInvite invite);

  /// Toglie l'invito: chi non c'è non è un errore.
  Future<void> remove(String id);

  /// Gli inviti per [email]. Una lettura fallita lancia (vedi
  /// [backendFailure]) e non torna mai una lista vuota: da una lista vuota chi
  /// chiama conclude che non ce ne sono.
  Future<List<ServerInvite>> listFor(String email);

  /// Un evento ogni volta che gli inviti per [email] possono essere cambiati.
  /// È un di più: un canale che non si apre o che cade tace, senza errori, e
  /// restano le riletture di chi chiama.
  Stream<void> changes(String email);
}

class SupabaseInviteStore implements InviteStore {
  /// [client] di serie è quello del backend della build; un altro lo passano
  /// i test.
  const SupabaseInviteStore({this.client});

  final SupabaseClient? client;

  static const String table = 'server_invites';

  /// Si controlla la sessione prima di chiedere: senza, il backend risponde
  /// «permesso negato» a tutto, che [backendFailure] leggerebbe come «tabella
  /// non disponibile».
  SupabaseClient _session() {
    final active = client ?? backend;
    if (active == null || active.auth.currentSession == null) throw AuthSessionMissingException();
    return active;
  }

  @override
  Future<void> put(ServerInvite invite) async {
    await _session().from(table).upsert({
      'id': invite.id,
      'to_email': invite.to,
      'from_email': invite.from,
      'from_name': invite.fromName,
      'url': invite.url,
      'server_name': invite.serverName,
    });
  }

  @override
  Future<void> remove(String id) async {
    await _session().from(table).delete().eq('id', id);
  }

  @override
  Future<List<ServerInvite>> listFor(String email) async {
    final rows = await _session().from(table).select().eq('to_email', email.toLowerCase());
    return [for (final row in rows) ServerInvite.fromRow(row)];
  }

  @override
  Stream<void> changes(String email) {
    final active = client ?? backend;
    if (active == null || active.auth.currentSession == null) return const Stream.empty();
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        try {
          channel = active
              .channel('server_invites:${email.toLowerCase()}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: table,
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'to_email',
                  value: email.toLowerCase(),
                ),
                callback: (_) => controller.add(null),
              )
              .subscribe();
        } on Object {
          // Senza canale restano le riletture.
        }
      },
      onCancel: () async {
        final open = channel;
        if (open == null) return;
        try {
          await active.removeChannel(open);
        } on Object {
          // Già chiuso.
        }
      },
    );
    return controller.stream;
  }
}
