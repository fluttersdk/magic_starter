import 'package:magic/magic.dart';

/// Builds the [WindRecipe] for the [MSSwitchRow] layout.
///
/// `w-full` only: the switch lays out its own label (see `MSSwitch.label`),
/// so the row just hands it the column's width to wrap the label in.
WindRecipe switchRowRecipe() {
  return const WindRecipe(base: 'w-full');
}
