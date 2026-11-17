/// Cosa fa l'app quando un sito risponde con `ProviderChanged`: segnala a
/// Sentry quale variante si è rotta e, al più ogni 10 minuti, ricontrolla il
/// catalogo; se c'è una variante nuova di quel sito ritenta l'operazione una
/// volta (`docs/catalogo.md`, «Quando si ricontrolla»).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart' show providerById;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'catalog_sync.dart';

/// Il `ProviderChanged` di [site] alla versione [version] della definizione in
/// uso (`builtin` per i siti inclusi).
typedef ProviderChangedReport = void Function(ProviderChanged error, String site, String version);

/// I tag Sentry di un guasto: solo fase e campo; `detail` e `url` restano sul
/// telefono perché l'indirizzo può contenere la ricerca dell'utente.
Map<String, String> sentryTags(ProviderChanged error, String site, String version) {
  final fault = error.fault;
  return {
    'site': site,
    'version': version,
    if (fault != null) 'phase': fault.phase,
    if (fault?.field != null) 'field': fault!.field!,
  };
}

void reportToSentry(ProviderChanged error, String site, String version) {
  if (!Sentry.isEnabled) return;
  Sentry.captureException(
    error,
    withScope: (scope) async {
      for (final MapEntry(:key, :value) in sentryTags(error, site, version).entries) {
        await scope.setTag(key, value);
      }
    },
  );
}

class CatalogRecheck {
  CatalogRecheck({
    required this.sync,
    DateTime Function()? now,
    this.interval = const Duration(minutes: 10),
    this.report = reportToSentry,
  }) : _now = now ?? DateTime.now;

  final CatalogSync sync;
  final DateTime Function() _now;
  final Duration interval;
  final ProviderChangedReport report;

  /// Uno per processo, non per sito.
  DateTime? _last;

  String versionOf(String site) => switch (providerById(site)?.unwrapped) {
        final DeclarativeProvider provider => '${provider.version}',
        _ => 'builtin',
      };

  /// Segnala il guasto e, al più ogni [interval], ricontrolla il catalogo:
  /// `true` se c'è una variante nuova di [site].
  Future<bool> onChanged(String site, ProviderChanged error) async {
    report(error, site, versionOf(site));
    if (!sync.config.isConfigured) return false;
    final last = _last;
    if (last != null && _now().difference(last) < interval) return false;
    _last = _now();
    try {
      return await sync.refreshedVariant(site);
    } on Object {
      return false;
    }
  }

  /// Esegue [operation]; su `ProviderChanged` di [site] la segnala e, se il
  /// ricontrollo porta una variante nuova, la riesegue una volta sola.
  Future<T> guard<T>(String site, Future<T> Function() operation) async {
    try {
      return await operation();
    } on ProviderChanged catch (error) {
      if (!await onChanged(site, error)) rethrow;
      try {
        return await operation();
      } on ProviderChanged catch (again) {
        report(again, site, versionOf(site));
        rethrow;
      }
    }
  }
}

final catalogRecheckProvider = Provider<CatalogRecheck>((ref) => CatalogRecheck(sync: ref.watch(catalogSyncProvider)));
