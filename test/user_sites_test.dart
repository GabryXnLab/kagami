// I siti degli utenti nella libreria: installare scrive il file, togliere lo
// cancella, l'aggiornamento vuole una versione più alta e una lettura fallita
// non svuota i siti già installati.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/site_replacements.dart';
import 'package:kagami/src/data/user_sites.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/providers.dart' as archive show installUserProviders, providers;
import 'package:kagami_archive/stores.dart';

Map<String, Object?> siteJson(String id, {int version = 1, String? update, String host = 'examplescans.com'}) => {
      'format': 1,
      'id': id,
      'name': 'Example $id',
      'version': version,
      'update': ?update,
      'home': 'https://$host',
      'hosts': [host],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'title': 'h1',
        'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'img', 'url': {'attr': 'src'}},
      },
    };

DeclarativeProvider site(String id, {int version = 1, String? update}) =>
    DeclarativeProvider.fromJson(siteJson(id, version: version, update: update));

void main() {
  late KagamiDatabase db;
  late Directory root;
  late bool failing;
  late bool noLibrary;
  late Map<String, String> remote;
  late int syncs;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('user_sites_');
    failing = false;
    noLibrary = false;
    remote = {};
    syncs = 0;
  });

  tearDown(() async {
    archive.installUserProviders(const []);
    await db.close();
    root.deleteSync(recursive: true);
  });

  File file(String id) => File('${root.path}/providers/$id.json');

  ProviderContainer make() {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      siteReplacementsProvider.overrideWithValue(SiteReplacements(File('${root.path}/site-replacements.json'))),
      userSitesAccessProvider.overrideWithValue(({required write}) async {
        if (failing) throw const FileSystemException('non si apre');
        if (noLibrary) return null;
        return (store: LocalStore(root.path), close: () {});
      }),
      siteFetcherProvider.overrideWithValue((url) async => remote[url] ?? (throw const SocketException('offline'))),
      userSitesServerSyncProvider.overrideWithValue(() async => syncs++),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('installare scrive il file, mette il sito nel motore e avvisa il server', () async {
    final container = make();
    expect((await container.read(userSitesProvider.future)).sites, isEmpty);

    await container.read(userSitesProvider.notifier).install(site('examplescans'));

    expect(file('examplescans').existsSync(), isTrue);
    expect(container.read(userSitesProvider).value!.sites.map((s) => s.id), ['examplescans']);
    expect(archive.providers.any((p) => p.id == 'examplescans' && !p.builtIn), isTrue);
    expect(syncs, 1);
  });

  test('un sito della libreria con l\'id di uno incluso non lo sostituisce senza conferma (T10)', () async {
    file('coffeemanga').parent.createSync(recursive: true);
    file('coffeemanga').writeAsStringSync(jsonEncode(siteJson('coffeemanga')));
    final container = make();
    final sites = await container.read(userSitesProvider.future);
    expect(sites.sites.map((s) => s.id), ['coffeemanga']);
    expect(sites.replacesBuiltIn('coffeemanga'), isTrue);
    expect(sites.unconfirmed, {'coffeemanga'});
    expect(archive.providers.firstWhere((p) => p.id == 'coffeemanga').builtIn, isTrue);

    await container.read(userSitesProvider.notifier).confirmReplacement('coffeemanga');

    expect(container.read(userSitesProvider).value!.unconfirmed, isEmpty);
    expect(archive.providers.firstWhere((p) => p.id == 'coffeemanga').builtIn, isFalse);
  });

  test('la conferma vale per quel file: se cambia, torna a chiederla (T10)', () async {
    file('coffeemanga').parent.createSync(recursive: true);
    file('coffeemanga').writeAsStringSync(jsonEncode(siteJson('coffeemanga')));
    final container = make();
    await container.read(userSitesProvider.future);
    await container.read(userSitesProvider.notifier).confirmReplacement('coffeemanga');

    file('coffeemanga').writeAsStringSync(jsonEncode(siteJson('coffeemanga', version: 2)));
    container.invalidate(userSitesProvider);
    final sites = await container.read(userSitesProvider.future);

    expect(sites.unconfirmed, {'coffeemanga'});
    expect(archive.providers.firstWhere((p) => p.id == 'coffeemanga').builtIn, isTrue);
  });

  test('togliere cancella solo il file e il sito esce dal motore', () async {
    final container = make();
    final notifier = container.read(userSitesProvider.notifier);
    await container.read(userSitesProvider.future);
    await notifier.install(site('examplescans'));
    await notifier.remove('examplescans');

    expect(file('examplescans').existsSync(), isFalse);
    expect(container.read(userSitesProvider).value!.sites, isEmpty);
    expect(archive.providers.any((p) => p.id == 'examplescans'), isFalse);
    expect(syncs, 2);
  });

  test('l\'aggiornamento si applica solo con una versione più alta, e un errore lascia il sito', () async {
    const url = 'https://examplescans.com/site.json';
    final container = make();
    final notifier = container.read(userSitesProvider.notifier);
    await container.read(userSitesProvider.future);
    await notifier.install(site('examplescans', version: 2, update: url));

    remote[url] = jsonEncode(siteJson('examplescans', version: 2, update: url));
    expect(await notifier.checkUpdates(force: true), isEmpty);

    remote[url] = jsonEncode(siteJson('examplescans', version: 1, update: url));
    expect(await notifier.checkUpdates(force: true), isEmpty);

    remote[url] = 'non è json';
    expect(await notifier.checkUpdates(force: true), isEmpty);

    remote.remove(url);
    expect(await notifier.checkUpdates(force: true), isEmpty);
    expect(container.read(userSitesProvider).value!.sites.single.version, 2);

    remote[url] = jsonEncode(siteJson('examplescans', version: 3, update: url));
    expect(await notifier.checkUpdates(force: true), ['examplescans']);
    expect(container.read(userSitesProvider).value!.sites.single.version, 3);
    expect(jsonDecode(file('examplescans').readAsStringSync())['version'], 3);
  });

  test('il controllo degli aggiornamenti è al più uno al giorno', () async {
    const url = 'https://examplescans.com/site.json';
    final container = make();
    final notifier = container.read(userSitesProvider.notifier);
    await container.read(userSitesProvider.future);
    await notifier.install(site('examplescans', update: url));

    remote[url] = jsonEncode(siteJson('examplescans', version: 2, update: url));
    expect(await notifier.checkUpdates(), ['examplescans']);
    remote[url] = jsonEncode(siteJson('examplescans', version: 3, update: url));
    expect(await notifier.checkUpdates(), isEmpty);
    expect(container.read(userSitesProvider).value!.sites.single.version, 2);
  });

  test('una lettura fallita non svuota i siti installati', () async {
    final container = make();
    final notifier = container.read(userSitesProvider.notifier);
    await container.read(userSitesProvider.future);
    await notifier.install(site('examplescans'));

    failing = true;
    container.invalidate(userSitesProvider);
    final after = await container.read(userSitesProvider.future);
    expect(after.sites.map((s) => s.id), ['examplescans']);
    expect(archive.providers.any((p) => p.id == 'examplescans'), isTrue);
  });

  test('un file che non si legge non toglie il suo sito, ma si segnala', () async {
    final container = make();
    final notifier = container.read(userSitesProvider.notifier);
    await container.read(userSitesProvider.future);
    await notifier.install(site('examplescans'));

    file('examplescans').writeAsStringSync('{rotto');
    container.invalidate(userSitesProvider);
    final after = await container.read(userSitesProvider.future);
    expect(after.sites.map((s) => s.id), ['examplescans']);
    expect(after.errors.keys, ['examplescans.json']);
  });

  test('senza libreria l\'elenco è vuoto e non si può installare', () async {
    noLibrary = true;
    final container = make();
    final sites = await container.read(userSitesProvider.future);
    expect(sites.hasLibrary, isFalse);
    await expectLater(
        container.read(userSitesProvider.notifier).install(site('examplescans')), throwsA(isA<SiteDefinitionError>()));
  });

  test('fetchDefinition valida il file e rifiuta ciò che non è un sito', () async {
    const url = 'https://examplescans.com/site.json';
    final container = make();
    final notifier = container.read(userSitesProvider.notifier);
    remote[url] = jsonEncode(siteJson('examplescans'));
    expect((await notifier.fetchDefinition(url)).id, 'examplescans');
    remote[url] = '{"format": 9}';
    await expectLater(notifier.fetchDefinition(url), throwsA(isA<SiteDefinitionError>()));
  });

  test('fetchSiteText rifiuta un link che non è https', () async {
    await expectLater(fetchSiteText('http://examplescans.com/site.json'), throwsA(isA<SiteDefinitionError>()));
    await expectLater(fetchSiteText('non un link'), throwsA(isA<SiteDefinitionError>()));
  });
}
