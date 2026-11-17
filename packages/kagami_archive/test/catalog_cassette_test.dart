// Ogni definizione di catalog/sites/ riprodotta su ogni sua cassetta con expect.json.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/check.dart';

void main() {
  final sites = Directory('../../catalog/sites');
  for (final def in sites.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path))) {
    final id = p.basenameWithoutExtension(def.path);
    final root = Directory('test/fixtures/sites/$id');
    final cassettes = !root.existsSync()
        ? <Directory>[]
        : (root.listSync().whereType<Directory>().where((d) => File('${d.path}/expect.json').existsSync()).toList()
          ..sort((a, b) => a.path.compareTo(b.path)));
    group(id, () {
      for (final dir in cassettes) {
        test(p.basename(dir.path), () async {
          final out = StringBuffer();
          final code = await runCheck(CheckOptions(definition: def.path, replay: dir.path), out);
          expect(code, 0, reason: out.toString());
          expect(out.toString(), isNot(contains('DIFFERENZA')));
        });
      }
    });
  }
  // I temi di catalog/themes/ provati su un sito campione (fuori dal catalogo): la definizione
  // piatta è quella che si pubblicherebbe, e il replay la rifà sulle cassette del campione.
  group('tema', () {
    final themes = Directory('../../catalog/themes');
    final samples = Directory('test/fixtures/themes')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final sample in samples) {
      final id = p.basenameWithoutExtension(sample.path);
      final root = Directory('test/fixtures/sites/$id');
      final cassettes = root
          .listSync()
          .whereType<Directory>()
          .where((d) => File('${d.path}/expect.json').existsSync())
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      test('$id ha una cassetta', () => expect(cassettes, isNotEmpty));
      for (final dir in cassettes) {
        test('$id ${p.basename(dir.path)}', () async {
          final out = StringBuffer();
          final code = await runCheck(
            CheckOptions(definition: sample.path, replay: dir.path, themes: themes.path),
            out,
          );
          expect(code, 0, reason: out.toString());
          expect(out.toString(), isNot(contains('DIFFERENZA')));
        });
      }
    }
  });
}
