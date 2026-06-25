import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'select.dart';

/// Static variant-matrix preview for [Select].
///
/// Shows a Select with populated options in both the default state and a
/// pre-selected state so the catalog can exercise light and dark themes.
/// One preview class per file is the canonical Wave 4 contract.
class SelectPreview extends StatelessWidget {
  /// Creates the select variant-matrix preview.
  const SelectPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        WText(
          'Select — default (no value)',
          className: 'text-sm font-medium text-fg-muted',
        ),
        Select<String>(
          value: null,
          options: const [
            SelectOption(value: 'option_a', label: 'Option A'),
            SelectOption(value: 'option_b', label: 'Option B'),
            SelectOption(value: 'option_c', label: 'Option C'),
          ],
          onChange: (_) {},
        ),
        WText(
          'Select — pre-selected value',
          className: 'text-sm font-medium text-fg-muted',
        ),
        Select<String>(
          value: 'option_b',
          options: const [
            SelectOption(value: 'option_a', label: 'Option A'),
            SelectOption(value: 'option_b', label: 'Option B'),
            SelectOption(value: 'option_c', label: 'Option C'),
          ],
          onChange: (_) {},
        ),
        WText(
          'Select — disabled',
          className: 'text-sm font-medium text-fg-muted',
        ),
        Select<String>(
          value: null,
          options: const [],
          onChange: (_) {},
          disabled: true,
          placeholder: 'Disabled select',
        ),
      ],
    );
  }
}
