/// Le sorgenti in più: come si salvano, e cosa succede quando ciò che è
/// salvato non si capisce.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_sources.dart';

SourceConfig webdav(String id, {int order = 0, DateTime? expiresAt}) => SourceConfig(
      id: id,
      kind: SourceKind.webdav,
      label: 'NAS $id',
      params: const {'url': 'https://nas.example.com/dav', 'user': 'lettore', 'root': '/manga'},
      expiresAt: expiresAt,
      order: order,
    );

void main() {
  group('La lista salvata', () {
    test('va e torna, scadenza e parametri compresi', () {
      final expiry = DateTime.utc(2027, 1, 31, 12);
      final list = SourceList([webdav('s-00000001', expiresAt: expiry)]);
      final back = SourceList.decode(list.encode());
      expect(back.unreadable, isFalse);
      final source = back.sources.single;
      expect(source.id, 's-00000001');
      expect(source.kind, SourceKind.webdav);
      expect(source.label, 'NAS s-00000001');
      expect(source.params['root'], '/manga');
      expect(source.expiresAt, expiry);
      expect(source.expiredAt(expiry), isTrue);
      expect(source.expiredAt(expiry.subtract(const Duration(seconds: 1))), isFalse);
    });

    test('niente salvato è una lista vuota, non un errore', () {
      expect(SourceList.decode(null).sources, isEmpty);
      expect(SourceList.decode('').unreadable, isFalse);
    });

    test('ciò che non è una lista è illeggibile, non vuoto', () {
      for (final value in ['{', '{"id": "s-1"}', '"testo"']) {
        final list = SourceList.decode(value);
        expect(list.unreadable, isTrue, reason: value);
        expect(list.sources, isEmpty);
      }
    });

    test('l\'ordine è quello di order, poi dell\'id', () {
      final list = SourceList([
        webdav('s-0000000c', order: 1),
        webdav('s-0000000b', order: 0),
        webdav('s-0000000a', order: 1),
      ]);
      expect([for (final source in list.sources) source.id],
          ['s-0000000b', 's-0000000a', 's-0000000c']);
    });

    test('una riga di un tipo nato dopo non si usa e non si perde', () {
      final future = {'id': 's-0000000f', 'kind': 'teletrasporto', 'label': 'x', 'order': 3};
      final list = SourceList.decode(jsonEncode([webdav('s-00000001').toJson(), future]));
      expect(list.unreadable, isFalse);
      expect(list.sources.single.id, 's-00000001');
      final rewritten = jsonDecode(
        list.withSources([...list.sources, webdav('s-00000002', order: 1)]).encode(),
      ) as List;
      expect(rewritten, hasLength(3));
      expect(rewritten.last, future);
    });

    test('una scadenza che non si capisce non diventa «senza scadenza»', () {
      final row = webdav('s-00000001').toJson()..['expiresAt'] = 'domani';
      final list = SourceList.decode(jsonEncode([row]));
      expect(list.sources, isEmpty);
      expect(jsonDecode(list.encode()), [row]);
    });

    test('gli id nuovi hanno la forma che finisce negli indirizzi', () {
      final id = SourceConfig.newId();
      expect(id, matches(RegExp(r'^s-[0-9a-f]{8}$')));
      expect(SourceConfig.newId(), isNot(id));
    });
  });

  group('librarySourcesProvider', () {
    late KagamiDatabase db;
    late ProviderContainer container;
    late Directory temp;

    setUp(() {
      db = KagamiDatabase.forTesting(NativeDatabase.memory());
      // togliere una sorgente ripulisce le sue cartelle di cache e di stato
      temp = Directory.systemTemp.createTempSync('kagami_sources_');
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        appDirectoriesProvider.overrideWithValue(
          AppDirectories(support: '${temp.path}/support', cache: '${temp.path}/cache'),
        ),
      ]);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
      temp.deleteSync(recursive: true);
    });

    Future<String?> saved() =>
        container.read(userRepositoryProvider).readSetting(LibrarySources.settingKey);

    test('aggiungere, rinominare, riordinare, togliere', () async {
      final sources = container.read(librarySourcesProvider.notifier);
      expect((await container.read(librarySourcesProvider.future)).sources, isEmpty);
      await sources.add(webdav('s-0000000a'));
      await sources.add(webdav('s-0000000b'));
      await sources.replace(webdav('s-0000000a').copyWith(label: 'Soffitta'));
      await sources.reorder(['s-0000000b']);
      var list = SourceList.decode(await saved());
      expect([for (final source in list.sources) source.id], ['s-0000000b', 's-0000000a']);
      expect(list.byId('s-0000000a')!.label, 'Soffitta');

      await container.read(sourceSecretsProvider).write('s-0000000b', 'segreto');
      await sources.remove('s-0000000b');
      list = SourceList.decode(await saved());
      expect(list.sources.single.id, 's-0000000a');
      expect(await container.read(sourceSecretsProvider).read('s-0000000b'), isNull);
      expect(await saved(), isNot(contains('segreto')));
    });

    test('un\'impostazione illeggibile non si riscrive leggendola', () async {
      await container.read(userRepositoryProvider).writeSetting(LibrarySources.settingKey, '{rotto');
      final list = await container.read(librarySourcesProvider.future);
      expect(list.unreadable, isTrue);
      expect(list.sources, isEmpty);
      expect(await saved(), '{rotto');

      // Solo un gesto dell'utente la sostituisce.
      await container.read(librarySourcesProvider.notifier).add(webdav('s-0000000a'));
      expect(SourceList.decode(await saved()).sources.single.id, 's-0000000a');
    });
  });
}
