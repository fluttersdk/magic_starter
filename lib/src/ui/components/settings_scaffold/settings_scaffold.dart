import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
import '../page_header/page_header.dart';
import 'settings_scaffold.recipe.dart';

/// Mobile-first centered sub-page wrapper for Settings screens.
///
/// Wraps a vertically scrollable, max-width-constrained centered column
/// containing a unified [MSPageHeader] (title, subtitle, optional back
/// affordance) and a `mt-6 flex flex-col gap-6` children area intended for
/// [MSSettingsSection] widgets.
///
/// Works identically on mobile and desktop inside `layout.app`: the inner
/// column is always `w-full max-w-2xl mx-auto px-4 lg:px-0` so content is
/// edge-padded on narrow screens and centred with no padding on wide ones.
///
/// The [SingleChildScrollView] uses `primary: false` so it owns its own
/// implicit scroll controller and never contends with the ambient
/// [PrimaryScrollController] (the same fix applied in `MagicStarterGuestLayout`
/// for RouteTransition.none scenarios).
///
/// ### Example — sub-page with back:
/// ```dart
/// MSSettingsScaffold(
///   title: 'Profile',
///   subtitle: 'Update your personal information',
///   backLabel: 'Settings',
///   backFallback: '/settings',
///   children: [
///     MSSettingsSection(header: 'Personal', children: [...]),
///   ],
/// )
/// ```
///
/// ### Example — top-level page (no back):
/// ```dart
/// MSSettingsScaffold(
///   title: 'Settings',
///   children: [
///     MSSettingsSection(header: 'Account', children: [...]),
///   ],
/// )
/// ```
@immutable
class MSSettingsScaffold extends StatelessWidget {
  /// Required page title forwarded to [MSPageHeader].
  final String title;

  /// Optional subtitle forwarded to [MSPageHeader].
  final String? subtitle;

  /// Optional back-affordance label forwarded to [MSPageHeader].
  ///
  /// When set, a chevron + label back control appears in the header leading
  /// slot; tapping it calls `MagicRoute.back(fallback: backFallback)`.
  /// When null (default), no back affordance is rendered.
  final String? backLabel;

  /// Fallback route forwarded to [MSPageHeader]'s `MagicRoute.back` call.
  ///
  /// Only used when [backLabel] is set.
  final String? backFallback;

  /// The [MSSettingsSection] widgets (or other content) to render in the
  /// `mt-6 flex flex-col gap-6` children area below the header.
  final List<Widget> children;

  /// Creates a [MSSettingsScaffold].
  const MSSettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.backLabel,
    this.backFallback,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Each sub-page owns its own implicit scroll controller. Never attach
    //    to the ambient PrimaryScrollController: with RouteTransition.none two
    //    routes are briefly mounted simultaneously and two `primary: true`
    //    views contend for the single controller (dropChild cascade).
    // The page-surface fill wraps the scroll view (which expands to the full
    // content viewport), so the surface paints the ENTIRE area — not only the
    // content height. Painting it on the scroll view's child left everything
    // below the last section showing the layout's grey content background.
    return WDiv(
      className: settingsScaffoldScrollableRecipe(),
      child: SingleChildScrollView(
        primary: false,
        child: WDiv(
          // The cap comes from the host: these pages share the host's shell, so
          // they have to share the width the host caps its own pages at.
          className: settingsScaffoldContainerRecipe(
            maxWidthClassName: MagicStarter.manager.settingsMaxWidthClassName,
          ),
          children: [
            // 2. Unified page header — back affordance is composed here.
            MSPageHeader(
              title: title,
              subtitle: subtitle,
              backLabel: backLabel,
              backFallback: backFallback,
            ),

            // 3. Children column with standard gap between SettingsSections.
            WDiv(
              className: settingsScaffoldChildrenAreaRecipe(),
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}
