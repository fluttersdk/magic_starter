import 'package:flutter/material.dart' show Icons, ElevatedButton, Text;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'empty_state.dart';

/// Static preview for [EmptyState].
///
/// Renders three variations: minimal (title-only), with all slots, and with
/// action. One preview class per file.
class EmptyStatePreview extends StatelessWidget {
  const EmptyStatePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-8 p-6',
      children: [
        const EmptyState(title: 'Nothing here yet'),
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'No notifications',
          description: 'You are all caught up! Check back later.',
        ),
        EmptyState(
          icon: Icons.folder_open_outlined,
          title: 'No projects found',
          description: 'Create your first project to get started.',
          action: ElevatedButton(
            onPressed: () {},
            child: const Text('Create project'),
          ),
        ),
      ],
    );
  }
}
