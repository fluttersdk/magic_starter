import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'toast.dart';

/// Static variant-matrix preview for [MSToast].
///
/// Renders each [ToastVariant] in sequence so the preview catalog can show
/// the full tone surface in light and dark. One preview class per file is
/// the canonical Wave 4 contract.
class ToastPreview extends StatelessWidget {
  /// Creates the toast variant-matrix preview.
  const ToastPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-4 p-6',
      children: [
        for (final variant in ToastVariant.values)
          MSToast(
            message: '${variant.name}: example toast notification',
            variant: variant,
          ),
      ],
    );
  }
}
