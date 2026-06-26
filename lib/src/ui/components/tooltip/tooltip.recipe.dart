/// Default className for the [Tooltip] popover panel.
///
/// Uses semantic alias tokens (`bg-surface-container-high`, `text-fg`,
/// `border-color-border`) so the tooltip re-skins with `MagicStarterTokens`
/// and `design:sync` output, in both light and dark theme, with no hardcoded
/// palette utilities.
const String kTooltipDefaultPanelClassName =
    'bg-surface-container-high text-fg border border-color-border '
    'text-xs px-2 py-1 rounded max-w-xs';
