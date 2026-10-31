import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../components/settings_nav_row/index.dart';
import '../components/settings_section/index.dart';

/// The Account group of the settings hub, gating included.
///
/// Renders an [MSSettingsSection] headed `magic_starter.settings.account_section`
/// with the Profile row, whose subtitle joins the signed-in user's name and
/// email. A guest (denied `starter.delete-account`) also gets an upgrade row on
/// the profile route and a sign-in row on the login route, for a guest who
/// already has an account elsewhere.
///
/// The settings hub mounts it, and a host that builds its own settings page
/// places it among the children of its `MSPageScaffold`:
///
/// ```dart
/// MSPageScaffold(
///   title: trans('magic_starter.nav.settings'),
///   children: [
///     MagicStarterSettingsAccountGroup(),
///     if (MagicStarterSettingsSecurityGroup.hasRows)
///       MagicStarterSettingsSecurityGroup(),
///     MagicStarterSettingsPreferencesGroup(),
///   ],
/// )
/// ```
///
/// The Profile row has no gate, so the group always renders. It reads
/// [Auth.user] and [Gate] when it builds and listens to neither, so it shows
/// the current user as of its parent's last rebuild.
class MagicStarterSettingsAccountGroup extends StatelessWidget {
  static const _iconProfile = Icons.person_outline;
  static const _iconGuestUpgrade = Icons.upgrade;
  static const _iconGuestSignIn = Icons.login;

  /// Creates a [MagicStarterSettingsAccountGroup].
  const MagicStarterSettingsAccountGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isGuest = Gate.denies('starter.delete-account');

    return MSSettingsSection(
      header: trans('magic_starter.settings.account_section'),
      children: [
        MSSettingsNavRow(
          icon: _iconProfile,
          title: trans('profile.profile_information'),
          subtitle: _profileSubtitle(),
          to: MagicStarterConfig.profileRoute(),
        ),
        if (isGuest)
          MSSettingsNavRow(
            icon: _iconGuestUpgrade,
            title: trans('magic_starter.guest_upgrade.title'),
            subtitle: trans('magic_starter.guest_upgrade.description'),
            to: MagicStarterConfig.profileRoute(),
          ),
        if (isGuest)
          MSSettingsNavRow(
            icon: _iconGuestSignIn,
            title: trans('auth.sign_in'),
            subtitle: trans('auth.already_have_account'),
            to: MagicStarterConfig.loginRoute(),
          ),
      ],
    );
  }

  /// Joins the user's name and email with a middle dot, skipping an absent or
  /// empty one; null when neither is set.
  String? _profileSubtitle() {
    final user = Auth.user();
    final String? name = user?.get<String>('name');
    final String? email = user?.get<String>('email');
    final parts = [
      if (name != null && name.isNotEmpty) name,
      if (email != null && email.isNotEmpty) email,
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }
}
