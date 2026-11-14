/// La sessione del backend nell'archivio sicuro (FASE-8, T17).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/backend.dart';
import 'package:kagami/src/data/backend_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'sb-backend-auth-token';
const _session = '{"refresh_token":"segreto"}';

class _BrokenSecure extends FlutterSecureStorage {
  const _BrokenSecure();

  @override
  Future<String?> read({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async =>
      throw StateError('Keystore non disponibile');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la chiave è quella di supabase_flutter', () {
    expect(persistSessionKeyFor('https://backend.example.com'), _key);
  });

  test('la sessione delle preferenze passa nell\'archivio sicuro e la copia in chiaro sparisce', () async {
    SharedPreferences.setMockInitialValues({_key: _session});
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureSessionStorage(persistSessionKey: _key);

    await storage.initialize();

    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), _session);
    expect(await const FlutterSecureStorage().read(key: _key), _session);
    expect((await SharedPreferences.getInstance()).containsKey(_key), isFalse);
  });

  test('una sessione nuova va solo nell\'archivio sicuro, e uscire la toglie', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureSessionStorage(persistSessionKey: _key);
    await storage.initialize();
    expect(await storage.hasAccessToken(), isFalse);

    await storage.persistSession(_session);
    expect(await const FlutterSecureStorage().read(key: _key), _session);
    expect((await SharedPreferences.getInstance()).containsKey(_key), isFalse);

    await storage.removePersistedSession();
    expect(await const FlutterSecureStorage().read(key: _key), isNull);
    expect(await storage.hasAccessToken(), isFalse);
  });

  test('una lettura fallita non è «nessuna sessione»: resta quella di prima e niente si cancella', () async {
    SharedPreferences.setMockInitialValues({_key: _session});
    final storage = SecureSessionStorage(persistSessionKey: _key, storage: const _BrokenSecure());

    await storage.initialize();

    expect(await storage.accessToken(), _session);
    expect((await SharedPreferences.getInstance()).getString(_key), _session);
    // L'uscita che supabase annuncia all'avvio senza sessione non cancella ciò che non si è visto.
    await storage.removePersistedSession();
    expect((await SharedPreferences.getInstance()).getString(_key), _session);
  });
}
