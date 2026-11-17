/// Le sorgenti in più della libreria, come le tiene l'app.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/webdav.dart';
import 'package:path/path.dart' as p;

import 'data/drive.dart';
import 'data/download_origin.dart';
import 'data/drive_library.dart';
import 'data/library.dart';
import 'data/library_repository.dart';
import 'data/network.dart';
import 'data/share_directory.dart';
import 'data/shared_copies.dart';
import 'data/shared_library.dart';
import 'data/sources/path_shelf.dart';
import 'data/sources/shared_drive_source.dart';
import 'data/sources/shelf_source.dart';
import 'data/sources/smb_source.dart';
import 'data/sources/smb_transport.dart';
import 'data/sources/source.dart';
import 'data/sources/webdav_source.dart';
import 'providers.dart';
import 'providers_shares.dart' show shareReceiverProvider;

final sourceSecretsProvider =
    Provider<SourceSecrets>((ref) => MemorySourceSecrets());

/// La lista salvata in `library.sources`. Ogni metodo è un gesto
/// dell'utente: solo da lì l'impostazione si riscrive, mai da una lettura.
/// Se la lettura è fallita (database, non contenuto) i metodi rilanciano e
/// non scrivono.
class LibrarySources extends AsyncNotifier<SourceList> {
  static const String settingKey = 'library.sources';

  @override
  Future<SourceList> build() async => SourceList.decode(
        await ref.watch(userRepositoryProvider).readSetting(settingKey),
      );

  /// Aggiunge in coda: chi c'era già continua a vincere.
  Future<void> add(SourceConfig source) async {
    final list = await future;
    final last = list.sources.isEmpty ? -1 : list.sources.last.order;
    await _save(list.withSources([
      ...list.sources.where((other) => other.id != source.id),
      source.copyWith(order: last + 1),
    ]));
  }

  /// Sostituisce quella con lo stesso id (`update` è già di `AsyncNotifier`).
  Future<void> replace(SourceConfig source) async {
    final list = await future;
    await _save(list.withSources([
      for (final other in list.sources) other.id == source.id ? source : other,
    ]));
  }

