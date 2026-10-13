import 'package:flutter/foundation.dart';

/// One message in a support conversation, as `magic-starter-laravel` serialises
/// it.
@immutable
class MagicStarterSupportMessage {
  /// Backend key. Untyped because the backend switches between integer and
  /// UUID keys per `use_uuids`.
  final dynamic id;

  /// Who wrote it: `customer`, `staff`, `ai` or `system`. Kept as the wire
  /// string so a value a newer backend adds still renders instead of being
  /// dropped.
  final String senderType;

  /// `message` for something a sender wrote, `activity` for a line the desk
  /// recorded (a handoff, a status change). Wire string, for the same reason as
  /// [senderType]; an older backend that sends no kind reads as `message`.
  final String kind;

  /// The author's display name. Null for a customer or system line, and for a
  /// staff member the backend chose not to name.
  final String? senderName;

  final String? senderAvatarUrl;

  final String body;

  final DateTime createdAt;

  const MagicStarterSupportMessage({
    required this.id,
    required this.senderType,
    required this.body,
    required this.createdAt,
    this.kind = 'message',
    this.senderName,
    this.senderAvatarUrl,
  });

  factory MagicStarterSupportMessage.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'] as Map<String, dynamic>?;

    return MagicStarterSupportMessage(
      id: map['id'],
      senderType: map['sender_type'] as String,
      kind: map['kind'] as String? ?? 'message',
      senderName: sender?['name'] as String?,
      senderAvatarUrl: sender?['avatar_url'] as String?,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// The newest customer-visible message of a listed conversation, as the index
/// serialises it for the row preview.
@immutable
class MagicStarterSupportLastMessage {
  /// Wire string, for the same reason as [MagicStarterSupportMessage.senderType].
  final String senderType;

  final String? senderName;

  /// The body, already shortened by the backend.
  final String bodyPreview;

  final DateTime createdAt;

  const MagicStarterSupportLastMessage({
    required this.senderType,
    required this.senderName,
    required this.bodyPreview,
    required this.createdAt,
  });

  factory MagicStarterSupportLastMessage.fromMap(Map<String, dynamic> map) {
    return MagicStarterSupportLastMessage(
      senderType: map['sender_type'] as String,
      senderName: map['sender_name'] as String?,
      bodyPreview: map['body_preview'] as String,
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

  /// Where the customer opened it from (`in_app`, `contact_sales`, ...).
  /// Stays the wire string for the same reason as
  /// [MagicStarterSupportMessage.senderType].
  final String source;

  final String status;

  final String priority;

  /// Null when the backend has recorded no activity yet.
  final DateTime? lastActivityAt;

  /// Whether staff wrote since the customer last viewed the thread.
  final bool hasUnread;

  final DateTime createdAt;

  /// What the customer said it is about (`billing`, `technical`, ...). Null for
  /// a conversation opened without one. Wire string.
  final String? topic;

  /// Whether the AI has been asked to answer and has not yet replied or handed
  /// off.
  final bool awaitingAi;

  /// Whether the conversation is waiting for a teammate rather than the AI.
  final bool waitingOnTeam;

  /// The newest customer-visible message. Only the list endpoint sends it;
  /// null on a thread read and on a conversation with no visible message.
  final MagicStarterSupportLastMessage? lastMessage;

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
    this.topic,
    this.awaitingAi = false,
    this.waitingOnTeam = false,
    this.lastMessage,
    this.messages = const <MagicStarterSupportMessage>[],
  });

  factory MagicStarterSupportConversation.fromMap(Map<String, dynamic> map) {
    final lastActivityAt = map['last_activity_at'] as String?;
    final lastMessage = map['last_message'] as Map<String, dynamic>?;
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
      topic: map['topic'] as String?,
      awaitingAi: map['awaiting_ai'] == true,
      waitingOnTeam: map['waiting_on_team'] == true,
      lastMessage: lastMessage == null
          ? null
          : MagicStarterSupportLastMessage.fromMap(lastMessage),
      messages: [
        for (final message in messages ?? const <dynamic>[])
          MagicStarterSupportMessage.fromMap(message as Map<String, dynamic>),
      ],
    );
  }

  /// This conversation with [message] appended, for a reply the backend has
  /// just accepted.
  ///
  /// A customer message on a `pending` conversation is one the AI now owes an
  /// answer to, so the copy reads [awaitingAi] true: the answer is queued, not
  /// yet written, and the typing bubble has to show before the next refetch.
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
      topic: topic,
      awaitingAi:
          awaitingAi ||
          (status == 'pending' && message.senderType == 'customer'),
      waitingOnTeam: waitingOnTeam,
      lastMessage: lastMessage,
      messages: [...messages, message],
    );
  }
}
