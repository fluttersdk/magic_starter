import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'settings_section.recipe.dart';

/// An iOS inset-grouped settings section.
///
/// Renders an optional uppercase muted [header] caption above the grouped
/// container, the [children] rows edge-to-edge inside a rounded bordered card,
/// and an optional muted [footer] caption below. Hairline dividers are
/// auto-inserted between child rows so each row stays divider-agnostic.
///
/// The container and caption classNames are produced by the recipe functions in
/// `settings_section.recipe.dart` and are theme-overridable via
/// [containerClassName] and [captionClassName].
///
/// ### Example — account section:
/// ```dart
/// MSSettingsSection(
///   header: 'Account',
///   footer: 'Manage your personal information.',
///   children: [
///     MSSettingsNavRow(title: 'Profile', to: '/settings/profile'),
///     MSSettingsNavRow(title: 'Email', to: '/settings/email'),
///   ],
/// )
/// ```
@immutable
class MSSettingsSection extends StatelessWidget {
  /// Optional uppercase muted caption rendered above the container.
  ///
  /// When `null` no header is rendered.
  final String? header;

  /// The row widgets displayed inside the grouped container.
  ///
  /// Hairline dividers are inserted between each pair of adjacent children;
  /// the last child receives no trailing divider.
  final List<Widget> children;

  /// Optional muted caption rendered below the container.
  ///
  /// When `null` no footer is rendered.
  final String? footer;

  /// Optional caller className appended after [settingsSectionContainerRecipe]
  /// for the grouped container.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens refine the recipe
  /// output while every non-overridden base class survives.
  final String? containerClassName;

  /// Optional caller className appended after [settingsSectionCaptionRecipe]
  /// for both the header and footer captions.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens refine the recipe
  /// output while every non-overridden base class survives.
  final String? captionClassName;

  /// Creates a [MSSettingsSection].
  const MSSettingsSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.containerClassName,
    this.captionClassName,
  });

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  String _containerClass() =>
      settingsSectionContainerRecipe(className: containerClassName);

  String _captionClass() =>
      settingsSectionCaptionRecipe(className: captionClassName);

  String _dividerClass() => settingsSectionDividerRecipe();

  /// Interleaves dividers between [children].
  ///
  /// Returns a flat list of [children] with a hairline [WDiv] divider between
  /// each adjacent pair (N children -> N-1 dividers).
  List<Widget> _buildRows() {
    if (children.isEmpty) {
      return const [];
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(WDiv(className: _dividerClass()));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-1.5',
      children: [
        // 1. Optional header caption.
        if (header != null)
          WText(
            header!,
            className: _captionClass(),
          ),

        // 2. Grouped rounded container with interleaved dividers.
        WDiv(
          className: _containerClass(),
          children: _buildRows(),
        ),

        // 3. Optional footer caption.
        if (footer != null)
          WText(
            footer!,
            className: _captionClass(),
          ),
      ],
    );
  }
}