  Future<void> remove(String id) async {
    final list = await future;
    await _save(list.withSources(list.sources.where((other) => other.id != id)));
    await ref.read(sourceSecretsProvider).delete(id);
    // Cache e stato della sorgente, mai lo stato di lettura (`reading/`).
    final directories = ref.read(appDirectoriesProvider);
    for (final path in [
      p.join(directories.support, 'sources', id),
      p.join(directories.cache, 'sources', id),
    ]) {
      final directory = Directory(path);
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    await dropSharedCopies(directories, id, SharedCopiesFate.everything);
  }

  /// [ids] nell'ordine voluto; quelle non nominate restano in coda, com'erano.
  Future<void> reorder(List<String> ids) async {
    final list = await future;
    final named = [
      for (final id in ids) ?list.byId(id),
    ];
    final rest = list.sources.where((source) => !ids.contains(source.id));
    await _save(list.withSources([
      for (final (index, source) in [...named, ...rest].indexed)
        source.copyWith(order: index),
    ]));
  }

  /// Accetta l'invito: aggiunge la sorgente in sola lettura, se non c'è già.
  Future<void> accept(DriveShare share) async {
    final list = await future;
    if (list.sources.any((source) => followsShare(source, share))) return;
    await add(sourceFromShare(share, id: SourceConfig.newId()));
  }

  /// Fa seguire le sorgenti condivise alle righe appena **lette** (mai a una
  /// lettura fallita): vedi [followShares]. Scrive solo se qualcosa è cambiato.
  Future<void> follow(List<DriveShare> rows, {required String account, DateTime? now}) async {
    final list = await future;
    final next = followShares(list.sources, rows, now ?? DateTime.now(), account: account);
    final changed = [
      for (var i = 0; i < next.length; i++)
        if (!identical(next[i], list.sources[i])) i,
    ];
    if (changed.isEmpty) return;
    await _save(list.withSources(next));
  }

  Future<void> _save(SourceList next) async {
    await ref.read(userRepositoryProvider).writeSetting(settingKey, next.encode());
    state = AsyncData(next);
  }
}

final librarySourcesProvider =
    AsyncNotifierProvider<LibrarySources, SourceList>(LibrarySources.new);

/// Come si costruisce una sorgente di un dato tipo dalla sua riga. La tabella
/// è vuota finché non arrivano i tipi (Drive condiviso, WebDAV): una riga di
/// un tipo senza costruttore non è una sorgente vuota, è un avviso.
typedef SourceBuilder = StorageSource Function(Ref ref, SourceConfig config);

final sourceBuildersProvider = Provider<Map<SourceKind, SourceBuilder>>(
  (ref) => const {
    SourceKind.driveShared: buildSharedDrive,
    SourceKind.webdav: buildWebDav,
    SourceKind.smb: buildSmb,
  },
);

/// Una libreria su una condivisione SMB: stessa forma del WebDAV, ma host e
/// condivisione al posto dell'indirizzo, e in chiaro solo in casa (`seal` =
/// SMB 3 cifrato, richiesto verso un host pubblico).
StorageSource buildSmb(Ref ref, SourceConfig config) {
  final params = config.params;
  final seal = params['seal'] == true;
  final String host;
  final String share;
  try {
    host = smbHost('${params['host'] ?? ''}', seal: seal);
    share = smbShare('${params['share'] ?? ''}');
  } on FormatException {
    throw SourceUnavailable(config.id, SourceState.missing);
  }
  final folder = params['folder'];
  final directories = ref.watch(appDirectoriesProvider);
  final transport = secretSmbTransport(
    host: host,
    share: share,
    user: '${params['user'] ?? ''}',
    domain: '${params['domain'] ?? ''}',
    seal: seal,
    secrets: ref.watch(sourceSecretsProvider),
    sourceId: config.id,
  );
  final shelf = PathShelf(
    transport: transport,
    sourceId: config.id,
    stateDirectory: p.join(directories.support, 'sources', config.id),
    root: folder is String ? folder : '',
  );
  final cache = DriveFileCache(
    Directory(p.join(directories.cache, 'sources', config.id)),
    limitBytes: ref.read(driveCacheLimitProvider).value ?? DriveCacheLimit.standard,
  );
  return SmbSource(
    config: config,
    transport: transport,
    shelf: shelf,
    files: PathFiles(shelf, cache),
  );
}

/// Una libreria su WebDAV: la password si legge dai segreti alla prima
/// richiesta (senza, la sorgente è `needsAuth`), stato e cache per id.
StorageSource buildWebDav(Ref ref, SourceConfig config) {
  final url = config.params['url'];
  final Uri address;
  try {
    address = webDavAddress(url is String ? url : '');
  } on FormatException {
    throw SourceUnavailable(config.id, SourceState.missing);
  }
  final user = config.params['user'];
  final root = config.params['root'];
  final directories = ref.watch(appDirectoriesProvider);
  final transport = SecretWebDavTransport(
    address: address,
    user: user is String ? user : '',
    secrets: ref.watch(sourceSecretsProvider),
    sourceId: config.id,
  );
  final shelf = PathShelf(
    transport: transport,
    sourceId: config.id,
    stateDirectory: p.join(directories.support, 'sources', config.id),
    root: root is String ? root : '',
  );
  final cache = DriveFileCache(
    Directory(p.join(directories.cache, 'sources', config.id)),
    limitBytes: ref.read(driveCacheLimitProvider).value ?? DriveCacheLimit.standard,
  );
  return WebDavSource(
    config: config,
    transport: transport,
    shelf: shelf,
    files: PathFiles(shelf, cache),
  );
}

/// La libreria di un altro su Drive: stesso client e token di sola lettura
/// del Drive dell'account, la cartella della riga, e stato e cache propri per
/// id di sorgente (due librerie possono avere serie con lo stesso nome).
StorageSource buildSharedDrive(Ref ref, SourceConfig config) => sharedDriveSource(
      ref,
      config,
      DriveClient(ref.watch(driveAuthProvider).token, network: NetworkMonitor.instance),
    );

/// [buildSharedDrive] con il client dato.
StorageSource sharedDriveSource(Ref ref, SourceConfig config, DriveClient client) {
  final folderId = config.params['folderId'];
  if (folderId is! String || folderId.isEmpty) {
    throw SourceUnavailable(config.id, SourceState.missing);
  }
  final directories = ref.watch(appDirectoriesProvider);
  final cache = DriveFileCache(
    Directory(sharedCacheDirectory(directories, config.id)),
    limitBytes: ref.read(driveCacheLimitProvider).value ?? DriveCacheLimit.standard,
  );
  return SharedDriveSource(
    config: config,
    client: client,
    repository: DriveRepository(
      client: client,
      folderId: folderId,
      stateDirectory: sharedStateDirectory(directories, config.id),
      files: cache,
      sourceId: config.id,
      origin: LibraryOrigin.remote,
    ),
  );
}

/// Le sorgenti accese, in ordine di preferenza, e ciò che di loro non si è
/// potuto accendere.
class StorageSources {
  const StorageSources(this.sources, this.notices);

