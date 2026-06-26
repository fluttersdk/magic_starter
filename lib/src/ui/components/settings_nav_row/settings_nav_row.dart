import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'settings_nav_row.recipe.dart';

/// A drill-navigation row for iOS-style grouped settings lists.
///
/// Combines a leading icon tile, a title / optional subtitle column, an
/// optional trailing value label, and a fixed trailing chevron
/// (`Icons.chevron_right`). Tapping the whole row calls `MagicRoute.push(to)`
/// so the back stack is built and the unified header back can pop.
///
/// ### Anatomy
/// ```
/// [icon-tile]  Title             value  ›
///              subtitle
/// ```
///
/// ### Usage
/// ```dart
/// SettingsNavRow(
///   title: 'Two-Factor',
///   subtitle: 'Secure your account',
///   value: 'On',
///   icon: Icons.lock_outline,
///   to: '/settings/security/two-factor',
/// )
/// ```
///
/// ### Testing
///
/// Pass [onTapOverride] in widget tests to intercept navigation without
/// requiring a live router:
/// ```dart
/// SettingsNavRow(
///   title: 'Profile',
///   to: '/settings/profile',
///   onTapOverride: (path) => capturedPath = path,
/// )
/// ```
@immutable
class SettingsNavRow extends StatelessWidget {
  /// Required row title text.
  final String title;

  /// Optional subtitle displayed below the title in a muted smaller font.
  final String? subtitle;

  /// Optional trailing value label (e.g. "On", "3 devices").
  final String? value;

  /// Optional leading icon shown inside the icon tile.
  ///
  /// When `null` no leading tile is rendered.
  final IconData? icon;

  /// Route path to push when the row is tapped.
  ///
  /// Navigation is performed via `MagicRoute.push(to)` so the pop stack is
  /// preserved and the unified header back can return to the parent.
  final String to;

  /// Test-only tap interceptor.
  ///
  /// When non-null, this callback is invoked with [to] instead of
  /// `MagicRoute.push`. Widget tests inject this to avoid requiring a live
  /// `MagicRouter` instance.
  final void Function(String path)? onTapOverride;

  /// Creates a [SettingsNavRow].
  const SettingsNavRow({
    super.key,
    required this.title,
    required this.to,
    this.subtitle,
    this.value,
    this.icon,
    this.onTapOverride,
  });

  // Exposed for tree-shaking; Icons referenced in build() must be static
  // fields on Flutter web to avoid runtime exclusion.
  static const IconData _chevronRight = Icons.chevron_right;

  void _handleTap() {
    final override = onTapOverride;
    if (override != null) {
      override(to);
      return;
    }
    MagicRoute.push(to);
  }

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: _handleTap,
      child: WDiv(
        className: settingsNavRowRecipe(
          variants: {
            kSettingsNavRowLayoutAxis: kSettingsNavRowLayoutDefault,
          },
        ),
        children: [
          // 1. Optional leading icon tile.
          if (icon != null) ...[
            WDiv(
              className: kSettingsNavRowIconTileClassName,
              child: WIcon(
                icon!,
                className: kSettingsNavRowIconClassName,
              ),
            ),
            const WDiv(className: 'w-3'),
          ],

          // 2. Title + subtitle column (takes remaining space).
          WDiv(
            className: 'flex flex-col flex-1 min-w-0 gap-0.5',
            children: [
              WText(
                title,
                className: kSettingsNavRowTitleClassName,
              ),
              if (subtitle != null)
                WText(
                  subtitle!,
                  className: kSettingsNavRowSubtitleClassName,
                ),
            ],
          ),

          // 3. Optional trailing value text.
          if (value != null) ...[
            const WDiv(className: 'w-2'),
            WText(
              value!,
              className: kSettingsNavRowValueClassName,
            ),
          ],

          // 4. Trailing chevron — always present on a drill row.
          const WDiv(className: 'w-1'),
          const WIcon(
            _chevronRight,
            className: kSettingsNavRowChevronClassName,
          ),
        ],
      ),
    );
  }
}
