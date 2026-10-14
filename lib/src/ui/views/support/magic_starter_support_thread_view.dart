import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../../models/magic_starter_support_conversation.dart';
import '../../components/button/index.dart';
import '../../components/error_state/index.dart';
import '../../components/form_field/index.dart';
import '../../components/page_scaffold/index.dart';
import '../../components/skeleton/index.dart';
import 'magic_starter_support_attachments.dart';
import 'magic_starter_support_index_view.dart';
import 'magic_starter_support_message_bubble.dart';
import 'magic_starter_support_rating.dart';

/// One support conversation as a chat: bubbles by who wrote them, a docked
/// composer, and what to expect from the AI or the team above it.
///
/// Opening it tells the backend the customer has read it, which clears the
/// unread dot on the list. The backend answers 404 for a conversation that is
/// missing and for one a teammate opened alike, so the not-found state says
/// nothing more than that.
///
/// Behind `support_attachments` the composer takes files and the bubbles show
/// them; behind `support_csat` a resolved conversation asks for a thumbs
/// rating under the thread. The composer stays on a resolved conversation:
/// writing again reopens it.
class MagicStarterSupportThreadView
    extends MagicStatefulView<MagicStarterSupportController> {
  /// [pickFiles] stands in for the system file picker; it is a parameter only
  /// so a test can choose files without one.
  const MagicStarterSupportThreadView({
    super.key,
    @visibleForTesting this.pickFiles,
  });

  final Future<List<MagicFile>> Function(List<String> extensions)? pickFiles;

  @override
  State<MagicStarterSupportThreadView> createState() =>
      _MagicStarterSupportThreadViewState();
}