  final List<StorageSource> sources;

  /// [SourceUnavailable] per ogni sorgente che c'è in configurazione ma non
  /// si usa, e uno per la lista che non si è potuta leggere: mai una
  /// sorgente vuota.
  final List<Object> notices;

  List<LibraryShelf> get shelves => [for (final source in sources) source.shelf];
}

/// L'id con cui un avviso dice che la lista `library.sources` non si è
/// potuta leggere.
const String unreadableSourcesId = 'library.sources';

/// L'id dell'avviso «la lista si sta ancora leggendo»: finché c'è, il
/// catalogo non è completo e chi conclude qualcosa da un'assenza aspetta.
/// Passa da solo; l'interfaccia non lo mostra.
const String loadingSourcesId = 'library.sources.loading';

/// Cartella scelta, spazio dell'app e Drive dell'account — le tre di sempre,
/// con le loro impostazioni — e poi le altre per `order`.
final storageSourcesProvider = Provider<StorageSources>((ref) {
  final root = ref.watch(libraryRootProvider);
  final hasFolder =
      ref.watch(driveFolderProvider.select((state) => state.value != null));
  final drive = ref.watch(driveRepositoryProvider);
  final directories = ref.watch(appDirectoriesProvider);
  // Un valore con uguaglianza: finché la lista si legge, e se non c'è
  // niente di salvato, la libreria non si ricompone per niente.
  final (encoded, unreadable, loading) = ref.watch(librarySourcesProvider.select(
    (list) => (
      list.value?.encode() ?? '[]',
      list.value?.unreadable ?? false,
      list.value == null && !list.hasError,
    ),
  ));
  final list = SourceList.decode(encoded);
  final builders = ref.watch(sourceBuildersProvider);
  final now = DateTime.now();
  final account = ref.watch(shareReceiverProvider);

  final sources = <StorageSource>[
    if (root != null)
      ShelfSource(
        config: const SourceConfig(
          id: SourceConfig.folderId,
          kind: SourceKind.folder,
          label: 'folder',
        ),
        // Con Drive la cartella può anche non avere `library.json`: può
        // contenere soltanto ciò che l'app vi ha scaricato.
        shelf: LibraryRepository(root, requireIndex: !hasFolder),
      ),
    ShelfSource(
      config: const SourceConfig(
        id: SourceConfig.privateId,
        kind: SourceKind.appPrivate,
        label: 'private',
      ),
      shelf: LibraryRepository(
        directories.privateLibrary,
        requireIndex: false,
        private: true,
      ),
    ),
    if (drive != null)
      ShelfSource(
        config: const SourceConfig(
          id: SourceConfig.driveId,
          kind: SourceKind.drive,
          label: 'drive',
        ),
        shelf: drive,
        files: ref.watch(driveFilesProvider),
        capabilities: const SourceCapabilities(write: true, trash: true, closedApp: true, download: true),
      ),
  ];
  final notices = <Object>[
    if (unreadable)
      const SourceUnavailable(unreadableSourcesId, SourceState.missing),
    if (loading) const SourceUnavailable(loadingSourcesId, SourceState.offline),
  ];

  // Le copie delle librerie condivise: dopo lo spazio dell'app, perché un
  // capitolo che è sul telefono si legge da qui e non in streaming.
  final copies = <StorageSource>[];
  DateTime? nextExpiry;
  for (final config in list.sources) {
    final builder = builders[config.kind];
    final fate = sharedCopiesFate(config, account: account, now: now);
    if (fate != SharedCopiesFate.keep) unawaited(dropSharedCopies(directories, config.id, fate).catchError((Object _) {}));
    if (config.kind == SourceKind.driveShared && fate != SharedCopiesFate.everything) {
      final expiry = config.expiresAt;
      if (expiry != null && (nextExpiry == null || expiry.isBefore(nextExpiry))) nextExpiry = expiry;
    }
    if (belongsToOtherAccount(config, account)) {
      notices.add(SourceUnavailable(config.id, SourceState.otherAccount));
    } else if (config.expiredAt(now)) {
      notices.add(SourceUnavailable(config.id, SourceState.expired));
    } else if (builder == null) {
      notices.add(SourceUnavailable(config.id, SourceState.missing));
    } else {
      final StorageSource source;
      try {
        source = builder(ref, config);
      } on SourceUnavailable catch (notice) {
        notices.add(notice);
        continue;
      }
      final files = source.files;
      if (files != null) {
        final router = ref.read(remoteRouterProvider)..attach(config.id, files);
        ref.onDispose(() => router.detach(config.id, files));
      }
      ref.onDispose(source.dispose);
      sources.add(source);
      if (fate == SharedCopiesFate.keep && config.kind == SourceKind.driveShared) {
        final shelf = SharedCopiesShelf(directories, config.id);
        copies.add(ShelfSource(
          config: SourceConfig(id: shelf.sourceId, kind: SourceKind.driveShared, label: config.label),
          shelf: shelf,
          capabilities: const SourceCapabilities(trash: true),
        ));
      }
    }
  }
  sources.insertAll(sources.indexWhere((source) => source.config.id == SourceConfig.privateId) + 1, copies);
  // Il termine lo sa il telefono: la sorgente si spegne, e le copie se ne
  // vanno, quando arriva, anche senza rete e senza che niente la rilegga.
  if (nextExpiry != null) {
    final timer = Timer(nextExpiry.difference(DateTime.now()), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return StorageSources(sources, notices);
});

/// Da dove si scarica un capitolo servito dalla sorgente [sourceId], se la
/// sorgente lo permette ([SourceCapabilities.download]). Da una libreria
/// condivisa le copie vanno nel suo scaffale privato, mai nella cartella
/// dell'utente, che FolderSync porterebbe sul suo Drive.
final downloadOriginProvider = Provider.family<DownloadOrigin?, String>((ref, sourceId) {
  for (final source in ref.watch(storageSourcesProvider).sources) {
    if (source.config.id != sourceId) continue;
    if (!source.capabilities.download) return null;
    final shared = source.config.kind == SourceKind.driveShared;
    return switch ((source.shelf, source.files)) {
      (final DriveRepository drive, final DriveFiles files) => DriveOrigin(
          drive,
          files,
          destination: shared ? sharedCopiesDirectory(ref.watch(appDirectoriesProvider), sourceId) : null,
        ),
      (final PathShelf path, final PathFiles files) => PathOrigin(path, files),
      _ => null,
    };
  }
  return null;
});
