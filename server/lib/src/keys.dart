/// Le chiavi API: chi le presenta come `Authorization: Bearer …` parla col
/// server.
///
/// Una chiave sono 32 byte casuali, scritti una volta sola a chi la crea; il
/// server ne tiene l'impronta SHA-256, quindi chi legge `keys.json` non
/// ottiene chiavi da usare. Una per dispositivo, con un nome, così se ne
/// revoca una senza toccare le altre. È lo schema dei token personali di
/// GitHub o di Home Assistant.
///
/// Non c'è un limite ai tentativi: 256 bit casuali non si indovinano, e dietro
/// un proxy o Tailscale Funnel tutte le richieste arrivano dallo stesso
/// indirizzo, quindi un blocco per indirizzo chiuderebbe fuori anche il
/// proprietario.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/stores.dart';

import 'config.dart';

/// Il prefisso rende una chiave riconoscibile a chi la trova incollata da
/// qualche parte, e agli scanner di segreti.
const String keyPrefix = 'kagami_';

class ApiKey {
  const ApiKey({
    required this.id,
    required this.name,
    required this.hash,
    required this.createdAt,
    this.usedAt,
  });

  factory ApiKey.fromJson(Map<String, Object?> json) => ApiKey(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        hash: json['hash'] as String,
        createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
        usedAt: DateTime.tryParse('${json['usedAt']}'),
      );

  /// Le prime cifre dell'impronta: identificano la chiave senza rivelarla.
  final String id;
  final String name;
  final String hash;
  final DateTime createdAt;
  final DateTime? usedAt;

  ApiKey used(DateTime at) => ApiKey(id: id, name: name, hash: hash, createdAt: createdAt, usedAt: at);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'hash': hash,
        'createdAt': createdAt.toIso8601String(),
        'usedAt': ?usedAt?.toIso8601String(),
      };
}

class ApiKeys {
  ApiKeys(this.file);

  final File file;

  List<ApiKey>? _keys;
  DateTime? _read;

  /// L'ultimo uso si annota al più una volta l'ora: scriverlo a ogni
  /// richiesta sarebbe una scrittura su disco per ogni sguardo alla coda.
  static const Duration _usedEvery = Duration(hours: 1);

  /// Le chiavi, rilette se il file è cambiato: `key revoke` dalla riga di
  /// comando vale subito anche per il server acceso.
  Future<List<ApiKey>> list() async {
    final modified = await file.exists() ? await file.lastModified() : null;
    if (_keys == null || modified != _read) {
      _keys = [
        for (final row in ((await readJsonFile(file))?['keys'] as List? ?? const [])
            .whereType<Map<String, Object?>>())
          ApiKey.fromJson(row),
      ];
      _read = modified;
    }
    return _keys!;
  }

  Future<void> _save(List<ApiKey> keys) async {
    await writeSecret(
      file,
      const JsonEncoder.withIndent('  ').convert({'keys': [for (final key in keys) key.toJson()]}),
    );
    _keys = keys;
    _read = await file.lastModified();
  }

  /// Crea una chiave e la restituisce in chiaro: è l'unica volta.
  Future<(ApiKey, String)> create(String name) async {
    final random = Random.secure();
    final secret = keyPrefix +
        base64Url.encode([for (var i = 0; i < 32; i++) random.nextInt(256)]).replaceAll('=', '');
    final hash = _hash(secret);
    final key = ApiKey(id: hash.substring(0, 8), name: name, hash: hash, createdAt: DateTime.now());
    await _save([...await list(), key]);
    return (key, secret);
  }

  /// Toglie la chiave con questo id o questo nome. Dice se c'era.
  Future<bool> revoke(String idOrName) async {
    final keys = await list();
    final rest = [for (final key in keys) if (key.id != idOrName && key.name != idOrName) key];
    if (rest.length == keys.length) return false;
    await _save(rest);
    return true;
  }

  /// La chiave che [presented] apre, o `null`.
  Future<ApiKey?> verify(String presented) async {
    final hash = _hash(presented);
    ApiKey? found;
    // Si confrontano tutte, sempre per intero: il tempo della risposta non
    // deve dire quanto una chiave falsa somigli a una vera.
    for (final key in await list()) {
      if (_same(key.hash, hash)) found = key;
    }
    if (found == null) return null;
    final now = DateTime.now();
    final used = found.usedAt;
    if (used == null || now.difference(used) > _usedEvery) {
      await _save([for (final key in await list()) key.id == found.id ? key.used(now) : key]);
    }
    return found;
  }

  static String _hash(String secret) => sha256.convert(utf8.encode(secret)).toString();

  static bool _same(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Il link che l'app accetta incollato: indirizzo del server e chiave in un
/// colpo solo, per non doverli copiare a mano uno per uno.
Uri pairingLink(Uri server, String secret) => Uri(
      scheme: 'kagami',
      host: 'server',
      queryParameters: {'url': '$server', 'key': secret},
    );
