import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/magic_starter.dart';

Map<String, dynamic> conversationMap({Map<String, dynamic>? extra}) {
  return <String, dynamic>{
    'id': 7,
    'number': 107,
    'subject': 'Cannot add a monitor',
    'source': 'in_app',
    'status': 'open',
    'priority': 'normal',
    'last_activity_at': '2026-10-12T09:30:00+00:00',
    'created_at': '2026-10-12T09:00:00+00:00',
    'has_unread': false,
    ...?extra,
  };
}

Map<String, dynamic> messageMap({Map<String, dynamic>? extra}) {
  return <String, dynamic>{
    'id': 1,
    'sender_type': 'customer',
    'kind': 'message',
    'sender': null,
    'body': 'Hello',
    'created_at': '2026-10-12T09:00:00+00:00',
    ...?extra,
  };
}

void main() {
  group('MagicStarterSupportConversation.fromMap', () {
    test('decodes the AI flags and the topic', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'topic': 'billing',
            'awaiting_ai': true,
            'waiting_on_team': false,
          },
        ),
      );

      expect(conversation.topic, 'billing');
      expect(conversation.awaitingAi, isTrue);
      expect(conversation.waitingOnTeam, isFalse);
    });

    test('decodes a list row last_message', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'last_message': <String, dynamic>{
              'sender_type': 'ai',
              'sender_name': 'Uptizm Assistant',
              'body_preview': 'Your plan allows 10 monitors.',
              'created_at': '2026-10-12T09:29:00+00:00',
            },
          },
        ),
      );

      final last = conversation.lastMessage!;
      expect(last.senderType, 'ai');
      expect(last.senderName, 'Uptizm Assistant');
      expect(last.bodyPreview, 'Your plan allows 10 monitors.');
      expect(last.createdAt, DateTime.utc(2026, 10, 12, 9, 29));
    });

    test('tolerates a null last_message and a null sender_name', () {
      final empty = MagicStarterSupportConversation.fromMap(
        conversationMap(extra: <String, dynamic>{'last_message': null}),
      );
      expect(empty.lastMessage, isNull);

      final anonymous = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'last_message': <String, dynamic>{
              'sender_type': 'customer',
              'sender_name': null,
              'body_preview': 'Hi',
              'created_at': '2026-10-12T09:29:00+00:00',
            },
          },
        ),
      );
      expect(anonymous.lastMessage!.senderName, isNull);
    });

    test('defaults the new fields when an older backend omits them', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(),
      );

      expect(conversation.topic, isNull);
      expect(conversation.awaitingAi, isFalse);
      expect(conversation.waitingOnTeam, isFalse);
      expect(conversation.lastMessage, isNull);
    });

    test('keeps an unknown status and ignores an unknown field', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'status': 'escalated',
            'something_new': <String, dynamic>{'a': 1},
          },
        ),
      );

      expect(conversation.status, 'escalated');
    });

    test('withMessage keeps the new fields', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'topic': 'sales',
            'awaiting_ai': true,
            'waiting_on_team': true,
          },
        ),
      );

      final next = conversation.withMessage(
        MagicStarterSupportMessage.fromMap(messageMap()),
      );

      expect(next.topic, 'sales');
      expect(next.awaitingAi, isTrue);
      expect(next.waitingOnTeam, isTrue);
      expect(next.messages, hasLength(1));
    });
  });

  group('MagicStarterSupportMessage.fromMap', () {
    test('decodes a staff message with its sender identity', () {
      final message = MagicStarterSupportMessage.fromMap(
        messageMap(
          extra: <String, dynamic>{
            'sender_type': 'staff',
            'sender': <String, dynamic>{
              'name': 'Ayse',
              'avatar_url': 'https://cdn.example.com/a.png',
            },
            'body': 'On it',
          },
        ),
      );

      expect(message.senderType, 'staff');
      expect(message.kind, 'message');
      expect(message.senderName, 'Ayse');
      expect(message.senderAvatarUrl, 'https://cdn.example.com/a.png');
      expect(message.body, 'On it');
    });

    test('a customer message has a null sender', () {
      final message = MagicStarterSupportMessage.fromMap(messageMap());

      expect(message.senderName, isNull);
      expect(message.senderAvatarUrl, isNull);
    });

    test('decodes an activity line', () {
      final message = MagicStarterSupportMessage.fromMap(
        messageMap(
          extra: <String, dynamic>{
            'sender_type': 'system',
            'kind': 'activity',
            'body': 'Handed off to the team',
          },
        ),
      );

      expect(message.senderType, 'system');
      expect(message.kind, 'activity');
    });

    test('defaults kind to message and tolerates a nameless sender', () {
      final message = MagicStarterSupportMessage.fromMap(<String, dynamic>{
        'id': 3,
        'sender_type': 'robot',
        'sender': <String, dynamic>{'name': null, 'avatar_url': null},
        'body': 'Beep',
        'created_at': '2026-10-12T09:00:00+00:00',
      });

      expect(message.kind, 'message');
      expect(message.senderType, 'robot');
      expect(message.senderName, isNull);
    });
  });
}
