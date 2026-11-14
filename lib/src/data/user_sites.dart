/// I siti degli utenti: i file di `providers/` nella libreria in uso
/// (`docs/siti.md`), letti all'avvio e quando la libreria cambia, e installati
/// nel motore con `installUserProviders`.
///
/// Adozione, non sovrascrittura: se la cartella non si legge (rete, permesso)
/// restano i siti di prima, e un file che non si legge non toglie il suo sito.
/// Togliere un sito è una scelta dell'utente ([UserSitesNotifier.remove]).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/providers.dart' show builtInProviders, installUserProviders, providerById;
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/stores.dart' show ArchiveStore;

import '../archive/device.dart';
import '../archive/repair.dart' show repairTargetOf;
import '../providers.dart';
import 'drive.dart';
import 'network.dart';
import 'site_replacements.dart';

/// I siti letti dalla libreria e i file che non si sono potuti leggere.
class UserSites {
  const UserSites({this.sites = const [], this.errors = const {}, this.hasLibrary = true, this.unconfirmed = const {}});

  final List<DeclarativeProvider> sites;

  /// Per nome di file, perché il file non ha dato un sito.
  final Map<String, String> errors;

  /// Se c'è una libreria in cui installare: senza, l'elenco è vuoto e
  /// [UserSitesNotifier.install] non può scrivere.
  final bool hasLibrary;

  /// Gli id dei siti che sostituirebbero uno incluso e l'utente non ha ancora
  /// confermato: stanno in [sites], ma il motore usa ancora quello incluso.
  final Set<String> unconfirmed;

  DeclarativeProvider? byId(String id) {
    for (final site in sites) {
      if (site.id == id) return site;
    }
    return null;
  }

  /// Se il sito [id] prende il posto di uno incluso nell'app.
  bool replacesBuiltIn(String id) => builtInProviders.any((provider) => provider.id == id);
}

/// Un posto dove leggere e scrivere `providers/`, con come chiuderlo.
typedef SitesAccess = ({ArchiveStore store, void Function() close});

/// Apre la libreria in uso: Drive se c'è la cartella, altrimenti la cartella
/// del telefono; `null` senza libreria. Con [write] chiede il permesso di
/// scrivere (può lanciare `DriveAuthRequired`).
typedef SitesAccessOf = Future<SitesAccess?> Function({required bool write});

/// Le sostituzioni di siti inclusi confermate dall'utente.
final siteReplacementsProvider = Provider<SiteReplacements>(
  (ref) => SiteReplacements(File('${ref.watch(archiveFilesProvider).directory.path}/site-replacements.json')),
);

final userSitesAccessProvider = Provider<SitesAccessOf>((ref) {
  return ({required write}) async {
    final target = repairTargetOf(ref);
    if (target == null) return null;
    final auth = ref.read(driveAuthProvider);
    final client = DriveClient(write ? auth.writeToken : auth.token, network: NetworkMonitor.instance);
    final environment = deviceEnvironment(ref.read(archiveFilesProvider), client, ref.read(appDirectoriesProvider).cache);
    return (store: environment.storeFor(target), close: client.close);
  };
});

/// Scarica il file di un sito da un link https.
typedef SiteFetcher = Future<String> Function(String url);

/// Il file non è più grande di così (`docs/siti.md`).
const int siteFileLimit = 64 * 1024;

const Duration _fetchTimeout = Duration(seconds: 10);
const int _maxRedirects = 3;

Future<String> fetchSiteText(String url) async {
  var uri = Uri.tryParse(url.trim());
  final client = HttpClient()..connectionTimeout = _fetchTimeout;
  try {
    // Gli spostamenti si seguono a mano: ognuno deve restare in https.
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const SiteDefinitionError('Il link del sito deve essere https.');
      }
      final request = await client.getUrl(uri).timeout(_fetchTimeout);
      request.followRedirects = false;
      final response = await request.close().timeout(_fetchTimeout);
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        uri = location == null ? null : uri.resolve(location);
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw SiteDefinitionError('Il link ha risposto ${response.statusCode}.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(_fetchTimeout)) {
        bytes.addAll(chunk);
        if (bytes.length > siteFileLimit) throw const SiteDefinitionError('Il file del sito è troppo grande.');
      }
      return utf8.decode(bytes);
    }
    throw const SiteDefinitionError('Troppi spostamenti.');
  } on FormatException {
    throw const SiteDefinitionError('Il file del sito non è testo.');
  } finally {
    client.close(force: true);
  }
}

