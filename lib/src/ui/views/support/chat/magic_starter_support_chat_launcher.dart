import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show Icons, Material, MaterialType;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../facades/magic_starter.dart';
import '../../../../support/support_chat_state.dart';
import '../magic_starter_support_thread_body.dart'
    show MagicStarterSupportControllerRebuild;

/// The button that opens the floating support chat, with a badge counting the
/// conversations answered since the customer last read them.
///
/// Renders nothing, and reads nothing, unless `support_chat` (and with it
/// `support`) is on and a signed-in, non-guest user is present; signing out
/// closes the panel. While visible it reads the conversation list once, when
/// it mounts, and then follows whatever the other support surfaces read: a
/// closed launcher holds no poll.
///
/// The panel (`support.chat_panel` in the view registry) floats at the bottom
/// right of the screen in the app's overlay, [width] by [height] logical
/// pixels, [margin] away from the screen edges wherever the launcher sits. It
/// is non-modal: no barrier, a tap outside does not close it and the page
/// stays interactive. It stays on screen: it is held inside the safe area and
/// its height gives way to the keyboard. Escape closes it; opening moves focus
/// into it and closing hands focus back to the launcher.
class MagicStarterSupportChatLauncher extends StatefulWidget {
  const MagicStarterSupportChatLauncher({
    super.key,
    this.className,
    this.width = 400,
    this.height = 520,
    this.margin = 16,
  });

  /// The trigger's classes, so a host can match its sidebar items. Null uses
  /// a full-width sidebar row.
  final String? className;

  /// The panel's size in logical pixels before the screen clamps it.
  final double width;
  final double height;

  /// The gap in logical pixels the panel keeps from the screen edges.
  final double margin;

  @override
  State<MagicStarterSupportChatLauncher> createState() =>
      _MagicStarterSupportChatLauncherState();
}

