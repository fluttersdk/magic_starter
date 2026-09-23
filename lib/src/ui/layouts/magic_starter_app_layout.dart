import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show Drawer, Scaffold, Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';
import '../../magic_starter_manager.dart';
import '../components/avatar/index.dart';
import '../components/team_selector/team_selector.dart';
import '../components/user_profile_dropdown/user_profile_dropdown.dart';
import '../widgets/magic_starter_hide_bottom_nav.dart';
import '../widgets/magic_starter_hide_chrome.dart';

/// Default App Layout for Magic Starter.
///
/// A generic responsive shell with:
/// - Sidebar (Desktop) / Drawer (Mobile)
/// - Header with User/Team info (customizable via [MagicStarter.useHeader])
/// - Navigation items (customizable via [MagicStarter.useNavigation])
/// - Bottom navigation bar for mobile
/// - Content Area
///
/// **Construct this through `MagicStarter.view.makeLayout('layout.app', child:
/// ...)` rather than directly.** That is where the route-keyed `KeyedSubtree`
/// is applied, and this widget no longer carries its own: a host that reaches
/// past the registry gets the unkeyed shell the keying exists to prevent. See
/// `MagicStarterViewRegistry.makeLayout` for what the key is for.
class MagicStarterAppLayout extends StatefulWidget {
  final Widget child;

  /// Static notifier bumped by [AuthRestored] listener to trigger rebuilds.
  static final ValueNotifier<int> refreshNotifier = ValueNotifier(0);

  const MagicStarterAppLayout({super.key, required this.child});

  @override
  State<MagicStarterAppLayout> createState() => _MagicStarterAppLayoutState();
}

class _MagicStarterAppLayoutState extends State<MagicStarterAppLayout> {
  /// Where a collapsible sidebar's state is remembered in Magic's `Cache`.
  static const _collapsedKey = 'magic_starter.sidebar_collapsed';

  /// How long the remembered state is kept.
  ///
  /// The cache has no `forever`, and a write without a TTL takes the store's
  /// own `cache.ttl` (an hour in the shipped config), which would quietly hand
  /// the viewer the default back the next morning.
  static const _collapsedLifetime = Duration(days: 3650);

  static const _expandIcon = Icons.keyboard_double_arrow_right;
  static const _collapseIcon = Icons.keyboard_double_arrow_left;
  static const _avatarPlaceholderIcon = Icons.person_outline;

  /// What the viewer chose for a collapsible sidebar, or `null` until they
  /// have, in which case `sidebarCollapsedByDefault` decides. Held apart from
  /// that default so a host changing its theme still moves a viewer who never
  /// touched the toggle.
  bool? _collapsedChoice;

  @override
  void initState() {
    super.initState();
    MagicStarterAppLayout.refreshNotifier.addListener(_refresh);
    Auth.stateNotifier.addListener(_refresh);

    // Read only by a host that opted in: every read dispatches a cache
    // hit-or-miss event, and a host without the toggle would log a miss on
    // every shell mount. A host that binds no cache keeps the choice for this
    // shell's lifetime only; that is a host decision rather than a failure.
    if (MagicStarter.manager.layoutTheme.sidebarCollapsible &&
        Magic.bound('cache')) {
      final stored = Cache.get(_collapsedKey);
      if (stored is bool) _collapsedChoice = stored;
    }

    // Start notification polling when layout mounts (user is authenticated).
    // startPolling() is idempotent and calls fetchNotifications() immediately.
    if (MagicStarterConfig.hasNotificationFeatures()) {
      try {
        Notify.startPolling();
      } catch (_) {
        // Silently fail in test environments where Magic may not be initialized.
      }
    }
  }

