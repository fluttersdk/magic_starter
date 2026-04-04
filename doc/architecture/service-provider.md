# MagicStarterServiceProvider

- [Introduction](#introduction)
- [Two-Phase Bootstrap](#two-phase-bootstrap)
- [Register Phase](#register-phase)
- [Boot Phase](#boot-phase)
    - [Teams Feature Warning](#teams-feature-warning)
    - [Gate Abilities](#gate-abilities)
    - [Primary Color Fallback](#primary-color-fallback)
- [IoC Bindings](#ioc-bindings)
- [Related](#related)

<a name="introduction"></a>
## Introduction

`MagicStarterServiceProvider` is the bootstrap entry point for the magic_starter plugin. It binds the `MagicStarterManager` singleton into the IoC container, registers an `AuthRestored` event listener for team-switch reloads, defines 9 Gate abilities for profile section visibility, and sets up a primary color fallback for Wind UI.

The provider lives at `lib/src/providers/magic_starter_service_provider.dart` and extends `ServiceProvider` from `package:magic/magic.dart`.

<a name="two-phase-bootstrap"></a>
## Two-Phase Bootstrap

The Magic Framework calls providers in two ordered phases:

| Phase | Method | Constraint |
|-------|--------|------------|
| 1 | `register()` | Sync. Only bind into the container — no other service may be accessed yet. |
| 2 | `boot()` | Async. All providers have been registered. Safe to resolve, configure, and wire services. |

Splitting into two phases guarantees that when `boot()` runs, every binding registered by every other provider is already resolvable from the container.

<a name="register-phase"></a>
## Register Phase

```dart
@override
void register() {
  app.singleton('magic_starter', () => MagicStarterManager());

  EventDispatcher.instance
      .register(AuthRestored, [() => _ReloadOnAuthRestored()]);
}
```

Two things happen here:

1. **Manager singleton** — binds `MagicStarterManager` under the key `'magic_starter'`. The manager's constructor calls `registerDefaultViews()`, so all default views and layouts are immediately available.

2. **Auth restored listener** — registers `_ReloadOnAuthRestored`, which calls `Magic.reload()` when `AuthRestored` fires. This triggers a soft app reload after team switches so all team-scoped data refreshes.

> [!NOTE]
> The `MagicStarterManager` constructor calls `registerDefaultViews()` at instantiation time. If you want to override views, register them in your `AppServiceProvider.boot()` — the "register if absent" strategy in `registerDefaultViews()` will skip any keys you have already set.

<a name="boot-phase"></a>
## Boot Phase

`boot()` is `async`. It checks the teams feature configuration, registers Gate abilities, and sets up the primary color fallback.

```dart
@override
Future<void> boot() async {
  // 1. Teams feature warning
  // 2. Gate abilities
  // 3. Primary color fallback
}
```

<a name="teams-feature-warning"></a>
### Teams Feature Warning

If `magic_starter.features.teams` is enabled in config but no team resolver has been registered, the provider emits a warning:

```dart
final teamsEnabled =
    Config.get<bool>('magic_starter.features.teams', false) ?? false;
if (teamsEnabled && MagicStarter.manager.teamResolver == null) {
  Log.warning(
    '[MagicStarter] Teams feature is enabled but no team resolver '
    'is configured. Call MagicStarter.useTeamResolver() in your AppServiceProvider.',
  );
}
```

> [!TIP]
> Call `MagicStarter.useTeamResolver()` in your `AppServiceProvider.boot()` before this provider boots. Order your providers so `AppServiceProvider` runs first, or register the resolver in `register()` if ordering is not guaranteed.

<a name="gate-abilities"></a>
### Gate Abilities

The provider registers 9 Gate abilities that control profile section visibility. Each ability follows the same pattern: grant access when the user is **not** a guest (`is_guest != true`).

```dart
bool isNotGuest(Model user, [dynamic _]) {
  return user.get<bool>('is_guest') != true;
}

Gate.define('starter.update-profile-photo', isNotGuest);
Gate.define('starter.update-email', isNotGuest);
// ...
```

| Ability | Controls |
|---------|----------|
| `starter.update-profile-photo` | Profile photo upload/remove section |
| `starter.update-email` | Email field in profile information |
| `starter.update-phone` | Phone and country code in extended profile |
| `starter.update-password` | Password change section |
| `starter.verify-email` | Email verification banner |
| `starter.manage-two-factor` | Two-factor authentication section |
| `starter.manage-newsletter` | Newsletter preferences section |
| `starter.logout-sessions` | Logout/revoke buttons in browser sessions |
| `starter.delete-account` | Account deletion section |

Host apps can override any ability by calling `Gate.define()` with the same key after this provider boots:

```dart
// In AppServiceProvider.boot()
Gate.define('starter.delete-account', (user, [_]) => false); // disable for all
```

<a name="primary-color-fallback"></a>
### Primary Color Fallback

If the host app has not defined a `primary` color in the Wind UI theme, the provider registers `indigo` as the fallback. Because `boot()` runs during `Magic.init()` — before `runApp()` builds the widget tree — the check is deferred to a post-frame callback:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  final context = MagicRouter.instance.navigatorKey.currentContext;
  if (context == null) return;

  final windTheme = WindTheme.of(context);
  if (!windTheme.data.isValidColor('primary')) {
    windTheme.updateTheme(
      colors: {'primary': windTheme.data.colors['indigo']!},
    );
  }
});
```

> [!NOTE]
> The fallback only applies when no `primary` color exists. If your app defines `primary` in `WindThemeData.colors`, this callback is a no-op.

<a name="ioc-bindings"></a>
## IoC Bindings

The manager can be resolved from the container in two ways:

```dart
// Via facade (preferred)
final manager = MagicStarter.manager;

// Via IoC directly
final manager = Magic.make<MagicStarterManager>('magic_starter');
```

Add the provider to the `providers` list in your app's kernel:

```dart
import 'package:magic_starter/magic_starter.dart';

Map<String, dynamic> get appConfig => {
  'app': {
    'providers': [
      // ... other providers
      (app) => MagicStarterServiceProvider(app),
    ],
  },
  'magic_starter': {
    'features': {
      'teams': true,
      'two_factor': true,
      'notifications': true,
      // ... other feature flags
    },
  },
};
```

> [!TIP]
> For guidance on registering your own controllers and state classes in a consumer app, see [Controllers & State Registration](controllers.md).

<a name="related"></a>
## Related

- [MagicStarterManager](https://magic.fluttersdk.com/packages/starter/architecture/manager) — central singleton holding all customization registrations
- [View Registry](https://magic.fluttersdk.com/packages/starter/architecture/view-registry) — string-keyed view factory for overridable UI
- [Controllers & State Registration](https://magic.fluttersdk.com/packages/starter/architecture/controllers) — lazy singleton pattern, consumer app state registration guide
- [Magic Framework — Service Providers](https://magic.fluttersdk.com/getting-started/service-providers) — two-phase lifecycle reference
- [Magic Framework — Gate](https://magic.fluttersdk.com/getting-started/gate) — authorization abilities reference
