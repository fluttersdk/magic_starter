// MSUpgradeDialog component folder-local barrel.
//
// Re-exports the public surface (component + recipe). The preview is
// intentionally NOT re-exported: `previews:refresh` discovers `*.preview.dart`
// files directly and the preview must stay out of the release barrel.

export 'upgrade_dialog.dart';
export 'upgrade_dialog.recipe.dart';
