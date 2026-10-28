import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

/// Navigation item model for Magic Starter.
///
/// Apps register these via [MagicStarter.useNavigation] to populate
/// the sidebar, drawer, and bottom navigation bar.
class MagicStarterNavItem {
  /// Icon displayed in the navigation.
  final IconData icon;

  /// Active state icon (optional, falls back to [icon]).
  final IconData? activeIcon;

  /// Translation key for the label (passed through `trans()`).
  final String labelKey;

  /// Route path to navigate to.
  final String path;

  /// A live count drawn as a badge on the item, or `null` for no badge.
  ///
  /// The shell listens to the notifier itself, so the host updates the value
  /// and never rebuilds the navigation config: the badge appears, changes and
  /// goes away on its own. It is hidden while the value is `null` or not above
  /// zero, and reads `99+` above 99.
  ///
  /// Drawn in the sidebar, the drawer and the bottom bar; the profile menu
  /// ignores it. The item stays `const` without a badge. One that holds a
  /// notifier is not, so the list carrying it is `final`.
  ///
  /// ```dart
  /// final unticked = ValueNotifier<int?>(null);
  ///
  /// MagicStarterNavItem(
  ///   icon: Icons.shopping_cart_outlined,
  ///   labelKey: 'nav.shopping',
  ///   path: '/shopping',
  ///   badgeCount: unticked,
  /// )
  /// ```
  final ValueListenable<int?>? badgeCount;

  /// Translation key naming the badge for a screen reader.
  ///
  /// Read through `transChoice` with the real count, so a catalogue line such
  /// as `"One line to buy|:count lines to buy"` carries both plural forms. The
  /// sentence is announced after the item's own label, and above 99 it still
  /// says the true count while the badge draws `99+`.
  ///
  /// Defaults to `nav.badge_count`, which the install stub ships.
  final String badgeLabelKey;

  const MagicStarterNavItem({
    required this.icon,
    required this.labelKey,
    required this.path,
    this.activeIcon,
    this.badgeCount,
    this.badgeLabelKey = 'nav.badge_count',
  });
}
