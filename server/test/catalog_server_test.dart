// Il catalogo dei siti sul server (`docs/catalogo.md`, «Sul server»): cache nel
// volume, ETag, indirizzi in ordine, mai un catalogo vuoto per una lettura
// fallita, e ciò che /v2/server ne dichiara.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/providers.dart' show Provider, ProviderOrigin, installCatalogProviders, providers;
import 'package:kagami_archive/signature.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';

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


String site(String id, int version) => jsonEncode({
      'format': 1,
      'id': id,
      'name': 'Sito $id',
      'version': version,
      'home': 'https://$id.com',
      'hosts': ['$id.com'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'url': 'https://$id.com/manga/{id}',
        'title': 'h1',
        'chapters': {'items': 'ul li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/c-[a-z0-9-]+/?$',
        'pages': {'items': 'div img', 'url': {'attr': 'src'}},
      },
    });

/// Un catalogo pubblicato: indice firmato e definizioni.
class Published {
  Published(int serial, Map<String, int> versions) {
    final sites = {for (final MapEntry(:key, :value) in versions.entries) key: site(key, value)};
    index = utf8.encode(jsonEncode({
      'catalog': 1,
      'serial': serial,
      'issuedAt': '2026-11-15T09:30:00Z',
      'sites': {
        for (final MapEntry(:key, :value) in versions.entries)
          key: {
            'state': 'ok',
            'variants': [
              {
                'version': value,
                'minEngine': 1,
                'sha256': sha256.convert(utf8.encode(sites[key]!)).toString(),
                'path': 'sites/$key-$value.json',
              },
            ],
          },
      },
    }));
    sig = sigFile(index);
    files = {for (final MapEntry(:key, :value) in versions.entries) 'sites/$key-$value.json': utf8.encode(sites[key]!)};
  }

  late final List<int> index, sig;
  late final Map<String, List<int>> files;
}

/// Un server HTTP che fa da indirizzo del catalogo, con l'ETag.
class FakeCatalogHost {
  FakeCatalogHost._(this.server) {
    server.listen((request) async {
      requests.add('${request.uri.path} ${request.headers.value(HttpHeaders.ifNoneMatchHeader) ?? ''}'.trim());
      final response = request.response;
      final published = this.published;
      final name = request.uri.path.substring('/catalog/'.length);
      final List<int>? bytes = published == null || down
          ? null
          : switch (name) {
              'index.json' => published.index,
              'index.sig' => badSignature ? sigFile([...published.index, 0]) : published.sig,
              _ => published.files[name],
            };
      if (bytes == null) {
        response.statusCode = HttpStatus.internalServerError;
      } else if (name == 'index.json' && request.headers.value(HttpHeaders.ifNoneMatchHeader) == '"v$etag"') {
        response.statusCode = HttpStatus.notModified;
      } else {
        if (name == 'index.json') response.headers.set(HttpHeaders.etagHeader, '"v$etag"');
        response.add(bytes);
      }
      await response.close();
    });
  }

  static Future<FakeCatalogHost> start() async => FakeCatalogHost._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer server;
  Published? published;
  bool down = false, badSignature = false;
  int etag = 1;
  final List<String> requests = [];

  Uri get url => Uri.parse('http://127.0.0.1:${server.port}/catalog');
}

void main() {
  late Directory dir;
  late FakeCatalogHost host;
  final lines = <String>[];

  ServerCatalog open({List<Uri>? urls}) => ServerCatalog(
        directory: Directory(p.join(dir.path, 'catalog')),
        urls: urls ?? [host.url],
        keys: keys,
        log: lines.add,
        minInterval: Duration.zero,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kagami-catalog-');
    host = await FakeCatalogHost.start();
    lines.clear();
  });
  tearDown(() async {
    installCatalogProviders(const []);
    await host.server.close(force: true);
    await dir.delete(recursive: true);
  });

  Provider? find(String id) => providers.where((provider) => provider.id == id).firstOrNull;

  group('configurazione', () {
    final urls = 'https://a.example/c';
    final keyText = 'test-1.${bigB64(n)}.${bigB64(e)}';

    test('assente o vuota: niente catalogo; KAGAMI_CATALOG_* vince anche se vuota', () {
      Directory d = dir;
      expect(ServerCatalog.fromEnvironment({}, d), isNull);
      expect(ServerCatalog.fromEnvironment({'CATALOG_URLS': urls}, d), isNull);
      expect(ServerCatalog.fromEnvironment({'CATALOG_URLS': urls, 'CATALOG_KEYS': keyText}, d), isNotNull);
      expect(ServerCatalog.fromEnvironment({'CATALOG_URLS': urls, 'CATALOG_KEYS': keyText, 'KAGAMI_CATALOG_URLS': ''}, d), isNull);
      expect(ServerCatalog.fromEnvironment({'CATALOG_URLS': urls, 'CATALOG_KEYS': keyText, 'KAGAMI_CATALOG_KEYS': ' '}, d), isNull);
      final other = ServerCatalog.fromEnvironment(
          {'CATALOG_URLS': urls, 'CATALOG_KEYS': keyText, 'KAGAMI_CATALOG_URLS': 'https://b.example/c'}, d);
      expect(other!.urls.map((uri) => '$uri'), ['https://b.example/c']);
    });

    test('variabile mal scritta: spento, senza eccezioni', () {
      final said = <String>[];
      expect(ServerCatalog.fromEnvironment({'KAGAMI_CATALOG_URLS': 'http://a.example', 'KAGAMI_CATALOG_KEYS': keyText}, dir, log: said.add), isNull);
      expect(said, isNotEmpty);
    });
  });

  group('recupero e cache', () {
    test('adotta, installa i siti con origin catalog e scrive la cache', () async {
      host.published = Published(5, {'alpha': 2, 'beta': 1});
      final catalog = open();
      await catalog.refresh();
      expect(catalog.serial, 5);
      expect(find('alpha')!.origin, ProviderOrigin.catalog);
      final cache = Directory(p.join(dir.path, 'catalog'));
      expect(File(p.join(cache.path, 'index.json')).existsSync(), isTrue);
      expect(File(p.join(cache.path, 'index.sig')).existsSync(), isTrue);
      final state = jsonDecode(File(p.join(cache.path, 'state.json')).readAsStringSync()) as Map;
      expect(state['serial'], 5);
      expect(state['etag'], '"v1"');
      expect(Directory(p.join(cache.path, 'sites')).listSync(), hasLength(2));
    });

    test('secondo controllo: If-None-Match e 304, niente da riscaricare', () async {
      host.published = Published(5, {'alpha': 2});
      final catalog = open();
      await catalog.refresh();
      host.requests.clear();
      await catalog.refresh();
      expect(host.requests, ['/catalog/index.json "v1"']);
      expect(catalog.serial, 5);
    });

    test('avvio dalla cache anche con l\'indirizzo spento; poi aggiorna e toglie le definizioni vecchie', () async {
      host.published = Published(5, {'alpha': 2});
      await open().refresh();
      installCatalogProviders(const []);
      host.down = true;
      final restarted = open();
      await restarted.load();
      expect(restarted.serial, 5);
      expect(find('alpha'), isNotNull);
      await restarted.refresh();
      expect(restarted.serial, 5);
      expect(find('alpha'), isNotNull, reason: 'una lettura fallita non svuota il catalogo');
      host.down = false;
      host.published = Published(6, {'beta': 1});
      host.etag = 2;
      await restarted.refresh();
      expect(restarted.serial, 6);
      expect(Directory(p.join(dir.path, 'catalog', 'sites')).listSync(), hasLength(1));
    });

    test('firma falsa o serial più basso: si tiene quello di prima', () async {
      host.published = Published(5, {'alpha': 2});
      final catalog = open();
      await catalog.refresh();
      host.published = Published(7, {'beta': 1});
      host.etag = 2;
      host.badSignature = true;
      await catalog.refresh();
      expect(catalog.serial, 5);
      host.badSignature = false;
      host.published = Published(4, {'beta': 1});
      host.etag = 3;
      await catalog.refresh();
      expect(catalog.serial, 5);
      expect(find('beta'), isNull);
    });

    test('indirizzi in ordine: il primo guasto passa al secondo', () async {
      host.published = Published(3, {'alpha': 1});
      final broken = Uri.parse('http://127.0.0.1:1/catalog');
      final catalog = open(urls: [broken, host.url]);
      await catalog.refresh();
      expect(catalog.serial, 3);
    });

    test('cache con altre chiavi: ignorata', () async {
      host.published = Published(3, {'alpha': 1});
      await open().refresh();
      installCatalogProviders(const []);
      final other = ServerCatalog(directory: Directory(p.join(dir.path, 'catalog')), urls: [host.url], keys: const {}, log: lines.add);
      await other.load();
      expect(other.serial, 0);
      expect(find('alpha'), isNull);
    });
  });

  group('/v2/server', () {
    const owner = 'owner@example.com';
    final http = HttpClient();

    Future<Map<String, Object?>> info(TestServer server) async {
      final request = await http.getUrl(server.address.replace(path: '/v2/server'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer tok:$owner');
      final response = await request.close();
      return jsonDecode(await utf8.decodeStream(response)) as Map<String, Object?>;
    }

    test('con il catalogo: funzione, engine e serial, origin catalog', () async {
      host.published = Published(9, {'alpha': 2});
      final catalog = open();
      await catalog.refresh();
      final server = await TestServer.start(owner: owner, catalog: catalog);
      addTearDown(server.close);
      await server.ready(owner);
      final body = await info(server);
      expect(body['features'], contains('catalog'));
      expect((body['catalog'] as Map)['serial'], 9);
      expect((body['catalog'] as Map)['engine'], isA<int>());
      final alpha = (body['providers'] as List).cast<Map>().firstWhere((site) => site['id'] == 'alpha');
      expect(alpha['origin'], 'catalog');
      expect(alpha['version'], 2);
      final builtIn = (body['providers'] as List).cast<Map>().firstWhere((site) => site['id'] != 'alpha');
      expect(builtIn.containsKey('origin'), isFalse);
    });

    test('senza catalogo: niente funzione né campo', () async {
      final server = await TestServer.start(owner: owner);
      addTearDown(server.close);
      await server.ready(owner);
      final body = await info(server);
      expect(body['features'], isNot(contains('catalog')));
      expect(body.containsKey('catalog'), isFalse);
    });
  });
}
