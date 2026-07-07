import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../settings_section/settings_section.dart';
import 'settings_scaffold.dart';

/// Static preview for [MSSettingsScaffold].
///
/// Renders representative configurations — top-level (no back) and sub-page
/// (with back affordance) — so the dev catalog (`/preview`) can show the full
/// surface in both light and dark mode. One preview class per file is the
/// canonical 4-file contract.
class SettingsScaffoldPreview extends StatelessWidget {
  /// Creates the [MSSettingsScaffold] preview.
  const SettingsScaffoldPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-8 bg-surface',
      children: [
        // 1. Sub-page with back affordance.
        MSSettingsScaffold(
          title: 'Profile',
          subtitle: 'Update your personal information',
          backLabel: 'Settings',
          backFallback: '/settings',
          children: [
            MSSettingsSection(
              header: 'Personal',
              footer: 'Your display name is visible to team members.',
              children: [
                _PreviewRow(label: 'Full Name', value: 'Anilcan Cakir'),
                _PreviewRow(label: 'Email', value: 'anilcan@example.com'),
              ],
            ),
            const MSSettingsSection(
              header: 'Danger',
              children: [
                _PreviewRow(label: 'Delete Account'),
              ],
            ),
          ],
        ),

        // 2. Top-level hub (no back affordance).
        MSSettingsScaffold(
          title: 'Settings',
          children: [
            const MSSettingsSection(
              header: 'Account',
              children: [
                _PreviewRow(label: 'Profile'),
              ],
            ),
            const MSSettingsSection(
              header: 'Security',
              children: [
                _PreviewRow(label: 'Password'),
                _PreviewRow(label: 'Two-Factor Authentication'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Minimal row stub for use inside preview only.
class _PreviewRow extends StatelessWidget {
  final String label;
  final String? value;

  const _PreviewRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className:
          'px-5 py-3.5 min-h-11 flex flex-row items-center justify-between',
      children: [
        WText(label, className: 'text-sm text-fg'),
        if (value != null) WText(value!, className: 'text-sm text-fg-muted'),
      ],
    );
  }
}
