/// La libreria condivisa resta dell'account che l'ha accettata (F5.20):
/// l'account si salva, con un altro la sorgente non si legge e lo dice, una
/// configurazione vecchia lo prende da una rilettura riuscita, le righe di un
/// altro account non toccano le sorgenti (docs/drive.md, «Chi riceve»).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/data/share_directory.dart';
import 'package:kagami/src/data/shared_library.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_shares.dart';
import 'package:kagami/src/providers_sources.dart';

const _me = 'me@example.com';
const _other = 'altro@example.com';

DriveShare row({String to = _me, String from = 'amica@example.com', String folderId = 'folder-1'}) => DriveShare(
      id: DriveShare.shareId(from, to, folderId),
      to: to,
      from: from,
      fromName: 'Amica',
      folderId: folderId,
      folderName: 'Manga di Amica',
      permissionId: 'perm',
      at: DateTime.utc(2026, 11, 1),
    );

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KagamiDatabase db;
  late Directory temp;
  late MemoryShareDirectory directory;
  late ProviderContainer container;

  /// Un avvio dell'app con [account] entrato (o nessuno): stesso database.
  Future<ProviderContainer> launch(String? account) async {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appDirectoriesProvider.overrideWithValue(
        AppDirectories(support: '${temp.path}/support', cache: '${temp.path}/cache'),
      ),
      shareDirectoryProvider.overrideWithValue(directory),
      shareReceiverProvider.overrideWithValue(account),
    ]);
    c.read(libraryRootProvider.notifier).select('${temp.path}/manga');
    c.listen(sharedLibraryWatcherProvider, (_, _) {});
    await c.read(librarySourcesProvider.future);
    await _settle();
    return c;
  }

  Future<void> relaunch(String? account) async {
    container.dispose();
    container = await launch(account);
  }

  List<SourceConfig> sources() => container.read(librarySourcesProvider).value!.sources;

  Future<void> write(SourceConfig config) => container
      .read(userRepositoryProvider)
      .writeSetting(LibrarySources.settingKey, SourceList([config]).encode());

  setUp(() async {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('kagami-shared-account');
    directory = MemoryShareDirectory();
    container = await launch(_me);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<SourceConfig> accept() async {
    await directory.put(row());
    directory.notifyChanged();
    await _settle();
    await container.read(librarySourcesProvider.notifier).accept(container.read(shareInvitesProvider).single);
    return sources().single;
  }

  test('accettare salva l\'account, in minuscolo', () async {
    expect(sourceFromShare(row(to: 'Me@Example.com'), id: 's-1').params['account'], _me);
    expect((await accept()).params['account'], _me);
  });

  test('con un altro account la sorgente è in elenco, non si legge, lo stato di lettura resta', () async {
    final source = await accept();
    final reading = container.read(readingProvider.notifier);
    await container.read(readingProvider.future);
    await reading.setStatus('serie-di-amica', ShelfStatus.reading);
    final before = container.read(readingProvider).value!.of('serie-di-amica');
    expect(container.read(storageSourcesProvider).sources.any((s) => s.config.id == source.id), isTrue);

    for (final account in [_other, null]) {
      await relaunch(account);
      expect(sources().single.params, source.params);
      final built = container.read(storageSourcesProvider);
      expect(built.sources.any((s) => s.config.id == source.id), isFalse);
      final notice = built.notices.single as SourceUnavailable;
      expect(notice.sourceId, source.id);
      expect(notice.state, SourceState.otherAccount);
      await container.read(readingProvider.future);
      expect(container.read(readingProvider).value!.of('serie-di-amica').status, before.status);
    }

    // Tornando l'account giusto riparte da sola.
    await relaunch(_me);
    final built = container.read(storageSourcesProvider);
    expect(built.notices, isEmpty);
    expect(built.sources.any((s) => s.config.id == source.id), isTrue);
  });

  test('con un altro account nemmeno la scadenza la fa «scaduta»', () async {
    final source = await accept();
    await write(source.copyWith(expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1))));
    await relaunch(_other);
    expect((container.read(storageSourcesProvider).notices.single as SourceUnavailable).state, SourceState.otherAccount);
  });

  group('configurazione senza account', () {
    final old = SourceConfig(
      id: 's-0000000c',
      kind: SourceKind.driveShared,
      label: 'Manga di Amica',
      params: const {'folderId': 'folder-1', 'folderName': 'Manga di Amica', 'owner': 'amica@example.com'},
    );

    test('si comporta come prima, e prende l\'account alla prima rilettura riuscita', () async {
      await write(old);
      await directory.put(row());
      // Una lettura fallita non cambia niente (né lega, né scade).
      directory.failure = Exception('rete');
      await relaunch(_me);
      expect(sources().single.params.containsKey('account'), isFalse);
      expect(container.read(storageSourcesProvider).notices, isEmpty);

      directory.failure = null;
      directory.notifyChanged();
      await _settle();
      expect(sources().single.params['account'], _me);
      expect(sources().single.expiresAt, isNull);
      expect(container.read(storageSourcesProvider).notices, isEmpty);
    });

    test('una riga che non combacia non la lega', () async {
      await write(old);
      await relaunch(_me);
      await directory.put(row(folderId: 'altra'));
      directory.notifyChanged();
      await _settle();
      expect(sources().single.params.containsKey('account'), isFalse);
    });
  });

  test('le righe di un altro account non toccano le sorgenti', () async {
    final source = await accept();
    await relaunch(_other);
    // Per `altro` la stessa cartella è un invito suo; la sorgente di `me` non si tocca.
    await directory.put(row(to: _other));
    directory.notifyChanged();
    await _settle();
    expect(sources().single.toJson(), source.toJson());
    expect(container.read(shareInvitesProvider).single.to, _other);

    // Senza righe per `altro`, la sorgente di `me` non scade.
    directory.rows.clear();
    directory.notifyChanged();
    await _settle();
    expect(sources().single.toJson(), source.toJson());

    expect(followsShare(source, row(to: _other)), isFalse);
    expect(followsShare(source, row()), isTrue);
  });
}
