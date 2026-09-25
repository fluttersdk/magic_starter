import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'key_value_editor.dart';

/// Static preview for [MSKeyValueEditor].
///
/// One preview class per file is the canonical Wave 4 contract.
class KeyValueEditorPreview extends StatelessWidget {
  /// Creates the key/value editor preview.
  const KeyValueEditorPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-3 p-6',
      children: [
        MSKeyValueEditor(
          value: const [
            MSKeyValueRow(key: 'Authorization', value: 'Bearer token'),
            MSKeyValueRow(key: 'Content-Type', value: 'application/json'),
          ],
          onChanged: (_) {},
          keyPlaceholder: 'Header',
          valuePlaceholder: 'Value',
          addLabel: 'Add header',
          removeRowLabel: 'Remove row',
        ),
      ],
    );
  }
}
