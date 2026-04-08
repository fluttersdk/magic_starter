# Plan: Dialog Shell Fixes (Issue #7)

**TL;DR**: Export `MagicStarterDialogShell` publicly, fix confirm dialog button layout to compact/right-aligned, add `footerBuilder` for dialog context exposure, and fix body spacing gap caused by `Flexible` + `SingleChildScrollView`.

**Intent**: Mid-sized
**Complexity**: Standard
**Test Strategy**: TDD — red-green-refactor per step
**Tier Summary**: 5 mid, 0 quick

## Research Summary

**Key Files**:
- `lib/src/ui/widgets/magic_starter_dialog_shell.dart` — Internal shell widget, `footer: Widget?`, `Flexible` + `SingleChildScrollView` body
- `lib/src/ui/widgets/magic_starter_confirm_dialog.dart:130-152` — Footer with `flex-1` wrappers, uses DialogShell
- `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart:172-198` — Same `flex-1` pattern, builds own Dialog (NOT using DialogShell)
- `lib/src/ui/widgets/magic_starter_two_factor_modal.dart:165-182` — Already uses `justify-end`, no button layout issue
- `lib/magic_starter.dart` — Barrel exports, DialogShell NOT exported
- `lib/src/magic_starter_manager.dart:164-210` — `MagicStarterModalTheme` with `footerClassName`
- `test/ui/widgets/magic_starter_dialog_shell_test.dart` — 7 existing tests
- `test/ui/widgets/magic_starter_confirm_dialog_test.dart` — 10 existing tests
- `test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` — Existing tests

