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
import '../../components/segmented_control/index.dart';
import '../../components/skeleton/index.dart';
import 'magic_starter_support_message_bubble.dart';

/// Keeps a support screen current without the customer reloading it.
///
/// The backend broadcasts `support.conversation.updated` on the private user
/// channel `App.Models.User.{id}`; the screen refetches when it arrives. A 30
/// second poll runs beside it whatever the socket says, so the screen never
/// depends on a socket to be correct: a connected socket is not a subscribed
/// one, and a socket that pings with no channel joined reports itself healthy.
///
/// Shared by the index and the thread view and defined here rather than
/// duplicated in both. It subscribes through [BroadcastListeners] and not
/// through `Echo.private(...).listen(...)` directly: the user channel is shared
/// with the notification bell, and `listen` replaces a same-event handler, so a
/// second owner of the channel would silently deafen the first.
mixin MagicStarterSupportLiveRefresh<T extends StatefulWidget> on State<T> {
  /// How often a screen rereads, socket or not.
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
    _pollTimer = Timer.periodic(pollInterval, (_) => _refresh());

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

/// The display label of a conversation topic.
///
/// `magic_starter.support.topic.<topic>` when the catalogue carries it, the
/// wire value itself for a topic a host added without translating it.
String magicStarterSupportTopicLabel(String topic) {
  final String key = 'magic_starter.support.topic.$topic';

  return Lang.has(key) ? trans(key) : topic;
}

/// A conversation's status as the customer reads it.
///
/// Resolved reads as finished. A `pending` conversation belongs to the AI desk
/// and reads as the AI's, answered or not. An open conversation reads as who
/// owes the next answer when the backend says so (the AI while [awaitingAi],
/// the team while [waitingOnTeam]) and as plain open otherwise; `snoozed` and a
/// status a newer backend adds read as open. Resolved, the AI and the team are
/// soft tinted pills with a leading dot; plain open stays a solid badge.
class MagicStarterSupportStatusBadge extends StatelessWidget {
  const MagicStarterSupportStatusBadge(
    this.status, {
    super.key,
    this.awaitingAi = false,
    this.waitingOnTeam = false,
  });

  /// The wire status of the conversation.
  final String status;

  /// Whether the AI still owes the conversation an answer.
  final bool awaitingAi;

  /// Whether the conversation is waiting for a teammate.
  final bool waitingOnTeam;

  @override
  Widget build(BuildContext context) {
    if (status == 'resolved') {
      return _softPill(
        trans('magic_starter.support.status.resolved'),
        background: 'bg-success-soft',
        foreground: 'text-success-soft-foreground',
      );
    }

    if (awaitingAi || status == 'pending') {
      return _softPill(
        trans('magic_starter.support.status.ai_answering'),
        background: 'bg-ai-soft',
        foreground: 'text-ai-soft-foreground',
      );
    }

    if (waitingOnTeam) {
      return _softPill(
        trans('magic_starter.support.status.team_answering'),
        background: 'bg-warning-soft',
        foreground: 'text-warning-soft-foreground',
      );
    }

    return MSBadge(
      trans('magic_starter.support.status.open'),
      tone: BadgeTone.primary,
    );
  }

  /// A soft tint with a leading dot, the quiet pill the design gives a
  /// conversation that has an owner or an ending.
  static Widget _softPill(
    String label, {
    required String background,
    required String foreground,
  }) {
    return WDiv(
      key: const ValueKey<String>('support-status-pill'),
      className:
          'inline-flex flex-row items-center gap-1.5 rounded-full px-2.5 py-1 '
          '$background',
      children: [
        WIcon(
          Icons.circle,
          key: const ValueKey<String>('support-status-dot'),
          className: 'text-[6px] $foreground',
        ),
        WText(label, className: 'text-xs font-medium $foreground'),
      ],
    );
  }
}

/// The signed-in user's support conversations: newest activity first, split into
/// Open and Resolved, each row previewing the last message behind its sender, an
/// unread dot on a thread answered since it was last opened, and a way to start
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

  /// 0 is the Open tab, 1 the Resolved one.
  int _tab = 0;

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
      // The empty state sizes to its text; the page column would otherwise park
      // it against the left edge.
      MagicStarterSupportReadStatus.loaded => WDiv(
        className: 'w-full flex flex-col items-center',
        child: MSEmptyState(
          icon: _iconEmpty,
          title: trans('magic_starter.support.empty_title'),
          description: trans('magic_starter.support.empty_description'),
        ),
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
    final open = [
      for (final c in conversations)
        if (c.status != 'resolved') c,
    ];
    final resolved = [
      for (final c in conversations)
        if (c.status == 'resolved') c,
    ];
    final shown = _tab == 0 ? open : resolved;

    // A count over the rows loaded so far would undercount while pages remain.
    final bool counted = !controller.hasMoreConversations;
    String label(String key, int n) =>
        counted ? '${trans(key)} · $n' : trans(key);

    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        MSSegmentedControl<int>(
          options: [
            label('magic_starter.support.status.open', open.length),
            label('magic_starter.support.status.resolved', resolved.length),
          ],
          selectedIndex: _tab,
          onChanged: (index) => setState(() => _tab = index),
        ),
        MSCard(
          noPadding: true,
          child: WDiv(
            className: 'flex flex-col',
            children: [
              // An unloaded page may still hold rows for this tab, so the empty
              // claim waits until every page has been read.
              if (shown.isEmpty && !controller.hasMoreConversations)
                MSEmptyState(
                  icon: _iconEmpty,
                  title: trans(
                    _tab == 0
                        ? 'magic_starter.support.empty_open_title'
                        : 'magic_starter.support.empty_resolved_title',
                  ),
                ),
              for (var i = 0; i < shown.length; i++) _buildRow(shown[i], i),
              if (controller.hasMoreConversations) _buildLoadMore(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(MagicStarterSupportConversation conversation, int index) {
    final MagicStarterSupportLastMessage? last = conversation.lastMessage;
    final DateTime activity =
        last?.createdAt ??
        conversation.lastActivityAt ??
        conversation.createdAt;
    final String? topic = conversation.topic;

    return WAnchor(
      onTap: () => _openThread(conversation),
      child: WDiv(
        className:
            'flex flex-row items-center gap-3 p-3.5 lg:p-4 '
            '${index == 0 ? '' : 'border-t border-color-border-subtle'}',
        children: [
          _buildAvatar(last),
          WDiv(
            className: 'flex-1 min-w-0 flex flex-col gap-1',
            children: [
              WDiv(
                className: 'flex flex-row items-center gap-2',
                children: [
                  Flexible(
                    child: WText(
                      conversation.subject,
                      className: conversation.hasUnread
                          ? 'text-sm font-bold text-fg truncate'
                          : 'text-sm font-medium text-fg truncate',
                    ),
                  ),
                  if (topic != null)
                    WDiv(
                      className:
                          'shrink-0 px-1.5 rounded-md border '
                          'border-color-border',
                      child: WText(
                        magicStarterSupportTopicLabel(topic),
                        className: 'text-xs text-fg-muted',
                      ),
                    ),
                ],
              ),
              if (last != null)
                WText(
                  _preview(last),
                  className: conversation.hasUnread
                      ? 'text-sm text-fg truncate'
                      : 'text-sm text-fg-muted truncate',
                ),
            ],
          ),
          WDiv(
            className: 'shrink-0 flex flex-col items-end gap-1.5',
            children: [
              WDiv(
                className: 'flex flex-row items-center gap-2',
                children: [
                  WText(
                    activity.toCarbon().shortDiffForHumans(),
                    className: 'text-xs text-fg-muted',
                  ),
                  if (conversation.hasUnread)
                    WDiv(
                      key: ValueKey<String>(
                        'support-unread-${conversation.id}',
                      ),
                      className: 'w-2 h-2 rounded-full bg-primary',
                    ),
                ],
              ),
              WDiv(
                className: 'hidden lg:flex',
                child: MagicStarterSupportStatusBadge(
                  conversation.status,
                  awaitingAi: conversation.awaitingAi,
                  waitingOnTeam: conversation.waitingOnTeam,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The face of whoever wrote the row's last message; the viewer's own
  /// initials while nothing has been written.
  Widget _buildAvatar(MagicStarterSupportLastMessage? last) {
    final String senderType = last?.senderType ?? 'customer';
    final String? name = senderType == 'customer'
        ? Auth.user()?.get<String>('name')
        : last?.senderName;

    return MagicStarterSupportSenderAvatar(senderType: senderType, name: name);
  }

  /// `Ayse: body`, with the viewer's own lines prefixed "You".
  String _preview(MagicStarterSupportLastMessage last) {
    final String? author = switch (last.senderType) {
      'customer' => trans('magic_starter.support.sender.customer'),
      'ai' => last.senderName ?? trans('magic_starter.support.sender.ai'),
      'staff' => last.senderName ?? trans('magic_starter.support.sender.staff'),
      _ => null,
    };

    return author == null ? last.bodyPreview : '$author: ${last.bodyPreview}';
  }

  Widget _buildLoadMore() {
    return WAnchor(
      onTap: () => unawaited(controller.loadMoreConversations()),
      child: WDiv(
        className:
            'flex items-center justify-center p-3.5 '
            'border-t border-color-border-subtle',
        child: WText(
          trans(
            controller.isLoadingMoreConversations
                ? 'magic_starter.support.loading_more'
                : 'magic_starter.support.load_more',
          ),
          className: 'text-sm text-fg-muted',
        ),
      ),
    );
  }
}
