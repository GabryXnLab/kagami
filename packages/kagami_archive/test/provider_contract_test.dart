// Ciò che ogni sito registrato deve avere perché app e server lo trattino
// come gli altri: un sito nuovo che dimentica un pezzo si ferma qui, non
// sul telefono di qualcuno.
import 'dart:io';

import 'package:kagami_archive/providers.dart';
import 'package:test/test.dart';

void main() {
  test('id unici, fatti per una chiave MALF e per un nome di cartella', () {
    final ids = [for (final provider in providers) provider.id];
    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[a-z0-9]+$')), reason: id);
    }
  });

  for (final provider in providers) {
    group(provider.name, () {
      test('l\'icona sta fra gli asset dell\'app', () {
        // I test girano dalla cartella del pacchetto; gli asset sono dell'app.
        expect(File('../../${provider.icon}').existsSync(), isTrue, reason: provider.icon);
      });

      test('la pagina principale è sua e il link di una serie lo riconosce solo lui', () {
        expect(() => provider.validateUrl(provider.home), returnsNormally);
        expect(provider.accepts(provider.home), isFalse);
        expect(providerById(provider.id), same(provider));
      });

      test('la verifica del browser, se c\'è, è sui suoi host', () {
        final gate = provider.browser;
        expect(provider.needsBrowser, gate != null);
        for (final host in gate?.hosts ?? const <String>[]) {
          expect(provider.allowedHost(Uri.https(host, '/')), isTrue, reason: host);
        }
      });
    });
  }
}
