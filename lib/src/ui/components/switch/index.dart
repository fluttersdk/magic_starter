// Switch component — folder-local barrel.
//
// The preview is intentionally NOT re-exported here — `previews:refresh`
// discovers `*.preview.dart` directly, and the preview must stay out of the
// release barrel.

export 'switch.dart' show Switch;
export 'switch.recipe.dart';
