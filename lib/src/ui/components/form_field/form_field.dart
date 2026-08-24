import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'form_field.recipe.dart';

/// A labeled form-field wrapper composing label / child / hint / error slots.
///
/// Provides a consistent vertical layout for form inputs: an optional label
/// above the child, an optional hint below, and an optional inline error (in
/// destructive tone) that replaces the hint when present.
///
/// ### Example
/// ```dart
/// MSFormField(
///   label: 'Email',
///   hint: 'We will never share your email',
///   error: controller.errors['email'],
///   child: WFormInput(form: form, name: 'email'),
/// )
/// ```
@immutable
class MSFormField extends StatelessWidget {
  /// Optional label displayed above the child input.
  final String? label;

  /// The child input or widget placed in the field body.
  final Widget child;

  /// Optional helper text displayed below the child.
  ///
  /// Hidden when [error] is non-null.
  final String? hint;

  /// Optional error message displayed in destructive tone below the child.
  ///
  /// When non-null, the hint is suppressed.
  final String? error;

  /// Creates a [MSFormField].
  const MSFormField({
    super.key,
    required this.child,
    this.label,
    this.hint,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: formFieldRootClassName(),
      children: [
        // 1. Optional label slot.
        if (label != null) WText(label!, className: formFieldLabelClassName()),
        // 2. Child input slot.
        child,
        // 3. Error slot takes priority over hint.
        if (error != null)
          WText(error!, className: formFieldErrorClassName())
        else if (hint != null)
          WText(hint!, className: formFieldHintClassName()),
      ],
    );
  }
}
