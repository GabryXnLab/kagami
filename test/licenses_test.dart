import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/native_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('libsmb2 e OpenSSL compaiono con il testo integrale delle licenze', () async {
    registerNativeLicenses();
    final byPackage = <String, String>{};
    await for (final e in LicenseRegistry.licenses) {
      for (final p in e.packages) {
        byPackage[p] = e.paragraphs.map((x) => x.text).join('\n');
      }
    }
    expect(byPackage['libsmb2'], contains('GNU LESSER GENERAL PUBLIC LICENSE'));
    expect(byPackage['libsmb2'], contains('END OF TERMS AND CONDITIONS'));
    final openssl = byPackage['OpenSSL (libcrypto, inside libsmb2)'];
    expect(openssl, contains('Apache License'));
    expect(openssl, contains('END OF TERMS AND CONDITIONS'));
  });
}
