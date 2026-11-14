import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/social/content.dart';
import 'package:kagami/src/data/social/message_alerts.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/user_repository.dart';

Conversation conversation(String peer, String id, {int unread = 1, String? from, String body = 'ciao'}) => (
      peer: peer,
      card: SocialCard(id: peer, name: 'Nome $peer'),
      last: Message(id: id, from: from ?? peer, to: 'me', body: body, at: DateTime.utc(2026, 11, 14)),
      unread: unread,
    );

void main() {
  late KagamiDatabase db;
  late UserRepository user;
  const on = SocialSettings(enabled: true, messages: MessagePolicy.everyone);

  setUp(() {
    db = KagamiDatabase.forTesting(NativeDatabase.memory());
    user = UserRepository(db);
  });
  tearDown(() => db.close());

  List<MessageAlert> alerts(List<Conversation> c, Map<String, String> seen,
          {SocialSettings settings = on, Set<String> blocked = const {}}) =>
      messageAlerts(conversations: c, seen: seen, settings: settings, blocked: blocked, unknownName: '?');

  Future<List<String>> run(List<Conversation> c, {SocialSettings settings = on, Set<String> blocked = const {}}) async {
    final sent = <String>[];
    await announceMessages(
      user,
      alerts(c, await readMessagesSeen(user), settings: settings, blocked: blocked),
      (a) async => sent.add('${a.peer}:${a.messageId}:${a.preview}'),
    );
    return sent;
  }

  test('un messaggio nuovo si annuncia una volta sola, uno successivo di nuovo', () async {
    expect(await run([conversation('a', 'm1')]), ['a:m1:ciao']);
    expect(await run([conversation('a', 'm1')]), isEmpty);
    expect(await run([conversation('a', 'm2', body: 'altro')]), ['a:m2:altro']);
  });

  test('una notifica per conversazione, solo con non letti e scritti dall\'altro', () async {
    final sent = await run([
      conversation('a', 'm1'),
      conversation('b', 'm2'),
      conversation('c', 'm3', unread: 0),
      conversation('d', 'm4', from: 'me'),
    ]);
    expect(sent, ['a:m1:ciao', 'b:m2:ciao']);
  });

  test('niente con social spento, policy nessuno, mittente bloccato o silenziato', () async {
    final c = [conversation('a', 'm1')];
    expect(await run(c, settings: const SocialSettings(messages: MessagePolicy.everyone)), isEmpty);
    expect(await run(c, settings: on.copyWith(messages: MessagePolicy.nobody)), isEmpty);
    expect(await run(c, blocked: {'a'}), isEmpty);
    expect(await run(c, settings: on.copyWith(muted: {'a'})), isEmpty);
    expect(await run(c), ['a:m1:ciao']);
  });

  test('l\'anteprima è corta e su una riga', () {
    final long = 'x' * 200;
    final preview = alerts([conversation('a', 'm1', body: 'a\n  b $long')], {}).single.preview;
    expect(preview.length, messagePreviewLength);
    expect(preview.startsWith('a b x'), isTrue);
  });
}
