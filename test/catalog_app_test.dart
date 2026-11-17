// Il catalogo sul telefono (`docs/catalogo.md`): configurazione, cache in
// `catalog/`, ETag, indirizzi in ordine e letture fallite che non svuotano.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/catalog_config.dart';
import 'package:kagami/src/data/catalog_sync.dart';
import 'package:kagami/src/data/user_sites.dart' show noServerSites, serverCatalogOlder;
import 'package:kagami_archive/jobs.dart' show CheckScope;
import 'package:kagami_archive/catalog.dart';
import 'package:kagami/src/data/catalog_recheck.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart' show builtInProviders, installCatalogProviders, providerById;
import 'package:kagami_archive/signature.dart';
import 'package:path/path.dart' as p;

// Una chiave da 3072 bit generata con openssl solo per questi test: non firma
// niente fuori da qui.
final BigInt n = BigInt.parse(
  '99f2dfc73be96a38f92cba80cf7007428e4573d6c41cf6d8bef256f6e39001de198d0b21e0252b75e6ad3c290e92a3fc'
  '1674fb5194636bbc928a61e4c1d032e8c754b123da9d76e83bb559df12fa7d9026971e52d9bb0c756824d0fda3b62cd1'
  '564d62006b805e9d43cde11a048961d20b8d6299c241274cf6a79e1947ec330c656b8ce99e7ac0bdfdceca217bb55855'
  'e3349cb296b7c4c6bf62aec0f2997582a0394fe2af97e0e5cf66cfaf5b444e85a65f79f108d813e13a49011d9af96617'
  '2e7fb8759fcbe45fccfa406782dde14a6cdc6c1ca9a8ea9af8a432cd3735eaa701e5c45ff86de96f3a3010b733ef09d2'
  'c9b793a7c377ee5426587284f7a27110309c362967d7e84dcc835c1a5b6bf4585a4de371cfeec92c90371268520d255d'
  '19013b0149fa01099d3ec4125304fb11a6301f05639aef3a0e3d30e3581fef32d51fc6e2b330d8eb125860a4858995ab'
  '9f448bbd1bbda09441da5613afaf7c60095269735c4b6c799743563a30925d3b1ab24845dbe9c1257fda92cf70d51f21',
  radix: 16,
);
final BigInt d = BigInt.parse(
  '3c8025f09afb76cad026035f96e62c7c3c04506b7123fee09c5e09ce3a0d40a6a3bcf9c884d9a6b44d84fc35186c89b4'
  '8ab0cb89ba7abdfedc4a35019d2770b2698fbf93db18f1ff7f639c5f9e0a422951f926aa21b63045bdb966469fbd7aec'
  '83f1a2578ee7e287047c17004e131d95da0364e20f64e2888d10bf81a8f1caf80ead8f31ca9dec3c5e5013c0c7e8b340'
  '01ac0dfee35b72223759955aef9c5e8188ed2d1765b196e949b25a614c49526094cb45d57387d37c3a9731308cd48189'
  '739c0c65f6d6fa08629cc130bf21bdbb9d83f5d4f19f1898f20bdd5bb807e9a30e5b6933e58ca3bb5bddd3e41dfe27cc'
  '644724e0688a0441978c03fb1531743fd97d464e743bef701e4c71d56d7b6fae84374bcf67906b90d41290adf7065b4a'
  'f1d6f5ff457efbd2eb354876b1391bad06581dcde5cd20403143b065f0d28e4ae87a57aa26961b9572a5eeed24b375fc'
  '922cc795acc6f12e5b04aebf01ff8cc16ea16e331213feb3c36b071c9ccf37c9a1030236077c4b5f53cfd3d5cc77aecf',
  radix: 16,
);
final BigInt e = BigInt.from(65537);
final RsaKey key = (n: n, e: e);
final Map<String, RsaKey> keys = {'test-1': key};

String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String bigB64(BigInt value) => b64(bigToBytes(value, (value.bitLength + 7) ~/ 8));

