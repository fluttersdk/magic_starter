import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../components/settings_nav_row/index.dart';
import '../components/settings_section/index.dart';

/// The Preferences group of the settings hub, gating included.
///
/// Renders an [MSSettingsSection] headed
/// `magic_starter.settings.preferences_section` with Appearance, which has no
/// gate, followed in this order by the rows whose feature is on: Notifications
/// (`notifications`), Language (`extended_profile`), Timezone (`timezones`),
/// Newsletter (`newsletter` and the `starter.manage-newsletter` ability) and
/// What's new (`releases`).
///
/// The version caption is not part of the group: the hub closes its page with
/// a `MagicStarterAppVersion` when `MagicStarterConfig.hasReleasesFeatures()`,
/// and a host composing its own page places one the same way.
///
/// Appearance keeps the group from ever being empty, so it always renders. It
/// reads the feature flags and [Gate] when it builds and listens to neither.
class MagicStarterSettingsPreferencesGroup extends StatelessWidget {
  static const _iconAppearance = Icons.palette_outlined;
  static const _iconNotifications = Icons.notifications_outlined;
  static const _iconLanguage = Icons.language_outlined;
  static const _iconTimezone = Icons.schedule_outlined;
  static const _iconNewsletter = Icons.mail_outline;
  static const _iconChangelog = Icons.new_releases_outlined;

  /// Creates a [MagicStarterSettingsPreferencesGroup].
  const MagicStarterSettingsPreferencesGroup({super.key});

  @override
  Widget build(BuildContext context) {
    return MSSettingsSection(
      header: trans('magic_starter.settings.preferences_section'),
      children: [
        MSSettingsNavRow(
          icon: _iconAppearance,
          title: trans('magic_starter.appearance.title'),
          to: MagicStarterConfig.settingsAppearanceRoute(),
        ),
        if (MagicStarterConfig.hasNotificationFeatures())
          MSSettingsNavRow(
            icon: _iconNotifications,
            title: trans('magic_starter.notifications.preferences_title'),
            to: MagicStarterConfig.notificationPreferencesRoute(),
          ),
        if (MagicStarterConfig.hasExtendedProfileFeatures())
          MSSettingsNavRow(
            icon: _iconLanguage,
            title: trans('profile.language_label'),
            to: MagicStarterConfig.settingsLanguageRoute(),
          ),
        if (MagicStarterConfig.hasTimezoneFeatures())
          MSSettingsNavRow(
            icon: _iconTimezone,
            title: trans('profile.timezone_label'),
            to: MagicStarterConfig.settingsTimezoneRoute(),
          ),
        if (MagicStarterConfig.hasNewsletterFeatures() &&
            Gate.allows('starter.manage-newsletter'))
          MSSettingsNavRow(
            icon: _iconNewsletter,
            title: trans('magic_starter.newsletter.section_title'),
            to: MagicStarterConfig.settingsNewsletterRoute(),
          ),
        if (MagicStarterConfig.hasReleasesFeatures())
          MSSettingsNavRow(
            icon: _iconChangelog,
            title: trans('magic_starter.releases.title'),
            to: MagicStarterConfig.settingsChangelogRoute(),
          ),
      ],
    );
  }
}
