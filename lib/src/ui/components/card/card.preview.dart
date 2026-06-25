import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'card.dart';

/// Static variant-matrix preview for [Card].
///
/// Renders every [CardVariant] in both the padded and full-bleed (`noPadding`)
/// modes so the catalog (Wave 6 `/preview`) can show the full surface in light
/// and dark. One preview class per file is the canonical Wave 4 contract.
class CardPreview extends StatelessWidget {
  /// Creates the card variant-matrix preview.
  const CardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        for (final variant in CardVariant.values) ...[
          Card(
            title: '${variant.name} (padded)',
            variant: variant,
            child: const WText('Body content', className: 'text-sm'),
          ),
          Card(
            title: '${variant.name} (noPadding)',
            variant: variant,
            noPadding: true,
            child: const WDiv(
              className: 'flex flex-col p-6',
              child: WText('Full-bleed body', className: 'text-sm'),
            ),
          ),
        ],
      ],
    );
  }
}
