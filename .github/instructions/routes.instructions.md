---
name: 'Route Registration Rules'
description: 'Top-level function pattern, feature guards, view registry, middleware'
applyTo: 'lib/src/routes/**/*.dart'
---

# Route Registration

- Top-level function pattern: `void registerMagicStarter<Module>Routes(MagicRouter router)`
- Feature guard: check `MagicStarterConfig.has<Feature>Features()` before registering — throw `StateError` if disabled
- Route paths from config: `MagicStarterConfig.<module>Path()` — never hardcode paths
- Guest routes (login, register, forgot, reset): wrapped in `GuestLayout` via view registry
- Authenticated routes (profile, teams, notifications): wrapped in `AppLayout` via view registry
- View instantiation: `MagicStarter.view.make('auth.login')` — always through registry, never direct constructor
- Layout wrapping: `MagicStarter.view.makeLayout('guest', child: view)` — registry-based
- Route groups: use `router.group(prefix, (router) { ... })` for module-scoped paths
- Middleware: `EnsureAuthenticated` for protected routes, `RedirectIfAuthenticated` for guest routes
- Transition: `.transition(RouteTransition.none)` on auth routes — no animation between guest screens
- Conditional registration inside group closure: check `MagicStarterConfig.has*Features()` per route, not per group
