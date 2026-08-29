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
- **`MagicStarterHideBottomNav`**: an `InheritedWidget` that signals `MagicStarterAppLayout` to suppress the mobile bottom nav for a fullscreen route. Wrap the route group, do not poke the layout.

## Dialog layout rules

These hold for every dialog reached from here, alias or not:

- Footers use compact right-aligned buttons with `justify-end gap-2 wrap`, never `flex-1` full-width. `wrap` is required alongside `justify-end`: Wind renders it as `Wrap(alignment: WrapAlignment.end)` and a constrained container overflows without it.
- `safeHeight` comes from `MediaQuery.viewPaddingOf(context)`: subtract the top and bottom insets from screen height, then apply `* 0.85` for `maxHeight`. Vertical `insetPadding: 24` keeps a phone off the edges.
