import 'package:flutter/widgets.dart' show Color;
import 'package:magic/magic.dart';

import '../../theme/magic_starter_tokens.dart';
import 'toast.dart' show ToastVariant;

/// The variant axis key for the toast recipe (`ToastVariant.<value>.name`).
const String kToastVariantAxis = 'variant';

/// The on-colour role that reads on the fill of each toned [ToastVariant], by
/// variant name, or `null` for the neutral `info` toast, which has no fill of
/// its own to read against.
String? toastOnRole(String variant) {
  return switch (variant) {
    'success' => 'text-on-success',
    'warning' => 'text-on-warning',
    'error' => 'text-on-destructive',
    _ => null,
  };
}

/// Builds the toast [WindRecipe] using semantic tokens.
///
/// The recipe maps each [ToastVariant] to a bg-* semantic token so the toast
/// tone follows the design-system color ramp without hardcoded hex values.
///
/// The text of a toned variant is the on-colour role of its fill
/// ([toastOnRole]) and never a literal `text-white`: a host's dark fills can be
/// light, and white on them fails 4.5:1. [theme] is the active Wind theme, so a
/// role the host defines stays a bare token that its alias map expands, and one
/// it does not define resolves to the role's fallback pair (see
/// [MagicStarterTokens.role]). With no theme every role takes its fallback.
///
/// Emission order: `base ++ variant ++ caller` — no compound variants.
WindRecipe buildToastRecipe([WindThemeData? theme]) {
  String on(String variant) =>
      MagicStarterTokens.role(theme, toastOnRole(variant)!);

  return WindRecipe(
    base: 'flex flex-row items-center gap-3 px-4 py-3 rounded-lg shadow-md',
    variants: {
      kToastVariantAxis: {
        'info': 'bg-surface border border-color-border text-fg',
        'success': 'bg-success ${on('success')}',
        'warning': 'bg-warning ${on('warning')}',
        'error': 'bg-destructive ${on('error')}',
      },
    },
    defaultVariants: {kToastVariantAxis: 'info'},
  );
}

/// Classes the toast box takes on when it carries an action, appended after the
/// recipe and before the caller's className.
///
/// The action is a 44 px cell, so it cannot sit inside the box's `py-3` without
/// making the toast 24 px taller than one without an action. The vertical
/// padding moves to the message (see [toastActionRecipe]) and the box gives the
/// cell the room it needs on the right: the cell's own `px-2` and this `pr-2`
/// add up to the `px-4` the toast had.
const String kToastWithActionClassName = 'py-0 pr-2';

/// The tone axis key for the toast action recipe.
const String kToastToneAxis = 'tone';

/// Builds the slot recipe for the action of [MSToast].
///
/// Slots:
/// - `message` - the message column. It takes the box's vertical padding and
///   shrinks to its content while the text fits, and wraps in the width left
///   beside the action once it does not. `flex-initial` is a loose fit, so a
///   short message does not stretch the toast, and `min-w-0` lets the text
///   shrink instead of pushing the action out.
/// - `cell` - the tap target around the label, 44 px tall and at least 44 px
///   wide at every width, whose focus ring is `ring-inset`: the cell is as tall
///   as a one line toast, so an outside ring would paint beyond the box, white
///   on white. Its height is fixed rather than a minimum because the cell
///   centres its label with a column, and a column with only a minimum height
///   grows to the whole height an overlay offers it.
/// - `label` - the action text.
///
/// A toned toast passes [onRole], the on-colour role of its fill (already
/// resolved, see [toastOnRole]), and [onColour], what that role paints in the
/// current mode. The label reads the role. The ring and the hover fill are
/// arbitrary-colour classes made from [onColour], because a ring takes a colour
/// and not a text role: they are the label's colour, and so read against the
/// fill exactly as the label does (3:1 for the ring is met wherever 4.5:1 is
/// for the label). Without [onRole] the toast is the neutral `info` one: a
/// primary label on the surface, with a primary ring.
Map<String, String> toastActionRecipe({String? onRole, Color? onColour}) {
  final bool toned = onRole != null;
  final String? hex = onColour == null
      ? null
      : '#${(onColour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  final recipe = WindSlotRecipe(
    slots: const {
      'message': 'flex-initial min-w-0 py-3',
      'cell':
          'flex flex-col justify-center items-center h-11 min-w-11 px-2 '
          'rounded-md transition-colors focus:ring-2 focus:ring-inset',
      'label': 'text-sm font-semibold',
    },
    variants: {
      kToastToneAxis: {
        'neutral': const {
          'cell':
              'hover:bg-surface-container-high focus:ring-primary-500 '
              'dark:focus:ring-primary-400',
          'label': 'text-primary',
        },
        'toned': {
          'cell': hex == null ? '' : 'hover:bg-[$hex]/15 focus:ring-[$hex]',
          'label': onRole ?? '',
        },
      },
    },
    defaultVariants: const {kToastToneAxis: 'neutral'},
  );

  return recipe(variants: {kToastToneAxis: toned ? 'toned' : 'neutral'});
}
