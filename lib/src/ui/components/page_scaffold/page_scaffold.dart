import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
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
/// ### Large title
///
/// With [largeTitle] (or `MagicStarterPageHeaderTheme.largeTitle`), the header
/// renders as [MSPageHeaderSize.large] and collapses into a
/// [MSPageHeaderSize.compact] bar pinned over the top of the page once the
/// large header has scrolled under it, fading back out on the way down. The
/// bar spans the page edge to edge, outside the container, and is unmounted
/// while hidden, so the title and actions exist once in the tree whenever the
/// bar is not on screen. While it is, they exist twice: an action carrying a
/// `GlobalKey` cannot be used here.
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

  /// Whether the header is a large title that collapses into a compact bar on
  /// scroll.
  ///
  /// Null (the default) reads `MagicStarter.pageHeaderTheme.largeTitle`, so a
  /// host turns every scaffold, the starter's own pages included, into large
  /// titles once.
  final bool? largeTitle;

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
    this.largeTitle,
  });

  /// Whether this scaffold uses the large title, resolving the theme default.
  bool get isLargeTitle =>
      largeTitle ?? MagicStarter.pageHeaderTheme.largeTitle;

  /// The page header in [headerSize], keyed when the large-title frame needs
  /// to measure it.
  MSPageHeader _header(MSPageHeaderSize headerSize, {Key? key}) {
    return MSPageHeader(
      key: key,
      title: title,
      subtitle: subtitle,
      actions: actions,
      backLabel: backLabel,
      backFallback: backFallback,
      size: headerSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = isLargeTitle
        ? _LargeTitleFrame(
            compactBar: _header(MSPageHeaderSize.compact),
            scrollAreaBuilder: (Key headerKey) => _buildScrollArea(
              _header(MSPageHeaderSize.large, key: headerKey),
            ),
          )
        : _buildScrollArea(_header(MSPageHeaderSize.regular));

    // The page-surface fill wraps the scroll view (which expands to the full
    // content viewport), so the surface paints the ENTIRE area, not only the
    // content height. Painting it on the scroll view's child left everything
    // below the last section showing the layout's grey content background.
    return WDiv(
      className: pageScaffoldSurfaceRecipe(),
      child: footer == null
          ? content
          : Column(
              children: [
                Expanded(child: content),
                _DockedFooter(child: footer!),
              ],
            ),
    );
  }

  /// The scrolling area: [header] plus the children in the page geometry.
  Widget _buildScrollArea(Widget header) {
    // 1. The scrolling area: header plus children in the shared page geometry.
    return SingleChildScrollView(
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
          header,

          // 5. Children column with a standard gap between sections.
          WDiv(className: pageScaffoldChildrenAreaRecipe(), children: children),
        ],
      ),
    );
  }
}

/// The large-title behaviour of [MSPageScaffold]: watches its own scroll view
/// and fades [compactBar] in over the top once the large header is under it.
@immutable
class _LargeTitleFrame extends StatefulWidget {
  /// The bar shown once the large header has scrolled away.
  final Widget compactBar;

  /// Builds the scroll area around a large header carrying the given key,
  /// which the frame measures to know when the header has gone.
  final Widget Function(Key headerKey) scrollAreaBuilder;

  const _LargeTitleFrame({
    required this.compactBar,
    required this.scrollAreaBuilder,
  });

  @override
  State<_LargeTitleFrame> createState() => _LargeTitleFrameState();
}

class _LargeTitleFrameState extends State<_LargeTitleFrame>
    with SingleTickerProviderStateMixin {
  /// The quiet state change the design calls for, 200 ms ease-out.
  static const Duration _fadeDuration = Duration(milliseconds: 200);

  final GlobalKey _headerKey = GlobalKey();

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _fadeDuration,
  );

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOut,
  );

  bool _collapsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Reduce Motion: the bar swaps instead of fading.
    _fade.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _fadeDuration;
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// Collapses once the large header's bottom edge has passed under the
  /// compact bar, and expands again when it comes back out.
  ///
  /// Measured from the header's render box rather than a fixed scroll offset,
  /// because the header's height and its distance from the top (the host's
  /// page padding, a wrapped two-line title) are not known here.
  bool _onScroll(ScrollNotification notification) {
    // 1. Only this page's own vertical scroll counts: a horizontal carousel or
    //    a nested list inside a section says nothing about the header.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    // 2. Locate the header against the frame.
    final RenderObject? frame = context.findRenderObject();
    final RenderObject? header = _headerKey.currentContext?.findRenderObject();
    if (frame is! RenderBox || header is! RenderBox || !header.attached) {
      return false;
    }

    final double headerBottom = header
        .localToGlobal(Offset(0, header.size.height), ancestor: frame)
        .dy;
    final double barBottom =
        MediaQuery.paddingOf(context).top + MSPageHeader.compactBarHeight;

    // 3. Flip only on a change, so a scroll does not rebuild per frame.
    final bool collapsed = headerBottom <= barBottom;
    if (collapsed != _collapsed) {
      setState(() => _collapsed = collapsed);
      collapsed ? _fade.forward() : _fade.reverse();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.scrollAreaBuilder(_headerKey),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _fade,
            builder: (BuildContext context, Widget? bar) {
              // Unmounted while fully hidden: the title and the actions would
              // otherwise sit in the tree twice, once invisible.
              if (_fade.isDismissed) return const SizedBox.shrink();

              return IgnorePointer(
                ignoring: !_collapsed,
                child: FadeTransition(opacity: _opacity, child: bar),
              );
            },
            child: widget.compactBar,
          ),
        ),
      ],
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
