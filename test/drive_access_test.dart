import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/drive_access.dart';
import 'package:kagami/src/data/network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeDrive extends DriveClient {
  FakeDrive() : super(({refresh = false}) async => 'token', network: NetworkMonitor.instance);

  final List<String> calls = [];
  Object? unshareError;
  Object? renewError;
  Object? sharedWithError;
  String? answerEmail;
  List<DrivePermission> permissions = [];
  int _n = 0;

  @override
  Future<DrivePermission> share(String folderId, String email, {DateTime? expiresAt}) async {
    calls.add('share $email');
    return DrivePermission(id: 'p${++_n}', email: answerEmail ?? email, expiresAt: expiresAt);
  }

  @override
  Future<DrivePermission> renewShare(String folderId, String permissionId, DateTime? expiresAt) async {
    calls.add('renew $permissionId');
    if (renewError case final error?) throw error;
    return DrivePermission(id: permissionId, expiresAt: expiresAt);
  }

  @override
  Future<void> unshare(String folderId, String permissionId) async {
    calls.add('unshare $permissionId');
    if (unshareError case final error?) throw error;
  }

  // La cartella non ha `reading/`: il passo zero non trova niente.
  @override
  Future<List<DriveItem>> query(String q, {String orderBy = 'name'}) async => const [];

  @override
  Future<List<DrivePermission>> sharedWith(String folderId) async {
    if (sharedWithError case final error?) throw error;
    return permissions;
  }
}

