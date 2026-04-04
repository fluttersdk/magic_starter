# Controllers

- [Introduction](#introduction)
- [Lazy Singleton Pattern](#lazy-singleton-pattern)
- [MagicController and MagicStateMixin](#magiccontroller-and-magicstatemixin)
- [Controller Lifecycle](#controller-lifecycle)
- [View Binding](#view-binding)
- [Consumer App Pattern](#consumer-app-pattern)
- [View Integration for Consumer Apps](#view-integration-for-consumer-apps)
- [Fine-Grained Reactivity](#fine-grained-reactivity)
- [Testing Controllers](#testing-controllers)
- [Related](#related)

<a name="introduction"></a>
## Introduction

Controllers in magic_starter are the single source of truth for business logic and async state. Every page-level view delegates all API calls, state transitions, and navigation to its paired controller. Views contain zero business logic — they render state and forward user input.

The plugin ships seven controllers covering auth, profile, teams, notifications, OTP, guest auth, and newsletter flows. All seven share the same structural core: lazy singleton via `Magic.findOrPut` and `MagicController + MagicStateMixin` for state. Controllers that handle page navigation also mix in `NavigatesRoutes` (auth, guest auth, profile), while others (notification, team, newsletter) manage state without navigation concerns. Consumer apps building custom features on top of magic_starter should follow the same conventions for consistency.

<a name="lazy-singleton-pattern"></a>
## Lazy Singleton Pattern

Every controller exposes a single static accessor that delegates instantiation to the Magic IoC container:

```dart
class MagicStarterAuthController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests, NavigatesRoutes {
  static MagicStarterAuthController get instance =>
      Magic.findOrPut(MagicStarterAuthController.new);
}
```

`Magic.findOrPut` checks whether a binding already exists under the controller's runtime type. On first access it calls `MagicStarterAuthController.new` (the default constructor), stores the result, and returns it. Every subsequent call returns the cached instance. This means a controller is created only when first needed and lives for the lifetime of the IoC container.

The same pattern across all seven controllers:

| Controller | Singleton key |
|------------|---------------|
| `MagicStarterAuthController.instance` | `Magic.findOrPut(MagicStarterAuthController.new)` |
| `MagicStarterProfileController.instance` | `Magic.findOrPut(MagicStarterProfileController.new)` |
| `MagicStarterTeamController.instance` | `Magic.findOrPut(MagicStarterTeamController.new)` |
| `MagicStarterNotificationController.instance` | `Magic.findOrPut(MagicStarterNotificationController.new)` |
| `MagicStarterOtpController.instance` | `Magic.findOrPut(MagicStarterOtpController.new)` |
| `MagicStarterGuestAuthController.instance` | `Magic.findOrPut(MagicStarterGuestAuthController.new)` |
| `MagicStarterNewsletterController.instance` | `Magic.findOrPut(MagicStarterNewsletterController.new)` |

> [!NOTE]
> `Magic.findOrPut` is distinct from `Magic.singleton`. `singleton` registers a factory eagerly so the container can resolve it by key string. `findOrPut` uses the concrete type as the implicit key and creates the instance on first access — no upfront registration required.

<a name="magiccontroller-and-magicstatemixin"></a>
## MagicController and MagicStateMixin

All magic_starter controllers extend `MagicController` and mix in `MagicStateMixin<T>`.

`MagicController` extends `ChangeNotifier`, so every controller is a `Listenable`. `MagicStateMixin<T>` adds a typed state machine on top of it.

The mixin provides these state-transition methods and read properties:

| Method / Property | Description |
|-------------------|-------------|
| `setLoading()` | Transitions to loading state, calls `notifyListeners()` |
| `setSuccess(T value)` | Transitions to success state with a typed payload, notifies listeners |
| `setError(String message)` | Transitions to error state with a message, notifies listeners |
| `setEmpty()` | Resets to empty/idle state, notifies listeners |
| `clearErrors()` | Clears any error state without changing the primary state |
| `isLoading` | `true` while the controller is in loading state |
| `isSuccess` | `true` after a successful transition |
| `hasErrors` | `true` when the controller holds an error message |
| `renderState(builder, {onEmpty, onError})` | Widget factory — dispatches to the correct builder based on current state |

The type parameter `T` is the success payload type. `MagicStateMixin<bool>` is the most common pattern because many controllers only need to signal success or failure, not carry data. However, some controllers use a different success payload type (or omit the explicit type argument) and call `setSuccess(...)` with non-boolean data when the state itself needs to carry a result. Controllers may also expose structured data through `ValueNotifier<T>` fields alongside `MagicStateMixin<T>` when that produces a cleaner API.

A standard async action looks like this:

```dart
Future<void> doLogin({
  required String email,
  required String password,
}) async {
  setLoading();
  clearErrors();

  try {
    final response = await Http.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    if (!response.successful) {
      setError(trans('auth.login_failed'));
      return;
    }

    await Auth.restore();
    setSuccess(true);
  } catch (e, stackTrace) {
    Log.error('[MagicStarterAuthController.doLogin] $e\n$stackTrace');
    setError(trans('errors.unexpected'));
  }
}
```

> [!TIP]
> Always call `setLoading()` and `clearErrors()` at the top of an async action, before the first `await`. This gives the UI immediate feedback and clears stale error messages from the previous run.

<a name="controller-lifecycle"></a>
## Controller Lifecycle

Because `Magic.findOrPut` stores the instance in the IoC container, a controller outlives any individual view. A user may navigate away from the login screen and back — `MagicStarterAuthController.instance` returns the same object both times.

Practical consequences:

- State carries over between visits. If a controller is in the error state when the view is dismissed, it will still be in the error state the next time the view mounts. Reset state in the view's `onInit()` hook (see [View Binding](#view-binding)).
- `ValueNotifier` fields must be disposed when the controller is no longer needed. In tests, call `controller.dispose()` in `tearDown`. In production, controllers that live for the full app session typically do not need explicit disposal.
- The container is reset by calling `Magic.flush()` or `MagicApp.reset()`, which replaces the IoC container entirely. After a reset, the next call to `Magic.findOrPut` creates a fresh instance. This is the standard test isolation mechanism.

<a name="view-binding"></a>
## View Binding

Every page-level view in magic_starter extends `MagicStatefulView<ControllerType>`. The base class resolves the controller via `Magic.findOrPut` and exposes it through the `controller` getter, available throughout the state class.

```dart
class MagicStarterLoginView
    extends MagicStatefulView<MagicStarterAuthController> {
  const MagicStarterLoginView({super.key});

  @override
  State<MagicStarterLoginView> createState() => _MagicStarterLoginViewState();
}

class _MagicStarterLoginViewState extends MagicStatefulViewState<
    MagicStarterAuthController, MagicStarterLoginView> {
  late final form = MagicFormData(
    {'email': '', 'password': '', 'remember_me': false},
    controller: controller,
  );

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() => form.dispose();

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

`MagicStatefulViewState` lifecycle hooks:

| Hook | Called when | Typical use |
|------|-------------|-------------|
| `onInit()` | After `initState()` — view is mounted | Reset controller state, set initial empty state |
| `onClose()` | In `dispose()` — view is removed | Dispose `MagicFormData`, cancel subscriptions |

The view automatically subscribes to `controller` (via `ChangeNotifier`) and calls `setState` on every `notifyListeners`, so `renderState` always reflects the latest controller state without any manual subscription code.

<a name="consumer-app-pattern"></a>
## Consumer App Pattern

Consumer apps building custom features should pick a registration strategy based on their initialization requirements.

### Option 1 — Lazy Singleton (default recommendation)

Use `Magic.findOrPut` for controllers that require no upfront initialization. The instance is created on first access and cached for the app session.

```dart
class ProjectController extends MagicController
    with MagicStateMixin<bool> {
  static ProjectController get instance =>
      Magic.findOrPut(ProjectController.new);

  Future<void> loadProjects() async {
    setLoading();
    clearErrors();

    try {
      final response = await Http.get('/projects');
      if (!response.successful) {
        setError('Failed to load projects.');
        return;
      }
      setSuccess(true);
    } catch (e, stackTrace) {
      Log.error('[ProjectController.loadProjects] $e\n$stackTrace');
      setError('An unexpected error occurred.');
    }
  }
}
```

No registration in `AppServiceProvider` is needed. The first view that accesses `ProjectController.instance` initialises it.

### Option 2 — Eager Registration in AppServiceProvider.boot()

Register the controller explicitly when it needs to connect to a WebSocket, subscribe to an event, or perform auth-dependent work at startup — before any view has mounted.

```dart
// In AppServiceProvider.boot()
@override
Future<void> boot() async {
  final controller = Magic.findOrPut(ProjectController.new);
  await controller.connectRealtime();
}
```

The explicit `Magic.findOrPut` call in `boot()` forces instantiation and stores the singleton. Later calls from views return the same already-initialised instance.

### Option 3 — Per-View Instance (form / wizard state)

When state should not persist across view visits — multi-step forms, wizards, ephemeral UI — use a plain `ChangeNotifier` created inside the `StatefulWidget`. No IoC container involvement.

```dart
class ProjectFormState extends ChangeNotifier {
  String name = '';
  bool isSubmitting = false;

  void setName(String value) {
    name = value;
    notifyListeners();
  }
}

class _ProjectCreateViewState extends State<ProjectCreateView> {
  late final _state = ProjectFormState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }
}
```

### Decision Table

| Scenario | Strategy |
|----------|----------|
| Standard CRUD — loaded on demand | Lazy singleton (`Magic.findOrPut`) |
| Needs WebSocket / boot-time init | Eager via `AppServiceProvider.boot()` |
| Multi-step form — state should reset on dismiss | Per-view `ChangeNotifier` |
| Shared state accessed from multiple screens | Lazy singleton |
| Controller tied to a single, ephemeral modal | Per-view `ChangeNotifier` |

<a name="view-integration-for-consumer-apps"></a>
## View Integration for Consumer Apps

Consumer apps have two options for wiring a controller to a view.

### Option A — MagicStatefulView (auto-listens)

Extend `MagicStatefulView<T>` to get the controller resolved and subscribed automatically. This matches the pattern used by most plugin views and is the recommended choice; `MagicStarterNotificationsListView` is the current exception — it is implemented as a plain `StatefulWidget` that manages state locally.

```dart
class ProjectListView extends MagicStatefulView<ProjectController> {
  const ProjectListView({super.key});

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState
    extends MagicStatefulViewState<ProjectController, ProjectListView> {
  @override
  void onInit() => controller.loadProjects();

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (_) => _buildList(),
      onEmpty: const WText('No projects yet.'),
      onError: (message) => WText(message),
    );
  }
}
```

### Option B — StatefulWidget + Magic.find (more control)

Use a plain `StatefulWidget` and resolve the controller manually when you need more control over subscription granularity or want to avoid the full `MagicStatefulView` lifecycle.

```dart
class _ProjectListViewState extends State<ProjectListView> {
  late final ProjectController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Magic.findOrPut(ProjectController.new);
    _controller.addListener(_onControllerUpdate);
    _controller.loadProjects();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() => setState(() {});

  @override
  Widget build(BuildContext context) { /* ... */ }
}
```

> [!NOTE]
> Always use `removeListener` in `dispose()` when subscribing manually. Forgetting this causes the disposed widget to receive updates and triggers "called after dispose" Flutter errors.

<a name="fine-grained-reactivity"></a>
## Fine-Grained Reactivity

`MagicStateMixin` calls `notifyListeners()` on every state transition, which rebuilds the entire view tree listening to the controller. For complex views with multiple independent loading sections, this full-page rebuild can cause UI flicker.

The solution is `ValueNotifier<T>` fields — one per independently-loading section. The notification controller demonstrates this with a preference matrix:

```dart
class MagicStarterNotificationController extends MagicController
    with MagicStateMixin<bool> {
  static MagicStarterNotificationController get instance =>
      Magic.findOrPut(MagicStarterNotificationController.new);

  /// Preference matrix updated independently of the page-level state machine.
  final matrixNotifier = ValueNotifier<Map<String, dynamic>>({});

  Future<void> fetchPreferences() async {
    setLoading();
    try {
      final response = await Http.get('/notification-preferences');
      if (!response.successful) {
        setError(trans('magic_starter.notifications.fetch_error'));
        return;
      }
      matrixNotifier.value = _normalizeMap(response.data['data'] as Map);
      setSuccess(true);
    } catch (e, stackTrace) {
      Log.error('[MagicStarterNotificationController.fetchPreferences] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    }
  }
}
```

The team controller uses the same technique for member and invitation lists:

```dart
final ValueNotifier<List<Map<String, dynamic>>> members = ValueNotifier([]);
final ValueNotifier<List<Map<String, dynamic>>> invitations = ValueNotifier([]);
```

In the view, wrap only the section that depends on the notifier:

```dart
ValueListenableBuilder<Map<String, dynamic>>(
  valueListenable: controller.matrixNotifier,
  builder: (_, matrix, __) => _buildPreferenceGrid(matrix),
)
```

The `ValueListenableBuilder` rebuilds only its own subtree when `matrixNotifier.value` changes, leaving the rest of the view untouched.

`MagicStarterProfileController` uses `withoutNotifying()` to suppress full-page `notifyListeners` calls when a section-level operation is already driving its own loading indicator via `MagicFormData.process`:

```dart
await form.process(() => controller.withoutNotifying(
  () => controller.doUpdateProfile(name: 'Alice', email: 'a@example.com'),
));
```

<a name="testing-controllers"></a>
## Testing Controllers

Every controller test follows the same setup sequence: reset the IoC container, bind mock drivers, create a fresh controller instance.

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectController', () {
    late MockNetworkDriver mockDriver;
    late ProjectController controller;

    setUp(() {
      // 1. Reset IoC container — clears all singletons from previous tests.
      MagicApp.reset();
      Magic.flush();

      // 2. Bind mock network driver so Http facade is intercepted.
      Magic.singleton('network', () => MockNetworkDriver());

      // 3. Bind log service so Log.error() works inside catch blocks.
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      // 4. Bind auth guard.
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => MockGuard());
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {'mock': {'driver': 'mock'}});

      // 5. Bind MagicStarterManager if the controller uses MagicStarter.*
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 6. Create a fresh controller — NOT via .instance (avoids cached state).
      controller = ProjectController();

      // 7. Resolve the mock driver reference for response setup.
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    test('loadProjects — success sets isSuccess true', () async {
      mockDriver.mockResponse(statusCode: 200, data: {'data': []});

      await controller.loadProjects();

      expect(controller.isSuccess, isTrue);
      expect(mockDriver.lastMethod, 'GET');
      expect(mockDriver.lastUrl, contains('/projects'));
    });

    test('loadProjects — API error sets hasErrors true', () async {
      mockDriver.mockResponse(statusCode: 422, data: {});

      await controller.loadProjects();

      expect(controller.hasErrors, isTrue);
      expect(controller.isSuccess, isFalse);
    });
  });
}
```

Key rules:

- **Always use `controller = ProjectController()` in tests**, not `ProjectController.instance`. The `.instance` accessor uses `Magic.findOrPut`, which returns a cached singleton. After `Magic.flush()` the cache is empty, but using the accessor in tests couples test isolation to container state. Constructing directly is unambiguous.
- **Dispose `ValueNotifier` fields** in `tearDown`. Forgetting causes "ValueNotifier used after dispose" errors in subsequent tests. Call `controller.dispose()` which triggers the `ChangeNotifier` disposal chain.
- **Queue multiple responses** for multi-request flows (e.g., OTP send followed by verify) using `mockDriver.mockQueue(responses)` when available in the test driver, or call `mockDriver.mockResponse()` between the two actions.
- **Feature flags** are set via `Config.set` in `setUp` before the controller is created: `Config.set('magic_starter.features.teams', true)`.

<a name="related"></a>
## Related

- [MagicStarterServiceProvider](https://magic.fluttersdk.com/packages/starter/architecture/service-provider) — bootstrap entry point, IoC bindings, and Gate ability registration
- [MagicStarterManager](https://magic.fluttersdk.com/packages/starter/architecture/manager) — central singleton holding all customization registrations
- [Views and Layouts](https://magic.fluttersdk.com/packages/starter/basics/views-and-layouts) — MagicStatefulView lifecycle and Wind UI rendering conventions
- [Magic Framework — IoC Container](https://magic.fluttersdk.com/getting-started/ioc-container) — singleton, factory, and findOrPut reference
- [Magic Framework — Service Providers](https://magic.fluttersdk.com/getting-started/service-providers) — two-phase bootstrap lifecycle
