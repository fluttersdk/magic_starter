// Avatar component: folder-local barrel.
//
// The preview is intentionally NOT re-exported here: `previews:refresh`
// discovers `*.preview.dart` files directly, and the preview must stay out of
// the release barrel.

export 'avatar.dart' show MSAvatar;
export 'avatar.recipe.dart';
