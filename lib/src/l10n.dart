/// Le lingue dell'interfaccia e il modo di raggiungerle.
///
/// I testi stanno nei file ARB di `lib/l10n/`: l'originale è `app_it.arb`, le
/// altre lingue ne sono traduzioni, e `flutter gen-l10n` (o `flutter pub get`)
/// ne genera `AppLocalizations`.
library;

import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// Il nome di ogni lingua nella lingua stessa: chi non capisce quella attuale
/// deve comunque riconoscere la propria nell'elenco.
const Map<String, String> languageNames = {
  'it': 'Italiano',
  'en': 'English',
  'zh': '中文',
  'hi': 'हिन्दी',
  'es': 'Español',
  'ar': 'العربية',
  'fr': 'Français',
  'pt': 'Português',
  'ja': '日本語',
};

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// La lingua scelta, per chi non ha un `BuildContext`: notifiche, giri senza
/// schermo, messaggi costruiti nei provider. La tiene aggiornata `KagamiApp`;
/// finché nessuno l'ha impostata vale quella del sistema.
Locale? appLocale;

AppLocalizations currentL10n() => lookupAppLocalizations(
  basicLocaleListResolution(
    [?appLocale, ...PlatformDispatcher.instance.locales],
    AppLocalizations.supportedLocales,
  ),
);