class _MagicStarterSupportChatLauncherState
    extends State<MagicStarterSupportChatLauncher>
    with
        MagicStarterSupportControllerRebuild<MagicStarterSupportChatLauncher>,
        WidgetsBindingObserver {
  static const IconData _icon = Icons.chat_bubble_outline;

  /// The trigger when the host passes no [MagicStarterSupportChatLauncher.className].
  static const String _defaultClassName =
      'w-full flex flex-row items-center gap-3 px-3 py-2 rounded-lg '
      'text-sm text-fg hover:bg-surface-container-high '
      'active:bg-surface-container-high';

  /// The badge stops counting here.
  static const int _maxBadge = 9;

  final MagicStarterSupportChatState _chat =
      MagicStarterSupportChatState.instance;
  final OverlayPortalController _portal = OverlayPortalController();
  final FocusNode _triggerFocus = FocusNode(
    debugLabel: 'support chat launcher',
    skipTraversal: true,
  );
  final FocusNode _panelFocus = FocusNode(debugLabel: 'support chat panel');

  /// The notifier subscribed to, held so dispose unsubscribes from that exact
  /// instance: re-binding the guard hands back another one. Null while the
  /// flag is off, so a launcher that renders nothing never reads [Auth].
  ValueListenable<int>? _authState;

  late bool _mayShow = _resolveMayShow();
  bool _listRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (MagicStarterConfig.hasSupportChatFeatures()) {
      _authState = Auth.stateNotifier..addListener(_onAuthChanged);
    }
    _chat.addListener(_onChatChanged);

    // After the frame: the list read notifies the controller's listeners at
    // once, and the portal cannot show before it has built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _readListOnce();
      _syncPortal();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authState?.removeListener(_onAuthChanged);
    _chat.removeListener(_onChatChanged);
    _triggerFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  /// The keyboard, a rotation or a window resize moves the screen edges the
  /// panel is clamped to.
  @override
  void didChangeMetrics() {
    if (mounted && _portal.isShowing) setState(() {});
  }

  bool _resolveMayShow() {
    if (!MagicStarterConfig.hasSupportChatFeatures()) return false;
    if (!Auth.check()) return false;

    return Auth.user()?.get<bool>('is_guest') != true;
  }

  void _onAuthChanged() {
    final bool mayShow = _resolveMayShow();
    if (!mounted || mayShow == _mayShow) return;

    setState(() => _mayShow = mayShow);
    if (!mayShow) {
      _chat.close();
      return;
    }

    _readListOnce();
  }

  void _readListOnce() {
    if (!_mayShow || _listRead) return;

    _listRead = true;
    unawaited(supportController.loadConversations());
  }

  void _onChatChanged() {
    if (!mounted) return;

    _syncPortal();
    setState(() {});
  }

  /// Shows the panel while the chat is open and the launcher may show, and
  /// moves focus with it.
  void _syncPortal() {
    final bool show = _mayShow && _chat.isOpen;
    if (show == _portal.isShowing) return;

    if (show) {
      _portal.show();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _portal.isShowing) _panelFocus.requestFocus();
      });

      return;
    }

    // Focus goes back only when the panel held it; a customer who clicked
    // into the page keeps their place.
    final bool panelHadFocus = _panelFocus.hasFocus;
    _portal.hide();
    if (panelHadFocus) {
      _triggerFocus.traversalDescendants.firstOrNull?.requestFocus();
    }
  }

  int _unreadCount() {
    return supportController.conversations
        .where((conversation) => conversation.hasUnread)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    if (!_mayShow) return const SizedBox.shrink();

    // The layout builder hands over the overlay's size, which the corner
    // placement clamps against.
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: Focus(
        focusNode: _triggerFocus,
        canRequestFocus: false,
        child: _buildTrigger(),
      ),
    );
  }

  Widget _buildTrigger() {
    final String label = trans('magic_starter.support.chat.launcher');
    final int unread = _unreadCount();

    return WAnchor(
      key: const ValueKey<String>('support-chat-launcher'),
      onTap: _chat.toggle,
      semanticLabel: unread == 0
          ? label
          : '$label, ${trans('magic_starter.support.chat.unread', {'count': unread})}',
      child: WDiv(
        states: {if (_chat.isOpen) 'active'},
        className: widget.className ?? _defaultClassName,
        children: [
          WIcon(_icon, className: 'text-lg'),
          Flexible(child: WText(label, className: 'truncate')),
          if (unread > 0)
            WDiv(
              key: const ValueKey<String>('support-chat-unread'),
              className:
                  'h-5 px-1.5 rounded-full bg-primary '
                  'flex items-center justify-center',
              child: WText(
                unread > _maxBadge ? '$_maxBadge+' : '$unread',
                className: 'text-xs font-semibold text-on-primary',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final Rect placement = _placement(View.of(context), info.overlaySize);

    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(left: placement.left, top: placement.top),
        child: SizedBox.fromSize(
          size: placement.size,
          child: Material(
            type: MaterialType.transparency,
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.escape): _chat.close,
              },
              child: Focus(
                focusNode: _panelFocus,
                child: MagicStarter.view.make('support.chat_panel'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The panel's rect in the overlay's coordinates: the bottom right corner of
  /// the room the safe area and the keyboard leave inside [overlay].
  ///
  /// The safe area and the keyboard come from [view], not from the launcher's
  /// [MediaQuery]: a launcher inside a `Scaffold` body sees the keyboard inset
  /// removed, and the panel would then slide under it.
  Rect _placement(FlutterView view, Size overlay) {
    // 1. The room the screen leaves, inside the safe area and the keyboard.
    final MediaQueryData screen = MediaQueryData.fromView(view);
    final double left = screen.padding.left + widget.margin;
    final double right = overlay.width - screen.padding.right - widget.margin;
    final double top = screen.padding.top + widget.margin;
    final double bottom =
        overlay.height -
        screen.padding.bottom -
        screen.viewInsets.bottom -
        widget.margin;
    final Size size = Size(
      math.max(0, math.min(widget.width, right - left)),
      math.max(0, math.min(widget.height, bottom - top)),
    );

    // 2. Pinned to the corner; a room too small for the margins keeps the
    // top left edge rather than a negative offset.
    return Offset(
          math.max(left, right - size.width),
          math.max(top, bottom - size.height),
        ) &
        size;
  }
}