/// RSASSA-PKCS1-v1_5 con SHA-256, firmata con [d].
List<int> sign(List<int> message) {
  final length = (n.bitLength + 7) ~/ 8;
  final t = [
    0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
    ...sha256.convert(message).bytes,
  ];
  final em = [0x00, 0x01, for (var i = 0; i < length - t.length - 3; i++) 0xff, 0x00, ...t];
  return bigToBytes(bytesToBig(em).modPow(d, n), length);
}

List<int> sigFile(List<int> index, {String kid = 'test-1'}) => utf8.encode('$kid ${b64(sign(index))}\n');

String site(String id, int version, {String title = 'h1'}) => jsonEncode({
      'format': 1,
      'id': id,
      'name': 'Sito $id',
      'version': version,
      'home': 'https://$id.com',
      'hosts': ['$id.com'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'url': 'https://$id.com/manga/{id}',
        'title': title,
        'chapters': {
          'items': 'ul li',
          'url': {'css': 'a', 'attr': 'href'},
          'title': 'a',
        },
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/c-[a-z0-9-]+/?$',
        'pages': {'items': 'div img', 'url': {'attr': 'src'}},
      },
    });

String hash(String text) => sha256.convert(utf8.encode(text)).toString();

Map<String, Object?> indexJson(int serial, {Map<String, int> sites = const {'alpha': 2}}) => {
      'catalog': 1,
      'serial': serial,
      'issuedAt': '2026-11-15T09:30:00Z',
      'sites': {
        for (final MapEntry(key: id, value: version) in sites.entries)
          id: {
            'state': 'ok',
            'variants': [
              {'version': version, 'minEngine': 1, 'sha256': hash(site(id, version)), 'path': 'sites/$id-$version.json'},
            ],
          },
      },
    };

/// Un server finto: i file per indirizzo, con ETag, e il registro delle richieste.
class FakeCatalog {
  final files = <String, List<int>>{};
  final etags = <String, String>{};
  final down = <String>{};
  final requests = <String>[];

  void publish(String base, Map<String, Object?> index, {Map<String, int> sites = const {'alpha': 2}, List<int>? signature}) {
    final bytes = utf8.encode(jsonEncode(index));
    files['$base/index.json'] = bytes;
    files['$base/index.sig'] = signature ?? sigFile(bytes);
    etags['$base/index.json'] = '"${index['serial']}"';
    for (final MapEntry(key: id, value: version) in sites.entries) {
      files['$base/sites/$id-$version.json'] = utf8.encode(site(id, version));
    }
  }

  Future<CatalogReply> fetch(Uri url, {String? ifNoneMatch, required int maxBytes}) async {
    requests.add('$url${ifNoneMatch == null ? '' : ' (If-None-Match)'}');
    final key = '$url';
    if (down.any(key.startsWith)) throw const SocketException('giù');
    final bytes = files[key];
    if (bytes == null) return const CatalogReply(status: 404);
    if (ifNoneMatch != null && ifNoneMatch == etags[key]) return const CatalogReply(status: 304);
    return CatalogReply(status: 200, bytes: bytes, etag: etags[key]);
  }
}

