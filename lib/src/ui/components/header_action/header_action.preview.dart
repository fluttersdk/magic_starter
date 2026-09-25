import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../button/button.recipe.dart';
import 'header_action.dart';

/// Static variant-matrix preview for [MSHeaderAction].
///
/// Renders the primary and secondary intents, and the disabled form, on the
/// icon-only layout a phone-width preview lands on.
class HeaderActionPreview extends StatelessWidget {
  /// Creates the header-action variant-matrix preview.
  const HeaderActionPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row gap-4 p-6',
      children: [
        MSHeaderAction(
          icon: Icons.add,
          label: 'New monitor',
          intent: ButtonIntent.primary,
          onPressed: () {},
        ),
        MSHeaderAction(
          icon: Icons.filter_list,
          label: 'Filters',
          intent: ButtonIntent.secondary,
          onPressed: () {},
        ),
        const MSHeaderAction(
          icon: Icons.add,
          label: 'New monitor',
          onPressed: null,
        ),
      ],
    );
  }
}
