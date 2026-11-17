/// La salute dei siti: quali provider non funzionano più per intero.
///
/// Una serie che fallisce è un problema della serie ([TrackedSeries.problem]);
/// un sito che cambia forma fa fallire tutte le sue serie nello stesso modo, e
/// ritentarle una per una è solo rumore. Qui il sito si dichiara rotto una
/// volta, e ripartono i suoi lavori quando un successo lo dichiara sano. È
/// stato di chi legge i siti (telefono o server), accanto a `ongoing.json`.
library;

import 'dart:convert';
import 'dart:io';

import 'http.dart';
import 'model.dart';
import 'stores.dart';

class SiteHealth {
  const SiteHealth({required this.broken, required this.message, required this.since, required this.checkedAt});

  factory SiteHealth.fromJson(Map<String, Object?> json) => SiteHealth(
        broken: json['broken'] == true,
        message: json['message'] as String? ?? '',
        since: DateTime.tryParse('${json['since']}') ?? DateTime.now(),
        checkedAt: DateTime.tryParse('${json['checkedAt']}') ?? DateTime.now(),
      );

  final bool broken;

  /// L'errore tecnico che ha fatto dichiarare rotto il sito.
  final String message;

  /// Da quando il sito è in questo stato.
  final DateTime since;

  /// L'ultima volta che l'errore (o il successo) è stato visto.
  final DateTime checkedAt;

  Map<String, Object?> toJson() => {
        'broken': broken,
        'message': message,
        'since': since.toIso8601String(),
        'checkedAt': checkedAt.toIso8601String(),
      };
}

class HealthLog {
  HealthLog(this.file);

  final File file;

  Future<Map<String, SiteHealth>> load() async {
    final json = await readJsonFile(file);
    final sites = json?['sites'];
    return {
      if (sites is Map)
        for (final MapEntry(:key, :value) in sites.entries)
          if (key is String && value is Map<String, Object?>) key: SiteHealth.fromJson(value),
    };
  }

  Future<void> _save(Map<String, SiteHealth> sites) => writeAtomically(
        file,
        utf8.encode(jsonEncode({'sites': {for (final MapEntry(:key, :value) in sites.entries) key: value.toJson()}})),
      );

  Future<bool> isBroken(String site) async => (await load())[site]?.broken ?? false;

  Future<void> markBroken(String site, String message) async {
    final sites = await load();
    final previous = sites[site];
    final now = DateTime.now();
    sites[site] = SiteHealth(
      broken: true,
      message: message,
      since: previous != null && previous.broken ? previous.since : now,
      checkedAt: now,
    );
    await _save(sites);
  }

  /// Un successo dal sito: se era rotto torna sano; se non lo era non si
  /// scrive niente.
  Future<void> markHealthy(String site) async {
    final sites = await load();
    final previous = sites[site];
    if (previous == null || !previous.broken) return;
    final now = DateTime.now();
    sites[site] = SiteHealth(broken: false, message: '', since: now, checkedAt: now);
    await _save(sites);
  }
}

/// La salute dei siti vista da un solo controllo: un [ProviderChanged]
/// dichiara rotto il sito, un successo lo dichiara sano, e se tutte le
/// serie di un sito (almeno due) falliscono senza che nessuna riesca, è il
/// sito.
class SiteWatch {
  SiteWatch(this.log);

  final HealthLog log;
  final Map<String, ({int ok, int failed, String message})> _seen = {};

  Future<void> succeeded(String site) async {
    final seen = _seen[site];
    _seen[site] = (ok: (seen?.ok ?? 0) + 1, failed: seen?.failed ?? 0, message: seen?.message ?? '');
    await log.markHealthy(site);
  }

  Future<void> failed(String site, ProviderError error) async {
    if (error is ProviderOffline || error is CloudflareChallenge) return;
    if (error is ProviderChanged) {
      await log.markBroken(site, error.message);
      return;
    }
    // Un sito che risponde male per un momento non è un sito cambiato.
    if (error is HttpStatusError && (error.status == 429 || error.status >= 500)) return;
    final seen = _seen[site];
    _seen[site] = (ok: seen?.ok ?? 0, failed: (seen?.failed ?? 0) + 1, message: seen?.message ?? error.message);
  }

  /// Chiude il controllo: i siti in cui nessuna serie è riuscita.
  Future<void> finish() async {
    for (final MapEntry(:key, :value) in _seen.entries) {
      if (value.ok == 0 && value.failed >= 2) await log.markBroken(key, value.message);
    }
  }
}
