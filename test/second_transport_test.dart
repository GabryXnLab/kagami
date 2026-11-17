/// Il trasporto SMB (`SmbTransport`) sopra una sessione finta: nessuna
/// connessione di rete, la CI non ha un Samba.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/sources/smb_transport.dart';
import 'package:kagami_archive/transport.dart';

class FakeSession implements SmbSession {
  final Map<String, Uint8List> files = {};
  final Set<String> folders = {''};
  final DateTime modified = DateTime.utc(2026, 11, 1, 12);
  Smb2Exception? failure;

  /// Le operazioni non finiscono mai: solo il token le sblocca.
  bool hang = false;
  bool closed = false;
  int connects = 0;
  final List<(int, int)> reads = [];

  void put(String path, List<int> bytes) {
    files[path] = Uint8List.fromList(bytes);
    final parts = path.split('/');
    for (var i = 1; i < parts.length; i++) {
      folders.add(parts.take(i).join('/'));
    }
  }

  Future<void> _gate(Smb2CancelToken cancel, String path) async {
    if (failure != null) throw failure!;
    if (hang) {
      await cancel.whenCancelled;
      throw Smb2Exception('Cancelled', type: Smb2ErrorType.cancelled, path: path);
    }
  }

  SmbItem _item(String path) {
    final name = path.isEmpty ? '' : path.split('/').last;
    if (folders.contains(path)) return SmbItem(name: name, folder: true, modified: modified);
    final file = files[path];
    if (file == null) {
      throw Smb2Exception('no such file', type: Smb2ErrorType.notFound, path: path);
    }
    return SmbItem(name: name, folder: false, size: file.length, modified: modified);
  }

  @override
  Future<List<SmbItem>> list(String path, Smb2CancelToken cancel) async {
    await _gate(cancel, path);
    _item(path);
    final prefix = path.isEmpty ? '' : '$path/';
    final names = {
      for (final other in [...files.keys, ...folders])
        if (other.length > prefix.length && other.startsWith(prefix))
          other.substring(prefix.length).split('/').first,
    };
    return [for (final name in names) _item('$prefix$name')];
  }

  @override
  Future<SmbItem> stat(String path, Smb2CancelToken cancel) async {
    await _gate(cancel, path);
    return _item(path);
  }

  @override
  Future<Uint8List> read(String path, int offset, int length, Smb2CancelToken cancel) async {
    await _gate(cancel, path);
    reads.add((offset, length));
    final bytes = files[path]!;
    return bytes.sublist(offset, (offset + length).clamp(0, bytes.length));
  }

  @override
  Future<void> close() async => closed = true;
}

/// Una sessione che dopo [after] letture riuscite perde la connessione.
class _CutAfter implements SmbSession {
  _CutAfter(this._inner, this.after);
  final FakeSession _inner;
  int after;

  @override
  Future<List<SmbItem>> list(String path, Smb2CancelToken cancel) => _inner.list(path, cancel);

  @override
  Future<SmbItem> stat(String path, Smb2CancelToken cancel) => _inner.stat(path, cancel);

  @override
  Future<Uint8List> read(String path, int offset, int length, Smb2CancelToken cancel) {
    if (after-- <= 0) throw const Smb2Exception('x', type: Smb2ErrorType.connection);
    return _inner.read(path, offset, length, cancel);
  }

  @override
  Future<void> close() async {}
}

