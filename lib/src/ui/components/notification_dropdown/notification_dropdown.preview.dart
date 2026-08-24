import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';

import 'notification_dropdown.dart';

/// Static preview for [MSNotificationDropdown].
///
/// Renders the dropdown with a mock notification stream (empty state). One
/// preview class per file.
class NotificationDropdownPreview extends StatefulWidget {
  const NotificationDropdownPreview({super.key});

  @override
  State<NotificationDropdownPreview> createState() =>
      _NotificationDropdownPreviewState();
}

class _NotificationDropdownPreviewState
    extends State<NotificationDropdownPreview> {
  final StreamController<List<DatabaseNotification>> _controller =
      StreamController<List<DatabaseNotification>>.broadcast();

  @override
  void initState() {
    super.initState();
    // Emit empty list so the preview shows the empty state immediately.
    _controller.add([]);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-start gap-6 p-6',
      children: [
        MSNotificationDropdown(notificationStream: _controller.stream),
      ],
    );
  }
}
