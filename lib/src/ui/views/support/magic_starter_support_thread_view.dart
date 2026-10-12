import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../../models/magic_starter_support_conversation.dart';
import '../../components/button/index.dart';
import '../../components/card/index.dart';
import '../../components/error_state/index.dart';
import '../../components/form_field/index.dart';
import '../../components/page_scaffold/index.dart';
import '../../components/skeleton/index.dart';
import '../../components/textarea/index.dart';
import 'magic_starter_support_index_view.dart';

/// One support conversation: its messages by who wrote them, and a composer.
///
/// Opening it tells the backend the customer has read it, which clears the
/// unread dot on the list. The backend answers 404 for a conversation that is
/// missing and for one a teammate opened alike, so the not-found state says
/// nothing more than that.
class MagicStarterSupportThreadView
    extends MagicStatefulView<MagicStarterSupportController> {
  const MagicStarterSupportThreadView({super.key});

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

  late final String _id = MagicRouter.instance.pathParameter('id') ?? '';

  final TextEditingController _reply = TextEditingController();

  @override
  void onInit() {
    unawaited(refreshSupport());
    startLiveRefresh();
  }

  @override
  void onClose() {
    stopLiveRefresh();
    _reply.dispose();
  }

  /// Rereads the thread and marks it seen.
  ///
  /// The list is reread only when this thread was unread, because that is the
  /// one case where marking it seen changes what the list shows: the index
  /// stays mounted under this route, and its dot would otherwise outlive the
  /// read.
  @override
  Future<void> refreshSupport() async {
    await controller.loadConversation(_id);
    if (controller.threadStatus != MagicStarterSupportReadStatus.loaded) return;

    final bool wasUnread = controller.conversation?.hasUnread ?? false;
    final bool seen = await controller.markSeen(_id);

    if (seen && wasUnread && mounted) await controller.loadConversations();
  }

  Future<void> _send() async {
    final bool sent = await controller.sendMessage(_id, _reply.text.trim());

    if (sent) _reply.clear();
  }

  @override
  Widget build(BuildContext context) {
    final MagicStarterSupportConversation? conversation =
        controller.conversation;

    return MSPageScaffold(
      title:
          conversation?.subject ?? trans('magic_starter.titles.support_thread'),
      subtitle: conversation == null ? null : '#${conversation.number}',
      actions: [
        if (conversation != null)
          MagicStarterSupportStatusBadge(conversation.status),
      ],
      backLabel: trans('magic_starter.support.index_title'),
      backFallback: MagicStarterConfig.supportRoute(),
      children: [_buildBody(conversation)],
    );
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

    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        for (final message in conversation.messages) _buildMessage(message),
        _buildComposer(),
      ],
    );
  }

  Widget _buildMessage(MagicStarterSupportMessage message) {
    final String sentAt = message.createdAt.toCarbon().shortDiffForHumans();

    // The desk's own activity lines (a status change, an AI note) are not a
    // person speaking, so they read as a quiet centred note, not a bubble.
    if (message.senderType != 'customer' && message.senderType != 'staff') {
      return WDiv(
        className: 'flex flex-col items-center gap-1',
        children: [
          WText(message.body, className: 'text-xs text-fg-muted text-center'),
        ],
      );
    }

    final bool mine = message.senderType == 'customer';

    return WDiv(
      className: mine
          ? 'flex flex-col items-end gap-1'
          : 'flex flex-col items-start gap-1',
      children: [
        WText(
          '${trans('magic_starter.support.sender.${message.senderType}')} · '
          '$sentAt',
          className: 'text-xs text-fg-muted',
        ),
        WDiv(
          className: mine
              ? 'max-w-xl px-4 py-3 rounded-2xl bg-primary'
              : 'max-w-xl px-4 py-3 rounded-2xl bg-surface-container',
          child: WText(
            message.body,
            className: mine ? 'text-sm text-on-primary' : 'text-sm text-fg',
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return MSCard(
      child: WDiv(
        className: 'flex flex-col gap-3',
        children: [
          MSFormField(
            error: controller.getError('body') ?? controller.writeError,
            child: MSTextarea(
              controller: _reply,
              placeholder: trans('magic_starter.support.reply_placeholder'),
              fullWidth: true,
            ),
          ),
          WDiv(
            className: 'flex flex-row justify-end',
            child: MSButton(
              onPressed: _send,
              isLoading: controller.isSubmitting,
              child: WText(
                trans('magic_starter.support.reply_submit'),
                className: 'text-center',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
