# Plan: Reusable Modal System

**TL;DR**: Make the modal/dialog system customizable for consumer apps — add `MagicStarterModalTheme` (className tokens), `_MagicStarterDialogShell` (internal composition widget with sticky header/footer), `MagicStarterConfirmDialog` (generic Wind UI-native confirm), integrate theme into existing modals, and extend ViewRegistry with modal override support.

**Intent**: Build
**Complexity**: Complex
**Test Strategy**: TDD — failing test first for every unit, red-green-refactor
**Codebase State**: Disciplined — consistent patterns, strong test coverage, strict typing

### Design Decisions
- **Scroll**: Hybrid — new ConfirmDialog uses sticky header/footer via dialog shell, existing modals (PasswordConfirm, TwoFactor) keep current full-scroll behavior unchanged
- **Shell**: Internal `_MagicStarterDialogShell` composition widget — NOT exported, plugin-internal only. Handles Dialog shell, ConstrainedBox, theme token reads, sticky header/scrollable body/sticky footer layout
- **Variant**: Enum + Theme hybrid — `ConfirmDialogVariant` enum (primary/danger/warning) with theme-overridable className defaults
- **Registry**: Same ViewRegistry, new `_modals` Map with `registerModal()`/`makeModal()`/`hasModal()`
- **API compat**: Existing `show()` signatures unchanged — theme read internally from manager at build time
- **makeModal()**: Throws `StateError` for unregistered keys (consistent with `make()`/`makeLayout()`)

---

## Steps

### Step 1: MagicStarterModalTheme — const config class [TDD: test first]

**1a — RED: Write failing tests for MagicStarterModalTheme**

Files:
- `test/facades/magic_starter_facade_test.dart` (add `group('modal theme', ...)`)

Done when:
- `flutter test test/facades/magic_starter_facade_test.dart` fails with "no modalTheme getter" or similar
- Tests cover: default values, custom values preserved, `useModalTheme()` stores on manager, `manager.reset()` restores defaults

QA: `flutter test test/facades/magic_starter_facade_test.dart 2>&1 | grep -c 'FAILED'` returns ≥4
Independence: independent
Tier: mid

**1b — GREEN: Implement MagicStarterModalTheme + facade + manager**

Files:
- `lib/src/magic_starter_manager.dart` — add `MagicStarterModalTheme` class (after `MagicStarterNavigationTheme`), add `modalTheme` field to manager, update `reset()`
- `lib/src/facades/magic_starter.dart` — add `useModalTheme()` static method + `modalTheme` getter
- `lib/magic_starter.dart` — barrel export (already exports manager.dart, theme class is in same file)

MagicStarterModalTheme fields (all with sensible Wind UI defaults):
```
containerClassName    — 'bg-white dark:bg-gray-800 rounded-2xl'
headerClassName       — 'px-6 pt-6 pb-4'
bodyClassName         — 'px-6 pb-4'
footerClassName       — 'px-6 py-4 bg-gray-50 dark:bg-gray-800/50'
titleClassName        — 'text-xl font-semibold text-gray-900 dark:text-white mb-2'
descriptionClassName  — 'text-sm text-gray-600 dark:text-gray-400'
primaryButtonClassName   — 'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium'
secondaryButtonClassName — 'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium'
dangerButtonClassName    — 'px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-medium'
warningButtonClassName   — 'px-4 py-2 rounded-lg bg-amber-500 hover:bg-amber-600 text-white text-sm font-medium'
errorClassName           — 'text-sm text-red-600 dark:text-red-400'
inputClassName           — 'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary'
maxWidth                 — 448.0 (double, not className)
```

Pattern: mirror `MagicStarterNavigationTheme` exactly — const constructor, all fields optional with defaults.

Done when:
- `flutter test test/facades/magic_starter_facade_test.dart` passes (all modal theme tests green)
- `dart analyze --no-fatal-infos` clean

QA: `flutter test test/facades/magic_starter_facade_test.dart` exits 0
Independence: independent
Tier: mid

---

### Step 2: _MagicStarterDialogShell — internal composition widget [TDD: test first]

**2a — RED: Write failing tests for DialogShell**

Files:
- `test/ui/widgets/magic_starter_dialog_shell_test.dart` (new file)

Test cases:
- Renders title and description in header section
- Renders body content in scrollable area
- Renders footer content (sticky, does not scroll)
- Footer omitted when null
- Reads theme tokens from `MagicStarter.manager.modalTheme` (container, header, title, description classNames)
- Body scrolls independently when content overflows (sticky header/footer)

