/// Il catalogo dei siti sul telefono: cache in `catalog/` della cartella di
/// supporto, recupero in rete e installazione nel motore (`docs/catalogo.md`,
/// «Adozione» e «Cache»).
///
/// Adozione, non sovrascrittura: una lettura fallita (rete, firma, indice
/// illeggibile) lascia il catalogo di prima. Le regole di adozione stanno in
/// `adoptCatalog` (pacchetto); qui ci sono solo il disco e la rete.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/providers.dart' show installCatalogProviders;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';
import 'catalog_config.dart';

/// Una risposta di [CatalogFetch]; `304` ha [bytes] vuoti.
class CatalogReply {
  const CatalogReply({required this.status, this.bytes = const [], this.etag});

  final int status;
  final List<int> bytes;
  final String? etag;
}

/// `GET` di [url] con al più [maxBytes] di corpo. Lancia se la rete non va o il
/// corpo supera il tetto (nel quale caso l'indirizzo vale come irraggiungibile).
typedef CatalogFetch = Future<CatalogReply> Function(Uri url, {String? ifNoneMatch, required int maxBytes});

const Duration _timeout = Duration(seconds: 15);

Future<CatalogReply> fetchCatalogFile(Uri url, {String? ifNoneMatch, required int maxBytes}) async {
  final client = HttpClient()..connectionTimeout = _timeout;
  try {
    final request = await client.getUrl(url).timeout(_timeout);
    if (ifNoneMatch != null) request.headers.set(HttpHeaders.ifNoneMatchHeader, ifNoneMatch);
    final response = await request.close().timeout(_timeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return CatalogReply(status: response.statusCode);
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(_timeout)) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) throw const FormatException('Risposta oltre il tetto.');
    }
    return CatalogReply(status: 200, bytes: bytes, etag: response.headers.value(HttpHeaders.etagHeader));
  } finally {
    client.close(force: true);
  }
}

/// Com'è il catalogo adesso, per chi lo mostra (pagina Siti).
class CatalogStatus {
  const CatalogStatus({this.serial = 0, this.issuedAt, this.sites = const {}, this.lastCheck, this.enabled = true});

  /// L'interruttore «usa il catalogo» della pagina Siti; spento, il catalogo non
  /// è installato e `serial` vale `0`.
  final bool enabled;

  /// `0` senza catalogo adottato.
  final int serial;
  final DateTime? issuedAt;

  /// Per id di sito dell'ultimo indice adottato in questa sessione; per quello
  /// letto dalla cache, solo `state` e `message` dell'indice.
  final Map<String, CatalogSiteResult> sites;
  final DateTime? lastCheck;

  bool get hasCatalog => serial > 0 || issuedAt != null;
}

class CatalogSync {
  CatalogSync({required this.directory, required this.config, CatalogFetch? fetch, DateTime Function()? now})
      : _fetch = fetch ?? fetchCatalogFile,
        _now = now ?? DateTime.now;

  /// `catalog/` nella cartella di supporto.
  final Directory directory;
  final CatalogConfig config;
  final CatalogFetch _fetch;
  final DateTime Function() _now;

  /// Spento dall'utente (pagina Siti): nessuna lettura e nessuna richiesta.
  bool enabled = true;

  bool get _active => config.isConfigured && enabled;

  File _file(String name) => File(p.join(directory.path, name));
  File _site(String sha) => File(p.join(directory.path, 'sites', '$sha.json'));

  /// Il catalogo in cache, o `null` se non c'è o è guasto (allora valgono gli
  /// inclusi finché il recupero non riesce).
  Future<({AdoptedCatalog catalog, CatalogStatus status})?> loadCache() async {
    try {
      final index = await _file('index.json').readAsBytes();
      final state = jsonDecode(await _file('state.json').readAsString()) as Map<String, Object?>;
      final parsed = CatalogIndex.parse(index);
      final definitions = <String, CatalogDefinition>{};
      final saved = state['definitions'] as Map<String, Object?>? ?? const {};
      for (final MapEntry(key: id, value: raw) in saved.entries) {
        final entry = raw as Map<String, Object?>;
        final sha = entry['sha256'] as String;
        final version = entry['version'] as int;
        final File file = _site(sha);
        if (!await file.exists()) continue;
        definitions[id] = CatalogDefinition(text: await file.readAsString(), sha256: sha, version: version);
      }
      final catalog = AdoptedCatalog(serial: parsed.serial, indexBytes: index, definitions: definitions);
      final checked = state['lastCheck'] as String?;
      return (
        catalog: catalog,
        status: CatalogStatus(
          serial: parsed.serial,
          issuedAt: parsed.issuedAt,
          lastCheck: checked == null ? null : DateTime.tryParse(checked),
          sites: {
            for (final site in parsed.sites.values)
              site.id: CatalogSiteResult(state: site.state, message: site.message, definition: definitions[site.id]),
          },
        ),
      );
    } on Object {
      return null;
    }
  }

