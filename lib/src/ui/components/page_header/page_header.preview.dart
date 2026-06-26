import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../button/button.dart';
import 'page_header.dart';

/// Static preview for [PageHeader].
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
        const PageHeader(title: 'Dashboard'),
        const PageHeader(
          title: 'Projects',
          subtitle: 'Manage your projects',
        ),
        PageHeader(
          title: 'Settings',
          actions: [
            Button(
              onPressed: () {},
              child: const WText('Save'),
            ),
          ],
        ),
        PageHeader(
          title: 'Create',
          inlineActions: true,
          leading: const Icon(Icons.arrow_back),
          actions: [
            Button(
              onPressed: () {},
              child: const WText('Create'),
            ),
          ],
        ),
      ],
    );
  }
}
