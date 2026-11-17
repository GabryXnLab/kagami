/// Ingressi non fidati e segreti nell'app (FASE-8, F8.4). Gli indici di una
/// libreria altrui li scrive chi la condivide: niente di ciò che dicono deve
/// portare letture o scritture fuori dalla cartella.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/backup.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_sources.dart';
import 'package:kagami_archive/remote.dart' show ServerLink;
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/download_origin.dart';
import 'package:kagami/src/data/downloads.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/page_decoder.dart';
import 'package:kagami/src/data/sources/path_shelf.dart';
import 'package:kagami_archive/transport.dart' show StorageTransport;
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/sentry_scrub.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/format/malf.dart';
import 'package:kagami/src/l10n.dart';
import 'package:kagami/src/ui/social_widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class _BigTransport implements StorageTransport {
  _BigTransport(this.size);

  final int size;

  @override
  Future<void> download(String path, File target, {int resumeFrom = 0}) =>
      target.writeAsBytes(List.filled(size, 1));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Un PNG a un bit per pixel tutto nero: poche decine di KB per milioni di pixel.
List<int> _pngOf(int width, int height) {
  final crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = c & 1 == 1 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });
  int crc(List<int> data) {
    var c = 0xffffffff;
    for (final b in data) {
      c = crcTable[(c ^ b) & 0xff] ^ (c >> 8);
    }
    return c ^ 0xffffffff;
  }

  List<int> be(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [...be(data.length), ...body, ...be(crc(body))];
  }

  final row = List.filled(1 + (width + 7) ~/ 8, 0);
  final raw = <int>[for (var y = 0; y < height; y++) ...row];
  return [
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ...chunk('IHDR', [...be(width), ...be(height), 1, 0, 0, 0, 0]),
    ...chunk('IDAT', ZLibCodec().encode(raw)),
    ...chunk('IEND', const []),
  ];
}

const _evil = ['../evil', 'a/../../evil', '/tmp/evil', r'..\evil', 'C:/evil', 'a\u0000b'];

class _Origin implements DownloadOrigin {
  final fetched = <String>[];

  @override
  LibraryShelf get shelf => throw UnimplementedError();

  @override
  String? get destination => null;

  @override
  Future<bool> online() async => true;

  @override
  Future<String?> seriesText(SeriesEntry entry, String name) async => '{}';

  @override
  Future<void> fetch(SeriesEntry entry, String relative, File temporary) async {
    fetched.add(relative);
    await temporary.writeAsString('x');
  }
}

SeriesEntry _series(String path, {String? cover}) => SeriesEntry(
      key: 'site:x',
      path: path,
      title: 'X',
      provider: 'site',
      releaseStatus: ReleaseStatus.parse(null),
      chapterCount: 1,
      archivedChapterCount: 1,
      pageCount: 1,
      bytes: 1,
      signature: '',
      cover: cover,
    );

