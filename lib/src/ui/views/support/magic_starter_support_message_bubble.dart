import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../models/magic_starter_support_conversation.dart';
import '../../components/avatar/index.dart';
import 'magic_starter_support_article_card.dart';
import 'magic_starter_support_attachments.dart';

/// The face of whoever wrote a support line.
///
/// The assistant is a sparkle on `bg-ai-soft`, a teammate is their photo or
/// their initials, and the customer is their own initials. Shared by the thread
/// bubbles and the list rows so one author never looks like two.
class MagicStarterSupportSenderAvatar extends StatelessWidget {
  const MagicStarterSupportSenderAvatar({
    super.key,
    required this.senderType,
    this.name,
    this.photoUrl,
  });

  /// The wire `sender_type`: `ai`, `staff` or `customer`. Anything else reads as
  /// a teammate.
  final String senderType;

  /// The author's display name, for the initials. Null draws a person glyph.
  final String? name;

  /// A photo for the avatar; the initials stand in when it is absent or fails.
  final String? photoUrl;

  static const _iconAssistant = Icons.auto_awesome;
  static const _iconPerson = Icons.person_outline;

  /// Two letters for [name], upper-cased: the first letters of its first two
  /// words, or the first two letters of a single word. An empty string when
  /// there is no name.
  static String initials(String? name) {
    final List<String> words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';

    final String letters = words.length > 1
        ? '${words[0].characters.first}${words[1].characters.first}'
        : words.first.characters.take(2).toString();

    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool assistant = senderType == 'ai';
    final (String background, String foreground) = switch (senderType) {
      'ai' => ('bg-ai-soft', 'text-ai-soft-foreground'),
      'customer' => ('bg-surface-container-high', 'text-fg'),
      _ => ('bg-primary-container', 'text-fg'),
    };

    return MSAvatar(
      photoUrl: assistant ? null : photoUrl,
      className: 'w-7 h-7 lg:w-8 lg:h-8 rounded-full $background',
      fallback: _fallback(assistant, foreground),
    );
  }

  Widget _fallback(bool assistant, String foreground) {
    if (assistant) {
      return WIcon(_iconAssistant, className: 'text-sm $foreground');
    }

    final String letters = initials(name);
    if (letters.isEmpty) {
      return WIcon(_iconPerson, className: 'text-sm $foreground');
    }

    return WText(letters, className: 'text-xs font-bold $foreground');
  }
}

/// One support message as a chat bubble.
///
/// The customer sits on the right in `bg-primary-container` with the label
/// "You" under the bubble. The assistant and staff sit on the left; their
/// avatar is aligned to the TOP of the bubble and the sender label sits UNDER
/// it: the assistant as a `bg-ai-soft` chip, a teammate as
/// "First name · Support team · time". The assistant's bubble also carries a 2px
/// `border-ai` rule down its left edge.
///
/// Activity lines (a handoff, a status change) are not a person speaking and
/// render through [MagicStarterSupportActivityLine], not here.
///
/// With `support_attachments` on, what the message carried renders inside the
/// bubble, once the thread has handed over [onOpenPdf]; without it the bubble
/// shows the text only. An image-only message has no text line.
///
/// The assistant's knowledge-base articles sit under its bubble as
/// [MagicStarterSupportArticleCard]s; no other sender gets them.
class MagicStarterSupportMessageBubble extends StatelessWidget {
  const MagicStarterSupportMessageBubble(
    this.message, {
    super.key,
    this.attachmentHeaders,
    this.onOpenPdf,
  });

  final MagicStarterSupportMessage message;

  /// The bearer header an image read needs; null while it is still resolving.
  final Map<String, String>? attachmentHeaders;

  /// Opens a PDF through a signed link. Null leaves attachments undrawn.
  final ValueChanged<MagicStarterSupportAttachment>? onOpenPdf;

  static const _iconChip = Icons.auto_awesome;

  /// `09:42`, in the viewer's clock.
  static String clock(DateTime at) => at.toLocal().toCarbon().format('HH:mm');

  @override
  Widget build(BuildContext context) {
    return switch (message.senderType) {
      'customer' => _buildCustomer(),
      'ai' => _buildOther(label: _assistantLabel(), accent: true),
      _ => _buildOther(label: _staffLabel()),
    };
  }

  Widget _buildCustomer() {
    // The 12 on the left is what keeps a phone-width bubble off the far edge,
    // roughly the 85% the design gives it; at lg the bubble's own max width
    // does that job.
    return WDiv(
      className: 'w-full flex flex-col items-end gap-1.5 pl-12 lg:pl-0',
      children: [
        WDiv(
          key: ValueKey<String>('support-bubble-${message.id}'),
          className: 'max-w-xl px-3.5 py-2.5 rounded-2xl bg-primary-container',
          child: _buildContent(alignEnd: true),
        ),
        WText(
          key: ValueKey<String>('support-label-${message.id}'),
          '${trans('magic_starter.support.sender.customer')} · '
          '${clock(message.createdAt)}',
          className: 'text-xs text-fg-muted',
        ),
      ],
    );
  }

