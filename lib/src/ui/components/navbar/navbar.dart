import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'navbar.recipe.dart';

/// A responsive top navigation bar.
///
/// Renders a horizontal bar with an optional [brand] slot on the left,
/// optional [children] (nav links, hidden on mobile via `hidden sm:flex`) in
/// the center, and an optional [trailing] slot on the right.
///
/// ### Example
/// ```dart
/// Navbar(
///   brand: WText('Acme', className: 'text-lg font-bold text-primary'),
///   trailing: const UserProfileDropdown(),
///   children: [
///     WText('Dashboard', className: 'text-sm font-medium text-fg'),
///     WText('Projects', className: 'text-sm font-medium text-fg'),
///   ],
/// )
/// ```
@immutable
class Navbar extends StatelessWidget {
  /// Optional brand/logo widget.
  final Widget? brand;

  /// Optional nav-link children (hidden on mobile).
  final List<Widget> children;

  /// Optional trailing widget (e.g. user profile dropdown).
  final Widget? trailing;

  /// Creates a [Navbar].
  const Navbar({
    super.key,
    required this.children,
    this.brand,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: navbarRootClassName(),
      children: [
        // 1. Brand slot.
        if (brand != null)
          WDiv(className: navbarBrandClassName(), child: brand!),
        // 2. Children (nav links) — responsive.
        if (children.isNotEmpty)
          WDiv(
            className: navbarChildrenClassName(),
            children: children,
          ),
        // 3. Trailing slot.
        if (trailing != null)
          WDiv(className: navbarTrailingClassName(), child: trailing!),
      ],
    );
  }
}
