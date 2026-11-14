import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('La configurazione di chi compila', () {
    test('una build senza BACKEND_URL non ha account', () async {
      expect(BackendConfig.environment.isConfigured, isFalse);
      expect(await openBackend(), isNull);
      expect(backend, isNull);
    });

    test('servono un indirizzo vero e la chiave, tutti e due', () {
      bool configured(String url, String key) =>
          BackendConfig(url: url, anonKey: key).isConfigured;
      expect(configured('https://backend.example.com', ''), isFalse);
      expect(configured('', 'chiave'), isFalse);
      expect(configured('backend.example.com', 'chiave'), isFalse);
      expect(configured('https://backend.example.com', 'chiave'), isTrue);
      // Un backend in locale, per chi sviluppa.
      expect(configured('http://127.0.0.1:54321', 'chiave'), isTrue);
    });

    test('con indirizzo e chiave il client nasce, senza rete e senza sessione',
        () async {
      SharedPreferences.setMockInitialValues({});
      final client = await openBackend(const BackendConfig(
        url: 'https://backend.example.com',
        anonKey: 'chiave',
      ));
      addTearDown(Supabase.instance.dispose);
      expect(client, isNotNull);
      expect(backend, same(client));
      expect(client!.auth.currentSession, isNull);
      expect(client.rest.url, startsWith('https://backend.example.com/'));
    });
  });

  group('Un errore del backend non è mai «vuoto»', () {
    test('senza rete: non si è potuto chiedere', () {
      expect(backendFailure(const SocketException('giù')), BackendFailure.offline);
      expect(backendFailure(TimeoutException('lento')), BackendFailure.offline);
      expect(backendFailure(AuthRetryableFetchException()),
          BackendFailure.offline);
    });

    test('tabella assente o non concessa: la funzione non è disponibile', () {
      for (final code in ['PGRST205', '42P01', '42501']) {
        expect(
          backendFailure(PostgrestException(message: 'no', code: code)),
          BackendFailure.unavailable,
          reason: code,
        );
      }
    });

    test('sessione scaduta: serve rifare l\'accesso', () {
      expect(backendFailure(AuthSessionMissingException()),
          BackendFailure.signedOut);
      expect(
        backendFailure(const PostgrestException(message: 'no', code: 'PGRST301')),
        BackendFailure.signedOut,
      );
    });

    test('il resto resta un errore', () {
      expect(
        backendFailure(const PostgrestException(message: 'no', code: '23505')),
        BackendFailure.other,
      );
      expect(backendFailure(StateError('altro')), BackendFailure.other);
    });
  });

  group('Lo schema nel repo', () {
    final migrations = Directory('backend/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('le migrazioni sono numerate di seguito, da 0001', () {
      final names = [
        for (final file in migrations) file.uri.pathSegments.last,
      ];
      expect(names, isNotEmpty);
      for (var i = 0; i < names.length; i++) {
        expect(names[i], startsWith('${'${i + 1}'.padLeft(4, '0')}_'));
      }
    });

    test('schema.sql è le migrazioni una dopo l\'altra', () {
      final schema = File('backend/schema.sql').readAsStringSync();
      final body = [
        for (final file in migrations) file.readAsStringSync(),
      ].join('\n');
      expect(schema, endsWith('\n\n$body'));
    });
  });
}
