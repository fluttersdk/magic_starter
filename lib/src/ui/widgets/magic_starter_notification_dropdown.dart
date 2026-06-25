// Thin alias — MagicStarterNotificationDropdown is preserved for backward
// compatibility. The implementation now lives in
// components/notification_dropdown/notification_dropdown.dart.

import '../components/notification_dropdown/notification_dropdown.dart';

export '../components/notification_dropdown/notification_dropdown.dart'
    show NotificationDropdown;

/// Backward-compatible alias for [NotificationDropdown].
class MagicStarterNotificationDropdown extends NotificationDropdown {
  const MagicStarterNotificationDropdown({
    super.key,
    required super.notificationStream,
    super.onMarkAsRead,
    super.onMarkAllAsRead,
    super.onNotificationTap,
    super.onViewAll,
  });
}
