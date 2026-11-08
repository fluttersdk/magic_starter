import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show CircularProgressIndicator, Icons;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../../models/magic_starter_support_conversation.dart';
import '../../components/form_field/index.dart';
import 'magic_starter_support_attachments.dart';
import 'magic_starter_support_message_bubble.dart';
import 'magic_starter_support_rating.dart';

/// Rebuilds a support part when the shared [MagicStarterSupportController]
/// notifies.
///
/// A [ListenableBuilder] throws when the controller notifies in the middle of
/// another widget's build, which a page's first load does from
/// `didChangeDependencies`, and a part can sit on a covered page or in a chat
/// panel while that happens. A notification that arrives inside the build phase
/// waits for the end of the frame.
mixin MagicStarterSupportControllerRebuild<T extends StatefulWidget>
    on State<T> {
  final MagicStarterSupportController supportController =
      MagicStarterSupportController.instance;

  @override
  void initState() {
    super.initState();
    supportController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    supportController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }
}

/// The messages of one loaded support conversation: bubbles by who wrote them,
/// activity lines, the typing bubble while the AI owes an answer, the "taking
/// longer" note after 45 seconds, and the rating block of a resolved thread.
///
/// A part for the `/support/:id` page and the chat panel alike: it reads no
/// route, never loads a thread (the caller loads it and passes it in) and never
/// clears errors. It draws no scroll area; given a [scrollController] that a
/// host's scrollable uses, it brings the newest line into view when one arrives.
class MagicStarterSupportThreadMessages extends StatefulWidget {
  const MagicStarterSupportThreadMessages({
    super.key,
    required this.conversation,
    this.scrollController,
    this.surface = 'page',
    this.ratingError,
  });

  final MagicStarterSupportConversation conversation;

  /// The controller of the scrollable this sits in; null scrolls nothing.
  final ScrollController? scrollController;

  /// The write lock a rating takes (see
  /// [MagicStarterSupportController.isSubmittingFor]).
  final String surface;

  /// Why the last rating was refused. The controller keeps one write error for
  /// everything, so the composer would show it too; a host that draws both
  /// parts passes the same notifier to [MagicStarterSupportComposer] so the
  /// rating's refusal stays under the rating. Null keeps it private.
  final ValueNotifier<String?>? ratingError;

  @override
  State<MagicStarterSupportThreadMessages> createState() =>
      _MagicStarterSupportThreadMessagesState();
}

