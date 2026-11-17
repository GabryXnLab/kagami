// Lo strumento di pubblicazione del catalogo (`tool/catalog.dart`): build,
// firma e verifica su una cartella temporanea.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/site_engine.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/catalog.dart';
import '../tool/site.dart';

// Chiave da 3072 bit generata con openssl solo per i test (stessa di catalog_test.dart).
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

List<int> _derInt(BigInt value) {
  var bytes = <int>[];
  for (var rest = value; rest > BigInt.zero; rest >>= 8) {
    bytes.insert(0, (rest & BigInt.from(0xff)).toInt());
  }
  if (bytes.isEmpty || bytes.first & 0x80 != 0) bytes = [0, ...bytes];
  return [0x02, ..._derLength(bytes.length), ...bytes];
}

List<int> _derLength(int length) => length < 0x80 ? [length] : [0x82, length >> 8, length & 0xff];

List<int> _derSeq(List<int> content) => [0x30, ..._derLength(content.length), ...content];

/// Un PKCS#1 «RSA PRIVATE KEY» con n, e, d veri e il resto a 0 (lo strumento non lo legge).
String pkcs1Pem() {
  final der = _derSeq([
    ..._derInt(BigInt.zero),
    ..._derInt(n),
    ..._derInt(BigInt.from(65537)),
    ..._derInt(d),
    for (var i = 0; i < 5; i++) ..._derInt(BigInt.one),
  ]);
  return '-----BEGIN RSA PRIVATE KEY-----\n${base64.encode(der)}\n-----END RSA PRIVATE KEY-----\n';
}

String siteJson(String id, int version, {Map<String, Object?> extra = const {}}) => jsonEncode({
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
      ...extra,
    });

