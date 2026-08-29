# Installation

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installing the Package](#installing-the-package)
- [Running the Install Command](#running-the-install-command)
- [Registering the Service Provider](#registering-the-service-provider)
- [Injecting the Config Factory](#injecting-the-config-factory)
- [Bootstrapping the Starter](#bootstrapping-the-starter)
- [Configuration Reference](#configuration-reference)
- [Next Steps](#next-steps)

<a name="introduction"></a>
## Introduction

`magic_starter` is a starter kit for the Magic Framework that provides auth screens, profile management, team support, notifications, and more — all behind 13 opt-in feature toggles. It follows the same ServiceProvider + config pattern used throughout the framework, so it wires up in exactly the same way as every other Magic plugin.

Under the hood the package provides 7 controllers, overridable views via a string-keyed view registry, 9 Gate abilities for section visibility, and Wind UI-based layouts. Every feature defaults to `false` — you enable only what your app needs.

<a name="requirements"></a>
## Requirements

- **Dart SDK**: 3.6.0 or higher
- **Flutter**: 3.27.0 or higher
- **Magic Framework** installed and bootstrapped (`lib/config/app.dart` present)

<a name="installing-the-package"></a>
## Installing the Package

Add `magic_starter` to your Flutter project:

```bash
flutter pub add magic_starter
```

Or add it manually to `pubspec.yaml`:

```yaml
dependencies:
  magic_starter: ^0.0.1-alpha.22
```

Then fetch dependencies:

```bash
flutter pub get
```

<a name="running-the-install-command"></a>
## Running the Install Command

Magic Starter ships its own CLI command. Run it from your project root to scaffold all required files and inject the provider automatically:

```bash
dart run magic_starter:install
```

The command performs the following steps:

1. **Validates** that `lib/config/app.dart` exists (Magic must be installed first).
2. **Prompts** for which features to enable (interactive mode).
3. **Creates** `lib/config/magic_starter.dart` with all 13 feature toggles set to your selections.
4. **Injects** `MagicStarterServiceProvider` into the `providers` list in `lib/config/app.dart`.
5. **Injects** `() => magicStarterConfig` into the `configFactories` list in `lib/main.dart`.
6. **Creates** middleware files (`EnsureAuthenticated`, `RedirectIfAuthenticated`).
7. **Injects** middleware aliases into `lib/config/kernel.dart`.
8. **Injects** starter route registrations into `RouteServiceProvider`.
9. **Scaffolds** `AppServiceProvider`, `User` model, `Dashboard` view, app routes, and translation files.
10. **Scaffolds** `Team` model (only when the teams feature is enabled).
11. **Runs** `dart format .` on the host project.

> [!NOTE]
> If `lib/config/magic_starter.dart` already exists the command skips the write and prints a warning. Pass `--force` to overwrite existing generated files.

```bash
dart run magic_starter:install --force
```

For CI pipelines or scripted installs, use non-interactive mode with a comma-separated list of features:

```bash
dart run magic_starter:install --non-interactive --features teams,registration,notifications
```

<a name="registering-the-service-provider"></a>
## Registering the Service Provider

If you ran `dart run magic_starter:install`, the provider was already injected. The relevant section of `lib/config/app.dart` will look like this:

```dart
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart'; // injected by install

final appConfig = {
  'app': {
    'name': Env.get('APP_NAME', 'My App'),
    'providers': [
      (app) => RouteServiceProvider(app),
      (app) => AppServiceProvider(app),
      (app) => MagicStarterServiceProvider(app), // injected by install
    ],
  },
};
```

> [!TIP]
> `MagicStarterServiceProvider` registers `MagicStarterManager` as a singleton under the `'magic_starter'` key in the IoC container and defines 9 Gate abilities for profile section visibility. Host apps can override any ability by re-defining it with `Gate.define()` after this provider boots.

<a name="injecting-the-config-factory"></a>
## Injecting the Config Factory

The install command also adds the config factory to `Magic.init()` in `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'config/app.dart';
import 'config/magic_starter.dart'; // injected by install

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => magicStarterConfig, // injected by install
    ],
  );

  runApp(MagicApplication(title: 'My App'));
}
```

<a name="bootstrapping-the-starter"></a>
## Bootstrapping the Starter

Registering the provider is not enough. The starter also needs to know four host-owned things: how to build **your** user model, how to log out, which locales to offer, and (when the teams feature is enabled) how to read and switch teams. Register all of them with a single required call, `MagicStarter.bootstrap()`, from your `AppServiceProvider.boot()`:

```dart
class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    MagicStarter.bootstrap(
      userFactory: (data) => User.fromMap(data),
      onLogout: () async {
        await Auth.logout();
        MagicRoute.to('/auth/login');
      },
      locales: {
        'en': 'English',
        'tr': 'Türkçe',
      },
    );
  }
}
```

That is the complete setup for a teamless app. When `magic_starter.features.teams` is `true`, pass the three team callbacks as well:

```dart
MagicStarter.bootstrap(
  userFactory: (data) => User.fromMap(data),
  onLogout: () async => Auth.logout(),
  locales: {
    'en': 'English',
    'tr': 'Türkçe',
  },
  currentTeam: () => User.current.currentTeam?.toMagicStarterTeam(),
  allTeams: () =>
      User.current.allTeams.map((t) => t.toMagicStarterTeam()).toList(),
  onSwitch: (id) => MagicStarterTeamController.instance.switchTeam(id),
);
```

The team callbacks are a cohesive group: pass all three or none.

| Situation | Result |
|-----------|--------|
| Teams disabled, team callbacks omitted | Valid. No team resolver is registered and no team UI renders. |
| Teams enabled, all three callbacks passed | Valid. The team selector, team switching, and team settings work. |
| Teams enabled, team callbacks omitted | Throws a `StateError` naming the missing call and the config flag. |
| Only some of the three callbacks passed | Throws an `ArgumentError`; the manager is left untouched. |

> [!WARNING]
> Do not skip `userFactory`. Without it the starter falls back to its own `MagicStarterAuthUser` type, so every screen keeps rendering while silently reading the wrong user model. `bootstrap()` makes that omission impossible: the parameter is required.

The individual setters remain available for partial or advanced setup, and any of them can be called after `bootstrap()` to override what it registered:

```dart
// Register the team resolver later, once your own team store is warm.
MagicStarter.useTeamResolver(
  currentTeam: () => TeamStore.instance.current?.toMagicStarterTeam(),
  allTeams: () => TeamStore.instance.all,
  onSwitch: (id) => TeamStore.instance.switchTo(id),
);
```

| Setter | Covered by `bootstrap()` |
|--------|--------------------------|
| `MagicStarter.useUserModel()` | Yes, as the required `userFactory` argument. |
| `MagicStarter.useLogout()` | Yes, as the required `onLogout` argument. |
| `MagicStarter.useLocaleOptions()` | Yes, as the required `locales` argument. |
| `MagicStarter.useTeamResolver()` | Yes, as the optional `currentTeam` / `allTeams` / `onSwitch` group. |

> [!NOTE]
> `bootstrap()` covers the identity contract only. Optional presentation setters (`useNavigation()`, `useTheme()`, `useWindTheme()`, `useHeader()`, `useSocialLogin()`, and the per-surface theme setters) stay separate and are called alongside it.

<a name="configuration-reference"></a>
## Configuration Reference

The generated `lib/config/magic_starter.dart` looks like this out of the box (with all features defaulting to `false`):

```dart
// Magic Starter Configuration.
//
// This file is auto-generated by the magic_starter install command.
// Customize feature toggles and route prefixes as needed.

Map<String, dynamic> get magicStarterConfig => {
  'magic_starter': {
    'features': {
      'teams': false,
      'registration': false,
      'extended_profile': false,
      'profile_photos': false,
      'social_login': false,
      'two_factor': false,
      'sessions': false,
      'phone_otp': false,
      'newsletter': false,
      'notifications': false,
      'email_verification': false,
      'guest_auth': false,
      'timezones': false,
    },
    'auth': {
      'email': true,
      'phone': false,
    },
    'defaults': {
      'locale': 'en',
      'timezone': 'UTC',
    },
    'supported_locales': [
      'en',
      'tr',
    ],
    'routes': {
      'home': '/',
      'login': '/auth/login',
      'auth_prefix': '/auth',
      'teams_prefix': '/teams',
      'profile_prefix': '/settings',
      'notifications_prefix': '/notifications',
    },
    'legal': {
      'terms_url': null,
      'privacy_url': null,
    },
  },
};
```

> [!NOTE]
> All keys under `'magic_starter'` are accessible at runtime via `Config.get('magic_starter.<key>')` using dot notation. The `MagicStarterServiceProvider` reads from this namespace during the boot phase.

<a name="next-steps"></a>
## Next Steps

Now that the plugin is installed and wired up:

- **[Configuration](https://magic.fluttersdk.com/packages/starter/getting-started/configuration)** — Learn how to customise feature toggles, route prefixes, and auth identity modes.
- **[Views](https://magic.fluttersdk.com/packages/starter/basics/views)** — Override any screen using the string-keyed view registry.
- **[Controllers](https://magic.fluttersdk.com/packages/starter/basics/controllers)** — Understand the auth, profile, team, and notification controllers.
