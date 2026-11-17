/// Il catalogo dei siti sul server (`docs/catalogo.md`, «Sul server»): una
/// copia per tutto il server, nel volume dei dati, perché il catalogo è
/// dell'immagine e non degli account. Le regole (firma, anti-rollback,
/// adozione sito per sito) sono quelle del pacchetto; qui ci sono solo la
/// rete e il disco.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/providers.dart' show installCatalogProviders;
import 'package:kagami_archive/signature.dart';
import 'package:kagami_archive/stores.dart';
import 'package:path/path.dart' as p;


class ServerCatalog {
  ServerCatalog({
    required this.directory,
    required this.urls,
    required this.keys,
    this.log = _stderr,
    this.minInterval = const Duration(minutes: 1),
    HttpClient? client,
  }) : _client = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 15));

  /// Il catalogo configurato, o `null` se non lo è: `KAGAMI_CATALOG_*` vince su
  /// `CATALOG_*` (l'ambiente dell'immagine) anche se vuoto ma presente, che è il
  /// modo di spegnere il catalogo dell'immagine. Una variabile mal scritta
  /// spegne il catalogo e lo dice.
  static ServerCatalog? fromEnvironment(Map<String, String> env, Directory directory, {void Function(String)? log}) {
    String pick(String name) => (env.containsKey('KAGAMI_$name') ? env['KAGAMI_$name'] : env[name])?.trim() ?? '';
    final rawUrls = pick('CATALOG_URLS'), rawKeys = pick('CATALOG_KEYS');
    if (rawUrls.isEmpty || rawKeys.isEmpty) return null;
    final say = log ?? _stderr;
    final urls = parseCatalogUrls(rawUrls, onError: say);
    final keys = parseCatalogKeys(rawKeys, onError: say);
    if (urls.isEmpty || keys.isEmpty) {
      say('Catalogo dei siti: configurazione senza indirizzi o chiavi validi, spento.');
      return null;
    }
    return ServerCatalog(directory: directory, urls: urls, keys: keys, log: log ?? _stderr);
  }

  static void _stderr(String line) => stderr.writeln(line);

  final Directory directory;
  final List<Uri> urls;
  final Map<String, RsaKey> keys;
  final void Function(String) log;

  /// Al più un controllo in questo intervallo: ogni giro e ogni controllo di
  /// ogni account lo chiede, e senza novità costa comunque una richiesta.
  final Duration minInterval;
  final HttpClient _client;

  AdoptedCatalog? _adopted;
  String? _etag;
  Uri? _etagUrl;
  DateTime? _checkedAt;
  Future<void>? _running;

  /// Il `serial` del catalogo adottato, `0` se non ne ha.
  int get serial => _adopted?.serial ?? 0;

  File _file(String name) => File(p.join(directory.path, name));
  File _site(String sha) => File(p.join(directory.path, 'sites', '$sha.json'));

  /// Dalla cache, senza rete: l'avvio non dipende da nessuno. Una cache che non
  /// torna (firma, impronte, chiavi cambiate) si ignora e il primo recupero la
  /// rimpiazza.
  Future<void> load() async {
    try {
      final state = await readJsonFile(_file('state.json'));
      final index = _file('index.json'), sig = _file('index.sig');
      if (state == null || !await index.exists() || !await sig.exists()) return;
      final indexBytes = await index.readAsBytes();
      if (!verifyCatalogSignature(indexBytes, await sig.readAsBytes(), keys)) {
        log('Catalogo dei siti: la cache non ha una firma valida, la ignoro.');
        return;
      }
      final definitions = <String, CatalogDefinition>{};
      for (final MapEntry(key: id, value: entry) in (state['definitions'] as Map? ?? const {}).entries) {
        final sha = (entry as Map)['sha256'] as String;
        final file = _site(sha);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        if (sha256.convert(bytes).toString() != sha) continue;
        definitions['$id'] = CatalogDefinition(text: utf8.decode(bytes), sha256: sha, version: entry['version'] as int);
      }
      _adopt(AdoptedCatalog(serial: CatalogIndex.parse(indexBytes).serial, indexBytes: indexBytes, definitions: definitions));
      _etag = state['etag'] as String?;
      _etagUrl = Uri.tryParse(state['etagUrl'] as String? ?? '');
    } on Object catch (error) {
      log('Catalogo dei siti: cache illeggibile ($error), la ignoro.');
    }
  }

  void _adopt(AdoptedCatalog catalog) {
    installCatalogProviders(catalogProviders(catalog, onError: (id, problem) => log('Catalogo dei siti, $id: $problem')));
    _adopted = catalog;
  }

  /// Controlla gli indirizzi, in ordine, e adotta il primo indice che passa.
  /// Mai un catalogo vuoto per una lettura fallita: senza novità, o se nessuno
  /// risponde, resta quello di prima.
  Future<void> refresh({bool force = false}) {
    final running = _running;
    if (running != null) return running;
    final checked = _checkedAt;
    if (!force && checked != null && DateTime.now().difference(checked) < minInterval) return Future.value();
    return _running = _refresh().whenComplete(() => _running = null);
  }

  Future<void> _refresh() async {
    _checkedAt = DateTime.now();
    try {
      for (final url in urls) {
        if (await _tryUrl(url)) return;
      }
      log('Catalogo dei siti: nessun indirizzo ha dato un indice valido, tengo ${_adopted == null ? 'i siti inclusi' : 'la cache (serial $serial)'}.');
    } on Object catch (error) {
      log('Catalogo dei siti: controllo fallito ($error).');
    }
  }

  /// Vero se non serve provare l'indirizzo dopo.
  Future<bool> _tryUrl(Uri url) async {
    final etag = _adopted != null && _etagUrl == url ? _etag : null;
    final index = await _get(_child(url, 'index.json'), maxCatalogIndexBytes, etag: etag);
    if (index == null) return false;
    if (index.status == HttpStatus.notModified) return true;
    if (index.status != HttpStatus.ok) return false;
    final sig = await _get(_child(url, 'index.sig'), maxCatalogSignatureBytes);
    if (sig == null || sig.status != HttpStatus.ok) return false;
    final adoption = await adoptCatalog(
      previous: _adopted,
      indexBytes: index.body,
      signatureBytes: sig.body,
      keys: keys,
      fetchSite: (path) async {
        final site = await _get(_child(url, path), maxCatalogSiteBytes);
        return site?.status == HttpStatus.ok ? site!.body : null;
      },
    );
    switch (adoption.outcome) {
      case CatalogOutcome.unchanged:
        return true;
      case CatalogOutcome.adopted:
        await _save(adoption.catalog!, index.body, sig.body, url, index.etag);
        _adopt(adoption.catalog!);
        _etag = index.etag;
        _etagUrl = url;
        log('Catalogo dei siti: adottato il serial ${adoption.serial} da $url.');
        return true;
      case CatalogOutcome.badSignature:
      case CatalogOutcome.invalid:
      case CatalogOutcome.rollback:
        log('Catalogo dei siti: $url rifiutato (${adoption.outcome.name}${adoption.detail == null ? '' : ', ${adoption.detail}'}).');
        return false;
    }
  }

  /// Prima le definizioni, poi indice, firma e stato: una cache a metà non
  /// nomina file che mancano.
  Future<void> _save(AdoptedCatalog catalog, List<int> index, List<int> sig, Uri url, String? etag) async {
    try {
      for (final definition in catalog.definitions.values) {
        final file = _site(definition.sha256);
        if (!await file.exists()) await writeAtomically(file, utf8.encode(definition.text));
      }
      await writeAtomically(_file('index.json'), index);
      await writeAtomically(_file('index.sig'), sig);
      await writeAtomically(
        _file('state.json'),
        utf8.encode(jsonEncode({
          'serial': catalog.serial,
          'etag': ?etag,
          'etagUrl': '$url',
          'checkedAt': DateTime.now().toUtc().toIso8601String(),
          'definitions': {
            for (final MapEntry(:key, :value) in catalog.definitions.entries) key: {'sha256': value.sha256, 'version': value.version},
          },
        })),
      );
      final keep = catalog.cachedShas;
      final sites = Directory(p.join(directory.path, 'sites'));
      await for (final entry in sites.list()) {
        if (entry is File && entry.path.endsWith('.json') && !keep.contains(p.basenameWithoutExtension(entry.path))) await entry.delete();
      }
    } on Object catch (error) {
      log('Catalogo dei siti: cache non scritta ($error); vale solo fino al riavvio.');
    }
  }

  static Uri _child(Uri base, String path) => base.replace(path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/$path');

  /// `null` per un errore di rete o un corpo oltre [limit]: l'indirizzo vale
  /// come irraggiungibile.
  Future<({int status, List<int> body, String? etag})?> _get(Uri url, int limit, {String? etag}) async {
    try {
      return await () async {
        final request = await _client.getUrl(url);
        if (etag != null) request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          return (status: response.statusCode, body: const <int>[], etag: null);
        }
        final body = <int>[];
        await for (final chunk in response) {
          body.addAll(chunk);
          if (body.length > limit) {
            response.detachSocket().then((socket) => socket.destroy(), onError: (_) {});
            return null;
          }
        }
        return (status: HttpStatus.ok, body: body, etag: response.headers.value(HttpHeaders.etagHeader));
      }()
          .timeout(const Duration(seconds: 60));
    } on Object catch (error) {
      log('Catalogo dei siti: $url non risponde ($error).');
      return null;
    }
  }

  void close() => _client.close(force: true);
}
