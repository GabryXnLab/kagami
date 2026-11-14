/// I messaggi del motore sono in italiano; a schermo i casi noti vanno nella
/// lingua dell'utente, con testi nelle nove lingue.
library;

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/server_error_text.dart';
import 'package:kagami/src/l10n.dart';
import 'package:kagami_archive/remote.dart' show ServerException;

void main() {
  const codes = ['update_server', 'tickets_unavailable', 'impostor', 'other_server', 'not_owner'];

  test('ogni codice noto ha un testo diverso dal messaggio italiano, in tutte le lingue', () {
    for (final locale in AppLocalizations.supportedLocales) {
      appLocale = locale;
      final seen = <String>{};
      for (final code in codes) {
        final text = serverErrorText(ServerException('messaggio del motore', code: code, status: 403));
        expect(text, isNot('messaggio del motore'), reason: '$locale $code');
        expect(text, isNotEmpty);
        seen.add(text);
      }
      expect(seen.length, codes.length, reason: 'ogni codice ha il suo testo in $locale');
    }
    appLocale = null;
  });

  test('un codice sconosciuto resta il messaggio del server', () {
    expect(serverErrorText(const ServerException('Coda piena.', code: 'queue_full')), 'Coda piena.');
    expect(serverErrorText(const ServerException('Il server non risponde.')), 'Il server non risponde.');
  });

  test('i testi in lingua diversa dall\'italiano non sono quello italiano', () {
    appLocale = const Locale('en');
    expect(serverErrorText(const ServerException('x', code: 'not_owner')), contains('Drive folder'));
    appLocale = null;
  });

  test('il foglio del collegamento dice che chi gestisce il server scrive nel Drive, in ogni lingua', () {
    final italian = lookupAppLocalizations(const Locale('it')).serverLinkTrust;
    for (final locale in AppLocalizations.supportedLocales.where((l) => l.languageCode != 'it')) {
      expect(lookupAppLocalizations(locale).serverLinkTrust, isNot(italian), reason: '$locale');
    }
  });
}