void main() {
  group('ricontrollo su ProviderChanged', recheckTests);
  const a = 'https://a.example/cat';
  const b = 'https://b.example/cat';
  late Directory dir;
  late FakeCatalog net;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('kagami-catalog');
    net = FakeCatalog();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  CatalogSync sync([List<String> urls = const [a]]) => CatalogSync(
        directory: dir,
        config: CatalogConfig(urls: [for (final u in urls) Uri.parse(u)], keys: keys),
        fetch: net.fetch,
      );
  String cached(String name) => File(p.join(dir.path, name)).readAsStringSync();

  test('senza configurazione niente catalogo e nessuna richiesta', () async {
    final unconfigured = CatalogSync(directory: dir, config: const CatalogConfig(), fetch: net.fetch);
    expect(await unconfigured.start(), isNull);
    expect(net.requests, isEmpty);
    expect(dir.listSync(), isEmpty);
    expect(CatalogConfig.environment.isConfigured, isFalse);
    expect(CatalogConfig.parse('https://a.example/c', '').isConfigured, isFalse);
    expect(CatalogConfig.parse('', 'k.AQAB.AQAB').isConfigured, isFalse);
  });

  test('primo avvio: adotta, scrive la cache e installa il sito', () async {
    net.publish(a, indexJson(5));
    final status = await sync().start();
    expect(status!.serial, 5);
    expect(status.sites['alpha']!.definition!.version, 2);
    expect(File(p.join(dir.path, 'index.sig')).existsSync(), isTrue);
    expect(File(p.join(dir.path, 'sites', '${hash(site('alpha', 2))}.json')).existsSync(), isTrue);
    expect(jsonDecode(cached('state.json'))['serial'], 5);
    expect(providerById('alpha'), isNotNull);
  });

  test('avvio dalla cache: installa prima della rete, e con la rete giù tiene tutto', () async {
    net.publish(a, indexJson(5));
    await sync().start();
    net.down.add(a);
    net.requests.clear();
    final seen = <int>[];
    final status = await sync().start(onCached: (s) => seen.add(s.serial));
    expect(seen, [5]);
    expect(status!.serial, 5);
    expect(status.sites['alpha']!.definition, isNotNull);
    expect(cached('index.json'), isNotEmpty);
  });

  test('secondo controllo con ETag: 304, niente di riscritto', () async {
    net.publish(a, indexJson(5));
    await sync().start();
    net.requests.clear();
    expect(await sync().start(), isA<CatalogStatus>());
    expect(net.requests.first, '$a/index.json (If-None-Match)');
    expect(net.requests, hasLength(1));
  });

  test('indice nuovo: aggiorna e toglie dalla cache le definizioni non più nominate', () async {
    net.publish(a, indexJson(5));
    await sync().start();
    net.publish(a, indexJson(6, sites: {'alpha': 3}), sites: {'alpha': 3});
    final status = await sync().start();
    expect(status!.serial, 6);
    final names = Directory(p.join(dir.path, 'sites')).listSync().map((f) => p.basename(f.path)).toList();
    expect(names, ['${hash(site('alpha', 3))}.json']);
  });

  test('un indirizzo giù o con firma falsa passa al successivo', () async {
    net.publish(a, indexJson(5));
    net.publish(b, indexJson(5));
    net.down.add(a);
    expect((await sync([a, b]).start())!.serial, 5);
    expect(net.requests.first, startsWith(a));

    net.down.clear();
    net.publish(a, indexJson(7), signature: utf8.encode('test-1 AAAA\n'));
    net.publish(b, indexJson(8), sites: {'alpha': 2});
    expect((await sync([a, b]).start())!.serial, 8);
  });

  test('una lettura fallita non svuota il catalogo: rete giù, firma falsa, rollback', () async {
    net.publish(a, indexJson(5));
    await sync().start();
    final before = cached('index.json');

    net.down.add(a);
    expect((await sync().start())!.serial, 5);
    net.down.clear();
    net.publish(a, indexJson(9), signature: utf8.encode('test-1 AAAA\n'));
    expect((await sync().start())!.serial, 5);
    net.publish(a, indexJson(4));
    expect((await sync().start())!.serial, 5);
    expect(cached('index.json'), before);
    expect(providerById('alpha'), isNotNull);
  });

  test('un file di sito irraggiungibile tiene la variante di prima, gli altri passano', () async {
    net.publish(a, indexJson(5, sites: {'alpha': 2, 'beta': 1}), sites: {'alpha': 2, 'beta': 1});
    await sync().start();
    net.publish(a, indexJson(6, sites: {'alpha': 3, 'beta': 2}), sites: {'alpha': 3, 'beta': 2});
    net.files.remove('$a/sites/alpha-3.json');
    final status = await sync().start();
    expect(status!.serial, 6);
    expect(status.sites['alpha']!.problem, CatalogSiteProblem.unreachable);
    expect(status.sites['alpha']!.definition!.version, 2);
    expect(status.sites['beta']!.definition!.version, 2);
  });
}

class _Clock {
  DateTime now = DateTime.utc(2026, 11, 15, 10);
  DateTime call() => now;
}

