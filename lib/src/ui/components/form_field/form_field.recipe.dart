import 'package:magic/magic.dart';

// No variant axes needed for FormField — the layout is static (root/label/hint/error
// slots). The recipe provides the root container className.

/// Builds the root-container className for [MSFormField].
///
/// Returns a plain string rather than a [WindRecipe] because FormField has no
/// variant axes; the recipe is kept as a named function for visual consistency
/// with the atomic-component shape.
String formFieldRootClassName() => 'flex flex-col gap-1 w-full';

/// Label text className.
String formFieldLabelClassName() => 'text-sm font-medium text-fg';

/// Hint text className.
String formFieldHintClassName() => 'text-xs text-fg-muted';

/// Error text className (destructive tone).
String formFieldErrorClassName() => 'text-xs text-red-600 dark:text-red-400';