**Patterns Found**:
- DialogShell is only consumed by ConfirmDialog internally
- PasswordConfirmDialog and TwoFactorModal build their own `Dialog` shells directly (don't use DialogShell)
- TwoFactorModal already uses `justify-end` for buttons — no fix needed there
- Test pattern: `WindTheme` > `MaterialApp` > `Scaffold` > widget, with `tester.view.physicalSize` setup

**Dependencies**: magic (Wind UI), flutter/material (Dialog shell only)

**Codebase State**: Disciplined — consistent patterns, good test coverage, follow existing patterns exactly

### Conventions
- Wind UI exclusively — no Material except `Dialog` shell and `Icons.*`
- Dark mode pairs: always `light dark:dark` classes
- Trailing commas on ALL multi-line arguments
- TDD red-green-refactor, `flutter test` + `dart analyze` after every change
- Section dividers: 73-char ASCII dashes
- Doc comments (`///`) on public APIs

## Steps

### Step 1 [mid]: DialogShell — footerBuilder + body shrink-to-content

**What**: Replace `footer: Widget?` with `footerBuilder: Widget Function(BuildContext dialogContext)?`. Replace `Flexible` + `SingleChildScrollView` body with `Flexible` + `ListView(shrinkWrap: true)` to fix content-footer gap.

**Files**:
- `lib/src/ui/widgets/magic_starter_dialog_shell.dart` — Change `footer` parameter to `footerBuilder`, replace body scroll pattern
- `test/ui/widgets/magic_starter_dialog_shell_test.dart` — Add tests for `footerBuilder` receiving context, body shrink behavior; update existing `footer` tests to use `footerBuilder`

**TDD**:
- RED: Write test that `footerBuilder` callback receives a `BuildContext`; write test that body does not expand beyond content height when content is short
- GREEN: Implement parameter change and body pattern change
- REFACTOR: Clean up

**Done when**:
- `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` — all pass
- `grep 'footerBuilder' lib/src/ui/widgets/magic_starter_dialog_shell.dart` returns matches
- `grep 'Widget? footer' lib/src/ui/widgets/magic_starter_dialog_shell.dart` returns NO matches
- `grep 'shrinkWrap: true' lib/src/ui/widgets/magic_starter_dialog_shell.dart` returns match
- `grep 'SingleChildScrollView' lib/src/ui/widgets/magic_starter_dialog_shell.dart` returns NO matches

**QA**: `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` passes; `dart analyze --no-fatal-infos` clean

**Independence**: independent
**Tier**: mid

---

### Step 2 [mid]: ConfirmDialog — compact right-aligned buttons + footerBuilder

**What**: Remove `flex-1` wrappers from footer buttons, add `justify-end` for right-alignment, remove `w-full` from confirm button className. Adapt to pass `footerBuilder` instead of `footer` to DialogShell.

**Files**:
- `lib/src/ui/widgets/magic_starter_confirm_dialog.dart:130-154` — Restructure footer layout, switch from `footer:` to `footerBuilder:`
- `test/ui/widgets/magic_starter_confirm_dialog_test.dart` — Add test verifying no `flex-1` wrapper divs in footer

**TDD**:
- RED: Write test that confirm dialog footer uses right-aligned compact buttons (no flex-1 wrapper)
- GREEN: Remove `WDiv(className: 'flex-1', ...)` wrappers, add `justify-end` to parent row, remove `w-full` from WButton, pass `footerBuilder: (_) =>` instead of `footer:`
- REFACTOR: Clean up

**Done when**:
- `flutter test test/ui/widgets/magic_starter_confirm_dialog_test.dart` — all pass
- `grep 'flex-1' lib/src/ui/widgets/magic_starter_confirm_dialog.dart` returns NO matches
- `grep 'justify-end' lib/src/ui/widgets/magic_starter_confirm_dialog.dart` returns match
- `grep 'footerBuilder' lib/src/ui/widgets/magic_starter_confirm_dialog.dart` returns match
- `grep 'w-full' lib/src/ui/widgets/magic_starter_confirm_dialog.dart` returns NO matches (was on confirm button)

**QA**: `flutter test test/ui/widgets/magic_starter_confirm_dialog_test.dart` passes; `dart analyze --no-fatal-infos` clean

**Independence**: depends on Step 1 (footerBuilder API change)
**Tier**: mid

---

### Step 3 [mid]: PasswordConfirmDialog — compact right-aligned buttons

**What**: Same button layout fix as Step 2. Remove `flex-1` wrappers, add `justify-end`, remove `w-full` from confirm button. PasswordConfirmDialog does NOT use DialogShell, so no footerBuilder change needed.

**Files**:
- `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart:172-198` — Restructure footer button layout
- `test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` — Add test verifying compact button layout

**TDD**:
- RED: Write test verifying no flex-1 wrappers in footer
- GREEN: Remove `WDiv(className: 'flex-1', ...)` wrappers, add `justify-end` to footer row, remove `w-full` from WButton
- REFACTOR: Clean up

**Done when**:
- `flutter test test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` — all pass
- `grep 'flex-1' lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart` returns NO matches
- `grep 'justify-end' lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart` returns match

**QA**: `flutter test test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` passes

**Independence**: independent
**Tier**: quick

---

### Step 4 [mid]: Export DialogShell from barrel

**What**: Add export line to `lib/magic_starter.dart`. Update docblock in `magic_starter_dialog_shell.dart` — remove "Internal" / "NOT exported" language, add proper public API docs.

**Files**:
- `lib/magic_starter.dart` — Add `export 'src/ui/widgets/magic_starter_dialog_shell.dart';`
- `lib/src/ui/widgets/magic_starter_dialog_shell.dart` — Update class docblock to public-facing documentation

**Done when**:
- `grep 'magic_starter_dialog_shell' lib/magic_starter.dart` returns match
- `grep -c 'NOT exported' lib/src/ui/widgets/magic_starter_dialog_shell.dart` returns 0
- `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` passes (no import errors from newly public symbol)
- `dart analyze --no-fatal-infos` clean

**QA**: `flutter test` full suite passes (no import conflicts)

**Independence**: depends on Step 1 (changes should be done before export)
**Tier**: mid

---

### Step 5 [mid]: Documentation updates

**What**: Update all documentation to reflect the 4 changes.

**Files**:
- `CHANGELOG.md` — Add entries under `[Unreleased]`
- `CLAUDE.md` — Update skill description (DialogShell now public), update gotchas if needed
- `.claude/rules/widgets.md` — Remove "internal-only (NOT exported)" note for DialogShell, add footerBuilder pattern, update button layout guidance
- `doc/` — Update relevant architecture/widget docs

**Done when**:
- `grep 'DialogShell' CHANGELOG.md` returns match
- `grep 'footerBuilder' .claude/rules/widgets.md` returns match
- `grep -c 'NOT exported' .claude/rules/widgets.md` returns 0
- `grep -c 'footer:' CHANGELOG.md` returns 0 (no old API reference in changelog)
- `grep 'footerBuilder' CHANGELOG.md` returns match

**QA**: `grep -rn 'footer:' .claude/rules/widgets.md CHANGELOG.md doc/` returns no stale `footer:` references (only `footerBuilder`)

**Independence**: depends on Steps 1-4
**Tier**: mid

---

## Waves

### Wave 1 (Start Immediately — parallel)
- Step 1 [mid]: DialogShell — footerBuilder + body shrink-to-content
- Step 3 [mid]: PasswordConfirmDialog — compact right-aligned buttons

### Wave 2 (After Wave 1)
- Step 2 [mid]: ConfirmDialog — compact buttons + footerBuilder adapter
- Step 4 [mid]: Export DialogShell from barrel

### Wave 3 (After Wave 2)
- Step 5 [mid]: Documentation updates

### Post-Waves
- `flutter test --coverage` full suite green
- `dart analyze --no-fatal-infos` clean
- `dart format .` clean
- Create feature branch + PR per project workflow

## Must NOT Have

- No `footer: Widget?` parameter remaining on DialogShell — fully replaced by `footerBuilder`
- No `flex-1` class on any dialog button wrapper (ConfirmDialog, PasswordConfirmDialog)
- No `SingleChildScrollView` in DialogShell body section
- No `w-full` on individual dialog buttons (buttons are auto-width from content)
- No migration of PasswordConfirmDialog or TwoFactorModal to use DialogShell — out of scope
- No new theme fields on `MagicStarterModalTheme` — existing tokens suffice
- No breaking changes to `MagicStarterConfirmDialog.show()` or `MagicStarterPasswordConfirmDialog.show()` public APIs
- No changes to TwoFactorModal — it already uses `justify-end` for buttons

## Risks

- `ListView(shrinkWrap: true)` has O(N) layout cost — acceptable for dialog content (never large lists). If body contains a nested ListView, it would need explicit height constraint. Document this in docblock.
- `footerBuilder` is a breaking internal API change — only ConfirmDialog uses DialogShell currently, so blast radius is contained. After export, this becomes the public API.
- Symbol existence unverified via LSP — confirm file structure before implementation.
