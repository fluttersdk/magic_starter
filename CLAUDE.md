# Magic Starter Plugin

Flutter starter kit for the Magic Framework. Pre-built Auth, Profile, Teams & Notifications — 13 opt-in features, every screen overridable via Wind UI.

**Version:** 0.0.1-alpha.2 · **Dart:** >=3.6.0 · **Flutter:** >=3.27.0

## Commands

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

## Architecture

**Pattern**: ServiceProvider + Singleton Manager + Feature Flags + View Registry + Controller/View separation

```
lib/
├── magic_starter.dart              # Barrel export — 46 exports
├── config/
│   └── magic_starter.dart          # Configuration template stub
└── src/
    ├── magic_starter_manager.dart  # Singleton registry: user model, team resolver, nav, views
    ├── configuration/              # 13 feature toggles (all default false, opt-in)
    ├── providers/                  # IoC registration, 9 Gate abilities, boot logic
    ├── facades/                    # Static API: MagicStarter.useUserModel(), .view.make()
    ├── http/controllers/           # 7 controllers + NavigatesRoutes mixin
    │   └── concerns/              # Shared mixins (navigates_routes.dart)
    ├── routes/                     # Per-module route registration (feature-gated)
    ├── models/                     # AuthUser, Team, NavItem
    ├── ui/
    │   ├── layouts/               # AppLayout (authenticated), GuestLayout (auth pages)
    │   ├── views/                 # auth/, profile/, teams/, notifications/
    │   └── widgets/               # 10 reusable Wind UI components
    └── cli/                        # install, configure, doctor, publish, uninstall
bin/
└── magic_starter.dart              # CLI entry point — registers commands with Kernel
assets/stubs/                       # Stub templates for code generation
```

**Data flow:** App boot → `MagicStarterServiceProvider.register()` → binds manager + 9 Gate abilities → `boot()` → resolves config, registers default views → Feature-gated routes registered → Controllers handle HTTP via `Http.*` → Views render via `MagicStatefulView` + Wind UI

**Pure Dart** — no android/, ios/, or native platform code.

Depends on: `magic`, `magic_notifications` (internal packages).

## Post-Change Checklist

After ANY source code change, sync **before committing**:

1. **`CHANGELOG.md`** — Add entry under `[Unreleased]` section
2. **`README.md`** — Update if features, API, or usage changes
3. **`doc/`** — Update relevant documentation files

## Development Flow (TDD)

Every feature, fix, or refactor must go through the red-green-refactor cycle:

1. **Red** — Write a failing test that describes the expected behavior
2. **Green** — Write the minimum code to make the test pass
3. **Refactor** — Clean up while keeping tests green

**Rules:**
- No production code without a failing test first
- Run `flutter test` after every change — all tests must stay green
- Run `dart analyze` after every change — zero warnings, zero errors
- Run `dart format .` before committing — zero formatting issues

**Verification cycle:** Edit → `flutter test` → `dart analyze` → repeat until green

## Testing

- Mock via contract inheritance (no mockito): `class MockNetworkDriver implements NetworkDriver`
- MockNetworkDriver tracks: `lastMethod`, `lastUrl`, `lastData`, `lastHeaders`
- Reset state in setUp: `MagicApp.reset()`, `Magic.flush()`, bind mocks, configure guards
- Tests mirror `lib/src/` structure in `test/`
- CLI tests in `test/cli/commands/`
- Payload verification: `expect(mockDriver.lastData['field'], expectedValue)`
- State verification: `expect(controller.isSuccess, isTrue)`

## Key Gotchas

| Mistake | Fix |
|---------|-----|
| Missing `Auth.restore()` after login | Always call `Auth.restore()` after successful login — user model is incomplete without it |
| Single-level two-factor check | Check BOTH `response['two_factor']` and `response['data']['two_factor']` |
| Wrong identity mode precedence | Phone takes precedence when both enabled; use `_applyIdentityToPayload()` helper |
| Direct `context.go()` in controllers | Use `navigateTo(path)` from `NavigatesRoutes` mixin — navigator may not be mounted |
| Feature-gated route without check | Routes throw `StateError` if called when feature is disabled — always check config first |
| Theme access in `boot()` | Requires `addPostFrameCallback` — navigator context unavailable during boot phase |
| Manual `refreshNotifier` poke | `MagicStarterAppLayout.refreshNotifier` triggers layout rebuilds on auth change — don't poke manually |
| Missing ValueNotifier disposal | Controllers with `ValueNotifier` fields must have `notifier.dispose()` in tearDown |
| Unnormalized notification keys | `NotificationController._normalizeMap()` is critical — backend returns mixed-case keys |
| `MagicStarterCard` title padding in `noPadding` mode | When `noPadding: true`, title gets `px-6 pt-6 pb-3` — do NOT add extra padding around it manually |
| `CardVariant` import | `CardVariant` is exported from the main barrel; import `package:magic_starter/magic_starter.dart` — no direct widget file import needed |

## Skills & Extensions

- `fluttersdk:magic-framework` — Magic Framework patterns: facades, service providers, IoC, Eloquent ORM, controllers, routing. Use for ANY code touching Magic APIs.
- `fluttersdk:magic-starter-widgets` — Reusable standalone widgets exported from `package:magic_starter/magic_starter.dart`: `MagicStarterCard` (with `CardVariant` enum: surface/inset/elevated), `MagicStarterPageHeader` (title, subtitle, leading, actions), `MagicStarterPasswordConfirmDialog`, `MagicStarterTwoFactorModal`. All accept plain callbacks — no internal controller coupling required.

## CI

- `ci.yml`: push/PR → `flutter pub get` → `flutter analyze --no-fatal-infos` → `dart format --set-exit-if-changed` → `flutter test --coverage` → codecov upload
