import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'tabs.dart';

/// Static variant-matrix preview for [MSTabs].
///
/// Renders a Tabs widget with a three-tab configuration so the catalog can
/// exercise light and dark themes and interaction states. One preview class per
/// file is the canonical Wave 4 contract.
class TabsPreview extends StatefulWidget {
  /// Creates the tabs variant-matrix preview.
  const TabsPreview({super.key});

  @override
  State<TabsPreview> createState() => _TabsPreviewState();
}

class _TabsPreviewState extends State<TabsPreview> {
  int _selected = 0;

  static const List<String> _tabs = ['Overview', 'Details', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        WText(
          'Tabs — interactive',
          className: 'text-sm font-medium text-fg-muted',
        ),
        MSTabs(
          tabs: _tabs,
          selectedIndex: _selected,
          onChanged: (i) => setState(() => _selected = i),
          panelBuilder: (i) => WDiv(
            className: 'p-2',
            child: WText(
              '${_tabs[i]} panel content',
              className: 'text-sm text-fg',
            ),
          ),
        ),
      ],
    );
  }
}
