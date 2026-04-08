# Plan: Customizable Sidebar Footer Builder

**Complexity**: standard
**Steps**: 4 | **Waves**: 3
**Codebase State**: disciplined

### Research Summary
- **Key Files**:
  - `lib/src/magic_starter_manager.dart:288-329` — MagicStarterManager with builder fields (headerBuilder:312, socialLoginBuilder:315)
  - `lib/src/magic_starter_manager.dart:502-518` — `reset()` method clearing all fields
  - `lib/src/facades/magic_starter.dart:127-144` — `useLogout()`, `useHeader()` facade pattern
  - `lib/src/ui/layouts/magic_starter_app_layout.dart:150-165` — `_buildSidebar()` structure: brand → team selector → Expanded(navigation) → userMenu
  - `lib/src/ui/layouts/magic_starter_app_layout.dart:172-198` — `_buildDrawer()` identical structure
  - `test/ui/layouts/magic_starter_app_layout_test.dart` — existing layout test patterns
  - `test/facades/magic_starter_facade_test.dart` — facade test patterns
- **Patterns**: Builder fields on manager → facade `useX()` method → layout reads at build time → `reset()` clears to null
- **Codebase State**: Disciplined — consistent patterns, full test coverage, clear conventions

### Conventions
- Wind UI exclusively — no Material widgets except `Icons.*` and `Dialog` shell
- Builder pattern: `Widget Function(BuildContext context)?` with null default
- Facade: `static void useX(builder)` sets `manager.xBuilder`
- Reset: every builder field must be `= null` in `reset()`
- Dark mode: builders are consumer-provided — no theme enforcement needed from our side
- Trailing commas on all multi-line argument lists
- Doc comments (`///`) on public APIs
- Section dividers: 73-char ASCII dashes
- Import order: dart: → package:flutter → package:magic → relative

### Wave 1

**Step 1**: Add sidebarFooterBuilder field to manager + facade method
- **Type**: code
- **Tier**: mid
- **Files**:
  - `/Users/anilcan/Code/fluttersdk/magic_starter/lib/src/magic_starter_manager.dart`
  - `/Users/anilcan/Code/fluttersdk/magic_starter/lib/src/facades/magic_starter.dart`
- **Description**: Add `Widget Function(BuildContext context)? sidebarFooterBuilder` field to `MagicStarterManager` (after `headerBuilder` at line 312). Add `sidebarFooterBuilder = null` to `reset()` method. Add `static void useSidebarFooter(Widget Function(BuildContext context) builder)` facade method to `MagicStarter` class following the exact pattern of `useHeader()` at facades/magic_starter.dart:140-144.
- **Done when**:
  - `grep 'sidebarFooterBuilder' lib/src/magic_starter_manager.dart` returns the field declaration AND the reset line
  - `grep 'useSidebarFooter' lib/src/facades/magic_starter.dart` returns the facade method
- **QA**: `dart analyze --no-fatal-infos` returns 0 issues
- **Must NOT**: Add example code blocks in doc comments. Add any builder for bottom nav. Add typedef or abstraction.

### Wave 2 (depends on Wave 1)

**Step 2**: Render sidebar footer in layout
- **Type**: code
- **Tier**: mid
- **Files**:
  - `/Users/anilcan/Code/fluttersdk/magic_starter/lib/src/ui/layouts/magic_starter_app_layout.dart`
- **Description**: In `_buildSidebar()` (line 150), insert the footer widget between `Expanded(child: _buildNavigation(...))` and `_buildUserMenu(context)`. Use a single null-check conditional: `if (MagicStarter.manager.sidebarFooterBuilder != null) MagicStarter.manager.sidebarFooterBuilder!(context)`. Apply the identical change in `_buildDrawer()` (line 172) at the same structural position. No wrapper div, no divider — just the raw builder output inserted in the children list.
- **Done when**:
  - `grep 'sidebarFooterBuilder' lib/src/ui/layouts/magic_starter_app_layout.dart` returns 2 occurrences (sidebar + drawer)
  - Both render sites are between navigation and user menu in the children list
- **QA**: `dart analyze --no-fatal-infos` returns 0 issues
- **Must NOT**: Add wrapper WDiv around the footer. Add more than one null-check per render site. Touch bottom nav code.

**Step 3**: Add tests for sidebar footer builder
- **Type**: code
- **Tier**: mid
- **Files**:
  - `/Users/anilcan/Code/fluttersdk/magic_starter/test/facades/magic_starter_facade_test.dart`
- **Description**: Add a test group for `useSidebarFooter` in the existing facade test file. Tests needed: (1) `useSidebarFooter()` sets `manager.sidebarFooterBuilder` to a non-null builder, (2) `manager.reset()` clears `sidebarFooterBuilder` back to null. Follow the existing test patterns in the file — setUp with `MagicApp.reset()` + `Magic.flush()`.
- **Done when**:
  - `grep 'useSidebarFooter' test/facades/magic_starter_facade_test.dart` returns test references
  - `flutter test test/facades/magic_starter_facade_test.dart` passes
- **QA**: `flutter test test/facades/magic_starter_facade_test.dart` — all tests pass
- **Must NOT**: Write widget pump tests. Write layout rendering tests. Test responsive breakpoints.

### Wave 3 (depends on Wave 2)

**Step 4**: Sync changelog, docs, and README
- **Type**: code
- **Tier**: quick
- **Files**:
  - `/Users/anilcan/Code/fluttersdk/magic_starter/CHANGELOG.md`
  - `/Users/anilcan/Code/fluttersdk/magic_starter/doc/basics/views-and-layouts.md`
- **Description**: In CHANGELOG.md, add under `## [Unreleased]` section `### ✨ New Features` with entry: `- **Sidebar Footer**: Added `sidebarFooterBuilder` slot via `MagicStarter.useSidebarFooter()` — renders custom widget between navigation and user menu in both desktop sidebar and mobile drawer (#27)`. In doc/basics/views-and-layouts.md, find the existing layout customization section and add a brief entry for `useSidebarFooter()` following the same format as other customization hooks documented there. Also note that logo/brand customization is already available via `useNavigationTheme(brandBuilder: ...)`.
- **Done when**:
  - `grep 'sidebarFooterBuilder' CHANGELOG.md` returns the entry
  - `grep 'useSidebarFooter' doc/basics/views-and-layouts.md` returns a reference
- **QA**: Files are valid markdown, no formatting issues
- **Must NOT**: Create new documentation sections. Add example code blocks. Update README widget count (still 10 widgets, this is a layout feature not a widget).

### Must NOT Have
- No `sidebarLogoBuilder` — `brandBuilder` on `MagicStarterNavigationTheme` already covers logo/brand customization
- No bottom navigation footer builder — the issue says "consider", deferred to follow-up
- No wrapper div or divider around the footer widget — consumer controls rendering
- No abstraction over builder fields (registry, typedef, base class)
- No widget pump / layout rendering tests — unit tests for facade/reset only
- No doc comment example code blocks on the facade method

### Risks
- The issue mentions `sidebarLogo` but `brandBuilder` already exists — PR description should clarify this is already supported via `useNavigationTheme(brandBuilder: ...)`
- Bottom nav footer deferred — may need a follow-up issue if consumers request it
