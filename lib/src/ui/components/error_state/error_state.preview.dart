import 'package:flutter/material.dart' show Icons, ElevatedButton, Text;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'error_state.dart';

/// Static preview for [ErrorState].
///
/// Renders two variations: minimal (title-only) and full (all slots). One
/// preview class per file.
class ErrorStatePreview extends StatelessWidget {
  const ErrorStatePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-8 p-6',
      children: [
        const ErrorState(title: 'Something went wrong'),
        ErrorState(
          icon: Icons.error_outline,
          title: 'Failed to load data',
          description: 'Please check your connection and try again.',
          action: ElevatedButton(
            onPressed: () {},
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
