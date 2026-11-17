/// Le licenze del codice nativo che `dart_smb2` porta nell'app: la pagina
/// delle licenze di Flutter non le conosce (la nota di `dart_smb2` dice di
/// aggiungerle a mano, con l'indirizzo del sorgente corrispondente).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Il rilascio che `dart_smb2` 0.4.0 scarica in build (`libsmb2Release`):
/// va riletto quando si alza la dipendenza.
const String _release = 'libsmb2-r12';

const String _releases = 'https://github.com/ales-drnz/dart_smb2/releases/tag/$_release';
const String _scripts = 'https://github.com/ales-drnz/libsmb2-scripts';

void registerNativeLicenses() {
  LicenseRegistry.addLicense(() async* {
    // I testi integrali sono asset: la LGPL chiede di darli insieme al binario.
    final lgpl = await rootBundle.loadString('assets/licenses/LGPL-2.1.txt');
    final apache = await rootBundle.loadString('assets/licenses/Apache-2.0.txt');
    yield LicenseEntryWithLineBreaks(['libsmb2'], '''
libsmb2 — SMB2/3 client library
Copyright (C) Ronnie Sahlberg and the libsmb2 contributors
https://github.com/sahlberg/libsmb2

Licensed under the GNU Lesser General Public License, version 2.1 or (at your
option) any later version (https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html).

Kagami loads libsmb2 as a separate shared library (through dart_smb2), so it can
be replaced with another build. The binary shipped in this app is the one of the
$_release release; the corresponding source and the build scripts are at
$_scripts, and the release, with the license texts (COPYING and
LICENCE-LGPL-2.1.txt), is at $_releases

$lgpl''');
    yield LicenseEntryWithLineBreaks(['OpenSSL (libcrypto, inside libsmb2)'], '''
OpenSSL — cryptography library
Copyright (c) 1998-2026 The OpenSSL Project Authors
https://www.openssl.org

Licensed under the Apache License, version 2.0 (https://www.apache.org/licenses/LICENSE-2.0).
It is linked statically into libsmb2 to sign and encrypt SMB 3 traffic. The build
scripts and the license text (LICENSE-OpenSSL.txt) are at $_scripts and
$_releases

$apache''');
  });
}