class _MagicStarterSupportThreadViewState
    extends
        MagicStatefulViewState<
          MagicStarterSupportController,
          MagicStarterSupportThreadView
        >
    with
        MagicStarterSupportLiveRefresh<MagicStarterSupportThreadView>,
        MagicStarterSupportAttachmentPicking<MagicStarterSupportThreadView> {
  static const _iconError = Icons.error_outline;
  static const _iconSend = Icons.send;
  static const _iconAssistant = Icons.auto_awesome;
  static const _iconWaiting = Icons.schedule;

  /// How long the typing bubble waits before it admits the AI is slow.
  static const Duration _slowAfter = Duration(seconds: 45);

  /// The conversation id from THIS page's own route.
  ///
  /// Not `MagicRouter.instance.pathParameter`: that reads whichever page the
  /// router built last, and a push from another page (Contact sales on the
  /// billing screen) rebuilds the page underneath after this one, so the id
  /// came back empty and the thread fetched `support/conversations/`. Resolved
  /// in [didChangeDependencies], the first point where an inherited route
  /// state can be read, and the first resolution starts the load.
  String? _id;

  final TextEditingController _reply = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Fires once the AI has been pending for [_slowAfter], counted from the
  /// moment this screen first saw it pending: the wire carries no timestamp for
  /// it, and a screen opened on a stranded thread should not claim the AI is
  /// typing forever.
  Timer? _slowTimer;
  bool _slow = false;

  /// The bearer header an attachment image is read with. Null until the token
  /// has been read, and always null with `support_attachments` off.
  Map<String, String>? _attachmentHeaders;

  /// Why the last rating was refused. The controller keeps one write error for
  /// the thread, so the composer would show it too; this one is the rating's.
  String? _ratingError;

  /// What the thread looked like the last time it was scrolled to its end, so a
  /// new message, the typing bubble and the slow note each bring the newest
  /// line into view exactly once.
  String _scrolledTo = '';

  @override
  Future<List<MagicFile>> Function(List<String> extensions)?
  get pickFilesOverride => widget.pickFiles;

  @override
  void onInit() {
    controller.forgetWriteError();
    startLiveRefresh();

    if (MagicStarterConfig.hasSupportAttachmentsFeatures()) {
      unawaited(_resolveAttachmentHeaders());
    }
  }

  /// Reads the token once; an image is then fetched with it, never with a
  /// credential carried in the url.
  Future<void> _resolveAttachmentHeaders() async {
    final headers = await controller.attachmentHeaders();

    if (mounted) setState(() => _attachmentHeaders = headers);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_id != null) return;

    _id = MagicRouter.instance.pathParameterOf(context, 'id') ?? '';
    unawaited(refreshSupport());
  }

  @override
  void onClose() {
    stopLiveRefresh();
    _slowTimer?.cancel();
    _reply.dispose();
    _scroll.dispose();
  }

  /// Rereads the thread and, when staff wrote since the last read, marks it
  /// seen.
  ///
  /// A thread with nothing unread sends no receipt: this runs on every poll
  /// and broadcast, and a receipt that changes nothing is still a write. The
  /// list is reread after a receipt because the index stays mounted under this
  /// route, and its dot would otherwise outlive the read.
  @override
  Future<void> refreshSupport() async {
    final String? id = _id;
    if (id == null) return;

    await controller.loadConversation(id);

    // A read dropped as stale leaves the controller describing whichever
    // thread is on screen now, so its unread state says nothing about this one.
    final MagicStarterSupportConversation? loaded = controller.conversation;
    if (!mounted || loaded == null || loaded.id.toString() != id) return;
    if (controller.threadStatus != MagicStarterSupportReadStatus.loaded) return;
    if (!loaded.hasUnread) return;

    final bool seen = await controller.markSeen(id);

    if (seen && mounted) await controller.loadConversations();
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
    final String? id = _id;
    final String body = _reply.text.trim();
    final List<MagicFile> files = pickedAttachments;
    if (id == null || (body.isEmpty && files.isEmpty)) return;

    _ratingError = null;
    final bool sent = await controller.sendMessage(
      id,
      body,
      attachments: files,
    );
    if (!sent || !mounted) return;

    _reply.clear();
    clearAttachments();
  }

  Future<bool> _rate(String rating, String comment) async {
    final String? id = _id;
    if (id == null) return false;

    final bool saved = await controller.rate(id, rating, comment: comment);

    if (mounted) {
      setState(() {
        _ratingError = saved
            ? null
            : controller.getError('rating') ??
                  controller.getError('comment') ??
                  controller.writeError;
      });
    }

    return saved;
  }

  /// Opens a PDF through a 60 second signed link: the read credential stays
  /// the bearer token, and the link is minted only for this one tap.
  Future<void> _openPdf(MagicStarterSupportAttachment attachment) async {
    final String? id = _id;
    if (id == null) return;

    final String? url = await controller.attachmentLink(id, attachment.id);
    if (url != null && await Launch.url(url)) return;

    Magic.error(
      trans('magic_starter.titles.support_thread'),
      trans('magic_starter.support.attachment_open_error'),
    );
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
    final String signature =
        '${conversation.id}:${conversation.messages.length}:'
        '${conversation.awaitingAi}:$_slow';
    if (signature == _scrolledTo) return;

    _scrolledTo = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;

      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MagicStarterSupportConversation? conversation =
        controller.conversation;

    if (conversation != null) {
      _syncSlowClock(conversation.awaitingAi);
      _keepLatestInView(conversation);
    }

    return MSPageScaffold(
      title:
          conversation?.subject ?? trans('magic_starter.titles.support_thread'),
      subtitle: conversation == null ? null : _meta(conversation),
      actions: [
        if (conversation != null)
          MagicStarterSupportStatusBadge(
            conversation.status,
            awaitingAi: conversation.awaitingAi,
            waitingOnTeam: conversation.waitingOnTeam,
          ),
      ],
      backLabel: trans('magic_starter.support.index_title'),
      backFallback: MagicStarterConfig.supportRoute(),
      scrollController: _scroll,
      footer: conversation == null ? null : _buildComposer(conversation),
      children: [_buildBody(conversation)],
    );
  }

  /// `#12 · Billing · opened Oct 13`, without the topic when there is none.
  String _meta(MagicStarterSupportConversation conversation) {
    final String? topic = conversation.topic;

    return [
      '#${conversation.number}',
      if (topic != null) magicStarterSupportTopicLabel(topic),
      trans('magic_starter.support.opened', {
        'date': conversation.createdAt.toLocal().toCarbon().format('MMM d'),
      }),
    ].join(' · ');
  }

  Widget _buildBody(MagicStarterSupportConversation? conversation) {
    if (controller.threadStatus == MagicStarterSupportReadStatus.notFound) {
      return MSErrorState(
        icon: _iconError,
        title: trans('magic_starter.support.not_found_title'),
        action: MSButton(
          intent: ButtonIntent.secondary,
          onPressed: () => MagicRoute.to(MagicStarterConfig.supportRoute()),
          child: WText(
            trans('magic_starter.support.back_to_list'),
            className: 'text-center',
          ),
        ),
      );
    }

    if (conversation == null) {
      return controller.threadStatus == MagicStarterSupportReadStatus.failed
          ? MSErrorState(
              icon: _iconError,
              title: trans('magic_starter.support.thread_load_error'),
            )
          : const MSSkeleton(height: 160);
    }

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
        ?_buildRating(conversation),
      ],
    );
  }

  /// The thumbs block, for a resolved conversation that can be rated or already
  /// carries a rating. Gone as soon as a reply reopens the conversation.
  Widget? _buildRating(MagicStarterSupportConversation conversation) {
    if (!MagicStarterConfig.hasSupportCsatFeatures() ||
        conversation.status != 'resolved' ||
        !(conversation.canRate || conversation.rating != null)) {
      return null;
    }

    return MagicStarterSupportRatingBlock(
      rating: conversation.rating,
      onSubmit: _rate,
      isSubmitting: controller.isSubmitting,
      error: _ratingError,
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

  Widget _buildComposer(MagicStarterSupportConversation conversation) {
    return WDiv(
      key: const ValueKey<String>('support-composer'),
      className:
          'w-full max-w-3xl mx-auto flex flex-col gap-2 pt-3 pb-4 lg:pb-5',
      children: [
        ?_buildExpectation(conversation),
        MagicStarterSupportPickedChips(
          files: pickedAttachments,
          onRemove: removeAttachment,
        ),
        MSFormField(
          error:
              controller.getError('body') ??
              magicStarterSupportAttachmentError(controller) ??
              (_ratingError == null ? controller.writeError : null),
          child: Focus(onKeyEvent: _onKey, child: _buildField()),
        ),
        if (_enterSends)
          WText(
            trans('magic_starter.support.composer_hint'),
            className: 'hidden lg:flex justify-end text-xs text-fg-disabled',
          ),
      ],
    );
  }

  /// What to expect next: the AI while the conversation is the AI desk's, the
  /// team while it waits on a person, and nothing otherwise.
  Widget? _buildExpectation(MagicStarterSupportConversation conversation) {
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
        w-full pl-3.5 pr-2 py-1.5 rounded-3xl border text-sm text-fg
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
        final bool ready =
            _reply.text.trim().isNotEmpty || pickedAttachments.isNotEmpty;

        return WDiv(
          className: 'py-1.5',
          child: Semantics(
            button: true,
            label: trans('magic_starter.support.reply_submit'),
            child: WAnchor(
              key: const ValueKey<String>('support-send'),
              onTap: _send,
              child: WDiv(
                className:
                    'w-9 h-9 rounded-full flex items-center justify-center '
                    '${ready ? 'bg-primary' : 'bg-surface-container-high'}',
                child: WIcon(
                  _iconSend,
                  className:
                      'text-base ${ready ? 'text-on-primary' : 'text-fg-muted'}',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
