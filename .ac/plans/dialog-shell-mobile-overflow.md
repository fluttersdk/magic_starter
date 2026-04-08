# Plan: Fix Dialog Mobile Overflow (#13)

**TL;DR**: Fix MagicStarterDialogShell overflow on mobile by adding vertical `insetPadding` and computing `maxHeight` from safe area. Standardize same pattern across PasswordConfirmDialog and TwoFactorModal which have hardcoded `maxHeight` (600/800) with no safe area awareness.

**Intent**: Mid-sized fix
**Complexity**: Standard
**Test Strategy**: TDD — Red-Green-Refactor
**Codebase State**: Disciplined

## Steps

### Step 1 [quick]: Verify — DialogShell (already implemented)

DialogShell safe area fix and tests are already in working tree (3 new overflow tests + source fix). Verify they pass.

**Files**: `lib/src/ui/widgets/magic_starter_dialog_shell.dart`, `test/ui/widgets/magic_starter_dialog_shell_test.dart`
**Done when**: `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` — all 12 tests pass
**QA**: Run test command, verify `+12 -0`
**Independence**: independent
**Tier**: quick

---

### Step 2 [mid]: Red — PasswordConfirmDialog safe area tests

Add `mobile overflow safety` test group in `magic_starter_password_confirm_dialog_test.dart`:

1. `Dialog has vertical insetPadding` — set 400x800 screen, assert `insetPadding.top > 0` and `.bottom > 0`, horizontal stays 16
2. `maxHeight accounts for viewPadding safe area` — set `tester.view.viewPadding = FakeViewPadding(top: 44, bottom: 34)`, find ConstrainedBox, assert maxHeight < 600 (the old hardcoded value) and is safe-area-aware

**Files**: `test/ui/widgets/magic_starter_password_confirm_dialog_test.dart`
**Done when**: `flutter test test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` — 2 new tests fail, all existing pass
**QA**: Run test command, verify 2 failures on new tests only
**Independence**: independent
**Tier**: mid

---

### Step 3 [mid]: Red — TwoFactorModal safe area tests

Add `mobile overflow safety` test group in `magic_starter_two_factor_modal_test.dart`:

1. `Dialog has vertical insetPadding` — same pattern as Step 2
2. `maxHeight accounts for viewPadding safe area` — set viewPadding, assert maxHeight < 800 (old hardcoded) and is safe-area-aware

**Files**: `test/ui/widgets/magic_starter_two_factor_modal_test.dart`
**Done when**: `flutter test test/ui/widgets/magic_starter_two_factor_modal_test.dart` — 2 new tests fail, all existing pass
**QA**: Run test command, verify 2 failures on new tests only
**Independence**: independent
**Tier**: mid

---

### Step 4 [mid]: Green — Fix PasswordConfirmDialog

In `magic_starter_password_confirm_dialog.dart` build method:

```dart
final viewPadding = MediaQuery.viewPaddingOf(context);
final safeHeight = MediaQuery.sizeOf(context).height
    - viewPadding.top
    - viewPadding.bottom;
```

Change `insetPadding` from `EdgeInsets.symmetric(horizontal: 16)` to `EdgeInsets.symmetric(horizontal: 16, vertical: 24)`.

Change `maxHeight` from hardcoded `600` to `safeHeight * 0.85`.

**Files**: `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart`
**Done when**: `flutter test test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` — all tests pass
**QA**: Run test command, verify 0 failures
**Independence**: depends on Step 2
**Tier**: mid

---

### Step 5 [mid]: Green — Fix TwoFactorModal

In `magic_starter_two_factor_modal.dart` build method:

Same safe area pattern — compute `safeHeight`, add vertical insetPadding (24px), replace hardcoded `maxHeight: 800` with `safeHeight * 0.85`.

**Files**: `lib/src/ui/widgets/magic_starter_two_factor_modal.dart`
**Done when**: `flutter test test/ui/widgets/magic_starter_two_factor_modal_test.dart` — all tests pass
**QA**: Run test command, verify 0 failures
**Independence**: depends on Step 3
**Tier**: mid

---

### Step 6 [quick]: Full suite verification + docs

1. Run `flutter test --coverage` — all ~630+ tests pass
2. Run `flutter analyze --no-fatal-infos` — zero warnings
3. Run `dart format .` — zero formatting issues
4. Update `CHANGELOG.md` under `[Unreleased]` section
5. Add safe area pattern bullet to `.claude/rules/widgets.md`

**Files**: `CHANGELOG.md`, `.claude/rules/widgets.md`
**Done when**: Full test suite green, analysis clean, changelog updated
**QA**: `flutter test --coverage && flutter analyze --no-fatal-infos && dart format --set-exit-if-changed .`
**Independence**: depends on Steps 1, 4, 5
**Tier**: quick

---

## Waves

**Wave 1** (Start Immediately — all independent):
├── Step 1 [quick]: Verify — DialogShell (already implemented)
├── Step 2 [mid]: Red — PasswordConfirmDialog safe area tests
├── Step 3 [mid]: Red — TwoFactorModal safe area tests

**Wave 2** (After Wave 1):
├── Step 4 [mid]: Green — Fix PasswordConfirmDialog (depends on Step 2)
├── Step 5 [mid]: Green — Fix TwoFactorModal (depends on Step 3)

**Wave 3** (After Wave 2):
└── Step 6 [quick]: Full suite verification + docs

## Must NOT Have

- No new public API surface — only internal safe area calculation changes
- No changes to `MagicStarterModalTheme` (maxHeight stays out of theme — it's viewport-dependent)
- No Wind UI className changes (research confirmed Wind UI can't solve this)
- No bonus refactors in dialog structure (e.g. don't convert PasswordConfirmDialog to use DialogShell)
- No `SafeArea` widget wrapping — use `MediaQuery.viewPaddingOf()` calculation directly
- No changes to `magic_starter_notification_dropdown.dart` (also has hardcoded maxHeight but separate scope)

## Risks

- **Test viewport simulation**: `FakeViewPadding` in tests may not perfectly simulate real device safe areas — tests verify the math, not real-device behavior

## Research Summary

**Key Files**:
- `lib/src/ui/widgets/magic_starter_dialog_shell.dart:48-55` — Already fixed: viewPaddingOf + safeHeight + vertical insetPadding
- `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart:130-137` — Dialog with hardcoded maxHeight: 600, no safe area
- `lib/src/ui/widgets/magic_starter_two_factor_modal.dart:252-259` — Dialog with hardcoded maxHeight: 800, no safe area

**Patterns Found**:
- All 3 dialogs share identical structure: `Dialog(insetPadding: ...) → ConstrainedBox(maxHeight: ...) → WDiv`
- DialogShell fix pattern: `viewPaddingOf()` → subtract top/bottom → multiply by 0.85

**Codebase State**: Disciplined

### Conventions

- TDD red-green-refactor — failing test first
- Wind UI exclusively — no Material widgets except Dialog shell and Icons
- Trailing commas on all multi-line argument lists
- Import order: dart:*, package:flutter/*, package:magic/*, relative
- Test setUp: `MagicApp.reset()`, `Magic.flush()`, bind singletons
- Modal theme: read from `MagicStarter.manager.modalTheme` at build time
