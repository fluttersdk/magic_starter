# Views and Layouts

- [Introduction](#introduction)
- [MagicStatefulView](#magicstatefulview)
- [View Lifecycle](#view-lifecycle)
- [State Rendering](#state-rendering)
- [Form Handling](#form-handling)
- [AppLayout](#applayout)
- [GuestLayout](#guestlayout)
- [Page Chrome](#page-chrome)
- [Wind UI System](#wind-ui-system)
- [Dark Mode](#dark-mode)
- [View Registry](#view-registry)
- [Layout Registry](#layout-registry)
- [Overriding the App Shell](#overriding-the-app-shell)
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
> Views are NOT widgets like `MSUserProfileDropdown` — those extend `StatelessWidget` or `StatefulWidget` directly. Only full-page views that need a controller binding use `MagicStatefulView`.

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

// Sidebar footer — custom widget between nav items and user menu
MagicStarter.useSidebarFooter((context) {
  return MyVersionBadge();
});

// Custom logo/brand — replaces default app name text
// MagicStarter.useNavigationTheme(brandBuilder: ...) handles this

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

### Where the sidebar starts, and where it grows labels

Three fields on `MagicStarterLayoutTheme` decide the shell's shape. The first two are breakpoints, named as keys of the Wind theme's `screens` map (`sm md lg xl 2xl` by default) rather than as pixel counts; the third is a width in logical pixels:

| Field | Default | What it decides |
|-------|---------|-----------------|
| `navigationBreakpoint` | `'lg'` | Breakpoint from which the sidebar replaces the drawer and the bottom bar |
| `sidebarExpandedBreakpoint` | `'lg'` | Breakpoint from which the sidebar carries labels beside its icons |
| `sidebarCompactWidth` | `80` | Width in logical pixels of the sidebar while it is compact |

Between the two breakpoints the sidebar renders compact: `sidebarCompactWidth` wide, icons only, and every text label dropped, because a label at that width would be clipped rather than shortened. That is the app name in the brand bar, the nav item labels, the system section's name, and the user's name and email, which falls back to the same avatar trigger the mobile header mounts. What a host supplies itself, `brandBuilder` and `sidebarFooterBuilder`, is passed through untouched: only the host knows whether its own widget fits an icon column. A host whose wordmark does not fit sets `MagicStarterNavigationTheme.compactBrandBuilder` to a glyph, and the compact rail shows that instead.

A name the Wind theme does not carry throws a `StateError` naming the field and listing the valid keys. `wScreenIs` answers false for an unknown key, so a typo would otherwise pin the shell to its narrow form at every width with nothing to read.

The shipped defaults leave the two breakpoints equal, so the compact form never fires until a host lowers one of them:

```dart
// An icon rail from 640 px, labels from 1024 px.
MagicStarter.useLayoutTheme(
  const MagicStarterLayoutTheme(
    navigationBreakpoint: 'sm',
    sidebarExpandedBreakpoint: 'lg',
  ),
);
```

Take care lowering `sidebarCompactWidth`. Its floor is the compact team selector rather than the nav icon: `MSTeamSelector`'s compact trigger is `mx-3 p-2` around a `w-8` avatar, which is 72 logical pixels, and `sidebarClassName`'s own `border-r` takes one more out of the box. 72 was measured overflowing by exactly 1 pixel, which is why the default is 80.

### Letting the viewer collapse the sidebar

Two more fields hand the compact form to the viewer on a window wide enough for labels:

| Field | Default | What it decides |
|-------|---------|-----------------|
| `sidebarCollapsible` | `false` | Whether a toggle above the user menu collapses the labelled sidebar to its compact form and back |
| `sidebarCollapsedByDefault` | `false` | Whether a collapsible sidebar starts compact before the viewer has chosen |

The toggle appears only at or above `sidebarExpandedBreakpoint`. Below it the sidebar is compact because the window cannot spare `sidebarWidth`, so a toggle there would promise an expansion the shell will not make. `sidebarCollapsedByDefault` is ignored unless the sidebar is collapsible: a default the viewer cannot undo would be a rail they are stuck with, and `sidebarExpandedBreakpoint` already expresses that.

The viewer's choice is remembered through Magic's `Cache` under `magic_starter.sidebar_collapsed`, written with a ten year TTL because the cache has no `forever` and its own default of an hour would hand the viewer the default back the next morning. A host that binds no cache keeps the choice in memory for the life of the shell. A remembered choice wins over `sidebarCollapsedByDefault`; changing the default moves only the viewers who never touched the toggle.

The toggle reads `nav.collapse_sidebar` and `nav.expand_sidebar`, and names itself with the second through `semanticLabel` while it is icon-only. Both keys ship in the install stub; a host installed before 0.0.34 adds them to its own language files.

```dart
// Icons only until the viewer asks for labels, with a glyph for the rail.
MagicStarter.useLayoutTheme(
  const MagicStarterLayoutTheme(
    sidebarCollapsible: true,
    sidebarCollapsedByDefault: true,
  ),
);

MagicStarter.useNavigationTheme(
  MagicStarterNavigationTheme(
    brandBuilder: (context) => const MyLogoLockup(),
    compactBrandBuilder: (context) => const MyLogoGlyph(),
  ),
);
```

### A focus ring for a keyboard or a remote

`MagicStarterNavigationTheme.focusItemClassName` is applied to every navigation item the shell draws: the sidebar and drawer items beside their active and hover classNames, and the bottom bar's items too, so a small window is lit the same way a wide one is. Each token carries the `focus:` prefix; the item already sits inside a `WAnchor`, so Wind lights them the moment it holds primary focus. It defaults to `''`, which is the shipped shell's no-ring behaviour, and an app driven by arrow keys or a television remote wants it set:

```dart
MagicStarter.useNavigationTheme(
  const MagicStarterNavigationTheme(
    focusItemClassName: 'focus:ring-2 focus:ring-primary focus:ring-offset-2',
  ),
);
```

### The box the route child is handed

The shell wraps the route child in one `WDiv`, and two fields on `MagicStarterLayoutTheme` own it:

| Field | Default | What it decides |
|-------|---------|-----------------|
| `contentClassName` | `'flex-1 overflow-y-auto'` | The content area's own className |
| `contentScrollPrimary` | `true` | Whether that area attaches to the ambient `PrimaryScrollController` |

The default scrolls the child, which hands it an unbounded height. That suits a page as tall as its content and is wrong for a fill-shaped screen: an `h-full` column whose body takes the slack and scrolls inside itself resolves its height against infinity, fails to lay out, and renders nothing at all. A host whose screens are all that shape, which is what a television guide or a media catalogue is, sets:

```dart
MagicStarter.useLayoutTheme(
  const MagicStarterLayoutTheme(
    contentClassName: 'flex-1 min-h-0',
    contentScrollPrimary: false,
  ),
);
```

Set the two together. Wind reads `scrollPrimary` only where it builds a scroll view, so leaving it true beside a non-scrolling className claims nothing and is inert; it matters the moment the className scrolls horizontally, or scrolls in a way that belongs to the page rather than to the shell. Two `primary: true` scrollables in one tree contend for the single controller.

> [!NOTE]
> Every view this package ships goes through `MSPageScaffold`, which brings its own `SingleChildScrollView(primary: false)`. So the default nests two scrollables on each of them. The default stays as it is, because changing it would move layout for every existing host, but a host that puts every one of its own pages through `MSPageScaffold` can set `'flex-1 min-h-0'` and lose nothing.

### An immersive route

`MagicStarterHideBottomNav` drops the mobile bottom bar. `MagicStarterHideChrome` drops all of the chrome, so a player, a viewfinder or a map paints the whole window:

```dart
MagicRoute.group(
  layout: (child) => MagicStarterHideChrome(
    child: MagicStarter.view.makeLayout('layout.app', child: child),
  ),
  layoutId: 'app.immersive',
  routes: () { ... },
);
```

No sidebar, no drawer, no header and no bottom bar. The route also gets the window with no safe-area inset and without the shell's own scroll container, since a surface that sizes itself cannot be handed unbounded height. The shell stays in the tree: its layout state, its notification polling and its auth listeners all survive the route, which wrapping the route in a bare page would throw away.

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

<a name="page-chrome"></a>
## Page Chrome

The layout shell owns the sidebar, the header, and the scroll region. What is left is page chrome: how wide the content column is, how far it sits from the edges, and where the page title goes. Two components own that, and every authenticated page goes through one of them.

`MSPageScaffold` is the full treatment. Give it a title and a list of sections, and it renders the page surface, its own vertical scroll, the shared content geometry, a unified `MSPageHeader`, and a `gap-6` column for the sections:

```dart
MSPageScaffold(
  title: trans('teams.settings'),
  subtitle: trans('teams.settings_subtitle'),
  children: [
    MSCard(title: 'General', child: generalForm),
    MSCard(title: 'Members', child: memberList),
  ],
)
```

A sub-page adds a back affordance, and a top-level page can put an action next to the title:

```dart
MSPageScaffold(
  title: trans('notifications.title'),
  actions: [markAllAsReadButton],
  children: [MSCard(noPadding: true, child: notificationList)],
)

MSPageScaffold(
  title: trans('profile.settings'),
  backLabel: trans('magic_starter.nav.settings'),
  backFallback: MagicStarterConfig.settingsHubRoute(),
  children: [profileForm],
)
```

`MSPageContainer` is the geometry alone: width cap, edge margins, vertical rhythm, and a horizontal safe-area guard. Reach for it when the page brings its own header or scrolls its own way, which is the usual shape in a host app:

```dart
MSPageContainer(
  children: [
    MSPageHeader(title: 'Monitors', actions: [newMonitorButton]),
    monitorTable,
  ],
)
```

Neither component decides the numbers. They read `MagicStarter.manager.pageContainerClassName`, which the host sets once (see [Page Geometry](https://magic.fluttersdk.com/packages/starter/architecture/manager#page-geometry)). That is what makes a starter account page and a host domain page line up inside the same shell.

> [!WARNING]
> Do not open a page with its own `WDiv(className: 'p-4 lg:p-6 flex flex-col gap-6')`. It looks harmless and it is how the settings, team, and notification pages ended up at three different widths in the same app: one capped at `max-w-7xl`, one at `max-w-6xl`, and one at nothing at all. A page that needs to tune one axis passes `className` to `MSPageContainer` instead.

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
> Never use Material widgets (`Container`, `Text`, `ElevatedButton`, etc.) in Magic Starter views. The only exception is `Icons.*` for icon data references and `MSSwitch.adaptive` where Wind UI does not yet provide a toggle.

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
> Theme toggling is available in the user profile dropdown menu via `context.windTheme.toggleTheme()`. Check the current mode with `context.windIsDark`.

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

> [!NOTE]
> `MagicStarter.view.make(key)` throws `StateError` when the key is not registered. Always ensure views are registered before routes reference them.

> [!NOTE]
> `notifications.list` and `notifications.preferences` are NOT registered on `MagicStarter.view`. Those two screens belong to `magic_notifications` and are registered on its own `Notify.view` (same shape: `register` / `has` / `make` / `slot` / `buildSlot` / `clear`); see [Notifications](notifications.md).

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

<a name="overriding-the-app-shell"></a>
## Overriding the App Shell

All account, profile, team, and settings routes render through the `layout.app` key. Out of the box, `MagicStarterServiceProvider` registers `MagicStarterAppLayout` under that key, so a fresh install already renders those routes in a working shell (sidebar/nav on desktop, drawer + bottom nav on mobile) with no extra setup.

An app that already has its own navigation chrome (its own sidebar, its own bottom nav) does not want starter routes rendering inside a second, different shell on top of its own. That is the case this seam exists for: re-register `layout.app` with your own shell and every starter route (login-gated pages, profile settings, team management, notifications) renders inside it instead:

```dart
MagicStarter.view.registerLayout(
  'layout.app',
  (child) => MyAppShell(child: child),
);
```

Call this from your own `AppServiceProvider`'s `boot()` method, alongside other startup customization such as `MagicStarter.useNavigation()` or `MagicStarter.useHeader()`.

`registerLayout()` always overwrites whatever is currently registered under the key: the default registration in `MagicStarterManager` is conditional (`if (!hasLayout(key))`), but `registerLayout()` itself is not. Since the default is registered synchronously the first time the `magic_starter` singleton is resolved (before your own code runs), your override always lands after it and always wins, whether you call `registerLayout()` early or late in your app's boot sequence. There is no ordering to get wrong.

> [!NOTE]
> Do not add a second layout key for this. `layout.app` is the only authenticated-shell key the starter resolves; overriding it in place is the supported pattern, not adding a new one alongside it.

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
      const MSSocialDivider(),
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

### MSPageHeader

Full-width page header with responsive `sm:flex-row` layout and a `border-b` separator. All parameters beyond `title` are optional:

```dart
MSPageHeader(
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
MSPageHeader(
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

### MSCard

Card wrapper with an optional `title` slot, `noPadding` mode for full-bleed content, and three visual variants:

| Variant | Background | Border | Shadow |
|---------|-----------|--------|--------|
| `CardVariant.surface` _(default)_ | `bg-white dark:bg-gray-800` | ✅ `border-gray-200` | — |
| `CardVariant.inset` | `bg-gray-50 dark:bg-gray-900` | ✅ `border-gray-200` | — |
| `CardVariant.elevated` | `bg-white dark:bg-gray-800` | — | ✅ `shadow-md` |

```dart
// Default padded surface card with title
MSCard(
  title: 'Team Members',
  child: memberList,
)

// Full-bleed elevated card (e.g. data table)
MSCard(
  variant: CardVariant.elevated,
  noPadding: true,
  child: dataTable,
)

// Inset danger-zone card
MSCard(
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
| `MagicStarterTimezoneSelect` | Searchable timezone dropdown backed by `GET /timezones?search=...`. Debounces search at 300 ms and always includes the pre-selected value in options. Pages through the endpoint on scroll and resets its cursor when the menu reopens, since the reopen restores the unfiltered list; a response whose list the reopen already replaced is dropped rather than written. |
| `MSTeamSelector` | Current-team switcher dropdown. Requires `MagicStarter.teamResolver` to be registered. `compact` mode hides the team name label. |
| `MSAvatar` | A photo with a fallback, clipped to whatever shape `className` asks for. Owns no size, shape or colour, because those differ per surface; the fallback is a WIDGET so a host keeps its own initials rule. Falls back on an empty url and on a load error. |
| `MSUserProfileDropdown` | Circular avatar menu showing signed-in user info, profile links, theme toggle, and logout. Supports a custom `triggerBuilder`. |
| `MSSocialDivider` | Horizontal "Or continue with" divider for auth forms. No parameters — pure presentation. |
| `MagicStarterHideBottomNav` | `InheritedWidget` that signals `MagicStarterAppLayout` to hide the mobile bottom navigation bar. Wrap a route layout with this widget and check `MagicStarterHideBottomNav.of(context)` in the layout's build method. |
| `MagicStarterHideChrome` | `InheritedWidget` that signals `MagicStarterAppLayout` to hide the whole shell chrome: sidebar, drawer, header and bottom bar, plus the safe-area inset and the shell's scroll container. Same wrapping shape, read with `MagicStarterHideChrome.of(context)`. See [An immersive route](#applayout). |

> [!NOTE]
> The bell-icon dropdown is not in this table. It moved to `magic_notifications` as `NotificationDropdown`; see [Notifications](notifications.md).
