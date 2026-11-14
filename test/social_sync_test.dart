/// Quando il profilo esce e come il client del backend legge i rifiuti:
/// `docs/social.md`, «La radio resta spenta» e «Errori».
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/social/backend.dart';
import 'package:kagami/src/data/social/hestia_social.dart';
import 'package:kagami/src/data/social/memory_social.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/social/sync.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const on = SocialSettings(enabled: true, name: 'Alice', showSeries: true);
  final now = DateTime(2026, 11, 14);

  PublicProfile build(String uid, {int chapters = 10, Set<String> hidden = const {}}) => buildPublicProfile(
        uid: uid,
        settings: on,
        statistics: ReadingStatistics(
          chaptersRead: chapters,
          pagesRead: 0,
          timeRead: Duration.zero,
          perDay: const {},
          perMonth: const {},
          topSeries: const [],
          firstRead: null,
          excluding: hidden,
        ),
        series: const [
          ProfileSeries(key: 'alfa', title: 'Alfa', genres: ['Azione'], read: 8),
          ProfileSeries(key: 'segreta', title: 'Segreta', genres: ['Orrore'], read: 30),
        ],
        hidden: hidden,
        now: now,
      );

  group('SocialSync', () {
    late MemorySocial network;
    String? published;
    late SocialSync sync;

    setUp(() {
      network = MemorySocial('alice');
      published = null;
      sync = SocialSync(
        backend: network,
        readPublished: () async => published,
        writePublished: (value) async => published = value,
      );
    });

    test('pubblica solo se il profilo è cambiato, o a richiesta', () async {
      expect(await sync.publish(on, () async => build('alice')), SocialPublish.published);
      expect(published, build('alice').fingerprint);
      expect(await sync.publish(on, () async => build('alice')), SocialPublish.unchanged);
      expect(network.calls, ['alice publish']);
      expect(await sync.publish(on, () async => build('alice', chapters: 11)), SocialPublish.published);
      expect(network.profiles['alice']!.chapters, 11);
      expect(await sync.publish(on, () async => build('alice', chapters: 11), force: true), SocialPublish.published);
      expect(network.calls, hasLength(3));
    });

    test('spento: nessuna chiamata, e il profilo non si costruisce', () async {
      var built = 0;
      final result = await sync.publish(const SocialSettings(name: 'Alice'), () async {
        built++;
        return build('alice');
      });
      expect(result, SocialPublish.disabled);
      expect(built, 0);
      expect(network.calls, isEmpty);
      expect(published, isNull);
      expect(await sync.publish(const SocialSettings(enabled: true, name: 'A'), () async => build('alice')),
          SocialPublish.incomplete);
      expect(network.calls, isEmpty);
    });

    test('una pubblicazione fallita non aggiorna l\'impronta', () async {
      network.failure = const SocialRefused();
      await expectLater(sync.publish(on, () async => build('alice')), throwsA(isA<SocialRefused>()));
      expect(published, isNull);
    });

    test('le serie nascoste non sono mai nel profilo pubblicato', () async {
      await sync.publish(on, () async => build('alice', hidden: {'segreta'}));
      final row = jsonEncode(network.profiles['alice']!.toRow());
      expect(row, isNot(contains('Segreta')));
      expect(row, isNot(contains('Orrore')));
      expect(network.profiles['alice']!.series, [('Alfa', 8)]);
      expect(network.profiles['alice']!.seriesCount, 1);
      // Statistiche chieste senza escludere le nascoste: non esce niente.
      await expectLater(sync.publish(on, () async => buildPublicProfile(
            uid: 'alice',
            settings: on,
            statistics: ReadingStatistics.empty,
            series: const [],
            hidden: {'segreta'},
            now: now,
          )), throwsStateError);
      expect(network.calls, hasLength(1));
    });

    test('uscire cancella profilo e legami, lascia i blocchi e dimentica l\'impronta', () async {
      final bob = network.as('bob');
      await sync.publish(on, () async => build('alice'));
      await bob.publish(build('bob'));
      await network.follow('bob', name: 'Alice');
      await bob.follow('alice', name: 'Bob');
      await network.block('dario');

      await sync.leave();
      expect(network.profiles.containsKey('alice'), isFalse);
      expect(await bob.profile('alice'), isNull);
      expect((await bob.graph()).followers, isEmpty);
      expect((await bob.graph()).following, isEmpty);
      expect(network.blocks['alice'], {'dario'});
      expect(published, isNull);
      expect(await sync.publish(on, () async => build('alice')), SocialPublish.published);
      expect(await network.blocked(), {'dario'});
    });

    test('in memoria valgono pubblico e blocco', () async {
      final bob = network.as('bob');
      final carla = network.as('carla');
      await network.publish(build('alice'));
      await bob.publish(PublicProfile(id: 'bob', name: 'Bob', audience: SocialAudience.mutual));
      await carla.publish(build('carla'));
      expect(await network.profile('bob'), isNull);
      await bob.follow('alice', name: 'Bob');
      expect(await network.profile('bob'), isNull);
      await network.follow('bob', name: 'Alice');
      expect((await network.profile('bob'))?.name, 'Bob');
      await bob.block('alice');
      expect(await network.profile('bob'), isNull);
      expect(await bob.profile('alice'), isNull);
      expect((await network.graph()).following, isEmpty);
      await expectLater(network.follow('bob', name: 'Alice'), throwsA(isA<SocialRefused>()));
      expect([for (final p in await carla.board(Board.allTime)) p.id], unorderedEquals(['alice', 'carla']));
    });
  });

  group('HestiaSocial contro un PostgREST finto', () {
    late HttpServer server;
    late SupabaseClient client;
    late List<HttpRequest> requests;
    late List<Object?> bodies;
    var status = 200;
    Object reply = <Object?>[];

    setUp(() async {
      requests = [];
      bodies = [];
      status = 200;
      reply = <Object?>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add(request);
        final text = await utf8.decodeStream(request);
        bodies.add(text.isEmpty ? null : jsonDecode(text));
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(reply));
        await request.response.close();
      });
      client = SupabaseClient(
        'http://${server.address.host}:${server.port}',
        'chiave',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final exp = DateTime.now().add(const Duration(hours: 1));
      await client.auth.recoverSession(jsonEncode({
        'access_token': [
          part({'alg': 'HS256', 'typ': 'JWT'}),
          part({'sub': 'u1', 'exp': exp.millisecondsSinceEpoch ~/ 1000}),
          'firma',
        ].join('.'),
        'token_type': 'bearer',
        'refresh_token': 'r',
        'user': {
          'id': 'u1',
          'aud': 'authenticated',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
          'created_at': '2026-11-13T00:00:00Z',
        },
      }));
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    Map<String, Object?> denied(String code) => {'code': code, 'message': 'no', 'details': null, 'hint': null};

    test('42501 su una lettura: il social non c\'è', () async {
      final social = HestiaSocial(client: client);
      status = 403;
      reply = denied('42501');
      await expectLater(social.profile('u2'), throwsA(isA<SocialUnavailable>()));
      await expectLater(social.board(Board.week), throwsA(isA<SocialUnavailable>()));
      status = 404;
      reply = denied('PGRST205');
      await expectLater(social.graph(), throwsA(isA<SocialUnavailable>()));
    });

    test('42501 su una scrittura: rifiutata dalle regole', () async {
      final social = HestiaSocial(client: client);
      status = 403;
      reply = denied('42501');
      await expectLater(social.publish(build('u1')), throwsA(isA<SocialRefused>()));
      await expectLater(social.follow('u2', name: 'Alice'), throwsA(isA<SocialRefused>()));
      await expectLater(social.block('u2'), throwsA(isA<SocialRefused>()));
      status = 404;
      reply = denied('PGRST205');
      await expectLater(social.publish(build('u1')), throwsA(isA<SocialUnavailable>()));
    });

    test('pubblica la riga del profilo con upsert, esce togliendo la propria', () async {
      final social = HestiaSocial(client: client);
      status = 201;
      await social.publish(build('u1'));
      expect(requests.last.method, 'POST');
      expect(requests.last.uri.path, '/rest/v1/profiles');
      expect(requests.last.headers.value('prefer'), contains('merge-duplicates'));
      expect(bodies.last, jsonDecode(jsonEncode(build('u1').toRow())));
      expect(jsonEncode(bodies.last), isNot(contains('updated_at')));
      status = 204;
      await social.withdraw();
      expect(requests.last.method, 'DELETE');
      expect(requests.last.uri.queryParameters['id'], 'eq.u1');
    });

    test('la classifica della settimana chiede la settimana di adesso', () async {
      final social = HestiaSocial(client: client, clock: () => now);
      reply = [build('u2').toRow()];
      final rows = await social.board(Board.week, limit: 5);
      expect(rows.single.id, 'u2');
      final query = requests.last.uri.queryParameters;
      expect(query['week_id'], 'eq.${weekId(now)}');
      expect(query['order'], startsWith('week_chapters.desc'));
      expect(query['limit'], '5');
    });

    test('nessuna persona chiesta: nessuna richiesta', () async {
      expect(await HestiaSocial(client: client).people(const []), isEmpty);
      expect(requests, isEmpty);
    });
  });
}
