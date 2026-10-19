import 'package:flutter/foundation.dart';

/// A file attached to a support message, as `magic-starter-laravel` serialises
/// it.
@immutable
class MagicStarterSupportAttachment {
  /// Backend key. Untyped for the same reason as [MagicStarterSupportMessage.id].
  final dynamic id;

  final String name;

  final String mime;

  /// Size in bytes after the backend re-encoded it.
  final int size;

  /// Pixel dimensions of an image. Null for a PDF.
  final int? width;
  final int? height;

  /// `image` or `pdf`. Wire string, for the same reason as
  /// [MagicStarterSupportMessage.senderType].
  final String kind;

  /// Where the bytes are read, relative to the API base
  /// (`support/conversations/{c}/attachments/{a}`). The read needs the bearer
  /// token, so it is fetched with `MagicStarterSupportController.attachmentHeaders`
  /// and never opened as a bare link.
  final String url;

  const MagicStarterSupportAttachment({
    required this.id,
    required this.name,
    required this.mime,
    required this.size,
    required this.kind,
    required this.url,
    this.width,
    this.height,
  });

  factory MagicStarterSupportAttachment.fromMap(Map<String, dynamic> map) {
    return MagicStarterSupportAttachment(
      id: map['id'],
      name: map['name'] as String,
      mime: map['mime'] as String,
      size: (map['size'] as num).toInt(),
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      kind: map['kind'] as String,
      url: map['url'] as String,
    );
  }
}

/// A knowledge-base article offered to the customer, as `magic-starter-laravel`
/// serialises it: a suggestion while writing, or a card under an AI answer.
@immutable
class MagicStarterSupportArticle {
  final String slug;

  final String question;

  /// Plain-text excerpt of the answer. Only the suggestion lookup sends it; the
  /// cards under an AI answer carry none.
  final String? excerpt;

  /// The public page the article is read on. Null when the host has configured
  /// no public page, in which case there is nothing to open.
  final String? url;

  const MagicStarterSupportArticle({
    required this.slug,
    required this.question,
    this.excerpt,
    this.url,
  });

  factory MagicStarterSupportArticle.fromMap(Map<String, dynamic> map) {
    return MagicStarterSupportArticle(
      slug: map['slug'] as String,
      question: map['question'] as String,
      excerpt: map['excerpt'] as String?,
      url: map['url'] as String?,
    );
  }
}

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

  /// What the sender attached. Empty on the public signed-link thread and on a
  /// message with no files.
  final List<MagicStarterSupportAttachment> attachments;

  /// The knowledge-base cards the backend stored with an AI answer. Empty for
  /// every other sender, which the backend never sends them for.
  final List<MagicStarterSupportArticle> articles;

  const MagicStarterSupportMessage({
    required this.id,
    required this.senderType,
    required this.body,
    required this.createdAt,
    this.kind = 'message',
    this.senderName,
    this.senderAvatarUrl,
    this.attachments = const <MagicStarterSupportAttachment>[],
    this.articles = const <MagicStarterSupportArticle>[],
  });

  factory MagicStarterSupportMessage.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'] as Map<String, dynamic>?;
    final attachments = map['attachments'] as List<dynamic>?;
    final articles = map['articles'] as List<dynamic>?;

    return MagicStarterSupportMessage(
      id: map['id'],
      senderType: map['sender_type'] as String,
      kind: map['kind'] as String? ?? 'message',
      senderName: sender?['name'] as String?,
      senderAvatarUrl: sender?['avatar_url'] as String?,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      attachments: [
        for (final attachment in attachments ?? const <dynamic>[])
          MagicStarterSupportAttachment.fromMap(
            attachment as Map<String, dynamic>,
          ),
      ],
      articles: [
        for (final article in articles ?? const <dynamic>[])
          MagicStarterSupportArticle.fromMap(article as Map<String, dynamic>),
      ],
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

/// The customer's rating of a resolved conversation.
@immutable
class MagicStarterSupportRating {
  /// `up` or `down`. Wire string, for the same reason as
  /// [MagicStarterSupportMessage.senderType].
  final String value;

  final String? comment;

  final DateTime ratedAt;

  const MagicStarterSupportRating({
    required this.value,
    required this.ratedAt,
    this.comment,
  });

  factory MagicStarterSupportRating.fromMap(Map<String, dynamic> map) {
    return MagicStarterSupportRating(
      value: map['value'] as String,
      comment: map['comment'] as String?,
      ratedAt: DateTime.parse(map['rated_at'] as String),
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

  /// How the customer rated the current resolution. Null while unrated.
  final MagicStarterSupportRating? rating;

  /// Whether the conversation is resolved and not yet rated for its current
  /// resolution, so the thumbs prompt applies.
  final bool canRate;

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
    this.rating,
    this.canRate = false,
  });

  factory MagicStarterSupportConversation.fromMap(Map<String, dynamic> map) {
    final lastActivityAt = map['last_activity_at'] as String?;
    final lastMessage = map['last_message'] as Map<String, dynamic>?;
    final messages = map['messages'] as List<dynamic>?;
    final rating = map['rating'] as Map<String, dynamic>?;

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
      rating: rating == null ? null : MagicStarterSupportRating.fromMap(rating),
      canRate: map['can_rate'] == true,
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
      rating: rating,
      canRate: canRate,
    );
  }

  /// This conversation with [rating] recorded, for a rating the backend has
  /// just accepted. A rated resolution cannot be rated again, so [canRate]
  /// closes.
  MagicStarterSupportConversation withRating(MagicStarterSupportRating rating) {
    return MagicStarterSupportConversation(
      id: id,
      number: number,
      subject: subject,
      source: source,
      status: status,
      priority: priority,
      lastActivityAt: lastActivityAt,
      hasUnread: hasUnread,
      createdAt: createdAt,
      topic: topic,
      awaitingAi: awaitingAi,
      waitingOnTeam: waitingOnTeam,
      lastMessage: lastMessage,
      messages: messages,
      rating: rating,
      canRate: false,
    );
  }
}
