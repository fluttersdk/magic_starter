import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Default Guest Layout for Magic Starter.
///
/// Simple centered wrapper for authentication pages.
class MagicStarterGuestLayout extends StatelessWidget {
  final Widget child;

  const MagicStarterGuestLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: wColor(
        context,
        MagicStarter.manager.layoutTheme.contentBackgroundLightColor,
        shade: MagicStarter.manager.layoutTheme.contentBackgroundLightShade,
        darkColorName:
            MagicStarter.manager.layoutTheme.contentBackgroundDarkColor,
        darkShade: MagicStarter.manager.layoutTheme.contentBackgroundDarkShade,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            primary: true,
            child: WDiv(className: 'p-4 lg:p-8', child: child),
          ),
        ),
      ),
    );
  }
}
