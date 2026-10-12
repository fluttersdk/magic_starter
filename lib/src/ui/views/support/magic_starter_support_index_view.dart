import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../../models/magic_starter_support_conversation.dart';
import '../../components/badge/index.dart';
import '../../components/button/index.dart';
import '../../components/card/index.dart';
import '../../components/empty_state/index.dart';
import '../../components/error_state/index.dart';
import '../../components/page_scaffold/index.dart';
import '../../components/skeleton/index.dart';

/// Keeps a support screen current without the customer reloading it.
///
/// The backend broadcasts `support.conversation.updated` on the private user
/// channel `App.Models.User.{id}`; the screen refetches when it arrives. With no
/// broadcast driver configured, or while the socket is down, a 30 second poll
/// does the same job, so the screen never depends on a socket to be correct.
///
/// Shared by the index and the thread view and defined here rather than
/// duplicated in both. It subscribes through [BroadcastListeners] and not
/// through `Echo.private(...).listen(...)` directly: the user channel is shared
/// with the notification bell, and `listen` replaces a same-event handler, so a
/// second owner of the channel would silently deafen the first.
mixin MagicStarterSupportLiveRefresh<T extends StatefulWidget> on State<T> {
  /// How often a screen without a live socket rereads.
  static const Duration pollInterval = Duration(seconds: 30);

  static const String _alias = 'magic_starter_support';
  static const String _event = 'support.conversation.updated';

  Timer? _pollTimer;
  BroadcastListenerToken? _broadcastToken;

  /// Rereads whatever this screen shows.
  Future<void> refreshSupport();

  /// Starts the poll and, when a broadcast driver is configured, the channel
  /// listener. Call from `onInit`.
  void startLiveRefresh() {
    _pollTimer = Timer.periodic(pollInterval, (_) {
      // A live socket delivers the event, so polling on top of it only repeats
      // the read; the null driver reports itself disconnected and keeps polling.
      if (_broadcastToken != null && Echo.connection.isConnected) return;

      _refresh();
    });

    if (!_broadcastingEnabled()) return;

    // Reverb has no replay: whatever was published while the socket was down is
    // gone, and only a read recovers it.
    BroadcastListeners.channel(_alias, _userChannel, onReconnect: _refresh);
    _broadcastToken = BroadcastListeners.add(_alias, _event, (_) => _refresh());

    unawaited(
      BroadcastListeners.sync().catchError((Object error) {
        Log.error('[MagicStarterSupportLiveRefresh] sync failed: $error');
      }),
    );
  }

  /// Stops the poll and the listener. Call from `onClose`.
  void stopLiveRefresh() {
    _pollTimer?.cancel();
    _pollTimer = null;

    final BroadcastListenerToken? token = _broadcastToken;
    if (token != null) BroadcastListeners.remove(token);
    _broadcastToken = null;
  }

  void _refresh() {
    if (!mounted) return;

    unawaited(refreshSupport());
  }

  /// The null driver accepts a subscription and delivers nothing, so it counts
  /// as no driver and is never subscribed to.
  bool _broadcastingEnabled() {
    final String? driver = Config.get<String>('broadcasting.default');

    return driver != null && driver.isNotEmpty && driver != 'null';
  }

  /// The signed-in user's private channel, or null while no identity resolved.
  String? _userChannel() {
    final String? id = Auth.id()?.toString();

    return (id == null || id.isEmpty) ? null : 'App.Models.User.$id';
  }
}

/// A conversation's status as the customer reads it.
///
/// Only two states matter to the customer: finished, or still open. `pending`
/// and `snoozed` are the desk's own bookkeeping and read as open, and so does a
/// status a newer backend adds.
class MagicStarterSupportStatusBadge extends StatelessWidget {
  const MagicStarterSupportStatusBadge(this.status, {super.key});

  /// The wire status of the conversation.
  final String status;

  @override
  Widget build(BuildContext context) {
    final bool resolved = status == 'resolved';

    return MSBadge(
      trans(
        resolved
            ? 'magic_starter.support.status.resolved'
            : 'magic_starter.support.status.open',
      ),
      tone: resolved ? BadgeTone.success : BadgeTone.primary,
    );
  }
}

