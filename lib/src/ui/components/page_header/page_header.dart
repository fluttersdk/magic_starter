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
/// slot: a `Icons.chevron_left` icon alone on screen, with [backLabel] as its
/// accessible name so a screen reader says which parent it returns to. Tapping
/// it navigates straight to [backFallback] with `MagicRoute.to`, rather than
/// popping the navigator: the settings surface uses `RouteTransition.none` and
/// popping that instant-swap stack triggered a teardown assertion. The control
/// needs BOTH [backLabel] and [backFallback]; with either missing the header is
/// unchanged and top-level pages show no back affordance.
///
/// ### Example
/// ```dart
/// MSPageHeader(
///   title: 'Settings',
///   subtitle: 'Manage your account',
///   actions: [MSButton(onPressed: save, child: const Text('Save'))],
/// )
///
/// // Sub-page with automatic back:
/// MSPageHeader(
///   title: 'Profile',
///   backLabel: 'Settings',
///   backFallback: '/settings',
/// )
/// ```
@immutable
class MSPageHeader extends StatelessWidget {
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
  /// responsive `flex-col sm:flex-row` stacked layout, and the title row claims
  /// the remaining width with `flex-1 min-w-0` so a long title SHRINKS instead
  /// of pushing past the actions.
  ///
  /// Null (the default) reads
  /// `MagicStarter.pageHeaderTheme.inlineActions`, so an app that has themed
  /// the container into a row at every width states that once rather than on
  /// every screen. [MSPageScaffold] does not expose this argument at all, which
  /// is why the theme is the only reachable switch for a scaffold consumer.
  final bool? inlineActions;

  /// Whether this header lays out on one row, resolving the theme default.
  bool get isInline =>
      inlineActions ?? MagicStarter.pageHeaderTheme.inlineActions;

  /// Back-affordance label (e.g. `'Settings'`).
  ///
  /// When set alongside [backFallback], and [leading] is null, renders a
  /// `chevron_left` icon as a tappable leading control that navigates to
  /// [backFallback]. This string is
  /// the control's ACCESSIBLE NAME rather than visible text: the chevron is
  /// icon-only on screen, and without a name the control reads as an unnamed
  /// button. When null (default), no back control is rendered.
  final String? backLabel;

  /// The route the back control navigates to, with `MagicRoute.to`.
  ///
  /// Required for the control to render at all: it is the only destination the
  /// control has, so a [backLabel] without one produced a chevron that
  /// announced itself as a button and did nothing when pressed.
  final String? backFallback;

  /// Creates a [MSPageHeader].
  const MSPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.titleSuffix,
    this.inlineActions,
    this.backLabel,
    this.backFallback,
  });

  /// Builds the back affordance control from [backLabel] and [backFallback].
  ///
  /// Only called when both are set, so [fallback] needs no null branch.
  Widget _buildBackControl(String fallback) {
    // Icon-only back control. It sits in the title row's leading slot
    // (`items-center`), so the chevron vertically centres against the
    // title + subtitle block. Navigation goes straight to the parent route
    // (`MagicRoute.to`) rather than popping the navigator: the settings
    // surface uses RouteTransition.none, and popping the instant-swap stack
    // triggered a teardown assertion (`_owner != null`); going to the parent
    // is stable and lands on the correct hub/parent.
    return WAnchor(
      // The control is a chevron and nothing else, so there is no child text
      // for the anchor's `MergeSemantics` to absorb, and `backLabel` was a
      // presence flag whose string went nowhere: every page carrying a back
      // control offered assistive technology an unnamed button. The label the
      // caller already passes is exactly the name it needs, since it says which
      // parent the control returns to.
      semanticLabel: backLabel,
      onTap: () => MagicRoute.to(fallback),
      child: WDiv(
        className: MagicStarter.pageHeaderTheme.backControlClassName,
        child: WIcon(_chevronLeft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the effective leading: an explicit widget takes priority; when
    // both back arguments are set, auto-build the unified back control.
    //
    // BOTH, because `backFallback` is the control's only destination. Gated on
    // `backLabel` alone, a caller passing just the label got a chevron that
    // announced itself as a button and did nothing when pressed, which is worse
    // than no control at all. Every in-package caller passes both.
    final String? fallback = backFallback;
    final Widget? effectiveLeading = leading ??
        (backLabel != null && fallback != null
            ? _buildBackControl(fallback)
            : null);

    return WDiv(
      className: isInline
          ? MagicStarter.pageHeaderTheme.containerInlineClassName
          : MagicStarter.pageHeaderTheme.containerClassName,
      children: [
        // 1. Title row: optional leading + title column + optional titleSuffix.
        WDiv(
          className: isInline
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
