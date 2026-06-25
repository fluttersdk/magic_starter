import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'navbar.dart';

/// Static preview for [Navbar].
///
/// Renders two variations: brand-only and full (brand + links + trailing). One
/// preview class per file.
class NavbarPreview extends StatelessWidget {
  const NavbarPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6',
      children: [
        Navbar(
          brand: const WText('Acme', className: 'text-lg font-bold text-fg'),
          children: const [],
        ),
        Navbar(
          brand: const WText('Acme', className: 'text-lg font-bold text-fg'),
          trailing: const WDiv(
            className:
                'w-8 h-8 rounded-full bg-surface-container flex items-center justify-center',
            child: WText('U', className: 'text-sm font-bold text-fg'),
          ),
          children: [
            const WText('Dashboard', className: 'text-sm font-medium text-fg'),
            const WText('Projects', className: 'text-sm font-medium text-fg'),
          ],
        ),
      ],
    );
  }
}
