// Textarea component — folder-local barrel.
//
// The preview is intentionally NOT re-exported here — `previews:refresh`
// discovers `*.preview.dart` directly, and the preview must stay out of the
// release barrel.

export 'textarea.dart' show Textarea;
export 'textarea.recipe.dart'
    show TextareaState, textareaRecipe, kTextareaStateAxis;
