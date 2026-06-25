import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'tooltip.dart';

/// Static preview for the [Tooltip] component.
///
/// Renders tooltips with different alignment options in a matrix so the
/// preview catalog can display them in light and dark. One preview class
/// per file is the canonical Wave 4 contract.
class TooltipPreview extends StatelessWidget {
  /// Creates the tooltip preview.
  const TooltipPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row gap-8 p-12 justify-center items-center',
      children: [
        Tooltip(
          content: const WText('Tooltip above'),
          alignment: PopoverAlignment.topCenter,
          child: WDiv(
            className:
                'px-4 py-2 rounded-lg bg-surface border border-color-border text-sm',
            child: const WText('Hover (top)'),
          ),
        ),
        Tooltip(
          content: const WText('Tooltip below'),
          alignment: PopoverAlignment.bottomCenter,
          child: WDiv(
            className:
                'px-4 py-2 rounded-lg bg-surface border border-color-border text-sm',
            child: const WText('Hover (bottom)'),
          ),
        ),
        Tooltip(
          content: const WText('Custom styled tooltip'),
          className: 'bg-primary text-white text-xs px-2 py-1 rounded',
          child: WDiv(
            className: 'px-4 py-2 rounded-lg bg-primary text-white text-sm',
            child: const WText('Hover (primary)'),
          ),
        ),
      ],
    );
  }
}