  /// Installa nel motore i siti di [catalog]; quelli che non si leggono più si
  /// saltano (vale l'incluso).
  void install(AdoptedCatalog catalog) {
    try {
      installCatalogProviders(catalogProviders(catalog));
    } on CatalogFormatError {
      // Cache guasta: restano i siti di prima.
    }
  }

  /// Cache, poi rete: installa subito ciò che c'è in cache e prova ad
  /// aggiornarlo. Senza configurazione non fa niente, nemmeno leggere il disco.
  Future<CatalogStatus?> start({void Function(CatalogStatus status)? onCached}) async {
    if (!_active) return null;
    final cached = await loadCache();
    if (cached != null) {
      install(cached.catalog);
      onCached?.call(cached.status);
    }
    return await refresh(previous: cached?.catalog) ?? cached?.status;
  }

  /// Il passo di rete di «Adozione»: gli indirizzi in ordine, il primo che dà un
  /// indice buono vince. `null` se non c'è niente di nuovo o nessuno ha dato un
  /// indice adottabile (la cache resta com'è).
  Future<CatalogStatus?> refresh({AdoptedCatalog? previous}) async {
    if (!_active) return null;
    final state = await _readState();
    for (final base in config.urls) {
      final folder = base.path.endsWith('/') ? base : base.replace(path: '${base.path}/');
      try {
        final etag = previous != null && state['etagUrl'] == '$base' ? state['etag'] as String? : null;
        final reply = await _fetch(folder.resolve('index.json'), ifNoneMatch: etag, maxBytes: maxCatalogIndexBytes);
        if (reply.status == HttpStatus.notModified && previous != null) {
          await _touch(state);
          return null;
        }
        if (reply.status != HttpStatus.ok) continue;
        final signature = await _fetch(folder.resolve('index.sig'), maxBytes: maxCatalogSignatureBytes);
        if (signature.status != HttpStatus.ok) continue;
        final adoption = await adoptCatalog(
          previous: previous,
          indexBytes: reply.bytes,
          signatureBytes: signature.bytes,
          keys: config.keys,
          fetchSite: (path) async {
            try {
              final site = await _fetch(folder.resolve(path), maxBytes: maxCatalogSiteBytes);
              return site.status == HttpStatus.ok ? site.bytes : null;
            } on Object {
              return null;
            }
          },
        );
        switch (adoption.outcome) {
          case CatalogOutcome.unchanged:
            await _touch(state, etag: reply.etag, etagUrl: '$base');
            return null;
          case CatalogOutcome.adopted:
            final catalog = adoption.catalog!;
            await _write(catalog, signature.bytes, adoption.index!.issuedAt, etag: reply.etag, etagUrl: '$base');
            install(catalog);
            return CatalogStatus(
              serial: catalog.serial,
              issuedAt: adoption.index!.issuedAt,
              sites: adoption.sites,
              lastCheck: _now(),
            );
          case CatalogOutcome.badSignature || CatalogOutcome.invalid || CatalogOutcome.rollback:
            continue;
        }
      } on Object {
        continue;
      }
    }
    return null;
  }

  /// Ricontrollo dopo un `ProviderChanged` di [siteId]: se il catalogo ha per
  /// quel sito una variante con un'impronta diversa da quella in uso, la
  /// adotta (`refresh` la installa) e dice `true`.
  Future<bool> refreshedVariant(String siteId) async {
    if (!_active) return false;
    final previous = (await loadCache())?.catalog;
    final status = await refresh(previous: previous);
    final after = status?.sites[siteId]?.definition?.sha256;
    return after != null && after != previous?.definitions[siteId]?.sha256;
  }

  Future<Map<String, Object?>> _readState() async {
    try {
      return jsonDecode(await _file('state.json').readAsString()) as Map<String, Object?>;
    } on Object {
      return {};
    }
  }

