// La stessa serie sugli altri siti: trovata col titolo alternativo, letta
// senza cercarla la volta dopo, non ricercata dove mancava da poco, siti
// rotti e dietro la verifica mai chiesti, l'errore di un sito che resta suo,
// la passata che parte dalle serie viste meno di recente e salta le escluse.
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/elsewhere.dart';
import 'package:kagami_archive/health.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/stores.dart';
import 'package:test/test.dart';

/// Un sito finto: le serie per link, e cosa dà la ricerca per titolo.
class _Site extends Provider {
  _Site(this.id, {this.series = const {}, this.gate, this.searchError, this.readError});

  @override
  final String id;
  final Map<String, Series> series;
  final BrowserGate? gate;
  final ProviderError? searchError;
  final ProviderError? readError;
  final List<String> asked = [];

  @override
  String get name => id;
  @override
  String get home => 'https://$id.test/';
  @override
  BrowserGate? get browser => gate;
  @override
  bool accepts(String url) => url.startsWith(home);
  @override
  String? seriesOfChapter(String url) => null;
  @override
  bool allowedHost(Uri uri) => uri.host == '$id.test';

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) async {
    asked.add('read $url');
    if (readError case final error?) throw error;
    return series[url] ?? (throw const ProviderError('Serie non trovata.'));
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) => throw UnimplementedError();

  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) async {
    asked.add('search $query');
    if (searchError case final error?) throw error;
    return [
      for (final found in series.values)
        if (titleKey(found.title).contains(titleKey(query)))
          SearchResult(provider: id, title: found.title, url: found.url),
    ];
  }
}

class _NoHttp implements ProviderHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) => throw UnimplementedError();
  @override
  Future<bool> imageExists(String url, {required String referer}) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> json(String url) => throw UnimplementedError();
}

