import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'skeleton.dart';

/// Static variant-matrix preview for [Skeleton].
///
/// Renders every [SkeletonShape] with representative dimensions so the catalog
/// can show the pulsing effect in light and dark. One preview class per file
/// is the canonical Wave 4 contract.
class SkeletonPreview extends StatelessWidget {
  /// Creates the skeleton variant-matrix preview.
  const SkeletonPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        // Block: image/card placeholder
        WDiv(
          className: 'flex flex-col gap-2',
          children: [
            WText('block', className: 'text-xs text-fg-muted'),
            const Skeleton(shape: SkeletonShape.block, width: 240, height: 80),
          ],
        ),

        // Text: paragraph line placeholders
        WDiv(
          className: 'flex flex-col gap-2',
          children: [
            WText('text', className: 'text-xs text-fg-muted'),
            const Skeleton(shape: SkeletonShape.text, width: 200, height: 14),
            const Skeleton(shape: SkeletonShape.text, width: 160, height: 14),
            const Skeleton(shape: SkeletonShape.text, width: 120, height: 14),
          ],
        ),

        // Circle: avatar placeholder
        WDiv(
          className: 'flex flex-col gap-2',
          children: [
            WText('circle', className: 'text-xs text-fg-muted'),
            const Skeleton(shape: SkeletonShape.circle, width: 48, height: 48),
          ],
        ),
      ],
    );
  }
}
