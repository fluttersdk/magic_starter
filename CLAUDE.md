# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Commands

| Command | Description |
|---------|-------------|
| `dart test` | Run all tests (37 files, 543 cases) |
| `dart test test/http/controllers/` | Run controller tests only |
| `dart test --name "pattern"` | Run tests matching pattern |
| `dart analyze` | Static analysis (flutter_lints ^6.0) |
| `dart format .` | Format Dart code |
| `dart fix --apply` | Auto-fix lint issues |

## Architecture

```
lib/
├── magic_starter.dart              # Public API — all exports
├── src/
│   ├── magic_starter_manager.dart  # Singleton registry: user model, team resolver, nav, views
│   ├── configuration/              # Feature flags (all default false, opt-in)
│   ├── providers/                  # IoC registration, Gate abilities, boot logic
│   ├── facades/                    # Static API: MagicStarter.useUserModel(), .view.make()
│   ├── http/controllers/           # MagicController + mixins, thin wrappers around API
│   │   └── concerns/              # Shared mixins (NavigatesRoutes)
│   ├── routes/                     # Per-module route registration (feature-gated)
│   ├── ui/
│   │   ├── layouts/               # AppLayout (authenticated), GuestLayout (auth pages)
│   │   ├── views/                 # auth/, profile/, teams/, notifications/
│   │   └── widgets/               # Reusable components (Wind UI / Tailwind-like)
│   ├── models/                     # AuthUser, Team, NavItem
│   └── cli/                        # install, configure, doctor, publish, uninstall
├── config/                         # Laravel-bound config stub
```

Depends on: `magic`, `magic_cli`, `magic_notifications` (internal packages).
SDK: Dart >=3.6.0, Flutter >=3.27.0.

## Key Files

- `lib/src/magic_starter_manager.dart` — Central singleton holding all customization registrations
- `lib/src/configuration/magic_starter_config.dart` — Feature flag queries and route path builders
- `lib/src/providers/magic_starter_service_provider.dart` — IoC boot: registers manager, defines Gate abilities
- `lib/src/ui/magic_starter_view_registry.dart` — String-keyed view builders, host app can override
- `lib/src/http/controllers/concerns/navigates_routes.dart` — Safe navigation mixin for controllers

## Code Style

- Controllers: `MagicController` + `MagicStateMixin<T>` + `ValidatesRequests` + `NavigatesRoutes`
- Static `.instance` getter via `Magic.findOrPut(ControllerName.new)` — no manual instantiation
- State flow: `setLoading()` → `setSuccess()`/`setError()` → `notifyListeners()`
- Guard `_isSubmitting` with early return to prevent double-submit
- 73-char ASCII comment dividers for section grouping in controllers
- Wind UI classes for styling (`WDiv(className: 'flex flex-col gap-4 p-6')`) — no Material widgets in layouts
- Views extend `MagicStatefulView<ControllerType>` — UI only, no business logic

## Testing

- `dart test` — mirrors source structure: `test/http/`, `test/ui/`, `test/models/`, `test/cli/`, `test/integration/`
- `setUp()`: reset `MagicApp.reset()`, `Magic.flush()`, bind mocks, configure guards
- `tearDown()`: dispose controller, `Auth.manager.forgetGuards()`, silent-catch `Notify.stopPolling()`
- Mock pattern: `MockNetworkDriver implements NetworkDriver` — intercept via `mockDriver.mockResponse()`
- Verify payloads via `mockDriver.lastData`, state via `controller.isSuccess`/`controller.hasErrors`

## Gotchas

- Always call `Auth.restore()` after successful login — without it, user model is incomplete
- Two-factor detection: check BOTH `response['two_factor']` and `response['data']['two_factor']`
- Identity modes (email/phone/both): phone takes precedence when both enabled; use `_applyIdentityToPayload()` helper
- Never use `context.go()` in controllers — navigator may not be mounted; use `NavigatesRoutes` mixin
- Feature-gated routes throw `StateError` if called when feature is disabled — always check config first
- Theme access in `boot()` requires `addPostFrameCallback` — navigator context unavailable during boot phase
- `MagicStarterAppLayout.refreshNotifier` triggers layout rebuilds on auth change — don't poke manually
