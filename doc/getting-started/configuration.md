# Configuration

- [Introduction](#introduction)
- [The Config File](#config-file)
- [Feature Toggles](#feature-toggles)
- [Route Customization](#route-customization)
- [Auth Identity Modes](#auth-identity-modes)
- [Locale & Timezone Defaults](#locale-timezone-defaults)
- [Accessing Values](#accessing-values)

<a name="introduction"></a>
## Introduction

The `magic_starter` plugin is configured via a single Dart file at `lib/config/magic_starter.dart` in your consumer project. This file is generated automatically when you run the install command, and contains all feature toggles, route prefixes, auth identity settings, and locale defaults your app needs.

```bash
dart run magic_starter:install
```

The install command scaffolds `lib/config/magic_starter.dart` with all features defaulting to `false`. Enable only the features your app requires — each toggle controls route registration, UI visibility, and controller behaviour.

<a name="config-file"></a>
## The Config File

The generated `lib/config/magic_starter.dart` exports a single top-level getter that returns a nested `Map<String, dynamic>`:

```dart
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

Register it with `Magic.init()` alongside your other config factories:

```dart
await Magic.init(
  configFactories: [
    () => appConfig,
    () => magicStarterConfig,
  ],
);
```

> [!NOTE]
> All keys under `'magic_starter'` are accessible at runtime via `Config.get('magic_starter.<key>')` using dot notation. The `MagicStarterServiceProvider` reads from this namespace during the boot phase.

<a name="feature-toggles"></a>
## Feature Toggles

Every feature defaults to `false` and must be explicitly enabled. Each toggle controls whether routes are registered, UI sections are rendered, and controller logic is activated.

| Key | Default | Description |
|-----|---------|-------------|
| `teams` | `false` | Team creation, management, member invitations, and team switching. |
| `registration` | `false` | User registration screen and route. |
| `extended_profile` | `false` | Additional profile fields: phone, timezone, and language preferences. |
| `profile_photos` | `false` | Profile photo upload and removal in the profile settings. |
| `social_login` | `false` | Social/OAuth login buttons on the auth screens. |
| `two_factor` | `false` | Two-factor authentication setup, challenge screen, and recovery codes. |
| `sessions` | `false` | Browser sessions list with logout/revoke capability. |
| `phone_otp` | `false` | Phone-based OTP authentication flow (send code, verify). |
| `newsletter` | `false` | Newsletter subscribe/unsubscribe toggle in the profile. |
| `notifications` | `false` | In-app notification list, unread badge, and preferences screen. |
| `email_verification` | `false` | Email verification banner and resend verification flow. |
| `guest_auth` | `false` | Guest-mode authentication screens (login, register, forgot password, reset). |
| `timezones` | `false` | Timezone selection with debounced async API search. |

To enable features, set their values to `true` in `lib/config/magic_starter.dart`:

```dart
'features': {
  'teams': true,
  'registration': true,
  'notifications': true,
  // ... remaining features stay false
},
```

> [!TIP]
> Feature-gated routes throw a `StateError` if you attempt to navigate to them when their feature is disabled. Always check the config before building navigation links — use `MagicStarterConfig.hasTeamFeatures()` and similar query methods.

<a name="route-customization"></a>
## Route Customization

The `routes` block controls all URL paths registered by Magic Starter. Change these values to match your app's URL structure:

```dart
'routes': {
  'home': '/',
  'login': '/auth/login',
  'auth_prefix': '/auth',
  'teams_prefix': '/teams',
  'profile_prefix': '/settings',
  'notifications_prefix': '/notifications',
},
```

| Key | Default | Description |
|-----|---------|-------------|
| `home` | `'/'` | Redirect target after successful login. |
| `login` | `'/auth/login'` | Login screen path; used by `RedirectIfAuthenticated` middleware. |
| `auth_prefix` | `'/auth'` | Prefix for all auth routes (login, register, forgot, reset, two-factor challenge). |
| `teams_prefix` | `'/teams'` | Prefix for team routes (create, settings). |
| `profile_prefix` | `'/settings'` | Prefix for profile routes (profile, notifications preferences). |
| `notifications_prefix` | `'/notifications'` | Prefix for the notifications list page. |

The config class also provides computed route paths built from these prefixes:

```dart
MagicStarterConfig.teamCreateRoute();          // '/teams/create'
MagicStarterConfig.teamSettingsRoute();         // '/teams/settings'
MagicStarterConfig.profileRoute();              // '/settings/profile'
MagicStarterConfig.notificationsRoute();        // '/notifications'
MagicStarterConfig.notificationPreferencesRoute(); // '/settings/notifications'
MagicStarterConfig.twoFactorChallengeRoute();   // '/auth/two-factor-challenge'
```

> [!NOTE]
> Changing a prefix automatically updates all computed routes that depend on it. For example, setting `profile_prefix` to `'/account'` changes `profileRoute()` to `'/account/profile'` and `notificationPreferencesRoute()` to `'/account/notifications'`.

<a name="auth-identity-modes"></a>
## Auth Identity Modes

The `auth` block controls which identity fields are shown on login and registration forms:

```dart
'auth': {
  'email': true,
  'phone': false,
},
```

There are three supported modes:

**Email only** (default) — users authenticate with email and password:

```dart
'auth': {
  'email': true,
  'phone': false,
},
```

**Phone only** — users authenticate with phone number:

```dart
'auth': {
  'email': false,
  'phone': true,
},
```

**Both** — both fields are shown, but phone takes precedence in the login payload when both are provided:

```dart
'auth': {
  'email': true,
  'phone': true,
},
```

> [!TIP]
> When both identity modes are enabled, the `_applyIdentityToPayload()` helper in auth controllers gives phone precedence. If the user fills in both fields, the phone value is sent as the primary identifier.

Access identity mode at runtime:

```dart
final emailEnabled = MagicStarterConfig.emailIdentity(); // true
final phoneEnabled = MagicStarterConfig.phoneIdentity(); // false
```

<a name="locale-timezone-defaults"></a>
## Locale & Timezone Defaults

The `defaults` and `supported_locales` sections configure localisation behaviour:

```dart
'defaults': {
  'locale': 'en',
  'timezone': 'UTC',
},
'supported_locales': [
  'en',
  'tr',
],
```

| Key | Default | Description |
|-----|---------|-------------|
| `defaults.locale` | `'en'` | Default locale for new users. |
| `defaults.timezone` | `'UTC'` | Default timezone for new users. |
| `supported_locales` | `['en', 'tr']` | Locales available in the language selector (when `extended_profile` is enabled). |

Access these values at runtime:

```dart
final locale = MagicStarterConfig.defaultLocale();       // 'en'
final timezone = MagicStarterConfig.defaultTimezone();    // 'UTC'
final locales = MagicStarterConfig.supportedLocales();    // ['en', 'tr']
```

The `legal` block provides optional links displayed on auth screens:

```dart
'legal': {
  'terms_url': 'https://example.com/terms',
  'privacy_url': 'https://example.com/privacy',
},
```

> [!NOTE]
> Legal links default to `null`. When set, they render as tappable links on the registration screen. Use `MagicStarterConfig.hasLegalLinks()` to check if at least one legal link is configured.

<a name="accessing-values"></a>
## Accessing Values

At runtime, all values are accessible in two ways.

**Via `MagicStarterConfig` static methods** — the recommended approach with type safety and defaults:

```dart
// Feature checks
final teamsEnabled = MagicStarterConfig.hasTeamFeatures();
final registrationEnabled = MagicStarterConfig.hasRegistrationFeatures();
final twoFactorEnabled = MagicStarterConfig.hasTwoFactorFeatures();

// Route paths
final loginPath = MagicStarterConfig.loginRoute();
final profilePath = MagicStarterConfig.profileRoute();

// Identity
final emailAuth = MagicStarterConfig.emailIdentity();
final phoneAuth = MagicStarterConfig.phoneIdentity();

// Defaults
final locale = MagicStarterConfig.defaultLocale();
final timezone = MagicStarterConfig.defaultTimezone();

// Legal
final termsUrl = MagicStarterConfig.termsUrl();
final hasLegal = MagicStarterConfig.hasLegalLinks();
```

**Via `Config.get()` dot notation** — for dynamic access or when you need the raw value:

```dart
final teamsEnabled = Config.get<bool>('magic_starter.features.teams', false);
final authPrefix = Config.get<String>('magic_starter.routes.auth_prefix', '/auth');
final termsUrl = Config.get<String?>('magic_starter.legal.terms_url', null);
```

> [!TIP]
> Prefer the `MagicStarterConfig` static methods over raw `Config.get()` calls. They encapsulate default values and provide self-documenting method names that are easier to find with IDE autocompletion.
