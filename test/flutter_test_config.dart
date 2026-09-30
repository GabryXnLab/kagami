import 'dart:async';
import 'dart:ui';

import 'package:kagami/src/l10n.dart';

/// I test confrontano i testi italiani, l'originale: senza fissare la lingua
/// seguirebbero quella della macchina che li fa girare.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  appLocale = const Locale('it');
  await testMain();
}
