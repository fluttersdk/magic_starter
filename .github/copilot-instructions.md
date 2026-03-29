# Magic Starter Plugin

Flutter starter kit for the Magic Framework. Pre-built Auth, Profile, Teams & Notifications — 13 opt-in features, every screen overridable via Wind UI.

**Dart:** >=3.6.0 · **Flutter:** >=3.27.0 · **Pure Dart** — no native platform code.

## Architecture

**Pattern**: ServiceProvider + Singleton Manager + Feature Flags + View Registry + Controller/View separation

```
lib/
├── magic_starter.dart              # Barrel export — 46 exports
└── src/
    ├── magic_starter_manager.dart  # Singleton registry
    ├── configuration/              # 13 feature toggles (all default false, opt-in)
    ├── providers/                  # IoC registration, 9 Gate abilities, boot logic
    ├── facades/                    # Static API: MagicStarter.useUserModel(), .view.make()
    ├── http/controllers/           # 7 controllers + NavigatesRoutes mixin
    │   └── concerns/              # Shared mixins
    ├── routes/                     # Per-module route registration (feature-gated)
    ├── models/                     # AuthUser, Team, NavItem
    ├── ui/
    │   ├── layouts/               # AppLayout (authenticated), GuestLayout (auth pages)
    │   ├── views/                 # auth/, profile/, teams/, notifications/
    │   └── widgets/               # 10 reusable Wind UI components
    └── cli/                        # install, configure, doctor, publish, uninstall
```

**Data flow:** App boot → `MagicStarterServiceProvider.register()` → binds manager + 9 Gate abilities → `boot()` → resolves config, registers default views → Feature-gated routes → Controllers handle HTTP via `Http.*` → Views render via `MagicStatefulView` + Wind UI

Depends on: `magic`, `magic_notifications` (internal packages).

## Key Gotchas

| Mistake | Fix |
|---------|-----|
| Missing `Auth.restore()` after login | Always call after successful login — user model is incomplete without it |
| Single-level two-factor check | Check BOTH `response['two_factor']` and `response['data']['two_factor']` |
| Wrong identity mode precedence | Phone takes precedence when both enabled; use `_applyIdentityToPayload()` |
| Direct `context.go()` in controllers | Use `navigateTo(path)` from `NavigatesRoutes` mixin |
| Feature-gated route without check | Routes throw `StateError` if feature is disabled — always check config |
| Theme access in `boot()` | Requires `addPostFrameCallback` — navigator context unavailable during boot |
| Manual `refreshNotifier` poke | Triggers layout rebuilds on auth change — don't poke manually |
| Missing ValueNotifier disposal | Controllers with `ValueNotifier` must have `notifier.dispose()` in tearDown |
| Hardcoding dialog classNames | All modal classNames from `MagicStarter.manager.modalTheme` — never hardcode |

## Conventions

- Wind UI exclusively — no Material widgets except `Icons.*` and `Dialog` shell
- Dark mode: always pair light/dark classes: `bg-white dark:bg-gray-800`
- Trailing commas on ALL multi-line argument lists
- Thin controllers, fat services — no business logic in views
- TDD: red-green-refactor cycle, no production code without failing test first
- Mock via contract inheritance (no mockito)

## Post-Change Checklist

1. **CHANGELOG.md** — Add entry under `[Unreleased]`
2. **README.md** — Update if features/API changed
3. **doc/** — Update relevant docs
