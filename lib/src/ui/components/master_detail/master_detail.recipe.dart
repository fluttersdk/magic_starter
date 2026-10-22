import 'package:magic/magic.dart';

/// Returns the className of the split row [MSMasterDetail] renders from its
/// breakpoint up.
///
/// Top-aligned, so a short detail does not stretch to the list's height, and
/// with the page's section gap between the two columns. [className] is the
/// caller's override, appended last.
String masterDetailSplitRecipe({String? className}) {
  return const WindRecipe(base: 'w-full flex flex-row items-start gap-6')(
    className: className,
  );
}

/// Returns the className of the list column in the split row.
///
/// A fixed `w-96` (384 px) that never shrinks, so the list keeps its row
/// layout whatever the detail holds. [className] is appended last, so a page
/// with longer rows widens it without restating the rest.
String masterDetailMasterColumnRecipe({String? className}) {
  return const WindRecipe(base: 'w-96 flex-shrink-0')(className: className);
}

/// Returns the className of the detail column in the split row.
///
/// Takes the rest of the row, and `min-w-0` lets a long detail title shrink
/// instead of pushing past the page container.
String masterDetailDetailColumnRecipe({String? className}) {
  return const WindRecipe(base: 'flex-1 min-w-0')(className: className);
}
