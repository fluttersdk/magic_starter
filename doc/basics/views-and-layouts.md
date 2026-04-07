# Views and Layouts

- [Introduction](#introduction)
- [MagicStatefulView](#magicstatefulview)
- [View Lifecycle](#view-lifecycle)
- [State Rendering](#state-rendering)
- [Form Handling](#form-handling)
- [AppLayout](#applayout)
- [GuestLayout](#guestlayout)
- [Wind UI System](#wind-ui-system)
- [Dark Mode](#dark-mode)
- [View Registry](#view-registry)
- [Layout Registry](#layout-registry)
- [Feature-Gated Rendering](#feature-gated-rendering)
- [Zero Business Logic](#zero-business-logic)
- [Reusable Widgets](#reusable-widgets)

<a name="introduction"></a>
## Introduction

Magic Starter's view layer follows a strict separation of concerns: views handle rendering, controllers handle state and business logic. Every page-level view extends `MagicStatefulView<ControllerType>`, which binds the view to its controller singleton and provides lifecycle hooks. Two layout shells — `AppLayout` for authenticated pages and `GuestLayout` for auth pages — wrap all views. The entire UI is built with Wind UI components exclusively, with no direct Material widget usage beyond `Icons.*` references.

All views and layouts are registered in a string-keyed registry, making every screen overridable by the host application.

<a name="magicstatefulview"></a>
## MagicStatefulView

Page-level views extend `MagicStatefulView<ControllerType>` with a state class that extends `MagicStatefulViewState`:

```dart
class MagicStarterLoginView
    extends MagicStatefulView<MagicStarterAuthController> {
  const MagicStarterLoginView({super.key});

  @override
  State<MagicStarterLoginView> createState() => _MagicStarterLoginViewState();
}

class _MagicStarterLoginViewState extends MagicStatefulViewState<
    MagicStarterAuthController, MagicStarterLoginView> {

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (_) => _buildForm(),
      onEmpty: _buildForm(),
      onError: (message) => _buildForm(errorMessage: message),
    );
  }
}
```

The `MagicStatefulViewState` base class provides access to the controller singleton via `controller` and lifecycle hooks via `onInit()` and `onClose()`.

> [!NOTE]
> Views are NOT widgets like `MagicStarterNotificationDropdown` — those extend `StatelessWidget` or `StatefulWidget` directly. Only full-page views that need a controller binding use `MagicStatefulView`.

<a name="view-lifecycle"></a>
## View Lifecycle

Two lifecycle hooks are available in `MagicStatefulViewState`:

**`onInit()`** — Called once when the state is initialized. Use it to clear errors, set initial state, or trigger data fetches:

```dart
@override
void onInit() {
  controller.clearErrors();
  controller.setEmpty();
}
```

**`onClose()`** — Called when the state is disposed. Use it to clean up form data or local notifiers:

```dart
@override
void onClose() => form.dispose();
```

> [!TIP]
> For views with multiple forms (like the profile settings page), dispose all `MagicFormData` instances in `onClose()`. Field names must not collide across forms in the same view.

<a name="state-rendering"></a>
## State Rendering

Views delegate state-based rendering to `controller.renderState()`, which selects the appropriate builder based on the controller's current `MagicStateMixin` state:

```dart
@override
Widget build(BuildContext context) {
  return controller.renderState(
    (_) => _buildForm(),
    onEmpty: _buildForm(),
    onError: (message) => _buildForm(errorMessage: message),
  );
}
```

The first positional argument handles the success state (receives the state value). Named parameters:

| Parameter | When | Typical use |
|-----------|------|-------------|
| `onEmpty` | No data loaded yet | Show empty form or placeholder |
| `onError` | Controller called `setError()` | Show form with error banner |

Extract loading state at the top of your build method for conditional UI:

```dart
Widget _buildForm({String? errorMessage}) {
  final isLoading = controller.isLoading;

  return WDiv(
    className: 'flex flex-col gap-4 p-6',
    children: [
      if (errorMessage != null)
        WText(errorMessage, className: 'text-sm text-red-500'),
      // ... form fields
      WButton(
        onTap: isLoading ? null : _submit,
        className: 'w-full py-3 rounded-lg bg-primary text-white',
        child: WText(isLoading ? trans('common.loading') : trans('auth.login')),
      ),
    ],
  );
}
```

<a name="form-handling"></a>
## Form Handling

Forms are declared as `MagicFormData` instances with empty string defaults for text fields and typed defaults for non-string fields:

```dart
late final form = MagicFormData(
  {
    'email': '',
    'phone': '',
    'password': '',
    'remember_me': false,
  },
  controller: controller,
);
```

Access values with type-safe extraction:

```dart
// String fields
final email = form.get('email');

// Non-string fields — use value<T>()
final rememberMe = form.value<bool>('remember_me');
```

Form fields render with `WFormInput`:

```dart
WFormInput(
  form: form,
  name: 'email',
  label: trans('auth.email'),
  keyboardType: TextInputType.emailAddress,
)
```

Validate and submit:

```dart
Future<void> _submit() async {
  if (!form.validate()) return;
  await controller.doLogin(
    email: form.get('email'),
    password: form.get('password'),
    rememberMe: form.value<bool>('remember_me'),
  );
}
```

> [!NOTE]
> Query parameters needed before calling the controller (like password reset tokens) should be extracted in the view: `MagicRouter.instance.queryParameter('token') ?? ''`.

<a name="applayout"></a>
## AppLayout

`MagicStarterAppLayout` is the authenticated shell used for all protected pages. It provides a responsive layout with:

- **Desktop:** Sidebar with brand, team selector, navigation items, and user menu
- **Mobile:** Hamburger menu with drawer, header bar, and bottom navigation

```dart
MagicStarter.view.registerLayout(
  'layout.app',
  (child) => MagicStarterAppLayout(child: child),
);
```

The layout automatically starts notification polling when mounted (if notifications are enabled) and rebuilds on auth state changes via `MagicStarterAppLayout.refreshNotifier` and `Auth.stateNotifier`.

Key customization points:

```dart
// Custom header — replaces the default mobile header
MagicStarter.useHeader((context, isDesktop) {
  return MyCustomHeader(showMenuButton: !isDesktop);
});

// Custom navigation items
MagicStarter.useNavigation(
  mainItems: [
    MagicStarterNavItem(
      icon: Icons.dashboard_outlined,
      labelKey: 'nav.dashboard',
      path: '/',
    ),
  ],
  systemItems: [...],
  bottomItems: [...],
);

// Custom navigation colors and brand
MagicStarter.useNavigationTheme(
  MagicStarterNavigationTheme(
    activeItemClassName:
        'active:text-amber-500 active:bg-amber-500/10 dark:active:text-amber-400 dark:active:bg-amber-400/10',
    brandBuilder: (context) => Image.asset('assets/logo.png', height: 28),
    bottomNavActiveClassName: 'active:text-amber-500 dark:active:text-amber-400',
    avatarClassName: 'bg-amber-500/10 dark:bg-amber-400/10',
  ),
);
```

> [!TIP]
> `MagicStarterAppLayout.refreshNotifier` is a static `ValueNotifier<int>` that triggers layout rebuilds. It is bumped automatically by auth state changes. Do not poke it manually unless you have a specific reason to force a layout rebuild.

<a name="guestlayout"></a>
## GuestLayout

`MagicStarterGuestLayout` is a minimal centered wrapper for authentication pages (login, register, forgot password, reset password). It constrains content to 480px max width and provides scrolling:

```dart
MagicStarter.view.registerLayout(
  'layout.guest',
  (child) => MagicStarterGuestLayout(child: child),
);
```

The layout uses `wColor()` for theme-aware background colors and wraps content in `WDiv(className: 'p-4 lg:p-8')` for responsive padding.

> [!NOTE]
> Guest routes use `RouteTransition.none` — there is no animation between auth screens (login to register, etc.). This is intentional for a seamless form-flow experience.

<a name="wind-ui-system"></a>
## Wind UI System

All Magic Starter views use Wind UI components exclusively. The framework provides Tailwind-like utility classes through a `className` property:

| Component | Purpose | Example |
|-----------|---------|---------|
| `WDiv` | Container/layout | `WDiv(className: 'flex flex-col gap-4 p-6')` |
| `WText` | Typography | `WText('Title', className: 'text-lg font-bold text-gray-900')` |
| `WFormInput` | Form field | `WFormInput(form: form, name: 'email')` |
| `WButton` | Interactive button | `WButton(onTap: submit, className: 'bg-primary text-white')` |
| `WIcon` | Icon display | `WIcon(Icons.mail_outline, className: 'text-xl text-gray-500')` |
| `WAnchor` | Tap target | `WAnchor(onTap: () => ..., child: ...)` |
| `WSpacer` | Spacing | `WSpacer(className: 'h-4')` |
| `WPopover` | Overlay dropdown | `WPopover(triggerBuilder: ..., contentBuilder: ...)` |

For long class lists, use triple-quoted strings:

```dart
WDiv(
  className: '''
    rounded-2xl bg-white dark:bg-gray-800
    border border-gray-200 dark:border-gray-700
    shadow-sm p-6
  ''',
  child: ...,
)
```

> [!NOTE]
> Never use Material widgets (`Container`, `Text`, `ElevatedButton`, etc.) in Magic Starter views. The only exception is `Icons.*` for icon data references and `Switch.adaptive` where Wind UI does not yet provide a toggle.

<a name="dark-mode"></a>
## Dark Mode

Always pair light and dark mode classes. Wind UI supports the `dark:` prefix for dark mode variants:

```dart
WText(
  'Hello',
  className: 'text-gray-900 dark:text-white',
)

WDiv(
  className: '''
    bg-white dark:bg-gray-800
    border border-gray-200 dark:border-gray-700
  ''',
)
```

Common pairings used throughout Magic Starter:

| Light | Dark |
|-------|------|
| `bg-white` | `dark:bg-gray-800` |
| `bg-gray-50` | `dark:bg-gray-900` |
| `text-gray-900` | `dark:text-white` |
| `text-gray-500` | `dark:text-gray-400` |
| `text-gray-400` | `dark:text-gray-500` |
| `border-gray-200` | `dark:border-gray-700` |
| `border-gray-100` | `dark:border-gray-700` |
| `hover:bg-gray-100` | `dark:hover:bg-gray-800` |

> [!TIP]
> Theme toggling is available in the app layout sidebar via `context.windTheme.toggleTheme()`. Check the current mode with `context.windIsDark`.

<a name="view-registry"></a>
## View Registry

All views are registered by string key in `MagicStarterViewRegistry`. The host application can override any screen by re-registering under the same key:

```dart
// Register a view
MagicStarter.view.register(
  'auth.login',
  () => const MagicStarterLoginView(),
);

// Override with custom view
MagicStarter.view.register(
  'auth.login',
  () => const MyCustomLoginView(),
);

// Build a view by key
final widget = MagicStarter.view.make('auth.login');
```

Built-in view keys:

| Key | View |
|-----|------|
| `auth.login` | Login page |
| `auth.register` | Registration page |
| `auth.forgot_password` | Forgot password page |
| `auth.reset_password` | Reset password page |
| `auth.otp_verify` | OTP verification page |
| `auth.two_factor_challenge` | Two-factor challenge page |
| `profile.settings` | Profile settings page |
| `teams.create` | Team creation page |
| `teams.settings` | Team settings page |
| `teams.invitation_accept` | Team invitation acceptance page |
| `notifications.list` | Notification list page |
| `notifications.preferences` | Notification preferences page |

> [!NOTE]
> `MagicStarter.view.make(key)` throws `StateError` when the key is not registered. Always ensure views are registered before routes reference them.

<a name="layout-registry"></a>
## Layout Registry

Layouts follow the same registry pattern with a `child` parameter for wrapping content:

```dart
// Register a layout
MagicStarter.view.registerLayout(
  'layout.app',
  (child) => MagicStarterAppLayout(child: child),
);

// Override with custom layout
MagicStarter.view.registerLayout(
  'layout.app',
  (child) => MyCustomAppLayout(child: child),
);

// Build a layout wrapping content
final widget = MagicStarter.view.makeLayout(
  'layout.guest',
  child: loginView,
);
```

Built-in layout keys:

| Key | Layout |
|-----|--------|
| `layout.app` | Authenticated layout with sidebar/nav |
| `layout.guest` | Centered guest layout for auth pages |

> [!TIP]
> To test views in isolation, register a minimal layout: `MagicStarter.view.registerLayout('layout.guest', (child) => child);`

<a name="feature-gated-rendering"></a>
## Feature-Gated Rendering

Use conditional spreads to show or hide UI sections based on feature flags at build time:

```dart
WDiv(
  className: 'flex flex-col gap-4',
  children: [
    _buildEmailField(),
    _buildPasswordField(),
    if (MagicStarterConfig.hasRegistrationFeatures()) ...[
      WSpacer(className: 'h-2'),
      WAnchor(
        onTap: () => MagicRoute.to(MagicStarterConfig.registerPath()),
        child: WText(
          trans('auth.register_link'),
          className: 'text-sm text-primary',
        ),
      ),
    ],
    if (MagicStarterConfig.hasSocialLoginFeatures() &&
        MagicStarter.hasSocialLogin) ...[
      const MagicStarterSocialDivider(),
      MagicStarter.socialLoginBuilder!(context, isLoading),
    ],
  ],
)
```

> [!NOTE]
> Feature checks in views are read-only queries against the config. The view never toggles features — that is the domain of the CLI configure command or direct config edits.

<a name="zero-business-logic"></a>
## Zero Business Logic

Views must contain zero business logic. All rules:

- **No async operations** in views — `_submit()` calls a controller method and returns
- **No state decisions** — the controller decides what happens after a form submit (navigation, error handling)
- **No HTTP calls** — all API communication lives in controllers via `Http.post()`, `Http.get()`, etc.
- **No direct navigation** — controllers use `NavigatesRoutes` mixin; views never call `context.go()`
- **Local UI state only** — password visibility toggles (`_obscurePassword`), phone/email toggle in "both" mode, section-level loading spinners via local `ValueNotifier<bool>` fields

```dart
// CORRECT: view delegates to controller
Future<void> _submit() async {
  if (!form.validate()) return;
  await controller.doLogin(
    email: form.get('email'),
    password: form.get('password'),
  );
}

// WRONG: view makes API call
Future<void> _submit() async {
  final response = await Http.post('/auth/login', data: {...}); // Never do this
}
```

---

**Related Links:**

- [Controllers](https://magic.fluttersdk.com/packages/starter/basics/controllers)
- [Notifications](https://magic.fluttersdk.com/packages/starter/basics/notifications)
- [Routes](https://magic.fluttersdk.com/packages/starter/basics/routes)
- [Configuration](https://magic.fluttersdk.com/packages/starter/getting-started/configuration)
- [Wind UI](https://magic.fluttersdk.com/packages/wind)

---

<a name="reusable-widgets"></a>
## Reusable Widgets

Magic Starter exports standalone UI widgets that consumer apps can import and use directly without duplicating them locally. None of these widgets depend on internal controllers — they accept plain callbacks.

All widgets are exported from `package:magic_starter/magic_starter.dart`.

### MagicStarterPageHeader

Full-width page header with responsive `sm:flex-row` layout and a `border-b` separator. All parameters beyond `title` are optional:

```dart
MagicStarterPageHeader(
  title: trans('projects.title'),
  subtitle: trans('projects.manage_subtitle'),  // optional
  leading: const BackButton(),                  // optional
  actions: [                                    // optional
    WButton(onTap: _onCreate, child: WText(trans('projects.new'))),
  ],
)
```

Detail view with status badge and always-inline layout:

```dart
MagicStarterPageHeader(
  title: 'Task Details',
  leading: Icon(Icons.arrow_back),
  titleSuffix: StatusBadge(status: 'done'),
  inlineActions: true,
  actions: [WButton(onTap: () {}, child: WText('Edit'))],
)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | `String` | ✅ | Main heading text |
| `subtitle` | `String?` | — | Secondary line below the title |
| `leading` | `Widget?` | — | Widget placed before the title (e.g. back button) |
| `actions` | `List<Widget>?` | — | Row of trailing action widgets (e.g. buttons) |
| `titleSuffix` | `Widget?` | — | Optional widget rendered inline after the title (e.g. status badge). Stays on the same row as the title text. |
| `inlineActions` | `bool` | — | When `true`, forces single-row layout on all screen sizes (no mobile stacking). Useful for detail views where actions must stay inline with the title. |

### MagicStarterCard

Card wrapper with an optional `title` slot, `noPadding` mode for full-bleed content, and three visual variants:

| Variant | Background | Border | Shadow |
|---------|-----------|--------|--------|
| `CardVariant.surface` _(default)_ | `bg-white dark:bg-gray-800` | ✅ `border-gray-200` | — |
| `CardVariant.inset` | `bg-gray-50 dark:bg-gray-900` | ✅ `border-gray-200` | — |
| `CardVariant.elevated` | `bg-white dark:bg-gray-800` | — | ✅ `shadow-md` |

```dart
// Default padded surface card with title
MagicStarterCard(
  title: 'Team Members',
  child: memberList,
)

// Full-bleed elevated card (e.g. data table)
MagicStarterCard(
  variant: CardVariant.elevated,
  noPadding: true,
  child: dataTable,
)

// Inset danger-zone card
MagicStarterCard(
  variant: CardVariant.inset,
  title: 'Danger Zone',
  child: deleteButton,
)
```

When `noPadding` is `true` and a `title` is provided, the title automatically receives `px-6 pt-6 pb-3` spacing so it aligns with full-bleed row content that uses `px-6`.

### MagicStarterConfirmDialog

Generic confirmation dialog with variant-driven styling. Uses `MagicStarterDialogShell` internally for sticky header/footer layout. All classNames are read from `MagicStarter.manager.modalTheme` at build time.

```dart
final confirmed = await MagicStarterConfirmDialog.show(
  context,
  title: trans('teams.remove_member_label'),
  description: trans('teams.confirm_remove_member'),
  confirmLabel: trans('teams.remove'),
  variant: ConfirmDialogVariant.danger,
  onConfirm: () async {
    await TeamService.removeMember(memberId);
  },
);

if (confirmed) _refreshMembers();
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `title` | `String` | **required** | Dialog title text |
| `description` | `String?` | `null` | Optional description below the title |
| `confirmLabel` | `String?` | `trans('common.confirm')` | Confirm button label |
| `cancelLabel` | `String?` | `trans('common.cancel')` | Cancel button label |
| `variant` | `ConfirmDialogVariant` | `.primary` | Button styling variant |
| `onConfirm` | `Future<void> Function()?` | `null` | Async action on confirm — dialog shows loading state |

**Variants:**

| Variant | Use case | Confirm button style |
|---------|----------|---------------------|
| `ConfirmDialogVariant.primary` | Neutral confirmations | `theme.primaryButtonClassName` |
| `ConfirmDialogVariant.danger` | Destructive actions (delete, remove, revoke) | `theme.dangerButtonClassName` |
| `ConfirmDialogVariant.warning` | Caution actions (leave, archive) | `theme.warningButtonClassName` |

Returns `true` when confirmed, `false` when cancelled or dismissed.

### MagicStarterPasswordConfirmDialog

Standalone password-confirmation dialog. Pass an `onConfirm` callback that returns `null` on success or an error string to display inline. The dialog stays open on error; it closes automatically on success and returns `true`.

```dart
final confirmed = await MagicStarterPasswordConfirmDialog.show(
  context,
  title: trans('projects.delete_title'),
  description: trans('projects.delete_description'),
  onConfirm: (password) async {
    // Return null to confirm, or an error string on failure.
    return await ProjectService.delete(id, password: password);
  },
);

if (confirmed) _removeProject();
```

Use with no `onConfirm` if you only need a confirmation gate (e.g. before a local-only destructive action):

```dart
final confirmed = await MagicStarterPasswordConfirmDialog.show(context);
```

> [!NOTE]
> Without an `onConfirm` callback, the dialog closes with `true` as soon as the user taps Confirm (no async validation is performed).

### MagicStarterTwoFactorModal

Multi-step 2FA wizard modal. Step 1 displays the QR code and OTP input; Step 2 displays recovery codes with a copy button. The modal advances to Step 2 only when `onConfirm` returns `true`.

```dart
final success = await MagicStarterTwoFactorModal.show(
  context,
  setupData: {
    'secret': '...',
    'qr_svg': '...',         // raw SVG string
    'recovery_codes': [...], // list of strings
  },
  onConfirm: (code) async {
    return await TwoFactorService.confirmSetup(code);
  },
);
```

| `setupData` key | Type | Description |
|-----------------|------|-------------|
| `secret` | `String` | Manual entry key shown below the QR code |
| `qr_svg` | `String` | Raw SVG markup rendered via `WSvg` with `preserve-colors` |
| `recovery_codes` | `List<dynamic>` | Backup codes displayed on Step 2 |

The modal can also be used for standalone re-authentication (e.g. before a sensitive action) by supplying minimal `setupData` with only the fields the flow needs.

### Other Exported Widgets

| Widget | Description |
|--------|-------------|
| `MagicStarterAuthFormCard` | Centered card wrapper (max 480 px) for auth-adjacent screens — invite accept, onboarding, etc. Accepts `title`, `subtitle`, optional `errorMessage`, and a theme-toggle button. |
| `MagicStarterTimezoneSelect` | Searchable timezone dropdown backed by `GET /timezones?search=...`. Debounces search at 300 ms and always includes the pre-selected value in options. |
| `MagicStarterTeamSelector` | Current-team switcher dropdown. Requires `MagicStarter.teamResolver` to be registered. `compact` mode hides the team name label. |
| `MagicStarterUserProfileDropdown` | Circular avatar menu showing signed-in user info, profile links, and logout. Supports a custom `triggerBuilder`. |
| `MagicStarterNotificationDropdown` | Bell-icon dropdown backed by a `Stream<List<DatabaseNotification>>`. Displays live unread badge, color-coded icons, and mark-as-read callbacks. |
| `MagicStarterSocialDivider` | Horizontal "Or continue with" divider for auth forms. No parameters — pure presentation. |
| `MagicStarterHideBottomNav` | `InheritedWidget` that signals `MagicStarterAppLayout` to hide the mobile bottom navigation bar. Wrap a route layout with this widget and check `MagicStarterHideBottomNav.of(context)` in the layout's build method. |
