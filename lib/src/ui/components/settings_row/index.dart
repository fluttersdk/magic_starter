// SettingsRow component — folder-local barrel.
//
// Atomic Wave component shape: the recipe, the component, and the preview each
// live in their own dotted-suffix file; this index re-exports the public surface
// (component + tone enum + recipe). The preview is intentionally NOT re-exported
// here — `previews:refresh` discovers `*.preview.dart` files directly, and the
// preview must stay out of the release barrel.

export 'settings_row.dart' show SettingsRow;
export 'settings_row.recipe.dart'
    show SettingsRowTone, kSettingsRowToneAxis, settingsRowRecipe;
