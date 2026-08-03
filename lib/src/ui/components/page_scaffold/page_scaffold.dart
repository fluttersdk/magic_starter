import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../page_container/page_container.dart';
import '../page_header/page_header.dart';
import 'page_scaffold.recipe.dart';

/// **The Shared Page Scaffold**
///
/// The full page treatment for every authenticated screen: a page surface that
/// paints the whole content viewport, its own vertical scroll, the shared
/// [MSPageContainer] geometry, a unified [MSPageHeader], and a
/// `mt-6 flex flex-col gap-6` children area for the page's sections.
///
/// One scaffold for every page, not one per surface. Settings, profile, teams,
/// and notifications each grew their own page chrome, and inside the same shell
/// that read as three different apps: the settings pages centred at one width,
/// the team and notification pages capped at nothing at all and spread the full
/// window, and their `p-4 lg:p-6` padding sat the header a few pixels off from
/// every neighbouring page. The geometry now lives in [MSPageContainer] and
/// comes from the host, so there is nothing left per page to disagree about.
///
/// ### Scroll ownership
///
/// The [SingleChildScrollView] uses `primary: false` so it owns its own
/// implicit scroll controller and never contends with the ambient
/// [PrimaryScrollController] (the same fix applied in `MagicStarterGuestLayout`
/// for RouteTransition.none scenarios).
///
/// ### Example: sub-page with back
/// ```dart
/// MSPageScaffold(
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
/// ### Example: top-level page with a header action
/// ```dart
/// MSPageScaffold(
///   title: 'Notifications',
///   actions: [markAllAsReadButton],
///   children: [MSCard(child: notificationList)],
/// )
/// ```
@immutable
class MSPageScaffold extends StatelessWidget {
  /// Required page title forwarded to [MSPageHeader].
  final String title;

  /// Optional subtitle forwarded to [MSPageHeader].
  final String? subtitle;

  /// Optional trailing header actions forwarded to [MSPageHeader].
  ///
  /// Page-level actions belong in the header, next to the title, rather than in
  /// a bar the page invents for itself.
  final List<Widget>? actions;

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

  /// The page sections to render in the `mt-6 flex flex-col gap-6` children
  /// area below the header.
  final List<Widget> children;

  /// Creates a [MSPageScaffold].
  const MSPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.backLabel,
    this.backFallback,
  });

  @override
  Widget build(BuildContext context) {
    // 1. The page-surface fill wraps the scroll view (which expands to the full
    //    content viewport), so the surface paints the ENTIRE area, not only the
    //    content height. Painting it on the scroll view's child left everything
    //    below the last section showing the layout's grey content background.
    return WDiv(
      className: pageScaffoldSurfaceRecipe(),
      child: SingleChildScrollView(
        // 2. Each page owns its own implicit scroll controller. Never attach to
        //    the ambient PrimaryScrollController: with RouteTransition.none two
        //    routes are briefly mounted simultaneously and two `primary: true`
        //    views contend for the single controller (dropChild cascade).
        primary: false,
        // 3. Width, edge margins, and vertical rhythm come from the host's one
        //    page geometry, shared with every other page in the app.
        child: MSPageContainer(
          children: [
            // 4. Unified page header: back affordance and actions compose here.
            MSPageHeader(
              title: title,
              subtitle: subtitle,
              actions: actions,
              backLabel: backLabel,
              backFallback: backFallback,
            ),

            // 5. Children column with a standard gap between sections.
            WDiv(
              className: pageScaffoldChildrenAreaRecipe(),
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}
