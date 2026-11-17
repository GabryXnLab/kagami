/// Prova di adozione e ripiego sulla cartella pubblicata da `catalog.dart build|sign`
/// (usata da `scripts/agent/prova-riparazione.sh`, nessuna rete):
///
/// ```text
///   dart run tool/adopt.dart <uscita> --keys '<CATALOG_KEYS>' --site <id>
/// ```
///
/// 1. adotta il catalogo con adoptCatalog e controlla che il sito valga come «catalogo» col ripiego
///    sull'incluso con lo stesso id;
/// 2. rovina di un byte il file del sito (copia temporanea): l'adozione tiene l'incluso.
library;

import 'dart:io';

import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/fallback.dart';
import 'package:kagami_archive/providers.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.length != 5 || args[1] != '--keys' || args[3] != '--site') {
    stderr.writeln("Uso: adopt.dart <uscita> --keys '<CATALOG_KEYS>' --site <id>");
    exit(2);
  }
  final dir = args[0];
  final id = args[4];
  final keys = parseCatalogKeys(args[2]);
  if (keys.isEmpty) _fail('nessuna chiave valida in --keys');

  Future<CatalogAdoption> adopt(String from) => adoptCatalog(
        previous: null,
        indexBytes: File(p.join(from, 'index.json')).readAsBytesSync(),
        signatureBytes: File(p.join(from, 'index.sig')).readAsBytesSync(),
        keys: keys,
        fetchSite: (path) async {
          final f = File(p.join(from, path));
          return f.existsSync() ? f.readAsBytesSync() : null;
        },
      );

  final good = await adopt(dir);
  if (good.outcome != CatalogOutcome.adopted) _fail('adozione: ${good.outcome} ${good.detail ?? ''}');
  if (good.catalog!.definitions[id] == null) _fail('il catalogo non ha una definizione per $id');
  installCatalogProviders(catalogProviders(good.catalog!));
  final active = providerById(id)!;
  if (active.origin != ProviderOrigin.catalog) _fail('$id vale ${active.origin}, non il catalogo');
  if (active is! FallbackProvider) _fail('$id è senza ripiego sull\'incluso');
  stdout.writeln('adozione: $id dal catalogo (serial ${good.serial}) con ripiego sull\'incluso');

  // Un file del sito che non torna con la sua impronta non entra: vale l'incluso.
  final broken = Directory.systemTemp.createTempSync('adopt_');
  try {
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
      final target = File(p.join(broken.path, p.relative(f.path, from: dir)))..createSync(recursive: true);
      target.writeAsBytesSync(f.readAsBytesSync());
    }
    final matches = Directory(p.join(broken.path, 'sites')).listSync().whereType<File>().where((f) => p.basename(f.path).startsWith('$id-')).toList();
    if (matches.isEmpty) _fail('file del sito $id non trovato nell\'uscita');
    final file = matches.first;
    file.writeAsStringSync('${file.readAsStringSync()} ');
    final bad = await adopt(broken.path);
    installCatalogProviders(bad.catalog == null ? const [] : catalogProviders(bad.catalog!));
    final after = providerById(id)!;
    if (after.origin != ProviderOrigin.builtIn) _fail('con il file alterato $id vale ${after.origin}, non l\'incluso');
    stdout.writeln('ripiego: file alterato scartato, $id torna all\'incluso');
  } finally {
    broken.deleteSync(recursive: true);
    installCatalogProviders(const []);
  }
}

Never _fail(String message) {
  stderr.writeln('adopt: $message');
  exit(1);
}
