// ConfirmDialog component — folder-local barrel.
//
// Canonical Wave 4 atomic-component shape: recipe, component, and preview each
// live in their own dotted-suffix file. This index re-exports the public
// surface (component + variant enum + recipe helper). The preview is
// intentionally NOT re-exported here.

export 'confirm_dialog.dart' show ConfirmDialog, ConfirmDialogVariant;
export 'confirm_dialog.recipe.dart';
