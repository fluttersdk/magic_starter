# AGENTS.md

## Build & Test

| Command | Description |
|---------|-------------|
| `flutter test --coverage` | Run all tests (~40 files, ~630+ cases) with coverage |
| `flutter test test/http/controllers/` | Run controller tests only |
| `flutter test --name "pattern"` | Run tests matching pattern |
| `flutter analyze --no-fatal-infos` | Static analysis (flutter_lints ^6.0) |
| `dart format .` | Format all code |
| `dart fix --apply` | Auto-fix lint issues |
| `dart run magic_starter:install` | Scaffold config + provider into consumer project |
| `dart run magic_starter:configure` | Interactive feature toggle configuration |
| `dart run magic_starter:doctor` | Diagnose project setup issues |

## Development Flow (TDD)

Every feature, fix, or refactor must go through the red-green-refactor cycle:

1. **Red** — Write a failing test that describes the expected behavior
2. **Green** — Write the minimum code to make the test pass
3. **Refactor** — Clean up while keeping tests green

**Verification cycle:** Edit → `flutter test` → `dart analyze` → repeat until green

- No production code without a failing test first
- Run `flutter test` after every change — all tests must stay green
- Run `dart analyze` after every change — zero warnings, zero errors
- Run `dart format .` before committing — zero formatting issues

## Testing

- Mock via contract inheritance (no mockito): `class MockNetworkDriver implements NetworkDriver`
- Reset state in setUp: `MagicApp.reset()`, `Magic.flush()`, bind mocks, configure guards
- Tests mirror `lib/src/` structure in `test/`

## Git Workflow

- Feature branches from main — never push to main directly
- PR required for all changes
- Run tests + analyzer before committing

## CI

`ci.yml`: push/PR → `flutter pub get` → `flutter analyze --no-fatal-infos` → `dart format --set-exit-if-changed` → `flutter test --coverage` → codecov upload

## Boundaries

- **Always**: run `flutter test` and `dart analyze` after code changes
- **Always**: update CHANGELOG.md, README.md, doc/ after source changes
- **Never**: force-push to main, skip pre-commit hooks
- **Never**: use Material widgets (except `Icons.*` and `Dialog` shell) — Wind UI only
