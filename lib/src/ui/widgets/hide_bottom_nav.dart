import 'package:flutter/widgets.dart';

/// Signals to [MagicStarterAppLayout] that the bottom navigation bar
/// should be hidden for routes nested under this widget.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.group(
///   layout: (child) => HideBottomNav(
///     child: MagicStarter.view.makeLayout('layout.app', child: child),
///   ),
///   layoutId: 'app.fullscreen',
///   routes: () { ... },
/// );
/// ```
class HideBottomNav extends InheritedWidget {
  /// Creates a [HideBottomNav] that hides bottom navigation for its subtree.
  const HideBottomNav({super.key, required super.child});

  /// Returns `true` if a [HideBottomNav] exists above [context].
  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HideBottomNav>() != null;
  }

  @override
  bool updateShouldNotify(HideBottomNav oldWidget) => false;
}
