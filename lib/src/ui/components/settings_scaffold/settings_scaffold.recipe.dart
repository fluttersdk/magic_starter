import 'package:magic/magic.dart';

/// Returns the className for the outermost page-surface wrapper.
///
/// Wraps the scroll view and fills the full content viewport (`w-full h-full`)
/// so the `bg-surface` page token paints the ENTIRE area, not just the content
/// height — otherwise everything below the last section shows the layout's grey
/// content background.
///
/// Emission order: base (width + height + surface token).
String settingsScaffoldScrollableRecipe() {
  return const WindRecipe(
    base: 'w-full h-full bg-surface',
  )();
}

/// Returns the className for the inner centered constrained column.
///
/// Mobile-first: `w-full px-4` fills the screen with edge padding. At `lg`
/// breakpoints the padding collapses (`lg:px-0`) and the centred column widens
/// from `max-w-2xl` (672px, comfortable on phones) to `lg:max-w-4xl` (896px) so
/// it does not read as a thin strip on wide desktops while staying centred.
///
/// Emission order: base (width + mx-auto) ++ padding ++ max-width.
String settingsScaffoldContainerRecipe() {
  return const WindRecipe(
    base: 'w-full mx-auto px-4 lg:px-0 max-w-2xl lg:max-w-4xl',
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
