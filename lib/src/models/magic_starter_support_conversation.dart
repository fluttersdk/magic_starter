import 'package:flutter/foundation.dart';

/// One message in a support conversation, as `magic-starter-laravel` serialises
/// it.
@immutable
class MagicStarterSupportMessage {
  /// Backend key. Untyped because the backend switches between integer and
  /// UUID keys per `use_uuids`.
  final dynamic id;

  /// Who wrote it: `customer`, `staff` or `system`. Kept as the wire string so
  /// a value a newer backend adds still renders instead of being dropped.
  final String senderType;

  final String body;

  final DateTime createdAt;

  const MagicStarterSupportMessage({
    required this.id,
    required this.senderType,
    required this.body,
    required this.createdAt,
  });

  factory MagicStarterSupportMessage.fromMap(Map<String, dynamic> map) {
    return MagicStarterSupportMessage(
      id: map['id'],
      senderType: map['sender_type'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// A support conversation the signed-in user opened.
///
/// The list endpoint answers conversations without [messages]; only the show
/// endpoint carries them, so an empty [messages] on a listed row means "not
/// loaded", not "no messages".
@immutable
class MagicStarterSupportConversation {
  /// Backend key. Untyped for the same reason as [MagicStarterSupportMessage.id].
  final dynamic id;

  /// The human-facing display number (`12`, shown as `#12`), never the key.
  final int number;

  final String subject;

  /// Where the customer opened it from (`help_page`, ...). Stays the wire
  /// string for the same reason as [MagicStarterSupportMessage.senderType].
  final String source;

  final String status;

  final String priority;

  /// Null when the backend has recorded no activity yet.
  final DateTime? lastActivityAt;

  /// Whether staff wrote since the customer last viewed the thread.
  final bool hasUnread;

  final DateTime createdAt;

  final List<MagicStarterSupportMessage> messages;

  const MagicStarterSupportConversation({
    required this.id,
    required this.number,
    required this.subject,
    required this.source,
    required this.status,
    required this.priority,
    required this.lastActivityAt,
    required this.hasUnread,
    required this.createdAt,
    this.messages = const <MagicStarterSupportMessage>[],
  });

  factory MagicStarterSupportConversation.fromMap(Map<String, dynamic> map) {
    final lastActivityAt = map['last_activity_at'] as String?;
    final messages = map['messages'] as List<dynamic>?;

    return MagicStarterSupportConversation(
      id: map['id'],
      number: (map['number'] as num).toInt(),
      subject: map['subject'] as String,
      source: map['source'] as String,
      status: map['status'] as String,
      priority: map['priority'] as String,
      lastActivityAt: lastActivityAt == null
          ? null
          : DateTime.parse(lastActivityAt),
      hasUnread: map['has_unread'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      messages: [
        for (final message in messages ?? const <dynamic>[])
          MagicStarterSupportMessage.fromMap(message as Map<String, dynamic>),
      ],
    );
  }

  /// This conversation with [message] appended, for a reply the backend has
  /// just accepted.
  MagicStarterSupportConversation withMessage(
    MagicStarterSupportMessage message,
  ) {
    return MagicStarterSupportConversation(
      id: id,
      number: number,
      subject: subject,
      source: source,
      status: status,
      priority: priority,
      lastActivityAt: message.createdAt,
      hasUnread: hasUnread,
      createdAt: createdAt,
      messages: [...messages, message],
    );
  }
}
