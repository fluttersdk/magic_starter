import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

/// A single item entry for [DropdownMenu].
@immutable
class DropdownMenuItem {
  /// The display label for this menu item.
  final String label;

  /// Optional callback invoked when the item is tapped.
  final VoidCallback? onTap;

  /// When `true`, the item is rendered in a muted style and cannot be tapped.
  final bool disabled;

  /// Optional leading icon or widget rendered before the label.
  final Widget? leading;

  /// Optional className override for this item's container.
  final String? className;

  /// Creates a [DropdownMenuItem].
  const DropdownMenuItem({
    required this.label,
    this.onTap,
    this.disabled = false,
    this.leading,
    this.className,
  });
}

/// A reusable dropdown-menu component that composes on [WPopover].
///
/// The trigger [child] opens a popover panel containing the provided [items].
/// Each item can carry an [onTap] callback, a disabled flag, and an optional
/// leading widget.
///
/// **WPopover dismiss race note**: the `_suppressNextTapOutside` guard in
/// [WPopover] handles the real-click dismiss race (wind/w_popover.dart
/// lines 231-240). The menu uses `enableTriggerOnTap: true` (WPopover's
/// default) so tapping the trigger reliably toggles the panel; the same-frame
/// outside-tap dismiss is suppressed internally by WPopover and does not need
/// any workaround here.
///
/// ### Example
/// ```dart
/// DropdownMenu(
///   child: const WText('Options'),
///   items: [
///     DropdownMenuItem(label: 'Edit', onTap: controller.edit),
///     DropdownMenuItem(label: 'Delete', onTap: controller.delete),
///   ],
/// )
/// ```
@immutable
class DropdownMenu extends StatelessWidget {
  /// The trigger widget that opens/closes the menu.
  final Widget child;

  /// The menu items to display in the popover panel.
  final List<DropdownMenuItem> items;

  /// Optional className for the popover panel container.
  final String? className;

  /// Popover alignment relative to the trigger.
  /// Defaults to [PopoverAlignment.bottomLeft].
  final PopoverAlignment alignment;

  /// Creates a [DropdownMenu].
  const DropdownMenu({
    super.key,
    required this.child,
    required this.items,
    this.className,
    this.alignment = PopoverAlignment.bottomLeft,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve panel className from argument or default semantic-token style.
    final panelClassName = className ??
        'min-w-40 bg-surface border border-color-border rounded-lg shadow-lg py-1 overflow-hidden';

    // 2. Build WPopover with the trigger and item list as content.
    return WPopover(
      alignment: alignment,
      className: panelClassName,
      enableTriggerOnTap: true,
      triggerBuilder: (_, __, ___) => child,
      contentBuilder: (_, close) => _buildItems(close),
    );
  }

  Widget _buildItems(VoidCallback close) {
    return WDiv(
      className: 'flex flex-col',
      children: [
        for (final item in items) _buildItem(item, close),
      ],
    );
  }

  Widget _buildItem(DropdownMenuItem item, VoidCallback close) {
    // 3. Disabled items: muted style, no tap handler.
    if (item.disabled) {
      return WDiv(
        className: item.className ??
            'flex flex-row items-center gap-2 px-4 py-2 text-sm text-fg-disabled',
        children: [
          if (item.leading != null) item.leading!,
          WText(item.label),
        ],
      );
    }

    // 4. Active items: WAnchor for interactivity.
    return WAnchor(
      onTap: () {
        item.onTap?.call();
        close();
      },
      child: WDiv(
        className: item.className ??
            'flex flex-row items-center gap-2 px-4 py-2 text-sm text-fg hover:bg-surface-container',
        children: [
          if (item.leading != null) item.leading!,
          WText(item.label),
        ],
      ),
    );
  }
}
