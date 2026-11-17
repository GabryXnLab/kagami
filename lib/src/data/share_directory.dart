/// Le righe di `drive_shares` su un backend compatibile Supabase: gli inviti
/// alla libreria su Drive e il termine vero di ogni permesso (docs/drive.md,
/// «La libreria condivisa»).
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';

/// Questo backend non ha la tabella, o non la lascia usare: la funzione non
/// c'è e non si offre.
class ShareUnavailable implements Exception {
  const ShareUnavailable();

  @override
  String toString() => 'La libreria condivisa non è disponibile su questo backend';
}

/// Questo backend non ha la colonna `download`: il permesso di scaricare non si
/// può concedere, e dirlo è meglio di una riga che sembra scritta.
class ShareDownloadUnavailable implements Exception {
  const ShareDownloadUnavailable();

  @override
  String toString() => 'Questo backend non sa ancora il permesso di scaricare';
}

/// Una riga di `drive_shares`: l'invito per [to] e fino a quando vale.
class DriveShare {
  const DriveShare({
    required this.id,
    required this.to,
    required this.from,
    required this.folderId,
    required this.folderName,
    required this.permissionId,
    required this.at,
    this.fromName,
    this.fromUid,
    this.expiresAt,
    this.download = false,
  });

  factory DriveShare.fromRow(Map<String, Object?> row) => DriveShare(
        id: row['id'] as String? ?? '',
        to: row['to_email'] as String? ?? '',
        from: row['from_email'] as String? ?? '',
        fromName: row['from_name'] as String?,
        fromUid: row['from_uid'] as String?,
        folderId: row['folder_id'] as String? ?? '',
        folderName: row['folder_name'] as String? ?? '',
        permissionId: row['permission_id'] as String? ?? '',
        at: DateTime.tryParse('${row['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        expiresAt: DateTime.tryParse('${row['expires_at']}'),
        download: row['download'] == true,
      );

  /// L'impronta che la tabella controlla: i primi 32 esadecimali di
  /// `sha256("<from>|<to>|<folderId>")`, indirizzi in minuscolo.
  static String shareId(String from, String to, String folderId) =>
      sha256.convert(utf8.encode('${from.toLowerCase()}|${to.toLowerCase()}|$folderId')).toString().substring(0, 32);

  final String id;
  final String to;
  final String from;
  final String? fromName;

  /// Chi condivide sul social (`from_uid`): è a lui che si scrive per chiedere
  /// più tempo. La scrive il backend, quindi non sta in [toRow].
  final String? fromUid;
  final String folderId;
  final String folderName;
  final String permissionId;
  final DateTime at;

  /// Il termine vero; vuoto se la condivisione non scade.
  final DateTime? expiresAt;

  /// Se chi riceve può anche scaricare, o solo leggere in streaming (FASE-5b §4).
  /// Un patto fra app, non una protezione. Una riga senza il campo (backend
  /// vecchio) è «solo streaming».
  final bool download;

  bool expiredAt(DateTime now) => expiresAt != null && !now.isBefore(expiresAt!);

  DriveShare copyWith({
    String? permissionId,
    DateTime? at,
    DateTime? expiresAt,
    bool clearExpiry = false,
    bool? download,
  }) =>
      DriveShare(
        id: id,
        to: to,
        from: from,
        fromName: fromName,
        fromUid: fromUid,
        folderId: folderId,
        folderName: folderName,
        permissionId: permissionId ?? this.permissionId,
        at: at ?? this.at,
        expiresAt: clearExpiry ? null : expiresAt ?? this.expiresAt,
        download: download ?? this.download,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'to_email': to,
        'from_email': from,
        'from_name': fromName,
        'folder_id': folderId,
        'folder_name': folderName,
        'permission_id': permissionId,
        'at': at.toUtc().toIso8601String(),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'download': download,
      };
}

/// Dove stanno le righe. L'app parla con questo, non con la tabella.
abstract interface class ShareDirectory {
  /// Scrive la riga, sostituendo quella con lo stesso `id`.
  Future<void> put(DriveShare share);

  /// Toglie la riga: chi non c'è non è un errore.
  Future<void> remove(String id);

  /// Le righe scritte da [email]. Una lettura fallita lancia e non torna mai
  /// una lista vuota.
  Future<List<DriveShare>> mine(String email);

