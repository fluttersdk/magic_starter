import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../facades/magic_starter.dart';
import '../../../../http/controllers/magic_starter_support_controller.dart';
import '../../../../models/magic_starter_support_conversation.dart';
import '../../../../support/support_chat_state.dart';
import '../../../../support/support_sync.dart';
import '../../../components/button/index.dart';
import '../../../components/empty_state/index.dart';
import '../../../components/error_state/index.dart';
import '../../../components/skeleton/index.dart';
import '../magic_starter_support_create_form.dart';
import '../magic_starter_support_index_view.dart';
import '../magic_starter_support_thread_body.dart';

/// The write lock every write from the chat panel takes, so a reply here is
/// never refused because the `/support` page has one in flight.
const String _surface = 'chat';

/// The floating support chat: the signed-in user's conversations, one thread,
/// or the form that opens a new one, as [MagicStarterSupportChatState.mode]
/// says.
///
/// Mounted by `MagicStarterSupportChatLauncher` only while the panel is open,
/// and it fills the box the launcher gives it. While mounted it holds the
/// shared [MagicStarterSupportSync] (one retain, released on dispose), so an
/// open panel rereads on each poll tick and broadcast; it never starts a timer
/// or a listener of its own. Reads go through the keyed thread API, so the
/// thread shown here never moves the page's thread, and mounting it never
/// clears the controller's errors. A write it sends still resets them: the
/// controller holds validation and write errors once for every surface.
///
/// Registered as `support.chat_panel`; a host replacing it through
/// `MagicStarter.view.register` takes over all of the above.
class MagicStarterSupportChatPanel extends StatefulWidget {
  const MagicStarterSupportChatPanel({super.key});

  @override
  State<MagicStarterSupportChatPanel> createState() =>
      _MagicStarterSupportChatPanelState();
}

