// Input component — folder-local barrel.
//
// The preview is intentionally NOT re-exported here — `previews:refresh`
// discovers `*.preview.dart` directly, and the preview must stay out of the
// release barrel.

export 'input.dart' show Input;
export 'input.recipe.dart' show InputState, inputRecipe, kInputStateAxis;
