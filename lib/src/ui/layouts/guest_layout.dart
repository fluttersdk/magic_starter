import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

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
        'slate',
        shade: 50,
        darkColorName: 'slate',
        darkShade: 900,
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
