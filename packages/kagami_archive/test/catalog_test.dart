// Il catalogo dei siti (`docs/catalogo.md`): configurazione, firma, indice,
// scelta della variante e adozione, senza rete né disco.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/signature.dart';
import 'package:test/test.dart';

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

Map<String, Object?> variant(String id, int version, {int minEngine = 1, String? text}) => {
      'version': version,
      'minEngine': minEngine,
      'sha256': hash(text ?? site(id, version)),
      'path': 'sites/$id-$version.json',
    };

Map<String, Object?> indexJson({int serial = 2, Map<String, Object?>? sites}) => {
      'catalog': 1,
      'serial': serial,
      'issuedAt': '2026-11-15T09:30:00Z',
      'sites': sites ??
          {
            'alpha': {'state': 'ok', 'variants': [variant('alpha', 2)]},
          },
    };

List<int> bytesOf(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

void main() {
  group('configurazione', () {
    test('CATALOG_KEYS: chiavi valide per kid, le altre saltate e dette', () {
      final short = BigInt.one << 2047 | BigInt.one;
      final problems = <String>[];
      final parsed = parseCatalogKeys(
        ' test-1.${bigB64(n)}.${bigB64(e)} , corta.${bigB64(short)}.${bigB64(e)},Maiuscola.${bigB64(n)}.${bigB64(e)},'
        'rotta.@@.AQAB,pochi.AQAB,,test-1.${bigB64(n)}.${bigB64(BigInt.from(3))},pad.${base64Url.encode(bigToBytes(n, 384))}=.AQAB',
        onError: problems.add,
      );
      expect(parsed.keys, ['test-1']);
      expect(parsed['test-1']!.n, n);
      expect(parsed['test-1']!.e, e);
      expect(problems, hasLength(6));
      expect(parseCatalogKeys(''), isEmpty);
    });

    test('CATALOG_URLS: solo https, nell\'ordine', () {
      final problems = <String>[];
      final urls = parseCatalogUrls(
        'https://a.example/catalog, http://b.example/c,https://c.example/x/,ftp://d,https://u:p@e.example,',
        onError: problems.add,
      );
      expect(urls.map((uri) => '$uri'), ['https://a.example/catalog', 'https://c.example/x/']);
      expect(problems, hasLength(3));
    });
  });

  group('firma', () {
    final index = bytesOf(indexJson());

    test('basta una riga valida con kid noto; i kid ignoti si saltano', () {
      final file = utf8.encode('vecchia ${b64(List.filled(384, 1))}\r\ntest-1 ${b64(sign(index))}\n');
      expect(verifyCatalogSignature(index, file, keys), isTrue);
    });

    test('firma falsa, di altri byte, kid sconosciuto o file vuoto: no', () {
      final other = [...index, 0x20];
      expect(verifyCatalogSignature(other, sigFile(index), keys), isFalse);
      expect(verifyCatalogSignature(index, sigFile(index, kid: 'altra'), keys), isFalse);
      expect(verifyCatalogSignature(index, utf8.encode('test-1 ${b64(List.filled(384, 7))}'), keys), isFalse);
      expect(verifyCatalogSignature(index, utf8.encode('test-1 non*base64'), keys), isFalse);
      expect(verifyCatalogSignature(index, const [], keys), isFalse);
      expect(verifyCatalogSignature(index, sigFile(index), const {}), isFalse);
    });
  });

  group('indice', () {
    test('legge i campi e ignora quelli sconosciuti', () {
      final json = indexJson(sites: {
        'alpha': {
          'state': 'broken',
          'message': 'Non risponde.',
          'nuovo': true,
          'variants': [variant('alpha', 2), {...variant('alpha', 3, minEngine: 2), 'extra': 1}],
        },
      })
        ..['futuro'] = {'x': 1};
      final index = CatalogIndex.parse(bytesOf(json));
      expect(index.serial, 2);
      expect(index.issuedAt, DateTime.utc(2026, 11, 15, 9, 30));
      final alpha = index.sites['alpha']!;
      expect(alpha.state, CatalogSiteState.broken);
      expect(alpha.message, 'Non risponde.');
      expect(alpha.variants.map((v) => v.version), [2, 3]);
    });

    final bad = <String, void Function(Map<String, Object?> json)>{
      'formato sconosciuto': (json) => json['catalog'] = 2,
      'serial non intero': (json) => json['serial'] = '2',
      'serial decimale': (json) => json['serial'] = 2.5,
      'issuedAt non data': (json) => json['issuedAt'] = 'ieri',
      'sites lista': (json) => json['sites'] = [],
      'id non valido': (json) => json['sites'] = {'Alpha': (json['sites'] as Map)['alpha']},
      'state inventato': (json) => _alpha(json)['state'] = 'maybe',
      'message troppo lungo': (json) => _alpha(json)['message'] = 'x' * 301,
      'message non testo': (json) => _alpha(json)['message'] = 3,
      'nessuna variante': (json) => _alpha(json)['variants'] = [],
      'nove varianti': (json) => _alpha(json)['variants'] = [for (var v = 1; v <= 9; v++) variant('alpha', v)],
      'versioni ripetute': (json) => _alpha(json)['variants'] = [variant('alpha', 2), variant('alpha', 2)],
      'sha maiuscolo': (json) => _first(json)['sha256'] = hash('x').toUpperCase(),
      'sha corto': (json) => _first(json)['sha256'] = 'abc',
      'minEngine testo': (json) => _first(json)['minEngine'] = '1',
      'path con ..': (json) => _first(json)['path'] = 'sites/../secret.json',
      'path assoluto': (json) => _first(json)['path'] = '/etc/passwd',
      'path con schema': (json) => _first(json)['path'] = 'https://evil.com/x.json',
      'troppi siti': (json) => json['sites'] = {
            for (var i = 0; i < 201; i++) 's$i': {'state': 'ok', 'variants': [variant('s$i', 1)]},
          },
    };
    for (final MapEntry(key: name, value: edit) in bad.entries) {
      test('indice invalido: $name', () {
        final json = jsonDecode(jsonEncode(indexJson())) as Map<String, Object?>;
        edit(json);
        expect(() => CatalogIndex.parse(bytesOf(json)), throwsA(isA<CatalogFormatError>()));
      });
    }

    test('oltre 1 MB o non JSON: invalido', () {
      expect(() => CatalogIndex.parse(List.filled(maxCatalogIndexBytes + 1, 0x20)), throwsA(isA<CatalogFormatError>()));
      expect(() => CatalogIndex.parse(utf8.encode('{')), throwsA(isA<CatalogFormatError>()));
    });
  });

  group('variante', () {
    final alpha = CatalogIndex.parse(bytesOf(indexJson(sites: {
      'alpha': {
        'state': 'ok',
        'variants': [variant('alpha', 6), variant('alpha', 8, minEngine: 3), variant('alpha', 7, minEngine: 2)],
      },
    }))).sites['alpha']!;

    test('la version più alta con minEngine ≤ engine', () {
      expect(alpha.choose(engine: 1)!.version, 6);
      expect(alpha.choose(engine: 2)!.version, 7);
      expect(alpha.choose(engine: 9)!.version, 8);
    });

    test('nessuna adatta: null', () {
      final future = CatalogIndex.parse(bytesOf(indexJson(sites: {
        'alpha': {'state': 'ok', 'variants': [variant('alpha', 9, minEngine: catalogEngine + 1)]},
      }))).sites['alpha']!;
      expect(future.choose(), isNull);
    });
  });

  group('adozione', () {
    late Map<String, String> files;
    late List<String> asked;

    Future<List<int>?> fetch(String path) async {
      asked.add(path);
      final text = files[path];
      return text == null ? null : utf8.encode(text);
    }

    setUp(() {
      files = {
        'sites/alpha-1.json': site('alpha', 1),
        'sites/alpha-2.json': site('alpha', 2),
        'sites/beta-1.json': site('beta', 1),
        'sites/beta-2.json': site('beta', 2),
      };
      asked = [];
    });

    Future<CatalogAdoption> adopt(Map<String, Object?> json, {AdoptedCatalog? previous, List<int>? signature, int engine = catalogEngine}) {
      final bytes = bytesOf(json);
      return adoptCatalog(
        previous: previous,
        indexBytes: bytes,
        signatureBytes: signature ?? sigFile(bytes),
        keys: keys,
        fetchSite: fetch,
        engine: engine,
      );
    }

    Map<String, Object?> two({int serial = 2, int alpha = 2, int beta = 2}) => indexJson(serial: serial, sites: {
          'alpha': {'state': 'ok', 'variants': [variant('alpha', alpha)]},
          'beta': {'state': 'broken', 'message': 'Giù.', 'variants': [variant('beta', beta)]},
        });

    Future<AdoptedCatalog> first() async => (await adopt(two(serial: 1, alpha: 1, beta: 1))).catalog!;

    test('primo catalogo: tutti i siti adottati', () async {
      final result = await adopt(two());
      expect(result.outcome, CatalogOutcome.adopted);
      expect(result.serial, 2);
      expect(result.catalog!.definitions['alpha']!.text, files['sites/alpha-2.json']);
      expect(result.sites['beta']!.state, CatalogSiteState.broken);
      expect(result.sites['beta']!.message, 'Giù.');
      expect(result.sites['beta']!.problem, isNull);
      expect(result.catalog!.cachedShas, {hash(site('alpha', 2)), hash(site('beta', 2))});
    });

    test('firma falsa: si tiene il precedente', () async {
      final previous = await first();
      final result = await adopt(two(), previous: previous, signature: sigFile(utf8.encode('altro')));
      expect(result.outcome, CatalogOutcome.badSignature);
      expect(result.catalog, same(previous));
    });

    test('serial minore: rifiuto; uguale con byte diversi: rifiuto; uguale e uguale: invariato', () async {
      final previous = (await adopt(two(serial: 5))).catalog!;
      expect((await adopt(two(serial: 4), previous: previous)).outcome, CatalogOutcome.rollback);
      expect((await adopt(two(serial: 5, beta: 1), previous: previous)).outcome, CatalogOutcome.rollback);
      asked.clear();
      final same = await adopt(two(serial: 5), previous: previous);
      expect(same.outcome, CatalogOutcome.unchanged);
      expect(same.catalog!.serial, 5);
      expect(asked, isEmpty);
    });

    test('formato sconosciuto: invalido, si tiene il precedente', () async {
      final previous = await first();
      final result = await adopt(two(serial: 3)..['catalog'] = 2, previous: previous);
      expect(result.outcome, CatalogOutcome.invalid);
      expect(result.catalog, same(previous));
    });

    test('impronta già in cache: non si riscarica', () async {
      final previous = await first();
      asked.clear();
      final result = await adopt(two(serial: 2, alpha: 1, beta: 2), previous: previous);
      expect(result.outcome, CatalogOutcome.adopted);
      expect(asked, ['sites/beta-2.json']);
      expect(result.catalog!.definitions['alpha']!.version, 1);
    });

    test('un sito che non passa tiene la sua variante, gli altri passano', () async {
      final previous = await first();
      files['sites/alpha-2.json'] = site('alpha', 2, title: 'h2');
      final result = await adopt(two(), previous: previous);
      expect(result.outcome, CatalogOutcome.adopted);
      expect(result.sites['alpha']!.problem, CatalogSiteProblem.hashMismatch);
      expect(result.catalog!.definitions['alpha']!.version, 1);
      expect(result.catalog!.definitions['beta']!.version, 2);
      expect(result.catalog!.cachedShas, {hash(site('alpha', 1)), hash(site('beta', 2))});
    });

    test('file irraggiungibile ≠ sito sparito: si tiene il precedente', () async {
      final previous = await first();
      files.remove('sites/beta-2.json');
      final result = await adopt(two(), previous: previous);
      expect(result.sites['beta']!.problem, CatalogSiteProblem.unreachable);
      expect(result.catalog!.definitions['beta']!.version, 1);
    });

    test('id o version diversi dall\'indice, file non valido o troppo grande: rifiutati', () async {
      final wrongId = site('gamma', 2);
      final wrongVersion = site('beta', 3);
      final big = ' ' * (maxCatalogSiteBytes + 1);
      files['sites/alpha-2.json'] = wrongId;
      files['sites/beta-2.json'] = wrongVersion;
      files['sites/c-1.json'] = '{"format": 1}';
      files['sites/d-1.json'] = big;
      final result = await adopt(indexJson(sites: {
        'alpha': {'state': 'ok', 'variants': [variant('alpha', 2, text: wrongId)]},
        'beta': {'state': 'ok', 'variants': [variant('beta', 2, text: wrongVersion)]},
        'c': {'state': 'ok', 'variants': [{...variant('c', 1, text: '{"format": 1}'), 'path': 'sites/c-1.json'}]},
        'd': {'state': 'ok', 'variants': [{...variant('d', 1, text: big), 'path': 'sites/d-1.json'}]},
      }));
      expect(result.outcome, CatalogOutcome.adopted);
      expect(result.sites['alpha']!.problem, CatalogSiteProblem.mismatch);
      expect(result.sites['beta']!.problem, CatalogSiteProblem.mismatch);
      expect(result.sites['c']!.problem, CatalogSiteProblem.invalid);
      expect(result.sites['d']!.problem, CatalogSiteProblem.tooLarge);
      expect(result.catalog!.definitions, isEmpty);
    });

    test('serve un motore più nuovo: si tiene il precedente e lo si dice', () async {
      final previous = await first();
      final result = await adopt(indexJson(sites: {
        'alpha': {'state': 'ok', 'variants': [variant('alpha', 2, minEngine: catalogEngine + 1)]},
      }), previous: previous);
      expect(result.sites['alpha']!.problem, CatalogSiteProblem.needsNewerEngine);
      expect(result.catalog!.definitions['alpha']!.version, 1);
      expect(result.catalog!.definitions.containsKey('beta'), isFalse);
      final newer = await adopt(indexJson(serial: 3, sites: {
        'alpha': {'state': 'ok', 'variants': [variant('alpha', 2, minEngine: catalogEngine + 1)]},
      }), previous: previous, engine: catalogEngine + 1);
      expect(newer.catalog!.definitions['alpha']!.version, 2);
    });
  });
}

Map<String, Object?> _alpha(Map<String, Object?> json) => (json['sites'] as Map)['alpha'] as Map<String, Object?>;

Map<String, Object?> _first(Map<String, Object?> json) => (_alpha(json)['variants'] as List).first as Map<String, Object?>;