void main() {
  final t0 = DateTime.utc(2026, 11, 14, 12);
  late MemoryShareDirectory directory;
  late FakeDrive drive;
  late DriveAccess access;
  var clock = t0;

  setUp(() {
    clock = t0;
    directory = MemoryShareDirectory();
    drive = FakeDrive();
    access = DriveAccess(
      directory: directory,
      drive: drive,
      account: () => const CloudAccount(id: 'me', email: 'Me@Example.com', name: 'Io'),
      now: () => clock,
    );
  });

  Future<DriveShare> shared([String to = 'amico@example.com', Duration? d = const Duration(days: 1)]) =>
      access.share(folderId: 'F', folderName: 'Libreria', email: to, duration: d);

  test('share: prima il permesso, poi la riga, con id e termine del contratto', () async {
    final row = await shared('Amico@Example.com');
    expect(drive.calls, ['share amico@example.com']);
    expect(directory.log, ['put ${row.id}']);
    expect(row.id, DriveShare.shareId('me@example.com', 'amico@example.com', 'F'));
    expect(row.id.length, 32);
    expect(row.from, 'me@example.com');
    expect(row.expiresAt, t0.add(const Duration(days: 1)));
    expect(directory.rows[row.id]!.permissionId, 'p1');
  });

  test('share: to_email è quello che risponde Drive, e il termine è di Kagami anche se Drive lo rifiuta', () async {
    drive.answerEmail = 'principale@example.com';
    final row = await shared('alias@example.com');
    expect(row.to, 'principale@example.com');
    expect(row.id, DriveShare.shareId('me@example.com', 'principale@example.com', 'F'));
    expect(row.expiresAt, isNotNull);
  });

  test('share: nomi troncati a 127 caratteri', () async {
    final row = await access.share(folderId: 'F', folderName: 'x' * 300, email: 'a@example.com');
    expect(row.folderName.length, 127);
    expect(row.expiresAt, isNull);
  });

  test('share con sé stessi: errore prima di ogni richiesta', () async {
    await expectLater(shared('ME@example.com'), throwsArgumentError);
    expect(drive.calls, isEmpty);
    expect(directory.log, isEmpty);
  });

  test('share: la riga non si scrive, il permesso si ritira e l\'errore della riga esce', () async {
    directory.putFailure = StateError('riga');
    await expectLater(shared(), throwsStateError);
    expect(drive.calls, ['share amico@example.com', 'unshare p1']);
    drive.calls.clear();
    drive.unshareError = const DriveOffline();
    await expectLater(shared(), throwsStateError);
    expect(drive.calls.last, 'unshare p2');
  });

  test('renew: renewShare e poi la riga con il termine nuovo', () async {
    final row = await shared();
    drive.calls.clear();
    directory.log.clear();
    clock = t0.add(const Duration(hours: 5));
    final next = await access.renew(row, const Duration(days: 7));
    expect(drive.calls, ['renew p1']);
    expect(directory.log, ['put ${row.id}']);
    expect(next.expiresAt, clock.add(const Duration(days: 7)));
    expect(directory.rows[row.id]!.expiresAt, next.expiresAt);
    expect(next.at, row.at);
  });

  test('renew con 404: permesso nuovo e riga aggiornata', () async {
    final row = await shared();
    drive.calls.clear();
    drive.renewError = const DriveException('no', status: 404);
    final next = await access.renew(row, const Duration(days: 3));
    expect(drive.calls, ['renew p1', 'share amico@example.com']);
    expect(next.permissionId, 'p2');
    expect(directory.rows[row.id]!.permissionId, 'p2');
    expect(directory.rows[row.id]!.expiresAt, t0.add(const Duration(days: 3)));
  });

  test('renew: riga non aggiornata, l\'errore esce e niente si disfa', () async {
    final row = await shared();
    drive.calls.clear();
    directory.putFailure = StateError('riga');
    await expectLater(access.renew(row, null), throwsStateError);
    expect(drive.calls, ['renew p1']);
    expect(directory.rows[row.id]!.expiresAt, row.expiresAt);
  });

  test('revoke: Drive offline lascia la riga, con 404 (già tolto) la toglie', () async {
    final row = await shared();
    drive.unshareError = const DriveOffline();
    await expectLater(access.revoke(row), throwsA(isA<DriveOffline>()));
    expect(directory.rows, contains(row.id));
    drive.unshareError = null;
    await access.revoke(row);
    expect(directory.rows, isEmpty);
    expect(drive.calls.last, 'unshare p1');
  });

  test('sweep: ritira solo le scadute e continua dopo un errore', () async {
    final a = await shared('a@example.com', const Duration(hours: 1));
    final b = await shared('b@example.com', const Duration(hours: 1));
    final c = await shared('c@example.com', const Duration(days: 5));
    final d = await shared('d@example.com', null);
    final e = await shared('e@example.com', const Duration(hours: 1));
    clock = t0.add(const Duration(hours: 2));
    drive.unshareError = const DriveAuthRequired();
    expect(await access.sweep(), 0);
    expect(directory.rows.length, 5);
    drive.unshareError = null;
    drive.calls.clear();
    // Fa fallire solo il permesso di b.
    final failing = _OnlyFails(drive, b.permissionId);
    final sweeper = DriveAccess(
      directory: directory,
      drive: failing,
      account: access.account,
      now: () => clock,
    );
    expect(await sweeper.sweep(), 2);
    expect(directory.rows.keys.toSet(), {b.id, c.id, d.id});
    expect(directory.rows, isNot(contains(a.id)));
    expect(directory.rows, isNot(contains(e.id)));
  });

  test('sweep: mine() fallita, esce l\'errore e niente cambia', () async {
    await shared('a@example.com', const Duration(hours: 1));
    clock = t0.add(const Duration(hours: 2));
    directory.failure = StateError('lettura');
    await expectLater(access.sweep(), throwsStateError);
    directory.failure = null;
    expect(directory.rows.length, 1);
    expect(drive.calls.where((call) => call.startsWith('unshare')), isEmpty);
  });

  test('readers: righe, permessi senza riga, link; Drive che non risponde dà le righe lo stesso', () async {
    final row = await shared();
    await access.share(folderId: 'G', folderName: 'Altra', email: 'x@example.com');
    drive.permissions = [
      const DrivePermission(id: 'o', role: 'owner', email: 'me@example.com'),
      DrivePermission(id: row.permissionId, email: 'amico@example.com'),
      const DrivePermission(id: 'z', email: 'amico@example.com'),
      const DrivePermission(id: 'm', email: 'manuale@example.com'),
      const DrivePermission(id: 'g', type: 'group', email: 'gruppo@example.com'),
      const DrivePermission(id: 'l', type: 'anyone'),
    ];
    var readers = await access.readers('F');
    expect(readers.shares.length, 2);
    expect(readers.withoutRow.map((p) => p.id), ['m', 'g']);
    expect(readers.linkAccess, isTrue);
    expect(readers.driveAnswered, isTrue);

    drive.sharedWithError = const DriveOffline();
    readers = await access.readers('F');
    expect(readers.shares.length, 2);
    expect(readers.driveAnswered, isFalse);
    expect(readers.withoutRow, isEmpty);
  });

  test('ShareUnavailable per tabella assente o negata, gli altri errori passano', () async {
    await expectLater(
      guardShares<void>(() async => throw const PostgrestException(message: 'x', code: 'PGRST205')),
      throwsA(isA<ShareUnavailable>()),
    );
    await expectLater(
      guardShares<void>(() async => throw const PostgrestException(message: 'x', code: '42501')),
      throwsA(isA<ShareUnavailable>()),
    );
    await expectLater(
      guardShares<void>(() async => throw const PostgrestException(message: 'x', code: '23505')),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('revokePermission ritira il permesso senza riga', () async {
    await access.revokePermission('F', 'm');
    expect(drive.calls, ['unshare m']);
  });
}

/// Come [FakeDrive], ma `unshare` fallisce per un solo permesso.
class _OnlyFails extends FakeDrive {
  _OnlyFails(this.inner, this.bad);
  final FakeDrive inner;
  final String bad;

  @override
  Future<void> unshare(String folderId, String permissionId) async {
    if (permissionId == bad) throw const DriveOffline();
  }
}
