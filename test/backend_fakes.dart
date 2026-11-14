/// Il backend finto dei test: le interfacce di `backend.dart` tenute in
/// memoria, senza rete.
library;

import 'dart:async';

import 'package:kagami/src/data/backend.dart';
import 'package:kagami/src/data/invite_store.dart';
import 'package:kagami/src/data/server_access.dart';

/// La riga del lettore in memoria, condivisibile fra più «dispositivi».
class MemoryReaderStore implements ReaderStore {
  ReaderRow? row;

  /// Se impostato, [read] lo lancia: la lettura che non è riuscita.
  Object? readError;

  int reads = 0;
  int writes = 0;
  int deletes = 0;

  @override
  Future<ReaderRow?> read() async {
    reads++;
    if (readError case final error?) throw error;
    return row;
  }

  @override
  Future<void> write(ReaderRow row) async {
    writes++;
    this.row = row;
  }

  @override
  Future<void> delete() async {
    deletes++;
    row = null;
  }
}

/// Gli inviti in memoria: stessa forma di `SupabaseInviteStore`.
class MemoryInviteStore implements InviteStore {
  final Map<String, ServerInvite> invites = {};

  /// Se impostato, [listFor] lo lancia: la lettura che non è riuscita.
  Object? readError;

  int reads = 0;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Un altro dispositivo ha scritto: chi ascolta rilegge.
  void notifyChanged() => _changes.add(null);

  @override
  Future<void> put(ServerInvite invite) async => invites[invite.id] = invite;

  @override
  Future<void> remove(String id) async => invites.remove(id);

  @override
  Future<List<ServerInvite>> listFor(String email) async {
    reads++;
    if (readError case final error?) throw error;
    return [for (final invite in invites.values) if (invite.to == email.toLowerCase()) invite];
  }

  @override
  Stream<void> changes(String email) => _changes.stream;
}
