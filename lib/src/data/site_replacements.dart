/// Le sostituzioni di un sito incluso che l'utente ha confermato (FASE-8, T10).
///
/// Un file in `providers/` della libreria con lo stesso id di un sito incluso
/// ne prenderebbe il posto: chi condivide una libreria potrebbe così
/// dirottare i download e i cookie della verifica. Il sito della libreria vale
/// solo se l'utente ha confermato **quel** file (id e impronta); se il file
/// cambia, la conferma non vale più. Il file sta accanto alla coda, perché
/// lo legge anche il giro ad app chiusa, che il database non lo apre.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/providers.dart' show builtInProviders;

class SiteReplacements {
  SiteReplacements(this.file);

  final File file;

  /// Quale file di sito si è confermato: cambia se cambia anche un solo byte della definizione.
  static String fingerprint(DeclarativeProvider site) => sha256.convert(site.encode()).toString();

  /// Le conferme: id → impronta. Un file che non si legge vale «nessuna
  /// conferma», cioè restano i siti inclusi: è la direzione sicura.
  Future<Map<String, String>> read() async {
    try {
      final json = jsonDecode(await file.readAsString());
      return {
        if (json is Map<String, Object?>)
          for (final MapEntry(:key, :value) in json.entries)
            if (value is String) key: value,
      };
    } on Object {
      return {};
    }
  }

  Future<void> confirm(DeclarativeProvider site) async {
    final all = await read()..[site.id] = fingerprint(site);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(all), flush: true);
    await temporary.rename(file.path);
  }

  /// I siti di [sites] che sostituirebbero uno incluso senza una conferma.
  static List<DeclarativeProvider> unconfirmed(List<DeclarativeProvider> sites, Map<String, String> confirmed) => [
        for (final site in sites)
          if (builtInProviders.any((built) => built.id == site.id) && confirmed[site.id] != fingerprint(site)) site,
      ];

  /// I siti che il motore può usare: tutti, tranne quelli da [unconfirmed].
  static List<DeclarativeProvider> usable(List<DeclarativeProvider> sites, Map<String, String> confirmed) {
    final held = unconfirmed(sites, confirmed).map((site) => site.id).toSet();
    return [for (final site in sites) if (!held.contains(site.id)) site];
  }
}
