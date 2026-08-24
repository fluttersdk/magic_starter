import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'typography.dart';

/// Static variant-matrix preview for [MSTypography].
///
/// Renders every [TypographyVariant] so the catalog can show the full scale
/// in light and dark. One preview class per file is the canonical Wave 4
/// contract.
class TypographyPreview extends StatelessWidget {
  /// Creates the typography variant-matrix preview.
  const TypographyPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-4 p-6',
      children: [
        for (final variant in TypographyVariant.values)
          WDiv(
            className: 'flex flex-col gap-1',
            children: [
              MSTypography(
                'The quick brown fox — ${variant.name}',
                variant: variant,
              ),
              WText(variant.name, className: 'text-xs text-fg-muted'),
            ],
          ),
      ],
    );
  }
}
