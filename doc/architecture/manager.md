# MagicStarterManager

- [Introduction](#introduction)
- [Singleton Pattern](#singleton-pattern)
- [User Model Registration](#user-model-registration)
- [Team Resolver](#team-resolver)
- [Navigation Configuration](#navigation-configuration)
- [Header Builder](#header-builder)
- [Logout Callback](#logout-callback)
- [Notification Type Mapper](#notification-type-mapper)
- [View Registry Integration](#view-registry-integration)
- [Default Views](#default-views)
- [MagicStarter Facade](#magicstarter-facade)
- [Related](#related)

<a name="introduction"></a>
## Introduction

`MagicStarterManager` is the central singleton that holds all customization registrations for the magic_starter plugin. It acts as a configuration hub where host apps register custom user models, team resolvers, navigation items, header builders, logout callbacks, notification type mappers, and view overrides.

The manager lives at `lib/src/magic_starter_manager.dart` and is instantiated once by `MagicStarterServiceProvider` during the register phase.

<a name="singleton-pattern"></a>
## Singleton Pattern

The manager is bound into the Magic IoC container under the key `'magic_starter'` by the service provider:

```dart
app.singleton('magic_starter', () => MagicStarterManager());
```

All access goes through the `MagicStarter` facade, which resolves the singleton from the container:

```dart
static MagicStarterManager get manager =>
    Magic.make<MagicStarterManager>('magic_starter');
```

> [!NOTE]
> The constructor calls `registerDefaultViews()` immediately. This means all default views and layouts are available as soon as the manager is instantiated — before `boot()` runs.

<a name="user-model-registration"></a>
## User Model Registration

By default the manager creates `MagicStarterAuthUser` instances from API data. Host apps override this to use their own `Authenticatable` subclass:

```dart
MagicStarter.useUserModel((data) => User.fromMap(data));
```

Internally the manager stores a `UserModelFactory` — a function that takes `Map<String, dynamic>` and returns `Authenticatable`:

```dart
UserModelFactory userFactory = (data) => MagicStarterAuthUser.fromMap(data);
```

The factory is invoked via `MagicStarter.createUser(data)` whenever the plugin needs to hydrate a user model from an API response.

> [!TIP]
> Register your user model factory early — ideally in your `AppServiceProvider.boot()` — so all auth flows use the correct model from the start.

<a name="team-resolver"></a>
## Team Resolver

The team resolver bridges the plugin's team UI with app-specific team models through three callbacks:

```dart
MagicStarter.useTeamResolver(
  currentTeam: () => User.current.currentTeam?.toMagicStarterTeam(),
  allTeams: () => User.current.allTeams
      .map((t) => t.toMagicStarterTeam())
      .toList(),
  onSwitch: (id) => TeamController.instance.switchTeam(id),
);
```

The callbacks are wrapped in `MagicStarterTeamResolverConfig`:

| Callback | Signature | Purpose |
|----------|-----------|---------|
| `currentTeam` | `MagicStarterTeam? Function()` | Returns the active team (null if none) |
| `allTeams` | `List<MagicStarterTeam> Function()` | Returns all teams the user belongs to |
| `onSwitch` | `Future<void> Function(dynamic teamId)` | Handles team switching logic |

> [!NOTE]
> If the `magic_starter.features.teams` config flag is enabled but no team resolver is configured, the service provider logs a warning at boot time. The `manager.isReady` getter also returns `false` in this state.

<a name="navigation-configuration"></a>
## Navigation Configuration

Host apps register navigation items for the authenticated app layout — sidebar, bottom bar, and profile dropdown:

```dart
MagicStarter.useNavigation(
  mainItems: [
    MagicStarterNavItem(
      icon: Icons.dashboard,
      labelKey: 'nav.dashboard',
      path: '/',
    ),
  ],
  systemItems: [
    MagicStarterNavItem(
      icon: Icons.people_outline,
      labelKey: 'nav.members',
      path: '/teams/members',
    ),
  ],
  bottomItems: [
    MagicStarterNavItem(
      icon: Icons.dashboard_outlined,
      labelKey: 'nav.dashboard',
      path: '/',
    ),
  ],
  profileMenuItems: [
    MagicStarterNavItem(
      icon: Icons.notifications_outlined,
      labelKey: 'nav.notifications',
      path: '/notifications',
    ),
  ],
);
```

The items are stored in `MagicStarterNavigationConfig`:

| Property | Required | Description |
|----------|----------|-------------|
| `mainItems` | Yes | Primary sidebar/drawer items (Dashboard, Monitors, etc.) |
| `systemItems` | No | Secondary items below the main group (Settings, Members) |
| `bottomItems` | No | Mobile bottom navigation bar items (subset of main) |
| `profileMenuItems` | No | Extra links in the profile dropdown, between "Profile Settings" and logout |

<a name="header-builder"></a>
## Header Builder

Replace the default app layout header with a custom widget:

```dart
MagicStarter.useHeader((context, isDesktop) {
  return AppHeader(showMenuButton: !isDesktop);
});
```

The builder receives the current `BuildContext` and a `bool isDesktop` flag so the header can adapt between desktop sidebar and mobile drawer layouts.

When `headerBuilder` is `null`, the app layout renders its built-in header with team selector, notification badge, and user profile dropdown.

<a name="logout-callback"></a>
## Logout Callback

Override the default logout behavior to add custom cleanup steps:

```dart
MagicStarter.useLogout(() async {
  await Notify.logoutPush();
  await SocialAuth.signOut();
  await Auth.logout();
  MagicRoute.to('/auth/login');
});
```

When set, the app layout's logout button calls this callback instead of `MagicStarterAuthController.instance.logout()`. This is useful for apps that need to unregister push tokens, sign out of social providers, or perform other cleanup before navigating to the login screen.

<a name="notification-type-mapper"></a>
## Notification Type Mapper

Map notification type strings to icons and color classes for the notification list UI:

```dart
MagicStarter.useNotificationTypeMapper((type) => switch (type) {
  'monitor_down' => (
    icon: Icons.error_outline,
    colorClass: 'text-red-500',
  ),
  'monitor_up' => (
    icon: Icons.check_circle_outline,
    colorClass: 'text-green-500',
  ),
  _ => (
    icon: Icons.info_outline,
    colorClass: 'text-blue-500',
  ),
});
```

The mapper returns a record `({IconData icon, String colorClass})`. When not configured, notification views fall back to built-in defaults.

<a name="view-registry-integration"></a>
## View Registry Integration

The manager holds a private `MagicStarterViewRegistry` instance, exposed via the `view` getter:

```dart
final MagicStarterViewRegistry _viewRegistry = MagicStarterViewRegistry();

MagicStarterViewRegistry get view => _viewRegistry;
```

The facade provides a shortcut: `MagicStarter.view` delegates to `manager.view`. All view and layout registration, lookup, and building flows through this single registry instance.

> [!TIP]
> Override views **before** the manager is instantiated (i.e., before `MagicStarterServiceProvider.register()` runs) if you want to prevent default views from being registered at all. In practice, registering overrides in your `AppServiceProvider.boot()` works because `registerDefaultViews()` uses a "register if absent" strategy — it skips keys that already exist.

<a name="default-views"></a>
## Default Views

`registerDefaultViews()` is called in the constructor and populates the registry with plugin-provided views. It uses a "register if absent" pattern — existing keys are never overwritten:

```dart
void _registerDefault(String key, Widget Function() builder) {
  if (!_viewRegistry.has(key)) {
    _viewRegistry.register(key, builder);
  }
}
```

The following default views are registered:

| Key | View | Condition |
|-----|------|-----------|
| `auth.login` | `MagicStarterLoginView` | Always |
| `auth.register` | `MagicStarterRegisterView` | Always |
| `auth.forgot_password` | `MagicStarterForgotPasswordView` | Always |
| `auth.reset_password` | `MagicStarterResetPasswordView` | Always |
| `auth.two_factor_challenge` | `MagicStarterTwoFactorChallengeView` | `hasTwoFactorFeatures()` |
| `auth.otp_verify` | `MagicStarterOtpVerifyView` | `hasPhoneOtpFeatures()` |
| `profile.settings` | `MagicStarterProfileSettingsView` | Always |
| `teams.create` | `MagicStarterTeamCreateView` | `hasTeamFeatures()` |
| `teams.settings` | `MagicStarterTeamSettingsView` | `hasTeamFeatures()` |
| `teams.invitation_accept` | `MagicStarterTeamInvitationAcceptView` | `hasTeamFeatures()` |
| `notifications.list` | `MagicStarterNotificationsListView` | `hasNotificationFeatures()` |
| `notifications.preferences` | `MagicStarterNotificationPreferencesView` | `hasNotificationFeatures()` |

Default layouts:

| Key | Layout |
|-----|--------|
| `layout.guest` | `MagicStarterGuestLayout` |
| `layout.app` | `MagicStarterAppLayout` |

<a name="magicstarter-facade"></a>
## MagicStarter Facade

`MagicStarter` is a static utility class (private constructor `MagicStarter._()`) that delegates every call to the manager singleton. It provides the public API that host apps interact with:

| Facade Method | Manager Property |
|---------------|-----------------|
| `MagicStarter.useUserModel(factory)` | `manager.userFactory = factory` |
| `MagicStarter.createUser(data)` | `manager.userFactory(data)` |
| `MagicStarter.useTeamResolver(...)` | `manager.teamResolver = config` |
| `MagicStarter.useNavigation(...)` | `manager.navigationConfig = config` |
| `MagicStarter.useHeader(builder)` | `manager.headerBuilder = builder` |
| `MagicStarter.useLogout(callback)` | `manager.onLogout = callback` |
| `MagicStarter.useSocialLogin(builder)` | `manager.socialLoginBuilder = builder` |
| `MagicStarter.useNotificationTypeMapper(mapper)` | `manager.notificationTypeMapper = mapper` |
| `MagicStarter.useLocaleOptions(locales)` | `manager.localeOptions = options` |
| `MagicStarter.useGuestAuthEntry(builder)` | `manager.guestAuthEntryBuilder = builder` |
| `MagicStarter.useNewsletterLabel(label)` | `manager.newsletterLabel = label` |
| `MagicStarter.view` | `manager.view` |
| `MagicStarter.isReady` | `manager.isReady` |

The `reset()` method on the manager restores all properties to their defaults, clears the view registry, and re-registers default views — used in test `setUp()` blocks for isolation.

<a name="related"></a>
## Related

- [MagicStarterServiceProvider](https://magic.fluttersdk.com/packages/starter/architecture/service-provider) — bootstrap entry point that binds the manager and registers Gate abilities
- [View Registry](https://magic.fluttersdk.com/packages/starter/architecture/view-registry) — string-keyed view factory for overridable UI
- [Magic Framework — IoC Container](https://magic.fluttersdk.com/getting-started/ioc-container) — singleton and factory binding reference
