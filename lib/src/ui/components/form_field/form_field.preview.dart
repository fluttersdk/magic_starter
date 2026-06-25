import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'form_field.dart';

/// Static preview for [MagicFormField].
///
/// Renders the four slot combinations: label-only, with hint, with error,
/// and without label. One preview class per file.
class MagicFormFieldPreview extends StatelessWidget {
  const MagicFormFieldPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        MagicFormField(
          label: 'Email address',
          hint: 'We will never share your email.',
          child: WDiv(
            className:
                'h-10 rounded-lg bg-surface-container border border-color-border',
          ),
        ),
        MagicFormField(
          label: 'Password',
          error: 'Password must be at least 8 characters.',
          child: WDiv(
            className:
                'h-10 rounded-lg bg-surface-container border border-color-border',
          ),
        ),
        MagicFormField(
          label: 'Name (no hint/error)',
          child: WDiv(
            className:
                'h-10 rounded-lg bg-surface-container border border-color-border',
          ),
        ),
        MagicFormField(
          child: WDiv(
            className:
                'h-10 rounded-lg bg-surface-container border border-color-border',
          ),
        ),
      ],
    );
  }
}