class _MagicStarterSupportThreadMessagesState
    extends State<MagicStarterSupportThreadMessages>
    with
        MagicStarterSupportControllerRebuild<
          MagicStarterSupportThreadMessages
        > {
  /// How long the typing bubble waits before it admits the AI is slow.
  static const Duration _slowAfter = Duration(seconds: 45);

  final ValueNotifier<String?> _ownRatingError = ValueNotifier<String?>(null);

  /// Fires once the AI has been pending for [_slowAfter], counted from the
  /// moment this part first saw it pending: the wire carries no timestamp for
  /// it, and a screen opened on a stranded thread should not claim the AI is
  /// typing forever.
  Timer? _slowTimer;
  bool _slow = false;

  /// The bearer header an attachment image is read with. Null until the token
  /// has been read, and always null with `support_attachments` off.
  Map<String, String>? _attachmentHeaders;

  /// What the thread looked like the last time it was scrolled to its end, so a
  /// new message, the typing bubble and the slow note each bring the newest
  /// line into view exactly once.
  String _scrolledTo = '';

  ValueNotifier<String?> get _ratingError =>
      widget.ratingError ?? _ownRatingError;

  @override
  void initState() {
    super.initState();

    if (MagicStarterConfig.hasSupportAttachmentsFeatures()) {
      unawaited(_resolveAttachmentHeaders());
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _ownRatingError.dispose();
    super.dispose();
  }

  /// Reads the token once; an image is then fetched with it, never with a
  /// credential carried in the url.
  Future<void> _resolveAttachmentHeaders() async {
    final headers = await supportController.attachmentHeaders();

    if (mounted) setState(() => _attachmentHeaders = headers);
  }

  Future<bool> _rate(String rating, String comment) async {
    final bool saved = await supportController.rate(
      widget.conversation.id,
      rating,
      comment: comment,
      surface: widget.surface,
    );

    if (mounted) {
      _ratingError.value = saved
          ? null
          : supportController.getError('rating') ??
                supportController.getError('comment') ??
                supportController.writeError;
    }

    return saved;
  }

  /// Opens a PDF through a 60 second signed link: the read credential stays
  /// the bearer token, and the link is minted only for this one tap.
  ///
  /// The web opens it in the current tab: a new window opened after the link
  /// request is a popup Safari blocks while the launcher still answers `true`,
  /// and the download route answers as an attachment, so the page stays.
  Future<void> _openPdf(MagicStarterSupportAttachment attachment) async {
    final String? url = await supportController.attachmentLink(
      widget.conversation.id,
      attachment.id,
    );
    if (url != null && await Launch.url(url, webOnlyWindowName: '_self')) {
      return;
    }

    Magic.error(
      trans('magic_starter.titles.support_thread'),
      trans('magic_starter.support.attachment_open_error'),
    );
  }

  /// Starts or clears the countdown behind the typing bubble.
  void _syncSlowClock(bool awaitingAi) {
    if (!awaitingAi) {
      _slowTimer?.cancel();
      _slowTimer = null;
      _slow = false;

      return;
    }

    if (_slowTimer != null) return;

    _slowTimer = Timer(_slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  /// Brings the newest line into view after the frame that changed the thread.
  void _keepLatestInView(MagicStarterSupportConversation conversation) {
    final ScrollController? scroll = widget.scrollController;
    if (scroll == null) return;

    final String signature =
        '${conversation.id}:${conversation.messages.length}:'
        '${conversation.awaitingAi}:$_slow';
    if (signature == _scrolledTo) return;

    _scrolledTo = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;

      scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MagicStarterSupportConversation conversation = widget.conversation;

    _syncSlowClock(conversation.awaitingAi);
    _keepLatestInView(conversation);

    // A conversation reads best in a column of its own, centred and capped like
    // the composer below it, rather than stretched across a wide page.
    return WDiv(
      className: 'w-full max-w-3xl mx-auto flex flex-col gap-3.5 lg:gap-4 pb-4',
      children: [
        for (final message in conversation.messages) _buildMessage(message),
        if (conversation.awaitingAi)
          _slow
              ? const MagicStarterSupportTakingLongerNote()
              : MagicStarterSupportTypingBubble(
                  assistantName: _assistantName(conversation),
                ),
        if (_showsRating(conversation)) _buildRating(conversation),
      ],
    );
  }

  /// The thumbs block, for a resolved conversation that can be rated or already
  /// carries a rating. Gone as soon as a reply reopens the conversation.
  bool _showsRating(MagicStarterSupportConversation conversation) {
    return MagicStarterConfig.hasSupportCsatFeatures() &&
        conversation.status == 'resolved' &&
        (conversation.canRate || conversation.rating != null);
  }

  Widget _buildRating(MagicStarterSupportConversation conversation) {
    return ValueListenableBuilder<String?>(
      valueListenable: _ratingError,
      builder: (context, error, _) => MagicStarterSupportRatingBlock(
        rating: conversation.rating,
        onSubmit: _rate,
        isSubmitting: supportController.isSubmittingFor(widget.surface),
        error: error,
      ),
    );
  }

  /// The name the assistant signed its earlier replies with, if it has replied.
  String? _assistantName(MagicStarterSupportConversation conversation) {
    for (final message in conversation.messages.reversed) {
      if (message.senderType == 'ai' && message.senderName != null) {
        return message.senderName;
      }
    }

    return null;
  }

  Widget _buildMessage(MagicStarterSupportMessage message) {
    // The desk's own activity lines (a handoff, a status change) are not a
    // person speaking, so they read as a divider line, not a bubble.
    if (message.kind == 'activity' || message.senderType == 'system') {
      return MagicStarterSupportActivityLine(message);
    }

    return MagicStarterSupportMessageBubble(
      message,
      attachmentHeaders: _attachmentHeaders,
      onOpenPdf: _openPdf,
    );
  }
}

/// The reply box of a support conversation: a multiline input with an attach
/// picker (behind `support_attachments`) and a round send button.
///
/// Holds its own draft and picked files. It reads no route and clears no
/// errors; it sends through
/// [MagicStarterSupportController.sendMessage] under [surface], so a reply here
/// is not refused while another surface has a write in flight.
class MagicStarterSupportComposer extends StatefulWidget {
  const MagicStarterSupportComposer({
    super.key,
    required this.conversationId,
    this.surface = 'page',
    this.ratingError,
    this.pickFiles,
  });

  final Object conversationId;

  /// The write lock a reply takes (see
  /// [MagicStarterSupportController.isSubmittingFor]).
  final String surface;

  /// The notifier handed to [MagicStarterSupportThreadMessages.ratingError].
  /// While it holds a refusal the controller's write error is the rating's, so
  /// it is not shown under the reply box; a new send clears it.
  final ValueNotifier<String?>? ratingError;

  /// Stands in for the system file picker; a parameter only so a test can
  /// choose files without one.
  final Future<List<MagicFile>> Function(List<String> extensions)? pickFiles;

  @override
  State<MagicStarterSupportComposer> createState() =>
      _MagicStarterSupportComposerState();
}

class _MagicStarterSupportComposerState
    extends State<MagicStarterSupportComposer>
    with
        MagicStarterSupportControllerRebuild<MagicStarterSupportComposer>,
        MagicStarterSupportAttachmentPicking<MagicStarterSupportComposer> {
  static const _iconSend = Icons.send;
  static const _iconAssistant = Icons.auto_awesome;
  static const _iconWaiting = Icons.schedule;

  /// The send circle while a reply can go (or is going) and while it cannot.
  static const String _sendLive = 'bg-primary text-on-primary';
  static const String _sendIdle = 'bg-surface-container-high text-fg-muted';

  final TextEditingController _reply = TextEditingController();

  /// Whether a reply is in flight. The composer's own flag, not the
  /// controller's lock, which every write of the surface shares: a rating being
  /// saved must not spin the Send circle.
  bool _sending = false;

  @override
  Future<List<MagicFile>> Function(List<String> extensions)?
  get pickFilesOverride => widget.pickFiles;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  /// Whether Enter sends. A hardware keyboard (web and desktop) sends on Enter
  /// and breaks the line on Shift+Enter; a phone's soft keyboard keeps Enter as
  /// a line break and sends from the button.
  bool get _enterSends =>
      kIsWeb ||
      const {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);

  Future<void> _send() async {
    final String body = _reply.text.trim();
    final List<MagicFile> files = pickedAttachments;
    if (_sending || supportController.isSubmittingFor(widget.surface)) return;
    if (body.isEmpty && files.isEmpty) return;

    widget.ratingError?.value = null;
    setState(() => _sending = true);
    final bool sent;
    try {
      sent = await supportController.sendMessage(
        widget.conversationId,
        body,
        attachments: files,
        surface: widget.surface,
      );
    } finally {
      // A reply whose answer fails to decode throws past the controller's own
      // guard; Send must not stay spinning and disabled after it.
      if (mounted) setState(() => _sending = false);
    }
    if (!mounted || !sent) return;

    _reply.clear();
    clearAttachments();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final bool enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!_enterSends || !enter || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    // A pending IME composition owns Enter (it commits the candidate), and
    // Shift+Enter is the line break.
    if (HardwareKeyboard.instance.isShiftPressed ||
        _reply.value.composing.isValid) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) unawaited(_send());

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([?widget.ratingError]),
      builder: (context, _) => WDiv(
        key: const ValueKey<String>('support-composer'),
        className:
            'w-full max-w-3xl mx-auto flex flex-col gap-2 pt-3 pb-4 lg:pb-5',
        children: [
          ?_buildExpectation(
            supportController.threadFor(widget.conversationId),
          ),
          MagicStarterSupportPickedChips(
            files: pickedAttachments,
            onRemove: removeAttachment,
          ),
          MSFormField(
            error:
                supportController.getError('body') ??
                magicStarterSupportAttachmentError(supportController) ??
                (widget.ratingError?.value == null
                    ? supportController.writeError
                    : null),
            child: Focus(onKeyEvent: _onKey, child: _buildField()),
          ),
          if (_enterSends)
            WText(
              trans('magic_starter.support.composer_hint'),
              className: 'hidden lg:flex justify-end text-xs text-fg-disabled',
            ),
        ],
      ),
    );
  }

  /// What to expect next: the AI while the conversation is the AI desk's, the
  /// team while it waits on a person, and nothing otherwise.
  Widget? _buildExpectation(MagicStarterSupportConversation? conversation) {
    if (conversation == null) return null;

    if (conversation.awaitingAi || conversation.status == 'pending') {
      return WDiv(
        className: 'flex flex-row items-center gap-2',
        children: [
          WIcon(_iconAssistant, className: 'text-xs text-ai-soft-foreground'),
          Flexible(
            child: WText(
              trans('magic_starter.support.expect_ai'),
              className: 'text-xs text-ai-soft-foreground',
            ),
          ),
        ],
      );
    }

    if (conversation.waitingOnTeam) {
      return WDiv(
        className: 'flex flex-row items-center gap-2',
        children: [
          WIcon(_iconWaiting, className: 'text-xs text-fg-muted'),
          Flexible(
            child: WText(
              trans('magic_starter.support.expect_team'),
              className: 'text-xs text-fg-muted',
            ),
          ),
        ],
      );
    }

    return null;
  }

  Widget _buildField() {
    return WInput(
      controller: _reply,
      type: InputType.multiline,
      minLines: 1,
      maxLines: 5,
      placeholder: trans('magic_starter.support.reply_placeholder'),
      className: '''
        w-full pl-3.5 pr-1 py-1.5 rounded-3xl border text-sm text-fg
        bg-surface-container border-color-border
        focus:border-color-border focus:ring-2 focus:ring-bg-primary
      ''',
      prefix: MagicStarterConfig.hasSupportAttachmentsFeatures()
          ? MagicStarterSupportAttachButton(onTap: pickAttachments)
          : null,
      suffix: _buildSendButton(),
    );
  }

  Widget _buildSendButton() {
    return ListenableBuilder(
      listenable: _reply,
      builder: (context, _) {
        final bool sending = _sending;
        // Another write (a rating) holds the surface: Send cannot go, but
        // nothing of this reply is in flight, so no spinner.
        final bool blocked =
            sending || supportController.isSubmittingFor(widget.surface);
        final bool ready =
            !sending &&
            (_reply.text.trim().isNotEmpty || pickedAttachments.isNotEmpty);

        // One labelled button node: an outer `Semantics(button:)` around the
        // anchor read as a button holding a second, unnamed one. The 44 px box
        // is the touch target; the 36 px circle is what paints. The circle
        // sits at the box's right edge and the field's right padding is 4 px,
        // the same as the box leaves above and below it, so the circle stands
        // the same distance from the border on three sides.
        return WAnchor(
          key: const ValueKey<String>('support-send'),
          onTap: blocked ? null : _send,
          // Says it is not pressable while a write is out, instead of an
          // enabled button that does nothing.
          isDisabled: blocked,
          semanticLabel: trans('magic_starter.support.reply_submit'),
          child: WDiv(
            className: 'size-11 flex items-center justify-end',
            child: WDiv(
              key: const ValueKey<String>('support-send-circle'),
              className:
                  'w-9 h-9 rounded-full flex items-center justify-center '
                  '${sending || ready ? _sendLive : _sendIdle}',
              child: sending
                  ? const _SendSpinner()
                  : WIcon(_iconSend, className: 'text-base'),
            ),
          ),
        );
      },
    );
  }
}

/// A support conversation for a host with a bounded height, such as a chat
/// panel: the messages in a scroll area of their own over the composer.
///
/// Owns its [ScrollController] unless one is passed. The caller loads the
/// thread and passes it in; nothing here reads a route or fetches.
class MagicStarterSupportThreadBody extends StatefulWidget {
  const MagicStarterSupportThreadBody({
    super.key,
    required this.conversation,
    this.surface = 'page',
    this.scrollController,
  });

  final MagicStarterSupportConversation conversation;

  /// The write lock a reply and a rating take.
  final String surface;

  final ScrollController? scrollController;

  @override
  State<MagicStarterSupportThreadBody> createState() =>
      _MagicStarterSupportThreadBodyState();
}

class _MagicStarterSupportThreadBodyState
    extends State<MagicStarterSupportThreadBody> {
  final ScrollController _ownScroll = ScrollController();
  final ValueNotifier<String?> _ratingError = ValueNotifier<String?>(null);

  ScrollController get _scroll => widget.scrollController ?? _ownScroll;

  @override
  void dispose() {
    _ownScroll.dispose();
    _ratingError.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: MagicStarterSupportThreadMessages(
              conversation: widget.conversation,
              scrollController: _scroll,
              surface: widget.surface,
              ratingError: _ratingError,
            ),
          ),
        ),
        MagicStarterSupportComposer(
          conversationId: widget.conversation.id,
          surface: widget.surface,
          ratingError: _ratingError,
        ),
      ],
    );
  }
}

/// The send circle's in-flight state: a small spinner in the circle's own
/// text colour, so it follows the host's `text-on-primary`.
class _SendSpinner extends StatelessWidget {
  const _SendSpinner();

  @override
  Widget build(BuildContext context) {
    final Color? color = DefaultTextStyle.of(context).style.color;

    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: color == null ? null : AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
