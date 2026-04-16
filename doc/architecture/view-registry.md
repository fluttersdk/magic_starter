# View Registry

- [Introduction](#introduction)
- [MagicStarterViewRegistry Class](#magicstarterviewregistry-class)
    - [Registering Views](#registering-views)
    - [Registering Layouts](#registering-layouts)
    - [Registering Modals](#registering-modals)
    - [Checking Existence](#checking-existence)
    - [Building Widgets](#building-widgets)
    - [Clearing the Registry](#clearing-the-registry)
- [Default View Keys](#default-view-keys)
- [Default Layout Keys](#default-layout-keys)
- [Default Modal Keys](#default-modal-keys)
- [Overriding Views](#overriding-views)
- [Overriding Layouts](#overriding-layouts)
- [Overriding Modals](#overriding-modals)
- [Builder Slots](#builder-slots)
- [Route Integration](#route-integration)
- [Testing](#testing)
- [Related](#related)

<a name="introduction"></a>
## Introduction

`MagicStarterViewRegistry` is a string-keyed view factory that makes every screen in the magic_starter plugin overridable by the host app. Instead of hard-wiring view constructors in routes, all views and layouts are resolved through this registry at runtime — allowing host apps to swap any screen without touching routes or controllers.

The registry lives at `lib/src/ui/magic_starter_view_registry.dart` and is held as a private field on `MagicStarterManager`.

<a name="magicstarterviewregistry-class"></a>
## MagicStarterViewRegistry Class

The registry maintains three internal maps — one for view builders, one for layout builders, and one for modal builders:

```dart
final Map<String, MagicStarterViewBuilder> _builders = {};
final Map<String, MagicStarterLayoutBuilder> _layouts = {};
final Map<String, MagicStarterModalBuilder> _modals = {};
```

The builder typedefs:

```dart
typedef MagicStarterViewBuilder = Widget Function();
typedef MagicStarterLayoutBuilder = Widget Function(Widget child);
typedef MagicStarterModalBuilder = Widget Function();
```

<a name="registering-views"></a>
### Registering Views

```dart
void register(String key, MagicStarterViewBuilder builder)
```

Stores a view builder under the given key. If the key already exists, the previous builder is replaced.

<a name="registering-layouts"></a>
### Registering Layouts

```dart
void registerLayout(String key, MagicStarterLayoutBuilder builder)
```

Stores a layout builder under the given key. Layout builders receive a `Widget child` and wrap it in a layout shell (sidebar, header, footer, etc.).

<a name="registering-modals"></a>
### Registering Modals

```dart
void registerModal(String key, MagicStarterModalBuilder builder)
```

Stores a modal builder under the given key. Modal builders return a widget that is displayed inside a dialog shell. If the key already exists, the previous builder is replaced.

<a name="checking-existence"></a>
### Checking Existence

```dart
bool has(String key)       // true when a view builder exists for key
bool hasLayout(String key) // true when a layout builder exists for key
bool hasModal(String key)  // true when a modal builder exists for key
```

Used internally by `registerDefaultViews()` to implement the "register if absent" pattern.

<a name="building-widgets"></a>
### Building Widgets

```dart
Widget make(String key)
Widget makeLayout(String key, {required Widget child})
Widget makeModal(String key)
```

All three methods throw `StateError` when the requested key is not registered:

```dart
throw StateError('No view builder registered for key "$key".');
```

> [!NOTE]
> A `StateError` from `make()` or `makeLayout()` usually means a feature flag is disabled. Feature-gated views (teams, two-factor, notifications) are only registered when their corresponding `MagicStarterConfig.has*Features()` flag returns `true`.

<a name="clearing-the-registry"></a>
### Clearing the Registry

```dart
void clear()
```

Removes all view, layout, and modal builders. Used in test teardowns and by `MagicStarterManager.reset()`.

<a name="default-view-keys"></a>
## Default View Keys

These are registered by `MagicStarterManager.registerDefaultViews()` at construction time:

**Auth views** (always registered):

| Key | View |
|-----|------|
| `auth.login` | `MagicStarterLoginView` |
| `auth.register` | `MagicStarterRegisterView` |
| `auth.forgot_password` | `MagicStarterForgotPasswordView` |
| `auth.reset_password` | `MagicStarterResetPasswordView` |

**Auth views** (feature-gated):

| Key | View | Feature Flag |
|-----|------|-------------|
| `auth.two_factor_challenge` | `MagicStarterTwoFactorChallengeView` | `hasTwoFactorFeatures()` |
| `auth.otp_verify` | `MagicStarterOtpVerifyView` | `hasPhoneOtpFeatures()` |

**Profile views** (always registered):

| Key | View |
|-----|------|
| `profile.settings` | `MagicStarterProfileSettingsView` |

**Team views** (require `hasTeamFeatures()`):

| Key | View |
|-----|------|
| `teams.create` | `MagicStarterTeamCreateView` |
| `teams.settings` | `MagicStarterTeamSettingsView` |
| `teams.invitation_accept` | `MagicStarterTeamInvitationAcceptView` |

**Notification views** (require `hasNotificationFeatures()`):

| Key | View |
|-----|------|
| `notifications.list` | `MagicStarterNotificationsListView` |
| `notifications.preferences` | `MagicStarterNotificationPreferencesView` |

<a name="default-layout-keys"></a>
## Default Layout Keys

| Key | Layout | Purpose |
|-----|--------|---------|
| `layout.app` | `MagicStarterAppLayout` | Authenticated pages — sidebar, header, bottom nav |
| `layout.guest` | `MagicStarterGuestLayout` | Auth pages — centered card, minimal chrome |

<a name="default-modal-keys"></a>
## Default Modal Keys

| Key | Modal | Purpose |
|-----|-------|---------|
| `modal.confirm` | `MagicStarterConfirmDialog` | Generic confirmation with `ConfirmDialogVariant` (primary/danger/warning) |
| `modal.password_confirm` | `MagicStarterPasswordConfirmDialog` | Password-confirmation prompt with inline error handling |
| `modal.two_factor` | `MagicStarterTwoFactorModal` | Multi-step 2FA wizard (QR code, OTP confirm, recovery codes) |

<a name="overriding-views"></a>
## Overriding Views

Register your custom view builder using the `MagicStarter.view` accessor:

```dart
// In AppServiceProvider.boot()
MagicStarter.view.register(
  'auth.login',
  () => const MyCustomLoginView(),
);
```

Because `registerDefaultViews()` uses "register if absent" logic, overrides registered before the manager is instantiated take precedence automatically. Overrides registered after construction simply replace the existing builder.

> [!TIP]
> You only need to override the views you want to change. All other views continue using the plugin defaults.

<a name="overriding-layouts"></a>
## Overriding Layouts

Replace the default layout wrapper for auth or authenticated pages:

```dart
MagicStarter.view.registerLayout(
  'layout.guest',
  (child) => MyGuestLayout(child: child),
);
```

The layout builder receives the view widget as `child` and must render it somewhere in the layout tree.

```dart
MagicStarter.view.registerLayout(
  'layout.app',
  (child) => MyAppLayout(child: child),
);
```

> [!NOTE]
> When overriding `layout.app`, your custom layout is responsible for rendering navigation, header, and responsive behavior. The plugin's controllers still work — only the layout shell changes.

<a name="overriding-modals"></a>
## Overriding Modals

Replace the default modal for any registered key:

```dart
MagicStarter.view.registerModal(
  'modal.confirm',
  () => const MyCustomConfirmDialog(),
);
```

Modal builders follow the same "register if absent" pattern as views and layouts. Overrides registered before the manager is instantiated take precedence automatically.

> [!TIP]
> Override modals when you need a completely custom dialog design. For style-only changes (colors, fonts, borders), use `MagicStarter.useModalTheme()` instead — it requires no view overrides.

<a name="builder-slots"></a>
## Builder Slots

Slots allow host apps to inject custom widgets into specific sections of plugin views without overriding the entire view. Each view defines named insertion points (slots) that accept a `Widget Function(BuildContext)` builder.

### Registering a Slot

```dart
MagicStarter.view.slot('auth.login', 'header', (context) {
  return WText('Welcome back!', className: 'text-2xl font-bold text-center');
});

MagicStarter.view.slot('profile.settings', 'afterProfileSection', (context) {
  return MyCustomBillingSection();
});
```

The `slot()` method takes three arguments: the view key, the slot name, and a builder function. Internally, slots are stored under the compound key `'viewKey.slotName'` (e.g. `'auth.login.header'`).

### Checking and Building Slots

Views check for registered slots at build time:

```dart
// Inside a view's build method
final headerSlot = MagicStarter.view.buildSlot('auth.login', 'header', context);
if (headerSlot != null) ...[headerSlot, const WSpacer(className: 'h-4')],
```

`buildSlot()` returns `null` when no slot is registered, so views can safely use conditional spreads.

```dart
bool hasSlot(String viewKey, String slot)
Widget? buildSlot(String viewKey, String slot, BuildContext context)
```

### Available Slots

Each view defines its own slot names. Slot registration must happen before the view is built (ideally in `AppServiceProvider.boot()`). Slots are cleared by `registry.clear()` and re-registered views do not re-populate slots.

> [!TIP]
> Use slots for small, targeted customizations (a banner, a section, extra fields). For larger structural changes, override the entire view via `MagicStarter.view.register()`.

<a name="route-integration"></a>
## Route Integration

Routes resolve views and layouts through the registry rather than constructing widgets directly:

```dart
// Inside route registration
final view = MagicStarter.view.make('auth.login');
final page = MagicStarter.view.makeLayout('layout.guest', child: view);
```

This indirection is what makes the entire UI swappable. Route files never import view classes — they only reference string keys. The registry resolves the correct widget at runtime, whether it is the plugin default or a host app override.

```dart
// Typical route registration pattern
void registerMagicStarterAuthRoutes(MagicRouter router) {
  router.group(MagicStarterConfig.authPath(), (router) {
    router.route('/login', (context) {
      final view = MagicStarter.view.make('auth.login');
      return MagicStarter.view.makeLayout('layout.guest', child: view);
    });
  });
}
```

<a name="testing"></a>
## Testing

Call `MagicStarter.view.clear()` in `setUp()` to reset the registry between tests:

```dart
setUp(() {
  MagicApp.reset();
  Magic.flush();
  // Re-bind manager (constructor re-registers defaults)
  Magic.singleton('magic_starter', () => MagicStarterManager());
});
```

To test with a custom view:

```dart
test('uses custom login view when overridden', () {
  MagicStarter.view.register(
    'auth.login',
    () => const Text('Custom Login'),
  );

  final widget = MagicStarter.view.make('auth.login');
  expect(widget, isA<Text>());
});
```

To verify a missing key throws:

```dart
test('throws StateError for unregistered key', () {
  MagicStarter.view.clear();
  expect(
    () => MagicStarter.view.make('auth.login'),
    throwsStateError,
  );
});
```

<a name="related"></a>
## Related

- [MagicStarterManager](https://magic.fluttersdk.com/packages/starter/architecture/manager) — central singleton that holds the view registry and registers default views
- [MagicStarterServiceProvider](https://magic.fluttersdk.com/packages/starter/architecture/service-provider) — bootstrap entry point that instantiates the manager
- [Route Registration](https://magic.fluttersdk.com/packages/starter/basics/routes) — how routes consume the view registry
- [Magic Framework — IoC Container](https://magic.fluttersdk.com/getting-started/ioc-container) — singleton and factory binding reference
