import 'package:magic/magic.dart';

/// The tone axis key for the settings row recipe (`SettingsRowTone.<value>.name`).
const String kSettingsRowToneAxis = 'tone';

/// Tone variants for [MSSettingsRow].
///
/// - [defaultTone] — Standard row: title uses the default foreground token.
/// - [destructive] — Danger row (Delete / Sign-out): title uses the host's
///   destructive text role, resolved by [MSSettingsRow] at build time.
enum SettingsRowTone {
  /// Standard row: title rendered in `text-fg`.
  defaultTone,

  /// Danger row: title rendered in the resolved destructive text role.
  destructive,
}

/// The settings row [WindRecipe].
///
/// Drives the title className for each [SettingsRowTone]. The recipe is a
/// top-level const because [MSSettingsRow] has no theme-override hook; it reads
/// straight from the semantic alias tokens.
///
/// Emission order: `base ++ tone-variant`.
///
/// Tone -> semantic token mapping:
/// - defaultTone: `text-fg font-medium text-base`
/// - destructive: no colour token; [MSSettingsRow] adds the resolved role to the
///   title, since the container class cannot read the theme
const WindRecipe settingsRowRecipe = WindRecipe(
  base: 'min-h-12 px-5 py-4 flex flex-row items-center gap-3',
  variants: {
    kSettingsRowToneAxis: {'defaultTone': 'text-fg', 'destructive': ''},
  },
  defaultVariants: {kSettingsRowToneAxis: 'defaultTone'},
);
