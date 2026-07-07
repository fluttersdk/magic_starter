// Thin alias — MagicStarterSocialDivider is preserved for backward
// compatibility. The implementation now lives in
// components/social_divider/social_divider.dart.

import '../components/social_divider/social_divider.dart';

export '../components/social_divider/social_divider.dart' show MSSocialDivider;

/// Backward-compatible alias for [MSSocialDivider].
class MagicStarterSocialDivider extends MSSocialDivider {
  const MagicStarterSocialDivider({super.key});
}
