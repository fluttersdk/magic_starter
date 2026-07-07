import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'badge.dart';

/// Static variant-matrix preview for [MSBadge].
///
/// Renders every [BadgeTone] in a column so the catalog can show the full
/// surface in light and dark. One preview class per file is the canonical
/// Wave 4 contract.
class BadgePreview extends StatelessWidget {
  /// Creates the badge variant-matrix preview.
  const BadgePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-3 p-6',
      children: [
        for (final tone in BadgeTone.values)
          WDiv(
            className: 'flex flex-row items-center gap-3',
            children: [
              MSBadge(tone.name, tone: tone),
              WText(
                tone.name,
                className: 'text-sm text-fg-muted',
              ),
            ],
          ),
      ],
    );
  }
}
