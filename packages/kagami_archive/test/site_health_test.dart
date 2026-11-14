import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/providers/mangak.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'archive_fakes.dart';

class NotFoundHttp extends ChallengedHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) =>
      throw const ProviderError('Serie non trovata.');
}

class OnlyKnown extends ChallengedHttp {
  OnlyKnown(this.inner);
  final ProviderHttp inner;

  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) =>
      url.contains('test-series') ? inner.get(url, limit: limit, referer: referer) : throw const ProviderError('Serie non trovata.');

  @override
  Future<Map<String, Object?>> json(String url) => inner.json(url);
}

const asuraUrl = 'https://asurascans.com/comics/war-of-extinction-bd5bdaf8';

void main() {
  late Directory temporary;
  late ArchiveFiles files;
  late FakeMangaK mangak;
  late FakeAsuraScans asura;
  late ProviderHttp Function(Provider) mangakAs;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('kagami-health');
    files = ArchiveFiles(temporary.path);
    mangak = FakeMangaK();
    asura = FakeAsuraScans();
    mangakAs = (provider) => mangak;
  });

  tearDown(() => temporary.delete(recursive: true));

  ArchiveTarget target() => ArchiveTarget(destination: ArchiveDestination.phone, root: p.join(temporary.path, 'library'));

  ProviderHttp httpFor(Provider provider) => provider.id == 'asurascans' ? asura : mangakAs(provider);

  Future<void> track(String provider, String id, String url) async {
    final rows = ((await readJsonFile(files.ongoing))?['series'] as List? ?? const []).cast<Object?>();
    await writeAtomically(
      files.ongoing,
      utf8.encode(jsonEncode({
        'schemaVersion': 1,
        'series': [
          ...rows,
          {
            'provider': provider,
            'id': id,
            'title': id,
            'url': url,
            'target': target().toJson(),
            'chapters': <String>[],
            'addedAt': DateTime.now().toIso8601String(),
          },
        ],
      })),
    );
  }

  Future<CheckReport> check() => Tracking(files.ongoing).check(files, httpFor);

  test('una pagina senza la forma attesa è ProviderChanged, un link sbagliato no', () async {
    await expectLater(
      MangaK().fetchSeries('https://mangak.io/test-series', PageHttp('<html></html>')),
      throwsA(isA<ProviderChanged>()),
    );
    await expectLater(
      MangaK().fetchSeries('https://example.com/x', mangak),
      throwsA(isA<ProviderError>().having((e) => e is ProviderChanged, 'changed', false)),
    );
  });

  test('un ProviderChanged nel controllo dichiara rotto il sito, le altre serie vengono guardate, il primo successo lo risana', () async {
    await track('mangak', 'S1', 'https://mangak.io/test-series');
    await track('asurascans', 'A1', asuraUrl);
    mangakAs = (provider) => PageHttp('<html></html>');
    final report = await check();
    expect(report.checked, 1);
    expect(report.failed, hasLength(1));
    final health = await files.health.load();
    expect(health['mangak']!.broken, isTrue);
    expect(health['mangak']!.message, contains('MangaK'));
    expect(health.containsKey('asurascans'), isFalse);

    mangakAs = (provider) => mangak;
    expect((await check()).checked, 2);
    expect((await files.health.load())['mangak']!.broken, isFalse);
  });

  test('tutte le serie di un sito (almeno due) che falliscono lo dichiarano rotto, una sola no', () async {
    await track('mangak', 'A', 'https://mangak.io/a');
    mangakAs = (provider) => NotFoundHttp();
    await check();
    expect(await files.health.load(), isEmpty);

    await track('mangak', 'B', 'https://mangak.io/b');
    await track('asurascans', 'A1', asuraUrl);
    final report = await check();
    expect(report.checked, 1);
    final health = await files.health.load();
    expect(health['mangak']!.broken, isTrue);
    expect(health['mangak']!.message, 'Serie non trovata.');
    expect(health.containsKey('asurascans'), isFalse);
  });

  test('con una serie che riesce e una che fallisce il sito resta sano', () async {
    await track('mangak', 'S1', 'https://mangak.io/test-series');
    await track('mangak', 'B', 'https://mangak.io/b');
    mangakAs = (provider) => OnlyKnown(mangak);
    await check();
    expect(await files.health.load(), isEmpty);
  });

  test('la coda salta i lavori automatici di un sito rotto, fa quelli degli altri e quelli chiesti a mano risanano', () async {
    await files.health.markBroken('mangak', 'Formato cambiato.');
    ArchiveJob job(String id, String url, {bool automatic = false}) => ArchiveJob(
          id: id,
          url: url,
          title: id,
          target: target(),
          delayMs: 0,
          automatic: automatic,
        );
    ArchiveEnvironment environment() => ArchiveEnvironment(
          scratch: Directory(p.join(temporary.path, 'scratch')),
          storeFor: (target) => LocalStore(target.root!),
          httpFor: (provider, {userAgent, cookies = const {}}) => httpFor(provider),
        );
    await files.enqueue(job('rotto', 'https://mangak.io/test-series', automatic: true));
    await files.enqueue(job('altro', asuraUrl, automatic: true));
    expect(await ArchiveRunner(files, environment()).run(), RunEnd.done);
    expect([for (final j in await files.jobs()) j.id], ['rotto']);
    expect((await files.history()).map((o) => o.ok), [true]);
    expect((await files.health.load())['mangak']!.broken, isTrue);

    await files.enqueue(job('mano', 'https://mangak.io/test-series'));
    await ArchiveRunner(files, environment()).run();
    expect(await files.jobs(), isEmpty);
    expect((await files.health.load())['mangak']!.broken, isFalse);
  });
}
