/// R9.8: il ripiego rifiutato (id della serie sconosciuto) non tocca i dati
/// personali, e «Cambia provider» (`moveSeries`) li porta tutti sulla serie nuova.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/user_repository.dart';
import 'package:kagami/src/format/reading.dart';
import 'package:kagami_archive/catalog.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/fallback.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';

const _url = 'https://examplescans.com/manga/solo';
const _old = 'mangak:S1';
const _fresh = 'coffeemanga:7743';

void main() {
  late KagamiDatabase db;
  late UserRepository repository;

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    repository = UserRepository(db);
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    await repository.saveSeriesState(
      _old,
      SeriesState(
        status: ShelfStatus.reading,
        rating: 8,
        favorite: true,
        notes: 'nota',
        reachedChapter: '52',
        updatedAt: DateTime.utc(2026, 6, 1),
      ),
    );
    await repository.markChapters(_old, ['a1', 'a2'], true);
    await repository.saveProgress(
      _old,
      ReadingProgress(chapterId: 'a2', page: 4, pageCount: 20, updatedAt: DateTime.utc(2026, 6, 1)),
    );
    await repository.addBookmark(seriesKey: _old, chapterId: 'a1', page: 3);
    await repository.replaceCollections([
      Collection(id: 'c', name: 'C', seriesKeys: const ['x', _old]),
    ]);
  }

  test('un ripiego rifiutato lancia l\'errore del catalogo e il DB personale resta com\'era', () async {
    await seed();
    final before = await repository.loadStates();
    final included = _Included('solo');
    await expectLater(
      FallbackProvider(_catalogWithSeriesId(), included).fetchSeries(_url, _Http(_idWithoutTitle)),
      throwsA(isA<ProviderChanged>()),
    );
    expect(included.calls, 1);
    final after = await repository.loadStates();
    expect(after.keys, before.keys);
    expect(after[_old]!.rating, 8);
    expect(after[_old]!.readChapters, {'a1', 'a2'});
    expect((await repository.loadCollections()).single.seriesKeys, ['x', _old]);
  });

  test('«Cambia provider» porta voto, stato, raccolte, letti, posizione e segnalibri', () async {
    await seed();
    await repository.moveSeries(_old, _fresh, chapters: {'a1': '1', 'a2': '2'});

    final states = await repository.loadStates();
    expect(states.containsKey(_old), isFalse);
    final state = states[_fresh]!;
    expect(state.status, ShelfStatus.reading);
    expect(state.rating, 8);
    expect(state.favorite, isTrue);
    expect(state.notes, 'nota');
    expect(state.reachedChapter, '52');
    expect(state.readChapters, {'1', '2'});
    expect(state.progress?.chapterId, '2');
    expect(state.progress?.page, 4);
    expect((await repository.bookmarks(_fresh)).single.chapterId, '1');
    expect((await repository.loadCollections()).single.seriesKeys, ['x', _fresh]);
  });
}

const _idWithoutTitle =
    '<html><head><meta name="series" content="4242"></head><body><p>nuova</p></body></html>';

DeclarativeProvider _catalogWithSeriesId() => DeclarativeProvider.fromJson({
      'format': 1,
      'id': 'mangak',
      'name': 'MangaK',
      'version': 1,
      'home': 'https://examplescans.com',
      'hosts': ['examplescans.com'],
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'id': {'css': 'meta[name=series]', 'attr': 'content'},
        'title': 'h1',
        'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'img', 'url': {'attr': 'src'}},
      },
    }, catalog: CatalogSite(id: 'mangak', state: CatalogSiteState.ok, variants: const [], builtin: true));

class _Included extends Provider {
  _Included(this.seriesId);

  final String seriesId;
  int calls = 0;

  @override
  String get id => 'mangak';
  @override
  String get name => 'MangaK incluso';
  @override
  String get home => 'https://examplescans.com';
  @override
  bool accepts(String url) => true;
  @override
  String? seriesOfChapter(String url) => null;
  @override
  bool allowedHost(Uri uri) => true;

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) async {
    calls++;
    return Series(
      provider: 'mangak',
      id: seriesId,
      title: 'Solo incluso',
      url: url,
      coverUrl: null,
      metadata: const {},
      chapters: [Chapter('1', 'Chapter 1', '1', '$url/chapter-1')],
    );
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) async =>
      const ChapterContent([Page('https://img.example.net/1.webp')], {});

  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) async => const [];
}

class _Http implements ProviderHttp {
  _Http(this.page);

  final String page;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) async =>
      (body: Uint8List.fromList(utf8.encode(page)), contentType: 'text/html');

  @override
  Future<bool> imageExists(String url, {required String referer}) async => true;

  @override
  Future<Map<String, Object?>> json(String url) async => decodeJsonObject((await get(url)).body);
}
