import 'package:flutter/widgets.dart';

/// Signals to `MagicStarterAppLayout` that the whole shell chrome should be
/// suppressed for routes nested under this widget.
///
/// `MagicStarterHideBottomNav` drops one bar. This drops all of it: the
/// sidebar, the drawer, the header and the bottom bar, leaving the route to
/// paint the full window with no safe-area inset and no scroll container of
/// the shell's own. It is the shape a video player, a camera viewfinder or a
/// map wants, and it keeps the shell in the tree: the layout state, its
/// notification polling and its auth listeners all survive the route, which
/// wrapping the route in a bare page instead of a layout would throw away.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.group(
///   layout: (child) => MagicStarterHideChrome(
///     child: MagicStarter.view.makeLayout('layout.app', child: child),
///   ),
///   layoutId: 'app.immersive',
///   routes: () { ... },
/// );
/// ```
///
/// The `layoutId` matters as much as the wrapper: two route groups sharing one
/// id share one layout element, so an immersive group needs its own.
class MagicStarterHideChrome extends InheritedWidget {
  /// Creates a [MagicStarterHideChrome] that hides the shell chrome for its
  /// subtree.
  const MagicStarterHideChrome({super.key, required super.child});

  /// Returns `true` if a [MagicStarterHideChrome] exists above [context].
  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<MagicStarterHideChrome>() !=
        null;
  }

  @override
  bool updateShouldNotify(MagicStarterHideChrome oldWidget) => false;
}
