/// La riga del lettore su un backend compatibile Supabase: la tabella
/// `readers` dello schema in `backend/`.
library;

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';

class SupabaseReaderStore implements ReaderStore {
  /// [client] `null` è una build senza backend: ogni richiesta è «senza
  /// accesso», come se nessuno fosse entrato.
  SupabaseReaderStore(this.client);

  static const String table = 'readers';

  final SupabaseClient? client;

  /// L'`id` della riga letta per ultima, e di chi: chi arriva da un altro
  /// backend ha una riga importata con l'`id` di allora, e scriverne una col
  /// proprio ne farebbe due.
  ({String owner, String id})? _row;

  /// Chi ha fatto l'accesso. Si controlla prima di chiedere: senza sessione
  /// il backend risponde «permesso negato» a tutto, che [backendFailure]
  /// leggerebbe come «tabella non disponibile».
  (SupabaseClient, String) _session() {
    final client = this.client;
    final user = client?.auth.currentSession?.user;
    if (client == null || user == null) throw AuthSessionMissingException();
    return (client, user.id);
  }

  @override
  Future<ReaderRow?> read() async {
    final (client, owner) = _session();
    final rows = await client
        .from(table)
        .select('id, data')
        .eq('owner', owner)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) {
      _row = null;
      return null;
    }
    final row = rows.first;
    _row = (owner: owner, id: row['id'] as String);
    final data = row['data'];
    final payload = data is Map ? data['payload'] : null;
    if (payload == null) return null;
    // Un payload che non si decodifica non è «vuoto»: chi lo prendesse per
    // tale scriverebbe sopra ai dati di un altro dispositivo.
    if (payload is! String) {
      throw const FormatException('readers.data.payload non è base64');
    }
    return ReaderRow(
      payload: base64Decode(payload),
      revision: '${(data as Map)['revision'] ?? ''}',
      device: data['device'] as String?,
    );
  }

  @override
  Future<void> write(ReaderRow row) async {
    final (client, owner) = _session();
    final known = _row;
    final id = known != null && known.owner == owner ? known.id : owner;
    // `owner` e `updated_at` li mette il backend: il primo dalla sessione, il
    // secondo dal suo orologio, che non è quello sbagliato di un telefono.
    await client.from(table).upsert({
      'id': id,
      'data': {
        'payload': base64Encode(row.payload),
        'revision': row.revision,
        'device': ?row.device,
      },
    });
    _row = (owner: owner, id: id);
  }

  @override
  Future<void> delete() async {
    final (client, owner) = _session();
    await client.from(table).delete().eq('owner', owner);
    _row = null;
  }
}
