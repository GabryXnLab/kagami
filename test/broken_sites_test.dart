// Un sito rotto si dice una volta, con il messaggio tecnico sotto.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/archive_flow.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami_archive/health.dart';

void main() {
  testWidgets('la scheda dei siti rotti nomina il sito e mostra il messaggio tecnico', (tester) async {
    final now = DateTime.utc(2026, 10, 28);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        brokenSitesProvider.overrideWith(
          (ref) async => {
            'coffeemanga': SiteHealth(broken: true, message: 'Serie Coffee Manga non trovata.', since: now, checkedAt: now),
          },
        ),
      ],
      child: MaterialApp(
        theme: kagamiTheme(Brightness.light),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: BrokenSitesCard()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Il sito Coffee Manga non funziona: è cambiato e Kagami va aggiornato.'), findsOneWidget);
    expect(find.text('Serie Coffee Manga non trovata.'), findsOneWidget);
  });
}
