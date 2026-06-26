// SettingsNavRow component — folder-local barrel.
//
// Exports the public component surface (class + recipe constants).
// The preview is intentionally NOT re-exported here — previews:refresh
// discovers *.preview.dart files directly, and the preview must stay out
// of the release barrel.

export 'settings_nav_row.dart' show SettingsNavRow;
export 'settings_nav_row.recipe.dart';
