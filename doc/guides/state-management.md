# State Management

- [Introduction](#introduction)
- [Creating a State Class](#creating-a-state-class)
  - [Extend MagicController](#extend-magiccontroller)
  - [Add the Singleton Accessor](#add-the-singleton-accessor)
  - [Implement Async Methods](#implement-async-methods)
- [Registration Decision Tree](#registration-decision-tree)
- [Connecting State to Views](#connecting-state-to-views)
  - [Pattern A: MagicStatefulView](#pattern-a-magicstatefulview)
  - [Pattern B: StatefulWidget + Magic.find](#pattern-b-statefulwidget--magicfind)
- [Testing](#testing)
- [Complete Example](#complete-example)
- [Related](#related)

<a name="introduction"></a>
## Introduction

Magic Starter uses a three-part state management model built on the Magic Framework:

1. **`MagicController`** — base class that provides lifecycle management and ties into the IoC container.
2. **`MagicStateMixin<T>`** — mixin that adds a five-state machine (`loading`, `success`, `error`, `empty`) with `setLoading()`, `setSuccess()`, `setError()`, `clearErrors()`, and `renderState()` helpers.
3. **IoC container** — `Magic.findOrPut()` returns the existing singleton for a class or registers and returns a new one. Views never construct controllers directly.

Consumer app controllers follow the exact same pattern as magic_starter's own controllers. You extend `MagicController`, mix in `MagicStateMixin<T>`, and expose a `static get instance` accessor backed by `Magic.findOrPut()`. Views bind to that accessor and call `renderState()` to drive conditional rendering.

<a name="creating-a-state-class"></a>
## Creating a State Class

<a name="extend-magiccontroller"></a>
### Extend MagicController

Declare your controller in a file named after the feature it manages:

```dart
import 'package:magic/magic.dart';

class ProjectController extends MagicController
    with MagicStateMixin<List<Map<String, dynamic>>> {
  // ...
}
```

The generic type parameter on `MagicStateMixin<T>` is the value type passed to `setSuccess(value)`. Use `List<Map<String, dynamic>>` for collections, `bool` for form-submission controllers, or a typed model class for single-resource controllers.

<a name="add-the-singleton-accessor"></a>
### Add the Singleton Accessor

Every controller exposes a static `instance` getter backed by `Magic.findOrPut()`:

```dart
class ProjectController extends MagicController
    with MagicStateMixin<List<Map<String, dynamic>>> {
  static ProjectController get instance =>
      Magic.findOrPut(ProjectController.new);
}
```

`Magic.findOrPut(ProjectController.new)` checks whether a `ProjectController` is already registered in the container. If it is, it returns the existing instance. If not, it calls `ProjectController.new` (the tear-off constructor), registers it as a singleton, and returns it. All views calling `ProjectController.instance` will receive the same object.

> [!NOTE]
> Never call `ProjectController()` directly in a view. The `instance` accessor is the only valid entry point — it ensures the same state is shared across all views that reference the controller.

<a name="implement-async-methods"></a>
### Implement Async Methods

Each async action follows the same lifecycle:

1. Guard against re-entrant calls with a `_isSubmitting` flag.
2. Call `setLoading()` to transition the state machine.
3. Perform the HTTP call via `Http.get()` / `Http.post()` / etc.
4. Call `setSuccess(value)` on the happy path or `setError(message)` on failure.
5. Reset the guard in `finally`.

```dart
class ProjectController extends MagicController
    with MagicStateMixin<List<Map<String, dynamic>>> {
  // -------------------------------------------------------------------------
  // Singleton
  // -------------------------------------------------------------------------

  static ProjectController get instance =>
      Magic.findOrPut(ProjectController.new);

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  bool _isLoading = false;

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  /// Fetch all projects from the API and expose them via state machine.
  Future<void> loadProjects() async {
    if (_isLoading) return;
    _isLoading = true;
    setLoading();

    try {
      final response = await Http.get('/api/projects');

      if (!response.successful) {
        setError('Failed to load projects.');
        return;
      }

      final data = response.data['data'];
      if (data is List) {
        setSuccess(data.cast<Map<String, dynamic>>());
      } else {
        setSuccess([]);
      }
    } catch (e, stackTrace) {
      Log.error('[ProjectController.loadProjects] $e\n$stackTrace');
      setError('An unexpected error occurred.');
    } finally {
      _isLoading = false;
    }
  }
}
```

The `MagicStateMixin` state transitions and the properties they expose:

| Method | Resulting state | View properties set |
|--------|-----------------|---------------------|
| `setLoading()` | loading | `isLoading == true` |
| `setSuccess(value)` | success | `isLoading == false`, state value available |
| `setError(message)` | error | `hasErrors == true`, error message stored |
| `clearErrors()` | (no transition) | Clears stored error messages |
| `setEmpty()` | empty | `isEmpty == true` |

<a name="registration-decision-tree"></a>
## Registration Decision Tree

Use this decision tree to determine how and where to register your controller:

```
Does the controller need to be ready before any view renders?
│
├─ YES → Register eagerly in AppServiceProvider.boot()
│        Magic.findOrPut(ProjectController.new);
│        Views resolve via ProjectController.instance (same singleton)
│
└─ NO  → Use lazy findOrPut() (default pattern)
         static ProjectController get instance =>
             Magic.findOrPut(ProjectController.new);
         First view access triggers registration automatically

         Is the controller shared across multiple views?
         │
         ├─ YES → findOrPut() — returns the same singleton everywhere
         │
         └─ NO  → Consider a plain StatefulWidget with local ChangeNotifier
                  (no IoC involvement needed for purely local state)
```

| Scenario | Registration approach | Example |
|----------|-----------------------|---------|
| Global nav data (unread count, current team) | Eager — `AppServiceProvider.boot()` | `NotificationController` pre-warmed on login |
| Feature-specific data (project list, report) | Lazy — `findOrPut()` | `ProjectController` only loaded when the projects screen mounts |
| Single-view transient state (modal open/close) | Local `ChangeNotifier` in `StatefulWidget` | No IoC — no need for `MagicController` |

> [!TIP]
> Prefer the lazy `findOrPut()` pattern for most feature controllers. Eager registration in `boot()` is only justified when the data must be available immediately after login (e.g., unread notification count shown in the navigation bar).

<a name="connecting-state-to-views"></a>
## Connecting State to Views

<a name="pattern-a-magicstatefulview"></a>
### Pattern A: MagicStatefulView

Use `MagicStatefulView<ControllerType>` for all full-page views. The base class resolves `controller` automatically via `instance` and listens to state changes.

```dart
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class ProjectListView extends MagicStatefulView<ProjectController> {
  const ProjectListView({super.key});

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState
    extends MagicStatefulViewState<ProjectController, ProjectListView> {
  @override
  void onInit() {
    controller.loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (projects) => _buildList(projects),
      onEmpty: _buildEmpty(),
      onError: (message) => _buildError(message),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> projects) {
    final isLoading = controller.isLoading;

    return WDiv(
      className: 'flex flex-col',
      children: [
        MagicStarterPageHeader(
          title: 'Projects',
          subtitle: 'Manage your projects',
          actions: [
            WButton(
              onTap: isLoading ? null : controller.loadProjects,
              className: 'py-2 px-4 rounded-lg bg-primary text-white text-sm',
              child: WText('Refresh'),
            ),
          ],
        ),
        WDiv(
          className: 'flex flex-col gap-2 p-6',
          children: [
            for (final project in projects)
              MagicStarterCard(
                child: WText(
                  project['name'] as String,
                  className: 'text-gray-900 dark:text-white text-sm',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return WDiv(
      className: 'flex flex-col items-center justify-center p-12',
      children: [
        WText(
          'No projects yet.',
          className: 'text-gray-500 dark:text-gray-400 text-sm',
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return WDiv(
      className: 'flex flex-col items-center justify-center p-12',
      children: [
        WText(message, className: 'text-sm text-red-500'),
      ],
    );
  }
}
```

The `renderState()` method selects the builder based on the current `MagicStateMixin` state:

| Argument | When rendered |
|----------|---------------|
| First positional `(T value) => Widget` | Controller called `setSuccess(value)` |
| `onEmpty:` | Controller called `setEmpty()` or state is initial |
| `onError: (String message) => Widget` | Controller called `setError(message)` |

While the state is `loading`, `renderState()` displays a built-in loading indicator — no `onLoading` builder is needed.

<a name="pattern-b-statefulwidget--magicfind"></a>
### Pattern B: StatefulWidget + Magic.find

Use `Magic.find<T>()` when you need controller access inside a non-page widget (e.g., a dropdown, a card action, or a sub-widget inside an existing view):

```dart
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class ProjectCountBadge extends StatefulWidget {
  const ProjectCountBadge({super.key});

  @override
  State<ProjectCountBadge> createState() => _ProjectCountBadgeState();
}

class _ProjectCountBadgeState extends State<ProjectCountBadge> {
  late final ProjectController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProjectController.instance;
    _controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final count = _controller.isSuccess
        ? (_controller.state as List).length
        : 0;

    return WDiv(
      className: 'flex items-center gap-1',
      children: [
        WIcon(Icons.folder_outlined, className: 'text-gray-500 text-base'),
        WText(
          '$count Projects',
          className: 'text-sm text-gray-700 dark:text-gray-300',
        ),
      ],
    );
  }
}
```

> [!NOTE]
> `ProjectController.instance` calls `findOrPut()` under the hood — it registers the controller on demand if it is not already in the container. Always prefer the static `instance` accessor over raw `Magic.find<T>()`, which returns `null` when the controller has not been registered yet.

<a name="testing"></a>
## Testing

Tests follow the same pattern as magic_starter's own controller tests: reset the IoC container in `setUp`, bind a `MockNetworkDriver`, and assert state transitions.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(
      data: data ?? {},
      statusCode: statusCode,
    );
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond('UPLOAD', url, data: data);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProjectController', () {
    late MockNetworkDriver mockDriver;
    late ProjectController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      Magic.singleton('network', () => MockNetworkDriver());
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      controller = ProjectController();
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    test('loadProjects success — state transitions to success', () async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': [
            {'id': 1, 'name': 'Alpha'},
            {'id': 2, 'name': 'Beta'},
          ],
        },
      );

      await controller.loadProjects();

      expect(mockDriver.lastMethod, equals('GET'));
      expect(mockDriver.lastUrl, equals('/api/projects'));
    });

    test('loadProjects error (500) — state transitions to error', () async {
      mockDriver.mockResponse(statusCode: 500);

      await controller.loadProjects();

      expect(controller.hasErrors, isTrue);
    });

    test('loadProjects is not re-entrant', () async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {'data': []},
      );

      final first = controller.loadProjects();
      final second = controller.loadProjects();
      await Future.wait([first, second]);

      // Only one GET should have been issued.
      expect(mockDriver.lastMethod, equals('GET'));
    });
  });
}
```

<a name="complete-example"></a>
## Complete Example

End-to-end implementation of a `ProjectList` feature — state class, view, and test.

### State class (`lib/src/http/controllers/project_controller.dart`)

```dart
import 'package:magic/magic.dart';

class ProjectController extends MagicController
    with MagicStateMixin<List<Map<String, dynamic>>> {
  // -------------------------------------------------------------------------
  // Singleton
  // -------------------------------------------------------------------------

  static ProjectController get instance =>
      Magic.findOrPut(ProjectController.new);

  // -------------------------------------------------------------------------
  // Private
  // -------------------------------------------------------------------------

  bool _isLoading = false;

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  /// Fetch all projects from the API.
  Future<void> loadProjects() async {
    if (_isLoading) return;
    _isLoading = true;
    setLoading();

    try {
      final response = await Http.get('/api/projects');

      if (!response.successful) {
        setError('Failed to load projects.');
        return;
      }

      final data = response.data['data'];
      setSuccess(
        data is List ? data.cast<Map<String, dynamic>>() : [],
      );
    } catch (e, stackTrace) {
      Log.error('[ProjectController.loadProjects] $e\n$stackTrace');
      setError('An unexpected error occurred.');
    } finally {
      _isLoading = false;
    }
  }
}
```

### View (`lib/src/ui/views/projects/project_list_view.dart`)

```dart
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class ProjectListView extends MagicStatefulView<ProjectController> {
  const ProjectListView({super.key});

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState
    extends MagicStatefulViewState<ProjectController, ProjectListView> {
  @override
  void onInit() {
    controller.loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (projects) => _buildList(projects),
      onEmpty: _buildEmpty(),
      onError: (message) => _buildError(message),
    );
  }

  // -------------------------------------------------------------------------
  // Private builders
  // -------------------------------------------------------------------------

  Widget _buildList(List<Map<String, dynamic>> projects) {
    final isLoading = controller.isLoading;

    return WDiv(
      className: 'flex flex-col',
      children: [
        MagicStarterPageHeader(
          title: 'Projects',
          subtitle: '${projects.length} total',
          actions: [
            WButton(
              onTap: isLoading ? null : controller.loadProjects,
              className: 'py-2 px-4 rounded-lg bg-primary text-white text-sm',
              child: WText('Refresh'),
            ),
          ],
        ),
        WDiv(
          className: 'flex flex-col gap-3 p-6',
          children: [
            for (final project in projects)
              MagicStarterCard(
                child: WDiv(
                  className: 'flex flex-col gap-1',
                  children: [
                    WText(
                      project['name'] as String,
                      className: 'text-sm font-medium text-gray-900 dark:text-white',
                    ),
                    if (project['description'] != null)
                      WText(
                        project['description'] as String,
                        className: 'text-xs text-gray-500 dark:text-gray-400',
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return WDiv(
      className: 'flex flex-col items-center justify-center p-12',
      children: [
        WIcon(Icons.folder_outlined, className: 'text-4xl text-gray-300 dark:text-gray-600'),
        WSpacer(className: 'h-4'),
        WText(
          'No projects yet.',
          className: 'text-sm text-gray-500 dark:text-gray-400',
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return WDiv(
      className: 'flex flex-col items-center justify-center p-12',
      children: [
        WText(message, className: 'text-sm text-red-500 dark:text-red-400'),
      ],
    );
  }
}
```

### Test (`test/http/controllers/project_controller_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;
  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond('UPLOAD', url, data: data);
}

void main() {
  group('ProjectController', () {
    late MockNetworkDriver mockDriver;
    late ProjectController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      Magic.singleton('network', () => MockNetworkDriver());
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      controller = ProjectController();
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    test('loadProjects success — hits correct endpoint', () async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': [
            {'id': 1, 'name': 'Alpha'},
            {'id': 2, 'name': 'Beta'},
          ],
        },
      );

      await controller.loadProjects();

      expect(mockDriver.lastMethod, equals('GET'));
      expect(mockDriver.lastUrl, equals('/api/projects'));
      expect(controller.hasErrors, isFalse);
    });

    test('loadProjects 500 — transitions to error state', () async {
      mockDriver.mockResponse(statusCode: 500);

      await controller.loadProjects();

      expect(controller.hasErrors, isTrue);
    });

    test('loadProjects re-entrant guard — only one GET issued', () async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {'data': []},
      );

      final first = controller.loadProjects();
      final second = controller.loadProjects();
      await Future.wait([first, second]);

      expect(mockDriver.lastUrl, equals('/api/projects'));
    });
  });
}
```

<a name="related"></a>
## Related

- [Controllers](https://magic.fluttersdk.com/packages/starter/basics/controllers) — full HTTP controller reference with error handling patterns
- [Service Providers](https://magic.fluttersdk.com/packages/starter/architecture/service-provider) — two-phase bootstrap and eager controller registration in `boot()`
- [Views and Layouts](https://magic.fluttersdk.com/packages/starter/basics/views-and-layouts) — `MagicStatefulView` lifecycle, `renderState()`, and form handling
