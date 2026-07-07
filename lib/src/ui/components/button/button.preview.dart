import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'button.dart';
import 'button.recipe.dart';

/// Static variant-matrix preview for [MSButton].
///
/// Renders every [ButtonIntent] x [ButtonSize] combination in a scrollable
/// column so the catalog (`/preview`) can display the full surface in both
/// light and dark modes.
class ButtonPreview extends StatelessWidget {
  /// Creates the button variant-matrix preview.
  const ButtonPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        for (final intent in ButtonIntent.values)
          WDiv(
            className: 'flex flex-col gap-3',
            children: [
              WText(
                intent.name,
                className: 'text-sm font-semibold text-fg-muted',
              ),
              WDiv(
                className: 'flex flex-row gap-3',
                children: [
                  for (final size in ButtonSize.values)
                    MSButton(
                      intent: intent,
                      size: size,
                      onPressed: () {},
                      child: WText(size.name),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
