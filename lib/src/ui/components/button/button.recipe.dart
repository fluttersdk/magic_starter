import 'package:flutter/widgets.dart' show BuildContext;
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';
import '../../theme/magic_starter_tokens.dart';

/// The intent axis key for the button recipe.
const String kButtonIntentAxis = 'intent';

/// The size axis key for the button recipe.
const String kButtonSizeAxis = 'size';

/// The smallest hit area, in logical pixels, every [MSButton] gets below `lg`:
/// the iOS minimum tap target.
///
/// By default `sm` paints 32 px and `md` about 36 px tall, so this is a hit area
/// around the button and not a bigger button; see [MSButton] for how it is laid
/// out. A [MagicStarterButtonTheme] that makes a size 44 px or taller leaves the
/// area exactly the size of the button.
const double kButtonMinTapExtent = 44;

/// Caller className that turns a [ButtonIntent.secondary] button into an
/// outlined danger action (remove, disable, revoke, disconnect).
///
/// The label colour is the host's `text-destructive` role when its theme defines
/// one and the red text pair otherwise (see [MagicStarterTokens.role]); a bare
/// `text-destructive` would render neutral where the host omits it, since wind
/// drops an unknown alias silently. The border is a raw red pair on purpose: the
/// alias contract ships no destructive BORDER role. Needs a [context] under the
/// `WindTheme`, so call it at build time. Appended after the intent, so
/// last-wins replaces the secondary text and border colours.
String buttonDangerOutlineClassName(BuildContext context) {
  final textRole = MagicStarterTokens.role(
    WindTheme.maybeDataOf(context),
    'text-destructive',
  );

  return '$textRole border-red-200 dark:border-red-700';
}

/// Visual intent variants for [MSButton].
///
/// - [primary] — Brand-colored filled button for the main call-to-action.
/// - [secondary] — Neutral surface button for secondary actions.
/// - [ghost] — Transparent button for low-emphasis actions.
/// - [destructive] — Red filled button for dangerous or irreversible actions.
enum ButtonIntent {
  /// Main call-to-action: brand-primary background.
  primary,

  /// Secondary action: neutral surface background.
  secondary,

  /// Low-emphasis action: transparent background.
  ghost,

  /// Dangerous action: destructive red background.
  destructive,
}

/// Size variants for [MSButton].
///
/// - [sm] — Compact button for toolbars and dense layouts.
/// - [md] — Default button size for most contexts.
/// - [lg] — Larger button for prominent hero actions.
enum ButtonSize {
  /// Compact button: smaller padding and text.
  sm,

  /// Default button: standard padding and text.
  md,

  /// Large button: generous padding and larger text.
  lg,
}

/// Builds the button [WindRecipe] from a [MagicStarterButtonTheme].
///
/// The recipe is theme-driven (not a top-level const) because the shape, the
/// three size classes and the secondary border are overridable through
/// `MagicStarter.useButtonTheme()`. The colour classes stay in here, written as
/// semantic aliases, so a `DESIGN.md` alias map re-skins every button without
/// the theme. With the default theme the output is byte-identical to the const
/// recipe this replaced.
///
/// Emission order: `base ++ intent-classes ++ size-classes ++ compound`.
///
/// There is no `justify-center` in the base: in Wind that maps to WButton's
/// Container alignment, which forces the button to expand and fill its
/// constraints (full-width). A default Button shrinks to its content (the
/// `inline-flex` intent); the single-child label is centred by the shrink-wrapped
/// padding box. A caller `className` APPENDS after this recipe (parser last-wins
/// resolves conflicts per family), so it refines the recipe rather than replacing
/// it; full-width is the dedicated `fullWidth` prop (a SizedBox wrapper), not a
/// className token.
WindRecipe buildButtonRecipe(MagicStarterButtonTheme theme) {
  return WindRecipe(
    base:
        'inline-flex items-center font-medium ${theme.shapeClassName} '
        'transition-colors disabled:opacity-50 disabled:cursor-not-allowed '
        'focus:outline-none focus:ring-2 focus:ring-offset-1',
    variants: {
      kButtonIntentAxis: {
        'primary':
            'bg-primary text-on-primary hover:opacity-90 focus:ring-color-border',
        // The border is dropped from the string, not blanked in place, so an
        // empty theme field leaves no doubled space between the other tokens.
        'secondary': [
          'bg-surface-container-high text-fg',
          theme.secondaryBorderClassName,
          'hover:bg-surface-container-high hover:opacity-80',
        ].where((part) => part.isNotEmpty).join(' '),
        'ghost': 'bg-transparent text-fg hover:bg-surface-container-high',
        'destructive':
            'bg-destructive text-on-destructive hover:opacity-90 '
            'focus:ring-bg-destructive',
      },
      kButtonSizeAxis: {
        'sm': theme.smClassName,
        'md': theme.mdClassName,
        'lg': theme.lgClassName,
      },
    },
    defaultVariants: {kButtonIntentAxis: 'primary', kButtonSizeAxis: 'md'},
  );
}
