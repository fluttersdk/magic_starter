# MagicStarterManager

- [Introduction](#introduction)
- [Singleton Pattern](#singleton-pattern)
- [User Model Registration](#user-model-registration)
- [Team Resolver](#team-resolver)
- [Navigation Configuration](#navigation-configuration)
- [Navigation Theme](#navigation-theme)
- [Modal Theme](#modal-theme)
- [Sidebar Footer Builder](#sidebar-footer-builder)
- [Header Builder](#header-builder)
- [Logout Callback](#logout-callback)
- [Notification Type Mapper](#notification-type-mapper)
- [Unified Theme](#unified-theme)
- [Form Theme](#form-theme)
- [Auth Theme](#auth-theme)
- [Card Theme](#card-theme)
- [Page Header Theme](#page-header-theme)
- [Layout Theme](#layout-theme)
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

<a name="navigation-theme"></a>
## Navigation Theme

`MagicStarterNavigationTheme` overrides the default Wind UI `text-primary` tokens used for active nav items, the brand/logo, bottom navigation, and user avatar colors — without requiring any view overrides.

```dart
MagicStarter.useNavigationTheme(
  MagicStarterNavigationTheme(
    activeItemClassName:
        'active:text-amber-500 active:bg-amber-500/10 dark:active:text-amber-400 dark:active:bg-amber-400/10',
    brandClassName:
        'text-lg font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent',
    brandBuilder: (context) => Image.asset('assets/logo.png', height: 28),
    bottomNavActiveClassName: 'active:text-amber-500 dark:active:text-amber-400',
    avatarClassName: 'bg-amber-500/10 dark:bg-amber-400/10',
    avatarTextClassName: 'text-sm font-bold text-amber-600 dark:text-amber-400',
    dropdownAvatarClassName: 'bg-gradient-to-tr from-amber-500 to-amber-300',
  ),
);
```

All fields are optional — omitted fields fall back to the current defaults.

| Field | Default | Controls |
|-------|---------|---------|
| `activeItemClassName` | `active:text-primary active:bg-primary/10 dark:active:bg-primary/10` | Sidebar/drawer active nav item |
| `hoverItemClassName` | `hover:bg-gray-100 dark:hover:bg-gray-800` | Sidebar/drawer hover state |
| `brandClassName` | `text-lg font-bold text-primary` | Brand/logo text style (supports gradient tokens) |
| `brandBuilder` | `null` | Custom brand widget builder (image, SVG, etc.) — overrides `brandClassName` when set |
| `bottomNavActiveClassName` | `active:text-primary` | Bottom nav active icon and label |
| `avatarClassName` | `bg-primary/10 dark:bg-primary/10` | Sidebar user menu avatar background |
| `avatarTextClassName` | `text-sm font-bold text-primary` | Sidebar user menu avatar initial color |
| `dropdownAvatarClassName` | `bg-gradient-to-tr from-primary to-gray-200` | Profile dropdown trigger avatar gradient |

The theme is stored on `MagicStarterManager` as `navigationTheme` and reset to defaults by `manager.reset()`. The active theme is read at widget build time, so `useNavigationTheme()` can be called at any point before the layout is first painted.

> [!NOTE]
> When `brandBuilder` is set, `brandClassName` is ignored. The builder receives the current `BuildContext` and should return any widget — `Image.asset`, `SvgPicture.asset`, a styled `WText`, etc.

<a name="modal-theme"></a>
## Modal Theme

`MagicStarterModalTheme` overrides the default Wind UI tokens used for all modal dialogs — confirmation dialogs, password prompts, and two-factor modals. Works the same way as `NavigationTheme`: register once, all modals pick up the tokens at build time.

```dart
MagicStarter.useModalTheme(
  MagicStarterModalTheme(
    containerClassName: 'rounded-2xl bg-white dark:bg-gray-900',
    titleClassName: 'text-lg font-semibold text-gray-900 dark:text-white',
    descriptionClassName: 'text-sm text-gray-500 dark:text-gray-400',
    primaryButtonClassName: 'bg-primary hover:bg-primary/90 text-white',
    dangerButtonClassName: 'bg-red-600 hover:bg-red-700 text-white',
    warningButtonClassName: 'bg-amber-500 hover:bg-amber-600 text-white',
    inputClassName: 'rounded-lg border border-gray-300 dark:border-gray-600',
    maxWidth: 480,
  ),
);
```

All fields are optional — omitted fields fall back to the current defaults.

| Field | Default | Controls |
|-------|---------|---------|
| `containerClassName` | Default dialog container | Outer dialog container background, border-radius, border |
| `headerClassName` | Default header | Dialog header section (sticky top) |
| `bodyClassName` | Default body | Scrollable body section |
| `footerClassName` | Default footer | Dialog footer section (sticky bottom) |
| `titleClassName` | Default title | Dialog title text style |
| `descriptionClassName` | Default description | Dialog description/subtitle text style |
| `primaryButtonClassName` | Default primary | Primary action button (confirm, save) |
| `secondaryButtonClassName` | Default secondary | Secondary action button (cancel, dismiss) |
| `dangerButtonClassName` | Default danger | Danger action button (delete, destroy) |
| `warningButtonClassName` | Default warning | Warning action button |
| `errorClassName` | Default error | Inline error message text style |
| `inputClassName` | Default input | Text input fields inside dialogs |
| `maxWidth` | `448.0` | Maximum dialog width in logical pixels |

The theme is stored on `MagicStarterManager` as `modalTheme` and reset to defaults by `manager.reset()`. The active theme is read at widget build time, so `useModalTheme()` can be called at any point before a dialog is shown.

> [!TIP]
> Register your modal theme in `AppServiceProvider.boot()` alongside `useNavigationTheme()`. Both follow the same pattern — register once, all widgets read the tokens at build time.

<a name="sidebar-footer-builder"></a>
## Sidebar Footer Builder

Add a custom widget between the navigation items and the user menu in both the desktop sidebar and mobile drawer:

```dart
MagicStarter.useSidebarFooter((context) {
  return MyVersionBadge();
});
```

The builder receives the current `BuildContext` and should return any widget — a version badge, environment indicator, support link, etc.

When `sidebarFooterBuilder` is `null` (the default), no extra content is rendered between navigation and the user menu.

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

<a name="unified-theme"></a>
## Unified Theme

`MagicStarterTheme` wraps all 7 sub-theme objects into a single configuration. Host apps can set the entire visual identity in one call, then selectively override individual sub-themes afterward:

```dart
MagicStarter.useTheme(
  MagicStarterTheme(
    navigation: MagicStarterNavigationTheme(
      activeItemClassName: 'active:text-amber-500 active:bg-amber-500/10',
    ),
    form: MagicStarterFormTheme(
      inputClassName: 'rounded-xl border-2 border-zinc-700',
    ),
    card: MagicStarterCardTheme(
      surfaceClassName: 'bg-zinc-50 dark:bg-zinc-900',
    ),
  ),
);

// Override just one sub-theme after unified set
MagicStarter.useAuthTheme(
  MagicStarterAuthTheme(cardClassName: 'rounded-3xl bg-zinc-900 p-8'),
);
```

The unified theme supports `copyWith()` for partial overrides:

```dart
final customTheme = MagicStarter.theme.copyWith(
  form: MagicStarterFormTheme(inputClassName: 'rounded-xl'),
);
MagicStarter.useTheme(customTheme);
```

The manager maintains bidirectional sync: the `theme` getter constructs a `MagicStarterTheme` from all 7 individual fields, while the `theme` setter distributes each sub-theme to its respective field. Both `useTheme()` and individual `use*Theme()` methods work together seamlessly.

| Sub-theme | Class | Facade getter/setter |
|-----------|-------|---------------------|
| Navigation | `MagicStarterNavigationTheme` | `useNavigationTheme()` / `navigationTheme` |
| Modal | `MagicStarterModalTheme` | `useModalTheme()` / `modalTheme` |
| Form | `MagicStarterFormTheme` | `useFormTheme()` / `formTheme` |
| Auth | `MagicStarterAuthTheme` | `useAuthTheme()` / `authTheme` |
| Card | `MagicStarterCardTheme` | `useCardTheme()` / `cardTheme` |
| Page Header | `MagicStarterPageHeaderTheme` | `usePageHeaderTheme()` / `pageHeaderTheme` |
| Layout | `MagicStarterLayoutTheme` | `useLayoutTheme()` / `layoutTheme` |

All sub-theme classes live in `lib/src/configuration/magic_starter_theme.dart`.

<a name="form-theme"></a>
## Form Theme

`MagicStarterFormTheme` overrides Wind UI tokens for form inputs, labels, placeholders, buttons, links, and checkboxes across all auth and profile forms.

```dart
MagicStarter.useFormTheme(
  MagicStarterFormTheme(
    inputClassName: 'w-full px-4 py-4 rounded-xl bg-zinc-900 border border-zinc-700 text-white',
    primaryButtonClassName: 'w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-xl',
  ),
);
```

<a name="auth-theme"></a>
## Auth Theme

`MagicStarterAuthTheme` overrides Wind UI tokens for the auth form card, title, subtitle, error banner, social divider, and link styles on login/register/forgot/reset pages.

```dart
MagicStarter.useAuthTheme(
  MagicStarterAuthTheme(
    cardClassName: 'rounded-3xl bg-zinc-900 border border-zinc-700 p-8',
    titleClassName: 'text-3xl font-black text-white text-center',
  ),
);
```

<a name="card-theme"></a>
## Card Theme

`MagicStarterCardTheme` overrides Wind UI tokens for `MagicStarterCard` variant backgrounds, border radius, padding, and title styles.

```dart
MagicStarter.useCardTheme(
  MagicStarterCardTheme(
    surfaceClassName: 'bg-zinc-900 border border-zinc-700',
    borderRadius: 'rounded-xl',
  ),
);
```

<a name="page-header-theme"></a>
## Page Header Theme

`MagicStarterPageHeaderTheme` overrides Wind UI tokens for the `MagicStarterPageHeader` container, title, subtitle, and action container.

```dart
MagicStarter.usePageHeaderTheme(
  MagicStarterPageHeaderTheme(
    titleClassName: 'text-3xl font-black text-white',
  ),
);
```

<a name="layout-theme"></a>
## Layout Theme

`MagicStarterLayoutTheme` overrides Wind UI class names and dimensions for the app layout shell: sidebar, header, content background, drawer background, brand bar, and bottom navigation.

```dart
MagicStarter.useLayoutTheme(
  MagicStarterLayoutTheme(
    sidebarWidth: 280,
    sidebarClassName: 'h-full flex flex-col bg-zinc-900 border-r border-zinc-700',
    contentBackgroundLightColor: 'zinc',
    contentBackgroundLightShade: 50,
  ),
);
```

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
| `MagicStarter.useTheme(theme)` | `manager.theme = theme` (sets all 7 sub-themes) |
| `MagicStarter.useNavigationTheme(theme)` | `manager.navigationTheme = theme` |
| `MagicStarter.useModalTheme(theme)` | `manager.modalTheme = theme` |
| `MagicStarter.useFormTheme(theme)` | `manager.formTheme = theme` |
| `MagicStarter.useAuthTheme(theme)` | `manager.authTheme = theme` |
| `MagicStarter.useCardTheme(theme)` | `manager.cardTheme = theme` |
| `MagicStarter.usePageHeaderTheme(theme)` | `manager.pageHeaderTheme = theme` |
| `MagicStarter.useLayoutTheme(theme)` | `manager.layoutTheme = theme` |
| `MagicStarter.useSidebarFooter(builder)` | `manager.sidebarFooterBuilder = builder` |
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
