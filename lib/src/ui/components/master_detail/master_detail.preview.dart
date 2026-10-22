import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'master_detail.dart';

/// Static preview for [MSMasterDetail].
///
/// Renders a selected item and an empty selection. At a catalog width from
/// `lg` up the list and the detail sit side by side; below it each instance
/// shows what a phone would (the item, then the list).
class MasterDetailPreview extends StatelessWidget {
  /// Creates the [MSMasterDetail] preview.
  const MasterDetailPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-8 p-6',
      children: const [
        MSMasterDetail(
          master: _PreviewList(selected: 'Milk'),
          detail: _PreviewPanel(text: 'Milk: 1 carton and 600 ml'),
        ),
        MSMasterDetail(
          master: _PreviewList(),
          placeholder: _PreviewPanel(text: 'Select an item to see it here.'),
        ),
      ],
    );
  }
}

/// A short list stub for the preview only.
class _PreviewList extends StatelessWidget {
  final String? selected;

  const _PreviewList({this.selected});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className:
          'flex flex-col rounded-2xl bg-surface-container border border-color-border',
      children: [
        for (final String item in const ['Milk', 'Coffee', 'Batteries'])
          WDiv(
            className: item == selected
                ? 'px-4 py-3 bg-surface-container-high'
                : 'px-4 py-3',
            child: WText(item, className: 'text-sm text-fg'),
          ),
      ],
    );
  }
}

/// A detail stub for the preview only.
class _PreviewPanel extends StatelessWidget {
  final String text;

  const _PreviewPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className:
          'p-6 rounded-2xl bg-surface-container border border-color-border',
      child: WText(text, className: 'text-sm text-fg-muted'),
    );
  }
}
