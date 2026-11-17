/// Chi riceve una libreria di Drive condivisa: inviti, accettare, rifiutare,
/// seguire la riga (rinnovo, ritiro), letture fallite, e la sorgente in
/// sola lettura (docs/drive.md, «La libreria condivisa»).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/drive_library.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/data/network.dart';
import 'package:kagami/src/data/share_directory.dart';
import 'package:kagami/src/data/shared_library.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_shares.dart';
import 'package:kagami/src/providers_sources.dart';

const _me = 'me@example.com';

DriveShare row({
  String from = 'amica@example.com',
  String folderId = 'folder-1',
  DateTime? at,
  DateTime? expiresAt,
}) =>
    DriveShare(
      id: DriveShare.shareId(from, _me, folderId),
      to: _me,
      from: from,
      fromName: 'Amica',
      folderId: folderId,
      folderName: 'Manga di Amica',
      permissionId: 'perm',
      at: at ?? DateTime.utc(2026, 11, 1),
      expiresAt: expiresAt,
    );

/// Drive che risponde sempre [status].
class _DeniedClient extends DriveClient {
  _DeniedClient(this.status)
      : super(({refresh = false}) async => 'token', network: NetworkMonitor.instance);

  final int status;

  @override
  Future<List<DriveItem>> children(String folderId) async =>
      throw DriveException('Drive ha risposto $status', status: status);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KagamiDatabase db;
  late Directory temp;
  late MemoryShareDirectory directory;
  late ProviderContainer container;

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        appDirectoriesProvider.overrideWithValue(
          AppDirectories(support: '${temp.path}/support', cache: '${temp.path}/cache'),
        ),
        shareDirectoryProvider.overrideWithValue(directory),
        shareReceiverProvider.overrideWithValue(_me),
      ];

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('kagami-shared');
    directory = MemoryShareDirectory();
    container = ProviderContainer(overrides: overrides());
    container.read(libraryRootProvider.notifier).select('${temp.path}/manga');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    temp.deleteSync(recursive: true);
  });

  /// Accende l'ascolto come fa `AppShell` e aspetta la prima lettura.
  Future<void> start() async {
    container.listen(sharedLibraryWatcherProvider, (_, _) {});
    await container.read(librarySourcesProvider.future);
    await _settle();
  }

  List<SourceConfig> sources() => container.read(librarySourcesProvider).value!.sources;

  Future<void> reread() async {
    directory.notifyChanged();
    await _settle();
  }

  group('inviti', () {
    test('una riga nuova è un invito, e si annuncia una volta sola', () async {
      await directory.put(row());
      await start();
      final invites = container.read(shareInvitesProvider);
      expect(invites, hasLength(1));

      // L'ascolto l'ha già annunciato (fuori da Android la notifica è muta, ma
      // l'id resta fra le impostazioni): ripeterlo non dice più niente.
      final user = container.read(userRepositoryProvider);
      expect(parseStamps(await user.readSetting(announcedSharesKey)), {shareStamp(invites.single)});
      final announced = <String>[];
      Future<void> notify(String id, {required String title, required String text}) async =>
          announced.add(id);
      await announceShareInvites(user, invites, notify: notify);
      expect(announced, isEmpty);

      // Riscritto dopo un ritiro: `at` nuovo, altro invito, una notifica sola.
      final again = row(at: DateTime.utc(2026, 11, 5));
      await announceShareInvites(user, [again], notify: notify);
      await announceShareInvites(user, [again], notify: notify);
      expect(announced, [again.id]);
    });

    test('rifiutato non torna; riscritto con un at nuovo sì', () async {
      await directory.put(row());
      await start();
      await container.read(dismissedSharesProvider.notifier).dismiss(container.read(shareInvitesProvider).single);
      expect(container.read(shareInvitesProvider), isEmpty);
      // Chi riceve non cancella mai la riga.
      expect(directory.rows, hasLength(1));
      expect(directory.log.where((entry) => entry.startsWith('remove')), isEmpty);

      await reread();
      expect(container.read(shareInvitesProvider), isEmpty);

      await directory.put(row(at: DateTime.utc(2026, 11, 9)));
      await reread();
      expect(container.read(shareInvitesProvider), hasLength(1));
    });

    test('una riga già scaduta non si propone', () async {
      await directory.put(row(expiresAt: DateTime.now().subtract(const Duration(days: 1))));
      await start();
      expect(container.read(shareInvitesProvider), isEmpty);
    });

    test('accettare aggiunge una sorgente driveShared in sola lettura', () async {
      final expiry = DateTime.now().toUtc().add(const Duration(days: 7));
      await directory.put(row(expiresAt: expiry));
      await start();
      await container.read(librarySourcesProvider.notifier).accept(container.read(shareInvitesProvider).single);

      final source = sources().single;
      expect(source.kind, SourceKind.driveShared);
      expect(source.label, 'Manga di Amica');
      expect(source.params, {
        'folderId': 'folder-1',
        'folderName': 'Manga di Amica',
        'owner': 'amica@example.com',
        'account': _me,
        'download': false,
        'ownerName': 'Amica',
      });
      expect(source.expiresAt!.millisecondsSinceEpoch ~/ 1000, expiry.millisecondsSinceEpoch ~/ 1000);
      expect(container.read(shareInvitesProvider), isEmpty);

      final built = container.read(storageSourcesProvider);
      final shared = built.sources.singleWhere((s) => s.config.id == source.id);
      expect(shared.capabilities.write, isFalse);
      expect(shared.capabilities.trash, isFalse);
      expect(shared.capabilities.closedApp, isFalse);
      expect(shared.shelf.sourceId, source.id);
      expect(shared.shelf.origin, LibraryOrigin.remote);
      expect(shared.files, isNotNull);
      expect(built.notices, isEmpty);
    });
  });

  group('la sorgente segue la riga', () {
    Future<SourceConfig> accepted({DateTime? expiresAt}) async {
      await directory.put(row(expiresAt: expiresAt));
      await start();
      await container.read(librarySourcesProvider.notifier).accept(container.read(shareInvitesProvider).single);
      return sources().single;
    }

    test('il rinnovo aggiorna il termine e la sorgente riparte', () async {
      final soon = DateTime.now().toUtc().add(const Duration(milliseconds: 200));
      final source = await accepted(expiresAt: soon);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      container.invalidate(storageSourcesProvider);
      expect(container.read(storageSourcesProvider).notices.single, isA<SourceUnavailable>());
      expect(container.read(storageSourcesProvider).sources.any((s) => s.config.id == source.id), isFalse);

      final later = DateTime.now().toUtc().add(const Duration(days: 30));
      await directory.put(row(expiresAt: later, at: DateTime.utc(2026, 11, 10)));
      await reread();
      expect(sources().single.expiresAt!.millisecondsSinceEpoch ~/ 1000, later.millisecondsSinceEpoch ~/ 1000);
      final built = container.read(storageSourcesProvider);
      expect(built.notices, isEmpty);
      expect(built.sources.any((s) => s.config.id == source.id), isTrue);

      // Un rinnovo senza scadenza toglie il termine.
      await directory.put(row());
      await reread();
      expect(sources().single.expiresAt, isNull);
    });

    test('riga sparita: scaduta da adesso, resta in elenco, lo stato di lettura non si tocca', () async {
      final source = await accepted(expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)));
      final reading = container.read(readingProvider.notifier);
      await container.read(readingProvider.future);
      await reading.setStatus('serie-di-amica', ShelfStatus.reading);
      await reading.saveProgress('serie-di-amica', chapterId: 'c1', page: 3, pageCount: 10);
      final before = container.read(readingProvider).value!.of('serie-di-amica');

      directory.rows.clear();
      await reread();
      final list = sources();
      expect(list.single.id, source.id);
      expect(list.single.expiredAt(DateTime.now()), isTrue);
      final built = container.read(storageSourcesProvider);
      expect(built.sources.any((s) => s.config.id == source.id), isFalse);
      final notice = built.notices.single as SourceUnavailable;
      expect(notice.sourceId, source.id);
      expect(notice.state, SourceState.expired);

      final after = container.read(readingProvider).value!.of('serie-di-amica');
      expect(after.status, before.status);
      expect(after.positions['c1']?.page, before.positions['c1']?.page);
      // E non è un invito: la sorgente c'è ancora.
      expect(container.read(shareInvitesProvider), isEmpty);
    });

    test('una rilettura fallita non cambia niente', () async {
      final expiry = DateTime.now().toUtc().add(const Duration(days: 7));
      final source = await accepted(expiresAt: expiry);
      final saved = await container.read(userRepositoryProvider).readSetting(LibrarySources.settingKey);
      directory.failure = Exception('rete');
      await reread();
      expect(sources().single.expiresAt, source.expiresAt);
      expect(await container.read(userRepositoryProvider).readSetting(LibrarySources.settingKey), saved);
      expect(container.read(storageSourcesProvider).notices, isEmpty);
    });
  });

  test('ShareUnavailable: funzione assente, niente crash, niente vuoto, non si riprova', () async {
    directory.failure = const ShareUnavailable();
    await start();
    expect(container.read(incomingSharesProvider).hasValue, isFalse);
    expect(container.read(incomingSharesProvider).hasError, isFalse);
    expect(container.read(shareInvitesProvider), isEmpty);

    // Anche se il backend poi "risponde", la funzione non si riprova.
    directory.failure = null;
    await directory.put(row());
    await reread();
    expect(container.read(incomingSharesProvider).hasValue, isFalse);
    expect(sources(), isEmpty);
  });

  group('lo scaffale di una libreria condivisa', () {
    DriveRepository repository(DriveClient client) => DriveRepository(
          client: client,
          folderId: 'folder-1',
          stateDirectory: '${temp.path}/state',
          files: DriveFileCache(Directory('${temp.path}/files'), limitBytes: 1 << 20),
          sourceId: 's-0000000a',
          origin: LibraryOrigin.remote,
        );

    for (final status in [403, 404]) {
      test('$status su una sorgente non scaduta è SourceUnavailable, mai vuota', () async {
        final shelf = repository(_DeniedClient(status));
        await expectLater(
          shelf.loadLibrary(),
          throwsA(isA<SourceUnavailable>()
              .having((e) => e.sourceId, 'sourceId', 's-0000000a')
              .having((e) => e.state, 'state', SourceState.missing)),
        );
        // Né l'istantanea né la memoria la mascherano al giro dopo.
        await expectLater(shelf.loadLibrary(), throwsA(isA<SourceUnavailable>()));
      });
    }

    test('gli indirizzi portano l\'id della sorgente, non `drive:`', () {
      expect(repository(_DeniedClient(403)).addressPrefix, 'remote:s-0000000a/');
    });
  });

  test('R7: finché la lista si legge il catalogo non sembra completo', () async {
    await container.read(userRepositoryProvider).writeSetting(
          LibrarySources.settingKey,
          SourceList([sourceFromShare(row(), id: 's-0000000b')]).encode(),
        );
    container.dispose();
    container = ProviderContainer(overrides: overrides());
    container.read(libraryRootProvider.notifier).select('${temp.path}/manga');

    final loading = container.read(libraryProvider)!;
    expect(
      loading.notices.whereType<SourceUnavailable>().map((n) => n.sourceId),
      contains(loadingSourcesId),
    );
    await container.read(librarySourcesProvider.future);
    final loaded = container.read(libraryProvider)!;
    expect(loaded.notices, isEmpty);
    expect(loaded.shelves.map((s) => s.sourceId), contains('s-0000000b'));
  });
}
