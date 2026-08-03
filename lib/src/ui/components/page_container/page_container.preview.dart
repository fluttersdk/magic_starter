import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'page_container.dart';

/// Static preview for [MSPageContainer].
///
/// The container is invisible chrome, so each configuration renders a dashed
/// placeholder inside it: what the preview shows is where the content edges
/// land, which is the entire contract. One preview class per file is the
/// canonical 4-file contract.
class PageContainerPreview extends StatelessWidget {
  /// Creates the [MSPageContainer] preview.
  const PageContainerPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-8 bg-surface dark:bg-surface py-4',
      children: [
        // 1. Single child: the shape a host page uses.
        const MSPageContainer(
          child: _PreviewBlock(label: 'child'),
        ),

        // 2. Children list: the shape a stacked page uses.
        const MSPageContainer(
          children: [
            _PreviewBlock(label: 'children[0]'),
            _PreviewBlock(label: 'children[1]'),
          ],
        ),

        // 3. Per-page override appended after the shared geometry.
        const MSPageContainer(
          className: 'pb-0',
          child: _PreviewBlock(label: "className: 'pb-0'"),
        ),
      ],
    );
  }
}

/// Minimal filled block that makes the container's content edges visible.
class _PreviewBlock extends StatelessWidget {
  final String label;

  const _PreviewBlock({required this.label});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full px-4 py-6 rounded-lg border border-color-border '
          'dark:border-color-border bg-surface-container '
          'dark:bg-surface-container',
      child:
          WText(label, className: 'text-sm text-fg-muted dark:text-fg-muted'),
    );
  }
}