  Widget _buildOther({required Widget label, bool accent = false}) {
    return WDiv(
      className: 'flex flex-row items-start gap-2.5',
      children: [
        MagicStarterSupportSenderAvatar(
          key: ValueKey<String>('support-avatar-${message.id}'),
          senderType: message.senderType,
          name: message.senderName,
          photoUrl: message.senderAvatarUrl,
        ),
        WDiv(
          className: 'flex-1 min-w-0 flex flex-col items-start gap-1.5',
          children: [
            WDiv(
              key: ValueKey<String>('support-bubble-${message.id}'),
              className:
                  'max-w-xl px-3.5 py-2.5 rounded-2xl bg-surface-container-high'
                  '${accent ? ' border-l-2 border-ai' : ''}',
              child: _buildContent(),
            ),
            if (message.senderType == 'ai' && message.articles.isNotEmpty)
              WDiv(
                key: ValueKey<String>('support-articles-${message.id}'),
                className: 'w-full max-w-xl flex flex-col gap-2',
                children: [
                  for (final article in message.articles)
                    MagicStarterSupportArticleCard(article),
                ],
              ),
            label,
          ],
        ),
      ],
    );
  }

  Widget _buildContent({bool alignEnd = false}) {
    final open = onOpenPdf;
    final showAttachments =
        open != null &&
        message.attachments.isNotEmpty &&
        MagicStarterConfig.hasSupportAttachmentsFeatures();
    final text = WText(message.body, className: 'text-sm text-fg');

    if (!showAttachments) return text;

    return WDiv(
      className:
          'flex flex-col gap-2 ${alignEnd ? 'items-end' : 'items-start'}',
      children: [
        if (message.body.isNotEmpty) text,
        MagicStarterSupportAttachmentList(
          attachments: message.attachments,
          headers: attachmentHeaders,
          onOpenPdf: open,
          alignEnd: alignEnd,
        ),
      ],
    );
  }

  Widget _assistantLabel() {
    return WDiv(
      key: ValueKey<String>('support-label-${message.id}'),
      className: 'flex flex-row items-center gap-1.5',
      children: [
        _chip(message.senderName),
        WText(
          '· ${clock(message.createdAt)}',
          className: 'text-xs text-fg-muted',
        ),
      ],
    );
  }

  Widget _staffLabel() {
    final String? first = message.senderName
        ?.trim()
        .split(RegExp(r'\s+'))
        .first;

    return WText(
      key: ValueKey<String>('support-label-${message.id}'),
      [
        if (first != null && first.isNotEmpty) first,
        trans('magic_starter.support.sender.staff'),
        clock(message.createdAt),
      ].join(' · '),
      className: 'text-xs text-fg-muted',
    );
  }

  /// The "✦ Name" chip that marks assistant-authored content.
  static Widget _chip(String? name) {
    return WDiv(
      className:
          'flex flex-row items-center gap-1 px-2 py-0.5 rounded-md bg-ai-soft',
      children: [
        WIcon(_iconChip, className: 'text-xs text-ai-soft-foreground'),
        WText(
          name ?? trans('magic_starter.support.sender.ai'),
          className: 'text-xs font-semibold text-ai-soft-foreground',
        ),
      ],
    );
  }
}

/// The assistant's pending reply: three dots in a bubble, labelled "typing".
class MagicStarterSupportTypingBubble extends StatelessWidget {
  const MagicStarterSupportTypingBubble({super.key, this.assistantName});

  /// The assistant's display name, as its earlier replies carried it.
  final String? assistantName;

  static const _iconDot = Icons.circle;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      key: const ValueKey<String>('support-typing'),
      className: 'flex flex-row items-start gap-2.5',
      children: [
        const MagicStarterSupportSenderAvatar(senderType: 'ai'),
        WDiv(
          className: 'flex flex-col items-start gap-1.5',
          children: [
            WDiv(
              className:
                  'flex flex-row items-center gap-1.5 px-4 py-3.5 '
                  'rounded-2xl bg-surface-container-high',
              children: [
                for (var i = 0; i < 3; i++)
                  WIcon(
                    _iconDot,
                    className: 'text-[6px] text-ai-soft-foreground',
                  ),
              ],
            ),
            WDiv(
              className: 'flex flex-row items-center gap-1.5',
              children: [
                MagicStarterSupportMessageBubble._chip(assistantName),
                WText(
                  '· ${trans('magic_starter.support.typing')}',
                  className: 'text-xs text-fg-muted',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// What replaces the typing bubble when the assistant is slower than expected.
class MagicStarterSupportTakingLongerNote extends StatelessWidget {
  const MagicStarterSupportTakingLongerNote({super.key});

  @override
  Widget build(BuildContext context) {
    return WText(
      trans('magic_starter.support.taking_longer'),
      className: 'text-xs text-fg-muted text-center',
    );
  }
}

/// A line the desk recorded (a handoff, a status change), centred between two
/// hairlines. On a phone the hairlines drop and only the text stays.
class MagicStarterSupportActivityLine extends StatelessWidget {
  const MagicStarterSupportActivityLine(this.message, {super.key});

  final MagicStarterSupportMessage message;

  @override
  Widget build(BuildContext context) {
    const String rule =
        'hidden lg:flex flex-1 border-t border-color-border-subtle';

    return WDiv(
      key: ValueKey<String>('support-activity-${message.id}'),
      className: 'w-full flex flex-row items-center justify-center gap-2.5',
      children: [
        WDiv(className: rule),
        Flexible(
          child: WText(
            message.body,
            className: 'text-xs text-fg-muted text-center',
          ),
        ),
        WDiv(className: rule),
      ],
    );
  }
}