Series _series(String provider, String id, String title, int chapters, {String status = 'ongoing'}) => Series(
      provider: provider,
      id: id,
      title: title,
      url: 'https://$provider.test/$id',
      coverUrl: null,
      metadata: {'releaseStatus': status},
      chapters: [
        for (var number = 1; number <= chapters; number++)
          Chapter('c$number', 'Chapter $number', '$number', 'https://$provider.test/$id/$number',
              {'publishedAt': '2026-10-${number.toString().padLeft(2, '0')}'}),
        Chapter('notice', 'Notice', '', 'https://$provider.test/$id/notice'),
      ],
    );

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);
  late Directory temporary;

  setUp(() async => temporary = await Directory.systemTemp.createTemp('kagami-elsewhere'));
  tearDown(() => temporary.delete(recursive: true));

  Future<Elsewhere> find(List<Provider> sites, {Elsewhere? previous, Map<String, SiteHealth> health = const {}}) =>
      findElsewhere(
        key: 'home:fog-land',
        titles: ['Fog Land', 'Kiri no Kuni'],
        httpFor: (_) => _NoHttp(),
        sites: sites,
        health: health,
        previous: previous,
        delay: Duration.zero,
        clock: () => now,
      );

  test('trovata col titolo alternativo: capitoli, ultimo numero, data, stato', () async {
    final other = _Site('other', series: {'https://other.test/kiri': _series('other', 'kiri', 'Kiri no Kuni', 41)});
    final result = await find([_Site('home'), other]);
    expect(result.sites.keys, ['other'], reason: 'il sito della serie non si cerca');
    final copy = result.sites['other']!;
    expect(copy.state, ElsewhereState.found);
    expect(copy.key, 'other:kiri');
    expect(copy.chapters, 42, reason: 'conta anche l\'avviso');
    expect(copy.latest, '41');
    expect(copy.latestAt, '2026-10-41');
    expect(copy.releaseStatus, 'ongoing');
    expect(other.asked, ['search Fog Land', 'search Kiri no Kuni', 'read https://other.test/kiri']);

    final again = Elsewhere.fromJson(result.key, jsonDecode(jsonEncode(result.toJson())) as Map<String, Object?>);
    other.asked.clear();
    await find([other], previous: again);
    expect(other.asked, ['read https://other.test/kiri'], reason: 'trovata una volta, si rilegge dal link');
  });

  test('dove mancava non si ricerca per una settimana', () async {
    final other = _Site('other');
    final first = await find([other]);
    expect(first.sites['other']!.state, ElsewhereState.missing);
    other.asked.clear();
    await find([other], previous: first);
    expect(other.asked, isEmpty);
    final old = Elsewhere(key: first.key, checkedAt: first.checkedAt, sites: {
      'other': SiteCopy(provider: 'other', state: ElsewhereState.missing, checkedAt: now.subtract(missingAgain)),
    });
    await find([other], previous: old);
    expect(other.asked, ['search Fog Land', 'search Kiri no Kuni']);
  });

  test('sito rotto, verifica del browser, errore e sito cambiato: ognuno resta suo', () async {
    final previous = Elsewhere(key: 'home:fog-land', checkedAt: now, sites: {
      'failing': SiteCopy(
          provider: 'failing', state: ElsewhereState.found, checkedAt: now, url: 'https://failing.test/fog', chapters: 30),
    });
    final broken = _Site('broken');
    final gated = _Site('gated', gate: const BrowserGate(hosts: ['gated.test'], seriesReady: 'true', searchReady: 'true'));
    final failing = _Site('failing', readError: HttpStatusError(500));
    final changed = _Site('changed', searchError: const ProviderChanged('Pagina cambiata.'));
    final fine = _Site('fine', series: {'https://fine.test/fog': _series('fine', 'fog', 'Fog Land', 3)});
    final log = HealthLog(File('${temporary.path}/health.json'));
    final result = await findElsewhere(
      key: 'home:fog-land',
      titles: ['Fog Land'],
      httpFor: (_) => _NoHttp(),
      sites: [broken, gated, failing, changed, fine],
      health: {
        'broken': SiteHealth(broken: true, message: 'Rotto.', since: now, checkedAt: now),
      },
      watch: SiteWatch(log),
      previous: previous,
      delay: Duration.zero,
      clock: () => now,
    );
    expect(broken.asked, isEmpty);
    expect(gated.asked, isEmpty);
    expect(result.sites['broken']!.state, ElsewhereState.broken);
    expect(result.sites['broken']!.message, 'Rotto.');
    expect(result.sites['gated']!.state, ElsewhereState.gated);
    expect(result.sites['failing']!.state, ElsewhereState.error);
    expect(result.sites['failing']!.chapters, 30, reason: 'restano i dati dell\'ultima volta');
    expect(result.sites['changed']!.state, ElsewhereState.broken);
    expect(await log.isBroken('changed'), isTrue);
    expect(result.sites['fine']!.state, ElsewhereState.found);
  });

  test('la rete che manca ferma la ricerca', () async {
    final offline = _Site('other', searchError: const ProviderOffline());
    expect(find([offline]), throwsA(isA<ProviderOffline>()));
  });

  test('la passata: serie da riguardare, la meno recente prima, escluse e limite', () async {
    final store = LocalStore(temporary.path);
    Future<void> write(String path, Object json) async {
      final file = File('${temporary.path}/$path');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(json));
    }
    Map<String, Object?> row(String id, String title, {String status = 'ongoing'}) =>
        {'key': 'home:$id', 'title': title, 'path': id, 'source': 'https://home.test/$id', 'releaseStatus': status};
    await write('library.json', {
      'series': [
        row('a', 'Alpha'),
        row('b', 'Beta'),
        row('c', 'Gamma'),
        row('d', 'Delta', status: 'completed'),
        {'key': 'manual:x', 'title': 'Scheda', 'path': 'x', 'source': null},
      ],
    });
    await write('a/series.json', {
      'title': 'Alpha',
      'metadata': {'alternativeTitles': ['Alfa']},
    });
    final other = _Site('other', series: {'https://other.test/alfa': _series('other', 'alfa', 'Alfa', 2)});
    final log = ElsewhereLog(File('${temporary.path}/elsewhere.json'));
    // b vista ieri mattina, d (conclusa) tre giorni fa: c e a prima, d no.
    await log.put(Elsewhere(key: 'home:b', checkedAt: now.subtract(const Duration(hours: 30)), sites: const {}));
    await log.put(Elsewhere(key: 'home:d', checkedAt: now.subtract(const Duration(days: 3)), sites: const {}));
    final titles = <String>[];
    final done = await sweepElsewhere(
      store: store,
      log: log,
      httpFor: (_) => _NoHttp(),
      sites: [_Site('home'), other],
      skip: {'home:c'},
      limit: 2,
      delay: Duration.zero,
      clock: () => now,
      progress: (_, _, title) => titles.add(title),
    );
    expect(done, 2);
    expect(titles, ['Alpha', 'Beta'], reason: 'mai vista prima, poi la più vecchia; c esclusa, d conclusa');
    final saved = await log.load();
    expect(saved['home:a']!.sites['other']!.key, 'other:alfa');
    expect(saved['home:b']!.checkedAt, now);
    expect(saved.containsKey('manual:x'), isFalse);

    titles.clear();
    await sweepElsewhere(
      store: store,
      log: log,
      httpFor: (_) => _NoHttp(),
      sites: [_Site('home'), other],
      only: {'home:a'},
      delay: Duration.zero,
      clock: () => now,
      progress: (_, _, title) => titles.add(title),
    );
    expect(titles, ['Alpha'], reason: 'chiesta per nome si riguarda subito');
  });
}
