import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';

import '../../widgets/magic_starter_card.dart';
import '../../widgets/magic_starter_page_header.dart';

import '../../../facades/magic_starter.dart';

/// Full-page view for listing all notifications with mark as read,
/// delete, pagination, and view all functionality.
/// Uses server-side pagination for efficiency.
class MagicStarterNotificationsListView extends StatefulWidget {
  final Future<void> Function(String id)? onMarkAsRead;
  final Future<void> Function()? onMarkAllAsRead;
  final Future<void> Function(String id)? onDelete;
  final void Function(String path)? onNavigate;
  final int perPage;

  const MagicStarterNotificationsListView({
    super.key,
    this.onMarkAsRead,
    this.onMarkAllAsRead,
    this.onDelete,
    this.onNavigate,
    this.perPage = 15,
  });

  @override
  State<MagicStarterNotificationsListView> createState() =>
      _MagicStarterNotificationsListViewState();
}

class _MagicStarterNotificationsListViewState
    extends State<MagicStarterNotificationsListView> {
  static const _notificationTypeIcons = <String, IconData>{
    'monitor_up': Icons.check_circle_outline,
    'monitor_degraded': Icons.warning_outlined,
    'monitor_down': Icons.error_outline,
  };
  static const _defaultNotificationIcon = Icons.info_outline;

  PaginatedNotifications? _paginatedData;
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await Notify.fetchPaginatedNotifications(
        page: page,
        perPage: widget.perPage,
      );

      if (!mounted) return;

      setState(() {
        _paginatedData = result;
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final notifications = _paginatedData?.data ?? [];
    final hasUnread = notifications.any((n) => !n.isRead);
    final totalPages = _paginatedData?.lastPage ?? 1;

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        _buildHeader(context, hasUnread: hasUnread),
        _buildBody(context, notifications, totalPages),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, {required bool hasUnread}) {
    return MagicStarterPageHeader(
      title: trans('notifications.title'),
      subtitle: trans('notifications.list_subtitle'),
      actions: hasUnread
          ? [
              WButton(
                onTap: () async {
                  if (widget.onMarkAllAsRead != null) {
                    await widget.onMarkAllAsRead!.call();
                  } else {
                    await Notify.markAllAsRead();
                  }
                  _loadPage(_currentPage);
                },
                className:
                    'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white font-medium text-sm',
                child: WText(
                  trans('notifications.mark_all_read'),
                  className: 'text-white font-medium text-sm',
                ),
              ),
            ]
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<DatabaseNotification> notifications,
    int totalPages,
  ) {
    if (_isLoading && notifications.isEmpty) {
      return const MagicStarterCard(
        child: WDiv(
          className: 'flex items-center justify-center py-20',
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasError) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        message: trans('notifications.load_failed'),
      );
    }

    if (notifications.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_off_outlined,
        message: trans('notifications.empty'),
      );
    }

    return WDiv(
      className: 'flex flex-col gap-6',
      children: [
        MagicStarterCard(
          noPadding: true,
          child: WDiv(
            className: 'flex flex-col',
            children:
                notifications.map((n) => _buildNotificationItem(n)).toList(),
          ),
        ),
        if (totalPages > 1) _buildPagination(totalPages),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return MagicStarterCard(
      child: WDiv(
        className: 'flex flex-col items-center justify-center py-20 gap-4',
        children: [
          WIcon(icon, className: 'text-6xl text-gray-300 dark:text-gray-600'),
          WText(message, className: 'text-gray-500 dark:text-gray-400'),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(DatabaseNotification notification) {
    final mapper = MagicStarter.notificationTypeMapper;
    final mapping = mapper?.call(notification.type);

    final IconData icon = mapping?.icon ??
        _notificationTypeIcons[notification.type] ??
        _defaultNotificationIcon;

    final String iconColor = mapping?.colorClass ??
        switch (notification.type) {
          'monitor_up' => 'text-green-500',
          'monitor_degraded' => 'text-yellow-500',
          'monitor_down' => 'text-red-500',
          _ => 'text-blue-500',
        };

    return WAnchor(
      onTap: () async {
        // 1. Mark as read via callback or Notify facade directly.
        if (widget.onMarkAsRead != null) {
          await widget.onMarkAsRead!.call(notification.id);
        } else {
          await Notify.markAsRead(notification.id);
        }

        // 2. Navigate to action URL or reload the page.
        if (notification.actionUrl != null) {
          if (widget.onNavigate != null) {
            widget.onNavigate!(notification.actionUrl!);
          } else {
            MagicRoute.to(notification.actionUrl!);
          }
        } else {
          _loadPage(_currentPage);
        }
      },
      child: WDiv(
        className:
            'px-6 py-4 flex flex-row items-center gap-4 border-b border-gray-100 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800/50',
        children: [
          WDiv(
            className:
                'w-10 h-10 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center flex-shrink-0',
            child: WIcon(icon, className: 'text-xl $iconColor'),
          ),
          Expanded(
            child: WDiv(
              className: 'flex flex-col min-w-0',
              children: [
                WText(
                  notification.title,
                  className: notification.isRead
                      ? 'text-sm text-gray-900 dark:text-white'
                      : 'text-sm text-gray-900 dark:text-white font-semibold',
                ),
                const WSpacer(className: 'h-0.5'),
                WText(
                  notification.body,
                  className: 'text-sm text-gray-500 dark:text-gray-400',
                ),
                const WSpacer(className: 'h-1'),
                WText(
                  _formatTime(notification.createdAt),
                  className: 'text-xs text-gray-400 dark:text-gray-500',
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            const WDiv(
              className: 'w-2 h-2 rounded-full bg-primary flex-shrink-0',
              child: SizedBox.shrink(),
            ),
          if (widget.onDelete != null)
            WAnchor(
              onTap: () async {
                await widget.onDelete?.call(notification.id);
                _loadPage(_currentPage);
              },
              child: WDiv(
                className:
                    'p-2 ml-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20',
                child: WIcon(
                  Icons.delete_outline,
                  className: 'text-lg text-gray-400 hover:text-red-500',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return WDiv(
      className: 'w-full flex flex-row items-center justify-center gap-2 mt-4',
      children: [
        WButton(
          onTap: _currentPage > 1 ? () => _loadPage(_currentPage - 1) : null,
          disabled: _currentPage <= 1,
          className:
              'px-3 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 disabled:opacity-50',
          child: WIcon(
            Icons.chevron_left,
            className: 'text-gray-600 dark:text-gray-300',
          ),
        ),
        WText(
          trans('common.page_of', {
            'current': _currentPage,
            'total': totalPages,
          }),
          className: 'text-sm font-medium text-gray-700 dark:text-gray-300',
        ),
        WButton(
          onTap: _currentPage < totalPages
              ? () => _loadPage(_currentPage + 1)
              : null,
          disabled: _currentPage >= totalPages,
          className:
              'px-3 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 disabled:opacity-50',
          child: WIcon(
            Icons.chevron_right,
            className: 'text-gray-600 dark:text-gray-300',
          ),
        ),
      ],
    );
  }
}