void main() {
  late FakeSession session;
  late SmbTransport transport;
  late Directory temp;

  SmbTransport make({Duration limit = const Duration(seconds: 5), int maxText = 1 << 20}) =>
      SmbTransport(() async {
        session.connects++;
        return session;
      }, limit: limit, maxText: maxText);

  setUp(() {
    session = FakeSession()
      ..put('manga/library.json', utf8.encode('{"series":[]}'))
      ..put('manga/日本語 #1/index.json', utf8.encode('{}'));
    transport = make();
    temp = Directory.systemTemp.createTempSync('kagami-smb');
  });
  tearDown(() {
    transport.close();
    temp.deleteSync(recursive: true);
  });

  test('elenco: nome, dimensione, data, cartelle, percorsi da ripassare', () async {
    final entries = {for (final e in await transport.list('manga')) e.name: e};
    expect(entries.keys, unorderedEquals(['library.json', '日本語 #1']));
    expect(entries['library.json']!.path, 'manga/library.json');
    expect(entries['library.json']!.folder, isFalse);
    expect(entries['library.json']!.size, 13);
    expect(entries['library.json']!.modified, session.modified);
    expect(entries['日本語 #1']!.folder, isTrue);
    expect(entries['日本語 #1']!.size, isNull);
    expect((await transport.stat(entries['日本語 #1']!.path))!.folder, isTrue);
  });

  test('stat: assente è null, presente ha dimensione', () async {
    expect(await transport.stat('manga/non-c-e.json'), isNull);
    expect((await transport.stat('manga/library.json'))!.size, 13);
    expect(await transport.text('manga/library.json'), '{"series":[]}');
  });

  test('la connessione si apre una volta sola; dopo close non si riapre', () async {
    await transport.stat('manga');
    await transport.stat('manga/library.json');
    expect(session.connects, 1);
    transport.close();
    await Future<void>.delayed(Duration.zero);
    expect(session.closed, isTrue);
    await expectLater(transport.stat('manga'), throwsA(isA<TransportOffline>()));
    expect(session.connects, 1);
  });

  group('errori', () {
    Future<void> expectMapping(Smb2ErrorType type, Matcher matcher) async {
      session.failure = Smb2Exception('x', type: type);
      await expectLater(transport.list('manga'), throwsA(matcher));
      await expectLater(transport.stat('manga'), throwsA(matcher));
    }

    test('auth e accessDenied → TransportAuthRequired', () async {
      await expectMapping(Smb2ErrorType.auth, isA<TransportAuthRequired>());
      await expectMapping(Smb2ErrorType.accessDenied, isA<TransportAuthRequired>());
    });

    test('connection, timeout, cancelled → TransportOffline', () async {
      await expectMapping(Smb2ErrorType.connection, isA<TransportOffline>());
      await expectMapping(Smb2ErrorType.timeout, isA<TransportOffline>());
      await expectMapping(Smb2ErrorType.cancelled, isA<TransportOffline>());
    });

    test('notFound: TransportNotFound dall\'elenco, null da stat', () async {
      await expectLater(transport.list('altro'), throwsA(isA<TransportNotFound>()));
      expect(await transport.stat('altro'), isNull);
    });

    test('il resto → TransportException; notSupported alla connessione dice perché', () async {
      session.failure = const Smb2Exception('x', type: Smb2ErrorType.io);
      await expectLater(
        transport.list('manga'),
        throwsA(isA<TransportException>().having((e) => e is TransportOffline, 'offline', isFalse)),
      );
      final old = SmbTransport(() async => throw const Smb2Exception('x', type: Smb2ErrorType.notSupported));
      await expectLater(
        old.stat('manga'),
        throwsA(isA<TransportException>().having((e) => e.message, 'testo', contains('SMB 2.1'))),
      );
    });

    test('un errore di connessione si riprova alla richiesta dopo', () async {
      var attempts = 0;
      final flaky = SmbTransport(() async {
        if (attempts++ == 0) throw const Smb2Exception('x', type: Smb2ErrorType.connection);
        return session;
      });
      await expectLater(flaky.stat('manga'), throwsA(isA<TransportOffline>()));
      expect(await flaky.stat('manga'), isNotNull);
    });

    test('un connettore che chiede la password mancante propaga TransportAuthRequired', () async {
      final locked = SmbTransport(() async => throw const TransportAuthRequired());
      await expectLater(locked.stat('manga'), throwsA(isA<TransportAuthRequired>()));
    });
  });

  test('tempo massimo: il token annulla la richiesta bloccata', () async {
    session.hang = true;
    final quick = make(limit: const Duration(milliseconds: 50));
    final watch = Stopwatch()..start();
    await expectLater(quick.stat('manga'), throwsA(isA<TransportOffline>()));
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    quick.close();
  });

  test('connessione che non arriva mai: Offline, e la sessione tardiva si chiude', () async {
    final slow = Completer<SmbSession>();
    final quick = SmbTransport(() => slow.future, limit: const Duration(milliseconds: 20));
    await expectLater(quick.stat('manga'), throwsA(isA<TransportOffline>()));
    slow.complete(session);
    await Future<void>.delayed(Duration.zero);
    expect(session.closed, isTrue);
  });

  group('download', () {
    final content = List<int>.generate(2 * 1024 * 1024 + 1234, (i) => (i * 7) % 251);

    test('a blocchi da 1 MiB, identico al file', () async {
      session.put('manga/grande.bin', content);
      final target = File('${temp.path}/grande.bin');
      await transport.download('manga/grande.bin', target);
      expect(await target.readAsBytes(), content);
      expect(session.reads, [(0, 1 << 20), (1 << 20, 1 << 20), (2 << 20, 1234)]);
    });

    test('riprende da un offset byte per byte, in coda a ciò che c\'è', () async {
      session.put('manga/grande.bin', content);
      final target = File('${temp.path}/grande.bin');
      await target.writeAsBytes(content.sublist(0, 700000) + [1, 2, 3]);
      await transport.download('manga/grande.bin', target, resumeFrom: 700000);
      expect(await target.readAsBytes(), content);
      expect(session.reads.first, (700000, 1 << 20));
    });

    test('una ripresa oltre ciò che c\'è è un errore di chi chiama', () async {
      session.put('manga/grande.bin', content);
      final target = File('${temp.path}/grande.bin')..writeAsBytesSync([1, 2]);
      await expectLater(
        transport.download('manga/grande.bin', target, resumeFrom: 10),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('file cambiato e più corto: si riparte da capo', () async {
      session.put('manga/piccolo.bin', [9, 8, 7]);
      final target = File('${temp.path}/piccolo.bin')..writeAsBytesSync([1, 2, 3, 4, 5]);
      await transport.download('manga/piccolo.bin', target, resumeFrom: 5);
      expect(await target.readAsBytes(), [9, 8, 7]);
    });

    test('la rete cade a metà: ciò che è arrivato resta, e si riprende', () async {
      session.put('manga/grande.bin', content);
      final target = File('${temp.path}/grande.bin');
      final flaky = SmbTransport(() async => _CutAfter(session, 1));
      await expectLater(flaky.download('manga/grande.bin', target), throwsA(isA<TransportOffline>()));
      expect(await target.length(), 1 << 20);
      await transport.download('manga/grande.bin', target, resumeFrom: 1 << 20);
      expect(await target.readAsBytes(), content);
    });
  });

  test('testo troppo grande per essere un indice', () async {
    final small = make(maxText: 5);
    await expectLater(small.text('manga/library.json'), throwsA(isA<TransportException>()));
  });

  test('«..» e percorsi vuoti non arrivano in rete', () async {
    await expectLater(transport.stat('manga/../altro'), throwsA(isA<ArgumentError>()));
    await expectLater(transport.list('manga//x'), throwsA(isA<ArgumentError>()));
    expect(session.connects, 0);
  });

  group('indirizzo', () {
    test('in chiaro solo verso la rete di casa', () {
      expect(smbHost('192.168.1.10', seal: false), '192.168.1.10');
      expect(smbHost('nas.local', seal: false), 'nas.local');
      expect(smbHost(' NAS ', seal: false), 'nas');
      expect(() => smbHost('nas.example.com', seal: false), throwsFormatException);
      expect(() => smbHost('8.8.8.8', seal: false), throwsFormatException);
    });

    test('pubblico solo con la cifratura', () {
      expect(smbHost('nas.example.com', seal: true), 'nas.example.com');
    });

    test('niente schema, percorso, porta o credenziali nel campo host', () {
      for (final bad in ['', 'smb://nas.local', 'nas.local/share', 'nas.local:4450', 'u@nas.local', 'a b']) {
        expect(() => smbHost(bad, seal: true), throwsFormatException, reason: bad);
      }
    });

    test('condivisione senza separatori', () {
      expect(smbShare(' manga '), 'manga');
      expect(() => smbShare('a/b'), throwsFormatException);
      expect(() => smbShare(''), throwsFormatException);
    });
  });
}
