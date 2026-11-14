/// Il permesso di scaricare nei fogli di condivisione (FASE-5b §4, F5.18): la
/// scelta alla concessione e sulla riga, il testo onesto, ciò che vede chi
/// riceve, e il backend senza la colonna che lo dice invece di fingere.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/cloud.dart';
import 'package:kagami/src/data/drive.dart';
import 'package:kagami/src/data/drive_access.dart';
import 'package:kagami/src/data/sources/source.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/providers_shares.dart';
import 'package:kagami/src/providers_sources.dart';
import 'package:kagami/src/ui/drive_received_sheet.dart';
import 'package:kagami/src/ui/drive_share_sheet.dart';
import 'package:kagami/src/ui/theme.dart';

import 'drive_access_test.dart' show FakeDrive;

class _Auth extends DriveAuth {
  @override
  Future<void> authorize({bool write = false}) async {}
}

class _Folder extends DriveFolderNotifier {
  @override
  Future<DriveFolder?> build() async => const DriveFolder(id: 'F', name: 'Libreria');
}

class _Sources extends LibrarySources {
  _Sources(this.list);

  final List<SourceConfig> list;

  @override
  Future<SourceList> build() async => SourceList(list);
}

void main() {
  late MemoryShareDirectory directory;
  late FakeDrive drive;

  setUp(() {
    directory = MemoryShareDirectory();
    drive = FakeDrive();
  });

  Future<void> open(WidgetTester tester, Widget sheet, List<Object> overrides) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      // ignore: argument_type_not_assignable
      overrides: overrides.cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        theme: kagamiTheme(Brightness.dark),
        home: Scaffold(body: SingleChildScrollView(child: sheet)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openShare(WidgetTester tester) => open(tester, const DriveShareSheet(), [
        driveAccessProvider.overrideWithValue(DriveAccess(
          directory: directory,
          drive: drive,
          account: () => const CloudAccount(id: 'me', email: 'me@example.com'),
        )),
        driveFolderProvider.overrideWith(_Folder.new),
        driveAuthProvider.overrideWithValue(_Auth()),
      ]);

  Future<void> add(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'amico@example.com');
    await tester.tap(find.text('Condividi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
  }

  DriveShare row({bool download = false}) => DriveShare(
        id: DriveShare.shareId('me@example.com', 'amico@example.com', 'F'),
        to: 'amico@example.com',
        from: 'me@example.com',
        folderId: 'F',
        folderName: 'Libreria',
        permissionId: 'p',
        at: DateTime(2026, 11, 1),
        download: download,
      );

  testWidgets('il foglio dice che è un patto fra app e di serie concede solo streaming', (tester) async {
    await openShare(tester);
    expect(find.text('Può anche scaricare'), findsOneWidget);
    expect(find.textContaining('patto fra app, non una protezione'), findsOneWidget);
    await add(tester);
    expect(directory.rows.values.single.download, isFalse);
  });

  testWidgets('con l\'interruttore la concessione porta download', (tester) async {
    await openShare(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await add(tester);
    expect(directory.rows.values.single.download, isTrue);
  });

  testWidgets('la riga dice il permesso e si cambia da lì, senza toccare Drive', (tester) async {
    directory.rows[row().id] = row();
    await openShare(tester);
    expect(find.textContaining('solo streaming'), findsOneWidget);
    drive.calls.clear();
    await tester.tap(find.byTooltip('Permetti di scaricare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(directory.rows[row().id]!.download, isTrue);
    expect(find.textContaining('anche scaricare'), findsWidgets);
    expect(drive.calls.where((call) => call.startsWith('share') || call.startsWith('unshare')), isEmpty);
    expect(find.byTooltip('Solo streaming'), findsOneWidget);
  });

  testWidgets('backend senza la colonna: concedere lo scaricare lo dice e non scrive', (tester) async {
    directory.withoutDownloadColumn = true;
    directory.rows[row().id] = row();
    await openShare(tester);
    await tester.tap(find.byTooltip('Permetti di scaricare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(find.textContaining('non sa ancora il permesso di scaricare'), findsOneWidget);
    expect(directory.rows[row().id]!.download, isFalse);
  });

  testWidgets('backend senza la colonna: la concessione con download lo dice e ritira il permesso', (tester) async {
    directory.withoutDownloadColumn = true;
    await openShare(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await add(tester);
    expect(find.textContaining('non sa ancora il permesso di scaricare'), findsOneWidget);
    expect(directory.rows, isEmpty);
    expect(drive.calls.any((call) => call.startsWith('unshare')), isTrue);
  });

  testWidgets('backend senza la colonna: la concessione solo streaming funziona', (tester) async {
    directory.withoutDownloadColumn = true;
    await openShare(tester);
    await add(tester);
    expect(find.textContaining('non sa ancora'), findsNothing);
    expect(directory.rows.values.single.download, isFalse);
  });

  testWidgets('chi riceve legge cosa gli è concesso', (tester) async {
    SourceConfig source(String id, bool download) => SourceConfig(
          id: id,
          kind: SourceKind.driveShared,
          label: 'Libreria $id',
          params: {'folderId': 'f', 'owner': 'bob@x.it', if (download) 'download': true},
        );
    await open(tester, const DriveReceivedSheet(), [
      incomingSharesProvider.overrideWith((ref) => Stream.value(const <DriveShare>[])),
      librarySourcesProvider.overrideWith(() => _Sources([source('uno', true), source('due', false)])),
    ]);
    expect(find.textContaining('puoi leggere e scaricare'), findsOneWidget);
    expect(find.textContaining('puoi solo leggere in streaming'), findsOneWidget);
  });
}
