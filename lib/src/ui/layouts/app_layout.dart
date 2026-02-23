import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';
import '../../http/controllers/auth_controller.dart';
import '../widgets/team_selector.dart';

/// Default App Layout for Magic Starter.
///
/// A generic responsive shell with:
/// - Sidebar (Desktop) / Drawer (Mobile)
/// - Header with User/Team info
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
  }

  @override
  void dispose() {
    MagicStarterAppLayout.refreshNotifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = wScreenIs(context, 'lg');
        return Scaffold(
          backgroundColor: wColor(
            context,
            'gray',
            shade: 50,
            darkColorName: 'gray',
            darkShade: 950,
          ),
          drawer: isDesktop ? null : _buildDrawer(context),
          body: SafeArea(
            bottom: false,
            child: WDiv(
              className: 'flex flex-row w-full h-full',
              children: [
                if (isDesktop) _buildSidebar(context),
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
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return WDiv(
      className:
          'w-64 h-full bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700 flex flex-col',
      children: [
        _buildBrand(context),
        const WSpacer(className: 'h-4'),
        _buildTeamSelector(context),
        const WSpacer(className: 'h-2'),
        Expanded(child: _buildNavigation(context)),
        _buildUserMenu(context),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
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
                onItemTap: () => Navigator.of(context).pop(),
              ),
            ),
            _buildUserMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    if (isDesktop) return const SizedBox.shrink();

    return WDiv(
      className:
          'h-16 px-4 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between',
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
        const SizedBox(width: 24), // Balance menu icon
      ],
    );
  }

  Widget _buildBrand(BuildContext context, {bool showClose = false}) {
    return WDiv(
      className:
          'h-14 px-5 flex items-center justify-between border-b border-gray-100 dark:border-gray-800',
      children: [
        WText(
          trans('app.name'),
          className: 'text-lg font-bold text-primary',
        ),
        if (showClose)
          WAnchor(
            onTap: () => Navigator.pop(context),
            child: WDiv(
              className:
                  'w-8 h-8 rounded-lg flex items-center justify-center hover:bg-gray-100 dark:hover:bg-gray-800',
              child: WIcon(
                Icons.close,
                className: 'text-[18px] text-gray-400 dark:text-gray-500',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamSelector(BuildContext context) {
    if (!MagicStarterConfig.hasTeamFeatures()) {
      return const SizedBox.shrink();
    }

    if (MagicStarter.view.has('sidebar.team_selector')) {
      return MagicStarter.view.make('sidebar.team_selector');
    }

    if (MagicStarter.hasTeamResolver) {
      return const MagicStarterTeamSelector();
    }

    return const SizedBox.shrink();
  }

  Widget _buildNavigation(BuildContext context, {VoidCallback? onItemTap}) {
    String currentPath;
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {
      currentPath = '/';
    }

    return WDiv(
      className: 'flex flex-col gap-1',
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
          onTap: () => MagicRoute.to('/settings/profile'),
          onBeforeTap: onItemTap,
          isActive: currentPath == '/settings/profile',
        ),
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
    return WAnchor(
      onTap: () {
        onBeforeTap?.call();
        onTap();
      },
      child: WDiv(
        states: {if (isActive) 'active'},
        className:
            'mx-3 px-3 py-2.5 rounded-lg flex items-center gap-3 duration-150 text-sm font-medium text-gray-600 dark:text-gray-400 active:text-primary active:bg-primary/10 hover:bg-gray-100 dark:hover:bg-gray-800',
        children: [
          WIcon(icon, className: 'text-[20px]'),
          Expanded(
            child: WText(label, className: 'truncate'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    final userName = Auth.user()?.get<String>('name') ?? trans('common.user');
    final userEmail = Auth.user()?.get<String>('email') ?? '';
    final initial = userName.isNotEmpty
        ? userName[0].toUpperCase()
        : trans('common.unknown');

    return WDiv(
      className: 'p-3 border-t border-gray-100 dark:border-gray-800',
      child: WDiv(
        className: 'flex items-center gap-3',
        children: [
          // Avatar
          WDiv(
            className:
                'w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0',
            child: WText(
              initial,
              className: 'text-sm font-bold text-primary',
            ),
          ),
          // Name + Email
          Expanded(
            child: WDiv(
              className: 'flex flex-col min-w-0',
              children: [
                WText(
                  userName,
                  className:
                      'text-sm font-medium text-gray-900 dark:text-white truncate',
                ),
                if (userEmail.isNotEmpty)
                  WText(
                    userEmail,
                    className:
                        'text-xs text-gray-500 dark:text-gray-400 truncate',
                  ),
              ],
            ),
          ),
          // Action Icons
          WDiv(
            className: 'flex items-center gap-1 flex-shrink-0',
            children: [
              WAnchor(
                onTap: () => context.windTheme.toggleTheme(),
                child: WDiv(
                  className:
                      'w-8 h-8 rounded-lg flex items-center justify-center hover:bg-gray-100 dark:hover:bg-gray-800 duration-150',
                  child: WIcon(
                    context.windIsDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    semanticLabel: trans('common.toggle_theme'),
                    className: 'text-[18px] text-gray-400 dark:text-gray-500',
                  ),
                ),
              ),
              WAnchor(
                onTap: () => AuthController.instance.logout(),
                child: WDiv(
                  className:
                      'w-8 h-8 rounded-lg flex items-center justify-center hover:bg-red-50 dark:hover:bg-red-900/20 duration-150',
                  child: WIcon(
                    Icons.logout_outlined,
                    className:
                        'text-[18px] text-gray-400 dark:text-gray-500 hover:text-red-500',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
