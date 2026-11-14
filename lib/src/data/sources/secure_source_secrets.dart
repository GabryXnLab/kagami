/// Le password delle sorgenti nell'archivio sicuro del sistema (Keystore su
/// Android, Keychain su iOS): fuori dalle impostazioni, quindi mai nel
/// backup né nell'account.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'source.dart';

class SecureSourceSecrets implements SourceSecrets {
  SecureSourceSecrets([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String id) => 'kagami.source.$id';

  @override
  Future<String?> read(String id) => _storage.read(key: _key(id));

  @override
  Future<void> write(String id, String secret) =>
      _storage.write(key: _key(id), value: secret);

  @override
  Future<void> delete(String id) => _storage.delete(key: _key(id));
}
