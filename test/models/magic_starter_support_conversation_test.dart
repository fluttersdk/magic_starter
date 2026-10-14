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

Map<String, dynamic> attachmentMap({Map<String, dynamic>? extra}) {
  return <String, dynamic>{
    'id': 'a1',
    'name': 'error.png',
    'mime': 'image/png',
    'size': 20480,
    'width': 640,
    'height': 480,
    'kind': 'image',
    'url': 'support/conversations/7/attachments/a1',
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

    test('decodes the rating and can_rate of a resolved conversation', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'status': 'resolved',
            'can_rate': false,
            'rating': <String, dynamic>{
              'value': 'down',
              'comment': 'Still broken',
              'rated_at': '2026-10-12T10:00:00+00:00',
            },
          },
        ),
      );

      expect(conversation.canRate, isFalse);
      expect(conversation.rating!.value, 'down');
      expect(conversation.rating!.comment, 'Still broken');
      expect(conversation.rating!.ratedAt, DateTime.utc(2026, 10, 12, 10));
    });

    test('an unrated resolved conversation can be rated', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'status': 'resolved',
            'can_rate': true,
            'rating': null,
          },
        ),
      );

      expect(conversation.canRate, isTrue);
      expect(conversation.rating, isNull);
    });

    test('a rating without a comment reads a null comment', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'rating': <String, dynamic>{
              'value': 'up',
              'comment': null,
              'rated_at': '2026-10-12T10:00:00+00:00',
            },
          },
        ),
      );

      expect(conversation.rating!.value, 'up');
      expect(conversation.rating!.comment, isNull);
    });

    test('an older backend that omits rating and can_rate reads unrated', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(),
      );

      expect(conversation.rating, isNull);
      expect(conversation.canRate, isFalse);
    });

    test('withMessage keeps the rating fields', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(
          extra: <String, dynamic>{
            'can_rate': true,
            'rating': <String, dynamic>{
              'value': 'up',
              'comment': null,
              'rated_at': '2026-10-12T10:00:00+00:00',
            },
          },
        ),
      );

      final next = conversation.withMessage(
        MagicStarterSupportMessage.fromMap(messageMap()),
      );

      expect(next.canRate, isTrue);
      expect(next.rating!.value, 'up');
    });

    test('withRating records the rating and closes the rating prompt', () {
      final conversation = MagicStarterSupportConversation.fromMap(
        conversationMap(extra: <String, dynamic>{'can_rate': true}),
      );

      final rated = conversation.withRating(
        MagicStarterSupportRating(
          value: 'down',
          comment: 'Slow',
          ratedAt: DateTime.utc(2026, 10, 12, 11),
        ),
      );

      expect(rated.rating!.value, 'down');
      expect(rated.canRate, isFalse);
      expect(rated.id, conversation.id);
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

    test('decodes an attachment payload', () {
      final message = MagicStarterSupportMessage.fromMap(
        messageMap(
          extra: <String, dynamic>{
            'attachments': <Map<String, dynamic>>[
              attachmentMap(),
              attachmentMap(
                extra: <String, dynamic>{
                  'id': 'a2',
                  'name': 'invoice.pdf',
                  'mime': 'application/pdf',
                  'size': 90210,
                  'width': null,
                  'height': null,
                  'kind': 'pdf',
                  'url': 'support/conversations/7/attachments/a2',
                },
              ),
            ],
          },
        ),
      );

      expect(message.attachments, hasLength(2));

      final image = message.attachments.first;
      expect(image.id, 'a1');
      expect(image.name, 'error.png');
      expect(image.mime, 'image/png');
      expect(image.size, 20480);
      expect(image.width, 640);
      expect(image.height, 480);
      expect(image.kind, 'image');
      expect(image.url, 'support/conversations/7/attachments/a1');

      final pdf = message.attachments.last;
      expect(pdf.width, isNull);
      expect(pdf.height, isNull);
      expect(pdf.kind, 'pdf');
    });

    test('a message without attachments reads an empty list', () {
      expect(
        MagicStarterSupportMessage.fromMap(messageMap()).attachments,
        isEmpty,
      );
      expect(
        MagicStarterSupportMessage.fromMap(
          messageMap(extra: <String, dynamic>{'attachments': null}),
        ).attachments,
        isEmpty,
      );
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
