import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'switch.dart';

/// Static variant-matrix preview for [Switch].
///
/// Renders on/off states in both enabled and disabled modes.
class SwitchPreview extends StatelessWidget {
  /// Creates the switch variant-matrix preview.
  const SwitchPreview({super.key});

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
                Switch(value: false, onChanged: (_) {}),
                WText('Off', className: 'text-sm text-fg'),
                Switch(value: true, onChanged: (_) {}),
                WText('On', className: 'text-sm text-fg'),
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
                const Switch(value: false, onChanged: null, disabled: true),
                WText('Off', className: 'text-sm text-fg-disabled'),
                const Switch(value: true, onChanged: null, disabled: true),
                WText('On', className: 'text-sm text-fg-disabled'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
