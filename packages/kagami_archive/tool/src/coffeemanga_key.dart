/// `site.dart coffeemanga-key`: la chiave del manifest di Coffee Manga, ricavata
/// dal bundle JavaScript con lo stesso codice del provider Dart (`coffeeMangaKey`),
/// da scrivere come costante in `catalog/sites/coffeemanga.json`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers/coffeemanga.dart';

import 'har.dart' show HarError;

const String coffeeKeyUsage = 'Uso: site.dart coffeemanga-key <bundle.js | --live>';

/// Stampa la chiave in esadecimale. Con `--live` chiede la pagina principale, ne
/// prende il bundle come fa il provider e lo legge; [http] sostituisce la rete nei test.
Future<int> runCoffeeMangaKey(List<String> args, StringSink out, {ProviderHttp? http}) async {
  if (args.length != 1) throw const HarError(coffeeKeyUsage);
  final String source;
  if (args.single == '--live') {
    final provider = CoffeeManga();
    final live = http == null ? SiteHttp(provider.allowedHost, attempts: 2, publicOnly: true) : null;
    final client = http ?? live!;
    try {
      final page = utf8.decode((await client.get('${provider.home}/')).body, allowMalformed: true);
      final bundle = coffeeMangaBundle(page);
      out.writeln('# $bundle');
      source = utf8.decode((await client.get(bundle, limit: 8000000)).body, allowMalformed: true);
    } on ProviderError catch (error) {
      throw HarError('Coffee Manga: ${error.message}');
    } finally {
      live?.close();
    }
  } else {
    final file = File(args.single);
    if (!file.existsSync()) throw HarError('${args.single} non si legge.');
    source = file.readAsStringSync();
  }
  final Uint8List key;
  try {
    key = coffeeMangaKey(source);
  } on ProviderError {
    throw const HarError('TE() non trovata o cambiata nel bundle: la chiave non si ricava.');
  }
  out.writeln([for (final byte in key) byte.toRadixString(16).padLeft(2, '0')].join());
  return 0;
}
