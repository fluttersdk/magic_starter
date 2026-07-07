import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'confirm_dialog.dart';

/// Static variant-matrix preview for [MSConfirmDialog].
///
/// Renders each [ConfirmDialogVariant] inline (not via showDialog) so the
/// preview catalog can display the full variant surface in light and dark.
/// One preview class per file is the canonical Wave 4 contract.
class ConfirmDialogPreview extends StatelessWidget {
  /// Creates the confirm dialog variant-matrix preview.
  const ConfirmDialogPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        for (final variant in ConfirmDialogVariant.values)
          MSConfirmDialog(
            title: '${variant.name} confirm',
            description:
                'This action demonstrates the ${variant.name} variant.',
            variant: variant,
          ),
      ],
    );
  }
}
