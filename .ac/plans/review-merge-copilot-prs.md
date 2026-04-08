# Plan: Review and Merge Copilot PRs #4 and #5

**TL;DR**: Checkout each Copilot PR branch sequentially, run full verification (test+lint+analyze+format), review code against project conventions, fix issues, merge to main. Then release 0.0.1-alpha.3 with both features.

**Intent**: Mid-sized | **Complexity**: Standard
**Test Strategy**: Tests after (verify existing Copilot tests pass + fix if needed)
**Tier Summary**: 0 quick / 1 mid / 2 senior

## Steps

### Step 1 [senior]: Review, verify, fix, and merge PR #4 (CardVariant + PageHeader tests)

**Files:** All files in PR #4 diff:
- `lib/src/ui/widgets/magic_starter_card.dart` (modify — CardVariant enum + variant param)
- `test/ui/widgets/magic_starter_card_test.dart` (modify — 6 new variant tests)
- `test/ui/widgets/magic_starter_page_header_test.dart` (new — 8 test cases)
- `.claude/rules/widgets.md` (modify — card variant + page header docs)
- `CHANGELOG.md` (modify — new entry)
- `CLAUDE.md` (modify — gotchas + skills)
- `README.md` (modify — reusable widgets section)
- `doc/basics/views-and-layouts.md` (modify — reusable widgets section)

**Description:**
1. Checkout PR #4 branch: `git checkout copilot/export-ui-widgets`
2. Run full verification: `flutter test`, `flutter analyze --no-fatal-infos`, `dart format --set-exit-if-changed .`
3. Review each changed file against project conventions:
   - **Code**: Import order (dart → flutter → magic → relative), trailing commas, doc comments (`///`), section dividers (73-char), Wind UI compliance, dark mode pairing
   - **Card widget**: Verify `CardVariant` enum has proper doc comments, `switch` is exhaustive, defaults match current behavior (backward compatible), `const` constructor preserved
   - **Tests**: Mock pattern (no mockito), setUp/tearDown, group structure, assertion style
   - **PageHeader tests**: Verify they test existing API (actions, subtitle, leading) — NOT new code. If PageHeader doesn't already have these params, flag as incomplete
   - **CHANGELOG**: Must use project emoji categories (`### ✨ New Features` or `### 🔧 Improvements`), entry format `- **Title**: Description`
   - **CLAUDE.md**: Verify gotchas are accurate, skills reference is correct
   - **README**: Verify widget docs match actual API, examples are runnable
   - **rules/widgets.md**: Verify rules match implementation
4. Fix any convention violations directly on the branch
5. Run verification again after fixes
6. Merge to main: `git checkout main && git merge copilot/export-ui-widgets --no-ff`
7. Push: `git push`
8. Close PR #4 (auto-closed by merge if linked to branch)

**Done when:**
- `git log --oneline -1` shows merge commit on main
- `flutter test` — all tests pass (493+ tests)
- `flutter analyze --no-fatal-infos` — no issues
- `dart format --set-exit-if-changed .` — no changes needed
- `gh pr view 4 --json state --jq '.state'` returns `MERGED`

**QA:** `flutter test test/ui/widgets/magic_starter_card_test.dart test/ui/widgets/magic_starter_page_header_test.dart` → all pass, including 6 variant + 8 header tests

**Independence:** independent
**Tier:** senior

---

### Step 2 [senior]: Rebase, review, verify, fix, and merge PR #5 (Navigation Theme)

**Files:** All files in PR #5 diff:
- `lib/src/magic_starter_manager.dart` (modify — MagicStarterNavigationTheme class + manager field)
- `lib/src/facades/magic_starter.dart` (modify — useNavigationTheme + getter)
- `lib/src/ui/layouts/magic_starter_app_layout.dart` (modify — 4 locations: brand, navItem, bottomNav, userMenu)
- `lib/src/ui/widgets/magic_starter_user_profile_dropdown.dart` (modify — avatar gradient)
- `test/facades/magic_starter_facade_test.dart` (modify — 6 new navigation theme tests)
- `.claude/rules/layouts.md` (new — layout conventions)
- `.claude/rules/widgets.md` (modify — dropdown avatar rule)
- `CHANGELOG.md` (modify — new feature entry)
- `CLAUDE.md` (modify — architecture tree + gotchas)
- `README.md` (modify — navigation theme section)
- `doc/architecture/manager.md` (modify — navigation theme section)
- `doc/basics/views-and-layouts.md` (modify — theme example)

