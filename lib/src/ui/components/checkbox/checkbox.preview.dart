import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'checkbox.dart';

/// Static variant-matrix preview for [Checkbox].
///
/// Renders checked and unchecked states in both enabled and disabled modes.
class CheckboxPreview extends StatelessWidget {
  /// Creates the checkbox variant-matrix preview.
  const CheckboxPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        WDiv(
          className: 'flex flex-col gap-3',
          children: [
            WText('Enabled', className: 'text-sm font-semibold text-fg-muted'),
            WDiv(
              className: 'flex flex-row gap-4 items-center',
              children: [
                Checkbox(value: false, onChanged: (_) {}),
                WText('Unchecked', className: 'text-sm text-fg'),
                Checkbox(value: true, onChanged: (_) {}),
                WText('Checked', className: 'text-sm text-fg'),
              ],
            ),
          ],
        ),
        WDiv(
          className: 'flex flex-col gap-3',
          children: [
            WText(
              'Disabled',
              className: 'text-sm font-semibold text-fg-muted',
            ),
            WDiv(
              className: 'flex flex-row gap-4 items-center',
              children: [
                const Checkbox(value: false, disabled: true),
                WText('Unchecked', className: 'text-sm text-fg-disabled'),
                const Checkbox(value: true, disabled: true),
                WText('Checked', className: 'text-sm text-fg-disabled'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
