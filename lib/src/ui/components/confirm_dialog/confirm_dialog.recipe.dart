import '../../../configuration/magic_starter_theme.dart';
import 'confirm_dialog.dart' show ConfirmDialogVariant;

/// Resolves the confirm button className for a given [ConfirmDialogVariant]
/// using the modal theme.
///
/// This function mirrors the `_resolveConfirmClassName()` method that existed
/// in the pre-migration `MagicStarterConfirmDialog`, extracted as a
/// theme-driven recipe helper so tests can assert it in isolation.
///
/// ```dart
/// final cls = resolveConfirmButtonClassName(
///   ConfirmDialogVariant.danger,
///   MagicStarter.manager.modalTheme,
/// );
/// ```
String resolveConfirmButtonClassName(
  ConfirmDialogVariant variant,
  MagicStarterModalTheme theme,
) {
  return switch (variant) {
    ConfirmDialogVariant.primary => theme.primaryButtonClassName,
    ConfirmDialogVariant.danger => theme.dangerButtonClassName,
    ConfirmDialogVariant.warning => theme.warningButtonClassName,
  };
}
