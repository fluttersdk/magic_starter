import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'settings_row.recipe.dart';

/// A single iOS-style settings list row.
///
/// Provides the standard anatomy shared by all settings rows in an
/// iOS inset-grouped settings layout:
///
/// - Optional leading icon tile (9-unit square, rounded, surface-container-high
///   background) wrapping a [WIcon].
/// - Title text (semantic-token driven; tone-controlled via [tone]).
/// - Optional subtitle text below the title.
/// - A flexible [trailing] slot for any widget: `Switch`, `Badge`, value text,
///   or a `Button`. The caller owns the trailing control; [SettingsRow] never
///   hardcodes it.
/// - Minimum 44pt-equivalent height (`min-h-11`), horizontal `px-5 py-3.5`.
/// - Optional [onTap] to make the whole row tappable via [WAnchor].
///
/// The row intentionally has **no internal divider** — the parent
/// [SettingsSection] owns dividers between rows.
///
/// ### Default row (no icon, value trailing):
/// ```dart
/// SettingsRow(
///   title: 'Language',
///   trailing: WText('English', className: 'text-sm text-fg-muted'),
/// )
/// ```
///
/// ### Destructive row (Delete / Sign-out):
/// ```dart
/// SettingsRow(
///   title: 'Delete Account',
///   tone: SettingsRowTone.destructive,
///   onTap: _openDeleteDialog,
/// )
/// ```
///
/// ### Row with leading icon:
/// ```dart
/// SettingsRow(
///   title: 'Notifications',
///   icon: Icons.notifications_none_outlined,
///   trailing: const Switch(value: true, onChanged: null),
/// )
/// ```
@immutable
class SettingsRow extends StatelessWidget {
  // Static icon constants extracted for Flutter web tree-shaking.
  // (No default icon; caller supplies any IconData from Icons.*)

  /// The main label text for the row.
  final String title;

  /// Optional secondary line of text shown below [title].
  final String? subtitle;

  /// Optional [IconData] rendered inside the leading icon tile.
  ///
  /// When `null` the icon tile is omitted entirely.
  final IconData? icon;

  /// Flexible trailing widget slot.
  ///
  /// Pass a `Switch`, `Badge`, value `WText`, or any widget. The slot is not
  /// constrained; the caller is responsible for appropriate sizing.
  final Widget? trailing;

  /// Called when the row is tapped.
  ///
  /// When `null` the row renders as a plain [WDiv] without a [WAnchor] wrapper.
  final VoidCallback? onTap;

  /// Visual tone controlling the title color.
  ///
  /// Defaults to [SettingsRowTone.defaultTone] (`text-fg`).
  /// Use [SettingsRowTone.destructive] for Delete / Sign-out rows.
  final SettingsRowTone tone;

  /// Creates a [SettingsRow].
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.tone = SettingsRowTone.defaultTone,
  });

  /// Resolves the title className from the recipe for the active [tone].
  String _resolveTitleClassName() {
    // The recipe base holds layout tokens; tone-variant holds the text color.
    // We only want the tone's color token for the title, not the full base.
    final toneClass = switch (tone) {
      SettingsRowTone.defaultTone => 'text-fg',
      SettingsRowTone.destructive => 'text-destructive',
    };
    return 'text-base font-medium $toneClass';
  }

  /// Resolves the root container className from the recipe.
  String _resolveContainerClassName() {
    return settingsRowRecipe(
      variants: {kSettingsRowToneAxis: tone.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Assemble row content.
    final rowContent = WDiv(
      className: _resolveContainerClassName(),
      children: [
        // 1a. Optional leading icon tile.
        if (icon != null)
          WDiv(
            className: 'grid place-items-center size-10 rounded-lg '
                'bg-surface-container-high text-fg-muted flex-shrink-0',
            child: WIcon(
              icon!,
              className: 'text-fg-muted text-lg',
            ),
          ),
        // 1b. Title + optional subtitle column.
        WDiv(
          className: 'flex flex-col gap-0.5 flex-1 min-w-0',
          children: [
            WText(
              title,
              className: _resolveTitleClassName(),
            ),
            if (subtitle != null)
              WText(
                subtitle!,
                className: 'text-sm text-fg-muted',
              ),
          ],
        ),
        // 1c. Optional trailing slot.
        if (trailing != null)
          WDiv(
            className: 'flex-shrink-0',
            child: trailing!,
          ),
      ],
    );

    // 2. Wrap in WAnchor only when the row is tappable.
    if (onTap != null) {
      return WAnchor(
        onTap: onTap,
        child: rowContent,
      );
    }

    return rowContent;
  }
}
