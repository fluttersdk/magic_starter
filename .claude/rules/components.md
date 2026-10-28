---
paths:
  - "lib/src/ui/components/**/*.dart"
---

# Design-System Components

The 46 `MS`-prefixed components under `lib/src/ui/components/`. These carry a visual contract and nothing else: an API call, a wizard or a layout signal belongs in `lib/src/ui/widgets/` instead.

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
- The alias contract ships no destructive TEXT role. `text-destructive` parses and then resolves to nothing unless the host defines it, so resolve it with `MagicStarterTokens.role(WindTheme.maybeDataOf(context), 'text-destructive')`, which keeps a host's alias and falls back to the red pair. `MSErrorState`'s context-free icon class keeps a raw `text-red-*` pair and says so in a docblock.
- Dark mode: every colour token needs its `dark:` pair in the same className.
- Never hardcode a modal className. Dialogs read `MagicStarter.manager.modalTheme` at build time (`titleClassName`, `primaryButtonClassName`, `dangerButtonClassName`, ...).

## Component-specific contracts

- **`MSCard`**: `noPadding` for full-bleed list content; `CardVariant` (`surface` default, `inset`, `elevated`) drives background, border and shadow. In `noPadding` mode the title gets `px-6 pt-6 pb-3` so it aligns with row content, and no caller adds padding around it.
- **`MSPageHeader`**: `WDiv` with `flex-col sm:flex-row`, a `border-b` separator, required `title`, optional `subtitle`, `leading`, `titleSuffix` and `actions` (rendered in a trailing `flex flex-row gap-2` row only when non-empty). `inlineActions` is `bool?` falling back to `MagicStarterPageHeaderTheme.inlineActions`, and it does TWO things that are required together: it swaps `containerClassName` for `containerInlineClassName`, AND it gives the title row `flex-1 min-w-0` instead of `sm:flex-1`. Theming the container into a row at every width without the flag leaves the title column a loose fit below `sm`, so a long title takes its intrinsic width and overflows. `MSPageScaffold` does not expose the argument, which is why the theme field exists.
- **`MSPageHeader` title role**: the title is `Semantics(header: true)` in all three sizes (`_buildTitle`), so heading navigation finds the page title. A new title text goes through it, never a bare `WText`.
- **`MSPageHeader` sizes**: `size` is `MSPageHeaderSize?` falling back to `MagicStarterPageHeaderTheme.largeTitle` (`large` when set, `regular` otherwise; `compact` is never a theme default). `large` changes the title class only. `compact` is its own layout, a `NavigationToolbar` in a 44 pt `SizedBox` under a top `SafeArea`, with no subtitle and no suffixes; it blurs through a `BackdropFilter` sized by `compactBarBlurSigma` and swaps to `compactBarOpaqueClassName` with no blur when `MediaQuery.highContrastOf` is true.
- **`MSPageScaffold(largeTitle:)`**: `bool?` with the same theme fallback. The collapse needs a scroll position, so it lives here, not in the header: a private frame stacks the compact header over the scroll view and shows it once the large header's bottom edge passes under `paddingOf(context).top + compactBarHeight`, measured from the header's render box (never a fixed offset). Only `depth == 0` vertical notifications count. The bar is unmounted while fully hidden, so the title and actions appear once in the tree except while the bar shows; while it does, the large header is `ExcludeSemantics` (it is still partly on screen behind the bar), and while the bar fades out the bar is, so the semantics tree holds one heading per visible title.
- **Page geometry**: `MSPageContainer` carries the shared width cap, edge margins and vertical rhythm from `MagicStarter.manager.pageContainerClassName`; `MSPageScaffold` is the full page treatment (surface, own scroll, container, header, `gap-6` sections column). A component never puts a `max-w-*` or a page-level `px-*` on itself.
- **`MSDataTable`**: the default constructor renders every row; `MSDataTable.paginated` hands the body to magic's `MagicPaginatedListView` inside a box bounded by `bodyHeight` (a `ListView` needs a bound, and `shrinkWrap: true` would build every row anyway). The header stays outside the scrolling body. The component LISTENS to its paginator: reading `isEmpty` once in a stateless build only produces an empty state when the caller already awaited the first page. Column labels and `loadingLabel` are ALREADY TRANSLATED strings, not keys. The column track is a wrapper rather than a `flex-1` on the cell, so `alignEnd` applies to a flexing column too.
- **`MSConfirmDialog`**: `static Future<bool> show(context, {required title, description, confirmLabel, cancelLabel, variant, onConfirm})`. `ConfirmDialogVariant.danger` for destructive actions (delete team, revoke session), `.warning` for caution (leave team), `.primary` for neutral. The confirm button className resolves through `_resolveConfirmClassName()` against the modal theme, never a literal.
- **`MSMasterDetail`**: layout only. From `breakpoint` (`'lg'`) a `w-96 flex-shrink-0` list column and a `flex-1 min-w-0` detail column in a top-aligned row; below it `detail ?? master`. No page geometry and no scroll of its own, so it sits inside `MSPageScaffold`. Breakpoints resolve through `MagicStarterBreakpoints.isAtLeast`, which throws a `StateError` naming the setting for a name the Wind theme lacks, as the shell does.
- **`MSBottomSheet.show(dialogBreakpoint:)`**: from that breakpoint the call returns `MSDialog.show` with the same arguments, `scrollable` included (which is why `MSDialog` has it too). Null keeps the sheet at every width.
- **`MSDialog`**: sticky header and footer with a scrollable body (`ListView(shrinkWrap: true)`), Material `Dialog` shell around Wind content. `footerBuilder: Widget Function(BuildContext dialogContext)?` exists so a caller can `Navigator.pop(dialogContext)` with the dialog's own context.
- **Dialog footers**: compact right-aligned buttons with `justify-end gap-2 wrap`, never `flex-1` full-width. `wrap` is required alongside `justify-end`, since Wind renders it as `Wrap(alignment: WrapAlignment.end)` and a constrained container overflows without it.
- **Dialog safe area**: compute `safeHeight` from `MediaQuery.viewPaddingOf(context)`, subtract the top and bottom insets from screen height, then apply `* 0.85` for `maxHeight`. Vertical `insetPadding: 24` keeps a phone off the edges.
- **`MSTeamSelector`**: built from `MagicStarter.manager.teamResolver` callbacks. **`MSUserProfileDropdown`**: reads `MagicStarter.navigationTheme.dropdownAvatarClassName` and `dropdownAvatarTextClassName` for the trigger avatar, and listens to `Auth.stateNotifier` itself: the shell mounts it const, so it is not rebuilt when the shell is. With no name it draws a person glyph, never an initial taken from a placeholder word. The bell dropdown (`StreamBuilder<List<DatabaseNotification>>` for the live unread badge) is not one of this package's components anymore: it is `NotificationDropdown` in `magic_notifications`, mounted by `MagicStarterAppLayout._buildNotificationBell()`.
- **Team switcher and user menu panels**: every colour comes from `MagicStarter.dropdownTheme` (`panelClassName`, `dividerClassName`, `itemClassName`, `tileClassName`, `textClassName`, `mutedTextClassName`, `dangerTextClassName`, `dangerTileClassName`), never a `gray-*` literal in the widget. It is its own sub-theme because a host replaces `navigationTheme` whole after `useWindTheme()`. Both panels carry `overflow-hidden` in the widget, after the theme's classes, so a hovered row cannot paint over the rounded corners and a theme cannot drop the clip. `panelClassName` must keep a border (`border border-transparent` at the least): Wind clips a bordered box inside the border, and wraps a `ClipRRect` around the decorated container of a borderless one, which cuts off the panel's shadow. A tile's resting fill must differ from `itemClassName`'s, and a `hover:` token on the tile reacts only to the pointer being on the tile itself (a `WDiv` with one is its own anchor).
- **`MSButton`**: the recipe is `buildButtonRecipe(MagicStarter.buttonTheme)`, not a const. `shapeClassName` sits where `rounded-lg` was in the base; `smClassName` / `mdClassName` / `lgClassName` carry padding, minimum height and label type of a size; `secondaryBorderClassName` is the one colour field, since a border costs layout (`''` drops it; `border-0` paints a hairline). Colours stay in the recipe as semantic aliases, so `useWindTheme()` derives nothing and resets the theme. Its own sub-theme, because a setter assigns the whole struct. The default theme must keep emitting the previous classNames byte for byte (a test pins all 12). Below `lg` the 44 px hit area wraps every size and adds nothing to one that is already 44. A 44 px size is `py-[11px]` plus `leading-[22px]`, never `min-h-11` alone (Wind gives the box a minimum height and no alignment, so the label sits at its top). A caller `className` is appended after the theme and wins, which is how the form theme's submit strings override it on the auth screens.
- **`MSSocialDivider`**: `WDiv` + centred `WText('or')`, used between a form and the social login buttons.
- **`MSFormActions`**: the cancel/submit footer row for a form; `submitLabel` and `isSubmitting` are required, `cancelLabel`/`onCancel` are optional (null renders no cancel button). Wraps (`wrap`) rather than stretching, since a full-width `MSButton` hands the row an unbounded child.
- **`MSSwitchRow`**: a full-width `MSSwitch(label:)`. The switch lays its label out itself (a two-slot render box, not a flex row, so it works in an unbounded-width row and under `IntrinsicHeight`): the label wraps in the width beside the track, toggles the switch when tapped, and is its accessibility name. A one-line label sits on the track's centre line, a wrapped one aligns to its top. The row's className can be overridden by a caller; the label layout cannot.
- **`MSHeaderAction`**: a page-header action that collapses to an icon-only glyph below `lg` and a labelled `MSButton` at `lg` and up; `label` becomes the icon form's accessibility label rather than being dropped.
- **`MSKeyValueEditor`** / **`MSKeyValueRow`**: controlled editor for an ordered list of key/value pairs (e.g. HTTP headers); every mutation emits a fresh list via `onChanged`, never mutating `value` in place.
- **`MSStringValueList`**: controlled editor for a short list of distinct strings, rendered as `WBadge` chips; commits on Enter/IME-done, trims and case-insensitively de-duplicates before appending, and Backspace on an empty draft drops the last chip.
- All five take every visible string as a required constructor parameter (no `cancelLabel`/`onCancel` pair, which is optional): none reads a translation key of its own.

## Sizing and tree-shaking

- `MSButton`, `MSInput` and `MSTextarea` take `bool fullWidth = false`. It wraps the rendered widget in a `SizedBox(width: double.infinity)` rather than adding a className token, because Material widgets ignore cross-axis stretch (flutter/flutter#19399).
- `Icons.*` in a `build()` goes to a `static const _iconName = Icons.xxx` field. Flutter web cannot tree-shake icons referenced inline.
