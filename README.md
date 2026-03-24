<p align="center">
  <img src="https://raw.githubusercontent.com/fluttersdk/magic/master/.github/magic-logo.svg" width="120" alt="Magic Logo" />
</p>

<h1 align="center">Magic Starter</h1>

<p align="center">
  <strong>Pre-built Auth, Profile, Teams & Notifications for the Magic Framework.</strong><br/>
  13 opt-in features — every screen overridable.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic_starter"><img src="https://img.shields.io/pub/v/magic_starter.svg" alt="pub.dev version" /></a>
  <a href="https://github.com/fluttersdk/magic_starter/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/fluttersdk/magic_starter/ci.yml?branch=main&label=CI" alt="CI Status" /></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" /></a>
  <a href="https://pub.dev/packages/magic_starter/score"><img src="https://img.shields.io/pub/points/magic_starter" alt="pub points" /></a>
  <a href="https://github.com/fluttersdk/magic_starter/stargazers"><img src="https://img.shields.io/github/stars/fluttersdk/magic_starter?style=flat" alt="GitHub Stars" /></a>
</p>

<p align="center">
  <a href="https://magic.fluttersdk.com/starter">Website</a> ·
  <a href="https://magic.fluttersdk.com/packages/starter/getting-started/installation">Docs</a> ·
  <a href="https://pub.dev/packages/magic_starter">pub.dev</a> ·
  <a href="https://github.com/fluttersdk/magic_starter/issues">Issues</a> ·
  <a href="https://github.com/fluttersdk/magic_starter/discussions">Discussions</a>
</p>

---

> **Alpha** — `magic_starter` is under active development. APIs may change between minor versions until `1.0.0`.

---

## Why Magic Starter?

Stop rebuilding authentication, profile management, and team features from scratch in every project. The same screens, the same API calls, the same state management — over and over.

**Magic Starter** gives you production-ready screens for auth, profile, teams, and notifications out of the box. Everything is config-driven with 13 opt-in feature toggles. Every view is overridable via the view registry — swap any screen or layout from your host app without touching the package.

> **Config-driven starter kit.** Enable only what you need. Override any screen. Ship faster.

---

## Features

| | Feature | Description |
|---|---------|-------------|
| :key: | **Authentication** | Login, register, forgot/reset password, remember me |
| :shield: | **Two-Factor Auth** | Enable/disable 2FA with QR code, OTP confirm, recovery codes |
| :bust_in_silhouette: | **Profile Management** | Photo upload, email/password change, email verification, sessions |
| :busts_in_silhouette: | **Teams** | Create, switch, invite members, manage roles |
| :bell: | **Notifications** | Real-time polling, mark read/unread, preference matrix |
| :iphone: | **OTP Login** | Phone-based guest authentication with send/verify flow |
| :art: | **Wind UI** | Tailwind-like className system — no Material widgets, dark mode built-in |
| :gear: | **13 Feature Toggles** | All opt-in, configure only what you need |
| :jigsaw: | **View Registry** | Override any screen or layout from the host app |
| :hammer_and_wrench: | **CLI Tools** | install, configure, doctor, publish, uninstall |

---

## Quick Start

### 1. Add the dependency

```yaml
dependencies:
  magic_starter: ^0.0.1
```

### 2. Install configuration

```bash
dart run magic_starter:install
```

This generates `lib/config/magic_starter.dart`, injects `MagicStarterServiceProvider` into `lib/config/app.dart`, and wires the `magicStarterConfig` factory into `lib/main.dart`.

### 3. Boot the provider

The `MagicStarterServiceProvider` is automatically registered during install. On app boot, it:

- Registers the singleton manager with all customization hooks
- Defines 9 Gate abilities for section visibility
- Registers feature-gated routes for auth, profile, teams, and notifications
- Boots the view registry with default screens and layouts

That's it — auth, profile, teams, and notifications are ready to use.

---

## Configuration

After running the install command, edit `lib/config/magic_starter.dart`:

```dart
Map<String, dynamic> get magicStarterConfig => {
  'magic_starter': {
    'features': {
      'teams': false,
      'profile_photos': false,
      'registration': true,
      'two_factor': false,
      'sessions': false,
      'guest_auth': false,
      'phone_otp': false,
      'newsletter': false,
      'email_verification': false,
      'extended_profile': true,
      'social_login': true,
      'notifications': true,
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
    'routes': {
      'home': '/',
      'login': '/auth/login',
      'auth_prefix': '/auth',
      'teams_prefix': '/teams',
      'profile_prefix': '/settings',
      'notifications_prefix': '/notifications',
    },
  },
};
```

All values are read at runtime via `ConfigRepository` — no hardcoded strings scattered across your codebase.

---

## Feature Toggles

All 13 features default to `false` (opt-in). Enable only what your app needs:

| Toggle | Description |
|--------|-------------|
| `teams` | Team creation, switching, member invitations, role management |
| `profile_photos` | Profile photo upload and display |
| `registration` | User registration screen and flow |
| `two_factor` | Two-factor authentication with QR code, OTP, and recovery codes |
| `sessions` | Active session listing and revocation |
| `guest_auth` | Guest-only authentication routes (login without account) |
| `phone_otp` | Phone-based OTP send/verify login flow |
| `newsletter` | Newsletter subscribe/unsubscribe toggle |
| `email_verification` | Email verification notice and resend flow |
| `extended_profile` | Extended profile fields: phone, timezone, language |
| `social_login` | Social login buttons (Google, Apple, etc.) |
| `notifications` | Real-time notification polling, read/unread, preference matrix |
| `timezones` | Timezone selection via async API search |

---

## View Customization

Override any screen or layout from your host app using the view registry:

```dart
MagicStarter.view.register('auth.login', (context) {
  return const MyCustomLoginView();
});

MagicStarter.view.register('layout.guest', (context, {required child}) {
  return MyCustomGuestLayout(child: child);
});
```

All views are resolved through `MagicStarter.view.make('auth.login')` — the registry always wins over defaults.

---

## CLI Tools

| Command | Description |
|---------|-------------|
| `dart run magic_starter:install` | Scaffold config, provider, and routes into your Magic project |
| `dart run magic_starter:configure` | Interactively toggle features and update config |
| `dart run magic_starter:doctor` | Verify installation, check dependencies, diagnose issues |
| `dart run magic_starter:publish` | Publish starter views and layouts for full customization |
| `dart run magic_starter:uninstall` | Remove starter config, provider, and routes from your project |

---

## Architecture

```
App launch → MagicStarterServiceProvider.boot()
  → registers MagicStarterManager singleton
  → defines 9 Gate abilities (starter.profile, starter.teams, etc.)
  → reads feature toggles via ConfigRepository
  → registers feature-gated routes (auth, profile, teams, notifications)
  → boots view registry with default screens and layouts
  → views resolve controllers via Magic.findOrPut()
  → controllers use MagicStateMixin for state flow
  → Wind UI renders all screens — no Material widgets
```

**Key patterns:**

| Pattern | Implementation |
|---------|---------------|
| Singleton Manager | `MagicStarterManager` — central customization registry |
| View Registry | `MagicStarterViewRegistry` — string-keyed view builders, host app overrides |
| Feature Toggles | `MagicStarterConfig` — 13 opt-in flags via `ConfigRepository` |
| Service Provider | Two-phase bootstrap: `register()` (sync) → `boot()` (async) |
| IoC Container | All bindings via `Magic.singleton()` / `Magic.findOrPut()` |

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](https://magic.fluttersdk.com/packages/starter/getting-started/installation) | Adding the package and running the installer |
| [Configuration](https://magic.fluttersdk.com/packages/starter/getting-started/configuration) | Config file reference and feature toggles |
| [Authentication](https://magic.fluttersdk.com/packages/starter/basics/authentication) | Login, register, forgot/reset password, 2FA, OTP |
| [Profile](https://magic.fluttersdk.com/packages/starter/basics/profile) | Profile management, photo upload, sessions |
| [Teams](https://magic.fluttersdk.com/packages/starter/basics/teams) | Team creation, switching, invitations, roles |
| [Notifications](https://magic.fluttersdk.com/packages/starter/basics/notifications) | Real-time polling, preferences, read/unread |
| [Views & Layouts](https://magic.fluttersdk.com/packages/starter/basics/views-and-layouts) | View registry, layout system, overriding screens |
| [CLI Tools](https://magic.fluttersdk.com/packages/starter/basics/cli) | Install, configure, doctor, publish, uninstall |
| [Manager](https://magic.fluttersdk.com/packages/starter/architecture/manager) | Singleton manager and customization hooks |
| [Service Provider](https://magic.fluttersdk.com/packages/starter/architecture/service-provider) | Bootstrap lifecycle, Gate abilities, IoC bindings |
| [View Registry](https://magic.fluttersdk.com/packages/starter/architecture/view-registry) | String-keyed builders and host app overrides |

---

## Contributing

Contributions are welcome! Please see the [issues page](https://github.com/fluttersdk/magic_starter/issues) for open tasks or to report bugs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests following the [TDD flow](#) — red, green, refactor
4. Ensure all checks pass: `flutter test`, `dart analyze`, `dart format .`
5. Submit a pull request

---

## License

Magic Starter is open-sourced software licensed under the [MIT License](LICENSE).

---

<p align="center">
  Built with care by <a href="https://github.com/fluttersdk">FlutterSDK</a><br/>
  <sub>If Magic Starter helps your project, consider giving it a <a href="https://github.com/fluttersdk/magic_starter">star on GitHub</a>.</sub>
</p>
