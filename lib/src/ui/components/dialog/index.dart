// Dialog component — folder-local barrel.
//
// Canonical Wave 4 atomic-component shape: recipe, component, and preview each
// live in their own dotted-suffix file. This index re-exports the public
// surface (component + recipe helpers). The preview is intentionally NOT
// re-exported here — `previews:refresh` (Step 18) discovers `*.preview.dart`
// files directly, and the preview must stay out of the release barrel.

export 'dialog.dart' show Dialog;
export 'dialog.recipe.dart';
