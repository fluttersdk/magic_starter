import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../button/button.dart';
import 'page_header.dart';

/// Static preview for [MSPageHeader].
///
/// Renders four layout variants: title-only, with subtitle, with actions, and
/// with inlineActions. One preview class per file.
class PageHeaderPreview extends StatelessWidget {
  const PageHeaderPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        const MSPageHeader(title: 'Dashboard'),
        const MSPageHeader(
          title: 'Projects',
          subtitle: 'Manage your projects',
        ),
        MSPageHeader(
          title: 'Settings',
          actions: [
            MSButton(
              onPressed: () {},
              child: const WText('Save'),
            ),
          ],
        ),
        MSPageHeader(
          title: 'Create',
          inlineActions: true,
          leading: const Icon(Icons.arrow_back),
          actions: [
            MSButton(
              onPressed: () {},
              child: const WText('Create'),
            ),
          ],
        ),
        // Back-enabled variant: auto-back via backLabel + backFallback.
        const MSPageHeader(
          title: 'Profile',
          subtitle: 'Edit your profile information',
          backLabel: 'Settings',
          backFallback: '/settings',
        ),
      ],
    );
  }
}
