# Design-System Components

- [Introduction](#introduction)
- [Semantic Token Layer](#semantic-token-layer)
  - [MagicStarterTokens](#magicstartertokens)
  - [Wiring into WindThemeData](#wiring-into-windthemedata)
  - [Token Reference](#token-reference)
- [Atomic Folder Shape](#atomic-folder-shape)
- [Component Families](#component-families)
  - [Form Controls](#form-controls)
  - [Display and Feedback](#display-and-feedback)
  - [Selection and Navigation](#selection-and-navigation)
  - [Overlay](#overlay)
  - [Composition and App Chrome](#composition-and-app-chrome)
- [Import Collisions](#import-collisions)
- [design.md.stub](#designmdstub)

<a name="introduction"></a>
## Introduction

Magic Starter ships a complete atomic design-system component library under `lib/src/ui/components/`. Every component is driven by a `WindRecipe` that resolves colors through the `MagicStarterTokens` semantic alias layer, so a single brand configuration flows into all built-in screens and every component your host app composes directly.

All 39 components are exported from `package:magic_starter/magic_starter.dart`.

<a name="semantic-token-layer"></a>
## Semantic Token Layer

<a name="magicstartertokens"></a>
### MagicStarterTokens

`MagicStarterTokens` is a single `const` class with one public member: `defaultAliases`. It is a `Map<String, String>` of 17 semantic roles to light+dark Wind className pairs following the `bg-/text-/border-color-` prefix convention:

```dart
final aliases = MagicStarterTokens.defaultAliases;
// {
//   'surface':                  'bg-white dark:bg-gray-950',
//   'surface-container':        'bg-gray-50 dark:bg-gray-900',
//   'surface-container-high':   'bg-gray-100 dark:bg-gray-800',
//   'fg':                       'text-gray-900 dark:text-gray-50',
//   'fg-muted':                 'text-gray-500 dark:text-gray-400',
//   'fg-disabled':              'text-gray-300 dark:text-gray-600',
//   'primary':                  'bg-primary-600 dark:bg-primary-500',
//   'on-primary':               'text-white dark:text-white',
//   'primary-container':        'bg-primary-50 dark:bg-primary-950',
//   'accent':                   'bg-accent-600 dark:bg-accent-500',
//   'border':                   'border-gray-200 dark:border-gray-800',
//   'border-subtle':            'border-gray-100 dark:border-gray-900',
//   'destructive':              'bg-red-600 dark:bg-red-500',
//   'on-destructive':           'text-white dark:text-white',
//   'destructive-container':    'bg-red-50 dark:bg-red-950',
//   'success':                  'bg-green-600 dark:bg-green-500',
//   'warning':                  'bg-amber-500 dark:bg-amber-400',
// }
```

<a name="wiring-into-windthemedata"></a>
### Wiring into WindThemeData

Pass `MagicStarterTokens.defaultAliases` as the `aliases` argument when constructing your `WindThemeData`:

```dart
WindApp(
  theme: WindThemeData(
    aliases: MagicStarterTokens.defaultAliases,
  ),
  child: const MyApp(),
)
```

Components that reference a semantic role (e.g. `bg-surface`, `text-fg`, `bg-primary`) will resolve through this map at render time. Without the aliases wired in, the semantic class names are silently skipped by Wind, so your brand color and surface tokens will not apply.

<a name="token-reference"></a>
### Token Reference

| Role | Semantic meaning | Maps to (default) |
|------|-----------------|-------------------|
| `surface` | Page/card background | `bg-white dark:bg-gray-950` |
| `surface-container` | Subtle recessed area | `bg-gray-50 dark:bg-gray-900` |
| `surface-container-high` | Elevated container | `bg-gray-100 dark:bg-gray-800` |
| `fg` | Primary text | `text-gray-900 dark:text-gray-50` |
| `fg-muted` | Secondary/supporting text | `text-gray-500 dark:text-gray-400` |
| `fg-disabled` | Disabled state text | `text-gray-300 dark:text-gray-600` |
| `primary` | Brand primary fill | `bg-primary-600 dark:bg-primary-500` |
| `on-primary` | Text on primary fill | `text-white dark:text-white` |
| `primary-container` | Tinted primary area | `bg-primary-50 dark:bg-primary-950` |
| `accent` | Secondary brand fill | `bg-accent-600 dark:bg-accent-500` |
| `border` | Standard border | `border-gray-200 dark:border-gray-800` |
| `border-subtle` | Faint separator | `border-gray-100 dark:border-gray-900` |
| `destructive` | Danger / delete fill | `bg-red-600 dark:bg-red-500` |
| `on-destructive` | Text on danger fill | `text-white dark:text-white` |
| `destructive-container` | Tinted danger area | `bg-red-50 dark:bg-red-950` |
| `success` | Positive / confirmed | `bg-green-600 dark:bg-green-500` |
| `warning` | Caution / review | `bg-amber-500 dark:bg-amber-400` |

To override individual roles, spread `defaultAliases` and replace specific keys:

```dart
WindThemeData(
  aliases: {
    ...MagicStarterTokens.defaultAliases,
    'primary': 'bg-indigo-600 dark:bg-indigo-500',
    'on-primary': 'text-white dark:text-white',
  },
)
```

<a name="atomic-folder-shape"></a>
## Atomic Folder Shape

Every component lives in a 4-file atomic folder:

```
lib/src/ui/components/<name>/
  <name>.dart          # The widget class (StatelessWidget or StatefulWidget)
  <name>.recipe.dart   # WindRecipe function: resolves className from theme tokens
  <name>.preview.dart  # Standalone preview widget for interactive inspection
  index.dart           # Barrel: re-exports the public API for this component
```

The `.recipe.dart` file contains a top-level function (e.g. `buttonRecipe`, `cardRecipe`) that accepts variant/state arguments and returns a Wind className string. The widget delegates its className derivation to the recipe so the visual contract is inspectable and testable in isolation.

<a name="component-families"></a>
## Component Families

<a name="form-controls"></a>
### Form Controls

| Component | Enums / Helpers | Notes |
|-----------|----------------|-------|
| `MSButton` | `ButtonIntent` (primary/secondary/ghost/destructive), `ButtonSize` (sm/md/lg), `buttonRecipe` | Use `ButtonIntent.destructive` for delete / danger actions; `fullWidth: true` fills the parent width (wraps in `SizedBox`, defaults `false`) |
| `MSInput` | `InputState` (idle/focused/error/disabled), `inputRecipe` | Pairs with `MSFormField` for label + error display; `fullWidth: true` fills the parent width (defaults `false`) |
| `MSTextarea` | `TextareaState`, `textareaRecipe` | Multi-line input, same state model as `MSInput`; `fullWidth: true` fills the parent width (defaults `false`). On iOS a focused field carries a Done toolbar above the keyboard, since a multiline field's Return key inserts a newline and would otherwise leave the keyboard with no way out. One consequence for consumer TESTS: while that toolbar is up it schedules a frame callback every frame, so `pumpAndSettle` under `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` never settles; pump explicitly instead |
| `MSCheckbox` | | Boolean toggle; Wind-only, no Material dependency |
| `MSSwitch` | | Toggle; replaces Flutter's `MSSwitch` in Wind layouts |
| `MSRadio` | | Single-select option |
| `MSSelect` | `selectRecipe` | Dropdown single-select backed by an item list |
| `MSCombobox` | `comboboxRecipe` | Searchable single-select with filter input |

<a name="display-and-feedback"></a>
### Display and Feedback

| Component | Enums / Helpers | Notes |
|-----------|----------------|-------|
| `MSBadge` | `BadgeTone` (neutral/primary/success/warning/destructive) | Inline label chip |
| `MSTypography` | `TypographyVariant` (h1-h6/body/caption/overline) | Semantic text wrapper |
| `MSSkeleton` | `SkeletonShape` (line/rect/circle) | Placeholder loading block |
| `MSToast` | `ToastVariant` (info/success/warning/error) | Transient feedback overlay |
| `MSTooltip` | | Hover/long-press hint bubble |
| `MSEmptyState` | | Illustrated empty-list placeholder |
| `MSErrorState` | | Full-screen or inline error with retry |
| `MSDataTable` | `MSDataColumn`, `dataTable*ClassName` | Header plus rows, with the columns passed in. Two modes: the default renders `rows` eagerly (right for a short, complete list); `MSDataTable.paginated` hands the body to magic's `MagicPaginatedListView` inside a bounded box, so a long collection costs the viewport rather than the result and reaching the tail asks the paginator for its next page. The header stays outside the scrolling body. `bodyHeight` is what bounds it, since a `ListView` needs a bound and `shrinkWrap: true` would build every row anyway. Column labels and `loadingLabel` are ALREADY TRANSLATED strings, not keys: half the callers render a label that is not a key at all (a currency code, a region name) |

<a name="selection-and-navigation"></a>
### Selection and Navigation

| Component | Enums / Helpers | Notes |
|-----------|----------------|-------|
| `MSSegmentedControl` | `SegmentedControlSize`, `segmentedControlRecipe` | Inline tab switcher |
| `MSTabs` | `tabsRecipe` | Full tab bar with content panels |
| `MSAccordion` | `MSAccordionItem`, `accordionRecipe` | Collapsible section list |
| `MSNavbar` | | Horizontal top navigation bar |
| `MSDropdownMenu` | `MSDropdownMenuItem` | Contextual action menu |

<a name="overlay"></a>
### Overlay

| Component | Notes |
|-----------|-------|
| `MSDialog` | Modal dialog shell; reads `MagicStarterModalTheme` tokens |
| `MSBottomSheet` | Slide-up sheet; reads `MagicStarterModalTheme` tokens |

<a name="composition-and-app-chrome"></a>
### Composition and App Chrome

| Component | Notes |
|-----------|-------|
| `MSFormField` | Label + input + hint + error layout wrapper |
| `MSCard` | Surface/inset/elevated variants |
| `MSPageHeader` | Full-width responsive header (title, subtitle, leading, actions). Stacked below `sm`, a row above it; `inlineActions` (or `MagicStarterPageHeaderTheme.inlineActions`) makes it a row at every width AND lets a long title shrink instead of overflowing |
| `MSSocialDivider` | "Or continue with" separator for auth forms |
| `MSNotificationDropdown` | Bell-icon dropdown with a live unread badge, backed by a notification stream |
| `MSUserProfileDropdown` | Avatar menu with profile links, theme toggle and logout |
| `MSTeamSelector` | Current-team switcher; requires a registered team resolver |
| `MSPageContainer` | Shared page geometry: width cap, edge margins, vertical rhythm, horizontal safe area. Reads `MagicStarter.manager.pageContainerClassName` |
| `MSPageScaffold` | Full page treatment: page surface + own scroll + `MSPageContainer` + `MSPageHeader` + `gap-6` sections column |

<a name="import-collisions"></a>
## Import Collisions

Every component carries an `MS` prefix (`MSButton`, `MSDialog`, `MSSwitch`, ...),
so none of the barrel's component exports collide with
`package:flutter/material.dart`. You can import both without a `hide` clause:

```dart
import 'package:flutter/material.dart';
import 'package:magic_starter/magic_starter.dart';

// No ambiguity: MSSwitch is the component, Switch is Material's.
```

> Earlier releases exported unprefixed names (`Switch`, `Dialog`, ...) and
> required a `hide` clause. See the migration table in the package README to
> update from the pre-`MS` names.

Or hide the specific colliding names:

```dart
import 'package:flutter/material.dart' hide MSSwitch, MSDialog, MSCheckbox;
import 'package:magic_starter/magic_starter.dart';
```

Widget tests that need both Material and magic_starter types must do the same.

<a name="designmdstub"></a>
## design.md.stub

`assets/stubs/design.md.stub` is a `DESIGN.md` template that covers all 17 semantic roles, typography on the 4px logical scale, rounded/spacing scales, and key component entries with `{{ placeholder }}` tokens.

Consumers copy it into their project root:

```bash
cp $(flutter pub cache list magic_starter)/assets/stubs/design.md.stub DESIGN.md
```

Then fill in brand hex values and fonts, and run the CLI commands:

```bash
# Validate your DESIGN.md against the schema
dart run <app>:artisan design:lint

# Generate the Wind theme from your DESIGN.md
dart run <app>:artisan design:sync
```

`design:sync` regenerates the `WindThemeData(aliases: ...)` map, replacing `MagicStarterTokens.defaultAliases` with your brand-specific values so every component reflects your brand automatically.
