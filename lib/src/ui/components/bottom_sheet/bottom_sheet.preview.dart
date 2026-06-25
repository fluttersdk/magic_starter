import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'bottom_sheet.dart';

/// Static preview for the [BottomSheet] component.
///
/// Renders the sheet panel inline (not via showModalBottomSheet) so the
/// preview catalog can display it in light and dark. One preview class per
/// file is the canonical Wave 4 contract.
class BottomSheetPreview extends StatelessWidget {
  /// Creates the bottom sheet preview.
  const BottomSheetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        // Sheet with title + description + footer.
        BottomSheet(
          title: 'Select an option',
          description: 'Choose the action you want to perform.',
          body: WDiv(
            className: 'flex flex-col gap-3',
            children: const [
              WText('Option A', className: 'text-sm'),
              WText('Option B', className: 'text-sm'),
              WText('Option C', className: 'text-sm'),
            ],
          ),
          footerBuilder: (_) => WDiv(
            className: 'flex flex-row justify-end gap-2 wrap',
            children: [
              WDiv(
                className: 'px-4 py-2 rounded-lg bg-primary text-white text-sm',
                child: const WText('Confirm'),
              ),
            ],
          ),
        ),
        // Sheet body only.
        const BottomSheet(
          body: WText(
            'A minimal bottom sheet with no title or footer.',
            className: 'text-sm',
          ),
        ),
      ],
    );
  }
}
