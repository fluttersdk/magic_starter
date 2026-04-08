# Plan: Fix Footer Button Alignment (Issue #9)

**TL;DR**: Add `w-full` to footer WDiv className in PasswordConfirmDialog (1 location) and TwoFactorModal (2 locations) so `justify-end` can right-align buttons. Add alignment tests for TwoFactorModal.

**Intent**: Fix
**Complexity**: Simple
**Test Strategy**: TDD — write failing tests first, then fix

## Steps

**Step 1**: Add footer alignment tests for TwoFactorModal [quick]

Add a test group `compact right-aligned button layout` to `test/ui/widgets/magic_starter_two_factor_modal_test.dart` mirroring the existing pattern in `magic_starter_password_confirm_dialog_test.dart:161-225`. Test that:
- Setup step footer Wrap has `WrapAlignment.end`
- Recovery step footer Wrap has `WrapAlignment.end`
- No `flex-1` WDiv wrappers in either footer
- No `w-full` WButton in either footer

Files: `test/ui/widgets/magic_starter_two_factor_modal_test.dart`
Done when: `flutter test test/ui/widgets/magic_starter_two_factor_modal_test.dart` — new tests exist and fail on alignment (Wrap alignment not end because w-full missing means container doesn't stretch)
QA: `grep -c 'right-aligned button layout' test/ui/widgets/magic_starter_two_factor_modal_test.dart` returns 1
Independence: independent
Tier: quick

**Step 2**: Add footer full-width test for PasswordConfirmDialog [quick]

Add a test to the existing `compact right-aligned button layout` group in `test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` that verifies the footer WDiv has `w-full` in its className. This test should fail initially (w-full is currently missing).

Files: `test/ui/widgets/magic_starter_password_confirm_dialog_test.dart`
Done when: `flutter test test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` — new test fails because `w-full` is not in the footer className
QA: `grep -c 'w-full' test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` returns ≥1
Independence: independent
Tier: quick

**Step 3**: Fix PasswordConfirmDialog footer — add `w-full` [quick]

In `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart` line 174, change:
```
'${theme.footerClassName} flex flex-row justify-end gap-2 wrap'
```
to:
```
'${theme.footerClassName} flex flex-row w-full justify-end gap-2 wrap'
```

Files: `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart`
Done when: `flutter test test/ui/widgets/magic_starter_password_confirm_dialog_test.dart` — all tests pass
QA: `grep 'w-full justify-end' lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart` returns 1 match
Independence: depends on Step 2
Tier: quick

**Step 4**: Fix TwoFactorModal footers — add `w-full` to both locations [quick]

In `lib/src/ui/widgets/magic_starter_two_factor_modal.dart`:
- Line 166: change `'flex flex-row justify-end gap-2 wrap mt-2'` to `'flex flex-row w-full justify-end gap-2 wrap mt-2'`
- Line 232: change `'flex flex-row justify-end gap-2 wrap mt-2'` to `'flex flex-row w-full justify-end gap-2 wrap mt-2'`

Files: `lib/src/ui/widgets/magic_starter_two_factor_modal.dart`
Done when: `flutter test test/ui/widgets/magic_starter_two_factor_modal_test.dart` — all tests pass including new alignment tests
QA: `grep -c 'w-full justify-end' lib/src/ui/widgets/magic_starter_two_factor_modal.dart` returns 2
Independence: depends on Step 1
Tier: quick

**Step 5**: Update CHANGELOG and docs [quick]

Add entry under `[Unreleased]` in CHANGELOG.md:
```
### Fixed
- **MagicStarterPasswordConfirmDialog**: Footer buttons now right-aligned — added `w-full` so `justify-end` stretches to container width
- **MagicStarterTwoFactorModal**: Footer buttons now right-aligned in both setup and recovery steps — same `w-full` fix
```

Files: `CHANGELOG.md`
Done when: `grep -c 'w-full' CHANGELOG.md` returns ≥1
Independence: depends on Steps 3, 4
Tier: quick

### Waves

**Wave 1** (parallel — no deps):
├── Step 1 [quick]: TwoFactorModal alignment tests
├── Step 2 [quick]: PasswordConfirmDialog w-full test

**Wave 2** (after Wave 1):
├── Step 3 [quick]: Fix PasswordConfirmDialog footer
├── Step 4 [quick]: Fix TwoFactorModal footers

**Wave 3** (after Wave 2):
├── Step 5 [quick]: CHANGELOG update

### Must NOT Have

- No refactoring PasswordConfirmDialog or TwoFactorModal to use DialogShell (out of scope — Option B from issue)
- No changes to ConfirmDialog (already works correctly)
- No changes to DialogShell
- No `flex-1` wrappers on buttons
- No `w-full` on individual buttons — only on the footer container WDiv

### Research Summary

**Key Files**:
- `lib/src/ui/widgets/magic_starter_password_confirm_dialog.dart:174` — footer missing `w-full`
- `lib/src/ui/widgets/magic_starter_two_factor_modal.dart:166` — setup step footer missing `w-full`
- `lib/src/ui/widgets/magic_starter_two_factor_modal.dart:232` — recovery step footer missing `w-full`
- `test/ui/widgets/magic_starter_password_confirm_dialog_test.dart:161-225` — existing alignment test pattern to follow
- `test/ui/widgets/magic_starter_two_factor_modal_test.dart` — no alignment tests yet

**Patterns Found**: Wind UI `justify-end` requires the container to have full width to push children right. ConfirmDialog works because DialogShell uses `crossAxisAlignment.stretch`. Custom layouts need explicit `w-full`.

**Codebase State**: Disciplined — consistent patterns, good test coverage, follow existing patterns exactly.

### Conventions

- TDD: red-green-refactor
- Wind UI className: `flex flex-row w-full justify-end gap-2 wrap`
- Test pattern: `find.ancestor(of: find.text('common.cancel'), matching: find.byType(Wrap)).first` then check `WrapAlignment.end`
- All dialog footers: compact right-aligned buttons with `justify-end gap-2 wrap` — never `flex-1`
- Dark mode pairing not affected (no color changes)
