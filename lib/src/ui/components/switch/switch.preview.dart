import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'switch.dart';

/// Static variant-matrix preview for [MSSwitch].
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
                MSSwitch(value: false, onChanged: (_) {}),
                WText('Off', className: 'text-sm text-fg'),
                MSSwitch(value: true, onChanged: (_) {}),
                WText('On', className: 'text-sm text-fg'),
              ],
            ),
          ],
        ),
        WDiv(
          className: 'flex flex-col gap-3',
          children: [
            WText('Disabled', className: 'text-sm font-semibold text-fg-muted'),
            WDiv(
              className: 'flex flex-row gap-4 items-center',
              children: [
                const MSSwitch(value: false, onChanged: null, disabled: true),
                WText('Off', className: 'text-sm text-fg-disabled'),
                const MSSwitch(value: true, onChanged: null, disabled: true),
                WText('On', className: 'text-sm text-fg-disabled'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
