/// Le note del dispositivo che copiano dati del database (la cartella di
/// Drive per il giro ad app chiusa) le riscrive ogni contenitore nuovo, anche
/// con il primo avvio a schermo: dopo il passaggio a un altro slot non deve
/// restare la cartella dell'account di prima (F9.5).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/folder_sync.dart';
import 'package:kagami/src/data/library_location.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/app_shell.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temp;
  late KagamiDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('kagami-shell-notes');
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  testWidgets('con il primo avvio a schermo la cartella di Drive della nota diventa null', (tester) async {
    final support = '${temp.path}/support';
    final files = SyncFiles(support);
    // La nota scritta dal contenitore dell'account di prima.
    await tester.runAsync(() => files.writeSettings(const SyncSettings(folderId: 'cartella-di-a')));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appDirectoriesProvider.overrideWithValue(
          AppDirectories(support: support, cache: '${temp.path}/cache'),
        ),
      ],
      child: MaterialApp(
        theme: kagamiTheme(Brightness.dark),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppShell(),
      ),
    ));
    // Fino a quando la nota cambia, con un tetto: il caricamento passa da
    // file e database veri, che sotto carico arrivano quando vogliono.
    SyncSettings? settings;
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
      settings = await tester.runAsync(files.readSettings);
      if (settings?.folderId == null) break;
    }
    expect(settings!.folderId, isNull);
  });
}
