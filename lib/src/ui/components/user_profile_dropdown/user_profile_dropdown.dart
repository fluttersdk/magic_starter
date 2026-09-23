import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_auth_controller.dart';
import '../avatar/index.dart';

/// A dropdown widget for the user profile.
///
/// Renders the user's avatar, name, and email, along with profile links and
/// a logout action, plus a StreamBuilder unread badge, teamResolver callbacks,
/// avatar theme tokens and a theme toggle.
///
/// ### Example
/// ```dart
/// const MSUserProfileDropdown()
/// // or with custom alignment:
/// const MSUserProfileDropdown(alignment: PopoverAlignment.topRight)
/// ```
class MSUserProfileDropdown extends StatelessWidget {
  /// The popover alignment direction.
  final PopoverAlignment alignment;

  /// Custom builder for the trigger widget.
  ///
  /// When null, renders the default circular avatar with user initial.
  final Widget Function(BuildContext context, bool isOpen, bool isHovering)?
  triggerBuilder;

  const MSUserProfileDropdown({
    super.key,
    this.alignment = PopoverAlignment.bottomRight,
    this.triggerBuilder,
  });

  static const _iconLightMode = Icons.light_mode_outlined;
  static const _iconDarkMode = Icons.dark_mode_outlined;
  static const _iconSignIn = Icons.login;
  static const _iconCreateAccount = Icons.person_add_alt_outlined;
  static const _iconPlaceholder = Icons.person_outline;

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
      // The trigger listens to the session itself. A shell that rebuilds on an
      // auth change mounts this widget const, and a const child is not rebuilt
      // with its parent, so a session that opens after the first frame (a
      // guest session a host deliberately does not await) left the trigger
      // drawing whatever it drew before anyone was signed in.
      triggerBuilder: (context, isOpen, isHovering) => MagicBuilder<int>(
        listenable: Auth.stateNotifier,
        builder: (_) =>
            triggerBuilder?.call(context, isOpen, isHovering) ??
            _buildAvatarTrigger(context, isOpen, isHovering),
      ),
      contentBuilder: (context, close) => _buildMenu(context, close),
    );
  }

  Widget _buildAvatarTrigger(
    BuildContext context,
    bool isOpen,
    bool isHovering,
  ) {
    final user = Auth.user();
    final userName = user?.get<String>('name')?.trim() ?? '';
    final navTheme = MagicStarter.navigationTheme;

    // Through [MSAvatar] so the account's photo reaches the one control that
    // is on screen at all times. This trigger drew the initial whatever the
    // account carried, so a person who had uploaded a photo saw it on the
    // profile screen and nowhere else, which reads as the upload not working.
    //
    // `dropdownAvatarClassName` stays on the WDiv that carries `states`, not on
    // the avatar. The avatar takes no states, so moving the theme className
    // inside would silently drop the hover and active branches of a host that
    // themed one: the shipped default has no state variants, so nothing would
    // have shown it. The avatar keeps only the geometry, which is what it needs
    // to clip the photo to the same circle this div paints.
    return WDiv(
      states: {if (isOpen) 'active', if (isHovering) 'hover'},
      className:
          '''
                w-8 h-8 rounded-full shadow-sm
                ${navTheme.dropdownAvatarClassName}
                cursor-pointer
                transition-all duration-200
                hover:scale-105
                active:scale-95
            ''',
      child: MSAvatar(
        photoUrl: user?.get<String>('profile_photo_url'),
        className: 'w-full h-full rounded-full',
        fallback: _buildAvatarFallback(
          userName,
          navTheme.dropdownAvatarTextClassName,
        ),
      ),
    );
  }

  /// The initial of [userName], or a person glyph when there is none.
  ///
  /// No name is the state before the session is known as well as an account
  /// that never set one. The initial used to come from the word "User" there,
  /// which drew a "U" belonging to nobody and then swapped it for the real
  /// initial once the session opened.
  Widget _buildAvatarFallback(String userName, String className) {
    if (userName.isEmpty) {
      return WIcon(_iconPlaceholder, className: className);
    }

    return WText(userName.characters.first.toUpperCase(), className: className);
  }

  Widget _buildMenu(BuildContext context, VoidCallback close) {
    final userName = Auth.user()?.get<String>('name') ?? trans('common.user');
    final userEmail = Auth.user()?.get<String>('email') ?? '';
    final profileMenuItems =
        MagicStarter.navigationConfig?.profileMenuItems ?? [];

    // A guest session is signed in, so without these the menu offered it
    // profile, settings and logout and nothing that turns it into an account.
    // Sign in reaches the login page (which lets a guest through), and create
    // account reaches the profile page's in-place upgrade, the same door the
    // settings hub's upgrade row opens, so the guest keeps its own data.
    final isGuest = Auth.user()?.get<bool>('is_guest') == true;

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
        if (isGuest) ...[
          _buildMenuItem(
            icon: _iconSignIn,
            label: trans('auth.sign_in'),
            onTap: () {
              close();
              MagicRoute.to(MagicStarterConfig.loginRoute());
            },
          ),
          _buildMenuItem(
            icon: _iconCreateAccount,
            label: trans('magic_starter.titles.register'),
            onTap: () {
              close();
              MagicRoute.to(MagicStarterConfig.profileRoute());
            },
          ),
          WDiv(
            className: 'h-[1px] bg-gray-200 dark:bg-gray-700 my-1 mx-2 w-full',
          ),
        ],
        WDiv(
          className: 'flex-1 overflow-y-auto',
          children: [
            _buildMenuItem(
              icon: Icons.settings_outlined,
              label: trans('magic_starter.nav.settings'),
              onTap: () {
                close();
                MagicRoute.to(MagicStarterConfig.settingsHubRoute());
              },
            ),
            _buildMenuItem(
              icon: Icons.person_outline,
              label: trans('auth.profile'),
              onTap: () {
                close();
                MagicRoute.to(MagicStarterConfig.profileRoute());
              },
            ),
            for (final item in profileMenuItems)
              _buildMenuItem(
                icon: item.icon,
                label: trans(item.labelKey),
                onTap: () {
                  close();
                  MagicRoute.to(item.path);
                },
              ),
            if (MagicStarterConfig.hasNotificationFeatures())
              _buildMenuItem(
                icon: Icons.notifications_outlined,
                label: trans('notifications.settings'),
                onTap: () {
                  close();
                  MagicRoute.to(
                    MagicStarterConfig.notificationPreferencesRoute(),
                  );
                },
              ),
            _buildMenuItem(
              icon: context.windIsDark ? _iconLightMode : _iconDarkMode,
              label: trans('common.toggle_theme'),
              onTap: () => context.windTheme.toggleTheme(),
            ),
          ],
        ),
        WDiv(
          className: 'h-[1px] bg-gray-200 dark:bg-gray-700 my-1 mx-2 w-full',
        ),
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
          WDiv(
            className: 'flex-1 min-w-0',
            child: WText(
              label,
              states: {if (isDanger) 'danger'},
              className: '''
                              text-sm font-medium truncate
                              text-gray-900 dark:text-gray-100
                              danger:text-red-600 dark:danger:text-red-500
                          ''',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final customLogout = MagicStarter.manager.onLogout;

    if (customLogout != null) {
      await customLogout();
      return;
    }

    await MagicStarterAuthController.instance.logout();
  }
}