class _MagicStarterSupportChatPanelState
    extends State<MagicStarterSupportChatPanel>
    with
        MagicStarterSupportControllerRebuild<MagicStarterSupportChatPanel>,
        MagicStarterSupportLiveRefresh<MagicStarterSupportChatPanel> {
  static const _iconBack = Icons.arrow_back;
  static const _iconFullPage = Icons.open_in_new;
  static const _iconClose = Icons.close;
  static const _iconEmpty = Icons.forum_outlined;
  static const _iconError = Icons.error_outline;

  final MagicStarterSupportChatState _chat =
      MagicStarterSupportChatState.instance;

  /// Whether this opening already judged the list for the jump to the create
  /// form, so going back to an empty list does not jump again.
  bool _listJudged = false;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChatChanged);
    startLiveRefresh();

    // After the frame: the read notifies the controller's listeners at once,
    // and the panel mounts in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(supportController.loadConversations());
    });
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    stopLiveRefresh();
    super.dispose();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
  }

  @override
  Future<void> refreshSupport() async {
    await MagicStarterSupportSync.instance.refresh();

    final Object? thread = _chat.activeThreadId;
    if (!mounted || thread == null) return;

    await MagicStarterSupportSync.instance.markSeenOnce(thread);
  }

  void _openFullPage() {
    _chat.close();
    MagicRoute.to(MagicStarterConfig.supportRoute());
  }

  void _onCreated(MagicStarterSupportConversation conversation) {
    _chat.showThread(conversation.id);
    unawaited(supportController.loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: trans('magic_starter.support.index_title'),
      child: WDiv(
        key: const ValueKey<String>('support-chat-panel'),
        className:
            '${MagicStarter.dropdownTheme.panelClassName} '
            'flex flex-col rounded-2xl shadow-lg overflow-hidden',
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final MagicStarterSupportChatMode mode = _chat.mode;

    return WDiv(
      className:
          'flex flex-row items-center gap-1 px-2 py-2 '
          'border-b border-color-border-subtle',
      children: [
        if (mode != MagicStarterSupportChatMode.list)
          _iconButton(
            key: 'support-chat-back',
            icon: _iconBack,
            label: trans('magic_starter.support.back_to_list'),
            onTap: _chat.showList,
          ),
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: WText(
              _title(mode),
              className: 'px-2 text-base font-semibold text-fg truncate',
            ),
          ),
        ),
        _iconButton(
          key: 'support-chat-full-page',
          icon: _iconFullPage,
          label: trans('magic_starter.support.chat.open_full_page'),
          onTap: _openFullPage,
        ),
        _iconButton(
          key: 'support-chat-close',
          icon: _iconClose,
          label: trans('magic_starter.support.chat.close'),
          onTap: _chat.close,
        ),
      ],
    );
  }

  /// The panel's one heading: the thread's subject once it has loaded, the
  /// create title on the form, the desk's name otherwise.
  String _title(MagicStarterSupportChatMode mode) {
    final Object? thread = _chat.activeThreadId;

    return switch (mode) {
      MagicStarterSupportChatMode.thread =>
        (thread == null
                ? null
                : supportController.threadFor(thread)?.subject) ??
            trans('magic_starter.titles.support_thread'),
      MagicStarterSupportChatMode.create => trans(
        'magic_starter.titles.support_create',
      ),
      MagicStarterSupportChatMode.list => trans(
        'magic_starter.support.index_title',
      ),
    };
  }

  Widget _iconButton({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return WAnchor(
      key: ValueKey<String>(key),
      onTap: onTap,
      semanticLabel: label,
      child: WDiv(
        className:
            'size-10 flex items-center justify-center rounded-lg '
            'hover:bg-surface-container-high',
        child: WIcon(icon, className: 'text-lg text-fg-muted'),
      ),
    );
  }

  Widget _buildBody() {
    final Object? thread = _chat.activeThreadId;

    return switch (_chat.mode) {
      MagicStarterSupportChatMode.thread when thread != null => _ChatThread(
        key: ValueKey<String>('support-chat-thread-$thread'),
        id: thread,
      ),
      MagicStarterSupportChatMode.create => MagicStarterSupportCreateForm(
        compact: true,
        surface: _surface,
        onCreated: _onCreated,
      ),
      _ => _buildList(),
    };
  }

  Widget _buildList() {
    final List<MagicStarterSupportConversation> rows =
        supportController.conversations;
    final MagicStarterSupportReadStatus status = supportController.listStatus;

    _judgeEmptyList(rows, status);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(child: _buildListContent(rows, status)),
        ),
        WDiv(
          className: 'p-3 border-t border-color-border-subtle',
          child: MSButton(
            key: const ValueKey<String>('support-chat-new'),
            onPressed: _chat.showCreate,
            fullWidth: true,
            child: WText(
              trans('magic_starter.support.new_button'),
              className: 'text-center',
            ),
          ),
        ),
      ],
    );
  }

  /// A customer with no conversation yet came to open one, so the first list
  /// that loads empty in this opening goes straight to the form.
  void _judgeEmptyList(
    List<MagicStarterSupportConversation> rows,
    MagicStarterSupportReadStatus status,
  ) {
    if (_listJudged || status != MagicStarterSupportReadStatus.loaded) return;

    _listJudged = true;
    if (rows.isNotEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _chat.mode == MagicStarterSupportChatMode.list) {
        _chat.showCreate();
      }
    });
  }

  Widget _buildListContent(
    List<MagicStarterSupportConversation> rows,
    MagicStarterSupportReadStatus status,
  ) {
    // A failed reread keeps the rows already read.
    if (rows.isNotEmpty) {
      return WDiv(
        className: 'flex flex-col',
        children: [for (var i = 0; i < rows.length; i++) _buildRow(rows[i], i)],
      );
    }

    return switch (status) {
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
      MagicStarterSupportReadStatus.loading => WDiv(
        className: 'flex flex-col gap-2 p-3',
        children: [for (var i = 0; i < 3; i++) const MSSkeleton(height: 56)],
      ),
    };
  }

  Widget _buildRow(MagicStarterSupportConversation conversation, int index) {
    final MagicStarterSupportLastMessage? last = conversation.lastMessage;
    final String? topic = conversation.topic;
    final String title = conversation.subject.isEmpty && topic != null
        ? magicStarterSupportTopicLabel(topic)
        : conversation.subject;
    final bool unread = conversation.hasUnread;

    return WAnchor(
      key: ValueKey<String>('support-chat-row-${conversation.id}'),
      onTap: () => _chat.showThread(conversation.id),
      child: WDiv(
        className:
            'flex flex-row items-center gap-3 px-4 py-3 '
            'hover:bg-surface-container-high '
            '${index == 0 ? '' : 'border-t border-color-border-subtle'}',
        children: [
          WDiv(
            className: 'flex-1 min-w-0 flex flex-col gap-1',
            children: [
              WDiv(
                className: 'flex flex-row items-center gap-2',
                children: [
                  Flexible(
                    child: WText(
                      title,
                      className: unread
                          ? 'text-sm font-bold text-fg truncate'
                          : 'text-sm font-medium text-fg truncate',
                    ),
                  ),
                  if (unread)
                    WDiv(
                      key: ValueKey<String>(
                        'support-unread-${conversation.id}',
                      ),
                      className: 'w-2 h-2 rounded-full bg-primary',
                    ),
                ],
              ),
              if (last != null)
                WText(
                  magicStarterSupportLastMessagePreview(last),
                  className: unread
                      ? 'text-sm text-fg truncate'
                      : 'text-sm text-fg-muted truncate',
                ),
            ],
          ),
          MagicStarterSupportStatusBadge(
            conversation.status,
            awaitingAi: conversation.awaitingAi,
            waitingOnTeam: conversation.waitingOnTeam,
          ),
        ],
      ),
    );
  }
}

