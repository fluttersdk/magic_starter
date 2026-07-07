import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'empty_state.recipe.dart';

/// A centered empty-state placeholder with optional icon, title, description,
/// and action slot.
///
/// ### Example
/// ```dart
/// MSEmptyState(
///   icon: Icons.inbox_outlined,
///   title: 'No notifications',
///   description: 'You are all caught up!',
///   action: MSButton(onPressed: refresh, child: const Text('Refresh')),
/// )
/// ```
@immutable
class MSEmptyState extends StatelessWidget {
  /// Optional icon rendered in the icon wrap slot.
  final IconData? icon;

  /// Title text — the primary message.
  final String title;

  /// Optional secondary description text.
  final String? description;

  /// Optional action widget (e.g. a [MSButton]).
  final Widget? action;

  /// Creates an [MSEmptyState].
  const MSEmptyState({
    super.key,
    required this.title,
    this.icon,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: emptyStateRootClassName(),
      children: [
        // 1. Optional icon wrap.
        if (icon != null)
          WDiv(
            className: emptyStateIconWrapClassName(),
            child: WIcon(icon!, className: emptyStateIconClassName()),
          ),
        // 2. Title slot.
        WText(title, className: emptyStateTitleClassName()),
        // 3. Optional description slot.
        if (description != null)
          WText(description!, className: emptyStateDescriptionClassName()),
        // 4. Optional action slot.
        if (action != null) action!,
      ],
    );
  }
}