/// The signed-in user's support conversations: newest activity first, an unread
/// dot on a thread staff answered since it was last opened, and a way to start
/// a new one.
class MagicStarterSupportIndexView
    extends MagicStatefulView<MagicStarterSupportController> {
  const MagicStarterSupportIndexView({super.key});

  @override
  State<MagicStarterSupportIndexView> createState() =>
      _MagicStarterSupportIndexViewState();
}

class _MagicStarterSupportIndexViewState
    extends
        MagicStatefulViewState<
          MagicStarterSupportController,
          MagicStarterSupportIndexView
        >
    with MagicStarterSupportLiveRefresh<MagicStarterSupportIndexView> {
  static const _iconEmpty = Icons.forum_outlined;
  static const _iconError = Icons.error_outline;

  @override
  void onInit() {
    unawaited(refreshSupport());
    startLiveRefresh();
  }

  @override
  void onClose() => stopLiveRefresh();

  @override
  Future<void> refreshSupport() => controller.loadConversations();

  void _openThread(MagicStarterSupportConversation conversation) {
    MagicRoute.to(
      MagicStarterConfig.supportThreadRoute().replaceFirst(
        ':id',
        '${conversation.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('magic_starter.support.index_title'),
      subtitle: trans('magic_starter.support.index_subtitle'),
      actions: [
        MSButton(
          onPressed: () =>
              MagicRoute.to(MagicStarterConfig.supportCreateRoute()),
          child: WText(
            trans('magic_starter.support.new_button'),
            className: 'text-center',
          ),
        ),
      ],
      children: [_buildBody()],
    );
  }

  Widget _buildBody() {
    final List<MagicStarterSupportConversation> conversations =
        controller.conversations;

    // A failed refresh keeps the rows already read, so a blip does not blank the
    // list; only a list that never loaded says so.
    if (conversations.isNotEmpty) return _buildList(conversations);

    return switch (controller.listStatus) {
      MagicStarterSupportReadStatus.loaded => MSEmptyState(
        icon: _iconEmpty,
        title: trans('magic_starter.support.empty_title'),
        description: trans('magic_starter.support.empty_description'),
      ),
      MagicStarterSupportReadStatus.failed ||
      MagicStarterSupportReadStatus.notFound => MSErrorState(
        icon: _iconError,
        title: trans('magic_starter.support.load_error'),
      ),
      MagicStarterSupportReadStatus.idle ||
      MagicStarterSupportReadStatus.loading => _buildSkeleton(),
    };
  }

  Widget _buildSkeleton() {
    return WDiv(
      className: 'flex flex-col gap-3',
      children: [for (var i = 0; i < 3; i++) const MSSkeleton(height: 64)],
    );
  }

  Widget _buildList(List<MagicStarterSupportConversation> conversations) {
    return WDiv(
      className: 'flex flex-col gap-3',
      children: [
        for (final conversation in conversations) _buildRow(conversation),
      ],
    );
  }

  Widget _buildRow(MagicStarterSupportConversation conversation) {
    final DateTime activity =
        conversation.lastActivityAt ?? conversation.createdAt;

    return WAnchor(
      onTap: () => _openThread(conversation),
      child: MSCard(
        child: WDiv(
          className: 'flex flex-row items-center gap-3',
          children: [
            if (conversation.hasUnread)
              WDiv(
                key: ValueKey<String>('support-unread-${conversation.id}'),
                className: 'w-2 h-2 rounded-full bg-primary',
              ),
            WDiv(
              className: 'flex-1 min-w-0 flex flex-col gap-1',
              children: [
                WText(
                  conversation.subject,
                  className: conversation.hasUnread
                      ? 'text-sm font-bold text-fg truncate'
                      : 'text-sm font-medium text-fg truncate',
                ),
                WText(
                  '#${conversation.number} · '
                  '${activity.toCarbon().shortDiffForHumans()}',
                  className: 'text-xs text-fg-muted',
                ),
              ],
            ),
            MagicStarterSupportStatusBadge(conversation.status),
          ],
        ),
      ),
    );
  }
}