/// One conversation in the panel, read through the keyed thread API.
///
/// Watched by the shared sync while mounted, so each tick rereads it, and
/// marked seen once it has loaded.
class _ChatThread extends StatefulWidget {
  const _ChatThread({super.key, required this.id});

  final Object id;

  @override
  State<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<_ChatThread>
    with MagicStarterSupportControllerRebuild<_ChatThread> {
  static const _iconError = Icons.error_outline;

  @override
  void initState() {
    super.initState();
    MagicStarterSupportSync.instance.watchThread(widget.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  @override
  void dispose() {
    MagicStarterSupportSync.instance.unwatchThread(widget.id);
    super.dispose();
  }

  Future<void> _open() async {
    await supportController.fetchThread(widget.id);
    if (!mounted) return;

    await MagicStarterSupportSync.instance.markSeenOnce(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final MagicStarterSupportReadStatus status = supportController
        .threadStatusFor(widget.id);
    final MagicStarterSupportConversation? conversation = supportController
        .threadFor(widget.id);

    if (status == MagicStarterSupportReadStatus.notFound) {
      return SingleChildScrollView(
        child: MSErrorState(
          icon: _iconError,
          title: trans('magic_starter.support.not_found_title'),
          action: MSButton(
            intent: ButtonIntent.secondary,
            onPressed: MagicStarterSupportChatState.instance.showList,
            child: WText(
              trans('magic_starter.support.back_to_list'),
              className: 'text-center',
            ),
          ),
        ),
      );
    }

    if (conversation == null) {
      return status == MagicStarterSupportReadStatus.failed
          ? SingleChildScrollView(
              child: MSErrorState(
                icon: _iconError,
                title: trans('magic_starter.support.thread_load_error'),
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(12),
              child: MSSkeleton(height: 160),
            );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: MagicStarterSupportThreadBody(
        conversation: conversation,
        surface: _surface,
      ),
    );
  }
}
