// Button component — folder-local barrel.
//
// Canonical Wave 4 atomic-component shape: the recipe, the component, and the
// preview each live in their own dotted-suffix file; this index re-exports the
// public surface (component + variant enums). The preview is intentionally NOT
// re-exported here — `previews:refresh` discovers `*.preview.dart` directly,
// and the preview must stay out of the release barrel.

export 'button.dart' show MSButton;
export 'button.recipe.dart'
    show
        ButtonIntent,
        ButtonSize,
        buttonRecipe,
        kButtonIntentAxis,
        kButtonSizeAxis;
