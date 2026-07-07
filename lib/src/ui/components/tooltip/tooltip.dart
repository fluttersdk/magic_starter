import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'tooltip.recipe.dart';

/// A reusable tooltip component that wraps [WPopover] to display a brief
/// label on hover (desktop) or long-press (mobile).
///
/// The tooltip content is shown above the [child] trigger by default.
/// All styling is className-driven (semantic tokens).
///
/// **WPopover dismiss race note**: the `_suppressNextTapOutside` guard in
/// [WPopover] handles the real-click dismiss race (see `wind/w_popover.dart`).
/// Tooltip sets `enableTriggerOnTap: true` so tapping the trigger toggles the
/// tooltip on touch screens; WPopover's guard swallows the same-frame
/// outside-tap so opening does not immediately dismiss it.
///
/// ### Example
/// ```dart
/// MSTooltip(
///   content: const WText('Saves your current draft'),
///   child: const WText('Save'),
/// )
/// ```
@immutable
class MSTooltip extends StatelessWidget {
  /// The widget that acts as the anchor/trigger for the tooltip.
  final Widget child;

  /// The tooltip content widget shown in the popover panel.
  final Widget content;

  /// Optional caller className for the tooltip panel, appended after
  /// [tooltipPanelRecipe]'s default semantic-token styling.
  final String? className;

  /// Popover alignment relative to the trigger. Defaults to [PopoverAlignment.topCenter].
  final PopoverAlignment alignment;

  /// Creates a [MSTooltip].
  const MSTooltip({
    super.key,
    required this.child,
    required this.content,
    this.className,
    this.alignment = PopoverAlignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve panel className from the recipe; the caller className appends
    //    last so it refines the default rather than replacing it.
    final panelClassName = tooltipPanelRecipe(className: className);

    // 2. Wrap the trigger in WPopover for hover/tap-driven display.
    //    enableTriggerOnTap: true lets tapping the trigger show/hide the
    //    tooltip on touch screens; the _suppressNextTapOutside guard in
    //    WPopover prevents the same-frame dismiss race.
    return WPopover(
      alignment: alignment,
      className: panelClassName,
      enableTriggerOnTap: true,
      triggerBuilder: (_, __, ___) => child,
      contentBuilder: (_, close) => content,
    );
  }
}