void main() {
  late Directory tmp;
  late String sites;
  late String out;
  late String keyFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('catalog_tool_');
    sites = p.join(tmp.path, 'siti')..let(Directory.new).createSync();
    out = p.join(tmp.path, 'uscita');
    keyFile = p.join(tmp.path, 'chiave.pem');
    File(keyFile).writeAsStringSync(pkcs1Pem());
    File(p.join(sites, 'alpha.json')).writeAsStringSync(siteJson('alpha', 2));
    File(p.join(sites, 'beta.json')).writeAsStringSync(siteJson('beta', 5));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<({int code, String out, String err})> run(List<String> args) async {
    final o = StringBuffer();
    final e = StringBuffer();
    final code = await runCatalogTool(args, out: o, err: e);
    return (code: code, out: o.toString(), err: e.toString());
  }

  Future<void> publish({int serial = 1, List<String> more = const []}) async {
    expect((await run(['build', sites, out, '--serial', '$serial', ...more])).code, 0);
    expect((await run(['sign', out, '--kid', 'test-1', '--key', keyFile])).code, 0);
  }

  Future<String> pubkeys() async => (await run(['pubkey', keyFile, '--kid', 'test-1'])).out.trim();

  test('build, sign e verify: minEngine calcolato dallo strumento', () async {
    File(p.join(sites, 'beta.json')).writeAsStringSync(siteJson('beta', 5, extra: {'format': 2}));
    await publish();
    final index = CatalogIndex.parse(File(p.join(out, 'index.json')).readAsBytesSync());
    expect(index.serial, 1);
    expect(index.sites.keys, ['alpha', 'beta']);
    expect(index.sites['alpha']!.variants.single.minEngine, 1);
    expect(index.sites['beta']!.variants.single.minEngine, siteMinEngine(jsonDecode(siteJson('beta', 5, extra: {'format': 2})) as Map<String, Object?>).engine);
    expect(index.sites['beta']!.variants.single.minEngine, greaterThan(1));
    expect(File(p.join(out, 'sites', 'alpha-2.json')).existsSync(), isTrue);

    final keys = await pubkeys();
    final verified = await run(['verify', out, '--keys', keys]);
    expect(verified.err, isEmpty);
    expect(verified.code, 0);
    expect(verified.out, contains('beta [ok]: v5'));
    // Un motore vecchio non sceglie la variante che chiede un engine più alto.
    expect((await run(['verify', out, '--keys', keys, '--engine', '1'])).out, contains('beta [ok]: nessuna variante'));
  });

  test('sign sostituisce la riga dello stesso kid e tiene le altre', () async {
    await publish();
    await run(['sign', out, '--kid', 'altra', '--key', keyFile]);
    await run(['sign', out, '--kid', 'test-1', '--key', keyFile]);
    final lines = File(p.join(out, 'index.sig')).readAsLinesSync();
    expect(lines.map((l) => l.split(' ').first), ['altra', 'test-1']);
  });

  test('una definizione non valida non produce niente', () async {
    File(p.join(sites, 'beta.json')).writeAsStringSync(jsonEncode({'format': 1, 'id': 'beta', 'version': 1}));
    final result = await run(['build', sites, out, '--serial', '1']);
    expect(result.code, isNot(0));
    expect(result.err, contains('beta.json'));
    expect(Directory(out).existsSync(), isFalse);
  });

  test('un --check che fallisce non produce niente', () async {
    final result = await run(['build', sites, out, '--serial', '1', '--check', 'exit 3']);
    expect(result.code, isNot(0));
    expect(result.err, contains('exit 3'));
    expect(Directory(out).existsSync(), isFalse);
    expect((await run(['build', sites, out, '--serial', '1', '--check', 'true'])).code, 0);
  });

  test('il serial deve superare quello precedente; le varianti vecchie restano', () async {
    await publish();
    final previous = p.join(out, 'index.json');
    final next = p.join(tmp.path, 'dopo');
    expect((await run(['build', sites, next, '--serial', '1', '--previous', previous])).code, isNot(0));
    expect(Directory(next).existsSync(), isFalse);

    File(p.join(sites, 'alpha.json')).writeAsStringSync(siteJson('alpha', 3));
    File(p.join(sites, 'beta.json')).deleteSync();
    expect((await run(['build', sites, next, '--serial', '2', '--previous', previous])).code, 0);
    final index = CatalogIndex.parse(File(p.join(next, 'index.json')).readAsBytesSync());
    expect(index.sites['alpha']!.variants.map((v) => v.version), [3, 2]);
    expect(index.sites['beta']!.variants.single.version, 5);
    expect(File(p.join(next, 'sites', 'alpha-2.json')).existsSync(), isTrue);
  });

  test('status.json: state, message e builtin nell\'indice; un id senza definizione è un errore', () async {
    final status = File(p.join(tmp.path, 'status.json'));
    status.writeAsStringSync(jsonEncode({
      'sites': {
        'alpha': {'state': 'broken', 'message': 'Alpha è giù.'},
        'beta': {'builtin': 'off'},
      },
    }));
    expect((await run(['build', sites, out, '--serial', '1', '--status', status.path])).code, 0);
    final raw = jsonDecode(File(p.join(out, 'index.json')).readAsStringSync())['sites'] as Map;
    expect(raw['alpha']['state'], 'broken');
    expect(raw['alpha']['message'], 'Alpha è giù.');
    expect(raw['alpha'].containsKey('builtin'), isFalse);
    expect(raw['beta']['state'], 'ok');
    expect(raw['beta']['builtin'], 'off');

    // Con --previous lo stato non torna a ok da solo: lo decide il file.
    status.writeAsStringSync(jsonEncode({'sites': {'gamma': {'state': 'broken'}}}));
    final bad = await run(['build', sites, p.join(tmp.path, 'x'), '--serial', '2', '--status', status.path]);
    expect(bad.code, isNot(0));
    expect(bad.err, contains('gamma'));
  });

  test('--previous rifiuta stessa version con sha diverso', () async {
    await publish();
    File(p.join(sites, 'alpha.json')).writeAsStringSync(siteJson('alpha', 2, extra: {'name': 'Altro nome'}));
    final next = p.join(tmp.path, 'dopo');
    final result = await run(['build', sites, next, '--serial', '2', '--previous', p.join(out, 'index.json')]);
    expect(result.code, isNot(0));
    expect(result.err, contains('alpha.json'));
    expect(result.err, contains('version'));
    expect(Directory(next).existsSync(), isFalse);
  });

  test('--previous stampa gli host nuovi, anche negli indirizzi composti', () async {
    await publish();
    File(p.join(sites, 'alpha.json')).writeAsStringSync(siteJson('alpha', 3, extra: {
      'hosts': ['alpha.com', 'api.nuovo.org'],
      'mediaHosts': ['cdn.altro.net'],
      'search': {
        'url': 'https://api.nuovo.org/s?q={query}',
        'items': 'li',
        'link': {'css': 'a', 'attr': 'href'},
        'title': 'a',
      },
    }));
    final result = await run(['build', sites, p.join(tmp.path, 'dopo'), '--serial', '2', '--previous', p.join(out, 'index.json')]);
    expect(result.err, isEmpty);
    expect(result.out, contains('Host nuovo in alpha v3'));
    expect(result.out, contains('cdn.altro.net'));
    expect(result.out, contains('api.nuovo.org'));
    expect(result.out, isNot(contains('Host nuovo in beta')));
  });

  test('il lint gira in build: un error ferma, un warn si stampa', () async {
    final warn = await run(['build', sites, out, '--serial', '1']);
    expect(warn.code, 0);
    expect(warn.out, contains('lint alpha: warn single-source'));

    File(p.join(sites, 'beta.json')).writeAsStringSync(siteJson('beta', 5, extra: {'home': 'https://beta.com/_next/data/abc123/x.json'}));
    final next = p.join(tmp.path, 'dopo');
    final error = await run(['build', sites, next, '--serial', '1']);
    expect(error.code, isNot(0));
    expect(error.err, contains('volatile-segment'));
    expect(Directory(next).existsSync(), isFalse);
  });

  test('verify rifiuta un file alterato, una firma falsa e una chiave estranea', () async {
    await publish();
    final keys = await pubkeys();
    File(p.join(out, 'sites', 'alpha-2.json')).writeAsStringSync(siteJson('alpha', 2, extra: {'name': 'Altro'}));
    final tampered = await run(['verify', out, '--keys', keys]);
    expect(tampered.code, isNot(0));
    expect(tampered.err, contains('sha256'));

    await publish(serial: 2);
    File(p.join(out, 'index.json')).writeAsStringSync('${File(p.join(out, 'index.json')).readAsStringSync()} ');
    expect((await run(['verify', out, '--keys', keys])).err, contains('Firma'));

    await publish(serial: 3);
    final other = keys.replaceFirst('test-1.', 'altro.');
    expect((await run(['verify', out, '--keys', other])).code, isNot(0));
  });

  group('extends (temi a tempo di build)', () {
    late String themes;
    setUp(() {
      themes = p.join(tmp.path, 'themes')..let(Directory.new).createSync();
      File(p.join(sites, 'alpha.json')).deleteSync();
      File(p.join(sites, 'beta.json')).deleteSync();
    });

    Map<String, Object?> base() => jsonDecode(siteJson('x', 1)) as Map<String, Object?>;
    Map<String, Object?> themeOf() {
      final t = base()..removeWhere((k, _) => const {'id', 'name', 'version', 'home', 'hosts'}.contains(k));
      return t;
    }

    void writeTheme(String name, Map<String, Object?> t) => File(p.join(themes, '$name.json')).writeAsStringSync(jsonEncode(t));
    void writeSite(String id, int version, Map<String, Object?> extra) => File(p.join(sites, '$id.json')).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({'id': id, 'name': 'S $id', 'version': version, 'home': 'https://$id.com', 'hosts': ['$id.com'], 'extends': 't', ...extra, 'series': {'url': 'https://$id.com/manga/{id}', ...?extra['series'] as Map<String, Object?>?}}));
    Map<String, Object?> published(String id, int v) => jsonDecode(File(p.join(out, 'sites', '$id-$v.json')).readAsStringSync()) as Map<String, Object?>;

    test('merge profondo, null toglie, liste sostituite; si pubblica il piatto', () async {
      writeTheme('t', {
        'format': 1,
        'series': themeOf()['series'],
        'chapter': themeOf()['chapter'],
        'mediaHosts': ['a.example', 'b.example'],
      });
      writeSite('gamma', 3, {
        'series': {'title': 'h2'},
        'chapter': {'pages': {'items': 'section img'}},
        'mediaHosts': ['c.example'],
      });
      final r = await run(['build', sites, out, '--serial', '1']);
      expect(r.code, 0, reason: r.err);
      final flat = published('gamma', 3);
      expect(flat.containsKey('extends'), isFalse);
      expect((flat['series']! as Map)['title'], 'h2');
      expect((flat['series']! as Map)['chapters'], isNotNull);
      expect(((flat['chapter']! as Map)['pages']! as Map)['items'], 'section img');
      expect(((flat['chapter']! as Map)['pages']! as Map)['url'], {'attr': 'src'});
      expect(flat['mediaHosts'], ['c.example']);
      final index = CatalogIndex.parse(File(p.join(out, 'index.json')).readAsBytesSync());
      expect(index.sites['gamma']!.variants.single.sha256, sha256.convert(File(p.join(out, 'sites', 'gamma-3.json')).readAsBytesSync()).toString());
    });

    test('null nel sito toglie una chiave del tema', () async {
      writeTheme('t', {'format': 1, 'series': themeOf()['series'], 'chapter': themeOf()['chapter'], 'mediaHosts': ['a.example']});
      writeSite('gamma', 1, {'mediaHosts': null});
      {final r = await run(['build', sites, out, '--serial', '1']); expect(r.code, 0, reason: r.err);}
      expect(published('gamma', 1).containsKey('mediaHosts'), isFalse);
    });

    test('catena rifiutata', () async {
      writeTheme('t', {'extends': 'u', 'series': themeOf()['series'], 'chapter': themeOf()['chapter']});
      writeSite('gamma', 1, {});
      final r = await run(['build', sites, out, '--serial', '1']);
      expect(r.code, 1);
      expect(r.err, contains('catene'));
    });

    test('tema mancante = errore', () async {
      writeSite('gamma', 1, {});
      final r = await run(['build', sites, out, '--serial', '1']);
      expect(r.code, 1);
      expect(r.err, contains('Tema «t» non trovato'));
    });

    test('un tema con id non è un tema', () async {
      writeTheme('t', {'id': 'zzz', 'series': themeOf()['series'], 'chapter': themeOf()['chapter']});
      writeSite('gamma', 1, {});
      expect((await run(['build', sites, out, '--serial', '1'])).err, contains('«id»'));
    });

    test('tema cambiato: stessa version con sha diverso = errore; bump --theme alza solo i siti giusti', () async {
      final t = {'format': 1, 'series': themeOf()['series'], 'chapter': themeOf()['chapter']};
      writeTheme('t', t);
      writeSite('gamma', 3, {});
      writeSite('delta', 7, {});
      File(p.join(sites, 'eps.json')).writeAsStringSync(siteJson('eps', 2));
      {final r = await run(['build', sites, out, '--serial', '1']); expect(r.code, 0, reason: r.err);}
      final index1 = p.join(tmp.path, 'prev.json');
      File(p.join(out, 'index.json')).copySync(index1);
      final before = File(p.join(sites, 'gamma.json')).readAsStringSync();

      writeTheme('t', {...t, 'mediaHosts': ['n.example']});
      final out2 = p.join(tmp.path, 'uscita2');
      final bad = await run(['build', sites, out2, '--serial', '2', '--previous', index1]);
      expect(bad.code, 1);
      expect(bad.err, contains('alza «version»'));

      final b = await runSiteTool(['bump', '--theme', 't', '--sites', sites], out: StringBuffer(), err: StringBuffer());
      expect(b, 0);
      expect(File(p.join(sites, 'gamma.json')).readAsStringSync(), before.replaceFirst('"version": 3', '"version": 4'));
      expect(jsonDecode(File(p.join(sites, 'delta.json')).readAsStringSync())['version'], 8);
      expect(File(p.join(sites, 'eps.json')).readAsStringSync(), siteJson('eps', 2));
      final ok = await run(['build', sites, out2, '--serial', '2', '--previous', index1]);
      expect(ok.code, 0, reason: ok.err);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
