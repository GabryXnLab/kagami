/// I biglietti (`Authorization: Kagami-Ticket`, docs/server-api.md): chi
/// chiama non manda più il token della sessione, che varrebbe sul backend,
/// ma un biglietto che il backend ha rilasciato per l'id di questo server e
/// per un indirizzo che il suo proprietario ha garantito: l'id è pubblico, e
/// da solo lo potrebbe dichiarare un server che si spaccia per questo.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'config.dart';
import 'identity.dart';

/// L'id del server: 128 bit casuali, nati al primo avvio nella cartella dei
/// dati e tenuti finché c'è il volume. Non è un segreto: lo dichiara `GET /`.
Future<String> serverIdentity(ServerPaths paths) async {
  final file = File('${paths.root.path}/id');
  if (await file.exists()) {
    final id = (await file.readAsString()).trim();
    if (RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) return id;
  }
  final random = Random.secure();
  final id = [for (var i = 0; i < 16; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  await paths.root.create(recursive: true);
  await file.writeAsString(id, flush: true);
  return id;
}

/// Chiede al backend, con la sola chiave `anon`, di chi è un biglietto per
/// [audience] il cui indirizzo ha garantito [owner] (`kagami_ticket_who`), e
/// tiene l'esito fino al termine del biglietto.
class TicketVerifier implements IdentityVerifier {
  TicketVerifier(Uri url, this.anonKey, this.audience, String owner, {DateTime Function()? clock, this.cacheSize = 512})
      : _rpc = Uri.parse('${url.toString().replaceAll(RegExp(r'/+$'), '')}/rest/v1/rpc/kagami_ticket_who'),
        owner = owner.trim().toLowerCase(),
        _clock = clock ?? DateTime.now;

  final String anonKey;
  final String audience;

  /// Il proprietario di `KAGAMI_SETUP`: vale solo l'indirizzo che ha garantito lui.
  final String owner;
  final int cacheSize;
  final Uri _rpc;
  final DateTime Function() _clock;
  final LinkedHashMap<String, (Identity, DateTime)> _cache = LinkedHashMap();

  @override
  Future<Identity> verify(String ticket) async {
    // kagami_ticket ne fa da 96 cifre esadecimali: tutto il resto è falso, e non si chiede.
    if (!RegExp(r'^[0-9a-f]{64,128}$').hasMatch(ticket)) throw const IdentityError('Biglietto non valido.');
    final now = _clock();
    final hash = sha256.convert(utf8.encode(ticket)).toString();
    final cached = _cache[hash];
    if (cached != null && now.isBefore(cached.$2)) return cached.$1;

    final (email, expires) = await _ask(ticket);
    final who = Identity(email.trim().toLowerCase());
    _cache.removeWhere((_, entry) => !now.isBefore(entry.$2));
    while (_cache.length >= cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    if (now.isBefore(expires)) _cache[hash] = (who, expires);
    return who;
  }

  Future<(String, DateTime)> _ask(String ticket) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await http.postUrl(_rpc);
      final body = utf8.encode(jsonEncode({'ticket': ticket, 'audience': audience, 'owner': owner}));
      request.headers
        ..set('apikey', anonKey)
        ..set(HttpHeaders.authorizationHeader, 'Bearer $anonKey')
        ..contentType = ContentType.json;
      request.contentLength = body.length;
      request.add(body);
      final response = await request.close().timeout(const Duration(seconds: 20));
      final text = await utf8.decodeStream(response).timeout(const Duration(seconds: 20));
      // 404: il backend non ha la funzione (PGRST202), quindi non ha rilasciato questo biglietto.
      if (response.statusCode == HttpStatus.notFound) {
        throw const IdentityError('Il backend non rilascia biglietti: aggiorna l\'app o rifai l\'accesso.');
      }
      if (response.statusCode != HttpStatus.ok) {
        throw IdentityUnavailable('Il backend non risponde (${response.statusCode}): non posso verificare chi sei.');
      }
      final rows = jsonDecode(text);
      if (rows is! List) throw const FormatException('Non è un elenco');
      if (rows.isEmpty) {
        throw const IdentityError('Biglietto scaduto o non valido, o per un indirizzo che il proprietario '
            'non ha ancora collegato dalla sua app: rifai l\'accesso nell\'app.');
      }
      final row = rows.first;
      final email = row is Map ? row['email'] : null;
      final expires = row is Map ? DateTime.tryParse('${row['expires_at']}') : null;
      if (email is! String || email.trim().isEmpty || expires == null) throw const FormatException('Riga incompleta');
      return (email, expires);
    } on IdentityError {
      rethrow;
    } on IdentityUnavailable {
      rethrow;
    } on Exception {
      throw const IdentityUnavailable('Il backend non risponde: non posso verificare chi sei.');
    } finally {
      http.close(force: true);
    }
  }
}
