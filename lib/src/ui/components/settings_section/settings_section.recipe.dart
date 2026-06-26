import 'package:magic/magic.dart';

/// Returns the className for the grouped rounded container.
///
/// iOS inset-grouped appearance: `bg-surface-container` elevation token,
/// `rounded-lg` corner radius, a hairline border via `border-color-border-subtle`,
/// and `overflow-hidden` so child rows are clipped to the rounded corners.
///
/// Emission order: base (surface + layout) ++ border ++ shape.
String settingsSectionContainerRecipe() {
  return const WindRecipe(
    base:
        'w-full bg-surface-container rounded-lg border border-color-border-subtle overflow-hidden flex flex-col',
  )();
}

/// Returns the className for the section header and footer caption text.
///
/// Mirrors the iOS inset-grouped section header: 13pt-equivalent (`text-xs`),
/// uppercase muted label, with `px-1` horizontal nudge.
///
/// Emission order: base (size + weight + case + spacing + color + padding).
String settingsSectionCaptionRecipe() {
  return const WindRecipe(
    base: 'text-xs font-medium uppercase tracking-wide text-fg-muted px-1',
  )();
}

/// Returns the className for the hairline divider inserted between child rows.
///
/// A 1-logical-pixel horizontal rule using the subtle border token so it
/// blends cleanly in both light and dark surfaces without a raw color.
String settingsSectionDividerRecipe() {
  return const WindRecipe(
    base: 'w-full border-t border-color-border-subtle',
  )();
}
