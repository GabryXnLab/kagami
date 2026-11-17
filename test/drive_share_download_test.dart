/// Il permesso di scaricare nella riga di `drive_shares` (FASE-5b §4, F5.17):
/// di serie «solo streaming», si concede e si cambia con una riga sola, e un
/// backend senza la colonna vale «solo streaming».
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/drive_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'drive_access_test.dart' show FakeDrive;

void main() {
  late MemoryShareDirectory directory;
  late FakeDrive drive;
  late DriveAccess access;

  setUp(() {
    directory = MemoryShareDirectory();
    drive = FakeDrive();
    access = DriveAccess(
      directory: directory,
      drive: drive,
      account: () => const CloudAccount(id: 'me', email: 'me@example.com'),
    );
  });

  Map<String, Object?> row([Map<String, Object?> extra = const {}]) => {
        'id': 'i',
        'to_email': 'a@example.com',
        'from_email': 'me@example.com',
        'folder_id': 'F',
        'folder_name': 'L',
        'permission_id': 'p',
        'at': '2026-11-14T12:00:00Z',
        ...extra,
      };

  test('una riga senza il campo, o con null, è solo streaming', () {
    expect(DriveShare.fromRow(row()).download, isFalse);
    expect(DriveShare.fromRow(row({'download': null})).download, isFalse);
    expect(DriveShare.fromRow(row({'download': true})).download, isTrue);
  });

  test('toRow porta il campo, anche falso, e copyWith lo cambia', () {
    final share = DriveShare.fromRow(row());
    expect(share.toRow()['download'], false);
    expect(share.copyWith(download: true).toRow()['download'], true);
    expect(share.copyWith(permissionId: 'q').download, isFalse);
  });

  test('share: di serie solo streaming, con download la riga lo porta', () async {
    final base = await access.share(folderId: 'F', folderName: 'L', email: 'a@example.com');
    expect(directory.rows[base.id]!.download, isFalse);
    final more = await access.share(folderId: 'F', folderName: 'L', email: 'b@example.com', download: true);
    expect(directory.rows[more.id]!.download, isTrue);
  });

  test('setDownload cambia solo la riga: niente su Drive, il resto intatto', () async {
    final share = await access.share(
      folderId: 'F',
      folderName: 'L',
      email: 'a@example.com',
      duration: const Duration(days: 2),
    );
    drive.calls.clear();
    directory.log.clear();
    final on = await access.setDownload(share, true);
    expect(drive.calls, isEmpty);
    expect(directory.log, ['put ${share.id}']);
    expect(on.download, isTrue);
    expect(directory.rows[share.id]!.download, isTrue);
    expect(directory.rows[share.id]!.expiresAt, share.expiresAt);
    expect(directory.rows[share.id]!.permissionId, share.permissionId);
    expect((await access.setDownload(on, false)).download, isFalse);
    expect(directory.rows[share.id]!.download, isFalse);
  });

  test('un rinnovo non toglie il permesso di scaricare', () async {
    final share = await access.share(
      folderId: 'F',
      folderName: 'L',
      email: 'a@example.com',
      duration: const Duration(days: 1),
      download: true,
    );
    expect((await access.renew(share, const Duration(days: 5))).download, isTrue);
  });

  group('backend senza la colonna', () {
    final share = DriveShare.fromRow(row({'download': true}));

    for (final code in ['PGRST204', '42703', '42501']) {
      test('$code: «solo streaming» si riscrive senza il campo', () async {
        final writes = <Map<String, Object?>>[];
        await SupabaseShareDirectory.writeShareRow(share.copyWith(download: false), (data) async {
          writes.add(data);
          if (data.containsKey('download')) throw PostgrestException(message: 'no', code: code);
        });
        expect(writes, hasLength(2));
        expect(writes.last.containsKey('download'), isFalse);
        expect(writes.last['permission_id'], 'p');
      });

      test('$code: concedere lo scaricare esce con ShareDownloadUnavailable, senza riscrivere', () async {
        var writes = 0;
        await expectLater(
          SupabaseShareDirectory.writeShareRow(share, (data) async {
            writes++;
            throw PostgrestException(message: 'no', code: code);
          }),
          throwsA(isA<ShareDownloadUnavailable>()),
        );
        expect(writes, 1);
      });
    }

    test('un altro errore esce e non si riprova', () async {
      var writes = 0;
      await expectLater(
        SupabaseShareDirectory.writeShareRow(share, (data) async {
          writes++;
          throw PostgrestException(message: 'rete', code: '57014');
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(writes, 1);
    });

    test('backend con la colonna: una scrittura sola, col campo', () async {
      final writes = <Map<String, Object?>>[];
      await SupabaseShareDirectory.writeShareRow(share, (data) async => writes.add(data));
      expect(writes, hasLength(1));
      expect(writes.single['download'], true);
    });
  });
}
