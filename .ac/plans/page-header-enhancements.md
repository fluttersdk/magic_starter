# Plan: Enhance MagicStarterPageHeader with titleSuffix and inlineActions

**Complexity**: standard
**Steps**: 4 | **Waves**: 2
**Codebase State**: disciplined

### Research Summary
- **Key Files**:
  - `lib/src/ui/widgets/magic_starter_page_header.dart:1-66` — StatelessWidget, 4 params (title, subtitle, leading, actions), flat build method
  - `test/ui/widgets/magic_starter_page_header_test.dart:1-151` — 8 tests covering all branches
  - `doc/basics/views-and-layouts.md:481-501` — Public API docs for PageHeader
  - `.claude/rules/widgets.md:17` — PageHeader contract
  - 5 internal usages — all use title+subtitle only, no leading/actions
- **Patterns**: Wind UI exclusively, dark mode pairing, `if (x != null) x!` spread for optional widgets, flat build methods (no private builders)
- **Codebase State**: disciplined — consistent patterns, good test coverage, TDD enforced

### Conventions
- TDD: red-green-refactor — failing test first
- Wind UI exclusively — no Material widgets except Dialog shell and Icons.*
- Dark mode: always pair light/dark classes
- `if (x != null) x!` spread for conditional widgets — no SizedBox.shrink() fallback
- Flat build methods — no private `_buildX()` extraction for simple widgets
- Trailing commas on all multi-line argument lists
- Doc comments (`///`) on public APIs
- Post-change: CHANGELOG.md + doc/ updates required

### Wave 1

**Step 1**: Add failing tests for `titleSuffix` and `inlineActions`
- **Type**: code
- **Tier**: mid
- **Files**: `/Users/anilcan/Code/fluttersdk/magic_starter/test/ui/widgets/magic_starter_page_header_test.dart`
- **Done when**:
  - New test: `titleSuffix` renders inline after title column when provided — uses `find.byKey()` to verify suffix widget is present
  - New test: `titleSuffix` not rendered when null — no regression on existing layout
  - New test: `inlineActions: true` outer WDiv className contains `flex-row` without `flex-col`
  - New test: `inlineActions: false` (default) retains `flex-col sm:flex-row` — confirms no change to existing behavior
  - New test: combined `titleSuffix` + `inlineActions: true` + `leading` — all elements render
  - All new tests FAIL (widget params don't exist yet)
- **QA**: `flutter test test/ui/widgets/magic_starter_page_header_test.dart` — new tests fail with compile errors (unknown params)
- **Must NOT**: Modify any existing test case; touch production code

**Step 2**: Update CHANGELOG and documentation
- **Type**: code
- **Tier**: quick
- **Files**: `/Users/anilcan/Code/fluttersdk/magic_starter/CHANGELOG.md`
- **Description**: Add entry under `[Unreleased]` section:
  - Category: `### ✨ New Features`
  - Entry: `- **MagicStarterPageHeader**: Added `titleSuffix` (Widget?) for inline widgets after title (e.g. status badges) and `inlineActions` (bool) to force single-row layout on all screen sizes (#24)`
- **Done when**:
  - `grep 'titleSuffix' CHANGELOG.md` returns a match under `[Unreleased]`
- **QA**: `grep -A 2 'Unreleased' CHANGELOG.md` shows the new entry
- **Must NOT**: Move or modify existing changelog entries

### Wave 2 (depends on Wave 1)

**Step 3**: Implement `titleSuffix` and `inlineActions` in PageHeader widget
- **Type**: code
- **Tier**: mid
- **Files**: `/Users/anilcan/Code/fluttersdk/magic_starter/lib/src/ui/widgets/magic_starter_page_header.dart`
- **Done when**:
  - New `Widget? titleSuffix` field with `///` doc comment — positioned after the title column WDiv inside the inner title+leading row WDiv, via `if (titleSuffix != null) titleSuffix!` spread
  - New `bool inlineActions` field (default `false`) with `///` doc comment — toggles outer WDiv className: `inlineActions ? 'w-full flex flex-row items-center justify-between gap-4 p-2 lg:p-4 border-b border-gray-200 dark:border-gray-700' : 'w-full flex flex-col sm:flex-row items-start sm:items-center sm:justify-between gap-4 p-2 lg:p-4 border-b border-gray-200 dark:border-gray-700'`
  - Build method stays flat — no private builder methods
  - All 13 tests pass (8 existing + 5 new)
- **QA**: `flutter test test/ui/widgets/magic_starter_page_header_test.dart` — all 13 pass; `dart analyze --no-fatal-infos` — 0 issues
- **Must NOT**: Extract private builder methods; introduce computed className variables; modify existing params or doc comments; use SizedBox.shrink() as null fallback

**Step 4**: Update documentation for new params
- **Type**: code
- **Tier**: quick
- **Files**: `/Users/anilcan/Code/fluttersdk/magic_starter/doc/basics/views-and-layouts.md`
- **Description**: In the PageHeader section (lines 481-501), add two new rows to the parameter table:
  - `| titleSuffix | Widget? | null | Optional widget rendered inline after the title (e.g. status badge). Uses flex-shrink-0 to prevent truncation. |`
  - `| inlineActions | bool | false | When true, forces single-row layout on all screen sizes (no mobile stacking). |`
  - Add a usage example showing both new params
- **Done when**:
  - `grep 'titleSuffix' doc/basics/views-and-layouts.md` returns a match
  - `grep 'inlineActions' doc/basics/views-and-layouts.md` returns a match
- **QA**: Read the file and verify the param table has 6 rows (title, subtitle, leading, actions, titleSuffix, inlineActions)
- **Must NOT**: Rewrite existing parameter descriptions; change other sections of the doc

### Must NOT Have
- No private builder method extraction (`_buildTitleRow`, `_buildActionsRow`, etc.)
- No computed className variables or helper methods
- No SizedBox.shrink() or ternary wrapper WDiv as null fallback
- No modifications to existing tests or doc comments
- No changes to the 5 internal usages — they don't need updating
- No README changes beyond what's covered by doc/
- No bonus refactors or scope expansion

### Risks
- `titleSuffix` placement inside the title row may affect subtitle alignment — the title column (`flex-col gap-1`) with `flex-1 min-w-0` should still truncate correctly, but the suffix adds a sibling that reduces available title width. Verify visually if possible.
- `inlineActions: true` on very narrow screens (< 320px) may cause overflow if actions are wide. This matches consumer intent (issue states "always stay on the same row") — documented as expected behavior.
