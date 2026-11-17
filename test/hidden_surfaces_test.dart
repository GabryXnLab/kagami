import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chi aggiunge una lista di serie all'interfaccia deve scegliere: o parte da
/// `shownSignalsProvider` (senza le raccolte nascoste) o entra qui col suo perché.
const _allowed = {
  'collections_screen.dart': 'dettaglio della raccolta: aprendola le serie nascoste si vedono',
  'collection_properties_sheet.dart': 'le serie della raccolta che si sta modificando, nascosta o no',
};

void main() {
  test('librarySignalsProvider solo dove la libreria intera serve davvero', () {
    final offenders = <String>[];
    for (final file in Directory('lib/src/ui').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final name = file.uri.pathSegments.last;
      if (_allowed.containsKey(name)) continue;
      if (file.readAsStringSync().contains('librarySignalsProvider')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'usa shownSignalsProvider, o aggiungi il file a _allowed con il motivo');
  });
}
