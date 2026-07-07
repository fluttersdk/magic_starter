import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'segmented_control.dart';
import 'segmented_control.recipe.dart';

/// Static variant-matrix preview for [MSSegmentedControl].
///
/// Renders every size variant so the catalog shows the full surface in light
/// and dark. One preview class per file is the canonical Wave 4 contract.
class SegmentedControlPreview extends StatelessWidget {
  /// Creates the segmented-control variant-matrix preview.
  const SegmentedControlPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        for (final size in SegmentedControlSize.values) ...[
          WText(
            'SegmentedControl — ${size.name}',
            className: 'text-sm font-medium text-fg-muted',
          ),
          MSSegmentedControl<String>(
            options: const ['Day', 'Week', 'Month'],
            selectedIndex: 1,
            size: size,
            onChanged: (_) {},
          ),
        ],
      ],
    );
  }
}
