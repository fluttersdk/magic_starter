---
paths:
  - "lib/src/ui/components/bottom_sheet/**/*.dart"
  - "lib/src/ui/components/dialog/**/*.dart"
  - "lib/src/ui/widgets/magic_starter_*dialog*.dart"
  - "lib/src/ui/widgets/magic_starter_two_factor_modal.dart"
---

# Modal presentation: dialog, sheet, adaptive

`MagicStarterModalTheme.presentation` is read in one place, `ModalPresenter`, when a modal opens.

- **Openers** call `ModalPresenter.show` (never `showDialog`) and render on `MSDialog`, so every presentation reaches them. `ModalPresenter.presentsDialog(context)` is the single answer: `dialog` always, `sheet` never, `adaptive` from `dialogBreakpoint` (a Wind breakpoint name, default `'lg'`) up, through `MagicStarterBreakpoints.isAtLeast`, which throws a `StateError` naming `MagicStarterModalTheme.dialogBreakpoint` for a name the Wind theme lacks.
- **`MSBottomSheet.show(dialogBreakpoint:)`**: under `dialog` a screen at least that wide gets an `MSDialog` through `ModalPresenter.show` with the same arguments (`scrollable` included). Null keeps the sheet. `sheet` and `adaptive` ignore the argument: the theme has chosen for the whole app.
- **Dismiss guard** (`canDismiss`, `onDismissBlocked`) goes through `ModalPresenter`, never a caller's `PopScope`: a sheet's drag pops unconditionally, so only `GuardedSheetRoute.enableDrag` stops it. `onDismissBlocked` gets the modal's context: a confirmed discard pops with it, not the opener's (root navigator).
- **`MSDialog`**: fixed footer; header and body share one scroll view, header pinned while it takes at most half of it, Material `Dialog` shell around Wind content. `footerBuilder` gets the dialog's own context. In a `ModalBottomSheetRoute` it draws `MSBottomSheetPanel`.
- **`MSBottomSheet` in a `RawDialogRoute`** (a magic overlay route under `adaptive`, which builds its page's `MSBottomSheet` itself) draws `MSDialog`: the mirror of the rule above. With no title and no description the body takes `modalTheme.headlessBodyClassName` (`pt-6`), the space the sheet's drag handle held; a plain `MSDialog` is unchanged.
- **Overlay routes** follow the theme only under `adaptive`: the provider's `boot()` installs `ModalPresenter.overlayPresentation` on magic's router (`MagicRoute.useOverlayPresentation`); under `dialog` and `sheet` a route stays the sheet it has always been.
- **Footers**: compact right-aligned buttons with `justify-end gap-2 wrap`, never `flex-1`. Safe area: `safeHeight` from `MediaQuery.viewPaddingOf(context)` minus the top and bottom insets, then `* 0.85` for `maxHeight`; vertical `insetPadding: 24`.
