import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'radio.dart';

/// Static variant-matrix preview for [Radio].
///
/// Renders selected and unselected states in both enabled and disabled modes.
class RadioPreview extends StatelessWidget {
  /// Creates the radio variant-matrix preview.
  const RadioPreview({super.key});

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
                Radio<String>(
                  value: 'a',
                  groupValue: 'b',
                  onChanged: (_) {},
                ),
                WText('Unselected', className: 'text-sm text-fg'),
                Radio<String>(
                  value: 'a',
                  groupValue: 'a',
                  onChanged: (_) {},
                ),
                WText('Selected', className: 'text-sm text-fg'),
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
                Radio<String>(
                  value: 'a',
                  groupValue: 'b',
                  onChanged: (_) {},
                  disabled: true,
                ),
                WText('Unselected', className: 'text-sm text-fg-disabled'),
                Radio<String>(
                  value: 'a',
                  groupValue: 'a',
                  onChanged: (_) {},
                  disabled: true,
                ),
                WText('Selected', className: 'text-sm text-fg-disabled'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
