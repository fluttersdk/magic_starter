import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'settings_nav_row.dart';

/// Static variant-matrix preview for [MSSettingsNavRow].
///
/// Renders combinations of: with/without icon, with/without subtitle,
/// with/without trailing value — in a scrollable list so the catalog
/// (`/preview`) can show the full surface in light and dark.
class SettingsNavRowPreview extends StatelessWidget {
  /// Creates the [SettingsNavRowPreview].
  const SettingsNavRowPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-4 p-6',
      children: [
        // 1. Title only (no icon, no subtitle, no value).
        WDiv(
          className: 'flex flex-col overflow-hidden rounded-lg '
              'border border-color-border-subtle',
          child: const MSSettingsNavRow(
            title: 'Profile',
            to: '/settings/profile',
          ),
        ),

        // 2. With leading icon and subtitle.
        WDiv(
          className: 'flex flex-col overflow-hidden rounded-lg '
              'border border-color-border-subtle',
          child: const MSSettingsNavRow(
            title: 'Security',
            subtitle: 'Password, 2FA, sessions',
            icon: Icons.security,
            to: '/settings/security',
          ),
        ),

        // 3. With leading icon and trailing value.
        WDiv(
          className: 'flex flex-col overflow-hidden rounded-lg '
              'border border-color-border-subtle',
          child: const MSSettingsNavRow(
            title: 'Two-Factor Auth',
            value: 'On',
            icon: Icons.lock_outline,
            to: '/settings/security/two-factor',
          ),
        ),

        // 4. With icon, subtitle, and value.
        WDiv(
          className: 'flex flex-col overflow-hidden rounded-lg '
              'border border-color-border-subtle',
          child: const MSSettingsNavRow(
            title: 'Active Sessions',
            subtitle: 'Manage where you are signed in',
            value: '3 devices',
            icon: Icons.devices_outlined,
            to: '/settings/security/sessions',
          ),
        ),

        // 5. Multiple rows in a grouped section (edge-to-edge).
        WDiv(
          className: 'flex flex-col overflow-hidden rounded-lg '
              'border border-color-border-subtle',
          children: const [
            MSSettingsNavRow(
              title: 'Appearance',
              icon: Icons.palette_outlined,
              to: '/settings/appearance',
            ),
            MSSettingsNavRow(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              to: '/settings/notifications',
            ),
            MSSettingsNavRow(
              title: 'Language',
              value: 'English',
              icon: Icons.language,
              to: '/settings/language',
            ),
          ],
        ),
      ],
    );
  }
}
