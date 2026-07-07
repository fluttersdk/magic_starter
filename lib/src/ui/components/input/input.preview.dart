import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'input.dart';
import 'input.recipe.dart';

/// Static variant-matrix preview for [MSInput].
///
/// Renders every [InputState] so the catalog (`/preview`) can show the full
/// surface in both light and dark.
class InputPreview extends StatelessWidget {
  /// Creates the input variant-matrix preview.
  const InputPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        for (final state in InputState.values)
          WDiv(
            className: 'flex flex-col gap-2',
            children: [
              WText(
                state.name,
                className: 'text-sm font-semibold text-fg-muted',
              ),
              MSInput(
                state: state,
                placeholder: 'Enter text (${state.name})',
              ),
            ],
          ),
      ],
    );
  }
}
