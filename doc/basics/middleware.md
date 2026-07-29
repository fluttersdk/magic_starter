# Middleware

- [Introduction](#introduction)
- [Registering the Aliases](#registering-the-aliases)
- [EnsureAuthenticated](#ensureauthenticated)
- [RedirectIfAuthenticated](#redirectifauthenticated)
- [Which Routes Expect Which Alias](#which-routes-expect-which-alias)
- [Related](#related)

<a name="introduction"></a>
## Introduction

Magic Starter ships two route guards: `EnsureAuthenticated` (blocks a signed-out visitor from a protected route) and `RedirectIfAuthenticated` (blocks a signed-in visitor from a guest-only page, such as the login form). Both extend `MagicMiddleware` and override `redirectTarget`, so the redirect resolves inside the router's `redirect` callback before any page builds; the destination view mounts exactly once instead of building the gated page and then remounting.

<a name="registering-the-aliases"></a>
## Registering the Aliases

Register them once in your app's `Kernel`, using the exact alias names `'auth'` and `'guest'` that the starter's own route groups already reference:

```dart
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void registerMiddleware() {
  Kernel.registerAll({
    'auth': () => EnsureAuthenticated(),
    'guest': () => RedirectIfAuthenticated(),
  });
}
```

Call `registerMiddleware()` once from your app's bootstrap, before any route group that references `'auth'` or `'guest'` resolves.

<a name="ensureauthenticated"></a>
## EnsureAuthenticated

Redirects an unauthenticated visitor to `MagicStarterConfig.loginRoute()`. It guards the login route itself so the redirect can never loop back into itself: `go_router` raises past five successive redirects.

```dart
MagicRoute.group(
  middleware: ['auth'],
  routes: () {
    // protected routes
  },
);
```

<a name="redirectifauthenticated"></a>
## RedirectIfAuthenticated

Redirects an already authenticated visitor to `MagicStarterConfig.homeRoute()`. It guards the home route itself for the same reason: a signed-in visitor landing back on home must not be redirected to home again.

```dart
MagicRoute.group(
  middleware: ['guest'],
  routes: () {
    // auth pages: login, register, forgot/reset password
  },
);
```

<a name="which-routes-expect-which-alias"></a>
## Which Routes Expect Which Alias

The starter's own route groups already assume these aliases are registered:

| Route group | Alias | File |
|-------------|-------|------|
| Auth (login, register, forgot/reset password, two-factor challenge, OTP) | `guest` | `lib/src/routes/auth_routes.dart` |
| Profile / settings | `auth` | `lib/src/routes/profile_routes.dart` |
| Teams | `auth` | `lib/src/routes/team_routes.dart` |
| Notifications | `auth` | `lib/src/routes/notification_routes.dart` |

If your app never calls `registerMiddleware()`, these groups resolve to no guard at all: `Kernel.resolve()` returns `null` for an unregistered alias, and an unrecognized middleware is silently dropped from the chain rather than throwing.

<a name="related"></a>
## Related

- [Authentication](https://magic.fluttersdk.com/packages/starter/basics/authentication): `Auth.check()`, login, logout, and the routes these guards protect
- [Session Scope](https://magic.fluttersdk.com/packages/starter/basics/session-scope): what resets when `Auth.stateNotifier` changes identity
