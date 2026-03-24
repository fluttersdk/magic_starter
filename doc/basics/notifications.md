# Notifications

- [Introduction](#introduction)
- [Real-Time Polling](#real-time-polling)
- [Notification List](#notification-list)
- [Notification Preferences](#notification-preferences)
- [Notification Dropdown](#notification-dropdown)
- [Notification Type Mapper](#notification-type-mapper)
- [Controller](#controller)
    - [Fetching Preferences](#fetching-preferences)
    - [Updating Preferences](#updating-preferences)
    - [Key Normalization](#key-normalization)
    - [ValueNotifier Pattern](#valuenotifier-pattern)
- [Feature Gate](#feature-gate)

<a name="introduction"></a>
## Introduction

Magic Starter ships a complete notification subsystem built on top of the `magic_notifications` package. It provides three UI surfaces — a full-page notification list, a notification preferences matrix, and a header dropdown with a live unread badge — all wired together through `MagicStarterNotificationController` and the `Notify` facade.

The entire notification feature is opt-in. It activates only when `magic_starter.features.notifications` is set to `true` in your configuration. When enabled, the `AppLayout` automatically starts polling for new notifications and renders the bell icon in the header.

<a name="real-time-polling"></a>
## Real-Time Polling

Notification polling is managed automatically by `MagicStarterAppLayout`. When the authenticated layout mounts and the notifications feature is enabled, it calls `Notify.startPolling()` to begin fetching notifications at a regular interval. Polling stops when the layout is disposed:

```dart
@override
void initState() {
  super.initState();

  if (MagicStarterConfig.hasNotificationFeatures()) {
    Notify.startPolling();
  }
}

@override
void dispose() {
  if (MagicStarterConfig.hasNotificationFeatures()) {
    Notify.stopPolling();
  }
  super.dispose();
}
```

`Notify.startPolling()` is idempotent — calling it multiple times has no effect. It also triggers an immediate fetch so the UI has data without waiting for the first interval tick.

> [!NOTE]
> In test environments where Magic may not be fully initialized, `startPolling()` and `stopPolling()` are wrapped in try-catch blocks inside the layout. Your test tearDown should still call `Notify.stopPolling()` with a silent catch to prevent timer leaks.

<a name="notification-list"></a>
## Notification List

`MagicStarterNotificationsListView` is a full-page view that displays all notifications with server-side pagination. It supports mark-as-read, mark-all-as-read, delete, and navigation to the notification's action URL.

```dart
MagicStarterNotificationsListView(
  onMarkAsRead: (id) => Notify.markAsRead(id),
  onMarkAllAsRead: () => Notify.markAllAsRead(),
  onDelete: (id) => Notify.delete(id),
  onNavigate: (path) => MagicRoute.to(path),
  perPage: 15,
)
```

The view is registered in the view registry under the key `'notifications.list'` and rendered by the controller's `index()` method:

```dart
Widget index() => MagicStarter.view.make('notifications.list');
```

Each notification item resolves its icon and color through the notification type mapper (see [Notification Type Mapper](#notification-type-mapper)). When a notification is tapped, it is marked as read and the user is navigated to the notification's `actionUrl`. If no action URL exists, the current page reloads.

> [!TIP]
> Override the default list view by registering your own builder under `'notifications.list'` in the view registry before the service provider boots.

<a name="notification-preferences"></a>
## Notification Preferences

`MagicStarterNotificationPreferencesView` displays a type-by-channel preference matrix fetched from the backend. Each notification type (e.g., "Monitor Down") shows its available channels (email, in-app, push) as toggle switches.

```dart
const MagicStarterNotificationPreferencesView()
```

The view extends `MagicStatefulView<MagicStarterNotificationController>` and calls `controller.fetchPreferences()` in `onInit()`. The preference matrix is rendered reactively via `ValueListenableBuilder`:

```dart
ValueListenableBuilder<Map<String, dynamic>>(
  valueListenable: controller.matrixNotifier,
  builder: (context, matrix, _) {
    // Render type cards with channel toggles
  },
)
```

The matrix structure returned by the API:

```json
{
  "monitor_down": {
    "label": "Monitor Down",
    "channels": {
      "mail":     { "enabled": true,  "locked": false },
      "database": { "enabled": true,  "locked": true },
      "push":     { "enabled": false, "locked": false }
    }
  }
}
```

Locked channels display a lock icon and their toggle is disabled — the backend enforces that certain channels cannot be turned off.

> [!NOTE]
> Preference updates use optimistic UI. The toggle flips immediately in the local `matrixNotifier` and a `PUT /notification-preferences` request is sent. On failure, the matrix reverts to its pre-update snapshot.

<a name="notification-dropdown"></a>
## Notification Dropdown

`MagicStarterNotificationDropdown` is a standalone widget (not a view) that renders a bell icon with a live unread badge. It uses `StreamBuilder<List<DatabaseNotification>>` to reactively display the current notification count:

```dart
MagicStarterNotificationDropdown(
  notificationStream: Notify.notifications(),
  onMarkAsRead: (id) => Notify.markAsRead(id),
  onMarkAllAsRead: () => Notify.markAllAsRead(),
  onNotificationTap: (notification) =>
      MagicRoute.to(notification.actionUrl ?? '/'),
  onViewAll: () =>
      MagicRoute.to(MagicStarterConfig.notificationsRoute()),
)
```

The dropdown is rendered inside `AppLayout`'s header and sidebar via the centralized `_buildNotificationBell()` helper. It only appears when `MagicStarterConfig.hasNotificationFeatures()` returns `true`.

Key behaviors:

| State | Display |
|-------|---------|
| Loading | Bell icon with no badge, spinner in dropdown body |
| Error | Bell icon with no badge, error icon in dropdown body |
| Empty | Bell icon with no badge, "No notifications" empty state |
| Unread > 0 | Bell icon with red badge (`9+` overflow), notification list |

When a notification is tapped, it is marked as read and the `onNotificationTap` callback fires. The dropdown closes automatically after tap.

> [!TIP]
> The dropdown uses `WPopover` for overlay positioning. It aligns to `PopoverAlignment.bottomRight` by default and constrains its height to 400 logical pixels.

<a name="notification-type-mapper"></a>
## Notification Type Mapper

Register a custom mapper to control the icon and color for each notification type across all notification views (list, dropdown, preferences):

```dart
MagicStarter.useNotificationTypeMapper((type) => switch (type) {
  'monitor_down'     => (icon: Icons.error_outline,        colorClass: 'text-red-500'),
  'monitor_up'       => (icon: Icons.check_circle_outline, colorClass: 'text-green-500'),
  'monitor_degraded' => (icon: Icons.warning_outlined,     colorClass: 'text-yellow-500'),
  'payment_failed'   => (icon: Icons.credit_card_off,      colorClass: 'text-red-500'),
  _                  => (icon: Icons.info_outline,          colorClass: 'text-blue-500'),
});
```

The mapper is a typedef:

```dart
typedef MagicStarterNotificationTypeMapper =
    ({IconData icon, String colorClass}) Function(String type);
```

When no mapper is registered, views fall back to built-in defaults that handle `monitor_down`, `monitor_up`, and `monitor_degraded` types.

> [!NOTE]
> The `colorClass` value is a Wind UI color class string (e.g., `'text-red-500'`), not a Flutter `Color`. It is applied directly to the `WIcon` widget's `className`.

<a name="controller"></a>
## Controller

`MagicStarterNotificationController` manages notification preferences state. It follows the standard singleton pattern:

```dart
static MagicStarterNotificationController get instance =>
    Magic.findOrPut(MagicStarterNotificationController.new);
```

The controller extends `MagicController` with `MagicStateMixin<bool>` and `ValidatesRequests`.

<a name="fetching-preferences"></a>
### Fetching Preferences

```dart
await controller.fetchPreferences();
```

Sends `GET /notification-preferences` and normalizes the response into `matrixNotifier`. Guards against double-submit with `_isSubmitting`.

<a name="updating-preferences"></a>
### Updating Preferences

```dart
await controller.updateTypePreference(
  'monitor_down', // type key
  'mail',         // channel key
  false,          // new enabled state
);
```

Sends `PUT /notification-preferences` with `{ type, channel, is_enabled }`. Uses optimistic UI with snapshot rollback on failure. Guards against concurrent saves with `_isSaving`.

<a name="key-normalization"></a>
### Key Normalization

The backend may return map keys with mixed casing or non-string types. The controller's `_normalizeMap()` method recursively converts all keys to `String`:

```dart
Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> source) {
  return source.map(
    (key, value) => MapEntry(
      key.toString(),
      value is Map ? _normalizeMap(value) : value,
    ),
  );
}
```

> [!NOTE]
> This normalization is critical. Without it, Dart's type system will throw when you try to access map entries with string keys on a `Map<dynamic, dynamic>` payload.

<a name="valuenotifier-pattern"></a>
### ValueNotifier Pattern

The controller exposes `matrixNotifier` as a `ValueNotifier<Map<String, dynamic>>` for fine-grained reactive updates that bypass `MagicStateMixin`'s `notifyListeners()`:

```dart
final matrixNotifier = ValueNotifier<Map<String, dynamic>>({});
```

Views subscribe to it with `ValueListenableBuilder` to rebuild only the preference matrix when a toggle changes, without triggering a full page rebuild. The notifier must be disposed in the controller's `dispose()` method:

```dart
@override
void dispose() {
  matrixNotifier.dispose();
  super.dispose();
}
```

<a name="feature-gate"></a>
## Feature Gate

All notification functionality is gated behind `MagicStarterConfig.hasNotificationFeatures()`:

```dart
if (MagicStarterConfig.hasNotificationFeatures()) {
  Notify.startPolling();
}
```

Enable it in your configuration:

```dart
Config.set('magic_starter.features.notifications', true);
```

When disabled:

- Notification routes are not registered (the registration function is a no-op)
- The bell icon dropdown does not render in the app layout
- Polling never starts
- Calling notification route paths throws `StateError`

> [!TIP]
> The install command can enable notifications automatically: `dart run magic_starter install --non-interactive --features notifications`. This also triggers the `magic_notifications` package installer.

---

**Related Links:**

- [Notification Routes](https://magic.fluttersdk.com/packages/starter/routes/notifications)
- [Views and Layouts](https://magic.fluttersdk.com/packages/starter/basics/views-and-layouts)
- [Configuration](https://magic.fluttersdk.com/packages/starter/getting-started/configuration)
- [magic_notifications Package](https://magic.fluttersdk.com/packages/notifications)
