import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../../models/magic_starter_support_conversation.dart';
import '../../../support/support_sync.dart';
import '../../components/button/index.dart';
import '../../components/error_state/index.dart';
import '../../components/page_scaffold/index.dart';
import '../../components/skeleton/index.dart';
import 'magic_starter_support_index_view.dart';
import 'magic_starter_support_thread_body.dart';

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
///
/// This view is the page chrome around [MagicStarterSupportThreadMessages] and
/// [MagicStarterSupportComposer]: it owns the route id, the load and the seen
/// receipt, and the parts draw the conversation.
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
    with MagicStarterSupportLiveRefresh<MagicStarterSupportThreadView> {
  static const _iconError = Icons.error_outline;

  /// The conversation id from THIS page's own route.
  ///
  /// Not `MagicRouter.instance.pathParameter`: that reads whichever page the
  /// router built last, and a push from another page (Contact sales on the
  /// billing screen) rebuilds the page underneath after this one, so the id
  /// came back empty and the thread fetched `support/conversations/`. Resolved
  /// in [didChangeDependencies], the first point where an inherited route
  /// state can be read, and the first resolution starts the load.
  String? _id;

  final ScrollController _scroll = ScrollController();

  /// Why the last rating was refused, shared by the messages (which show it
  /// under the rating) and the composer (which then hides the shared write
  /// error).
  final ValueNotifier<String?> _ratingError = ValueNotifier<String?>(null);

  @override
  void onInit() {
    controller.forgetWriteError();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_id != null) return;

    final String id = MagicRouter.instance.pathParameterOf(context, 'id') ?? '';
    _id = id;
    startLiveRefresh(thread: id);
    unawaited(_open(id));
  }

  @override
  void onClose() {
    stopLiveRefresh();
    _scroll.dispose();
    _ratingError.dispose();
  }

  /// Points the page at its thread, reads it, and marks it seen when unread.
  Future<void> _open(String id) async {
    await controller.loadConversation(id);
    await _markSeen(id);
  }

  /// Rereads the thread (and the list, in the same shared read) and, when
  /// staff wrote since the last read, marks it seen.
  @override
  Future<void> refreshSupport() async {
    final String? id = _id;
    if (id == null) return;

    await MagicStarterSupportSync.instance.refresh();
    await _markSeen(id);
  }

  /// A thread with nothing unread sends no receipt: this runs on every poll
  /// and broadcast, and a receipt that changes nothing is still a write. The
  /// shared sync sends at most one per unread state and rereads the list after
  /// it, because the index stays mounted under this route and its dot would
  /// otherwise outlive the read. A screen left before its read answered sends
  /// nothing for it.
  Future<void> _markSeen(String id) async {
    if (!mounted) return;

    await MagicStarterSupportSync.instance.markSeenOnce(id);
  }

  @override
  Widget build(BuildContext context) {
    final MagicStarterSupportConversation? conversation =
        controller.conversation;

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
      footer: conversation == null
          ? null
          : MagicStarterSupportComposer(
              conversationId: conversation.id,
              ratingError: _ratingError,
              pickFiles: widget.pickFiles,
            ),
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

    return MagicStarterSupportThreadMessages(
      conversation: conversation,
      scrollController: _scroll,
      ratingError: _ratingError,
    );
  }
}
