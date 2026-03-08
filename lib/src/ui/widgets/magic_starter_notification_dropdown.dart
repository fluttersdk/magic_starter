import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';

/// Bell icon dropdown with real-time unread badge powered by a notification stream.
///
/// Uses [WPopover] for overlay mechanics and [StreamBuilder] for live unread counts.
/// This is a standalone widget — NOT registered in ViewRegistry (it's a component, not a page).
///
/// ### Example Usage
/// ```dart
/// MagicStarterNotificationDropdown(
///   notificationStream: Notify.notifications(),
///   onMarkAsRead: (id) => Notify.markAsRead(id),
///   onMarkAllAsRead: () => Notify.markAllAsRead(),
///   onNotificationTap: (notification) => MagicRoute.to(notification.actionUrl ?? '/'),
///   onViewAll: () => MagicRoute.to(MagicStarterConfig.notificationsRoute()),
/// )
/// ```
class MagicStarterNotificationDropdown extends StatelessWidget {
  /// Stream of notifications to display.
  final Stream<List<DatabaseNotification>> notificationStream;

  /// Callback when a notification is marked as read.
  final Future<void> Function(String id)? onMarkAsRead;

  /// Callback when all notifications are marked as read.
  final Future<void> Function()? onMarkAllAsRead;

  /// Callback when a notification is tapped.
  final void Function(DatabaseNotification notification)? onNotificationTap;

  /// Callback when the "View all" link is tapped.
  final VoidCallback? onViewAll;

