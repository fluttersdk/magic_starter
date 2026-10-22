import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../button/button.dart';
import 'page_header.dart';

/// Static preview for [MSPageHeader].
///
/// Renders the layout variants: title-only, with subtitle, with actions, with
/// inlineActions, with a back control, the large title and the compact bar.
/// One preview class per file.
class PageHeaderPreview extends StatelessWidget {
  const PageHeaderPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        const MSPageHeader(title: 'Dashboard'),
        const MSPageHeader(title: 'Projects', subtitle: 'Manage your projects'),
        MSPageHeader(
          title: 'Settings',
          actions: [MSButton(onPressed: () {}, child: const WText('Save'))],
        ),
        MSPageHeader(
          title: 'Create',
          inlineActions: true,
          leading: const Icon(Icons.arrow_back),
          actions: [MSButton(onPressed: () {}, child: const WText('Create'))],
        ),
        // Back-enabled variant: auto-back via backLabel + backFallback.
        const MSPageHeader(
          title: 'Profile',
          subtitle: 'Edit your profile information',
          backLabel: 'Settings',
          backFallback: '/settings',
        ),
        // Large title, and the compact bar it collapses into on scroll.
        const MSPageHeader(title: 'Stock', size: MSPageHeaderSize.large),
        MSPageHeader(
          title: 'Stock',
          size: MSPageHeaderSize.compact,
          backLabel: 'Overview',
          backFallback: '/',
          actions: [MSButton(onPressed: () {}, child: const WText('Edit'))],
        ),
      ],
    );
  }
}
