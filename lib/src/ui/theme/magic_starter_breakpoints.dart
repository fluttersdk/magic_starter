import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

/// Resolves a Wind breakpoint name against the current screen width.
///
/// Every width-driven decision in the starter (the shell's sidebar, the
/// master-detail split, the sheet that presents as a dialog) goes through
/// here, so they all read the same `WindThemeData.screens` table and fail the
/// same way on a name that table does not carry.
final class MagicStarterBreakpoints {
  MagicStarterBreakpoints._();

  /// Whether the screen is at least as wide as the breakpoint [name].
  ///
  /// Reads `MediaQuery.size` through `wScreenIs`, not a `LayoutBuilder`, so a
  /// caller in the shell does not become a build-scope root.
  ///
  /// Throws a [StateError] naming [setting] (the argument or theme field the
  /// name came from) when the Wind theme carries no such breakpoint. `wScreenIs`
  /// answers `false` for an unknown name, which would pin the narrow layout at
  /// every width and look like a layout bug rather than a typo.
  static bool isAtLeast(
    BuildContext context,
    String name, {
    required String setting,
  }) {
    final Map<String, int> screens = WindTheme.dataOf(context).screens;

    if (!screens.containsKey(name)) {
      final List<MapEntry<String, int>> known = screens.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      throw StateError(
        '$setting is "$name", which the Wind theme does not carry. '
        'Use one of: ${known.map((e) => e.key).join(', ')}.',
      );
    }

    return wScreenIs(context, name);
  }
}
