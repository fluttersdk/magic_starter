import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'combobox.dart';

/// Static variant-matrix preview for [Combobox].
///
/// Shows a Combobox in its default and pre-selected states so the catalog can
/// exercise light and dark themes. One preview class per file is the canonical
/// Wave 4 contract.
class ComboboxPreview extends StatelessWidget {
  /// Creates the combobox variant-matrix preview.
  const ComboboxPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        WText(
          'Combobox — default (searchable)',
          className: 'text-sm font-medium text-fg-muted',
        ),
        Combobox<String>(
          value: null,
          options: const [
            SelectOption(value: 'apple', label: 'Apple'),
            SelectOption(value: 'banana', label: 'Banana'),
            SelectOption(value: 'cherry', label: 'Cherry'),
            SelectOption(value: 'date', label: 'Date'),
          ],
          onChange: (_) {},
          placeholder: 'Search fruit...',
        ),
        WText(
          'Combobox — pre-selected value',
          className: 'text-sm font-medium text-fg-muted',
        ),
        Combobox<String>(
          value: 'banana',
          options: const [
            SelectOption(value: 'apple', label: 'Apple'),
            SelectOption(value: 'banana', label: 'Banana'),
            SelectOption(value: 'cherry', label: 'Cherry'),
          ],
          onChange: (_) {},
        ),
      ],
    );
  }
}
