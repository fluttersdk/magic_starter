import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'update_banner.dart';

/// Static variant-matrix preview for [MSUpdateBanner].
///
/// Covers the web reload copy, the store update copy with the default icon,
/// and a long message that wraps. One preview class per file; discovered by
/// `previews:refresh`.
class UpdateBannerPreview extends StatelessWidget {
  /// Creates the MSUpdateBanner variant-matrix preview.
  const UpdateBannerPreview({super.key});

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'flex flex-col gap-4 p-6',
      children: [
        MSUpdateBanner(
          message: 'A new version is available. Reload to get it.',
          actionLabel: 'Reload',
          onAction: _noop,
          dismissLabel: 'Later',
          onDismiss: _noop,
        ),
        MSUpdateBanner(
          message: 'Version 1.2.0 is out in the store.',
          actionLabel: 'Update',
          onAction: _noop,
          dismissLabel: 'Later',
          onDismiss: _noop,
          icon: Icons.system_update,
        ),
        MSUpdateBanner(
          message:
              'A new version is available. Reload to get the latest fixes and '
              'improvements; nothing you have open will be lost.',
          actionLabel: 'Reload',
          onAction: _noop,
          dismissLabel: 'Later',
          onDismiss: _noop,
        ),
      ],
    );
  }
}
