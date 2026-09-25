import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'string_value_list.dart';

/// Static variant-matrix preview for [MSStringValueList].
///
/// Renders every [StringValueListTone] so the catalog can show the full
/// surface in light and dark. One preview class per file is the canonical
/// Wave 4 contract.
class StringValueListPreview extends StatelessWidget {
  /// Creates the string value list variant-matrix preview.
  const StringValueListPreview({super.key});

  static const Map<StringValueListTone, List<String>> _seedValues = {
    StringValueListTone.neutral: ['ok', 'operational'],
    StringValueListTone.warn: ['degraded'],
    StringValueListTone.critical: ['down'],
  };

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        for (final tone in StringValueListTone.values)
          WDiv(
            className: 'flex flex-col gap-2',
            children: [
              WText(
                tone.name,
                className: 'text-sm font-semibold text-fg-muted',
              ),
              MSStringValueList(
                value: _seedValues[tone]!,
                onChanged: (_) {},
                tone: tone,
                placeholder: 'Enter value',
                addLabel: 'Add value',
                removeValueLabel: (value) => 'Remove $value',
              ),
            ],
          ),
      ],
    );
  }
}
