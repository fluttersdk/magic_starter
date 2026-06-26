import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_profile_controller.dart';
import '../../components/settings_nav_row/index.dart';
import '../../components/settings_scaffold/index.dart';
import '../../components/settings_section/index.dart';

/// iOS-style Settings hub --- the drill-down index for the starter.
///
/// Replaces the single long-form profile settings page with a grouped list of
/// [SettingsNavRow]s that push into focused sub-pages. The hub itself performs
/// no API calls: it reads [Auth.user] for the Profile row subtitle and reuses
/// [MagicStarterProfileController] purely so it slots into the same
/// [MagicStatefulView] lifecycle as the other settings views.
///
/// Rows and whole sections are gated two ways, mirroring the source view:
///
/// 1. **Feature toggles** via [MagicStarterConfig] (`hasTwoFactorFeatures`,
///    `hasSessionsFeatures`, `hasNotificationFeatures`, ...). A section with no
///    enabled rows is omitted entirely.
/// 2. **Guest detection** via `Gate.denies('starter.delete-account')`: guests
///    see an upgrade row in the Account group instead of editing affordances.
///
/// Header and footer injection points are exposed through the view registry
/// slots `settings.hub.header` and `settings.hub.footer`.
class MagicStarterSettingsHubView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterSettingsHubView({super.key});

  @override
  State<MagicStarterSettingsHubView> createState() =>
      _MagicStarterSettingsHubViewState();
}

