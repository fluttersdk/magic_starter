import 'package:magic/magic.dart';

/// Builds the [WindRecipe] for the [MSFormActions] row.
///
/// `wrap`, not `flex-row`: on a narrow phone a cancel button plus a long
/// submit label is wider than the content column, and a Row would overflow
/// it. A Wrap flows the submit onto its own line instead.
///
/// The buttons are auto-width at every breakpoint and never `w-full`. A
/// full-width button (Wind `width: double.infinity`) inside a flex row hands
/// the row an unbounded child and aborts its layout with "RenderBox was not
/// laid out".
WindRecipe formActionsRecipe() {
  return const WindRecipe(
    base: 'w-full wrap items-center justify-end gap-3 pt-2',
  );
}
