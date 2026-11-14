/// Gli accessi al server che scadono: il foglio «Chi può usarlo» offre la
/// durata solo se il server la conosce, dice quando scade ogni account e
/// rinnova chiamando il server.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/l10n/app_localizations.dart';
import 'package:kagami/src/providers.dart';
import 'package:kagami/src/ui/archive_server.dart';
import 'package:kagami/src/ui/theme.dart';
import 'package:kagami/src/ui/widgets/kit.dart';
import 'package:kagami_archive/remote.dart';

class _Fake extends RemoteArchiveController {
  _Fake(this.view, this.calls);

  final RemoteArchiveView view;
  final List<String> calls;

  @override
  RemoteArchiveView build() => view;

  @override
  Future<void> renewUser(ServerUser user, DateTime? expiresAt) async {
    calls.add('renew ${user.email} ${expiresAt != null}');
  }

  @override
  Future<void> addUser(String email, {DateTime? expiresAt}) async {
    calls.add('add $email ${expiresAt != null}');
  }
}

RemoteArchiveView _view({required bool expiry}) => RemoteArchiveView(
      info: ServerInfo(
        name: 'S',
        version: '1',
        api: 2,
        providers: const [],
        email: 'io@example.com',
        driveAuthorized: true,
        isOwner: true,
        features: {if (expiry) 'expiry'},
      ),
      users: [
        const ServerUser(email: 'io@example.com', owner: true),
        ServerUser(email: 'amico@example.com', connected: true, expiresAt: DateTime(2026, 12, 13)),
        const ServerUser(email: 'vecchio@example.com', expired: true),
      ],
    );

Future<void> _open(WidgetTester tester, RemoteArchiveView view, List<String> calls) async {
  await tester.binding.setSurfaceSize(const Size(500, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [remoteArchiveProvider.overrideWith(() => _Fake(view, calls))],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      theme: kagamiTheme(Brightness.dark),
      home: const Scaffold(body: SingleChildScrollView(child: ServerUsersSheet())),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('senza `expiry` niente selettore, niente scadenze, niente rinnovo', (tester) async {
    await _open(tester, _view(expiry: false), []);
    expect(find.byType(AccessDurationPicker), findsNothing);
    expect(find.textContaining('Scade il'), findsNothing);
    expect(find.text('Rinnova'), findsNothing);
  });

  testWidgets('con `expiry`: selettore, «Scade il», «Scaduto» e rinnovo', (tester) async {
    final calls = <String>[];
    await _open(tester, _view(expiry: true), calls);
    expect(find.byType(AccessDurationPicker), findsOneWidget);
    expect(find.textContaining('Scade il'), findsOneWidget);
    expect(find.textContaining('Scaduto'), findsOneWidget);

    await tester.tap(find.text('Rinnova').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Un anno').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(KButton));
    await tester.pumpAndSettle();
    expect(calls, ['renew amico@example.com true']);
  });

  testWidgets('aggiungere passa la scadenza scelta; «senza scadenza» la toglie', (tester) async {
    final calls = <String>[];
    await _open(tester, _view(expiry: true), calls);
    await tester.enterText(find.byType(TextField), 'nuovo@example.com');
    await tester.tap(find.byTooltip('Aggiungi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Senza scadenza'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'altro@example.com');
    await tester.tap(find.byTooltip('Aggiungi'));
    await tester.pumpAndSettle();
    expect(calls, ['add nuovo@example.com true', 'add altro@example.com false']);
  });

  test('AccessDuration: un mese proposto, never senza data', () {
    final now = DateTime(2026, 1, 1);
    expect(AccessDuration.proposed, AccessDuration.month);
    expect(AccessDuration.week.expiresAt(now), DateTime(2026, 1, 8));
    expect(AccessDuration.never.expiresAt(now), isNull);
  });
}
