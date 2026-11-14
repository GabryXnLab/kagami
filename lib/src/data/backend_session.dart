/// La sessione del backend nell'archivio sicuro del sistema (Keystore su
/// Android, Keychain su iOS) invece che nelle preferenze, che sono un file in
/// chiaro (FASE-8, T17): contiene il refresh token dell'account.
///
/// Chi era già dentro resta dentro: alla prima apertura la sessione delle
/// preferenze passa nell'archivio sicuro e solo dopo averla riletta da lì la
/// copia in chiaro si toglie. Una lettura che fallisce non è «non c'è
/// sessione»: si usa la copia vecchia, se c'è, e non si cancella niente.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show LocalStorage;

class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required this.persistSessionKey,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _secure = storage;

  /// La stessa chiave di `supabase_flutter`, perché la migrazione trovi la sessione di prima.
  final String persistSessionKey;
  final FlutterSecureStorage _secure;
  late SharedPreferences _preferences;

  String? _session;
  bool _readFailed = false;

  @override
  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final legacy = _preferences.getString(persistSessionKey);
    try {
      _session = await _secure.read(key: persistSessionKey);
    } on Object {
      // Non ho potuto chiedere: la copia di prima, se c'è, tiene dentro l'utente.
      _readFailed = true;
      _session = legacy;
      return;
    }
    if (_session == null && legacy != null) {
      try {
        await _secure.write(key: persistSessionKey, value: legacy);
        if (await _secure.read(key: persistSessionKey) != legacy) return;
      } on Object {
        _session = legacy;
        return;
      }
      _session = legacy;
    }
    if (legacy != null) await _preferences.remove(persistSessionKey);
  }

  @override
  Future<bool> hasAccessToken() async => _session != null;

  @override
  Future<String?> accessToken() async => _session;

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _secure.write(key: persistSessionKey, value: persistSessionString);
    _session = persistSessionString;
    _readFailed = false;
    await _preferences.remove(persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    _session = null;
    // Se non si è potuto leggere, l'«uscita» che supabase annuncia all'avvio
    // senza sessione non è una scelta dell'utente: non si cancella ciò che non si è visto.
    if (_readFailed) return;
    await _secure.delete(key: persistSessionKey);
    await _preferences.remove(persistSessionKey);
  }
}