final siteFetcherProvider = Provider<SiteFetcher>((ref) => fetchSiteText);

/// Dice al server che i siti sono cambiati, se li sa leggere. Un server che
/// non risponde non è un errore: li rilegge comunque a ogni giro.
final userSitesServerSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (ref.read(archiveEngineProvider) != ArchiveEngine.server) return;
    final link = ref.read(serverLinkProvider).value;
    if (link == null) return;
    final client = serverClient(ref, link);
    try {
      if ((await client.info()).userProviders) await client.refreshProviders();
    } on ServerException {
      return;
    } on IOException {
      return;
    } finally {
      client.close();
    }
  };
});

/// Se il server collegato sa usare i siti degli utenti. Finché non lo si è
/// chiesto, o se non risponde, è `false`: quei lavori restano sul telefono.
final serverUserSitesProvider = FutureProvider<bool>((ref) async {
  final link = ref.watch(serverLinkProvider).value;
  if (link == null) return false;
  final client = serverClient(ref, link);
  try {
    return (await client.info()).userProviders;
  } on ServerException {
    return false;
  } on IOException {
    return false;
  } finally {
    client.close();
  }
});

/// Chi lavora per il sito [siteId]: [engine], salvo che il sito sia di un
/// utente e il server non sappia usarli (`userProviders`), allora il telefono.
ArchiveEngine engineForSite(ArchiveEngine engine, String siteId, {required bool serverHasUserSites}) {
  if (engine != ArchiveEngine.server || serverHasUserSites) return engine;
  final site = providerById(siteId);
  return site != null && !site.builtIn ? ArchiveEngine.phone : engine;
}

/// L'id del sito dalla chiave di una serie, `<sito>:<id serie>`.
String siteOfKey(String key) => key.split(':').first;

class UserSitesNotifier extends AsyncNotifier<UserSites> {
  static const String _checkedKey = 'sites.updateCheck';
  static const Duration _updateEvery = Duration(days: 1);

  /// Ultimo elenco letto con successo: sopravvive alla riesecuzione di
  /// [build], per non svuotare i siti su una lettura fallita.
  UserSites _last = const UserSites();

  @override
  Future<UserSites> build() async {
    ref.watch(libraryRootProvider);
    await ref.watch(driveFolderProvider.future);
    ref.watch(cloudAccountProvider.select((status) => status.signedIn));
    final SitesAccess? access;
    try {
      access = await ref.read(userSitesAccessProvider)(write: false);
    } on Object {
      return _last;
    }
    // Nessuna libreria è «non c'è», non «non ho potuto leggere».
    if (access == null) return await _publish(const UserSites(hasLibrary: false));
    try {
      return await _publish(await _read(access.store));
    } on Object {
      return _last;
    } finally {
      access.close();
    }
  }

  Future<UserSites> _read(ArchiveStore store) async {
    final errors = <String, String>{};
    final sites = await loadSites(store, onError: (file, error) => errors[file] = '$error');
    // Un file che c'è ma non ha dato un sito (rovinato, o letto a metà: lo
    // store dà `null` in entrambi i casi) non toglie il sito di prima: lo
    // toglie solo l'utente.
    final listed = await store.filesIn(sitesFolder);
    for (final old in _last.sites) {
      final file = '${old.id}.json';
      if (!listed.containsKey(file) || sites.any((site) => site.id == old.id)) continue;
      sites.add(old);
      errors.putIfAbsent(file, () => 'Il file non si è potuto leggere.');
    }
    return UserSites(sites: sites, errors: errors);
  }

