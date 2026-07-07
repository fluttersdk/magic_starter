import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'error_state.recipe.dart';

/// A centered error-state placeholder with destructive tone.
///
/// Mirrors [MSEmptyState] slot structure (root/iconWrap/title/description/action)
/// but applies a destructive visual tone: red tinted icon background and red
/// title text.
///
/// ### Example
/// ```dart
/// MSErrorState(
///   icon: Icons.error_outline,
///   title: 'Something went wrong',
///   description: 'Failed to load your data.',
///   action: MSButton(onPressed: retry, child: const Text('Retry')),
/// )
/// ```
@immutable
class MSErrorState extends StatelessWidget {
  /// Optional icon rendered in the icon wrap slot.
  final IconData? icon;

  /// Title text — the primary error message.
  final String title;

  /// Optional secondary description text.
  final String? description;

  /// Optional action widget (e.g. a [MSButton]).
  final Widget? action;

  /// Creates an [MSErrorState].
  const MSErrorState({
    super.key,
    required this.title,
    this.icon,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: errorStateRootClassName(),
      children: [
        // 1. Optional icon wrap (destructive tinted).
        if (icon != null)
          WDiv(
            className: errorStateIconWrapClassName(),
            child: WIcon(icon!, className: errorStateIconClassName()),
          ),
        // 2. Title slot (destructive tone).
        WText(title, className: errorStateTitleClassName()),
        // 3. Optional description slot.
        if (description != null)
          WText(description!, className: errorStateDescriptionClassName()),
        // 4. Optional action slot.
        if (action != null) action!,
      ],
    );
  }
}
