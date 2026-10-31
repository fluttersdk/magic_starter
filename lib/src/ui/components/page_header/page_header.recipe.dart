// PageHeader has no variant axes: its layout is driven by the
// MagicStarterPageHeaderTheme tokens and the inlineActions bool, so no
// WindRecipe is needed. The one fixed class lives here.

/// The row that holds a header's actions while the host owns the page chrome:
/// full width so the theme's action container sits at the right edge.
const String pageHeaderHostActionsClassName =
    'w-full flex flex-row justify-end';