  /// Mette nel motore i siti di [value], meno quelli che sostituirebbero uno
  /// incluso senza che l'utente l'abbia confermato (T10).
  Future<UserSites> _publish(UserSites value) async {
    final confirmed = await ref.read(siteReplacementsProvider).read();
    final held = SiteReplacements.unconfirmed(value.sites, confirmed).map((site) => site.id).toSet();
    final result = UserSites(sites: value.sites, errors: value.errors, hasLibrary: value.hasLibrary, unconfirmed: held);
    _last = result;
    installUserProviders(SiteReplacements.usable(value.sites, confirmed));
    return result;
  }

  /// L'utente accetta che il sito [id] della libreria prenda il posto di
  /// quello incluso: vale per questo file, non per uno diverso con lo stesso id.
  Future<void> confirmReplacement(String id) async {
    final now = await _current();
    final site = now.byId(id);
    if (site == null) return;
    await ref.read(siteReplacementsProvider).confirm(site);
    state = AsyncData(await _publish(now));
    await ref.read(userSitesServerSyncProvider)();
  }

  Future<UserSites> _current() async => state.value ?? await future;

  /// Scrive [site] nella libreria, al posto della versione di prima.
  /// Lancia `DriveAuthRequired` se manca il permesso di scrivere.
  Future<void> install(DeclarativeProvider site) async {
    await _write((store) => saveSite(store, site));
    final now = await _current();
    final sites = [for (final old in now.sites) if (old.id != site.id) old, site]..sort((a, b) => a.id.compareTo(b.id));
    final errors = {...now.errors}..remove('${site.id}.json');
    state = AsyncData(await _publish(UserSites(sites: sites, errors: errors)));
    await ref.read(userSitesServerSyncProvider)();
  }

  /// Toglie il file del sito [id]; le sue serie restano in libreria.
  Future<void> remove(String id) async {
    await _write((store) => removeSite(store, id));
    final now = await _current();
    final errors = {...now.errors}..remove('$id.json');
    state = AsyncData(await _publish(UserSites(sites: [for (final site in now.sites) if (site.id != id) site], errors: errors)));
    await ref.read(userSitesServerSyncProvider)();
  }

  Future<void> _write(Future<void> Function(ArchiveStore store) action) async {
    final access = await ref.read(userSitesAccessProvider)(write: true);
    if (access == null) throw const SiteDefinitionError('Non c\'è una libreria in cui installare il sito.');
    try {
      await action(access.store);
    } finally {
      access.close();
    }
  }

  /// Scarica e valida il file di un sito dal link [url] (https, ≤ 64 KB),
  /// senza installarlo. Lancia [SiteDefinitionError] se non è valido e
  /// l'errore di rete se il link non risponde.
  Future<DeclarativeProvider> fetchDefinition(String url) async =>
      DeclarativeProvider.parse(await ref.read(siteFetcherProvider)(url));

  /// Rilegge i siti con un link `update` e applica quelli con `version` più
  /// alta. Al più una volta al giorno, salvo [force]. Un errore lascia il sito
  /// di prima. Restituisce gli id aggiornati.
  Future<List<String>> checkUpdates({bool force = false}) async {
    final now = DateTime.now();
    final repository = ref.read(userRepositoryProvider);
    if (!force) {
      final last = DateTime.tryParse(await repository.readSetting(_checkedKey) ?? '');
      if (last != null && now.difference(last).abs() < _updateEvery) return const [];
    }
    final current = await _current();
    final updated = <String>[];
    var asked = false;
    for (final site in current.sites) {
      final url = site.updateUrl;
      if (url == null) continue;
      asked = true;
      try {
        final fresh = await fetchDefinition(url);
        if (fresh.id != site.id || fresh.version <= site.version) continue;
        await _write((store) => saveSite(store, fresh));
        final sites = [for (final old in (await _current()).sites) old.id == site.id ? fresh : old];
        state = AsyncData(await _publish(UserSites(sites: sites, errors: (await _current()).errors)));
        updated.add(site.id);
      } on Object {
        continue;
      }
    }
    if (asked) await repository.writeSetting(_checkedKey, now.toUtc().toIso8601String());
    if (updated.isNotEmpty) await ref.read(userSitesServerSyncProvider)();
    return updated;
  }
}

final userSitesProvider = AsyncNotifierProvider<UserSitesNotifier, UserSites>(UserSitesNotifier.new);
