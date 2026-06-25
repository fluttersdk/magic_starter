// Thin alias — MagicStarterSocialDivider is preserved for backward
// compatibility. The implementation now lives in
// components/social_divider/social_divider.dart.

import '../components/social_divider/social_divider.dart';

export '../components/social_divider/social_divider.dart' show SocialDivider;

/// Backward-compatible alias for [SocialDivider].
class MagicStarterSocialDivider extends SocialDivider {
  const MagicStarterSocialDivider({super.key});
}
