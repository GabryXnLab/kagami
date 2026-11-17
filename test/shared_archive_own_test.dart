/// «Archivia nel mio Drive» (FASE-5b §3, F5.15): offerto solo per una serie che
/// viene soltanto da librerie Drive condivise; spento col motivo se il sito
/// non è installato; assente se la serie è anche nel mio Drive.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/data/drive.dart' show DriveFileCache;
import 'package:kagami/src/data/drive_library.dart';
import 'package:kagami/src/data/library.dart';
import 'package:kagami/src/data/sources/path_shelf.dart';
import 'package:kagami/src/ui/series_archive_own.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami/src/ui/widgets/kit.dart';

import 'drive_library_test.dart' show FakeClient;
import 'path_shelf_test.dart' show FakeTransport;

const _link = 'https://mangak.example/series/S1';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('kagami-own'));
  tearDown(() => temp.deleteSync(recursive: true));

  DriveRepository drive(LibraryOrigin origin) => DriveRepository(
        client: FakeClient(),
        folderId: 'R',
        stateDirectory: '${temp.path}/state',
        files: DriveFileCache(Directory('${temp.path}/cache'), limitBytes: 1 << 20),
        sourceId: origin == LibraryOrigin.drive ? 'drive' : 's-0000abcd',
        origin: origin,
      );

  group('archiveOwnOffer', () {
    test('solo da condivisioni: pronto col sito installato, spento senza', () {
      final shared = [drive(LibraryOrigin.remote), drive(LibraryOrigin.remote)];
      expect(archiveOwnOffer(shared, _link, (_) => true), ArchiveOwnOffer.ready);
      expect(archiveOwnOffer(shared, _link, (_) => false), ArchiveOwnOffer.siteMissing);
    });

    test('anche nel mio Drive, sul telefono o su un NAS: nessun pulsante', () {
      final nas = PathShelf(transport: FakeTransport(), sourceId: 's-0a0b0c0d', stateDirectory: '${temp.path}/nas');
      expect(archiveOwnOffer([drive(LibraryOrigin.remote), drive(LibraryOrigin.drive)], _link, (_) => true),
          ArchiveOwnOffer.none);
      expect(archiveOwnOffer([drive(LibraryOrigin.remote), nas], _link, (_) => true), ArchiveOwnOffer.none);
      expect(archiveOwnOffer(const [], _link, (_) => true), ArchiveOwnOffer.none);
    });

    test('senza link nell\'indice non si offre', () {
      expect(archiveOwnOffer([drive(LibraryOrigin.remote)], null, (_) => true), ArchiveOwnOffer.none);
    });
  });

  group('ArchiveOwnChip', () {
    Future<void> show(WidgetTester tester, ArchiveOwnOffer offer, VoidCallback onArchive) =>
        tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          theme: kagamiTheme(Brightness.dark),
          home: Scaffold(body: ArchiveOwnChip(offer: offer, busy: false, onArchive: onArchive)),
        ));

    testWidgets('pronto: il tocco avvia l\'archiviazione', (tester) async {
      var taps = 0;
      await show(tester, ArchiveOwnOffer.ready, () => taps++);
      await tester.tap(find.text('Archivia nel mio Drive'));
      expect(taps, 1);
    });

    testWidgets('sito non installato: spento, col motivo', (tester) async {
      var taps = 0;
      await show(tester, ArchiveOwnOffer.siteMissing, () => taps++);
      await tester.tap(find.text('Archivia nel mio Drive'), warnIfMissed: false);
      expect(taps, 0);
      expect(find.textContaining('Serve il sito di questa serie'), findsOneWidget);
    });

    testWidgets('nessuna offerta: niente pulsante', (tester) async {
      await show(tester, ArchiveOwnOffer.none, () {});
      expect(find.byType(KChip), findsNothing);
    });
  });
}