void main() {
  group('indici con percorsi fuori dalla cartella (T8)', () {
    test('library.json: la riga malevola si scarta, le altre restano', () {
      final index = LibraryIndex.fromJson({
        'series': [
          {'key': 'a:1', 'path': 'Buona [a-1]', 'cover': 'cover.webp'},
          for (final path in _evil) {'key': 'a:$path', 'path': path},
          {'key': 'a:2', 'path': 'Copertina [a-2]', 'cover': '../../cover.webp',
           'coverThumbnail': '/etc/passwd'},
        ],
      });
      expect(index.series.map((s) => s.key), ['a:1', 'a:2']);
      final second = index.series.last;
      expect(second.cover, isNull);
      expect(second.coverThumbnail, isNull);
    });

    test('library.json: una riga con un campo del tipo sbagliato non svuota la libreria', () {
      final index = LibraryIndex.fromJson({
        'series': [
          {'key': 'a:1', 'path': 'Buona [a-1]'},
          {'key': 'a:2', 'path': 'Rotta', 'title': 42, 'authors': 'nessuno'},
          {'key': 'a:3', 'path': 7},
        ],
      });
      expect(index.series.map((s) => s.key), ['a:1']);
    });

    test('index.json: capitoli con percorsi malevoli o rotti si scartano', () {
      final index = SeriesIndex.fromJson({
        'key': 'a:1',
        'chapters': [
          {'id': 'ok', 'path': 'chapters/0001 - Uno [ok]', 'complete': true, 'pageCount': 1},
          for (final path in _evil) {'id': path, 'path': path, 'complete': true, 'pageCount': 1},
          {'id': 'rotto', 'title': ['x']},
        ],
      });
      expect(index.chapters.map((c) => c.id), ['ok']);
    });

    test('pages.json: tavole e tessere con nomi malevoli si scartano', () {
      final index = PagesIndex.fromJson({
        'pages': {
          'c': [
            {'file': '0001.webp'},
            for (final path in _evil) {'file': path},
            {'file': '0002.webp', 'width': 'largo'},
            {'file': '0003.webp', 'width': 10, 'height': 20,
             'tiles': [{'file': '../t.webp', 'height': 20}]},
          ],
        },
      });
      expect(index.of('c').map((page) => page.file), ['0001.webp', '0002.webp', '0003.webp']);
      expect(index.of('c').last.tiles, isEmpty);
    });
  });

  group('download: nessun file fuori dalla destinazione (T8)', () {
    late Directory temp;
    late String destination;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('kagami-security');
      destination = p.join(temp.path, 'dest');
      await Directory(destination).create();
    });

    tearDown(() => temp.delete(recursive: true));

    Future<List<String>> outside() async => [
          await for (final entity in temp.list(recursive: true))
            if (!p.isWithin(destination, entity.path) && entity.path != destination) entity.path,
        ];

    test('serie, capitolo e tavola costruiti a mano con ../ si rifiutano', () async {
      for (final (series, chapter, page) in [
        ('../fuori', 'chapters/c', '0001.webp'),
        ('S', '../../fuori', '0001.webp'),
        ('S', 'chapters/c', '../../../fuori.webp'),
      ]) {
        final origin = _Origin();
        await expectLater(
          ChapterDownloader(origin).download(
            destination: destination,
            entry: _series(series),
            chapter: ChapterEntry(
              id: 'c', order: 0, archived: true, complete: true, pageCount: 1, bytes: 1,
              path: chapter,
            ),
            pages: [PageEntry(file: page)],
            onPage: (_, _) {},
            cancelled: () => false,
          ),
          throwsA(anything),
          reason: '$series | $chapter | $page',
        );
        expect(origin.fetched, isEmpty);
      }
      expect(await outside(), isEmpty);
    });

    test('finishSeries con percorso o copertina malevoli non scrive fuori', () async {
      for (final entry in [_series('../fuori'), _series('S', cover: '../../fuori.webp')]) {
        final origin = _Origin();
        await expectLater(
          ChapterDownloader(origin).finishSeries(destination: destination, entry: entry),
          throwsA(anything),
        );
        expect(origin.fetched, isEmpty);
      }
      expect(await outside(), isEmpty);
    });
  });

  test('il tetto di readers (23514, migrazione 0008) è un messaggio, non un guasto generico', () {
    final message = cloudMessage(const PostgrestException(
      message: 'new row for relation "readers" violates check constraint "readers_data_size"',
      code: '23514',
    ));
    expect(message, currentL10n().dataCloudTooLarge);
    expect(message, isNot(currentL10n().dataSyncFailed));
  });

  group('foto dei profili (T5, migrazione 0009)', () {
    const google = 'https://lh3.googleusercontent.com/a/ACg8ocK=s96-c';

    test('solo foto di Google, sotto i 512 caratteri', () {
      expect(isProfilePhoto(google), isTrue);
      expect(isProfilePhoto('https://lh6.googleusercontent.com/x'), isTrue);
      for (final photo in [
        null,
        '',
        'http://lh3.googleusercontent.com/a/x',
        'https://lh3.googleusercontent.com.evil.example/a',
        'https://evil.example/https://lh3.googleusercontent.com/a',
        'https://lh7.googleusercontent.com/a',
        'https://lh3.googleusercontent.com/a b',
        'https://lh3.googleusercontent.com/',
        'https://lh3.googleusercontent.com/${'p' * 480}',
      ]) {
        expect(isProfilePhoto(photo), isFalse, reason: photo);
      }
    });

    testWidgets('un indirizzo fuori regola non si carica: si vede l\'iniziale', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SocialAvatar(name: 'mallory', photo: 'https://tracker.example/pixel.png'),
      ));
      expect(find.byType(Image), findsNothing);
      expect(find.text('M'), findsOneWidget);
    });
  });

  test('il backup non porta password, token né refresh token (T18)', () async {
    const password = 'pw-segretissima-123';
    final db = KagamiDatabase.forTesting(NativeDatabase.memory());
    final secrets = MemorySourceSecrets();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sourceSecretsProvider.overrideWithValue(secrets),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    // Come fa il foglio della sorgente: il segreto a parte, la configurazione
    // nelle impostazioni.
    await secrets.write('w-1', password);
    await container.read(librarySourcesProvider.notifier).add(const SourceConfig(
          id: 'w-1',
          kind: SourceKind.webdav,
          label: 'NAS',
          params: {'url': 'https://nas.example/dav', 'user': 'gabry', 'root': 'manga'},
        ));
    await container.read(serverLinkProvider.notifier).choose(
          ServerLink(Uri.parse('https://kagami.example'), id: 'srv-1', owner: 'me@example.com'),
        );

    final text = utf8.decode(gzip.decode(await BackupService(db).export()));
    expect(text, contains('nas.example'));
    expect(text, contains('kagami.example'));
    expect(text, isNot(contains(password)));
    final settings = (jsonDecode(text) as Map<String, Object?>)['settings']! as Map<String, Object?>;
    for (final MapEntry(:key, :value) in settings.entries) {
      expect(key, isNot(matches(RegExp('password|token|secret', caseSensitive: false))), reason: key);
      expect('$value', isNot(matches(RegExp(r'refreshToken|eyJ[\w-]+\.|ya29\.|1//0', caseSensitive: false))),
          reason: key);
    }
  });

  group('Sentry senza dati personali (T19)', () {
    const driveId = '1AbCdEfGhIjKlMnOpQrStUvWxYz012345';
    const secrets = [
      'nas.casa.example', 'kagami.example', 'gabry@example.com', '192.168.1.20',
      'fe80::1:2:3', driveId, 'user:pw',
    ];

    test('messaggi tipici di rete, Drive e server', () {
      final text = scrubText(
        "SocketException: Failed host lookup: 'nas.casa.example' (OS Error: x), "
        'address = 192.168.1.20, port = 443; '
        'HttpException: 401, uri = https://user:pw@kagami.example/v2/queue?x=1 '
        'per gabry@example.com, cartella $driveId, fe80::1:2:3',
      );
      for (final secret in secrets) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
      // Quello che serve a correggere resta.
      expect(text, contains('SocketException'));
      expect(text, contains('401'));
      expect(scrubText('Bad state: 3 tavole su 12, 00:01:30'), 'Bad state: 3 tavole su 12, 00:01:30');
    });

    test('il beforeSend pulisce messaggio, eccezioni, breadcrumb, richiesta e utente', () {
      final event = SentryEvent(
        message: SentryMessage('apro https://kagami.example', template: 'apro %s', params: ['gabry@example.com']),
        exceptions: [SentryException(type: 'DriveException', value: 'cartella $driveId')],
        breadcrumbs: [
          Breadcrumb(message: 'GET https://nas.casa.example/dav', data: {'url': 'https://nas.casa.example/dav', 'n': 1}),
        ],
        request: SentryRequest(url: 'https://kagami.example/v2', queryString: 'token=x', headers: {'Authorization': 'Bearer y'}),
        user: SentryUser(id: 'u1', email: 'gabry@example.com', ipAddress: '192.168.1.20'),
      );
      final text = jsonEncode(scrubEvent(event).toJson());
      for (final secret in [...secrets, 'Bearer y', 'token=x']) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
      expect(text, contains('DriveException'));
    });
  });

  group('tavole enormi (T9)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kagami-t9'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('la cache butta un file oltre il tetto e non lo tiene', () async {
      final cache = DriveFileCache(dir, limitBytes: 1 << 30, maxEntryBytes: 10);
      await expectLater(
        cache.store('grande', (target) => target.writeAsBytes(List.filled(11, 1))),
        throwsA(isA<OversizedFile>()),
      );
      expect(cache.peek('grande'), isNull);
      expect(dir.listSync(), isEmpty, reason: 'nemmeno il .part resta');
      final ok = await cache.store('ok', (target) => target.writeAsBytes(List.filled(10, 1)));
      expect(File(ok).existsSync(), isTrue);
    });

    test('PathFiles: la tavola oltre il tetto è un errore, non una tavola', () async {
      final transport = _BigTransport(100);
      final shelf = PathShelf(
        transport: transport,
        sourceId: 's',
        stateDirectory: p.join(dir.path, 'state'),
        root: '',
      );
      final files = PathFiles(shelf, DriveFileCache(Directory(p.join(dir.path, 'c')), limitBytes: 1 << 30, maxEntryBytes: 50));
      await expectLater(files.fetch(sourceAddress('s', 'a/1.png')), throwsA(isA<OversizedFile>()));
      expect(files.peek(sourceAddress('s', 'a/1.png')), isNull);
    });

    test('il decodificatore rifiuta un file oltre il tetto di byte', () async {
      final file = File(p.join(dir.path, 'enorme.jpg'));
      final handle = file.openSync(mode: FileMode.write)..truncateSync(maxPageBytes + 1);
      handle.closeSync();
      await expectLater(
        PageDecoder(native: false).decode(file.path, targetWidth: 800),
        throwsA(isA<OversizedFile>()),
      );
    });

    testWidgets('il decodificatore rifiuta una tavola oltre il tetto di pixel', (tester) async {
      final file = File(p.join(dir.path, 'larga.png'))..writeAsBytesSync(_pngOf(8001, 8001));
      await tester.runAsync(() async {
        await expectLater(
          PageDecoder(native: false).decode(file.path, targetWidth: 800),
          throwsA(isA<OversizedFile>()),
        );
      });
    });
  });
}
