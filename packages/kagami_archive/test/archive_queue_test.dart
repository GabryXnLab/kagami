// La coda dei download e il controllo delle serie in corso, senza Android:
// siti finti, una cartella vera, la stessa logica del lavoro in primo piano.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/providers/mangak.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';
import 'package:kagami_archive/tracking.dart';
import 'package:path/path.dart' as p;

import 'archive_fakes.dart';

class OfflineHttp extends ChallengedHttp {
  @override
  Future<HttpResult> get(String url, {int limit = 2000000, String? referer}) =>
      throw const ProviderOffline();
}

void main() {
  late Directory temporary;
  late ArchiveFiles files;
  late FakeMangaK http;
  ProviderHttp? override;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('kagami-queue');
    files = ArchiveFiles(temporary.path);
    http = FakeMangaK();
    override = null;
  });

  tearDown(() => temporary.delete(recursive: true));

  String root() => p.join(temporary.path, 'library');

  ArchiveEnvironment environment() => ArchiveEnvironment(
        scratch: Directory(p.join(temporary.path, 'scratch')),
        storeFor: (target) => LocalStore(target.root!),
        httpFor: (provider, {userAgent, cookies = const {}}) => override ?? http,
      );

  ArchiveJob job({String? start, Set<String>? ids, String id = 'j1'}) => ArchiveJob(
        id: id,
        url: 'https://mangak.io/test-series',
        title: 'Test',
        target: ArchiveTarget(destination: ArchiveDestination.phone, root: root()),
        start: start,
        ids: ids,
        delayMs: 0,
      );

  Future<List<TrackedSeries>> tracked() => Tracking(files.ongoing).load();

  test('la coda scarica, annota com\'è andata e si svuota', () async {
    await files.enqueue(job());
    final end = await ArchiveRunner(files, environment()).run();
    expect(end, RunEnd.done);
    expect(await files.jobs(), isEmpty);
    final outcome = (await files.history()).single;
    expect((outcome.ok, outcome.seriesKey, outcome.message), (true, 'mangak:S1', 'Serie archiviata completamente.'));
    final status = await files.status();
    expect((status.state, status.done, status.total, status.pagesDownloaded), (ArchiveState.idle, 2, 2, 3));
    // La serie è in corso: il controllo la seguirà.
    expect((await tracked()).single.chapters, ['C1', 'C2']);
  });

  test('la stessa serie due volte in coda vale una, l\'ultima', () async {
    await files.enqueue(job(start: '2'));
    await files.enqueue(job(id: 'j2'));
    expect((await files.jobs()).map((job) => (job.id, job.start)), [('j2', null)]);
  });

  test('senza rete il lavoro resta in coda e il giro si riprende', () async {
    await files.enqueue(job());
    override = OfflineHttp();
    expect(await ArchiveRunner(files, environment()).run(), RunEnd.retry);
    expect((await files.jobs()).single.id, 'j1');
    expect((await files.status()).state, ArchiveState.waiting);
    override = null;
    expect(await ArchiveRunner(files, environment()).run(), RunEnd.done);
    expect(await files.jobs(), isEmpty);
  });

  test('un link che non è di nessun sito finisce fra gli errori, e la coda va avanti', () async {
    await files.enqueue(ArchiveJob(
      id: 'bad',
      url: 'https://example.org/manga',
      title: 'Boh',
      target: ArchiveTarget(destination: ArchiveDestination.phone, root: root()),
    ));
    await files.enqueue(job());
    expect(await ArchiveRunner(files, environment()).run(), RunEnd.done);
    final history = await files.history();
    expect(history.map((o) => o.ok), [true, false]);
    expect(history.last.message, contains('Link non supportato'));
  });

  group('la libreria intera', () {
    // Una libreria come la lascia un altro archiviatore: la serie c'è, con il
    // suo indice, ma nessuno la segue.
    Future<String> archived({String? start}) async {
      await files.enqueue(job(start: start));
      await ArchiveRunner(files, environment()).run();
      await Tracking(files.ongoing).forget('mangak:S1');
      final rows = jsonDecode(File(p.join(root(), 'reading', 'downloads.json')).readAsStringSync())['series'];
      File(p.join(root(), 'library.json')).writeAsStringSync(jsonEncode({'series': rows}));
      return (rows as List).single['path'] as String;
    }

    Future<CheckReport> check({Set<String> skip = const {}}) => checkLibrary(
          files: files,
          store: LocalStore(root()),
          target: ArchiveTarget(destination: ArchiveDestination.phone, root: root()),
          httpFor: (provider) => http,
          skip: skip,
          pause: Duration.zero,
        );

    test('i capitoli usciti dopo vanno in coda, non quelli lasciati per scelta', () async {
      await archived(start: '2');
      http.addChapter(3, 'Chapter 3', 'C3', ['https://rx.qvzre.org/d.webp']);
      final report = await check();
      expect(report.checked, 1);
      expect(report.queued, ['Test / Series']);
      expect((await files.jobs()).single.ids, {'C3'});
    });

    test('niente di nuovo, niente in coda; una serie seguita si lascia a Tracking', () async {
      await archived();
      expect((await check()).queued, isEmpty);
      http.addChapter(3, 'Chapter 3', 'C3', ['https://rx.qvzre.org/d.webp']);
      expect((await check(skip: {'mangak:S1'})).checked, 0);
      expect(await files.jobs(), isEmpty);
    });

    test('un capitolo che l\'indice dà a metà si rimette in coda, e il giro ripara l\'indice', () async {
      final folder = await archived();
      http.series['status'] = 'Completed';
      final file = File(p.join(root(), folder, 'index.json'));
      final index = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      ((index['chapters'] as List).first as Map)['complete'] = false;
      index['releaseStatus'] = 'completed';
      file.writeAsStringSync(jsonEncode(index));
      final report = await check();
      expect(report.checked, 0);
      expect(report.repaired, ['Test / Series']);
      expect((await files.jobs()).single.ids, {'C1'});
      final requests = http.imageRequests.length;
      await ArchiveRunner(files, environment()).run();
      expect(http.imageRequests.skip(requests).where((url) => !url.contains('covers')), isEmpty);
      final fixed = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      expect(((fixed['chapters'] as List).first as Map)['complete'], isTrue);
    });
  });

  group('serie in corso', () {
    Future<CheckReport> check() => Tracking(files.ongoing)
        .check(files, (provider) => override ?? http);

    test('i capitoli nuovi vanno in coda, solo quelli', () async {
      await files.enqueue(job());
      await ArchiveRunner(files, environment()).run();
      http.addChapter(3, 'Chapter 3', 'C3', ['https://rx.qvzre.org/d.webp']);
      final report = await check();
      expect(report.checked, 1);
      expect(report.queued, ['Test / Series']);
      final queued = (await files.jobs()).single;
      expect(queued.ids, {'C3'});
      expect(queued.automatic, isTrue);
      final requests = http.imageRequests.length;
      await ArchiveRunner(files, environment()).run();
      // Senza il Kotlin la miniatura non c'è e la copertina si ritenta:
      // delle tavole, scende solo quella nuova.
      expect(http.imageRequests.skip(requests).where((url) => !url.contains('covers')), ['https://rx.qvzre.org/d.webp']);
      expect((await tracked()).single.chapters, ['C1', 'C2', 'C3']);
    });

    test('una serie su Drive la lascia al server, se lui guarda tutta quella cartella', () async {
      final series = await MangaK().fetchSeries('https://mangak.io/test-series', http);
      const drive = ArchiveTarget(destination: ArchiveDestination.drive, folderId: 'cartella');
      await Tracking(files.ongoing).record(series, drive, settled: const ['C1'], metadata: const {'releaseStatus': 'ongoing'});
      await files.delegate('cartella');
      expect((await check()).checked, 0);
      await files.delegate(null);
      expect((await check()).queued, ['Test / Series']);
    });

    test('senza capitoli nuovi non mette in coda niente', () async {
      await files.enqueue(job());
      await ArchiveRunner(files, environment()).run();
      final report = await check();
      expect(report.checked, 1);
      expect(report.queued, isEmpty);
      expect(await files.jobs(), isEmpty);
    });

    test('una serie conclusa esce da sola', () async {
      await files.enqueue(job());
      await ArchiveRunner(files, environment()).run();
      http.series['status'] = 'Completed';
      final report = await check();
      expect(report.removed, ['Test / Series']);
      expect(await tracked(), isEmpty);
    });

    test('l\'ultimo capitolo, uscito con la serie conclusa, va in coda lo stesso', () async {
      await files.enqueue(job());
      await ArchiveRunner(files, environment()).run();
      http.series['status'] = 'Completed';
      http.addChapter(3, 'Chapter 3', 'C3', ['https://rx.qvzre.org/d.webp']);
      final report = await check();
      expect(report.queued, ['Test / Series']);
      expect(report.removed, ['Test / Series']);
      expect((await files.jobs()).single.ids, {'C3'});
    });

    test('una serie in pausa o con uno stato che non si capisce resta seguita', () async {
      for (final status in ['Hiatus', 'Boh']) {
        http.series['status'] = status;
        await files.enqueue(job());
        await ArchiveRunner(files, environment()).run();
        expect((await tracked()).single.chapters, ['C1', 'C2'], reason: status);
        await check();
        expect(await tracked(), hasLength(1), reason: status);
      }
    });

    test('un capitolo nuovo non prende il posto della serie chiesta dall\'utente', () async {
      await files.enqueue(job());
      await ArchiveRunner(files, environment()).run();
      await files.enqueue(job(id: 'utente', ids: {'C1'}));
      http.addChapter(3, 'Chapter 3', 'C3', ['https://rx.qvzre.org/d.webp']);
      await check();
      final queued = (await files.jobs()).single;
      expect((queued.id, queued.automatic), ('utente', false));
      expect(queued.ids, {'C1', 'C3'});
      await files.enqueue(job(id: 'tutta'));
      await check();
      expect((await files.jobs()).single.ids, isNull);
    });

    group('man mano', () {
      ArchiveJob ahead(Set<String> ids) => ArchiveJob(
            id: 'm',
            url: 'https://mangak.io/test-series',
            title: 'Test',
            target: ArchiveTarget(destination: ArchiveDestination.phone, root: root()),
            ids: ids,
            delayMs: 0,
            ahead: 5,
          );

      test('i capitoli nuovi scendono solo quando l\'app li chiede', () async {
        await files.enqueue(ahead({'C1'}));
        await ArchiveRunner(files, environment()).run();
        expect((await tracked()).single.ahead, 5);
        http.addChapter(3, 'Chapter 3', 'C3', ['https://rx.qvzre.org/d.webp']);
        http.addChapter(4, 'Chapter 4', 'C4', ['https://rx.qvzre.org/e.webp']);
        expect((await check()).queued, isEmpty);
        await Tracking(files.ongoing).want('mangak:S1', 1);
        expect((await check()).queued, ['Test / Series']);
        final queued = (await files.jobs()).single;
        expect(queued.ids, {'C3'});
        expect(queued.ahead, 5);
        expect((await tracked()).single.wanted, 0);
      });

      test('resta seguita anche conclusa', () async {
        http.series['status'] = 'Completed';
        await files.enqueue(ahead({'C1'}));
        await ArchiveRunner(files, environment()).run();
        await check();
        expect((await tracked()).single.ahead, 5);
      });
    });

    test('partendo da un capitolo, i precedenti non si riscaricano da soli', () async {
      await files.enqueue(job(start: '2'));
      await ArchiveRunner(files, environment()).run();
      expect((await tracked()).single.chapters.toSet(), {'C1', 'C2'});
      expect((await check()).queued, isEmpty);
    });

    test('un capitolo fallito si ritenta al controllo seguente', () async {
      http.broken.add(http.urls[2]!.single);
      await files.enqueue(job());
      await ArchiveRunner(files, environment()).run();
      expect((await files.history()).single.ok, isFalse);
      expect((await tracked()).single.chapters, ['C1']);
      http.broken.clear();
      await check();
      expect((await files.jobs()).single.ids, {'C2'});
    });

    test('una serie che il sito non dà più resta, con il perché', () async {
      await files.enqueue(job());
      await ArchiveRunner(files, environment()).run();
      override = ChallengedHttp();
      final report = await check();
      expect(report.failed.single.error, contains('verifica'));
      expect((await tracked()).single.problem, contains('verifica'));
    });

    test('il file sopravvive a formati vecchi o rovinati', () async {
      await files.ongoing.parent.create(recursive: true);
      await files.ongoing.writeAsString(jsonEncode({'series': [{'url': 1}, 'x']}));
      expect(await tracked(), isEmpty);
      expect(selectProvider('https://mangak.io/test-series').id, 'mangak');
    });
  });
}
