// Un sito degli utenti con motore server resta sul telefono se il server non
// elenca userProviders; gli inclusi seguono sempre il motore scelto.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/archive/repair.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/user_sites.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/providers.dart' as archive show installUserProviders;

DeclarativeProvider site(String id) => DeclarativeProvider.fromJson({
      'format': 1,
      'id': id,
      'name': id,
      'version': 1,
      'home': 'https://examplescans.com',
      'hosts': ['examplescans.com'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'title': 'h1',
        'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'img', 'url': {'attr': 'src'}},
      },
    });

void main() {
  setUp(() => archive.installUserProviders([site('examplescans')]));
  tearDown(() => archive.installUserProviders(const []));

  test('la scelta per sito', () {
    ArchiveEngine pick(ArchiveEngine engine, String id, bool feature) =>
        engineForSite(engine, id, serverHasUserSites: feature);

    expect(pick(ArchiveEngine.server, 'examplescans', false), ArchiveEngine.phone);
    expect(pick(ArchiveEngine.server, 'examplescans', true), ArchiveEngine.server);
    expect(pick(ArchiveEngine.server, 'mangak', false), ArchiveEngine.server);
    expect(pick(ArchiveEngine.server, 'sconosciuto', false), ArchiveEngine.server);
    expect(pick(ArchiveEngine.phone, 'examplescans', true), ArchiveEngine.phone);
    expect(siteOfKey('examplescans:fog-land'), 'examplescans');
  });

  test('la riparazione di un sito degli utenti va al telefono se il server non ha la funzione', () async {
    final db = KagamiDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final calls = <String>[];
    ProviderContainer make(bool feature) {
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        archiveEngineProvider.overrideWithValue(ArchiveEngine.server),
        serverUserSitesProvider.overrideWith((ref) async => feature),
        serverRepairRunProvider.overrideWithValue(({site, keys}) async => calls.add('server $site')),
        phoneRepairRunProvider.overrideWithValue(({site, keys, progress}) async {
          calls.add('phone $site');
          return 0;
        }),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    await make(false).read(repairProvider.notifier).start(site: 'examplescans');
    await make(true).read(repairProvider.notifier).start(site: 'examplescans');
    await make(false).read(repairProvider.notifier).start(site: 'mangak');
    expect(calls, ['phone examplescans', 'server examplescans', 'server mangak']);
  });
}
