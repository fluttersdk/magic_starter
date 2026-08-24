import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'usage_meter.dart';

/// Static variant-matrix preview for [MSUsageMeter].
///
/// Covers headroom, near-limit, at-limit, unlimited, and an explicit warning
/// (>80%) row so every tone is represented. One preview class per file;
/// discovered by `previews:refresh`.
///
/// Renders under whatever `WindTheme` its host provides; it does not wrap its
/// own, so a host must wire `MagicStarterTokens.defaultAliases` (or an
/// equivalent map) for the tone fills to be visible, same as every other
/// preview in this catalogue.
class UsageMeterPreview extends StatelessWidget {
  /// Creates the MSUsageMeter variant-matrix preview.
  const UsageMeterPreview({super.key});

  static String _format(int value) => value.toString();

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'flex flex-col gap-5 p-6 max-w-sm',
      children: [
        MSUsageMeter(
          label: 'Monitors',
          used: 4,
          limit: 50,
          formatNumber: _format,
        ),
        MSUsageMeter(
          label: 'Status pages',
          used: 2,
          limit: 3,
          formatNumber: _format,
        ),
        MSUsageMeter(
          label: 'Alerts',
          used: 9,
          limit: 10,
          formatNumber: _format,
        ),
        MSUsageMeter(
          label: 'Responders',
          used: 3,
          limit: 3,
          formatNumber: _format,
        ),
        MSUsageMeter(
          label: 'Monitors',
          used: 420,
          limit: null,
          formatNumber: _format,
        ),
      ],
    );
  }
}
