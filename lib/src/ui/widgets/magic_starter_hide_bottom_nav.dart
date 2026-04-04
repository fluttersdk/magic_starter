import 'package:flutter/widgets.dart';

/// Signals to [MagicStarterAppLayout] that the bottom navigation bar
/// should be hidden for routes nested under this widget.
///
/// Wrap a layout with this widget to suppress the mobile bottom navigation
/// bar for specific route groups (e.g., fullscreen views, media players,
/// chat screens).
///
/// ## Usage
///
/// ```dart
/// MagicRoute.group(
///   layout: (child) => MagicStarterHideBottomNav(
///     child: MagicStarter.view.makeLayout('layout.app', child: child),
///   ),
///   layoutId: 'app.fullscreen',
///   routes: () { ... },
/// );
/// ```
///
/// In your layout's `build` method, check whether to show bottom nav:
///
/// ```dart
/// if (!MagicStarterHideBottomNav.of(context)) _buildBottomNav(),
/// ```
class MagicStarterHideBottomNav extends InheritedWidget {
  /// Creates a [MagicStarterHideBottomNav] that hides bottom navigation
  /// for its subtree.
  const MagicStarterHideBottomNav({super.key, required super.child});

  /// Returns `true` if a [MagicStarterHideBottomNav] exists above [context].
  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<MagicStarterHideBottomNav>() !=
        null;
  }

  @override
  bool updateShouldNotify(MagicStarterHideBottomNav oldWidget) => false;
}
