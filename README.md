<p align="center">
  <img src="https://raw.githubusercontent.com/fluttersdk/magic/master/.github/magic-logo.svg" width="120" alt="Magic Logo" />
</p>

<h1 align="center">Magic Starter</h1>

<p align="center">
  <strong>Pre-built Auth, Profile, Teams & Notifications for the Magic Framework.</strong><br/>
  14 opt-in features — every screen overridable.
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

**Magic Starter** gives you production-ready screens for auth, profile, teams, and notifications out of the box. Everything is config-driven with 14 opt-in feature toggles. Every view is overridable via the view registry — swap any screen or layout from your host app without touching the package.

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
| :package: | **Design-System Components** | 39 atomic components (MSButton, MSInput, MSBadge, MSDialog, MSToast, MSTabs, MSAccordion, MSDataTable, and more) plus `MagicStarterTokens` semantic alias layer |
| :gear: | **14 Feature Toggles** | All opt-in, configure only what you need |
| :jigsaw: | **View Registry** | Override any screen or layout from the host app |
| :hammer_and_wrench: | **CLI Tools** | install, configure, doctor, publish, uninstall |

---

## Quick Start

### 1. Add the dependency

```yaml
dependencies:
  magic_starter: ^0.0.1-alpha.22
```

### 2. Install configuration

```bash
dart run <app>:artisan starter:install
```

This generates `lib/config/magic_starter.dart`, injects `MagicStarterServiceProvider` into `lib/config/app.dart`, and wires the `magicStarterConfig` factory into `lib/main.dart`.