void recheckTests() {
  const a = 'https://a.example/cat';
  late Directory dir;
  late FakeCatalog net;
  late _Clock clock;
  late List<String> reports;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('kagami-recheck');
    net = FakeCatalog();
    clock = _Clock();
    reports = [];
  });
  tearDown(() {
    installCatalogProviders(const []);
    dir.deleteSync(recursive: true);
  });

  CatalogRecheck recheck({bool configured = true}) => CatalogRecheck(
        sync: CatalogSync(
          directory: dir,
          config: configured ? CatalogConfig(urls: [Uri.parse(a)], keys: keys) : const CatalogConfig(),
          fetch: net.fetch,
          now: clock.call,
        ),
        now: clock.call,
        report: (error, site, version) => reports.add('$site:$version'),
      );

  Future<String> failing(CatalogRecheck r, List<int> calls) => r.guard('alpha', () async {
        calls.add(calls.length);
        if (providerById('alpha') case final DeclarativeProvider p when p.version >= 3) return 'ok v${p.version}';
        throw const ProviderChanged('rotto');
      });

  test('ProviderChanged: variante nuova, ritenta una volta e riesce; il tag porta la versione in uso', () async {
    net.publish(a, indexJson(5));
    final r = recheck();
    await r.sync.start();
    net.publish(a, indexJson(6, sites: {'alpha': 3}), sites: {'alpha': 3});
    final calls = <int>[];
    expect(await failing(r, calls), 'ok v3');
    expect(calls, hasLength(2));
    expect(reports, ['alpha:2']);
  });

  test('senza variante nuova non ritenta, e il ricontrollo è al più uno ogni 10 minuti per processo', () async {
    net.publish(a, indexJson(5));
    final r = recheck();
    await r.sync.start();
    net.requests.clear();
    final calls = <int>[];
    await expectLater(failing(r, calls), throwsA(isA<ProviderChanged>()));
    expect(calls, hasLength(1));
    expect(net.requests, isNotEmpty);

    net.publish(a, indexJson(6, sites: {'alpha': 3}), sites: {'alpha': 3});
    net.requests.clear();
    clock.now = clock.now.add(const Duration(minutes: 9));
    await expectLater(failing(r, calls), throwsA(isA<ProviderChanged>()));
    expect(net.requests, isEmpty);

    clock.now = clock.now.add(const Duration(minutes: 2));
    expect(await failing(r, calls), 'ok v3');
  });

  test('senza catalogo configurato non fa niente: nessuna richiesta, nessun ritento', () async {
    final r = recheck(configured: false);
    final calls = <int>[];
    await expectLater(failing(r, calls), throwsA(isA<ProviderChanged>()));
    expect(calls, hasLength(1));
    expect(net.requests, isEmpty);
    expect(dir.listSync(), isEmpty);
  });

  test('onChanged: segnala e dice se c\'è una variante nuova, con lo stesso tetto', () async {
    net.publish(a, indexJson(5));
    final r = recheck();
    await r.sync.start();
    net.publish(a, indexJson(6, sites: {'alpha': 3}), sites: {'alpha': 3});
    expect(await r.onChanged('alpha', const ProviderChanged('rotto')), isTrue);
    expect(reports, ['alpha:2']);
    clock.now = clock.now.add(const Duration(minutes: 1));
    net.requests.clear();
    expect(await r.onChanged('alpha', const ProviderChanged('rotto')), isFalse);
    expect(net.requests, isEmpty);
  });

  test('CheckScope: l\'origine decide chi controlla col server, e viaggia nel file', () async {
    net.publish(a, indexJson(5));
    await recheck().sync.start();
    final scope = CheckScope.fromJson(const CheckScope(toServer: true, catalogOnPhone: true).toJson());
    expect(scope.catalogOnPhone, isTrue);
    expect(scope.phoneChecks(providerById('alpha')!), isTrue);
    expect(const CheckScope(toServer: true, userSitesOnPhone: true).phoneChecks(providerById('alpha')!), isFalse);
    expect(scope.phoneChecks(builtInProviders.first), isFalse);
  });

  test('serverCatalogOlder: engine o serial più vecchi, o senza catalogo', () {
    expect(serverCatalogOlder(noServerSites, 0), isTrue);
    expect(serverCatalogOlder((userSites: true, catalogEngine: catalogEngine, catalogSerial: 5), 5), isFalse);
    expect(serverCatalogOlder((userSites: true, catalogEngine: catalogEngine, catalogSerial: 4), 5), isTrue);
  });
}
