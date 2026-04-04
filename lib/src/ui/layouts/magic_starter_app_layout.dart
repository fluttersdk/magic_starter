import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';
import '../../magic_starter_manager.dart';

import '../widgets/magic_starter_team_selector.dart';
import '../widgets/magic_starter_user_profile_dropdown.dart';
import 'package:magic_notifications/magic_notifications.dart';
import '../widgets/magic_starter_hide_bottom_nav.dart';
import '../widgets/magic_starter_notification_dropdown.dart';

/// Default App Layout for Magic Starter.
///
/// A generic responsive shell with:
/// - Sidebar (Desktop) / Drawer (Mobile)
/// - Header with User/Team info (customizable via [MagicStarter.useHeader])
/// - Navigation items (customizable via [MagicStarter.useNavigation])
/// - Bottom navigation bar for mobile
/// - Content Area
class MagicStarterAppLayout extends StatefulWidget {
  final Widget child;

  /// Static notifier bumped by [AuthRestored] listener to trigger rebuilds.
  static final ValueNotifier<int> refreshNotifier = ValueNotifier(0);

  const MagicStarterAppLayout({super.key, required this.child});

  @override
  State<MagicStarterAppLayout> createState() => _MagicStarterAppLayoutState();
}

class _MagicStarterAppLayoutState extends State<MagicStarterAppLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    MagicStarterAppLayout.refreshNotifier.addListener(_refresh);
    Auth.stateNotifier.addListener(_refresh);

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

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
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

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentPath = _getCurrentPath(context);
    final navConfig = MagicStarter.navigationConfig;
    final hasBottomNav = navConfig != null && navConfig.bottomItems.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = wScreenIs(context, 'lg');

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: wColor(
            context,
            'gray',
            shade: 50,
            darkColorName: 'gray',
            darkShade: 950,
          ),
          drawer: isDesktop ? null : _buildDrawer(context, currentPath),
          body: SafeArea(
            bottom: false,
            child: WDiv(
              className: 'flex flex-row w-full h-full',
              children: [
                if (isDesktop) _buildSidebar(context, currentPath),
                WDiv(
                  className: 'flex-1 flex flex-col h-full overflow-hidden',
                  children: [
                    _buildHeader(context, isDesktop),
                    WDiv(
                      className: 'flex-1 overflow-y-auto',
                      scrollPrimary: true,
                      child: widget.child,
                    ),
                  ],
                ),
              ],
            ),
          ),
          bottomNavigationBar: (!isDesktop &&
                  hasBottomNav &&
                  !MagicStarterHideBottomNav.of(context))
              ? _buildBottomNav(context, currentPath)
              : null,
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Sidebar
  // -------------------------------------------------------------------------

  Widget _buildSidebar(BuildContext context, String currentPath) {
    return WDiv(
      className: '''
                w-64 h-full flex flex-col
                bg-white dark:bg-gray-900
                border-r border-gray-200 dark:border-gray-700
            ''',
      children: [
        _buildBrand(context),
        const WSpacer(className: 'h-4'),
        _buildTeamSelector(context),
        const WSpacer(className: 'h-2'),
        Expanded(child: _buildNavigation(context, currentPath)),
        _buildUserMenu(context),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Drawer
  // -------------------------------------------------------------------------

  Widget _buildDrawer(BuildContext context, String currentPath) {
    return Drawer(
      backgroundColor: wColor(
        context,
        'white',
        darkColorName: 'gray',
        darkShade: 900,
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

    return WDiv(
      className: '''
                h-16 px-4
                bg-white dark:bg-gray-900
                border-b border-gray-200 dark:border-gray-700
                flex items-center justify-between
            ''',
      children: [
        WAnchor(
          onTap: _openDrawer,
          child: WIcon(
            Icons.menu,
            className: 'text-gray-600 dark:text-gray-300',
          ),
        ),
        WText(
          trans('app.name'),
          className: 'font-bold text-lg text-gray-900 dark:text-white',
        ),
        WDiv(
          className: 'flex items-center gap-1',
          children: [
            _buildNotificationBell(),
            const MagicStarterUserProfileDropdown(),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Brand
  // -------------------------------------------------------------------------

  Widget _buildBrand(BuildContext context, {bool showClose = false}) {
    final navTheme = MagicStarter.navigationTheme;
    return WDiv(
      className: '''
                h-14 px-5 flex items-center justify-between
                border-b border-gray-100 dark:border-gray-800
            ''',
      children: [
        navTheme.brandBuilder != null
            ? navTheme.brandBuilder!(context)
            : WText(
                trans('app.name'),
                className: navTheme.brandClassName,
              ),
        if (showClose)
          WAnchor(
            onTap: () => Navigator.pop(context),
            child: WDiv(
              className: '''
                                w-8 h-8 rounded-lg flex items-center justify-center
                                hover:bg-gray-100 dark:hover:bg-gray-800
                            ''',
              child: WIcon(
                Icons.close,
                className: 'text-[18px] text-gray-400 dark:text-gray-500',
              ),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Team Selector
  // -------------------------------------------------------------------------

  Widget _buildTeamSelector(BuildContext context) {
    if (!MagicStarterConfig.hasTeamFeatures()) {
      return const SizedBox.shrink();
    }

    if (MagicStarter.view.has('sidebar.team_selector')) {
      return MagicStarter.view.make('sidebar.team_selector');
    }

    if (MagicStarter.hasTeamResolver) {
      return MagicStarterTeamSelector();
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
  }) {
    final navConfig = MagicStarter.navigationConfig;

    // Registered navigation items from the app.
    if (navConfig != null) {
      return _buildRegisteredNavigation(
        context,
        currentPath,
        navConfig,
        onItemTap: onItemTap,
      );
    }

    // Default fallback: Dashboard + Profile.
    return WDiv(
      className: 'flex flex-col gap-1 py-2',
      children: [
        _navItem(
          context,
          icon: Icons.dashboard_outlined,
          label: trans('nav.dashboard'),
          onTap: () => MagicRoute.to('/'),
          onBeforeTap: onItemTap,
          isActive: currentPath == '/',
        ),
        _navItem(
          context,
          icon: Icons.person_outline,
          label: trans('nav.profile'),
          onTap: () => MagicRoute.to(MagicStarterConfig.profileRoute()),
          onBeforeTap: onItemTap,
          isActive: currentPath == MagicStarterConfig.profileRoute(),
        ),
      ],
    );
  }

  Widget _buildRegisteredNavigation(
    BuildContext context,
    String currentPath,
    MagicStarterNavigationConfig config, {
    VoidCallback? onItemTap,
  }) {
    return WDiv(
      className: 'flex flex-col py-2 gap-1 w-full',
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
          ),
        ),

        // System section (if any)
        if (config.systemItems.isNotEmpty) ...[
          // Divider
          WDiv(
            className: '''
                            my-2 mx-3
                            border-t border-gray-100 dark:border-gray-700
                        ''',
          ),
          // Section header
          WDiv(
            className: 'mx-3 px-3 pb-1',
            child: WText(
              trans('nav.system'),
              className: '''
                                text-xs font-bold uppercase tracking-wide
                                text-gray-400 dark:text-gray-500
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
  }) {
    final navTheme = MagicStarter.navigationTheme;
    return WAnchor(
      onTap: () {
        onBeforeTap?.call();
        onTap();
      },
      child: WDiv(
        states: {if (isActive) 'active'},
        className: '''
                    mx-3 px-3 py-2.5 rounded-lg flex items-center gap-3
                    duration-150 text-sm font-medium
                    text-gray-600 dark:text-gray-400
                    ${navTheme.activeItemClassName}
                    ${navTheme.hoverItemClassName}
                ''',
        children: [
          WIcon(icon, className: 'text-[20px]'),
          Expanded(
            child: WText(label, className: 'truncate'),
          ),
        ],
      ),
    );
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
                bg-white dark:bg-gray-900
                border-t border-gray-200 dark:border-gray-700
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
        className: 'py-2 flex flex-col items-center gap-1',
        children: [
          WIcon(
            isActive ? activeIcon : icon,
            states: isActive ? {'active'} : {},
            className:
                'text-2xl text-gray-400 ${navTheme.bottomNavActiveClassName}',
          ),
          WText(
            label,
            states: isActive ? {'active'} : {},
            className:
                'text-xs text-gray-400 ${navTheme.bottomNavActiveClassName}',
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // User Menu
  // -------------------------------------------------------------------------

  Widget _buildUserMenu(BuildContext context) {
    final userName = Auth.user()?.get<String>('name') ?? trans('common.user');
    final userEmail = Auth.user()?.get<String>('email') ?? '';
    final initial = userName.isNotEmpty
        ? userName[0].toUpperCase()
        : trans('common.unknown');
    final navTheme = MagicStarter.navigationTheme;

    return WDiv(
      className: 'p-3 border-t border-gray-100 dark:border-gray-800',
      child: WDiv(
        className: 'flex items-center gap-3',
        children: [
          // User profile dropdown (reuses the same dropdown menu)
          Expanded(
            child: MagicStarterUserProfileDropdown(
              alignment: PopoverAlignment.topRight,
              triggerBuilder: (context, isOpen, isHovering) => WDiv(
                states: {
                  if (isOpen) 'active',
                  if (isHovering) 'hover',
                },
                className: '''
                  flex items-center gap-3 px-1 py-1
                  rounded-lg cursor-pointer
                  hover:bg-gray-50 dark:hover:bg-gray-800
                  active:bg-gray-100 dark:active:bg-gray-800
                  transition-colors duration-150
                ''',
                children: [
                  // Avatar
                  WDiv(
                    className: '''
                      w-9 h-9 rounded-full ${navTheme.avatarClassName}
                      flex items-center justify-center flex-shrink-0
                    ''',
                    child: WText(
                      initial,
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
                            text-gray-900 dark:text-white truncate
                          ''',
                        ),
                        if (userEmail.isNotEmpty)
                          WText(
                            userEmail,
                            className: '''
                              text-xs
                              text-gray-500 dark:text-gray-400 truncate
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
          // Theme toggle (standalone)
          WAnchor(
            onTap: () => context.windTheme.toggleTheme(),
            child: WDiv(
              className: '''
                w-8 h-8 rounded-lg flex-shrink-0
                flex items-center justify-center
                hover:bg-gray-100 dark:hover:bg-gray-800 duration-150
              ''',
              child: WIcon(
                context.windIsDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                semanticLabel: trans('common.toggle_theme'),
                className: 'text-[18px] text-gray-400 dark:text-gray-500',
              ),
            ),
          ),
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

    return MagicStarterNotificationDropdown(
      notificationStream: Notify.notifications(),
      onMarkAsRead: (id) => Notify.markAsRead(id),
      onMarkAllAsRead: () => Notify.markAllAsRead(),
      onNotificationTap: (notification) =>
          MagicRoute.to(notification.actionUrl ?? '/'),
      onViewAll: () => MagicRoute.to(MagicStarterConfig.notificationsRoute()),
    );
  }
}
