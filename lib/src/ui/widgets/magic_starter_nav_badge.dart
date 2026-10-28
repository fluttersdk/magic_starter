import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../components/badge/index.dart';

/// The live count on a navigation item, drawn as a small [MSBadge] pill.
///
/// The shell mounts one for every [MagicStarterNavItem] that carries a
/// `badgeCount`; it is exported so a host that registers its own layout can
/// draw the same badge. It listens to [count] itself, which is why a host moves
/// the number by updating the notifier and never rebuilds the navigation.
///
/// ```dart
/// MagicStarterNavBadge(
///   count: unticked,
///   labelKey: 'nav.shopping_open',
/// )
/// ```
///
/// A count that is `null` or not above zero draws nothing, and leaves nothing
/// for a screen reader either. The drawn number stops at [maxShown], past which
/// it reads `99+`. The spoken sentence does not stop: it carries the real count
/// through `transChoice`, and the drawn text is left out of the semantics tree
/// so the number is not read a second time.
///
/// Colour comes from the neutral `MSBadge` tone, which is a semantic alias pair
/// and therefore already carries its dark-mode peer; [className] re-tones it.
@immutable
class MagicStarterNavBadge extends StatelessWidget {
  /// The largest count drawn as a number; one above it draws `99+`.
  static const int maxShown = 99;

  /// The count to show. Listened to for the life of the widget.
  final ValueListenable<int?> count;

  /// Translation key of the sentence a screen reader gets, with plural forms
  /// and a `:count` placeholder.
  final String labelKey;

  /// Appended to the `MSBadge` recipe, so a token written here wins its family.
  final String? className;

  /// Creates a badge bound to [count].
  const MagicStarterNavBadge({
    super.key,
    required this.count,
    required this.labelKey,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: count,
      builder: (BuildContext context, int? value, Widget? _) {
        // 1. No count to show: no badge, and no semantics node either.
        if (value == null || value <= 0) {
          return const SizedBox.shrink();
        }

        // 2. The pill caps its number to stay small; the sentence does not.
        final String drawn = value > maxShown ? '$maxShown+' : '$value';

        // 3. The sentence replaces the drawn number for assistive technology,
        // so a screen reader says the count once and says what it counts.
        return Semantics(
          label: transChoice(labelKey, value),
          excludeSemantics: true,
          child: MSBadge(drawn, className: className),
        );
      },
    );
  }
}
