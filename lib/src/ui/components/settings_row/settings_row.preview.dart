import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'settings_row.dart';
import 'settings_row.recipe.dart';

// Icon constants extracted for Flutter web tree-shaking.
const _kIconNotifications = Icons.notifications_none_outlined;
const _kIconPerson = Icons.person_outline;
const _kIconDelete = Icons.delete_outline;

/// Static tone-matrix preview for [SettingsRow].
///
/// Renders every [SettingsRowTone] in light and dark modes, exercising the
/// leading icon tile, subtitle, trailing slot, and tappable variant so the
/// catalog (`/preview`) can display the full surface.
class SettingsRowPreview extends StatelessWidget {
  /// Creates the settings row tone-matrix preview.
  const SettingsRowPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        // Default tone rows.
        WText(
          'default tone',
          className: 'text-xs font-medium uppercase tracking-wide text-fg-muted px-1',
        ),
        WDiv(
          className: 'bg-surface-container rounded-lg overflow-hidden flex flex-col',
          children: [
            SettingsRow(
              title: 'Profile',
              subtitle: 'Edit your name and email',
              icon: _kIconPerson,
              onTap: () {},
            ),
            WDiv(className: 'h-px bg-color-border-subtle mx-5'),
            SettingsRow(
              title: 'Notifications',
              icon: _kIconNotifications,
              trailing: WText(
                'On',
                className: 'text-sm text-fg-muted',
              ),
              onTap: () {},
            ),
            WDiv(className: 'h-px bg-color-border-subtle mx-5'),
            const SettingsRow(
              title: 'Language',
              trailing: SizedBox(width: 40, height: 20),
            ),
          ],
        ),
        // Destructive tone row.
        WText(
          'destructive tone',
          className: 'text-xs font-medium uppercase tracking-wide text-fg-muted px-1',
        ),
        WDiv(
          className: 'bg-surface-container rounded-lg overflow-hidden flex flex-col',
          children: [
            SettingsRow(
              title: 'Delete Account',
              icon: _kIconDelete,
              tone: SettingsRowTone.destructive,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}
