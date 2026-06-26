import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'settings_section.dart';

/// Static preview for [SettingsSection].
///
/// Renders a representative set of configurations in a scrollable column so
/// the dev catalog (`/preview`) can show the full surface in both light and
/// dark mode. One preview class per file is the canonical 4-file contract.
class SettingsSectionPreview extends StatelessWidget {
  /// Creates the [SettingsSection] preview.
  const SettingsSectionPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        // 1. Header + two rows + footer.
        const SettingsSection(
          header: 'Account',
          footer: 'Manage your personal information.',
          children: [
            _PreviewRow(label: 'Profile'),
            _PreviewRow(label: 'Email'),
          ],
        ),

        // 2. No header, single child, no footer.
        const SettingsSection(
          children: [
            _PreviewRow(label: 'Sign Out'),
          ],
        ),

        // 3. Header only, three rows.
        const SettingsSection(
          header: 'Security',
          children: [
            _PreviewRow(label: 'Two-Factor Authentication'),
            _PreviewRow(label: 'Password'),
            _PreviewRow(label: 'Active Sessions'),
          ],
        ),

        // 4. Footer only, two rows.
        const SettingsSection(
          footer: 'Appearance settings affect this device only.',
          children: [
            _PreviewRow(label: 'Appearance'),
            _PreviewRow(label: 'Language'),
          ],
        ),
      ],
    );
  }
}

/// Minimal row stub for use inside preview only.
class _PreviewRow extends StatelessWidget {
  final String label;

  const _PreviewRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'px-5 py-3.5 min-h-11',
      child: WText(label, className: 'text-sm text-fg'),
    );
  }
}
