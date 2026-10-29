import 'package:flutter/widgets.dart' show Color;
import 'package:magic/magic.dart';

import '../../theme/magic_starter_tokens.dart';
import 'toast.dart' show ToastVariant;

/// The variant axis key for the toast recipe (`ToastVariant.<value>.name`).
const String kToastVariantAxis = 'variant';

/// The text classes of the message: the size and weight [MSToast] has always
/// set. A host's `messageClassName` is appended after them, so the last class of
/// a family wins.
const String kToastMessageClassName = 'text-sm font-medium';

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

/// The semantic fill token each toned [ToastVariant] paints, by variant name, or
/// `null` for the neutral `info` toast.
String? toastFill(String variant) {
  return switch (variant) {
    'success' => 'bg-success',
    'warning' => 'bg-warning',
    'error' => 'bg-destructive',
    _ => null,
  };
}

/// Builds the toast [WindRecipe] using semantic tokens.
///
/// The recipe maps each [ToastVariant] to a bg-* semantic token so the toast
/// tone follows the design-system color ramp without hardcoded hex values.
///
/// The text of a toned variant is never a literal `text-white`: a host's dark
/// fills can be light, and white on them fails 4.5:1. It is [onClassName] when
/// the caller measured one (the widget does, with
/// [MagicStarterTokens.readableOn]), and otherwise the on-colour role of the
/// fill ([toastOnRole]) resolved against [theme]: a role the host defines stays
/// a bare token that its alias map expands, and one it does not define resolves
/// to the role's fallback pair (see [MagicStarterTokens.role]). With neither,
/// every role takes its fallback.
///
/// Emission order: `base ++ variant ++ caller` — no compound variants.
WindRecipe buildToastRecipe({WindThemeData? theme, String? onClassName}) {
  String on(String variant) =>
      onClassName ?? MagicStarterTokens.role(theme, toastOnRole(variant)!);

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
/// padding moves to the message (see [toastActionRecipe]). The side padding
/// halves, `px-4` to `px-2`, and the message column and the cell each carry the
/// other half: the message edge and the label edge are 16 px from the box either
/// way, and the same in a right to left locale, where a physical `pr-2` would
/// have left the message 8 px from its edge against 16.
const String kToastWithActionClassName = 'py-0 px-2';

/// The tone axis key for the toast action recipe.
const String kToastToneAxis = 'tone';

/// Builds the slot recipe for the action of [MSToast].
///
/// Slots:
/// - `message` - the message column. It takes the box's vertical padding and
///   half of its side padding, and shrinks to its content while the text fits
///   and wraps in the width left beside the action once it does not.
///   `flex-initial` is a loose fit, so a short message does not stretch the
///   toast, and `min-w-0` lets the text shrink instead of pushing the action out.
/// - `cell` - the tap target around the label: at least 44 px each way at every
///   width, and as tall as the label asks once large text outgrows that. Its
///   focus ring is `ring-inset`: the cell is as tall as a one line toast, so an
///   outside ring would paint beyond the box. The minimum height does not
///   expand: the widget centres the label in the cell with a `Center` of factor
///   1, which is the label's size raised to the minimum, where a `flex-col`
///   would grow to the whole height an overlay offers it and a fixed `h-11`
///   would overflow at a large text scale.
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
      'message': 'flex-initial min-w-0 px-2 py-3',
      'cell':
          'min-h-11 min-w-11 px-2 rounded-md transition-colors '
          'focus:ring-2 focus:ring-inset',
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
