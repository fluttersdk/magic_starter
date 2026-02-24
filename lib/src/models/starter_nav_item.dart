import 'package:flutter/widgets.dart';

/// Navigation item model for Magic Starter.
///
/// Apps register these via [MagicStarter.useNavigation] to populate
/// the sidebar, drawer, and bottom navigation bar.
class StarterNavItem {
  /// Icon displayed in the navigation.
  final IconData icon;

  /// Active state icon (optional, falls back to [icon]).
  final IconData? activeIcon;

  /// Translation key for the label (passed through `trans()`).
  final String labelKey;

  /// Route path to navigate to.
  final String path;

  const StarterNavItem({
    required this.icon,
    required this.labelKey,
    required this.path,
    this.activeIcon,
  });
}
