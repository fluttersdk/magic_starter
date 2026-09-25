import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'switch_row.dart';

/// Static variant-matrix preview for [MSSwitchRow].
///
/// Renders a short label and a long label that has to wrap.
class SwitchRowPreview extends StatelessWidget {
  /// Creates the switch-row variant-matrix preview.
  const SwitchRowPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        SizedBox(
          width: 280,
          child: MSSwitchRow(
            label: 'Notify subscribers',
            value: true,
            onChanged: (_) {},
          ),
        ),
        SizedBox(
          width: 280,
          child: MSSwitchRow(
            label:
                'Use as the default policy for every new watcher on this team',
            value: false,
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }
}