**Description:**
1. Checkout PR #5 branch: `git checkout copilot/add-configurable-navigation-colors`
2. Rebase on updated main (has PR #4 merge): `git rebase main`
3. Resolve merge conflicts in shared files: `widgets.md`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `doc/basics/views-and-layouts.md`
   - CHANGELOG: Both PRs add entries under `[Unreleased]` — combine them, PR #4 first then PR #5
   - widgets.md: Both PRs modify this — combine additions
   - CLAUDE.md: Both PRs add gotchas — append PR #5 entries after PR #4 entries
   - README.md: Both PRs add sections — ensure correct ordering
   - **Conflict resolution rule**: Resolve by mechanical combination only — do NOT rewrite non-conflicted prose
4. Run full verification: `flutter test`, `flutter analyze --no-fatal-infos`, `dart format --set-exit-if-changed .`
5. Review each changed file against project conventions:
   - **MagicStarterNavigationTheme class**: Verify doc comments, const constructor, all defaults match current hardcoded values in layout (cross-reference), trailing commas, field naming follows `*ClassName` pattern
   - **Manager integration**: Field placed in correct section, added to `reset()`, doc comment present
   - **Facade**: Follows `use*` pattern (like `useNavigation`, `useTeamResolver`), getter + setter pair, doc comment with example
   - **Layout updates**: All 4 hardcoded locations replaced with theme reads, string interpolation correct, `navTheme` local var used (not repeated `MagicStarter.navigationTheme` calls)
   - **Dropdown**: Avatar gradient uses theme
   - **Tests**: 6 tests cover defaults, custom values, brandBuilder, reset — verify completeness
   - **layouts.md rule**: Verify rules match implementation, no stale references
   - **Docs**: manager.md table updated, views-and-layouts.md example accurate
6. Verify `MagicStarterNavigationTheme` defaults match EXACTLY the current hardcoded values:
   - `activeItemClassName` default = `'active:text-primary active:bg-primary/10 dark:active:bg-primary/10'`
   - `brandClassName` default = `'text-lg font-bold text-primary'`
   - `bottomNavActiveClassName` default = `'active:text-primary'`
   - `avatarClassName` default = `'bg-primary/10 dark:bg-primary/10'`
   - `avatarTextClassName` default = `'text-sm font-bold text-primary'`
   - `dropdownAvatarClassName` default = `'bg-gradient-to-tr from-primary to-gray-200'`
7. Fix any convention violations directly on the branch
8. Run verification again after fixes
9. Merge to main: `git checkout main && git merge copilot/add-configurable-navigation-colors --no-ff`
10. Push: `git push`

**Done when:**
- `git log --oneline -1` shows merge commit on main
- `flutter test` — all tests pass
- `flutter analyze --no-fatal-infos` — no issues
- `dart format --set-exit-if-changed .` — no changes needed
- `gh pr view 5 --json state --jq '.state'` returns `MERGED`
- `grep -c 'MagicStarterNavigationTheme' lib/src/magic_starter_manager.dart` returns ≥1
- `grep -c 'useNavigationTheme' lib/src/facades/magic_starter.dart` returns ≥1
- `grep -c 'text-primary\|bg-primary/10' lib/src/ui/layouts/magic_starter_app_layout.dart` returns 0 (scoped to layout file only — other widgets may legitimately use these classes)

**QA:** `flutter test test/facades/magic_starter_facade_test.dart` → navigation theme group (6 tests) all pass

**Independence:** depends on Step 1
**Tier:** senior

---

### Step 3 [mid]: Release 0.0.1-alpha.3

**Files:**
- `pubspec.yaml` (version bump)
- `CHANGELOG.md` (move Unreleased → 0.0.1-alpha.3)
- `CLAUDE.md` (version bump)

**Description:**
Run `/release 0.0.1-alpha.3` which handles: version bump in pubspec/CLAUDE.md/CHANGELOG, local verification (format + analyze + test + dry-run), commit, push, GitHub Release creation (prerelease), and publish workflow monitoring.

**Done when:**
- `gh release view 0.0.1-alpha.3 --json tagName --jq '.tagName'` returns `0.0.1-alpha.3`
- Publish workflow completed successfully
- pub.dev shows version 0.0.1-alpha.3

**QA:** `gh run list --workflow=publish.yml --limit 1 --json conclusion --jq '.[0].conclusion'` → `success`

**Independence:** depends on Step 2
**Tier:** mid

## Waves

Wave 1 (Start Immediately):
└── Step 1 [senior]: Review, verify, fix, and merge PR #4

Wave 2 (After Wave 1):
└── Step 2 [senior]: Rebase, review, verify, fix, and merge PR #5

Wave 3 (After Wave 2):
└── Step 3 [mid]: Release 0.0.1-alpha.3

## Must NOT Have
- No code changes beyond mechanical convention fixes: formatting, import ordering, missing trailing commas, doc comment additions only — no logic changes, no restructuring, no extracting helpers
- No squash merges — use `--no-ff` merge commits to preserve PR history
- No skipping test/lint/analyze verification on either branch
- No merging with failing tests or lint warnings
- No changes to files outside the PR's diff scope (except conflict resolution)
- No version bump until both PRs are merged
- No direct push to PR branches without running verification first

## Risks
- **Merge conflicts in Wave 2**: PR #5 will conflict with PR #4 on 4-5 shared files (widgets.md, CHANGELOG, CLAUDE.md, README, views-and-layouts.md). Resolution is straightforward — combine additions from both PRs. Mitigation: manual rebase with careful conflict resolution.
- **PageHeader API confirmed**: PR #4 review agent confirmed `magic_starter_page_header.dart:1-66` already has `actions`, `subtitle`, and `leading` params. PR #4 correctly adds only tests for existing API. No risk here.
- **Navigation theme defaults drift**: If PR #4 changes any className in layout/widgets, PR #5's defaults might not match. Mitigation: cross-reference defaults after rebase in Step 2.

### Research Summary

**Key Files:**
- `lib/src/ui/widgets/magic_starter_card.dart:34-91` — Card widget baseline (noPadding, title slot)
- `lib/src/ui/widgets/magic_starter_page_header.dart:1-66` — PageHeader with existing subtitle/actions API
- `lib/src/magic_starter_manager.dart:42-106` — Manager config objects (NavigationConfig, TeamResolver)
- `lib/src/facades/magic_starter.dart:56-238` — Facade use*/getter pattern
- `lib/src/ui/layouts/magic_starter_app_layout.dart:244-540` — Layout hardcoded colors (4 locations)
- `lib/src/ui/widgets/magic_starter_user_profile_dropdown.dart:53-77` — Avatar gradient

**Patterns Found:**
- Config objects: plain Dart classes with const constructors, stored on Manager, exposed via Facade
- Facade pattern: `static void use*(Config)` setter + `static Config? get *` getter
- Test pattern: Wind UI `WindTheme(data: WindThemeData(), child: ...)` wrapper, no mockito
- Doc updates: CHANGELOG emoji categories, CLAUDE.md gotchas table, README sections

**Codebase State:** Disciplined

### Conventions
- Import order: dart → flutter → magic → relative
- Trailing commas on ALL multi-line params
- Doc comments `///` on public APIs
- Section dividers: 73-char ASCII dashes
- Dark mode: always pair light/dark classes
- Wind UI exclusively — no Material widgets except Icons.*
- Config classes: const constructor, all fields optional with defaults