class _MagicStarterSettingsHubViewState extends MagicStatefulViewState<
    MagicStarterProfileController, MagicStarterSettingsHubView> {
  // Icons referenced in build() are hoisted to static fields so Flutter web
  // tree-shaking keeps them (const tear-offs inside build() get dropped).
  static const _iconProfile = Icons.person_outline;
  static const _iconGuestUpgrade = Icons.upgrade;
  static const _iconTwoFactor = Icons.lock_outline;
  static const _iconPassword = Icons.password_outlined;
  static const _iconSessions = Icons.devices_outlined;
  static const _iconAppearance = Icons.palette_outlined;
  static const _iconNotifications = Icons.notifications_outlined;
  static const _iconLanguage = Icons.language_outlined;
  static const _iconTimezone = Icons.schedule_outlined;
  static const _iconNewsletter = Icons.mail_outline;

  /// Whether the current user is a guest (denied account deletion).
  bool get _isGuest => Gate.denies('starter.delete-account');

  // -------------------------------------------------------------------------
  // Section builders --- each returns its rows; the section is only rendered
  // when it has at least one row (never show an empty group).
  // -------------------------------------------------------------------------

  /// Builds the Account group rows: the Profile drill plus, for guests, an
  /// upgrade prompt that reuses the profile route's guest-upgrade flow.
  List<Widget> _accountRows() {
    final user = Auth.user();
    final name = user?.get<String>('name');
    final email = user?.get<String>('email');
    final subtitle = _profileSubtitle(name, email);

    return [
      SettingsNavRow(
        icon: _iconProfile,
        title: trans('profile.profile_information'),
        subtitle: subtitle,
        to: MagicStarterConfig.profileRoute(),
      ),
      if (_isGuest)
        SettingsNavRow(
          icon: _iconGuestUpgrade,
          title: trans('magic_starter.guest_upgrade.title'),
          subtitle: trans('magic_starter.guest_upgrade.description'),
          to: MagicStarterConfig.profileRoute(),
        ),
    ];
  }

  /// Builds the Security group rows.
  ///
  /// Each row honors both gating mechanisms used by the source view: the
  /// relevant feature toggle (Two-Factor / Sessions) AND the matching Gate
  /// ability so guests never see security affordances. Password change has no
  /// feature flag --- it is gated by `starter.update-password` alone, exactly
  /// like the long-form view.
  List<Widget> _securityRows() {
    return [
      if (MagicStarterConfig.hasTwoFactorFeatures() &&
          Gate.allows('starter.manage-two-factor'))
        SettingsNavRow(
          icon: _iconTwoFactor,
          title: trans('profile.two_factor_authentication'),
          value: _twoFactorValue(),
          to: MagicStarterConfig.settingsTwoFactorRoute(),
        ),
      if (Gate.allows('starter.update-password'))
        SettingsNavRow(
          icon: _iconPassword,
          title: trans('profile.update_password'),
          to: MagicStarterConfig.settingsPasswordRoute(),
        ),
      if (MagicStarterConfig.hasSessionsFeatures())
        SettingsNavRow(
          icon: _iconSessions,
          title: trans('profile.browser_sessions'),
          to: MagicStarterConfig.settingsSessionsRoute(),
        ),
    ];
  }

  /// Resolves the trailing On/Off value for the Two-Factor row.
  ///
  /// Reads the user's `two_factor_enabled` flag; the source view tracks the
  /// same state to decide whether to show the enabled or disabled section.
  String _twoFactorValue() {
    final enabled = Auth.user()?.get<bool>('two_factor_enabled') == true;
    return enabled ? trans('common.on') : trans('common.off');
  }

  /// Builds the Preferences group rows. Appearance is always available; the
  /// rest follow their feature toggles.
  List<Widget> _preferencesRows() {
    return [
      SettingsNavRow(
        icon: _iconAppearance,
        title: trans('magic_starter.appearance.title'),
        to: MagicStarterConfig.settingsAppearanceRoute(),
      ),
      if (MagicStarterConfig.hasNotificationFeatures())
        SettingsNavRow(
          icon: _iconNotifications,
          title: trans('magic_starter.notifications.preferences_title'),
          to: MagicStarterConfig.notificationPreferencesRoute(),
        ),
      if (MagicStarterConfig.hasExtendedProfileFeatures())
        SettingsNavRow(
          icon: _iconLanguage,
          title: trans('profile.language_label'),
          to: MagicStarterConfig.settingsLanguageRoute(),
        ),
      if (MagicStarterConfig.hasTimezoneFeatures())
        SettingsNavRow(
          icon: _iconTimezone,
          title: trans('profile.timezone_label'),
          to: MagicStarterConfig.settingsTimezoneRoute(),
        ),
      if (MagicStarterConfig.hasNewsletterFeatures() &&
          Gate.allows('starter.manage-newsletter'))
        SettingsNavRow(
          icon: _iconNewsletter,
          title: trans('magic_starter.newsletter.section_title'),
          to: MagicStarterConfig.settingsNewsletterRoute(),
        ),
    ];
  }

  /// Composes the Profile row subtitle from the available identity fields.
  String? _profileSubtitle(String? name, String? email) {
    final parts = [
      if (name != null && name.isNotEmpty) name,
      if (email != null && email.isNotEmpty) email,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    // 1. Resolve registry slots so host apps can inject around the hub.
    final headerSlot =
        MagicStarter.view.buildSlot('settings.hub', 'header', context);
    final footerSlot =
        MagicStarter.view.buildSlot('settings.hub', 'footer', context);

    // 2. Build each group's rows up front so empty groups can be dropped.
    final accountRows = _accountRows();
    final securityRows = _securityRows();
    final preferencesRows = _preferencesRows();

    // 3. Assemble the scaffold children, omitting any section with no rows.
    return SettingsScaffold(
      title: trans('magic_starter.nav.settings'),
      children: [
        if (headerSlot != null) headerSlot,
        if (accountRows.isNotEmpty)
          SettingsSection(
            header: trans('magic_starter.settings.account_section'),
            children: accountRows,
          ),
        if (securityRows.isNotEmpty)
          SettingsSection(
            header: trans('magic_starter.settings.security_section'),
            children: securityRows,
          ),
        if (preferencesRows.isNotEmpty)
          SettingsSection(
            header: trans('magic_starter.settings.preferences_section'),
            children: preferencesRows,
          ),
        if (footerSlot != null) footerSlot,
      ],
    );
  }
}