  /// Creates a notification dropdown.
  const MagicStarterNotificationDropdown({
    super.key,
    required this.notificationStream,
    this.onMarkAsRead,
    this.onMarkAllAsRead,
    this.onNotificationTap,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DatabaseNotification>>(
      stream: notificationStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingDropdown();
        }

        if (snapshot.hasError) {
          return _buildErrorDropdown();
        }

        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.isRead).length;

        return _buildDropdown(notifications, unreadCount);
      },
    );
  }

  /// Builds the main dropdown using WPopover.
  Widget _buildDropdown(
      List<DatabaseNotification> notifications, int unreadCount) {
    return WPopover(
      alignment: PopoverAlignment.bottomRight,
      className: '''
        w-80
        bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        rounded-xl shadow-xl
      ''',
      maxHeight: 400,
      triggerBuilder: (context, isOpen, isHovering) =>
          _buildTrigger(context, isOpen, isHovering, unreadCount: unreadCount),
      contentBuilder: (context, close) =>
          _buildContent(context, close, notifications, unreadCount),
    );
  }

  /// Builds the bell icon trigger with optional unread badge.
  Widget _buildTrigger(
    BuildContext context,
    bool isOpen,
    bool isHovering, {
    required int unreadCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        WDiv(
          states: {if (isOpen) 'active', if (isHovering) 'hover'},
          className: '''
            p-2 rounded-lg duration-150
            bg-transparent hover:bg-gray-100 dark:hover:bg-gray-800
            active:bg-gray-100 dark:active:bg-gray-800
          ''',
          child: WIcon(
            Icons.notifications_outlined,
            className: 'text-2xl text-gray-500 dark:text-gray-400',
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: WDiv(
              className: '''
                min-w-[14px] h-[14px] px-1 rounded-full
                bg-red-500
                flex items-center justify-center
                // animate-bounce duration-500
              ''',
              child: WText(
                unreadCount > 9
                    ? trans('notifications.badge_overflow')
                    : unreadCount.toString(),
                className: 'text-[9px] font-bold text-white',
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the dropdown panel content.
  Widget _buildContent(
    BuildContext context,
    VoidCallback close,
    List<DatabaseNotification> notifications,
    int unreadCount,
  ) {
    return WDiv(
      className: 'flex flex-col items-stretch',
      children: [
        _buildContentHeader(unreadCount),
        WDiv(
          className: 'flex-1 min-h-0',
          child: _buildNotificationsList(context, close, notifications),
        ),
        if (onViewAll != null) _buildFooter(context, close),
      ],
    );
  }

  /// Builds the header with title and "Mark all as read" action.
  Widget _buildContentHeader(int unreadCount) {
    return WDiv(
      className: '''
        px-4 py-3 w-full
        border-b border-gray-200 dark:border-gray-700
        flex flex-row items-center justify-between
      ''',
      children: [
        WText(
          trans('notifications.title'),
          className: 'text-base font-semibold text-gray-900 dark:text-white',
        ),
        if (unreadCount > 0 && onMarkAllAsRead != null)
          WAnchor(
            onTap: onMarkAllAsRead,
            child: WText(
              trans('notifications.mark_all_read'),
              className: 'text-xs text-primary hover:text-green-600',
            ),
          ),
      ],
    );
  }

  /// Builds the list of notifications or empty state.
  Widget _buildNotificationsList(
    BuildContext context,
    VoidCallback close,
    List<DatabaseNotification> notifications,
  ) {
    if (notifications.isEmpty) {
      return WDiv(
        className:
            'w-full py-12 flex flex-col items-center justify-center gap-3',
        children: [
          WIcon(
            Icons.notifications_off_outlined,
            className: 'text-4xl text-gray-300 dark:text-gray-600',
          ),
          WText(
            trans('notifications.empty'),
            className: 'text-sm text-gray-500 dark:text-gray-400',
          ),
        ],
      );
    }

    return WDiv(
      className: 'overflow-y-auto flex flex-col',
      children: notifications
          .map((n) => _buildNotificationItem(context, n, close))
          .toList(),
    );
  }

  /// Builds a single notification item.
  Widget _buildNotificationItem(
    BuildContext context,
    DatabaseNotification notification,
    VoidCallback close,
  ) {
    final IconData icon = _getIconForType(notification.type);
    final String iconColor = _getColorForType(notification.type);

    return WAnchor(
      onTap: () async {
        await onMarkAsRead?.call(notification.id);
        onNotificationTap?.call(notification);
        close();
      },
      child: WDiv(
        className: '''
          flex flex-row items-start gap-3 px-4 py-3 w-full
          border-b border-gray-100 dark:border-gray-700
          hover:bg-gray-50 dark:hover:bg-gray-700
          ${notification.isRead ? '' : 'bg-primary/5 dark:bg-primary/10'}
        ''',
        children: [
          WDiv(
            className: '''
              w-8 h-8 rounded-full
              bg-gray-100 dark:bg-gray-700
              flex items-center justify-center
            ''',
            child: WIcon(icon, className: 'text-lg $iconColor'),
          ),
          WDiv(
            className: 'flex-1 flex flex-col min-w-0',
            children: [
              WText(
                notification.title,
                className: '''
                  text-sm text-gray-900 dark:text-white truncate
                  ${notification.isRead ? '' : 'font-semibold'}
                ''',
              ),
              const WSpacer(className: 'h-0.5'),
              WText(
                notification.body,
                className: 'text-xs text-gray-500 dark:text-gray-400',
              ),
              const WSpacer(className: 'h-0.5'),
              WText(
                _formatTime(notification.createdAt),
                className: 'text-xs text-gray-400 dark:text-gray-500',
              ),
            ],
          ),
          if (!notification.isRead)
            WDiv(
              className: 'w-2 h-2 rounded-full bg-primary mt-2',
              child: const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  /// Builds the footer with "View all" action.
  Widget _buildFooter(BuildContext context, VoidCallback close) {
    return WAnchor(
      onTap: () {
        onViewAll?.call();
        close();
      },
      child: WDiv(
        className: '''
          px-4 py-3 w-full
          border-t border-gray-200 dark:border-gray-700
          hover:bg-gray-50 dark:hover:bg-gray-700
          flex items-center justify-center
        ''',
        child: WText(
          trans('notifications.view_all'),
          className: 'text-sm font-medium text-primary',
        ),
      ),
    );
  }

  /// Builds the loading state dropdown.
  Widget _buildLoadingDropdown() {
    return WPopover(
      alignment: PopoverAlignment.bottomRight,
      className: '''
        w-80
        bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        rounded-xl shadow-xl
      ''',
      maxHeight: 400,
      triggerBuilder: (context, isOpen, isHovering) =>
          _buildTrigger(context, isOpen, isHovering, unreadCount: 0),
      contentBuilder: (context, close) => WDiv(
        className: 'py-12 flex items-center justify-center',
        child: const CircularProgressIndicator(),
      ),
    );
  }

  /// Builds the error state dropdown.
  Widget _buildErrorDropdown() {
    return WPopover(
      alignment: PopoverAlignment.bottomRight,
      className: '''
        w-80
        bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        rounded-xl shadow-xl
      ''',
      maxHeight: 400,
      triggerBuilder: (context, isOpen, isHovering) =>
          _buildTrigger(context, isOpen, isHovering, unreadCount: 0),
      contentBuilder: (context, close) => WDiv(
        className:
            'w-full py-12 flex flex-col items-center justify-center gap-3',
        children: [
          WIcon(Icons.error_outline, className: 'text-4xl text-red-500'),
          WText(
            trans('notifications.load_failed'),
            className: 'text-sm text-gray-600 dark:text-gray-400',
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'monitor_down':
        return Icons.error_outline;
      case 'monitor_up':
        return Icons.check_circle_outline;
      case 'monitor_degraded':
        return Icons.warning_amber_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  String _getColorForType(String type) {
    switch (type) {
      case 'monitor_down':
        return 'text-red-500';
      case 'monitor_up':
        return 'text-green-500';
      case 'monitor_degraded':
        return 'text-yellow-500';
      default:
        return 'text-blue-500';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return trans('time.just_now');
    } else if (difference.inHours < 1) {
      return trans('time.minutes_ago', {'minutes': difference.inMinutes});
    } else if (difference.inDays < 1) {
      return trans('time.hours_ago', {'hours': difference.inHours});
    } else if (difference.inDays < 7) {
      return trans('time.days_ago', {'days': difference.inDays});
    } else {
      return trans('time.date_format', {
        'day': dateTime.day,
        'month': dateTime.month,
        'year': dateTime.year,
      });
    }
  }
}
