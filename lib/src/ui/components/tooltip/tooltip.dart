import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

/// A reusable tooltip component that wraps [WPopover] to display a brief
/// label on hover (desktop) or long-press (mobile).
///
/// The tooltip content is shown above the [child] trigger by default.
/// All styling is className-driven (semantic tokens).
///
/// **WPopover dismiss race note**: the `_suppressNextTapOutside` guard in
/// [WPopover] handles the real-click dismiss race (see `wind/w_popover.dart`
/// lines 231-240). Tooltip uses `enableTriggerOnTap: false` and a
/// [PopoverController] for programmatic show/hide so the synthetic-tap
/// behavior remains intact and no real-click race can be introduced.
///
/// ### Example
/// ```dart
/// Tooltip(
///   content: const WText('Saves your current draft'),
///   child: const WText('Save'),
/// )
/// ```
@immutable
class Tooltip extends StatelessWidget {
  /// The widget that acts as the anchor/trigger for the tooltip.
  final Widget child;

  /// The tooltip content widget shown in the popover panel.
  final Widget content;

  /// Optional className for the tooltip panel. Defaults to a standard dark
  /// popover style using semantic tokens.
  final String? className;

  /// Popover alignment relative to the trigger. Defaults to [PopoverAlignment.topCenter].
  final PopoverAlignment alignment;

  /// Creates a [Tooltip].
  const Tooltip({
    super.key,
    required this.child,
    required this.content,
    this.className,
    this.alignment = PopoverAlignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve panel className from argument or default token classes.
    final panelClassName = className ??
        'bg-gray-900 dark:bg-gray-700 text-white text-xs px-2 py-1 rounded max-w-xs';

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
