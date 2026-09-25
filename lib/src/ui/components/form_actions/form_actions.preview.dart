import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'form_actions.dart';

/// Static variant-matrix preview for [MSFormActions].
///
/// Renders the default (submit-only), cancel + submit, and submitting states.
class FormActionsPreview extends StatelessWidget {
  /// Creates the form-actions variant-matrix preview.
  const FormActionsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        WDiv(
          className: 'flex flex-col gap-3',
          children: [
            WText(
              'Submit only',
              className: 'text-sm font-semibold text-fg-muted',
            ),
            MSFormActions(submitLabel: 'Save', onSubmit: () {}),
          ],
        ),
        WDiv(
          className: 'flex flex-col gap-3',
          children: [
            WText(
              'Cancel + submit',
              className: 'text-sm font-semibold text-fg-muted',
            ),
            MSFormActions(
              submitLabel: 'Save',
              onSubmit: () {},
              cancelLabel: 'Cancel',
              onCancel: () {},
            ),
          ],
        ),
        WDiv(
          className: 'flex flex-col gap-3',
          children: [
            WText(
              'Submitting',
              className: 'text-sm font-semibold text-fg-muted',
            ),
            MSFormActions(
              submitLabel: 'Save',
              onSubmit: () {},
              isSubmitting: true,
            ),
          ],
        ),
      ],
    );
  }
}
