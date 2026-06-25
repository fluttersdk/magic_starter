// Thin alias — MagicStarterUserProfileDropdown is preserved for backward
// compatibility. The implementation now lives in
// components/user_profile_dropdown/user_profile_dropdown.dart.

import '../components/user_profile_dropdown/user_profile_dropdown.dart';

export '../components/user_profile_dropdown/user_profile_dropdown.dart'
    show UserProfileDropdown;

/// Backward-compatible alias for [UserProfileDropdown].
class MagicStarterUserProfileDropdown extends UserProfileDropdown {
  const MagicStarterUserProfileDropdown({
    super.key,
    super.alignment,
    super.triggerBuilder,
  });
}