  Future<void> _touch(Map<String, Object?> state, {String? etag, String? etagUrl}) async {
    if (state.isEmpty) return;
    final next = {...state, 'lastCheck': _now().toUtc().toIso8601String()};
    if (etagUrl != null) {
      next['etag'] = etag;
      next['etagUrl'] = etagUrl;
    }
    await _atomic(_file('state.json'), utf8.encode(jsonEncode(next)));
  }

  /// Prima le definizioni, per ultimo `state.json`: un'interruzione a metà
  /// lascia l'indice di prima con le sue definizioni ancora al loro posto.
  Future<void> _write(AdoptedCatalog catalog, List<int> signature, DateTime issuedAt, {String? etag, String? etagUrl}) async {
    for (final definition in catalog.definitions.values) {
      final file = _site(definition.sha256);
      if (!await file.exists()) await _atomic(file, utf8.encode(definition.text));
    }
    await _atomic(_file('index.json'), catalog.indexBytes);
    await _atomic(_file('index.sig'), signature);
    await _atomic(
      _file('state.json'),
      utf8.encode(jsonEncode({
        'serial': catalog.serial,
        'etag': etag,
        'etagUrl': etagUrl,
        'lastCheck': _now().toUtc().toIso8601String(),
        'definitions': {
          for (final MapEntry(key: id, value: definition) in catalog.definitions.entries)
            id: {'sha256': definition.sha256, 'version': definition.version},
        },
      })),
    );
    final keep = catalog.cachedShas.map((sha) => '$sha.json').toSet();
    final sites = Directory(p.join(directory.path, 'sites'));
    await for (final entry in sites.list()) {
      if (entry is File && !keep.contains(p.basename(entry.path))) await entry.delete().catchError((_) => entry);
    }
  }

  Future<void> _atomic(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }
}

const String catalogEnabledKey = 'catalog.enabled';

/// Il catalogo di questa installazione. Costruirlo lo avvia: si installa la
/// cache e si aggiorna in rete, a meno che l'utente l'abbia spento.
class CatalogNotifier extends Notifier<CatalogStatus> {
  @override
  CatalogStatus build() {
    final sync = ref.watch(catalogSyncProvider);
    if (sync.config.isConfigured) unawaited(_boot(sync));
    return const CatalogStatus();
  }

  Future<void> _boot(CatalogSync sync) async {
    final preferences = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    sync.enabled = preferences.getBool(catalogEnabledKey) ?? true;
    if (sync.enabled) {
      await _run(sync);
    } else {
      state = const CatalogStatus(enabled: false);
    }
  }

  Future<void> _run(CatalogSync sync) async {
    final fresh = await sync.start(onCached: (status) {
      if (ref.mounted && sync.enabled) state = status;
    });
    if (fresh != null && ref.mounted && sync.enabled) state = fresh;
  }

  /// L'interruttore: spento reinstalla un catalogo vuoto (valgono inclusi e siti
  /// dell'utente) e smette di chiedere; acceso riparte dalla cache.
  Future<void> setEnabled(bool value) async {
    final sync = ref.read(catalogSyncProvider);
    sync.enabled = value;
    await (await SharedPreferences.getInstance()).setBool(catalogEnabledKey, value);
    if (!ref.mounted) return;
    if (!value) {
      installCatalogProviders(const []);
      state = const CatalogStatus(enabled: false);
      return;
    }
    state = const CatalogStatus();
    await _run(sync);
  }
}

final catalogSyncProvider = Provider<CatalogSync>(
  (ref) => CatalogSync(
    directory: Directory(p.join(ref.watch(appDirectoriesProvider).support, 'catalog')),
    config: CatalogConfig.environment,
  ),
);

final catalogProvider = NotifierProvider<CatalogNotifier, CatalogStatus>(CatalogNotifier.new);

/// Nel giro ad app chiusa: stessa cosa, e un errore non ferma il giro.
Future<CatalogSync?> syncCatalogForRun(String support) async {
  try {
    final sync = CatalogSync(directory: Directory(p.join(support, 'catalog')), config: CatalogConfig.environment);
    if (sync.config.isConfigured) {
      sync.enabled = (await SharedPreferences.getInstance()).getBool(catalogEnabledKey) ?? true;
    }
    await sync.start();
    return sync;
  } on Object {
    // Restano gli inclusi e la cache.
    return null;
  }
}
