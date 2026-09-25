// KeyValueEditor component: folder-local barrel.
//
// Canonical Wave 4 atomic-component shape: the recipe, the component, and the
// preview each live in their own dotted-suffix file; this index re-exports
// the public surface (component + row value type + recipe). The preview is
// intentionally NOT re-exported here: `previews:refresh` discovers
// `*.preview.dart` files directly, and the preview must stay out of the
// release barrel.

export 'key_value_editor.dart' show MSKeyValueEditor, MSKeyValueRow;
export 'key_value_editor.recipe.dart';