  /// Le righe per [email], con lo stesso patto di [mine].
  Future<List<DriveShare>> forMe(String email);

  /// Un evento ogni volta che le righe per [email] possono essere cambiate
  /// (inviti e rinnovi, non i ritiri). Un canale che cade tace.
  Stream<void> changes(String email);
}

/// Esegue [run] traducendo «tabella assente o negata» in [ShareUnavailable];
/// ogni altro errore passa com'è.
Future<T> guardShares<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on Object catch (error) {
    if (backendFailure(error) == BackendFailure.unavailable) throw const ShareUnavailable();
    rethrow;
  }
}

class SupabaseShareDirectory implements ShareDirectory {
  const SupabaseShareDirectory({this.client});

  final SupabaseClient? client;

  static const String table = 'drive_shares';

  /// Come in `SupabaseInviteStore`: senza sessione il backend risponde
  /// «permesso negato» a tutto, che sarebbe letto come «tabella assente».
  SupabaseClient _session() {
    final active = client ?? backend;
    if (active == null || active.auth.currentSession == null) throw AuthSessionMissingException();
    return active;
  }

  @override
  Future<void> put(DriveShare share) =>
      guardShares(() => writeShareRow(share, (row) async => _session().from(table).upsert(row)));

  /// Scrive [share] con [write]. Un backend senza la colonna `download`
  /// (`PGRST204`, `42703`, o `42501` se non è concessa) rifiuta il campo: una
  /// riga «solo streaming» si riscrive senza, una che concede lo scaricare
  /// non si scrive e lancia [ShareDownloadUnavailable].
  @visibleForTesting
  static Future<void> writeShareRow(
    DriveShare share,
    Future<void> Function(Map<String, Object?> row) write,
  ) async {
    try {
      await write(share.toRow());
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST204' && error.code != '42703' && error.code != '42501') rethrow;
      if (share.download) throw const ShareDownloadUnavailable();
      await write(share.toRow()..remove('download'));
    }
  }

  @override
  Future<void> remove(String id) =>
      guardShares(() async => _session().from(table).delete().eq('id', id));

  Future<List<DriveShare>> _read(String column, String email) => guardShares(() async {
        final rows = await _session().from(table).select().eq(column, email.toLowerCase());
        return [for (final row in rows) DriveShare.fromRow(row)];
      });

  @override
  Future<List<DriveShare>> mine(String email) => _read('from_email', email);

  @override
  Future<List<DriveShare>> forMe(String email) => _read('to_email', email);

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
              .channel('drive_shares:${email.toLowerCase()}')
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

/// Le righe in memoria, per i test dell'app: stessa forma di
/// [SupabaseShareDirectory].
@visibleForTesting
class MemoryShareDirectory implements ShareDirectory {
  final Map<String, DriveShare> rows = {};

  /// Se impostato, ogni operazione lo lancia: la scrittura o la lettura che
  /// non è riuscita.
  Object? failure;

  /// Se impostato, solo [put] lo lancia.
  Object? putFailure;

  /// Simula un backend senza la colonna `download`: [put] di una riga che la
  /// concede lancia [ShareDownloadUnavailable], le altre si scrivono.
  bool withoutDownloadColumn = false;

  final List<String> log = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Un altro dispositivo ha scritto: chi ascolta rilegge.
  void notifyChanged() => _changes.add(null);

  void _check() {
    if (failure case final error?) throw error;
  }

  @override
  Future<void> put(DriveShare share) async {
    log.add('put ${share.id}');
    _check();
    if (putFailure case final error?) throw error;
    if (withoutDownloadColumn && share.download) throw const ShareDownloadUnavailable();
    rows[share.id] = share;
  }

  @override
  Future<void> remove(String id) async {
    log.add('remove $id');
    _check();
    rows.remove(id);
  }

  @override
  Future<List<DriveShare>> mine(String email) async {
    _check();
    return [for (final row in rows.values) if (row.from == email.toLowerCase()) row];
  }

  @override
  Future<List<DriveShare>> forMe(String email) async {
    _check();
    return [for (final row in rows.values) if (row.to == email.toLowerCase()) row];
  }

  @override
  Stream<void> changes(String email) => _changes.stream;
}
