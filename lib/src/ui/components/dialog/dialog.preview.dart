import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'dialog.dart';

/// Static preview for the [Dialog] component.
///
/// Renders a representative dialog inline (not via showDialog) so the preview
/// catalog can display the shell in light and dark without an overlay. One
/// preview class per file is the canonical Wave 4 contract.
class DialogPreview extends StatelessWidget {
  /// Creates the dialog preview.
  const DialogPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        // Dialog with title, description, and footer.
        Dialog(
          title: 'Confirm deletion',
          description: 'This action cannot be undone.',
          body: const WText(
            'Are you sure you want to delete this item?',
            className: 'text-sm',
          ),
          footerBuilder: (_) => WDiv(
            className: 'flex flex-row justify-end gap-2 wrap',
            children: [
              WDiv(
                className:
                    'px-4 py-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-sm',
                child: const WText('Cancel'),
              ),
              WDiv(
                className:
                    'px-4 py-2 rounded-lg bg-destructive text-white text-sm',
                child: const WText('Delete'),
              ),
            ],
          ),
        ),
        // Dialog with title only (no description, no footer).
        const Dialog(
          title: 'Informational',
          body: WText(
            'This dialog has only a title and body content.',
            className: 'text-sm',
          ),
        ),
      ],
    );
  }
}
