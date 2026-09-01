# Notifications

- [Introduction](#introduction)
- [Real-Time Polling](#real-time-polling)
- [Notification List](#notification-list)
- [Notification Preferences](#notification-preferences)
- [Notification Dropdown](#notification-dropdown)
- [Notification Type Icons](#notification-type-icons)
- [Overriding a Screen](#overriding-a-screen)
- [Feature Gate](#feature-gate)

<a name="introduction"></a>
## Introduction

The notification UI moved to the `magic_notifications` package. This package no longer ships the list view, the preferences view, the controller behind them, or the bell dropdown; `magic_notifications` >= 0.0.4 does, under `NotificationsListView`, `NotificationPreferencesView`, `NotificationPreferencesController` and `NotificationDropdown`.

What stays here is what a published notifications package cannot know on its own: `registerMagicStarterNotificationRoutes()` owns the two paths (`/notifications` and `/settings/notifications`), mounts them inside the authenticated `layout.app` shell, and wraps `magic_notifications`'s screens in this package's own page geometry (`MSPageContainer`) so they read like every other page in the app rather than spreading full-bleed. `MagicStarterAppLayout` owns the polling lifecycle and renders the bell.

The entire feature is still opt-in behind `magic_starter.features.notifications`. When enabled, the layout starts polling and renders the bell; the routes resolve through `Notify.view`, not `MagicStarter.view`.

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

`NotificationsListView` (from `magic_notifications`) is a full-page view that displays all notifications with server-side pagination. It supports mark-as-read, mark-all-as-read, delete, and navigation to the notification's action URL.

`registerMagicStarterNotificationRoutes()` mounts it under the key `'notifications.list'` on `Notify.view`, wrapped in this package's page container, and renders it at `MagicStarterConfig.notificationsRoute()`:

```dart
MagicRoute.page(
  MagicStarterConfig.notificationsRoute(),
  () => Notify.view.make('notifications.list'),
).title('magic_starter.titles.notifications');
```

Each notification item resolves its icon through the notification type icon slot (see [Notification Type Icons](#notification-type-icons)). When a notification is tapped, it is marked as read and the user is navigated to the notification's `actionUrl`.

<a name="notification-preferences"></a>
## Notification Preferences

`NotificationPreferencesView` (from `magic_notifications`) displays a type-by-channel preference matrix fetched from the backend. Each notification type (e.g., "Monitor Down") shows its available channels (email, in-app, push) as toggle switches.

`registerMagicStarterNotificationRoutes()` mounts it under `'notifications.preferences'`, passing the one thing the notifications package cannot know: where "back" goes in this app.

```dart
Notify.view.register(
  'notifications.preferences',
  () => NotificationPreferencesView(
    backRoute: MagicStarterConfig.settingsHubRoute(),
  ),
);
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
> Preference updates use optimistic UI. The toggle flips immediately and a `PUT /notification-preferences` request is sent. On failure, the matrix reverts to its pre-update snapshot. This state lives in `magic_notifications`'s own `NotificationPreferencesController` now; this package no longer carries one.

<a name="notification-dropdown"></a>
## Notification Dropdown

`NotificationDropdown` (from `magic_notifications`, no longer `MSNotificationDropdown`) is a standalone widget, not a view, that renders a bell icon with a live unread badge. It uses `StreamBuilder<List<DatabaseNotification>>` to reactively display the current notification count. `MagicStarterAppLayout` mounts it with the same five callbacks it always passed:

```dart
NotificationDropdown(
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

<a name="notification-type-icons"></a>
## Notification Type Icons

`MagicStarter.useNotificationTypeMapper(...)` and the `MagicStarterNotificationTypeMapper` typedef are gone. Saying what a notification type looks like is `magic_notifications`'s own slot now, and it answers the same question for the list screen and the bell at once:

```dart
import 'package:magic_notifications/magic_notifications.dart';

Notify.view.slot(
  NotificationViewRegistry.typeIconSlotView,
  'monitor_down',
  (context) => WIcon(Icons.error_outline, className: 'text-lg text-red-500'),
);
```

Register the slot name `'default'` to answer for every type you did not name individually:

```dart
Notify.view.slot(
  NotificationViewRegistry.typeIconSlotView,
  'default',
  (context) => WIcon(Icons.info_outline, className: 'text-lg text-blue-500'),
);
```

Both the list view and the dropdown read `Notify.view.buildTypeIcon(type, context)`, which checks the type's own slot first and falls back to `'default'`, so one registration call answers for both surfaces.

<a name="overriding-a-screen"></a>
## Overriding a Screen

An app that wants to swap either screen no longer registers on `MagicStarter.view`; it registers on `Notify.view`:

```dart
Notify.view.register(
  'notifications.list',
  () => const MyCustomNotificationsListView(),
);
```

**The order does not matter.** `registerMagicStarterNotificationRoutes()` installs its own screens only when the key is absent, matching how every other default in this package is registered (`MagicStarterManager._registerDefault`), so a host registration wins whether it runs before or after the routes are mapped. That is worth saying explicitly here, because the two calls land in different files: the installer injects the route mount into `route_service_provider.dart` while the scaffold points `Notify.view` work at `AppServiceProvider`, and which of those boots first is a property of the host's provider list rather than of anything this package can see.

The registry's shape is identical to `MagicStarter.view`'s (`register` / `has` / `make` / `slot` / `buildSlot` / `clear`), so an app that already knew one knows the other.

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
