import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/share_directory.dart';
import 'package:kagami/src/data/share_expiry_notice.dart';
import 'package:kagami/src/data/shared_library.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/data/user_repository.dart';

void main() {
  late KagamiDatabase db;
  late UserRepository user;
  final t0 = DateTime.utc(2026, 11, 1);
  final accepted = [
    const SourceConfig(
      id: 's',
      kind: SourceKind.driveShared,
      label: 'Manga',
      params: {'folderId': 'f1', 'owner': 'bob@x.it'},
    ),
  ];

  DriveShare row({DateTime? expiresAt}) => DriveShare(
        id: 's1',
        to: 'me@x.it',
        from: 'bob@x.it',
        folderId: 'f1',
        folderName: 'Manga',
        permissionId: 'p',
        at: t0,
        expiresAt: expiresAt,
      );

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    user = UserRepository(db);
  });
  tearDown(() => db.close());

  /// Una lettura delle righe all'istante [now]: le soglie annunciate, in giorni.
  Future<List<int>> run(List<DriveShare> rows, DateTime now,
      {List<SourceConfig>? sources, Set<String> dismissed = const {}}) async {
    final sent = <int>[];
    await announceShareExpiries(user, rows, sources ?? accepted, dismissed, (n) async => sent.add(n.threshold.inDays),
        now: now);
    return sent;
  }

  final expiry = DateTime.utc(2026, 11, 20);

  test('7 giorni una volta sola, poi 1 giorno una volta sola', () async {
    final rows = [row(expiresAt: expiry)];
    expect(await run(rows, expiry.subtract(const Duration(days: 8))), isEmpty);
    expect(await run(rows, expiry.subtract(const Duration(days: 6))), [7]);
    expect(await run(rows, expiry.subtract(const Duration(days: 5))), isEmpty);
    expect(await run(rows, expiry.subtract(const Duration(hours: 20))), [1]);
    expect(await run(rows, expiry.subtract(const Duration(hours: 2))), isEmpty);
  });

  test('aperta a meno di un giorno dal termine dà un solo avviso, quello urgente', () async {
    final rows = [row(expiresAt: expiry)];
    expect(await run(rows, expiry.subtract(const Duration(hours: 5))), [1]);
    expect(await run(rows, expiry.subtract(const Duration(hours: 4))), isEmpty);
  });

  test('niente per righe senza scadenza, scadute, rifiutate o non accettate', () async {
    final now = expiry.subtract(const Duration(hours: 5));
    expect(await run([row()], now), isEmpty);
    expect(await run([row(expiresAt: expiry)], expiry), isEmpty);
    expect(await run([row(expiresAt: expiry)], now, dismissed: {shareStamp(row(expiresAt: expiry))}), isEmpty);
    expect(await run([row(expiresAt: expiry)], now, sources: const []), isEmpty);
    expect(await run([row(expiresAt: expiry)], now, sources: [accepted.single.copyWith(label: 'x', params: const {'folderId': 'altra', 'owner': 'bob@x.it'})]), isEmpty);
  });

  test('un rinnovo che sposta il termine riarma le soglie', () async {
    expect(await run([row(expiresAt: expiry)], expiry.subtract(const Duration(days: 6))), [7]);
    final renewed = expiry.add(const Duration(days: 30));
    expect(await run([row(expiresAt: renewed)], expiry.subtract(const Duration(days: 6))), isEmpty);
    expect(await run([row(expiresAt: renewed)], renewed.subtract(const Duration(days: 6))), [7]);
    expect(await run([row(expiresAt: renewed)], renewed.subtract(const Duration(hours: 3))), [1]);
  });

  test('una notifica che fallisce non si ricorda: si riprova alla lettura dopo', () async {
    final rows = [row(expiresAt: expiry)];
    final now = expiry.subtract(const Duration(days: 6));
    await expectLater(
      announceShareExpiries(user, rows, accepted, {}, (_) async => throw StateError('no'), now: now),
      throwsStateError,
    );
    expect(await run(rows, now), [7]);
  });
}
