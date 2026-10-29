import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';

/// The state axis key for the input recipe.
const String kInputStateAxis = 'state';

/// Visual state variants for [MSInput].
///
/// - [normal] — Default resting state.
/// - [error] — Validation-failed state; applies destructive border color.
enum InputState {
  /// Default resting state.
  normal,

  /// Validation-failed: applies destructive border and ring.
  error,
}

/// Builds the input [WindRecipe] from a [MagicStarterFieldTheme].
///
/// The recipe is theme-driven (not a top-level const) because the padding and
/// the type of the text are overridable through `MagicStarter.useFieldTheme()`.
///
/// Semantic tokens drive background and border so a `DESIGN.md` override
/// re-skins all inputs without touching this file. Width-agnostic: full-width
/// is the dedicated [MSInput.fullWidth] prop (a `SizedBox` wrapper), not a
/// baked-in `w-full` token, so the default renders at content width.
///
/// [MagicStarterFieldTheme.inputSizeClassName] sits between `text-fg` and
/// `focus:ring-2`, in place of the padding and type the recipe used to spell
/// out. `text-fg` used to sit in the middle of that run (`py-3 lg:py-2.5 text-fg
/// text-sm leading-5`) and now comes ahead of it, so the size is one run a
/// theme replaces without restating the colour; the two orders parse to the
/// same style, because the tokens moved past each other belong to other
/// families. `px-3` stays here: Wind drops the input's own side inset as soon as
/// a className sets any padding.
///
/// The default size is `py-3 lg:py-2.5 text-sm leading-5`, 44 px below `lg` and
/// 40 px from `lg` up. It is padding rather than `min-h-11` because [WInput]
/// paints its border inside the padding (so a border adds no height) and, with
/// the padding and a fixed line height, centres the text in the box without
/// being told to.
WindRecipe buildInputRecipe(MagicStarterFieldTheme theme) {
  return WindRecipe(
    base:
        'rounded-lg border px-3 text-fg ${theme.inputSizeClassName} '
        'focus:ring-2 '
        'disabled:opacity-50 disabled:cursor-not-allowed',
    variants: {
      kInputStateAxis: {
        'normal':
            'bg-surface-container-high border-color-border '
            'focus:border-color-border focus:ring-bg-primary',
        'error':
            'bg-surface-container-high border-bg-destructive '
            'focus:ring-bg-destructive',
      },
    },
    defaultVariants: {kInputStateAxis: 'normal'},
  );
}
