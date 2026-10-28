# Wind theme adoption (`MagicStarter.useWindTheme`)

`MagicStarter.useWindTheme(WindThemeData)` aligns every built-in magic_starter
surface to a Wind semantic palette in a single call. Instead of constructing up
to nine sub-theme structs by hand, you pass the same `WindThemeData` your app
already installs at its root and the starter kit derives the eight colour-bearing
sub-themes (navigation, modal, form, card, page header, layout, auth, dropdown)
from its semantic alias roles. The ninth, the button theme, is shape and size
only and is set by hand; see [Button](#button).

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

A host that defines `text-destructive` (as an alias, or through a `destructive` colour) re-skins the outlined danger buttons, the destructive `MSSettingsRow` title and the inline error text; without it they fall back to the red pair. `MagicStarterTokens.role(theme, token)` is the lookup they share.

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
| `secondaryButtonClassName` | `text-fg-muted`, `bg-surface-container` (hover); the border is the button theme's |
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

### Dropdown

The panels of `MSTeamSelector` and `MSUserProfileDropdown`. This is its own
sub-theme, not more fields on `navigation`, because a host that sets
`useNavigationTheme()` after `useWindTheme()` replaces the navigation theme
whole and would hand any field it omitted back to the stock grey.

| Property | Roles used |
|----------|-----------|
| `panelClassName` | `bg-surface-container`, `border-color-border` |
| `dividerClassName` | `border-color-border` |
| `itemClassName` | `bg-surface-container-high` (hover) |
| `tileClassName` | `bg-surface` |
| `textClassName` | `text-fg` |
| `mutedTextClassName` | `text-fg-muted` |
| `dangerTextClassName` | `text-destructive` (danger state) |
| `dangerTileClassName` | `bg-destructive-container` (danger state) |

The tile takes `bg-surface` rather than `bg-surface-container-high` because the
hovered row is already `bg-surface-container-high`; a tile with that fill would
disappear into it. Geometry, including the `overflow-hidden` that keeps a hovered
row inside the panel's rounded corners, stays in the widgets.

Keep a border in `panelClassName`, even an invisible one
(`border border-transparent`), for the panel's shadow to survive: Wind clips a
bordered box inside the border, while a borderless one gets a `ClipRRect` around
the decorated container, which cuts the box shadow off.

### Button

Nothing is derived. `MSButton`'s recipe already writes the semantic aliases
(`bg-primary`, `text-on-primary`, `border-color-border`, ...) itself, so an alias
map re-skins every button, and `MagicStarterButtonTheme` carries only what an
alias cannot: the corner radius, the padding, minimum height and label type of
each size, and the secondary border. `useWindTheme()` and `useTheme()` reset it
to its defaults, so set it after them.

| Property | Default |
|----------|---------|
| `shapeClassName` | `rounded-lg` |
| `smClassName` | `px-3 py-1.5 text-sm` (32 px) |
| `mdClassName` | `px-4 py-2 text-sm` (36 px) |
| `lgClassName` | `px-5 py-3 text-base` (47 px) |
| `secondaryBorderClassName` | `border border-color-border` |

One 44 px capsule for every intent and size:

```dart
const standard = 'px-5 py-[11px] text-[17px] leading-[22px] font-semibold';

MagicStarter.useButtonTheme(
  MagicStarterButtonTheme(
    shapeClassName: 'rounded-full',
    smClassName: standard,
    mdClassName: standard,
    lgClassName: standard,
    secondaryBorderClassName: '',
  ),
);
```

Three things to know:

- **Use vertical padding around a fixed line height, not `min-h-11`.** A Wind
  button gives its box the minimum height and no alignment (`items-center` is
  ignored for a single child, and `justify-center` would stretch the button to
  fill its parent), so the label sits at the top of a `min-h-11` box. `py-[11px]`
  around `leading-[22px]` is 44 px with the label centred, and still grows with
  the platform text size.
- **Drop the secondary border in a fixed-height design.** A border adds its width
  to the box, so a secondary that keeps it is 2 px taller than the rest.
  `''` removes it; `border-0` would leave a hairline.
  `buttonDangerOutlineClassName` only recolours that border.
- **A `className` on a button wins, so two things never follow the theme.** The
  `className` is appended after it. The auth screens pass the form theme's
  `primaryButtonClassName` to an `lg` button, and the social and step-up
  buttons its `secondaryButtonClassName` and the guest button the auth theme's
  `guestButtonClassName` to a `secondary` `md` one. Those strings, stock and as
  `useWindTheme()` derives them, carry no `rounded-*`, `py-*`, `text-<size>` or
  border token, only the full width, the colours, the label weight of the
  primary and the hover opacity of the secondary ones, so the auth screens
  follow the button theme. The first exception is a host's OWN strings: a
  `useFormTheme()` or `useAuthTheme()` call whose button strings name a shape, a
  padding or a label size keeps it, because the string wins. Leave those out
  (the sub-themes have no `copyWith`, so the call passes all 8 fields of
  `MagicStarterFormTheme`, the ones you leave alone copied from
  `MagicStarter.formTheme`). The second is the dialogs, and the invite button of
  the team settings page: they draw raw `WButton`s on the strings of
  `MagicStarterModalTheme` and do not read the button theme at all.

Below `lg` every `MSButton` sits in a 44 x 44 hit area. A size the theme makes 44
px tall or more is not widened by it, so there is no extra layout and no extra
reach.

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
| `guestButtonClassName` | `text-fg-muted`, `bg-surface-container` (hover); the border is the button theme's |
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
