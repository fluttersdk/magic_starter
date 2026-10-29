# Wind theme adoption (`MagicStarter.useWindTheme`)

`MagicStarter.useWindTheme(WindThemeData)` aligns every built-in magic_starter
surface to a Wind semantic palette in a single call. Instead of constructing up
to ten sub-theme structs by hand, you pass the same `WindThemeData` your app
already installs at its root and the starter kit derives the eight colour-bearing
sub-themes (navigation, modal, form, card, page header, layout, auth, dropdown)
from its semantic alias roles. The ninth and tenth, the button theme and the
field theme, are shape and size only and are set by hand; see
[Button](#button) and [Field](#field).

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
| `text-on-success` / `text-on-warning` | Text and icons on `bg-success` / `bg-warning` (when undefined, `MSToast` picks white or near-black by measured contrast against the fill) |

A host that defines `text-destructive` (as an alias, or through a `destructive` colour) re-skins the outlined danger buttons, the destructive `MSSettingsRow` title and the inline error text; without it they fall back to the red pair. `MagicStarterTokens.role(theme, token)` is the lookup they share.

`MSToast` is the one place that reads `text-on-success` and `text-on-warning`: its success and warning variants paint the message, the action label and the focus ring in them (the error variant reads `text-on-destructive`). The alias contract ships the fills and not these two roles, so a host that defines its own `bg-success` and `bg-warning` defines them beside the fills, and a host whose dark fills are light (a pale green on a dark surface) writes dark text for the dark half. A role the host does not define is not assumed to suit the stock fills: the toast resolves the fill it paints in the current mode and takes the better of white and near-black by WCAG contrast, so the stock green and amber get near-black and a mid-dark green gets white. A role the host defines is used as written, poor contrast included.

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
  padding or a label size keeps it, because the string wins. Leave those out,
  and change one string through `copyWith` rather than a new
  `MagicStarterFormTheme`, which would hand the other seven fields back to their
  defaults:
  `MagicStarter.useFormTheme(MagicStarter.formTheme.copyWith(primaryButtonClassName: ...))`.
  The second is the dialogs, and the invite button of
  the team settings page: they draw raw `WButton`s on the strings of
  `MagicStarterModalTheme` and do not read the button theme at all.

Below `lg` every `MSButton` sits in a 44 x 44 hit area. A size the theme makes 44
px tall or more is not widened by it, so there is no extra layout and no extra
reach.

### Field

Nothing is derived either. The recipes of `MSInput`, `MSSelect`, `MSCombobox`
and `MSSegmentedControl` write their colours, borders and radius as semantic
aliases, and `MagicStarterFieldTheme` carries only the height and the type: one
string per control, each the run of padding, minimum height and text size the
recipe used to spell out. `useWindTheme()` and `useTheme()` reset it to its
defaults, so set it after them.

| Property | Control | Default |
|----------|---------|---------|
| `inputSizeClassName` | `MSInput`: text, placeholder and typed value | `py-3 lg:py-2.5 text-sm leading-5` (44 px, 40 px from `lg`) |
| `selectSizeClassName` | trigger of `MSSelect`, `MSCombobox` and the timezone select | `py-[9px] min-h-11 lg:min-h-0` (44 px, 40 px from `lg`) |
| `segmentedSmClassName` | `MSSegmentedControl` `sm` pill | `px-2 py-1 text-sm` (28 px) |
| `segmentedMdClassName` | `MSSegmentedControl` `md` pill | `px-3 py-1.5 text-sm` (32 px) |
| `segmentedPaddingClassName` | `MSSegmentedControl` root | `p-1` |

One 44 px standard with 17 on 22 type for every control:

```dart
MagicStarter.useFieldTheme(
  MagicStarterFieldTheme(
    inputSizeClassName: 'py-[11px] text-[17px] leading-[22px]',
    selectSizeClassName: 'py-2.5 text-[17px] leading-[22px]',
    segmentedSmClassName: 'py-[7px] text-[17px] leading-[22px]',
    segmentedMdClassName: 'py-[7px] text-[17px] leading-[22px]',
    segmentedPaddingClassName: 'px-1 py-0 lg:py-1',
  ),
);
```

Four things to know:

- **The string replaces the run, so state all of it.** The default input string
  is `py-3 lg:py-2.5 text-sm leading-5`; a host string that names `py-[11px]` only
  would leave `text-sm` and `leading-5` out of the box, not inherit them. The
  side padding (`px-3`), the colours and the border stay in the recipe.
- **Each control needs its own padding for 44 px.** A text input paints its
  border inside its padding, so it adds no height: `py-[11px]` around
  `leading-[22px]` is 44, and `py-2.5` is 42. A select or combobox trigger is a
  Wind box whose border adds to its size, so `py-2.5` around the same line plus
  the two border pixels is 44. Reach both with vertical padding around a fixed
  `leading-*`, which also centres the text, rather than with `min-h-11` alone.
- **The placeholder follows the input.** It inherits the field's text size and
  line height, so `inputSizeClassName` sets the placeholder and the typed value
  together and there is no placeholder field.
- **The segmented root needs `segmentedPaddingClassName` for 44 px at every
  width.** Below `lg` each segment sits in a 44 px hit cell, so a control with
  the default `p-1` root is 52 px tall on a phone whatever the pill size. A 36 px
  pill (`py-[7px]` around the line) in a root of `px-1 py-0 lg:py-1` is 44 px
  everywhere: the hit cell supplies the 4 px above and below the pill on a phone,
  and the root does from `lg` up.

A `className` (or the `classNames` of a slot) handed to a control is appended
after the theme and wins on any family it names. `MSTextarea` and the option
rows of the select and combobox menus are outside the field theme.

The auth, profile and settings forms are outside it too. They draw `WFormInput`s
on `MagicStarterFormTheme.inputClassName`, whose default carries `py-3`, and the
starter's own `WFormSelect`s read the same string for their trigger: the role
select of the team settings page (`magic_starter_team_settings_view.dart`), the
language select of the profile settings view
(`magic_starter_profile_settings_view.dart`) and the language preference view
(`magic_starter_language_view.dart`). A host sets that one string with
`MagicStarter.useFormTheme(MagicStarter.formTheme.copyWith(inputClassName: ...))`,
and one string has to serve an input and a select, which reach 44 px differently:
an input paints its border inside its padding and a select trigger adds it. With
17 on 22 type:

| `inputClassName` size run | `WFormInput` | `WFormSelect` |
|---------------------------|--------------|---------------|
| `py-[11px] text-[17px] leading-[22px]` | 44 | 46 |
| `py-2.5 text-[17px] leading-[22px]` | 42 | 44 |
| `py-[10px] min-h-11 text-[17px] leading-[22px]` | 44 | 44 |

The third is the one string that gives both 44 px: the select is 10 + 22 + 10 + 2
and the minimum height lifts the input from 42 to 44, where it centres its single
line (the line box measures dead centre in the test font; a real font's glyphs can
sit a pixel off the middle of a taller box). The heights are line boxes measured
in a widget test (`test/configuration/magic_starter_form_theme_input_test.dart`),
which pins all three rows of the table, and the 22 px line centred in the 44 px
box at 390 and 1440 in light and dark. A bare `min-h-11` does pin the label of a
`WButton` to the top of its box, which is why buttons reach 44 px with padding
around a fixed line height; a `WInput` and a `WFormSelect` trigger centre their
one line, so for them the minimum height is safe. The two agree at the default
text size only: once a larger text setting lifts the line past the minimum
height, the select trigger is 2 px taller than the input, because its border adds
to the padding where the input's sits inside it.

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
