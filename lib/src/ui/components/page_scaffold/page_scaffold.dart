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
/// ### Docked footer
///
/// With [footer] set, the header and [children] scroll inside an expanded area
/// and the footer sits below it, outside the scroll, in the same
/// [MSPageContainer] width and edge margins. It clears the bottom safe area and
/// rides above the on-screen keyboard (`MediaQuery.viewInsets`), which is what
/// a chat composer needs. A docked layout needs a bounded height, as the app
/// shell provides; without [footer] the layout is the plain scroll view above.
/// Pass [scrollController] to keep a thread pinned to its newest message.
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
  /// When set alongside [backFallback], a `chevron_left` control appears in the
  /// header leading slot and this string is its ACCESSIBLE NAME rather than
  /// visible text: the chevron is icon-only on screen. Tapping it navigates to
  /// [backFallback]. With either argument missing, no back affordance is
  /// rendered.
  final String? backLabel;

  /// The route the back control navigates to, forwarded to [MSPageHeader].
  ///
  /// Required alongside [backLabel] for the control to render: it is the only
  /// destination the control has.
  final String? backFallback;

  /// The page sections to render in the `mt-6 flex flex-col gap-6` children
  /// area below the header.
  final List<Widget> children;

  /// An optional widget docked below the scrolling area, outside the scroll.
  ///
  /// Sits inside the same width and edge margins as the page, clears the bottom
  /// safe area and stays above the keyboard. The container's top and bottom
  /// padding are zeroed, so the footer owns its own vertical breathing room.
  final Widget? footer;

  /// An optional controller for the scrolling area.
  ///
  /// Lets a page scroll to the newest content, for instance a message thread
  /// that keeps to the bottom.
  final ScrollController? scrollController;

  /// Creates a [MSPageScaffold].
  const MSPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.backLabel,
    this.backFallback,
    this.footer,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // 1. The scrolling area: header plus children in the shared page geometry.
    final Widget scrollArea = SingleChildScrollView(
      // 2. Each page owns its own implicit scroll controller. Never attach to
      //    the ambient PrimaryScrollController: with RouteTransition.none two
      //    routes are briefly mounted simultaneously and two `primary: true`
      //    views contend for the single controller (dropChild cascade).
      primary: false,
      controller: scrollController,
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
          WDiv(className: pageScaffoldChildrenAreaRecipe(), children: children),
        ],
      ),
    );

    // 6. The page-surface fill wraps the scroll view (which expands to the full
    //    content viewport), so the surface paints the ENTIRE area, not only the
    //    content height. Painting it on the scroll view's child left everything
    //    below the last section showing the layout's grey content background.
    return WDiv(
      className: pageScaffoldSurfaceRecipe(),
      child: footer == null
          ? scrollArea
          : Column(
              children: [
                Expanded(child: scrollArea),
                _DockedFooter(child: footer!),
              ],
            ),
    );
  }
}

/// The footer slot of [MSPageScaffold]: page geometry, safe area, keyboard.
@immutable
class _DockedFooter extends StatelessWidget {
  final Widget child;

  const _DockedFooter({required this.child});

  @override
  Widget build(BuildContext context) {
    // 1. Lift the footer by the keyboard. `MediaQuery.padding` already excludes
    //    the inset the keyboard covers, so the safe area below never doubles it
    //    and a Scaffold that resizes for the keyboard leaves nothing to add.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // 2. Clear the home indicator when no keyboard covers it.
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        // 3. Same width and edge margins as the page; the vertical padding is
        //    zeroed (at every breakpoint the default geometry sets one) because
        //    the footer is not a page section.
        child: MSPageContainer(
          className: 'pt-0 sm:pt-0 pb-0 sm:pb-0',
          child: child,
        ),
      ),
    );
  }
}
