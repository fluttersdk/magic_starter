import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';
import '../components/settings_nav_row/index.dart';
import '../components/settings_section/index.dart';

/// The Security group of the settings hub, gating included.
///
/// Renders an [MSSettingsSection] headed `magic_starter.settings.security_section`
/// with the rows the current user may reach, in this order:
///
/// 1. Two-factor: the `two_factor` feature and the `starter.manage-two-factor`
///    ability; its trailing value reads On or Off from the user's
///    `two_factor_enabled`.
/// 2. Password: the `starter.update-password` ability alone.
/// 3. Browser sessions: the `sessions` feature.
/// 4. Connected accounts: the `social_login` feature and a bridge registered
///    with `MagicStarter.useSocialAuth`.
///
/// With none of them reachable (a guest on a build without sessions, say) it
/// renders a zero-size box and no header. A zero-size child still takes a gap
/// in a `gap-*` column such as `MSPageScaffold`'s, so a page that wants its old
/// spacing guards the group with [hasRows], as the settings hub does:
///
/// ```dart
/// if (MagicStarterSettingsSecurityGroup.hasRows)
///   MagicStarterSettingsSecurityGroup(),
/// ```
///
/// It reads the feature flags, [Gate], [Auth.user] and the bridge when it
/// builds and listens to none of them.
class MagicStarterSettingsSecurityGroup extends StatelessWidget {
  static const _iconTwoFactor = Icons.lock_outline;
  static const _iconPassword = Icons.password_outlined;
  static const _iconSessions = Icons.devices_outlined;
  static const _iconConnectedAccounts = Icons.link_outlined;

  /// Creates a [MagicStarterSettingsSecurityGroup].
  const MagicStarterSettingsSecurityGroup({super.key});

  /// Whether the current user may reach at least one Security row, read
  /// through the same gates the group renders with.
  static bool get hasRows => _rows().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = _rows();
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return MSSettingsSection(
      header: trans('magic_starter.settings.security_section'),
      children: rows,
    );
  }

  static List<Widget> _rows() {
    return [
      if (MagicStarterConfig.hasTwoFactorFeatures() &&
          Gate.allows('starter.manage-two-factor'))
        MSSettingsNavRow(
          icon: _iconTwoFactor,
          title: trans('profile.two_factor_authentication'),
          value: _twoFactorValue(),
          to: MagicStarterConfig.settingsTwoFactorRoute(),
        ),
      if (Gate.allows('starter.update-password'))
        MSSettingsNavRow(
          icon: _iconPassword,
          title: trans('profile.update_password'),
          to: MagicStarterConfig.settingsPasswordRoute(),
        ),
      if (MagicStarterConfig.hasSessionsFeatures())
        MSSettingsNavRow(
          icon: _iconSessions,
          title: trans('profile.browser_sessions'),
          to: MagicStarterConfig.settingsSessionsRoute(),
        ),
      if (MagicStarterConfig.hasSocialLoginFeatures() &&
          MagicStarter.socialAuth != null)
        MSSettingsNavRow(
          icon: _iconConnectedAccounts,
          title: trans('social.connected_accounts'),
          to: MagicStarterConfig.settingsConnectedAccountsRoute(),
        ),
    ];
  }

  static String _twoFactorValue() {
    final bool enabled = Auth.user()?.get<bool>('two_factor_enabled') == true;

    return enabled ? trans('common.on') : trans('common.off');
  }
}
