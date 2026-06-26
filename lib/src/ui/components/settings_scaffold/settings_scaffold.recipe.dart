import 'package:magic/magic.dart';

/// Returns the className for the outermost scrollable area wrapper.
///
/// Full-width container that holds the centered constrained inner column.
/// `bg-surface` applies the page-level surface token (iOS grouped background).
///
/// Emission order: base (width + surface token).
String settingsScaffoldScrollableRecipe() {
  return const WindRecipe(
    base: 'w-full bg-surface',
  )();
}

/// Returns the className for the inner centered constrained column.
///
/// Mobile-first: `w-full px-4` fills the screen with edge padding. At `lg`
/// breakpoints the padding collapses (`lg:px-0`) and `max-w-2xl mx-auto`
/// centres the column capped at 672 logical pixels — matching the guest layout
/// max-width convention adapted for authenticated content.
///
/// Emission order: base (width + mx-auto) ++ padding ++ max-width.
String settingsScaffoldContainerRecipe() {
  return const WindRecipe(
    base: 'w-full mx-auto px-4 lg:px-0 max-w-2xl',
  )();
}

/// Returns the className for the children area (SettingsSections column).
///
/// `mt-6` separates the children from the header. `flex flex-col gap-6`
/// spaces the sections evenly — each SettingsSection sits in its own gap row.
///
/// Emission order: base (margin + flex + direction + gap).
String settingsScaffoldChildrenAreaRecipe() {
  return const WindRecipe(
    base: 'mt-6 flex flex-col gap-6',
  )();
}
