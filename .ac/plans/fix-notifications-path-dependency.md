# Plan: Fix hardcoded path dependency for magic_notifications

**TL;DR**: Replace `addPathDependencyToPubspec` with `addDependencyToPubspec` in the install command so `magic_notifications` is added as a pub.dev version constraint instead of a broken relative path.

**Intent**: Fix | **Complexity**: Simple
**Test Strategy**: TDD (test first)
**Tier Summary**: 1 quick / 1 mid / 0 senior

## Steps

### Step 1 [quick]: Add test for notifications dependency type

**Files:**
- `test/cli/commands/magic_starter_install_command_test.dart` (modify)

**Description:**
Add a test case in the install command test file that verifies when `notifications: true` is passed, the pubspec.yaml gets `magic_notifications` added as a version dependency (`^0.0.1-alpha.1`), NOT as a path dependency. The test should:
- Set up a mock project with a pubspec.yaml
- Run install with `notifications: true`
- Assert the pubspec.yaml contains `magic_notifications: ^0.0.1-alpha.1`
- Assert the pubspec.yaml does NOT contain `path: ../magic_notifications`

Follow existing test patterns in the file (mock filesystem, setUp/tearDown).

**Done when:**
- `flutter test test/cli/commands/magic_starter_install_command_test.dart --name "notifications"` runs (test may fail RED — that's expected for TDD)

**QA:** `grep -c 'addDependencyToPubspec\|version.*magic_notifications' test/cli/commands/magic_starter_install_command_test.dart` returns ≥1

**Independence:** independent
**Tier:** quick

### Step 2 [mid]: Replace path dependency with version dependency

**Files:**
- `lib/src/cli/commands/magic_starter_install_command.dart` (modify — lines 1118-1122)

**Description:**
In `_setupNotifications()` method, replace:
```dart
ConfigEditor.addPathDependencyToPubspec(
  pubspecPath: pubspecPath,
  name: 'magic_notifications',
  path: '../magic_notifications',
);
```
With:
```dart
ConfigEditor.addDependencyToPubspec(
  pubspecPath: pubspecPath,
  name: 'magic_notifications',
  version: '^0.0.1-alpha.1',
);
```

`ConfigEditor.addDependencyToPubspec` already exists in `magic_cli` (line 30 of `config_editor.dart`) with signature `({required String pubspecPath, required String name, required String version})`.

**Done when:**
- `flutter test` — all tests pass (GREEN)
- `dart analyze --no-fatal-infos` — zero errors/warnings
- `grep -c 'addPathDependencyToPubspec' lib/src/cli/commands/magic_starter_install_command.dart` returns 0
- `grep -c 'addDependencyToPubspec' lib/src/cli/commands/magic_starter_install_command.dart` returns 1

**QA:** `grep 'addDependencyToPubspec' lib/src/cli/commands/magic_starter_install_command.dart` shows version-based call with `^0.0.1-alpha.1`

**Independence:** depends on Step 1
**Tier:** mid

## Waves

Wave 1 (Start Immediately):
└── Step 1 [quick]: Add test for notifications dependency type

Wave 2 (After Wave 1):
└── Step 2 [mid]: Replace path dependency with version dependency

## Must NOT Have
- No hardcoded `../magic_notifications` path reference remaining in production code
- No changes to `ConfigEditor` class itself (it's in `magic_cli` package)
- No version bumps or changelog updates in this fix (separate concern)
- No changes to any file other than the install command and its test

## Risks
- The test pattern for install command may need adaptation — existing tests may not exercise `_setupNotifications` directly (it's a private method called during install flow). May need to test via the full install flow or make the method testable
- Version `^0.0.1-alpha.1` is hardcoded — if magic_notifications publishes a new version, this constraint stays. Acceptable for alpha stage

### Research Summary

**Key Files:**
- `lib/src/cli/commands/magic_starter_install_command.dart:1108-1133` — `_setupNotifications()` method with the bug
- `magic_cli` `config_editor.dart:30-48` — `addDependencyToPubspec()` target API (version-based)
- `magic_cli` `config_editor.dart:61-83` — `addPathDependencyToPubspec()` current (broken) API usage
- `test/cli/commands/magic_starter_install_command_test.dart` — existing install command tests
- `pubspec.yaml:25` — magic_notifications version constraint: `^0.0.1-alpha.1`

**Patterns Found:**
- `ConfigEditor` provides both `addDependencyToPubspec` (version) and `addPathDependencyToPubspec` (path) — wrong one was used
- All other dependencies in consumer projects use version constraints, not path dependencies

**Dependencies:**
- `magic_cli ^0.0.1-alpha.3` — provides ConfigEditor with both methods

**Codebase State:** Disciplined — consistent patterns, good test coverage, clear conventions
