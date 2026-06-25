import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'textarea.dart';
import 'textarea.recipe.dart';

/// Static variant-matrix preview for [Textarea].
///
/// Renders every [TextareaState] so the catalog (`/preview`) can show the full
/// surface in both light and dark.
class TextareaPreview extends StatelessWidget {
  /// Creates the textarea variant-matrix preview.
  const TextareaPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        for (final state in TextareaState.values)
          WDiv(
            className: 'flex flex-col gap-2',
            children: [
              WText(
                state.name,
                className: 'text-sm font-semibold text-fg-muted',
              ),
              Textarea(
                state: state,
                placeholder: 'Enter text (${state.name})',
                minLines: 3,
              ),
            ],
          ),
      ],
    );
  }
}