(If `magic_starter` is not yet registered as a provider in your host app, register `StarterArtisanProvider` in your app's `artisan.providers` list first.)

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
      'billing': false,
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

All 14 features default to `false` (opt-in). Enable only what your app needs:

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
| `billing` | Subscription and billing screen over `magic_payments`. Also needs `billing.web_origin`, an absolute url Stripe can return to |

---

## View Customization

Override any screen or layout from your host app using the view registry:

```dart
MagicStarter.view.register('auth.login', () {
  return const MyCustomLoginView();
});

MagicStarter.view.registerLayout('layout.guest', (child) {
  return MyCustomGuestLayout(child: child);
});
```

All views are resolved through `MagicStarter.view.make('auth.login')` — the registry always wins over defaults.

### Layout Customization

```dart
// Custom header — replaces the default mobile header
MagicStarter.useHeader((context, isDesktop) {
  return MyCustomHeader(showMenuButton: !isDesktop);
});

// Sidebar footer — custom widget between nav items and user menu
MagicStarter.useSidebarFooter((context) {
  return MyVersionBadge();
});
```

---

## Design-System Components

Magic Starter ships a full atomic design-system component library exported from `package:magic_starter/magic_starter.dart`. Every component lives in a canonical 4-file atomic folder (`<name>.dart`, `<name>.recipe.dart`, `<name>.preview.dart`, `index.dart`) under `lib/src/ui/components/` and is driven by a `WindRecipe` that reads from `MagicStarterTokens.defaultAliases`.

### MagicStarterTokens

`MagicStarterTokens.defaultAliases` is a map of 17 semantic roles to light+dark Wind className pairs:

| Role | Example className pair |
|------|----------------------|
| `surface` | `bg-white dark:bg-gray-950` |
| `fg` | `text-gray-900 dark:text-gray-50` |
| `primary` | `bg-primary-600 dark:bg-primary-500` |
| `destructive` | `bg-red-600 dark:bg-red-500` |
| `border` | `border-gray-200 dark:border-gray-800` |

Pass the map when configuring your Wind theme so all components resolve against semantic roles rather than raw palette utilities:

```dart
WindApp(
  theme: WindThemeData(
    aliases: MagicStarterTokens.defaultAliases,
  ),
  child: const MyApp(),
)
```

> **`MS` prefix (breaking)**: every design-system component now carries an `MS` prefix (`MSButton`, `MSDialog`, `MSSwitch`, ...). This removes the Material collision entirely, so importing both `package:flutter/material.dart` and `package:magic_starter/magic_starter.dart` no longer needs a `hide` clause. See the [migration table](#migration-ms-prefix) below to update from the pre-`MS` names.

### Component families

| Family | Components |
|--------|-----------|
| Form controls | `MSButton`, `MSInput`, `MSTextarea`, `MSCheckbox`, `MSSwitch`, `MSRadio`, `MSSelect`, `MSCombobox` |
| Display | `MSBadge`, `MSTypography`, `MSSkeleton`, `MSToast`, `MSTooltip`, `MSEmptyState`, `MSErrorState`, `MSDataTable` |
| Selection / navigation | `MSSegmentedControl`, `MSTabs`, `MSAccordion`, `MSNavbar`, `MSDropdownMenu` |
| Overlay | `MSDialog`, `MSBottomSheet`, `MSConfirmDialog` |
| Composition | `MSFormField`, `MSCard`, `MSPageHeader`, `MSSocialDivider` |
| Page geometry | `MSPageContainer`, `MSPageScaffold` |
| Settings surface | `MSSettingsSection`, `MSSettingsRow`, `MSSettingsNavRow` |
| Billing surface | `MSUsageMeter`, `MSUpgradeDialog`, `MSUpgradeNudge` |
| App chrome | `MSNotificationDropdown`, `MSUserProfileDropdown`, `MSTeamSelector` |

`MSDataTable` has two constructors, and the choice is about the collection rather than the styling. The default renders every row you pass, which is right for a short and complete list. `MSDataTable.paginated` hands the body to magic's `MagicPaginatedListView` inside a bounded box, so a long collection costs the viewport instead of the whole result and reaching the tail asks the paginator for its next page. The header stays outside the scrolling body either way.

All components accept Wind `className` strings and resolve colors through the semantic alias layer when configured. `MSButton`, `MSInput`, and `MSTextarea` also accept a `bool fullWidth = false` prop; setting it to `true` fills the parent width (wraps the rendered widget in a `SizedBox(width: double.infinity)` rather than a `className` token, since Material widgets ignore cross-axis stretch — see [flutter/flutter#19399](https://github.com/flutter/flutter/issues/19399)).

<a name="migration-ms-prefix"></a>
### Migration: the `MS` prefix

Earlier previews exported these components under bare names. They now carry an
`MS` prefix (and the old names are gone, no compat shim). Replace each old name
with its `MS` counterpart and drop any `hide` clause you added for the Material
collision:

| Old | New | Old | New |
|-----|-----|-----|-----|
| `Button` | `MSButton` | `DropdownMenu` | `MSDropdownMenu` |
| `Input` | `MSInput` | `DropdownMenuItem` | `MSDropdownMenuItem` |
| `Textarea` | `MSTextarea` | `MagicFormField` | `MSFormField` |
| `Checkbox` | `MSCheckbox` | `Navbar` | `MSNavbar` |
| `Switch` | `MSSwitch` | `EmptyState` | `MSEmptyState` |
| `Radio` | `MSRadio` | `ErrorState` | `MSErrorState` |
| `Badge` | `MSBadge` | `SettingsSection` | `MSSettingsSection` |
| `Typography` | `MSTypography` | `SettingsRow` | `MSSettingsRow` |
| `Skeleton` | `MSSkeleton` | `SettingsNavRow` | `MSSettingsNavRow` |
| `Select` | `MSSelect` | `SettingsScaffold` | `MSPageScaffold` |
| `Combobox` | `MSCombobox` | `Card` | `MSCard` |
| `SegmentedControl` | `MSSegmentedControl` | `PageHeader` | `MSPageHeader` |
| `Tabs` | `MSTabs` | `SocialDivider` | `MSSocialDivider` |
| `Accordion` | `MSAccordion` | `NotificationDropdown` | `MSNotificationDropdown` |
| `AccordionItem` | `MSAccordionItem` | `UserProfileDropdown` | `MSUserProfileDropdown` |
| `Dialog` | `MSDialog` | `TeamSelector` | `MSTeamSelector` |
| `BottomSheet` | `MSBottomSheet` | `ConfirmDialog` | `MSConfirmDialog` |
| `Toast` | `MSToast` | `Tooltip` | `MSTooltip` |

The per-axis enums (`ButtonIntent`, `InputState`, ...) are unchanged.

Two later changes go beyond that table. The six alias widgets are gone: use `MSCard`, `MSPageHeader`, `MSSocialDivider`, `MSNotificationDropdown`, `MSTeamSelector` and `MSUserProfileDropdown` directly. The remaining `MagicStarter*` widgets (`MagicStarterConfirmDialog`, `MagicStarterDialogShell`, `MagicStarterTimezoneSelect`, ...) keep their names. And the settings scaffold became the page scaffold, which renamed its recipes:

| Before | After |
|--------|-------|
| `MSSettingsScaffold` | `MSPageScaffold` |
| `settingsScaffoldScrollableRecipe()` | `pageScaffoldSurfaceRecipe()` |
| `settingsScaffoldChildrenAreaRecipe()` | `pageScaffoldChildrenAreaRecipe()` |
| `settingsScaffoldContainerRecipe()` | removed; render `MSPageContainer`, or call `pageContainerRecipe()` for the className alone |

Every other recipe function is unchanged.

---

## Reusable Widgets

Magic Starter also exports a set of standalone UI widgets that consumer apps can use directly. No internal controller coupling required.

### MSPageHeader

Full-width page header with title, optional subtitle, optional leading widget, and an `actions` list. Renders `sm:flex-row` responsive layout with a `border-b` divider:

```dart
MSPageHeader(
  title: trans('projects.title'),
  subtitle: trans('projects.manage_subtitle'),
  leading: BackButton(),
  actions: [
    PrimaryButton(label: trans('projects.new'), onTap: _onCreate),
  ],
)
```

### MSCard

Card wrapper with optional `title` slot, `noPadding` mode for full-bleed content, and three visual `variant` styles:

| Variant | Appearance |
|---------|-----------|
| `CardVariant.surface` _(default)_ | White background, subtle border |
| `CardVariant.inset` | Gray-50 recessed background, border |
| `CardVariant.elevated` | White background, drop shadow — no border |

```dart
// Default surface card with title
MSCard(
  title: 'Team Members',
  child: memberList,
)

// Full-bleed elevated card
MSCard(
  variant: CardVariant.elevated,
  noPadding: true,
  child: dataTable,
)

// Inset section card
MSCard(
  variant: CardVariant.inset,
  title: 'Danger Zone',
  child: deleteAccountButton,
)
```

### MagicStarterPasswordConfirmDialog

Standalone password-confirmation dialog. Pass an `onConfirm` callback that returns `null` on success or an error string to show inline. Works independently of any controller:

```dart
final confirmed = await MagicStarterPasswordConfirmDialog.show(
  context,
  title: trans('projects.delete_confirm_title'),
  description: trans('projects.delete_confirm_description'),
  onConfirm: (password) async {
    final error = await ProjectService.deleteProject(id, password: password);
    return error; // null = success, string = show error inline
  },
);

if (confirmed) _removeProject();
```

### MagicStarterTwoFactorModal

Multi-step 2FA wizard modal. Pass `setupData` (from the enable-2FA endpoint) and an `onConfirm` callback. Works for both initial setup and standalone re-authentication flows:

```dart
final success = await MagicStarterTwoFactorModal.show(
  context,
  setupData: response.data, // {secret, qr_svg, recovery_codes}
  onConfirm: (code) async {
    return await TwoFactorService.verify(code);
  },
);
```

### Other Exported Widgets

| Widget | Purpose |
|--------|---------|
| `MagicStarterAuthFormCard` | Centered card wrapper for auth-adjacent screens (invite accept, onboarding) |
| `MagicStarterTimezoneSelect` | Searchable timezone dropdown backed by `GET /timezones` |
| `MSTeamSelector` | Current-team switcher dropdown with create/settings links |
| `MSUserProfileDropdown` | User avatar menu with profile links, theme toggle, and logout |
| `MSNotificationDropdown` | Bell-icon dropdown with live unread badge and mark-as-read |
| `MSSocialDivider` | "Or continue with" divider for auth forms |

All widgets are exported from `package:magic_starter/magic_starter.dart`.

---

## Theming

### Navigation Theme

Customize navigation colors, the brand/logo, and avatar styles without overriding any screens:

```dart
MagicStarter.useNavigationTheme(
  MagicStarterNavigationTheme(
    // Active nav item — supports independent light/dark tokens
    activeItemClassName:
        'active:text-amber-500 active:bg-amber-500/10 dark:active:text-amber-400 dark:active:bg-amber-400/10',

    // Brand: gradient text
    brandClassName:
        'text-lg font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent',

    // Brand: image/SVG logo (overrides brandClassName when set)
    brandBuilder: (context) => Image.asset('assets/logo.png', height: 28),

    // Bottom nav active color
    bottomNavActiveClassName: 'active:text-amber-500 dark:active:text-amber-400',

    // Sidebar user menu avatar
    avatarClassName: 'bg-amber-500/10 dark:bg-amber-400/10',
    avatarTextClassName: 'text-sm font-bold text-amber-600 dark:text-amber-400',

    // Profile dropdown trigger avatar
    dropdownAvatarClassName: 'bg-gradient-to-tr from-amber-500 to-amber-300',
  ),
);
```

### Modal Theme

Customize dialog and modal styles — confirmation dialogs, password prompts, and two-factor modals all read from this theme:

```dart
MagicStarter.useModalTheme(
  MagicStarterModalTheme(
    containerClassName: 'rounded-2xl bg-white dark:bg-gray-900',
    titleClassName: 'text-lg font-semibold text-gray-900 dark:text-white',
    primaryButtonClassName: 'bg-primary hover:bg-primary/90 text-white',
    dangerButtonClassName: 'bg-red-600 hover:bg-red-700 text-white',
    maxWidth: 480,
  ),
);
```

All theme fields are optional — omitted fields fall back to sensible defaults. Call both `useNavigationTheme()` and `useModalTheme()` in `AppServiceProvider.boot()` before any UI is painted.

---

## Customization

Magic Starter supports five levels of customization. Each level is independent — use only what your app requires.

### Level 1: Config (Feature Toggles)

Enable or disable entire modules via `lib/config/magic_starter.dart`. No code changes required:

```dart
'features': {
  'teams': true,
  'two_factor': true,
  'notifications': true,
  // all others remain false
},
```

### Level 2: Theme Tokens

Apply Wind UI className overrides across all built-in screens at once using `MagicStarter.useTheme()`:

```dart
MagicStarter.useTheme(
  MagicStarterTheme(
    form: MagicStarterFormTheme(
      inputClassName: 'w-full px-4 py-3 rounded-xl bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700',
      primaryButtonClassName: 'w-full bg-primary hover:bg-primary/80 text-white text-base font-semibold py-3 rounded-lg',
    ),
    card: MagicStarterCardTheme(
      surfaceClassName: 'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700',
    ),
  ),
);
```

`MagicStarterTheme` has 7 sub-themes: `form`, `card`, `navigation`, `modal`, `layout`, `pageHeader`, `auth`. All fields are optional.

#### One-call adoption from a `WindThemeData`

If your app already defines a Wind semantic palette (the 17 alias roles, e.g. via `MagicStarterTokens.defaultAliases` or a `design:sync`-generated map), skip building sub-theme structs entirely and adopt the whole palette in one call:

```dart
MagicStarter.useWindTheme(
  WindThemeData(
    colors: {'primary': myBrandColor},
    aliases: MagicStarterTokens.defaultAliases, // or a design:sync map
  ),
);
```

`useWindTheme()` derives all 7 sub-themes from the theme's semantic roles (`bg-surface`, `text-fg`, `bg-primary`, `border-color-border`, `bg-destructive`, ...) and delegates to `useTheme()`. Each alias carries its own `dark:` pair, so one token re-skins both light and dark. It is additive: `useTheme()` and any `use*Theme()` setter still override afterward. A role you do not define keeps the shipped default (never an invisible surface). See [doc/guides/wind-theme-adoption.md](doc/guides/wind-theme-adoption.md) for the full alias-to-property mapping.

### Level 3: Builder Slots

Override specific sections of a screen without replacing the full view. Use `MagicStarter.view.slot()` to register a partial builder for a named slot:

```dart
// Replace only the header section inside the profile view
MagicStarter.view.slot('profile.settings', 'header', (context) {
  return MyCustomProfileHeader();
});
```

Slots let you inject custom widgets into predefined regions — useful when you need brand-specific visuals in one area but want the rest of the screen untouched.

### Level 4: View Override

Replace an entire screen with your own implementation. The host app always wins over package defaults:

```dart
MagicStarter.view.register('auth.login', () {
  return const MyBrandedLoginView();
});

MagicStarter.view.registerLayout('layout.guest', (child) {
  return MyCustomGuestLayout(child: child);
});
```

All overridable keys: `auth.login`, `auth.register`, `auth.forgot_password`, `auth.reset_password`, `auth.two_factor_challenge`, `auth.otp_verify`, `profile.settings`, `teams.create`, `teams.settings`, `teams.invitation_accept`, `notifications.list`, `notifications.preferences`, `layout.app`, `layout.guest`.

### Level 5: Publish and Own

Copy a view file directly into your host app for complete control. Changes are permanent and tracked by `git`:

```bash
# Publish a single view
dart run <app>:artisan starter:publish --tag=views:auth.login

# Publish all auth views
dart run <app>:artisan starter:publish --tag=views:auth

# Run doctor to verify wiring
dart run <app>:artisan starter:doctor
```

The publish command copies the view to `lib/resources/views/starter/` and auto-wires it into `AppServiceProvider` so it takes effect immediately. Use `dart run <app>:artisan starter:doctor` to confirm registration status.

---

## CLI Tools

Run any of these commands via your host app's artisan dispatcher:

| Command | Description |
|---------|-------------|
| `dart run <app>:artisan starter:install` | Scaffold config, provider, and routes into your Magic project |
| `dart run <app>:artisan starter:configure` | Interactively toggle features and update config |
| `dart run <app>:artisan starter:doctor` | Verify installation, check dependencies, diagnose issues |
| `dart run <app>:artisan starter:publish --tag=views:auth.login` | Publish a specific view/layout for full customization |
| `dart run <app>:artisan starter:uninstall` | Remove starter config, provider, and routes from your project |

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
| Feature Toggles | `MagicStarterConfig` — 14 opt-in flags via `ConfigRepository` |
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
| [Controllers & State Registration](https://magic.fluttersdk.com/packages/starter/architecture/controllers) | Recommended state/controller registration pattern for consumer apps |
| [State Management Guide](https://magic.fluttersdk.com/packages/starter/guides/state-management) | State management best practices and patterns |

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
