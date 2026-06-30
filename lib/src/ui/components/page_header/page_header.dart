import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';

/// Reusable page header for Magic Starter views.
///
/// Full-width header with `border-b` separator, responsive `flex-col sm:flex-row`
/// layout, optional [leading], optional [actions], optional [titleSuffix], and
/// an [inlineActions] flag to force a single-row layout.
///
/// When [backLabel] is set, a unified back affordance is rendered in the leading
/// slot: a `Icons.chevron_left` icon followed by the [backLabel] text. Tapping
/// it calls `MagicRoute.back(fallback: backFallback)`, which tries a native pop
/// first, then the internal history stack, then navigates to [backFallback] if
/// both are empty. When [backLabel] is null (default) the header is unchanged
/// and top-level pages show no back affordance.
///
/// ### Example
/// ```dart
/// PageHeader(
///   title: 'Settings',
///   subtitle: 'Manage your account',
///   actions: [Button(onPressed: save, child: const Text('Save'))],
/// )
///
/// // Sub-page with automatic back:
/// PageHeader(
///   title: 'Profile',
///   backLabel: 'Settings',
///   backFallback: '/settings',
/// )
/// ```
@immutable
class PageHeader extends StatelessWidget {
  // Icon reference extracted as a static const for Flutter web tree-shaking.
  static const IconData _chevronLeft = Icons.chevron_left;

  /// Required title text.
  final String title;

  /// Optional subtitle text displayed below the title.
  final String? subtitle;

  /// Optional leading widget (e.g. back button).
  ///
  /// Takes precedence over the auto-generated back control. When both
  /// [leading] and [backLabel] are provided, [leading] is rendered and
  /// [backLabel] is ignored.
  final Widget? leading;

  /// Optional trailing action widgets.
  final List<Widget>? actions;

  /// Optional widget rendered inline after the title column.
  final Widget? titleSuffix;

  /// When `true`, the outer container uses `flex-row` instead of the default
  /// responsive `flex-col sm:flex-row` stacked layout.
  final bool inlineActions;

  /// Back-affordance label (e.g. `'Settings'`).
  ///
  /// When set and [leading] is null, renders a `chevron_left` icon + this
  /// label as a tappable leading control that calls
  /// `MagicRoute.back(fallback: backFallback)`. When null (default), no back
  /// control is rendered.
  final String? backLabel;

  /// Fallback route passed to `MagicRoute.back({fallback})` when the native pop
  /// stack and internal history are both empty.
  ///
  /// Only used when [backLabel] is set.
  final String? backFallback;

  /// Creates a [PageHeader].
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.titleSuffix,
    this.inlineActions = false,
    this.backLabel,
    this.backFallback,
  });

  /// Builds the back affordance control when [backLabel] is set and no explicit
  /// [leading] widget was provided.
  Widget _buildBackControl(BuildContext context) {
    final fallback = backFallback;
    // Icon-only back control. It sits in the title row's leading slot
    // (`items-center`), so the chevron vertically centres against the
    // title + subtitle block. Navigation goes straight to the parent route
    // (`MagicRoute.to`) rather than popping the navigator: the settings
    // surface uses RouteTransition.none, and popping the instant-swap stack
    // triggered a teardown assertion (`_owner != null`); going to the parent
    // is stable and lands on the correct hub/parent.
    return WAnchor(
      onTap: () {
        if (fallback != null) {
          MagicRoute.to(fallback);
        }
      },
      child: WDiv(
        className: MagicStarter.pageHeaderTheme.backControlClassName,
        child: WIcon(_chevronLeft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the effective leading: an explicit widget takes priority; when
    // backLabel is set, auto-build the unified back control.
    final Widget? effectiveLeading =
        leading ?? (backLabel != null ? _buildBackControl(context) : null);

    return WDiv(
      className: inlineActions
          ? MagicStarter.pageHeaderTheme.containerInlineClassName
          : MagicStarter.pageHeaderTheme.containerClassName,
      children: [
        // 1. Title row: optional leading + title column + optional titleSuffix.
        WDiv(
          className: inlineActions
              ? 'flex flex-row items-center gap-3 flex-1 min-w-0'
              : 'flex flex-row items-center gap-3 sm:flex-1 min-w-0',
          children: [
            if (effectiveLeading != null) effectiveLeading,
            // The title column shrinks for truncation (flex-initial =
            // FlexFit.loose) but does NOT grow, so a `titleSuffix` sits right
            // after the title instead of being pushed to the row's far edge.
            // The title row's own `sm:flex-1` still claims the width so trailing
            // `actions` align right.
            WDiv(
              className: 'flex flex-col gap-1 flex-initial min-w-0',
              children: [
                WText(
                  title,
                  className: MagicStarter.pageHeaderTheme.titleClassName,
                ),
                if (subtitle != null)
                  WText(
                    subtitle!,
                    className: MagicStarter.pageHeaderTheme.subtitleClassName,
                  ),
              ],
            ),
            if (titleSuffix != null)
              WDiv(
                className: 'flex-shrink-0',
                child: titleSuffix!,
              ),
          ],
        ),
        // 2. Optional actions row.
        if (actions != null && actions!.isNotEmpty)
          WDiv(
            className: MagicStarter.pageHeaderTheme.actionContainerClassName,
            children: actions!,
          ),
      ],
    );
  }
}