  @override
  void dispose() {
    MagicStarterAppLayout.refreshNotifier.removeListener(_refresh);
    Auth.stateNotifier.removeListener(_refresh);

    // Stop notification polling when layout unmounts (safety net).
    if (MagicStarterConfig.hasNotificationFeatures()) {
      try {
        Notify.stopPolling();
      } catch (_) {
        // Silently fail — dispose must never throw.
      }
    }

    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Records the viewer's choice, and remembers it when a cache is bound.
  ///
  /// The toggle does not wait on this (`unawaited` at the call site): the rail
  /// moves on the `setState`, and the write finishes in the background. The
  /// write is awaited in here rather than dropped, so a store that fails
  /// surfaces as an uncaught error in the zone instead of vanishing.
  Future<void> _setCollapsed(bool collapsed) async {
    setState(() => _collapsedChoice = collapsed);

    if (!Magic.bound('cache')) return;

    await Cache.put(_collapsedKey, collapsed, ttl: _collapsedLifetime);
  }

  String _getCurrentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '/';
    }
  }

  bool _isActive(String path, String currentPath) {
    if (path == '/') return currentPath == '/';
    return currentPath.startsWith(path);
  }

  /// Answers whether the window is at least [name] wide, where [name] is a key
  /// of the Wind theme's `screens` map and [field] is the
  /// [MagicStarterLayoutTheme] field it came from.
  ///
  /// Throws [StateError] when the theme does not carry [name]. `wScreenIs`
  /// resolves an unknown key to null and answers false, so a typo would not
  /// fail: it would pin the shell to its narrow form at every width, dropping
  /// every sidebar label or leaving a 4K window on the drawer for ever, with
  /// nothing to read. Both values were hardcoded before they became fields, so
  /// this is a failure class the configuration introduced and has to close.
  bool _isAtLeast(BuildContext context, String field, String name) {
    final screens = WindTheme.dataOf(context).screens;

    if (!screens.containsKey(name)) {
      final known = screens.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      throw StateError(
        'MagicStarterLayoutTheme.$field is "$name", which the Wind theme does '
        'not carry. Use one of: ${known.map((e) => e.key).join(', ')}.',
      );
    }

    return wScreenIs(context, name);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentPath = _getCurrentPath(context);
    final navConfig = MagicStarter.navigationConfig;
    final layoutTheme = MagicStarter.manager.layoutTheme;
    final hasBottomNav = navConfig != null && navConfig.bottomItems.isNotEmpty;

    // An immersive route keeps the shell mounted (polling, auth listeners, the
    // route key) and gives the window to its child: no bar, no safe-area inset
    // and no scroll container, since a player or a map sizes itself and a
    // scroll view would hand it unbounded height.
    final hideChrome = MagicStarterHideChrome.of(context);

    // Responsive breakpoint via MediaQuery (wScreenIs reads MediaQuery.size),
    // NOT a LayoutBuilder. A LayoutBuilder here makes itself the build-scope
    // root; a setState from the auth/refresh listeners during a route
    // transition then rebuilds dirty widgets in the wrong scope, producing a
    // LayoutBuilder-slot / GlobalKey / RenderFlex exception cascade (worst at
    // narrow widths). MediaQuery.of registers a normal dependency, so width
    // changes still rebuild the shell without the layout-phase build boundary.
    //
    // Which breakpoint is the host's call: the shipped `'lg'` suits a desktop
    // web app, and a rail on a television or a small window needs it lower.
    final isDesktop = _isAtLeast(
      context,
      'navigationBreakpoint',
      layoutTheme.navigationBreakpoint,
    );

    // Compact is the band between the two breakpoints: the sidebar has been
    // chosen over the drawer, but the window is too narrow to spend
    // `sidebarWidth` on it. Equal breakpoints leave the band empty, which is
    // the shipped default.
    //
    // Resolved at every width rather than behind `isDesktop`, so a typo in the
    // field is reported on the window the host is looking at rather than on
    // the one that happens to consult it.
    final isExpanded = _isAtLeast(
      context,
      'sidebarExpandedBreakpoint',
      layoutTheme.sidebarExpandedBreakpoint,
    );
    // A collapsible sidebar can also be compact by the viewer's choice, and
    // only where it could have been expanded: in the band the window decides.
    final canCollapse =
        isDesktop && isExpanded && layoutTheme.sidebarCollapsible;
    final collapsed =
        canCollapse &&
        (_collapsedChoice ?? layoutTheme.sidebarCollapsedByDefault);
    final isCompact = isDesktop && (!isExpanded || collapsed);

    return Scaffold(
      backgroundColor: wColor(
        context,
        layoutTheme.contentBackgroundLightColor,
        shade: layoutTheme.contentBackgroundLightShade,
        darkColorName: layoutTheme.contentBackgroundDarkColor,
        darkShade: layoutTheme.contentBackgroundDarkShade,
      ),
      drawer: (isDesktop || hideChrome)
          ? null
          : _buildDrawer(context, currentPath),
      // The route content is keyed by path so each route mounts as a distinct
      // subtree. Without it the persistent shell reuses the scroll container's
      // child slot across different route views; swapping a scrollable view for
      // another then tears down render objects in a confused order
      // (markNeedsLayout on an already-dirty relayout boundary, double detach)
      // under accumulated navigation. Debug-only asserts, but they surface the
      // red ErrorWidget in dev.
      //
      // That key is applied by MagicStarterViewRegistry.makeLayout rather than
      // here, so a host app replacing this layout keeps it; see that method's
      // doc block. It survives the immersive branch below too, because the key
      // IS `widget.child` rather than something this shell wraps around it.
      body: hideChrome
          ? widget.child
          : SafeArea(
              bottom: false,
              child: WDiv(
                className: 'flex flex-row w-full h-full',
                children: [
                  if (isDesktop)
                    _buildSidebar(
                      context,
                      currentPath,
                      compact: isCompact,
                      collapsible: canCollapse,
                    ),
                  WDiv(
                    className: 'flex-1 flex flex-col h-full overflow-hidden',
                    children: [
                      _buildHeader(context, isDesktop),
                      // The content box is the host's, because only the host
                      // knows the shape of its screens. The shipped
                      // `flex-1 overflow-y-auto` scrolls the child and so
                      // hands it an unbounded height, which a fill-shaped
                      // screen (an `h-full` column with a body that scrolls
                      // inside itself) cannot resolve: it fails to lay out and
                      // renders nothing.
                      WDiv(
                        className: layoutTheme.contentClassName,
                        scrollPrimary: layoutTheme.contentScrollPrimary,
                        child: widget.child,
                      ),
                    ],
                  ),
                ],
              ),
            ),
      bottomNavigationBar:
          (!isDesktop &&
              hasBottomNav &&
              !hideChrome &&
              !MagicStarterHideBottomNav.of(context))
          ? _buildBottomNav(context, currentPath)
          : null,
    );
  }

  // -------------------------------------------------------------------------
  // Sidebar
  // -------------------------------------------------------------------------

  /// Builds the persistent sidebar column.
  ///
  /// [compact] is the icon-rail form. One rule governs it everywhere below:
  /// the rail carries what fits an icon column and drops every text label,
  /// because a label at `sidebarCompactWidth` is clipped rather than
  /// shortened. What a host supplies itself (`brandBuilder`,
  /// `sidebarFooterBuilder`) is passed through untouched, since only the host
  /// knows whether its widget fits.
  ///
  /// [collapsible] adds the viewer's toggle above the user menu.
  Widget _buildSidebar(
    BuildContext context,
    String currentPath, {
    required bool compact,
    required bool collapsible,
  }) {
    final layoutTheme = MagicStarter.manager.layoutTheme;
    return SizedBox(
      width: compact
          ? layoutTheme.sidebarCompactWidth
          : layoutTheme.sidebarWidth,
      child: WDiv(
        className: layoutTheme.sidebarClassName,
        children: [
          _buildBrand(context, compact: compact),
          const WSpacer(className: 'h-4'),
          _buildTeamSelector(context, compact: compact),
          const WSpacer(className: 'h-2'),
          Expanded(
            child: _buildNavigation(context, currentPath, compact: compact),
          ),
          if (MagicStarter.manager.sidebarFooterBuilder != null)
            MagicStarter.manager.sidebarFooterBuilder!(context),
          if (collapsible) _buildCollapseToggle(compact: compact),
          _buildUserMenu(context, compact: compact),
        ],
      ),
    );
  }

  /// The viewer's collapse toggle, drawn as a nav row so it lines up with the
  /// destinations above it in both forms.
  ///
  /// The icon-only form names itself through `semanticLabel`, since nothing
  /// else on it does; the labelled form reads its own text instead of a
  /// second copy of it.
  Widget _buildCollapseToggle({required bool compact}) {
    final navTheme = MagicStarter.navigationTheme;
    final label = trans(
      compact ? 'nav.expand_sidebar' : 'nav.collapse_sidebar',
    );

    return WAnchor(
      onTap: () => unawaited(_setCollapsed(!compact)),
      semanticLabel: compact ? label : null,
      child: WDiv(
        className:
            '''
                    ${_navRowClassName(compact: compact)} mb-2
                    duration-150 text-sm font-medium
                    text-fg-muted
                    ${navTheme.hoverItemClassName}
                    ${navTheme.focusItemClassName}
                ''',
        children: [
          WIcon(
            compact ? _expandIcon : _collapseIcon,
            className: 'text-[20px]',
          ),
          if (!compact) Expanded(child: WText(label, className: 'truncate')),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Drawer
  // -------------------------------------------------------------------------

  Widget _buildDrawer(BuildContext context, String currentPath) {
    final layoutTheme = MagicStarter.manager.layoutTheme;
    return Drawer(
      backgroundColor: wColor(
        context,
        layoutTheme.drawerBackgroundLightColor,
        shade: layoutTheme.drawerBackgroundLightShade,
        darkColorName: layoutTheme.drawerBackgroundDarkColor,
        darkShade: layoutTheme.drawerBackgroundDarkShade,
      ),
      child: SafeArea(
        child: WDiv(
          className: 'flex flex-col h-full',
          children: [
            _buildBrand(context, showClose: true),
            _buildTeamSelector(context),
            const WSpacer(className: 'h-2'),
            Expanded(
              child: _buildNavigation(
                context,
                currentPath,
                onItemTap: () => Navigator.of(context).pop(),
              ),
            ),
            if (MagicStarter.manager.sidebarFooterBuilder != null)
              MagicStarter.manager.sidebarFooterBuilder!(context),
            _buildUserMenu(context),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    // 1. Custom header builder takes full control.
    final headerBuilder = MagicStarter.manager.headerBuilder;
    if (headerBuilder != null) {
      return headerBuilder(context, isDesktop);
    }

    // 2. Default: mobile-only simple header.
    if (isDesktop) return const SizedBox.shrink();

    final layoutTheme = MagicStarter.manager.layoutTheme;
    final navTheme = MagicStarter.navigationTheme;
    return WDiv(
      className: layoutTheme.headerClassName,
      children: [
        Builder(
          builder: (drawerContext) => WAnchor(
            onTap: () => Scaffold.of(drawerContext).openDrawer(),
            child: WIcon(Icons.menu, className: 'text-fg-muted'),
          ),
        ),
        navTheme.brandBuilder != null
            ? navTheme.brandBuilder!(context)
            : WText(trans('app.name'), className: 'font-bold text-lg text-fg'),
        WDiv(
          className: 'flex items-center gap-1',
          children: [_buildNotificationBell(), const MSUserProfileDropdown()],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Brand
  // -------------------------------------------------------------------------

  Widget _buildBrand(
    BuildContext context, {
    bool showClose = false,
    bool compact = false,
  }) {
    final navTheme = MagicStarter.navigationTheme;
    final layoutTheme = MagicStarter.manager.layoutTheme;

    // The app name is a label, so the compact rail keeps only a brand the host
    // built for it, preferring the one built for the rail's width. The bar
    // itself stays, because the rail's first item lines up with the header's
    // baseline on the expanded form and should not jump when the window
    // crosses the breakpoint.
    //
    // Centred, because the compact nav rows centre their icons and a lone brand
    // on a `justify-between` bar sits on the bar's left padding instead, off
    // that line. Appended rather than substituted, so the host's height,
    // padding and border stay; the last `justify-*` wins, and a symmetric
    // horizontal padding keeps the centre where the rail's is.
    //
    // `justify-around` rather than `justify-center`: with one child the two
    // centre it identically, but only a space-distributing row keeps Wind's
    // own child wrapping, which bounds a brand wider than the rail and passes
    // through one that is already a flex child (`flex-1`, an `Expanded`). A
    // `Flexible` added here did the first and broke the second: a `flex-1`
    // brand then sat inside two flex parents and threw on every frame.
    if (compact) {
      final compactBrand =
          navTheme.compactBrandBuilder ?? navTheme.brandBuilder;

      return WDiv(
        className: '${layoutTheme.brandBarClassName} justify-around',
        children: [if (compactBrand != null) compactBrand(context)],
      );
    }

    return WDiv(
      className: layoutTheme.brandBarClassName,
      children: [
        navTheme.brandBuilder != null
            ? navTheme.brandBuilder!(context)
            : WText(trans('app.name'), className: navTheme.brandClassName),
        if (showClose)
          WAnchor(
            onTap: () => Navigator.pop(context),
            child: WDiv(
              className: '''
                                w-8 h-8 rounded-lg flex items-center justify-center
                                hover:bg-gray-100 dark:hover:bg-gray-800
                            ''',
              child: WIcon(Icons.close, className: 'text-[18px] text-fg-muted'),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Team Selector
  // -------------------------------------------------------------------------

  Widget _buildTeamSelector(BuildContext context, {bool compact = false}) {
    if (!MagicStarterConfig.hasTeamFeatures()) {
      return const SizedBox.shrink();
    }

    // A registered override owns its own width; the shell cannot compact a
    // widget it did not build.
    if (MagicStarter.view.has('sidebar.team_selector')) {
      return MagicStarter.view.make('sidebar.team_selector');
    }

    if (MagicStarter.hasTeamResolver) {
      return MSTeamSelector(compact: compact);
    }

    return const SizedBox.shrink();
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  Widget _buildNavigation(
    BuildContext context,
    String currentPath, {
    VoidCallback? onItemTap,
    bool compact = false,
  }) {
    final navConfig = MagicStarter.navigationConfig;

    // Registered navigation items from the app.
    if (navConfig != null) {
      return _buildRegisteredNavigation(
        context,
        currentPath,
        navConfig,
        onItemTap: onItemTap,
        compact: compact,
      );
    }

    // Default fallback: Dashboard + Profile.
    return WDiv(
      className: 'flex flex-col gap-1 py-2 overflow-y-auto',
      children: [
        _navItem(
          context,
          icon: Icons.dashboard_outlined,
          label: trans('nav.dashboard'),
          onTap: () => MagicRoute.to('/'),
          onBeforeTap: onItemTap,
          isActive: currentPath == '/',
          compact: compact,
        ),
        _navItem(
          context,
          icon: Icons.settings_outlined,
          label: trans('nav.settings'),
          onTap: () => MagicRoute.to(MagicStarterConfig.settingsHubRoute()),
          onBeforeTap: onItemTap,
          isActive: _isActive(
            MagicStarterConfig.settingsHubRoute(),
            currentPath,
          ),
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildRegisteredNavigation(
    BuildContext context,
    String currentPath,
    MagicStarterNavigationConfig config, {
    VoidCallback? onItemTap,
    bool compact = false,
  }) {
    return WDiv(
      className: 'flex flex-col py-2 gap-1 w-full overflow-y-auto',
      children: [
        // Main navigation items
        ...config.mainItems.map(
          (item) => _navItem(
            context,
            icon: item.icon,
            label: trans(item.labelKey),
            onTap: () => MagicRoute.to(item.path),
            onBeforeTap: onItemTap,
            isActive: _isActive(item.path, currentPath),
            compact: compact,
          ),
        ),

        // System section (if any)
        if (config.systemItems.isNotEmpty) ...[
          // Divider
          WDiv(
            className: '''
                            my-2 mx-3
                            border-t border-color-border-subtle
                        ''',
          ),
          // Section header. The rule stays the divider on a compact rail: the
          // section is still marked off, and its name is a label.
          if (!compact)
            WDiv(
              className: 'mx-3 px-3 pb-1',
              child: WText(
                trans('nav.system'),
                className: '''
                                text-xs font-bold uppercase tracking-wide
                                text-fg-muted
                            ''',
              ),
            ),
          // System items
          ...config.systemItems.map(
            (item) => _navItem(
              context,
              icon: item.icon,
              label: trans(item.labelKey),
              onTap: () => MagicRoute.to(item.path),
              onBeforeTap: onItemTap,
              isActive: _isActive(item.path, currentPath),
              compact: compact,
            ),
          ),
        ],
      ],
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onBeforeTap,
    bool isActive = false,
    bool compact = false,
  }) {
    final navTheme = MagicStarter.navigationTheme;
    final rowClassName = _navRowClassName(compact: compact);

    return WAnchor(
      onTap: () {
        onBeforeTap?.call();
        onTap();
      },
      child: WDiv(
        states: {if (isActive) 'active'},
        className:
            '''
                    $rowClassName
                    duration-150 text-sm font-medium
                    text-fg-muted
                    ${navTheme.activeItemClassName}
                    ${navTheme.hoverItemClassName}
                    ${navTheme.focusItemClassName}
                ''',
        children: [
          WIcon(icon, className: 'text-[20px]'),
          if (!compact) Expanded(child: WText(label, className: 'truncate')),
        ],
      ),
    );
  }

  /// The geometry of one sidebar row, shared by the destinations and the
  /// collapse toggle so the two cannot drift apart.
  ///
  /// The compact row centres the icon in the rail instead of reserving a label
  /// column: no horizontal padding to push it off centre, and no gap to an
  /// element that is not there.
  static String _navRowClassName({required bool compact}) {
    return compact
        ? 'mx-2 py-2.5 rounded-lg flex items-center justify-center'
        : 'mx-3 px-3 py-2.5 rounded-lg flex items-center gap-3';
  }

  // -------------------------------------------------------------------------
  // Bottom Navigation
  // -------------------------------------------------------------------------

  Widget _buildBottomNav(BuildContext context, String currentPath) {
    final navConfig = MagicStarter.navigationConfig;
    if (navConfig == null || navConfig.bottomItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return WDiv(
      className: '''
                bg-surface
                border-t border-color-border
            ''',
      children: [
        WDiv(
          className: 'flex flex-row justify-between px-4',
          children: navConfig.bottomItems
              .map(
                (item) => _bottomNavItem(
                  context,
                  icon: item.icon,
                  activeIcon: item.activeIcon ?? item.icon,
                  label: trans(item.labelKey),
                  path: item.path,
                  isActive: _isActive(item.path, currentPath),
                ),
              )
              .toList(),
        ),
        // Safe area padding for home indicator
        SizedBox(height: bottomPadding),
      ],
    );
  }

  Widget _bottomNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String path,
    required bool isActive,
  }) {
    final navTheme = MagicStarter.navigationTheme;
    return WAnchor(
      onTap: () => MagicRoute.to(path),
      child: WDiv(
        // The focus className is the same one the sidebar items take: a host
        // that lights a focused destination wants every destination lit, and
        // the bottom bar is where a small window puts them. Wind reads the
        // state off the enclosing WAnchor, so the ring follows the same
        // primary focus the tap does.
        className:
            'py-2 flex flex-col items-center gap-1 '
            '${navTheme.focusItemClassName}',
        children: [
          WIcon(
            isActive ? activeIcon : icon,
            states: isActive ? {'active'} : {},
            className:
                'text-2xl text-fg-muted ${navTheme.bottomNavActiveClassName}',
          ),
          WText(
            label,
            states: isActive ? {'active'} : {},
            className:
                'text-xs text-fg-muted ${navTheme.bottomNavActiveClassName}',
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // User Menu
  // -------------------------------------------------------------------------

  Widget _buildUserMenu(BuildContext context, {bool compact = false}) {
    final user = Auth.user();
    final accountName = user?.get<String>('name')?.trim() ?? '';
    final userName = accountName.isNotEmpty
        ? accountName
        : trans('common.user');
    final userEmail = user?.get<String>('email') ?? '';
    final navTheme = MagicStarter.navigationTheme;

    // The compact rail drops the name and email and falls back to the
    // dropdown's own avatar trigger, the same one the mobile header already
    // mounts. The bell stacks under it rather than beside it, because two
    // controls do not fit the rail's width side by side.
    if (compact) {
      return WDiv(
        className: 'p-3 border-t border-color-border-subtle',
        child: WDiv(
          className: 'flex flex-col items-center gap-2',
          children: [
            const MSUserProfileDropdown(alignment: PopoverAlignment.topRight),
            _buildNotificationBell(),
          ],
        ),
      );
    }

    return WDiv(
      className: 'p-3 border-t border-color-border-subtle',
      child: WDiv(
        className: 'flex items-center gap-3',
        children: [
          // User profile dropdown (reuses the same dropdown menu)
          Expanded(
            child: MSUserProfileDropdown(
              alignment: PopoverAlignment.topRight,
              triggerBuilder: (context, isOpen, isHovering) => WDiv(
                states: {if (isOpen) 'active', if (isHovering) 'hover'},
                className: '''
                  flex items-center gap-3 px-1 py-1
                  rounded-lg cursor-pointer
                  hover:bg-gray-50 dark:hover:bg-gray-800
                  active:bg-gray-100 dark:active:bg-gray-800
                  transition-colors duration-150
                ''',
                children: [
                  // Through [MSAvatar] for the same reason as the compact
                  // trigger: an uploaded photo belongs on the control that is
                  // on screen at all times. With no name to take an initial
                  // from (no session yet, or an account that never set one) it
                  // draws a person glyph rather than the first letter of the
                  // word "User", which belonged to nobody.
                  MSAvatar(
                    photoUrl: user?.get<String>('profile_photo_url'),
                    className:
                        'w-9 h-9 rounded-full ${navTheme.avatarClassName}',
                    fallback: accountName.isEmpty
                        ? WIcon(
                            _avatarPlaceholderIcon,
                            className: navTheme.avatarTextClassName,
                          )
                        : WText(
                            accountName.characters.first.toUpperCase(),
                            className: navTheme.avatarTextClassName,
                          ),
                  ),
                  // Name + Email
                  Expanded(
                    child: WDiv(
                      className: 'flex flex-col min-w-0',
                      children: [
                        WText(
                          userName,
                          className: '''
                            text-sm font-medium
                            text-fg truncate
                          ''',
                        ),
                        if (userEmail.isNotEmpty)
                          WText(
                            userEmail,
                            className: '''
                              text-xs
                              text-fg-muted truncate
                            ''',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Notification bell (gated by feature toggle)
          _buildNotificationBell(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Notification Bell
  // -------------------------------------------------------------------------

  /// Builds the notification bell dropdown, or an empty widget when the
  /// notifications feature is disabled.
  ///
  /// Used in both the desktop sidebar [_buildUserMenu] and the mobile
  /// [_buildHeader] so the configuration is centralised here.
  Widget _buildNotificationBell() {
    if (!MagicStarterConfig.hasNotificationFeatures()) {
      return const SizedBox.shrink();
    }

    // The widget belongs to `magic_notifications` now; its five callbacks are
    // the same ones this shell has always passed.
    return NotificationDropdown(
      notificationStream: Notify.notifications(),
      onMarkAsRead: (id) => Notify.markAsRead(id),
      onMarkAllAsRead: () => Notify.markAllAsRead(),
      onNotificationTap: (notification) =>
          MagicRoute.to(notification.actionUrl ?? '/'),
      onViewAll: () => MagicRoute.to(MagicStarterConfig.notificationsRoute()),
    );
  }
}
