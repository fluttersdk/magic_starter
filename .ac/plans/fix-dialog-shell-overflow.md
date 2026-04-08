# Plan: Fix MagicStarterDialogShell bottom overflow

**Complexity**: simple
**Steps**: 2 | **Waves**: 1
**Codebase State**: disciplined

### Research Summary
- **Key Files**: `lib/src/ui/widgets/magic_starter_dialog_shell.dart:65-68` — WDiv with `flex flex-col` wrapping Column breaks constraint chain
- **Key Files**: `test/ui/widgets/magic_starter_dialog_shell_test.dart` — 12 existing tests, none test overflow with many items
- **Patterns**: Wind UI WDiv with `flex flex-col` renders as Flex widget; nested Column (also Flex) receives unconstrained height
- **Codebase State**: disciplined — consistent patterns, good test coverage

### Conventions
- TDD: red-green-refactor — failing test first
- Wind UI exclusively — no Material widgets except Dialog shell and Icons.*
- Dark mode: always pair light/dark classes
- Dialog shell: sticky header/footer with scrollable body (ListView shrinkWrap: true)

### Wave 1

**Step 1**: Add failing overflow test with many body items
- **Type**: code
- **Tier**: mid
- **Files**: `/Users/anilcan/Code/fluttersdk/magic_starter/test/ui/widgets/magic_starter_dialog_shell_test.dart`
- **Done when**:
  - New test in `mobile overflow safety` group that renders DialogShell with 20+ tall children in a 400x600 viewport
  - Test asserts: no overflow error, body scrolls (ListView found), footer is rendered (footer key found)
  - Test FAILS on current code (overflow error)
- **QA**: `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` — new test fails with overflow
- **Must NOT**: Modify production code in this step

**Step 2**: Fix WDiv constraint propagation — remove `flex flex-col` from outer WDiv className
- **Type**: code
- **Tier**: mid
- **Files**: `/Users/anilcan/Code/fluttersdk/magic_starter/lib/src/ui/widgets/magic_starter_dialog_shell.dart`
- **Done when**:
  - Line 67: WDiv className no longer contains `flex flex-col` — becomes `'${theme.containerClassName} w-full overflow-hidden'`
  - Column still has `mainAxisSize: MainAxisSize.min` and `CrossAxisAlignment.stretch`
  - All 13 tests pass (12 existing + 1 new overflow test)
- **QA**: `flutter test test/ui/widgets/magic_starter_dialog_shell_test.dart` — all pass, zero overflow errors
- **Must NOT**: Change ListView to SingleChildScrollView, add ClipRRect, touch header/footer structure

### Must NOT Have
- No changes to other widgets or files beyond the two listed
- No bonus refactors or cleanups
- No SingleChildScrollView — keep ListView(shrinkWrap: true) pattern per project rules

### Risks
- Wind UI WDiv without `flex` may render differently than expected (unlikely — should be a simple container). Verify visually if possible.
