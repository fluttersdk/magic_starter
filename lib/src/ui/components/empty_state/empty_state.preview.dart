import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../button/button.dart';
import 'empty_state.dart';

/// Static preview for [MSEmptyState].
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
        const MSEmptyState(title: 'Nothing here yet'),
        const MSEmptyState(
          icon: Icons.inbox_outlined,
          title: 'No notifications',
          description: 'You are all caught up! Check back later.',
        ),
        MSEmptyState(
          icon: Icons.folder_open_outlined,
          title: 'No projects found',
          description: 'Create your first project to get started.',
          action: MSButton(
            onPressed: () {},
            child: const WText('Create project'),
          ),
        ),
      ],
    );
  }
}
