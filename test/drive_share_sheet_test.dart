/// Il foglio «Chi può leggere la mia libreria»: dice il vero (righe, permessi
/// senza riga, Drive che non risponde, righe non lette ≠ nessuno) e scrive solo
/// dopo il consenso.
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
import 'package:kagami/src/ui/widgets/kit.dart';

import 'drive_access_test.dart' show FakeDrive;

class _Auth extends DriveAuth {
  final List<String> calls = [];

  @override
  Future<void> authorize({bool write = false}) async => calls.add('authorize $write');
}

class _Folder extends DriveFolderNotifier {
  @override
  Future<DriveFolder?> build() async => const DriveFolder(id: 'F', name: 'Libreria');
}

void main() {
  late MemoryShareDirectory directory;
  late FakeDrive drive;
  late _Auth auth;

  DriveShare row(String to, {String folder = 'F', String name = 'Libreria', DateTime? expires, String permission = 'p'}) =>
      DriveShare(
        id: DriveShare.shareId('me@example.com', to, folder),
        to: to,
        from: 'me@example.com',
        folderId: folder,
        folderName: name,
        permissionId: '$permission-$to',
        at: DateTime(2026, 11, 1),
        expiresAt: expires,
      );

  void put(DriveShare share) => directory.rows[share.id] = share;

  setUp(() {
    directory = MemoryShareDirectory();
    drive = FakeDrive();
    auth = _Auth();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final access = DriveAccess(
      directory: directory,
      drive: drive,
      account: () => const CloudAccount(id: 'me', email: 'me@example.com'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        driveAccessProvider.overrideWithValue(access),
        driveFolderProvider.overrideWith(_Folder.new),
        driveAuthProvider.overrideWithValue(auth),
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

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
  }

  testWidgets('elenca le righe con scadenza, scaduto e altra cartella', (tester) async {
    put(row('amico@example.com', expires: DateTime.now().add(const Duration(days: 10))));
    put(row('vecchio@example.com', expires: DateTime.now().subtract(const Duration(days: 1))));
    put(row('fisso@example.com'));
    put(row('altro@example.com', folder: 'G', name: 'Altra'));
    // La passata ritira la riga scaduta: Drive la toglie e sparisce.
    await open(tester);
    expect(find.text('amico@example.com'), findsOneWidget);
    expect(find.textContaining('Scade il'), findsOneWidget);
    expect(find.text('fisso@example.com'), findsOneWidget);
    expect(find.textContaining('Cartella «Altra»'), findsOneWidget);
    expect(find.text('vecchio@example.com'), findsNothing);
    expect(drive.calls, contains('unshare p-vecchio@example.com'));
  });

  testWidgets('una scaduta che non si riesce a ritirare si mostra «Scaduto» con «Togli»', (tester) async {
    drive.unshareError = const DriveOffline();
    put(row('vecchio@example.com', expires: DateTime.now().subtract(const Duration(days: 1))));
    await open(tester);
    expect(find.text('vecchio@example.com'), findsOneWidget);
    expect(find.textContaining('Scaduto'), findsOneWidget);
    expect(find.byTooltip('Togli'), findsOneWidget);
  });

  testWidgets('aggiunta con durata: consenso, permesso, riga', (tester) async {
    await open(tester);
    expect(find.text('Nessuno, per ora.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Nuovo@Example.com');
    await tester.tap(find.text('Una settimana'));
    await tester.tap(find.widgetWithText(KButton, 'Condividi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('vedrà tutti i file'), findsOneWidget);
    await tapContinue(tester);
    expect(auth.calls, ['authorize true']);
    expect(drive.calls, ['share nuovo@example.com']);
    final saved = directory.rows.values.single;
    expect(saved.to, 'nuovo@example.com');
    expect(saved.expiresAt!.difference(saved.at).inDays, 7);
    expect(find.text('nuovo@example.com'), findsOneWidget);
  });

  testWidgets('chi rinuncia al consenso: non succede niente', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'nuovo@example.com');
    await tester.tap(find.widgetWithText(KButton, 'Condividi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(auth.calls, isEmpty);
    expect(drive.calls, isEmpty);
    expect(directory.rows, isEmpty);
  });

  testWidgets('rinnovo con un termine nuovo', (tester) async {
    final old = row('amico@example.com', expires: DateTime.now().add(const Duration(days: 2)));
    put(old);
    await open(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Rinnova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Un anno').last);
    await tester.tap(find.widgetWithText(KButton, 'Rinnova'));
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(drive.calls, ['renew ${old.permissionId}']);
    expect(directory.rows[old.id]!.expiresAt!.difference(DateTime.now()).inDays, greaterThan(360));
  });

  testWidgets('togli: conferma, consenso, permesso e riga', (tester) async {
    final share = row('amico@example.com');
    put(share);
    await open(tester);
    await tester.tap(find.byTooltip('Togli'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Togli'));
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(drive.calls, ['unshare ${share.permissionId}']);
    expect(directory.rows, isEmpty);
    expect(find.text('amico@example.com'), findsNothing);
  });

  testWidgets('un errore di rete nel togliere lascia la riga e lo dice', (tester) async {
    put(row('amico@example.com'));
    drive.unshareError = const DriveOffline();
    await open(tester);
    await tester.tap(find.byTooltip('Togli'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Togli'));
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(directory.rows, hasLength(1));
    expect(find.text('amico@example.com'), findsOneWidget);
    expect(find.text('Nessuna connessione: non è cambiato niente.'), findsOneWidget);
  });

  testWidgets('un permesso senza riga si mostra e si toglie; il link è un avviso', (tester) async {
    drive.permissions = const [
      DrivePermission(id: 'x1', email: 'manuale@example.com'),
      DrivePermission(id: 'x2', type: 'anyone'),
    ];
    await open(tester);
    expect(find.text('manuale@example.com'), findsOneWidget);
    expect(find.text('Condiviso da Drive'), findsOneWidget);
    expect(find.textContaining('chi ha il link'), findsOneWidget);
    await tester.tap(find.byTooltip('Togli'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Togli'));
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(drive.calls, ['unshare x1']);
  });

  testWidgets('Drive che non risponde: avviso, righe presenti, mai «nessuno»', (tester) async {
    drive.sharedWithError = const DriveOffline();
    put(row('amico@example.com'));
    await open(tester);
    expect(find.textContaining('Drive non ha risposto'), findsOneWidget);
    expect(find.text('amico@example.com'), findsOneWidget);
    expect(find.text('Nessuno, per ora.'), findsNothing);

  });

  testWidgets('senza la tabella: il messaggio e niente campo', (tester) async {
    directory.failure = const ShareUnavailable();
    await open(tester);
    expect(find.textContaining('non ha la condivisione'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('righe non lette: errore con «Riprova», non un elenco vuoto', (tester) async {
    directory.failure = StateError('rete');
    await open(tester);
    expect(find.textContaining('Non riesco a leggere'), findsOneWidget);
    expect(find.text('Nessuno, per ora.'), findsNothing);
    directory.failure = null;
    put(row('amico@example.com'));
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(find.text('amico@example.com'), findsOneWidget);
  });
}
