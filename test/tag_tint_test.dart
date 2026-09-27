import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/ui/theme.dart';

void main() {
  test('lo stesso tag ha la stessa tinta, comunque sia scritto', () {
    expect(tagHue('Action'), tagHue('action'));
    expect(tagHue(' Action '), tagHue('action'));
    expect(tagHue('#romance'), tagHue('Romance'));
    expect(tagHue('action'), isNot(tagHue('romance')));
  });

  test('la tinta è fissata, non dipende dall\'avvio', () {
    // FNV-1a di «action»: se cambia, cambiano i colori di tutte le etichette
    // che l'utente ha già imparato a riconoscere.
    expect(tagHue('action'), 0xc4642eff % 360);
  });
}
