import 'package:magic/magic.dart';

/// Returns the className for the outermost page-surface wrapper.
///
/// Wraps the scroll view and fills at least the full content viewport
/// (`w-full min-h-full`) so the `bg-surface` page token paints the ENTIRE area,
/// not just the content height — otherwise everything below the last section
/// shows the layout's grey content background.
///
/// Uses `min-h-full` (not `h-full`): the scaffold sits inside the app layout's
/// vertical scroll (`overflow-y-auto`), where a hard `h-full` resolves to an
/// unbounded height and Wind rejects it. `min-h-full` fills the viewport as a
/// floor while still growing with taller content.
///
/// Emission order: base (width + min-height + surface token).
String pageScaffoldSurfaceRecipe() {
  return const WindRecipe(
    base: 'w-full min-h-full bg-surface',
  )();
}

/// Returns the className for the children area (the page sections column).
///
/// `mt-6` separates the children from the header. `flex flex-col gap-6`
/// spaces the sections evenly — each section sits in its own gap row.
///
/// Emission order: base (margin + flex + direction + gap).
String pageScaffoldChildrenAreaRecipe() {
  return const WindRecipe(
    base: 'mt-6 flex flex-col gap-6',
  )();
}
