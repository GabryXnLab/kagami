/// Lo smistamento degli indirizzi remoti fra il Drive dell'account e le
/// altre sorgenti.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/sources/remote_router.dart';

class FakeFiles implements RemoteFiles {
  FakeFiles(this.name);

  final String name;
  final List<String> fetched = [];
  final List<String> warmed = [];
  final List<List<String>> chapters = [];

  @override
  Future<String> fetch(String address, {bool urgent = false}) async {
    fetched.add(address);
    return '/cache/$name/${fetched.length}';
  }

  @override
  String? peek(String address) => fetched.contains(address) ? '/cache/$name' : null;

  @override
  void warm(Iterable<String> addresses) => warmed.addAll(addresses);

  @override
  void rememberChapter(String series, String chapter, List<String> addresses) =>
      chapters.add(addresses);
}

void main() {
  late RemoteRouter router;
  late FakeFiles drive;
  late FakeFiles nas;
  const driveAddress = '${remotePrefix}serie/c1/001.webp';
  final nasAddress = sourceAddress('s-0000000a', 'serie/c1/001.webp');

  setUp(() {
    drive = FakeFiles('drive');
    nas = FakeFiles('nas');
    router = RemoteRouter()
      ..primary = drive
      ..attach('s-0000000a', nas);
  });

  test('gli indirizzi di Drive sono quelli di sempre', () {
    expect(driveAddress, 'drive:serie/c1/001.webp');
    expect(nasAddress, 'remote:s-0000000a/serie/c1/001.webp');
    expect(isRemote(driveAddress), isTrue);
    expect(isRemote(nasAddress), isTrue);
    expect(isRemote('/storage/manga/serie/c1/001.webp'), isFalse);
    expect(sourceIdOf(nasAddress), 's-0000000a');
    expect(sourceIdOf(driveAddress), isNull);
  });

  test('drive: va al Drive dell\'account, remote:<id>/ alla sua sorgente', () async {
    expect(await router.fetch(driveAddress, urgent: true), '/cache/drive/1');
    expect(await router.fetch(nasAddress), '/cache/nas/1');
    expect(drive.fetched, [driveAddress]);
    expect(nas.fetched, [nasAddress]);
    expect(router.peek(nasAddress), '/cache/nas');
  });

  test('una sorgente che non c\'è è un errore, non un file vuoto', () async {
    final unknown = sourceAddress('s-ffffffff', 'serie/c1/001.webp');
    await expectLater(router.fetch(unknown), throwsStateError);
    expect(router.peek(unknown), isNull);

    router.primary = null;
    await expectLater(router.fetch(driveAddress), throwsStateError);
    expect(router.peek(driveAddress), isNull);
  });

  test('precarichi e capitoli vanno ognuno alla sua sorgente, in ordine', () {
    final second = sourceAddress('s-0000000a', 'serie/c1/002.webp');
    final lost = sourceAddress('s-ffffffff', 'serie/c1/003.webp');
    router.warm([nasAddress, driveAddress, second, lost]);
    expect(nas.warmed, [nasAddress, second]);
    expect(drive.warmed, [driveAddress]);

    router.rememberChapter('serie', 'c1', [nasAddress, second]);
    expect(nas.chapters, [
      [nasAddress, second],
    ]);
    expect(drive.chapters, isEmpty);
  });

  test('chi si stacca dopo essere stato sostituito non porta via il sostituto', () async {
    final renewed = FakeFiles('nas-nuovo');
    router.attach('s-0000000a', renewed);
    router.detach('s-0000000a', nas);
    expect(await router.fetch(nasAddress), '/cache/nas-nuovo/1');
    router.detach('s-0000000a', renewed);
    await expectLater(router.fetch(nasAddress), throwsStateError);
  });
}
