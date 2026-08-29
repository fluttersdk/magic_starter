---
paths:
  - "lib/src/ui/components/**/*.dart"
---

# Design-System Components

The 30 `MS`-prefixed components under `lib/src/ui/components/`. These carry a visual contract and nothing else: an API call, a wizard or a layout signal belongs in `lib/src/ui/widgets/` instead.

## Folder shape is fixed

Every component is a 4-file atomic folder, and a new one gets all four:

```
lib/src/ui/components/<name>/
  <name>.dart          # The widget class (StatelessWidget or StatefulWidget)
  <name>.recipe.dart   # WindRecipe: resolves className from theme tokens
  <name>.preview.dart  # Standalone preview for interactive inspection
  index.dart           # Barrel: the public API of this component
```

- Class hierarchy: `extends StatelessWidget` or `extends StatefulWidget`, NEVER `MagicStatefulView`.
- Naming: the class is `MS<Name>`, the folder and files are `snake_case`. No `MagicStarter` prefix on a component; that prefix belongs to the starter's own widgets and controllers.
- Export through `index.dart`, then through the package barrel. A component the barrel does not export is not part of the API.
- The `.recipe.dart` file holds a top-level `WindRecipe` (or a recipe function when a theme hook feeds it), so the visual contract is inspectable and testable without mounting the widget. The widget delegates className derivation to it rather than composing strings inline.

## Styling rules

- Wind UI exclusively. No Material widgets, except `Icons.*` for icon data and the Material `Dialog` shell inside `MSDialog`.
- Style through the semantic alias layer (`bg-surface*`, `text-fg*`, `border-color-border*`, `bg-primary`, `text-on-primary`, `bg-destructive`), not raw `gray-*` / `red-*` palette classes. Wind drops an unknown alias SILENTLY, so a token that does not exist renders identically to no token at all: assert the RESOLVED colour in a test, never the className string.
- The alias contract ships no destructive TEXT role. `text-destructive` parses and then resolves to nothing; `MSErrorState` keeps a raw `text-red-*` pair on purpose and says so in a docblock.
- Dark mode: every colour token needs its `dark:` pair in the same className.
- Never hardcode a modal className. Dialogs read `MagicStarter.manager.modalTheme` at build time (`titleClassName`, `primaryButtonClassName`, `dangerButtonClassName`, ...).

## Component-specific contracts

- **`MSCard`**: `noPadding` for full-bleed list content; `CardVariant` (`surface` default, `inset`, `elevated`) drives background, border and shadow. In `noPadding` mode the title gets `px-6 pt-6 pb-3` so it aligns with row content, and no caller adds padding around it.
- **`MSPageHeader`**: `WDiv` with `flex-col sm:flex-row`, a `border-b` separator, required `title`, optional `subtitle`, `leading`, `titleSuffix` and `actions` (rendered in a trailing `flex flex-row gap-2` row only when non-empty). `inlineActions` is `bool?` falling back to `MagicStarterPageHeaderTheme.inlineActions`, and it does TWO things that are required together: it swaps `containerClassName` for `containerInlineClassName`, AND it gives the title row `flex-1 min-w-0` instead of `sm:flex-1`. Theming the container into a row at every width without the flag leaves the title column a loose fit below `sm`, so a long title takes its intrinsic width and overflows. `MSPageScaffold` does not expose the argument, which is why the theme field exists.
- **Page geometry**: `MSPageContainer` carries the shared width cap, edge margins and vertical rhythm from `MagicStarter.manager.pageContainerClassName`; `MSPageScaffold` is the full page treatment (surface, own scroll, container, header, `gap-6` sections column). A component never puts a `max-w-*` or a page-level `px-*` on itself.
- **`MSDataTable`**: the default constructor renders every row; `MSDataTable.paginated` hands the body to magic's `MagicPaginatedListView` inside a box bounded by `bodyHeight` (a `ListView` needs a bound, and `shrinkWrap: true` would build every row anyway). The header stays outside the scrolling body. The component LISTENS to its paginator: reading `isEmpty` once in a stateless build only produces an empty state when the caller already awaited the first page. Column labels and `loadingLabel` are ALREADY TRANSLATED strings, not keys. The column track is a wrapper rather than a `flex-1` on the cell, so `alignEnd` applies to a flexing column too.
- **`MSConfirmDialog`**: `static Future<bool> show(context, {required title, description, confirmLabel, cancelLabel, variant, onConfirm})`. `ConfirmDialogVariant.danger` for destructive actions (delete team, revoke session), `.warning` for caution (leave team), `.primary` for neutral. The confirm button className resolves through `_resolveConfirmClassName()` against the modal theme, never a literal.
- **`MSDialog`**: sticky header and footer with a scrollable body (`ListView(shrinkWrap: true)`), Material `Dialog` shell around Wind content. `footerBuilder: Widget Function(BuildContext dialogContext)?` exists so a caller can `Navigator.pop(dialogContext)` with the dialog's own context.
- **Dialog footers**: compact right-aligned buttons with `justify-end gap-2 wrap`, never `flex-1` full-width. `wrap` is required alongside `justify-end`, since Wind renders it as `Wrap(alignment: WrapAlignment.end)` and a constrained container overflows without it.
- **Dialog safe area**: compute `safeHeight` from `MediaQuery.viewPaddingOf(context)`, subtract the top and bottom insets from screen height, then apply `* 0.85` for `maxHeight`. Vertical `insetPadding: 24` keeps a phone off the edges.
- **`MSTeamSelector`**: built from `MagicStarter.manager.teamResolver` callbacks. **`MSNotificationDropdown`**: `StreamBuilder<List<DatabaseNotification>>` for the live unread badge. **`MSUserProfileDropdown`**: reads `MagicStarter.navigationTheme.dropdownAvatarClassName` for the trigger avatar.
- **`MSSocialDivider`**: `WDiv` + centred `WText('or')`, used between a form and the social login buttons.

## Sizing and tree-shaking

- `MSButton`, `MSInput` and `MSTextarea` take `bool fullWidth = false`. It wraps the rendered widget in a `SizedBox(width: double.infinity)` rather than adding a className token, because Material widgets ignore cross-axis stretch (flutter/flutter#19399).
- `Icons.*` in a `build()` goes to a `static const _iconName = Icons.xxx` field. Flutter web cannot tree-shake icons referenced inline.
