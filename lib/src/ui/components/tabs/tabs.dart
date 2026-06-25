import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'tabs.recipe.dart';

/// A recipe-driven tabs component for Magic Starter.
///
/// Wraps [WTabs] with semantic-token classNames resolved from [tabsRecipe].
/// This is a controlled widget: [selectedIndex] must be managed by the caller.
/// Use [onChanged] to react to tab taps.
///
/// ### Example Usage:
///
/// ```dart
/// Tabs(
///   tabs: const ['Overview', 'Details', 'Settings'],
///   selectedIndex: _selectedTab,
///   onChanged: (i) => setState(() => _selectedTab = i),
///   panelBuilder: (i) => _panels[i],
/// )
/// ```
///
/// ### Slot override:
///
/// ```dart
/// Tabs(
///   tabs: const ['A', 'B'],
///   selectedIndex: 0,
///   onChanged: (_) {},
///   panelBuilder: (i) => Text('Panel $i'),
///   classNames: {'tab': 'px-6 py-3'},
/// )
/// ```
@immutable
class Tabs extends StatelessWidget {
  /// The labels rendered for each tab, in display order.
  final List<String> tabs;

  /// The zero-based index of the currently selected tab.
  final int selectedIndex;

  /// Called when the user taps a tab, with its zero-based index.
  final ValueChanged<int>? onChanged;

  /// Builder that returns the panel content for the currently selected tab.
  final Widget Function(int index) panelBuilder;

  /// Per-slot className overrides appended after the recipe output.
  final Map<String, String>? classNames;

  /// Creates a [Tabs] widget.
  const Tabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.panelBuilder,
    this.onChanged,
    this.classNames,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve slot classNames from the recipe.
    final slots = tabsRecipe(classNames: classNames);

    // 2. Delegate to WTabs with recipe-driven slot classNames.
    return WTabs(
      tabs: tabs,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      panelBuilder: panelBuilder,
      listClassName: slots['list'],
      tabClassName: slots['tab'],
      panelClassName: slots['panel'],
    );
  }
}
