import 'package:flutter/foundation.dart' show ChangeNotifier, visibleForTesting;
import 'package:magic/magic.dart';

/// What the support chat panel shows.
enum MagicStarterSupportChatMode {
  /// The signed-in user's conversations.
  list,

  /// One conversation, [MagicStarterSupportChatState.activeThreadId].
  thread,

  /// The form that opens a new conversation.
  create,
}

/// Whether the support chat panel is open and what it shows, shared by the
/// launcher (which opens and closes it) and the panel (which moves between
/// its modes).
///
/// One per app, so a launcher remounted by a shell that swaps trees finds the
/// panel as it was left. [SessionScoped] and registered with [SessionScope]:
/// a sign-in or a team switch closes the panel and forgets the thread, which
/// belonged to the previous session.
class MagicStarterSupportChatState extends ChangeNotifier
    implements SessionScoped {
  MagicStarterSupportChatState._() {
    SessionScope.register(this);
  }

  static final MagicStarterSupportChatState instance =
      MagicStarterSupportChatState._();

  bool _open = false;
  MagicStarterSupportChatMode _mode = MagicStarterSupportChatMode.list;
  Object? _activeThreadId;

  bool get isOpen => _open;

  /// What the panel shows; kept while it is closed, so reopening it continues
  /// where the customer left.
  MagicStarterSupportChatMode get mode => _mode;

  /// The conversation the panel shows in [MagicStarterSupportChatMode.thread],
  /// null in any other mode.
  Object? get activeThreadId => _activeThreadId;

  void open() {
    if (_open) return;

    _open = true;
    notifyListeners();
  }

  void close() {
    if (!_open) return;

    _open = false;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();

  void showList() => _show(MagicStarterSupportChatMode.list, null);

  void showThread(Object id) => _show(MagicStarterSupportChatMode.thread, id);

  void showCreate() => _show(MagicStarterSupportChatMode.create, null);

  /// Closes the panel and returns it to the list.
  @override
  Future<void> resetForSession() async {
    final bool changed =
        _open ||
        _mode != MagicStarterSupportChatMode.list ||
        _activeThreadId != null;

    _reset();
    if (changed) notifyListeners();
  }

  /// Closes the panel and forgets everything without telling anyone: statics
  /// outlive a test's `Magic.flush()`, and the widgets of the finished test
  /// are torn down after it.
  @visibleForTesting
  static void resetForTesting() => instance._reset();

  void _show(MagicStarterSupportChatMode mode, Object? threadId) {
    if (_mode == mode && _activeThreadId == threadId) return;

    _mode = mode;
    _activeThreadId = threadId;
    notifyListeners();
  }

  void _reset() {
    _open = false;
    _mode = MagicStarterSupportChatMode.list;
    _activeThreadId = null;
  }
}
