# Wind theme adoption (`MagicStarter.useWindTheme`)

`MagicStarter.useWindTheme(WindThemeData)` aligns every built-in magic_starter
surface to a Wind semantic palette in a single call. Instead of constructing up
to seven sub-theme structs by hand, you pass the same `WindThemeData` your app
already installs at its root and the starter kit derives all seven sub-themes
(navigation, modal, form, card, page header, layout, auth) from its semantic
alias roles.

## The one-call adoption path

```dart
import 'package:magic_starter/magic_starter.dart';

// In your service provider boot(), before any UI is painted:
MagicStarter.useWindTheme(
  WindThemeData(
    colors: {'primary': myBrandColor},
    aliases: MagicStarterTokens.defaultAliases, // or a design:sync-generated map
  ),
);
```

`useWindTheme` builds a `MagicStarterTheme` via `MagicStarterTheme.fromWind(...)`
and delegates to the existing `MagicStarter.useTheme(...)` hook. It is purely
additive:

- `MagicStarter.useTheme(MagicStarterTheme)` still works unchanged.
- Every individual `use*Theme()` setter (`useCardTheme`, `useFormTheme`, ...)
  still works and overrides the derived value afterward, so you can adopt the
  whole palette and then fine-tune one surface.

## How derivation works

Every color-bearing className fragment in the sub-theme defaults is rebuilt from
the 17 semantic roles. Because each alias carries its own `dark:` counterpart
(for example `bg-surface` expands to `bg-white dark:bg-gray-950`), a single
semantic token replaces every hand-written `bg-white dark:bg-gray-800` pair. No
manual `dark:` palette utility is emitted.

A role is emitted as a semantic token only when the passed `WindThemeData`
defines it, either as a key in its `aliases` map or as the backing color key in
its `colors` map (`bg-primary` is backed by the `primary` color). When the theme
does not define a role, the property keeps the shipped default palette pair for
that role, so a partially-configured theme never produces a silent no-op
(invisible) surface. Pair `useWindTheme` with a full alias map to re-skin every
surface.

## The 17 semantic roles

The role tokens match the `MagicStarterTokens.defaultAliases` contract:

| Role token | Purpose |
|------------|---------|
| `bg-surface` | Page and base backgrounds |
| `bg-surface-container` | Cards, panels, dialog containers |
| `bg-surface-container-high` | Input backgrounds, nested panels, hover fills |
| `text-fg` | Primary text |
| `text-fg-muted` | Secondary and muted text |
| `text-fg-disabled` | Placeholder and disabled text |
| `bg-primary` / `text-primary` | Brand action background and brand text |
| `text-on-primary` | Text and icons on the primary surface |
| `border-color-border` | Dividers and card borders |
| `border-color-border-subtle` | Hairline borders (brand bar) |
| `bg-destructive` / `text-on-destructive` | Danger action surface and its text |
| `bg-destructive-container` | Tinted danger surface (error banners) |
| `text-destructive` | Inline error text (falls back to red when undefined) |
| `bg-warning` | Warning action surface |

## Alias-to-property mapping

Each sub-theme property below is rebuilt from the listed semantic roles. Layout,
spacing, radius, and dimension tokens are preserved as-is.

### Navigation

| Property | Roles used |
|----------|-----------|
| `activeItemClassName` | `text-primary` (+ `bg-primary/10`) |
| `hoverItemClassName` | `bg-surface-container-high` |
| `brandClassName` | `text-primary` |
| `bottomNavActiveClassName` | `text-primary` |
| `avatarTextClassName` | `text-primary` |

### Modal

| Property | Roles used |
|----------|-----------|
| `containerClassName` | `bg-surface-container` |
| `titleClassName` | `text-fg` |
| `descriptionClassName` | `text-fg-muted` |
| `footerClassName` | `bg-surface-container-high` |
| `primaryButtonClassName` | `bg-primary`, `text-on-primary` |
| `secondaryButtonClassName` | `bg-surface-container`, `border-color-border`, `bg-surface-container-high`, `text-fg` |
| `dangerButtonClassName` | `bg-destructive`, `text-on-destructive` |
| `warningButtonClassName` | `bg-warning` |
| `errorClassName` | `text-destructive` |
| `inputClassName` | `bg-surface-container-high`, `border-color-border`, `text-fg` |

### Form

| Property | Roles used |
|----------|-----------|
| `inputClassName` | `bg-surface-container-high`, `border-color-border`, `text-fg` |
| `labelClassName` | `text-fg` |
| `errorClassName` | `text-destructive` |
| `placeholderClassName` | `text-fg-disabled` |
| `primaryButtonClassName` | `bg-primary`, `text-on-primary` |
| `secondaryButtonClassName` | `border-color-border`, `text-fg-muted`, `bg-surface-container` |
| `linkClassName` | `text-primary` |
| `checkboxLabelClassName` | `text-fg-muted`, `text-fg` |

### Card

| Property | Roles used |
|----------|-----------|
| `surfaceClassName` | `bg-surface`, `border-color-border` |
| `insetClassName` | `bg-surface-container`, `border-color-border` |
| `elevatedClassName` | `bg-surface` (+ `shadow-md`) |
| `titleClassName` | `text-fg` |

### Page header

| Property | Roles used |
|----------|-----------|
| `containerClassName` / `containerInlineClassName` | `border-color-border` |
| `titleClassName` | `text-fg` |
| `subtitleClassName` | `text-fg-muted` |
| `backControlClassName` | `text-fg-muted`, `text-fg` |

### Layout

| Property | Roles used |
|----------|-----------|
| `sidebarClassName` | `bg-surface`, `border-color-border` |
| `headerClassName` | `bg-surface`, `border-color-border` |
| `brandBarClassName` | `border-color-border-subtle` |

Numeric dimensions (`sidebarWidth`, `headerHeight`) and the `wColor()`
content/drawer background color-key fields keep their defaults; they are not
expressed as semantic className tokens.

### Auth

| Property | Roles used |
|----------|-----------|
| `cardClassName` | `bg-surface-container`, `border-color-border` |
| `titleClassName` | `text-fg` |
| `subtitleClassName` | `text-fg-muted` |
| `errorBannerClassName` | `bg-destructive-container`, `text-destructive` |
| `themeToggleClassName` | `bg-surface-container-high` (hover) |
| `themeToggleIconClassName` | `text-fg-muted` |
| `socialDividerTextClassName` | `text-fg-muted` |
| `guestButtonClassName` | `border-color-border`, `text-fg-muted`, `bg-surface-container` |
| `registrationLinkClassName` | `text-fg-muted` |
| `registrationLinkTextClassName` | `text-primary` |

## Note: install the same WindThemeData as the ambient theme

`useWindTheme` derives className strings that reference semantic alias tokens
(`bg-surface`, `text-fg`, `bg-primary`, ...). Those tokens only resolve to your
palette when the SAME `WindThemeData` is installed as the ambient `WindTheme`
that renders the app. `useWindTheme` maps the roles onto the component
properties; the ambient `WindTheme` is what expands the tokens at paint time.
For any role the passed theme does not define, the derivation falls back to the
shipped default palette pair (so an omitted role never produces an invisible
surface), but a defined role that is missing from the ambient `WindTheme` will
render its bare token unresolved.
