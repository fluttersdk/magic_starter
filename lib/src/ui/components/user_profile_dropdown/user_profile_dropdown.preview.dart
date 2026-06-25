import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'user_profile_dropdown.dart';

/// Static preview for [UserProfileDropdown].
///
/// Renders the dropdown trigger in its default and topRight alignment. One
/// preview class per file.
class UserProfileDropdownPreview extends StatelessWidget {
  const UserProfileDropdownPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-start gap-6 p-6',
      children: const [
        UserProfileDropdown(),
        UserProfileDropdown(alignment: PopoverAlignment.topRight),
      ],
    );
  }
}