Done when:
- `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` fails (class doesn't exist)

QA: `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart 2>&1 | grep -c 'Error'` returns ≥1
Independence: independent
Tier: mid

**2b — GREEN: Implement _MagicStarterDialogShell**

Files:
- `lib/src/ui/widgets/magic_starter_dialog_shell.dart` (new file — NOT exported from barrel)

Widget structure:
- Private class: `class MagicStarterDialogShell extends StatelessWidget` (file-private, not exported)
- Parameters: `String? title`, `String? description`, `Widget body`, `Widget? footer`
- `build()` reads `MagicStarter.manager.modalTheme` for all chrome classNames
- Layout structure (sticky header/footer, scrollable body):
  ```
  Dialog(backgroundColor: transparent, insetPadding: horizontal 16)
  └── ConstrainedBox(maxWidth: theme.maxWidth, maxHeight: screenHeight * 0.85)
      └── WDiv(className: theme.containerClassName + ' flex flex-col w-full overflow-hidden')
          ├── WDiv(header — theme.headerClassName) [FIXED]
          │   ├── WText(title — theme.titleClassName)
          │   └── WText(description — theme.descriptionClassName)
          ├── Flexible [takes remaining space]
          │   └── SingleChildScrollView
          │       └── WDiv(body — theme.bodyClassName)
          │           └── body widget
          └── if (footer != null) WDiv(footer — theme.footerClassName) [FIXED]
  ```
- CRITICAL: This file is NOT added to barrel exports — internal plugin use only

Done when:
- `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` passes
- `dart analyze --no-fatal-infos` clean
- `grep -c 'dialog_shell' lib/magic_starter.dart` returns 0 (not exported)

QA: `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` exits 0
Independence: depends on Step 1b (needs MagicStarterModalTheme)
Tier: mid

---

### Step 3: MagicStarterConfirmDialog — generic confirm widget [TDD: test first]

**3a — RED: Write failing tests for ConfirmDialog**

Files:
- `test/ui/widgets/magic_starter_confirm_dialog_test.dart` (new file)

Test cases:
- Renders title, description, confirm/cancel buttons
- Returns false on cancel
- Returns true on confirm
- `ConfirmDialogVariant.danger` renders danger button className
- `ConfirmDialogVariant.warning` renders warning button className
- Default variant is `primary`
- Static `show()` method works (via Builder + showDialog pattern from existing tests)
- Reads theme from `MagicStarter.manager.modalTheme` — custom theme className appears in widget tree
- Sticky footer: buttons always visible even with long description content

Done when:
- `flutter test test/ui/widgets/magic_starter_confirm_dialog_test.dart` fails (class doesn't exist)

QA: `flutter test test/ui/widgets/magic_starter_confirm_dialog_test.dart 2>&1 | grep -c 'Error'` returns ≥1
Independence: independent
Tier: mid

**3b — GREEN: Implement ConfirmDialog + ConfirmDialogVariant enum**

Files:
- `lib/src/ui/widgets/magic_starter_confirm_dialog.dart` (new file)
- `lib/magic_starter.dart` — add barrel export for `MagicStarterConfirmDialog` and `ConfirmDialogVariant`

ConfirmDialogVariant enum: `primary`, `danger`, `warning`

Widget structure:
- `extends StatefulWidget` (NOT MagicStatefulView)
- Static `show(BuildContext context, {required String title, String? description, String? confirmLabel, String? cancelLabel, ConfirmDialogVariant variant, Future<void> Function()? onConfirm})` → returns `Future<bool>`
- Uses `MagicStarterDialogShell` internally for layout (sticky header/footer)
- Passes title/description to shell, builds body as empty or minimal content, builds footer with cancel + confirm buttons
- Button className resolved by variant: primary → `theme.primaryButtonClassName`, danger → `theme.dangerButtonClassName`, warning → `theme.warningButtonClassName` — inline switch expression
- `_isLoading` state for double-click protection
- `mounted` check after async onConfirm

Done when:
- `flutter test test/ui/widgets/magic_starter_confirm_dialog_test.dart` passes
- `dart analyze --no-fatal-infos` clean

QA: `flutter test test/ui/widgets/magic_starter_confirm_dialog_test.dart` exits 0
Independence: depends on Step 2b (needs DialogShell)
Tier: mid

---

### Step 4: Theme integration into existing modals [TDD: test first]

**4a — RED: Write failing tests for theme consumption**

Files:
- `test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` (add tests)
- `test/ui/widgets/magic_starter_two_factor_modal_test.dart` (add tests)

New test cases per file:
- Register custom `MagicStarterModalTheme` with distinctive className (e.g., `'bg-custom-test'`)
- Pump widget, verify custom className appears in rendered tree via `find.byWidgetPredicate` or className assertion
- Verify default theme className when no custom theme registered

Done when:
- New tests fail because modals still use hardcoded classNames

QA: `flutter test test/ui/widgets/ 2>&1 | grep -c 'FAILED'` returns ≥2
Independence: depends on Step 1b
Tier: mid

**4b — GREEN: Refactor existing modals to read from theme**

Files:
- `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart` — replace hardcoded classNames with `MagicStarter.manager.modalTheme.*` reads in `build()`
- `lib/src/ui/widgets/magic_starter_two_factor_modal.dart` — same refactor

Refactor pattern (for each modal):
1. At top of `build()`: `final theme = MagicStarter.manager.modalTheme;`
2. Replace hardcoded container className → `theme.containerClassName`
3. Replace hardcoded header className → `theme.headerClassName`
4. Replace hardcoded body className → `theme.bodyClassName`
5. Replace hardcoded footer className → `theme.footerClassName`
6. Replace hardcoded title className → `theme.titleClassName`
7. Replace hardcoded description className → `theme.descriptionClassName`
8. Replace hardcoded primary button className → `theme.primaryButtonClassName`
9. Replace hardcoded secondary/cancel button className → `theme.secondaryButtonClassName`
10. Replace hardcoded error className → `theme.errorClassName`
11. Replace hardcoded input className → `theme.inputClassName`

CRITICAL: show() signature does NOT change. Theme is read inside build() only.

Done when:
- `flutter test test/ui/widgets/` all pass (existing + new theme tests)
- `dart analyze --no-fatal-infos` clean
- No hardcoded bg-white/bg-gray-800/rounded-2xl in modal widget files (replaced by theme tokens)

QA: `flutter test test/ui/widgets/` exits 0 AND `grep -c 'bg-white dark:bg-gray-800' lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart` returns 0
Independence: depends on Step 1b
Tier: mid (2-file mechanical refactor with explicit 11-step pattern)

---

### Step 5: Modal View Registry [TDD: test first]

**5a — RED: Write failing tests for modal registry**

Files:
- `test/ui/magic_starter_view_registry_test.dart` (add `group('modal registry', ...)` — create file if missing)

Test cases:
- `registerModal()` stores a builder
- `hasModal()` returns true for registered key
- `hasModal()` returns false for unregistered key
- `makeModal()` returns widget from registered builder
- `makeModal()` throws StateError for unregistered key
- `clear()` clears modal builders too

Done when:
- Tests fail (registerModal/makeModal don't exist on ViewRegistry)

QA: `flutter test test/ui/magic_starter_view_registry_test.dart 2>&1 | grep -c 'Error'` returns ≥1
Independence: independent
Tier: mid

**5b — GREEN: Extend ViewRegistry with modal support**

Files:
- `lib/src/ui/magic_starter_view_registry.dart` — add `_modals` Map, `MagicStarterModalBuilder` typedef, `registerModal()`, `hasModal()`, `makeModal()`, update `clear()`

`MagicStarterModalBuilder` typedef: `Widget Function()` (same as `MagicStarterViewBuilder`)

`makeModal()`: throws `StateError` when key not registered (consistent with `make()` and `makeLayout()`)

Done when:
- `flutter test test/ui/magic_starter_view_registry_test.dart` passes
- `dart analyze --no-fatal-infos` clean

QA: `flutter test test/ui/magic_starter_view_registry_test.dart` exits 0
Independence: independent
Tier: mid

**5c — Register default modals in manager + tests**

Files:
- `lib/src/magic_starter_manager.dart` — add `_registerDefaultModal()` helper (with "register if absent" guard, same as `_registerDefault()`), register defaults in `registerDefaultViews()`: `modal.confirm`, `modal.password_confirm`, `modal.two_factor`
- `test/facades/magic_starter_facade_test.dart` — add test group verifying: default modal keys registered after manager init, consumer can override modal key before init, `manager.reset()` clears and re-registers default modals

NOTE on modal registry purpose: Registry entries store the **widget body** (not the `show()` factory). This enables consumers to override the visual content of a modal while the plugin controls the showDialog invocation. Example: consumer registers `modal.confirm` → plugin's `ConfirmDialog.show()` can optionally resolve from registry instead of hardcoded widget. This is a render-override pattern, not an invocation-override.

Done when:
- `flutter test test/facades/` passes
- Tests explicitly assert `MagicStarter.view.hasModal('modal.confirm')` returns true

QA: `flutter test test/facades/` exits 0
Independence: depends on Step 5b + Step 3b (needs ConfirmDialog for default registration)
Tier: mid

---

### Step 6: Replace Material AlertDialog in team settings [TDD: test if needed]

**6a — Verify or write test for confirmation flow**

Files:
- `test/ui/views/teams/` — check if team settings view tests exist. If not, write a focused test verifying the confirmation dialog call pattern (at minimum: mock controller, tap remove button, verify dialog shown)

Done when:
- Test exists that exercises the confirmation flow
- Test currently passes with Material AlertDialog (green baseline before refactor)

QA: `flutter test test/ui/views/teams/` exits 0 OR test file created and passes
Independence: depends on Step 3b
Tier: mid

**6b — Replace AlertDialog with ConfirmDialog**

Files:
- `lib/src/ui/views/teams/magic_starter_team_settings_view.dart` — replace 2x `showDialog<bool>` + `AlertDialog` + `TextButton` with `MagicStarterConfirmDialog.show()`

Two call sites:
1. Member removal (~line 323): `ConfirmDialogVariant.danger`
2. Invitation cancellation (~line 410): `ConfirmDialogVariant.danger`

Done when:
- `grep -c 'AlertDialog' lib/src/ui/views/teams/magic_starter_team_settings_view.dart` returns 0
- `grep -c 'TextButton' lib/src/ui/views/teams/magic_starter_team_settings_view.dart` returns 0
- `flutter test test/ui/views/teams/` passes
- `dart analyze --no-fatal-infos` clean

QA: `grep -c 'AlertDialog' lib/src/ui/views/teams/magic_starter_team_settings_view.dart` returns 0
Independence: depends on Step 6a
Tier: quick

---

### Step 7: Documentation sync

Files:
- `CHANGELOG.md` — add entries under `[Unreleased]`: MagicStarterModalTheme, MagicStarterConfirmDialog, ConfirmDialogVariant, modal registry, theme integration, dialog shell
- `README.md` — add ONE code example under existing customization section showing `useModalTheme()` usage (do NOT create a dedicated Modal System section)
- `doc/architecture/manager.md` — add MagicStarterModalTheme field docs (mirror NavigationTheme section format)
- `doc/architecture/view-registry.md` — add modal registry section (registerModal/makeModal/hasModal)
- `.claude/rules/widgets.md` — add: ConfirmDialog rules, ConfirmDialogVariant usage, modal theme consumption pattern, DialogShell internal-only note

Done when:
- All changed features documented
- `grep -c 'ModalTheme' CHANGELOG.md` returns ≥1
- `grep -c 'ConfirmDialog' CHANGELOG.md` returns ≥1

QA: `grep 'ModalTheme' CHANGELOG.md README.md doc/architecture/manager.md` returns matches in all 3 files
Independence: depends on all previous steps
Tier: mid

---

### Step 8: Final verification

Run full test suite + analysis:
- `flutter test --coverage`
- `dart analyze --no-fatal-infos`
- `dart format --set-exit-if-changed .`

Done when: all 3 commands exit 0
Independence: depends on all previous steps
Tier: quick

---

## Waves

### Wave 1 (Start Immediately — all independent, parallel):
- Step 1a [mid]: RED — modal theme tests
- Step 2a [mid]: RED — dialog shell tests
- Step 3a [mid]: RED — confirm dialog tests
- Step 5a [mid]: RED — modal registry tests

### Wave 2 (After Wave 1):
- Step 1b [mid]: GREEN — implement MagicStarterModalTheme + facade + manager
- Step 5b [mid]: GREEN — extend ViewRegistry with modal support

### Wave 3 (After Wave 2):
- Step 2b [mid]: GREEN — implement MagicStarterDialogShell (needs theme from 1b)
- Step 4a [mid]: RED — theme consumption tests for existing modals

### Wave 4 (After Wave 3):
- Step 3b [mid]: GREEN — implement ConfirmDialog using DialogShell (needs 2b)
- Step 4b [mid]: GREEN — refactor existing modals to read theme

### Wave 5 (After Wave 4):
- Step 5c [mid]: Register default modals in manager (needs 5b + 3b — both complete by now)
- Step 6a [mid]: Verify/write team settings confirmation test
- Step 6b [quick]: Replace Material AlertDialog in team settings (after 6a)

### Wave 6 (After Wave 5):
- Step 7 [mid]: Documentation sync

### Wave 7 (After Wave 6):
- Step 8 [quick]: Final verification

---

## Must NOT Have

- Do NOT refactor `_builders` and `_layouts` into a unified generic map — only add `_modals` as independent map
- Do NOT extract a shared abstract base class for dialogs — use `_MagicStarterDialogShell` composition instead. Existing modals (PasswordConfirm, TwoFactor) keep their current scroll behavior unchanged
- Do NOT export `_MagicStarterDialogShell` from the barrel — it is internal plugin infrastructure only
- Do NOT add null-guard checks on `ConfirmDialogVariant` — it is a non-nullable enum
- Do NOT add `///` doc comments to private dialog helper methods
- Do NOT make `MagicStarterConfirmDialog` const-constructible — show() factory pattern is incompatible
- Do NOT change show() signatures on existing modals — theme is resolved at build time only
- Do NOT add CLI doctor updates for modal theme
- Do NOT add feature flags for modals — they are always available (not opt-in)
- Do NOT add a `theme` parameter to existing show() methods
- Do NOT add a dedicated "Modal System" section to README.md — one code example under existing customization section is sufficient
- Do NOT restructure existing modal widget trees during theme integration — only swap className strings, keep structure identical
- Do NOT change `MagicStarterDialogShell` to a public/exported class — it stays file-internal

---

## Risks

- **Existing modal widget tests may break** during Step 4b if className assertions are exact-match. Mitigation: update assertions to match new theme-driven defaults (which are identical strings to current hardcoded values).
- **Symbol existence unverified for Wind UI widgets** — some className tokens (e.g., focus:border-primary) depend on Wind CSS engine. Mitigation: run widget tests to verify rendering.

---

## Research Summary

**Key Files:**
- `lib/src/magic_starter_manager.dart` — Manager singleton, NavigationTheme class (reference pattern), reset(), registerDefaultViews()
- `lib/src/facades/magic_starter.dart` — Facade with use*() methods, all static, delegates to manager
- `lib/src/ui/magic_starter_view_registry.dart` — ViewRegistry with _builders/_layouts, make()/makeLayout(), clear()
- `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart` — Hardcoded className modal, static show() factory
- `lib/src/ui/widgets/magic_starter_two_factor_modal.dart` — Multi-step hardcoded className modal
- `lib/src/ui/views/teams/magic_starter_team_settings_view.dart:323,410` — Material AlertDialog usage (to replace)
- `test/facades/magic_starter_facade_test.dart` — NavigationTheme test pattern (reference for modal theme tests)
- `test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` — Widget test pattern with wrap() helper

**Patterns Found:**
- NavigationTheme: const class, className defaults, registered via use*() on facade → stored on manager
- CardVariant: enum with 3 variants (surface/inset/elevated), visual style driven
- ViewRegistry: string-keyed factory, "register if absent" pattern, throws StateError on missing key
- Static show() factory: all dialogs use this, returns Future<bool>, wraps showDialog()
- Material Dialog shell + Wind UI content: standard for all modals (Wind UI has no dialog component)

**Dependencies:** `magic` (Wind UI), `flutter/material.dart` (Dialog shell only)

**Codebase State**: Disciplined — consistent patterns across all existing customization systems

## Conventions

- TDD: red-green-refactor, no production code without failing test
- Trailing commas on ALL multi-line args
- Dark mode: always pair light/dark classes
- Doc comments (`///`) on public APIs only
- Section dividers: 73-char ASCII dashes
- Import order: dart:*, package:flutter/*, package:magic/*, relative
- File naming: snake_case, prefixed with `magic_starter_`
- Class naming: PascalCase with `MagicStarter` prefix
- Private constructor for static utility classes: `ClassName._()`
- const constructor for immutable config classes
- setUp: `MagicApp.reset()`, `Magic.flush()`, bind mocks
