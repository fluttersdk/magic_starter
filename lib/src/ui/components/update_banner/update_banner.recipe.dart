import 'package:magic/magic.dart';

/// Builds the [WindSlotRecipe] for the MSUpdateBanner component.
///
/// A full-width strip, not a card: it sits above the page content, so it
/// carries a bottom border and no radius. Below `md:` the body and the actions
/// stack vertically; from `md:` up they share one row.
///
/// Every colour is a semantic alias (`bg-primary-container`, `text-fg`,
/// `text-primary`, `border-color-border`). Each alias expands to its light and
/// `dark:` pair inside the theme, so the pair is carried without repeating it
/// here, and every one is a token the starter's own theme guarantees. Wind
/// drops an unknown token silently, so no `ai-*` or other consumer-only token
/// belongs in this file.
///
/// ### Slot structure
/// ```
/// root    - full-width strip (stacked below md, one row from md)
/// body    - icon + message row, takes the free width and may shrink
/// icon    - leading glyph, tinted with the primary role
/// message - text-sm fg, flexes and wraps
/// actions - primary + ghost button row
/// ```
const WindSlotRecipe updateBannerRecipe = WindSlotRecipe(
  slots: {
    'root':
        'flex flex-col md:flex-row md:items-center gap-3 w-full '
        'px-4 py-3 border-b border-color-border bg-primary-container',
    'body': 'flex flex-row items-start md:items-center gap-3 md:flex-1 min-w-0',
    'icon': 'text-primary text-lg',
    'message': 'flex-1 min-w-0 text-sm font-medium text-fg',
    'actions': 'flex flex-row items-center gap-2',
  },
);
