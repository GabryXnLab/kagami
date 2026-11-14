/// Passo zero della condivisione (FASE-5b §2): prima di un permesso i dati
/// personali di `reading/` vanno nel cestino di Drive; se non si possono
/// elencare o cestinare il permesso non nasce. Il foglio li segnala con «Togli».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/drive_access.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_shares.dart';
import 'package:kagami/src/ui/drive_share_sheet.dart';
import 'package:kagami/src/ui/theme.dart';

import 'drive_access_test.dart' show FakeDrive;

/// Una cartella `F` con, se serve, `reading/` dentro.
class _Drive extends FakeDrive {
  Map<String, List<DriveItem>> tree = {};
  Object? listError;
  Object? trashError;

  @override
  Future<List<DriveItem>> query(String q, {String orderBy = 'name'}) async {
    calls.add('list');
    if (listError case final error?) throw error;
    final parent = RegExp(r"'([^']+)' in parents").firstMatch(q)!.group(1)!;
    return [for (final item in tree[parent] ?? const <DriveItem>[]) if (item.name == 'reading') item];
  }

  @override
  Future<List<DriveItem>> children(String folderId) async {
    calls.add('children $folderId');
    if (listError case final error?) throw error;
    return tree[folderId] ?? const [];
  }

  @override
  Future<void> trash(String id) async {
    calls.add('trash $id');
    if (trashError case final error?) throw error;
    for (final entry in tree.entries) {
      tree[entry.key] = [for (final item in entry.value) if (item.id != id) item];
    }
  }
}

const _reading = DriveItem(id: 'R', name: 'reading', folder: true);

void _personal(_Drive drive) => drive.tree = {
      'F': const [_reading, DriveItem(id: 'S1', name: 'Una serie', folder: true)],
      'R': const [
        DriveItem(id: 'B', name: 'backup', folder: true),
        DriveItem(id: 'ST', name: 'state.json'),
        DriveItem(id: 'C', name: 'collections.json'),
        DriveItem(id: 'D', name: 'downloads.json'),
        DriveItem(id: 'X', name: 'backup'), // un file, non la cartella
      ],
    };

void main() {
  late MemoryShareDirectory directory;
  late _Drive drive;
  late DriveAccess access;

  setUp(() {
    directory = MemoryShareDirectory();
    drive = _Drive();
    access = DriveAccess(
      directory: directory,
      drive: drive,
      account: () => const CloudAccount(id: 'me', email: 'me@example.com'),
    );
  });

  Future<DriveShare> share() => access.share(folderId: 'F', folderName: 'Libreria', email: 'amico@example.com');

  test('dati presenti: cestino, poi permesso, poi riga; downloads.json resta', () async {
    _personal(drive);
    final row = await share();
    expect(drive.calls, ['list', 'children R', 'trash B', 'trash ST', 'trash C', 'share amico@example.com']);
    expect(directory.log, ['put ${row.id}']);
  });

  test('elenco fallito: nessun permesso e nessuna riga', () async {
    drive.listError = const DriveOffline();
    await expectLater(share(), throwsA(isA<DriveOffline>()));
    expect(drive.calls, ['list']);
    expect(directory.rows, isEmpty);
  });

  test('cestino fallito: nessun permesso', () async {
    _personal(drive);
    drive.trashError = const DriveException('rifiutato', status: 403);
    await expectLater(share(), throwsA(isA<DriveException>()));
    expect(drive.calls.where((call) => call.startsWith('share')), isEmpty);
    expect(directory.rows, isEmpty);
  });

  test('niente da pulire: nessuna scrittura in più', () async {
    drive.tree = {
      'F': const [_reading],
      'R': const [DriveItem(id: 'D', name: 'downloads.json')],
    };
    await share();
    expect(drive.calls, ['list', 'children R', 'share amico@example.com']);
  });

  test('il proprio indirizzo si rifiuta prima di toccare la cartella', () async {
    _personal(drive);
    await expectLater(
      access.share(folderId: 'F', folderName: 'Libreria', email: 'Me@Example.com'),
      throwsA(isA<ArgumentError>()),
    );
    expect(drive.calls, isEmpty);
  });

  test('renew: passo zero prima del rinnovo; elenco fallito = niente rinnovo', () async {
    final row = await share();
    _personal(drive);
    drive.calls.clear();
    await access.renew(row, const Duration(days: 7));
    expect(drive.calls, ['list', 'children R', 'trash B', 'trash ST', 'trash C', 'renew ${row.permissionId}']);

    drive.calls.clear();
    drive.listError = const DriveOffline();
    await expectLater(access.renew(row, null), throwsA(isA<DriveOffline>()));
    expect(drive.calls, ['list']);
  });

  test('renew con permesso sparito: un permesso nuovo, senza ripulire due volte', () async {
    final row = await share();
    drive.calls.clear();
    drive.renewError = const DriveException('non trovato', status: 404);
    await access.renew(row, null);
    expect(drive.calls.where((call) => call == 'list'), hasLength(1));
    expect(drive.calls.last, 'share amico@example.com');
  });

  test('readers: con un lettore cerca i dati; senza lettori non chiede; elenco fallito = null', () async {
    _personal(drive);
    expect((await access.readers('F')).personal, isEmpty);
    expect(drive.calls, isNot(contains('list')));

    drive.permissions = const [DrivePermission(id: 'p9', email: 'altro@example.com')];
    expect([for (final item in (await access.readers('F')).personal!) item.id], ['B', 'ST', 'C']);

    drive.listError = const DriveOffline();
    expect((await access.readers('F')).personal, isNull);
  });

  group('foglio', () {
    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          driveAccessProvider.overrideWithValue(access),
          driveFolderProvider.overrideWith(_Folder.new),
          driveAuthProvider.overrideWithValue(_Auth()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          theme: kagamiTheme(Brightness.dark),
          home: const Scaffold(body: SingleChildScrollView(child: DriveShareSheet())),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('dati trovati con un lettore: avviso e «Togli» dopo il consenso', (tester) async {
      _personal(drive);
      drive.permissions = const [DrivePermission(id: 'p9', email: 'altro@example.com')];
      await open(tester);
      final remove = find.widgetWithText(TextButton, 'Togli');
      expect(find.textContaining('copie dei tuoi dati di lettura'), findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.textContaining('nel cestino di Drive'), findsWidgets);
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(drive.calls, containsAllInOrder(['trash B', 'trash ST', 'trash C']));
      // Si rilegge: sono nel cestino e la nota se ne va.
      expect(find.textContaining('copie dei tuoi dati di lettura'), findsNothing);
    });

    testWidgets('nessun lettore: nessun avviso e nessuna ricerca', (tester) async {
      _personal(drive);
      await open(tester);
      expect(find.textContaining('copie dei tuoi dati di lettura'), findsNothing);
      expect(drive.calls, isNot(contains('list')));
    });
  });
}

class _Auth extends DriveAuth {
  @override
  Future<void> authorize({bool write = false}) async {}
}

class _Folder extends DriveFolderNotifier {
  @override
  Future<DriveFolder?> build() async => const DriveFolder(id: 'F', name: 'Libreria');
}
