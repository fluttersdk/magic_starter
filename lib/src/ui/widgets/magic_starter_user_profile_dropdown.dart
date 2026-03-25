import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';
import '../../http/controllers/magic_starter_auth_controller.dart';

/// A dropdown widget for the user profile.
///
/// Renders the user's avatar, name, and email, along with profile links.
class MagicStarterUserProfileDropdown extends StatelessWidget {
  /// The popover alignment direction.
  ///
  /// Defaults to [PopoverAlignment.bottomRight] for header usage.
  /// Use [PopoverAlignment.topRight] for sidebar bottom placement.
  final PopoverAlignment alignment;

  /// Custom builder for the trigger widget.
  ///
  /// When null, renders the default circular avatar with user initial.
  /// The builder receives the same `isOpen` and `isHovering` states.
  final Widget Function(BuildContext context, bool isOpen, bool isHovering)?
      triggerBuilder;

  /// Creates a user profile dropdown.
  const MagicStarterUserProfileDropdown({
    super.key,
    this.alignment = PopoverAlignment.bottomRight,
    this.triggerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return WPopover(
      alignment: alignment,
      className: '''
                w-72
                bg-white dark:bg-gray-800
                rounded-2xl
                shadow-lg
                mt-2
                border border-gray-100 dark:border-gray-700
            ''',
      triggerBuilder: (context, isOpen, isHovering) =>
          triggerBuilder?.call(context, isOpen, isHovering) ??
          _buildAvatarTrigger(context, isOpen, isHovering),
      contentBuilder: (context, close) => _buildMenu(context, close),
    );
  }

  /// Builds the trigger avatar widget.
  Widget _buildAvatarTrigger(
      BuildContext context, bool isOpen, bool isHovering) {
    final userName = Auth.user()?.get<String>('name') ?? trans('common.user');
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final navTheme = MagicStarter.navigationTheme;

    return WDiv(
      states: {
        if (isOpen) 'active',
        if (isHovering) 'hover',
      },
      className: '''
                w-8 h-8
                rounded-full
                ${navTheme.dropdownAvatarClassName}
                flex items-center justify-center
                cursor-pointer
                shadow-sm
                transition-all duration-200
                hover:scale-105
                active:scale-95
            ''',
      child: WText(
        initial,
        className: 'text-sm font-bold text-white',
      ),
    );
  }

  /// Builds the dropdown menu content.
  Widget _buildMenu(BuildContext context, VoidCallback close) {
    final userName = Auth.user()?.get<String>('name') ?? trans('common.user');
    final userEmail = Auth.user()?.get<String>('email') ?? '';
    final profileMenuItems =
        MagicStarter.navigationConfig?.profileMenuItems ?? [];

    return WDiv(
      className: 'flex flex-col py-2 w-full',
      children: [
        WDiv(
          className:
              'w-full flex flex-col px-4 py-2 mb-1 border-b border-gray-100 dark:border-gray-700',
          children: [
            WText(
              trans('auth.signed_in_as').toUpperCase(),
              className: 'text-[10px] font-bold tracking-widest text-gray-400',
            ),
            const WSpacer(className: 'h-1'),
            WText(
              userName,
              className:
                  'text-sm font-semibold text-gray-900 dark:text-white truncate',
            ),
            if (userEmail.isNotEmpty)
              WText(
                userEmail,
                className: 'text-xs text-gray-500 dark:text-gray-400 truncate',
              ),
          ],
        ),
        const WSpacer(className: 'h-1'),
        _buildMenuItem(
          icon: Icons.person_outline,
          label: trans('auth.profile'),
          onTap: () {
            close();
            MagicRoute.to(MagicStarterConfig.profileRoute());
          },
        ),
        // App-registered profile menu items.
        for (final item in profileMenuItems)
          _buildMenuItem(
            icon: item.icon,
            label: trans(item.labelKey),
            onTap: () {
              close();
              MagicRoute.to(item.path);
            },
          ),

        // Auto-injected notification settings when feature is enabled.
        if (MagicStarterConfig.hasNotificationFeatures())
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            label: trans('notifications.settings'),
            onTap: () {
              close();
              MagicRoute.to(MagicStarterConfig.notificationPreferencesRoute());
            },
          ),
        WDiv(
            className: 'h-[1px] bg-gray-200 dark:bg-gray-700 my-1 mx-2 w-full'),
        _buildMenuItem(
          icon: Icons.logout,
          label: trans('auth.logout'),
          isDanger: true,
          onTap: () {
            close();
            _handleLogout();
          },
        ),
      ],
    );
  }

  /// Builds a single menu item.
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return WAnchor(
      onTap: onTap,
      child: WDiv(
        states: {if (isDanger) 'danger'},
        className: '''
                    mx-2 px-3 py-2.5 w-full
                    rounded-lg
                    hover:bg-gray-50 dark:hover:bg-gray-700/50
                    active:bg-gray-100 dark:active:bg-gray-700
                    flex items-center gap-3
                    cursor-pointer
                    transition-colors duration-150
                ''',
        children: [
          WDiv(
            states: {if (isDanger) 'danger'},
            className: '''
                            w-8 h-8
                            rounded-lg
                            bg-gray-100 dark:bg-gray-700
                            hover:bg-gray-200 dark:hover:bg-gray-600
                            danger:bg-red-50 dark:danger:bg-red-900/20
                            flex items-center justify-center
                            transition-colors duration-150
                        ''',
            child: WIcon(
              icon,
              states: {if (isDanger) 'danger'},
              className: '''
                                text-lg
                                text-gray-600 dark:text-gray-400
                                danger:text-red-600 dark:danger:text-red-500
                            ''',
            ),
          ),
          WText(
            label,
            states: {if (isDanger) 'danger'},
            className: '''
                            text-sm font-medium
                            text-gray-900 dark:text-gray-100
                            danger:text-red-600 dark:danger:text-red-500
                        ''',
          ),
        ],
      ),
    );
  }

  /// Handles the logout action.
  Future<void> _handleLogout() async {
    final customLogout = MagicStarter.manager.onLogout;

    if (customLogout != null) {
      await customLogout();
      return;
    }

    await MagicStarterAuthController.instance.logout();
  }
}
