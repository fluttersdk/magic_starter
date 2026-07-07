// SegmentedControl component — folder-local barrel.
//
// Canonical Wave 4 atomic-component shape. The preview is intentionally NOT
// re-exported here — `previews:refresh` discovers `*.preview.dart` files
// directly, and the preview must stay out of the release barrel.

export 'segmented_control.dart' show MSSegmentedControl;
export 'segmented_control.recipe.dart'
    show segmentedControlRecipe, SegmentedControlSize;
