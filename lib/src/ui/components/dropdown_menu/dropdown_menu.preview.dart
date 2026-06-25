import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'dropdown_menu.dart';

/// Static preview for the [DropdownMenu] component.
///
/// Renders a dropdown with a representative set of items (normal, disabled,
/// with leading icon) so the preview catalog can display the surface in light
/// and dark. One preview class per file is the canonical Wave 4 contract.
class DropdownMenuPreview extends StatelessWidget {
  /// Creates the dropdown-menu preview.
  const DropdownMenuPreview({super.key});

  static const _iconEdit = Icons.edit;
  static const _iconDelete = Icons.delete;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row gap-8 p-6',
      children: [
        // Standard menu.
        DropdownMenu(
          items: [
            DropdownMenuItem(
              label: 'Edit',
              leading: const WIcon(_iconEdit, className: 'text-fg text-sm'),
              onTap: () {},
            ),
            const DropdownMenuItem(label: 'View details', onTap: null),
            DropdownMenuItem(
              label: 'Delete',
              leading: const WIcon(
                _iconDelete,
                className: 'text-destructive text-sm',
              ),
              onTap: () {},
            ),
          ],
          child: WDiv(
            className:
                'px-4 py-2 rounded-lg bg-surface border border-color-border text-sm',
            child: const WText('Options'),
          ),
        ),
        // Menu with a disabled item.
        DropdownMenu(
          items: [
            const DropdownMenuItem(label: 'Available action', onTap: null),
            const DropdownMenuItem(
              label: 'Unavailable action',
              disabled: true,
            ),
          ],
          child: WDiv(
            className:
                'px-4 py-2 rounded-lg bg-surface border border-color-border text-sm',
            child: const WText('With disabled'),
          ),
        ),
      ],
    );
  }
}
