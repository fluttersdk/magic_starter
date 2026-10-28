---
paths:
  - "lib/src/ui/widgets/**/*.dart"
---

# Starter Widgets

The widgets under `lib/src/ui/widgets/` that carry starter BEHAVIOUR rather than a visual contract: an API call, a multi-step wizard, a layout signal. A component whose only job is styling belongs in `lib/src/ui/components/` instead (see `components.md`), and that is where the whole `MS`-prefixed design system lives.

Two files here are thin aliases kept for existing callers: `MagicStarterConfirmDialog extends MSConfirmDialog` and `MagicStarterDialogShell extends MSDialog`. They add nothing. New code writes the `MS` name; changes to their behaviour belong in the component, not here.

## Shape

- Class hierarchy: `extends StatefulWidget` or `extends StatelessWidget`, NEVER `MagicStatefulView`.
- Dialog factory: `static Future<T?> show(BuildContext context, ...)` wrapping `showDialog()` or `showModalBottomSheet()`.
- Wind UI exclusively. No Material widgets, except `Icons.*` for icon data and the Material `Dialog` shell reached through `MSDialog`.
- Dark mode: every colour token needs its `dark:` pair in the same className.
- Never hardcode a dialog className. All modals read `MagicStarter.manager.modalTheme` at build time (`titleClassName`, `primaryButtonClassName`, `dangerButtonClassName`, ...).
- `Icons.*` in a `build()` goes to a `static const _iconName = Icons.xxx` field, or Flutter web cannot tree-shake it.

## The widgets themselves

- **`MagicStarterTwoFactorModal`**: multi-step wizard, enable then QR code then OTP confirm then recovery codes. Each step owns its own local state; the modal never auto-advances on an error.
- **`MagicStarterPasswordConfirmDialog`**: inline error handling through `setState()`, and it NEVER auto-closes on error. Supports `ConfirmDialogVariant` (`primary` default, `danger`, `warning`) through the same `_resolveConfirmClassName()` pattern as `MSConfirmDialog`; pass `variant:` to both the constructor and `show()`.
- **`MagicStarterTimezoneSelect`**: debounced async search through `Http.get('/timezones')`. Never a local timezone list.
- **`MagicStarterAuthFormCard`**: `WDiv` + `WText` title + child, reused across login, register, forgot and reset.
- **`MagicStarterHideBottomNav`**: wraps a PAGE (not a route group) and registers its `ModalRoute` with the nearest `MagicStarterBottomNavScope`, so the phone's bottom nav collapses in step with that page's transition. A layout puts `MagicStarterBottomNavScope` at its own root (never around the layout: magic tells shells apart by the layout's runtime type) and its nav in `MagicStarterBottomNavSlot`; `MagicStarterBottomNavScope.visibilityOf(context)` reads the fraction showing. There is no `of()`.
- **`MagicStarterNavBadge`**: the count on a `MagicStarterNavItem`, bound to its `badgeCount` `ValueListenable<int?>` through a `ValueListenableBuilder`, so the shell is not rebuilt when the number moves. Draws nothing for `null` or a count not above zero, a neutral `MSBadge` reading `99+` above `maxShown` (99) otherwise. A `Semantics` with `excludeSemantics: true` carries the `transChoice(labelKey, count)` sentence in place of the drawn number, so a screen reader hears the real count once and the pill's text is not read twice. It owns no position: the layout decides where it sits.
- **`MagicStarterHideChrome`**: an `InheritedWidget` for an immersive route group. It needs its own `layoutId`, and a separate id is a separate shell, so entering it rebuilds the layout and its state. Every other authenticated group uses `MagicStarterLayoutIds.app`.

## Dialog layout rules

These hold for every dialog reached from here, alias or not:

- Footers use compact right-aligned buttons with `justify-end gap-2 wrap`, never `flex-1` full-width. `wrap` is required alongside `justify-end`: Wind renders it as `Wrap(alignment: WrapAlignment.end)` and a constrained container overflows without it.
- `safeHeight` comes from `MediaQuery.viewPaddingOf(context)`: subtract the top and bottom insets from screen height, then apply `* 0.85` for `maxHeight`. Vertical `insetPadding: 24` keeps a phone off the edges.
